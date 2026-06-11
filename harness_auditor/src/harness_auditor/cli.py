"""
CLI entrypoint for the RAGF Ontology Auditor.

End-to-end pipeline:

  1. Validate the candidate YAML against the ontology schema.
  2. Hash the canonical JSON form (SHA-256) for provenance.
  3. Wipe and project the ontology into the Neo4j sandbox.
  4. Execute every registered certification criterion.
  5. Aggregate, render, and HMAC-sign the report.

Exit codes follow ``docs/ARCHITECTURE.md``:

  0 — PASSED
  1 — FAILED or REQUIRES_REVIEW (any blocking/advisory failure, or unsigned)
  2 — input invalid (YAML parse / schema validation failure / file missing)
  3 — infrastructure error (Neo4j unreachable, query execution failure)
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

import typer
import yaml
from neo4j import GraphDatabase
from neo4j.exceptions import AuthError, Neo4jError, ServiceUnavailable
from pydantic import ValidationError
from rich.console import Console

from harness_auditor import __version__
from harness_auditor.loader import (
    LoaderMismatchError,
    load,
    load_previous,
    load_taxonomy,
)
from harness_auditor.report import build_report, write_artifacts
from harness_auditor.runner import packaged_queries_dir, run_all
from harness_auditor.schemas.ontology_schema import Ontology, Taxonomy
from harness_auditor.schemas.report_schema import (
    AuditReport,
    CertificationStatus,
    CriterionStatus,
)

EXIT_OK = 0
EXIT_VERDICT_FAILURE = 1
EXIT_INPUT_INVALID = 2
EXIT_INFRA_ERROR = 3

#: Default threshold for CC-11. A constraint is reported when its PageRank
#: score strictly exceeds this multiple of the graph's mean score. Lower
#: values are stricter (more rows reported).
DEFAULT_CC11_THRESHOLD_RATIO = 1.3

app = typer.Typer(
    name="harness-audit",
    add_completion=False,
    no_args_is_help=True,
    help="Pre-execution certification of RAGF governance harnesses.",
)
console = Console()


@app.callback()
def _main() -> None:
    """Force ``audit`` (and any future subcommand) to be explicit at the CLI."""


def _read_ontology(path: Path) -> tuple[Ontology, str]:
    if not path.is_file():
        console.print(f"[red]error[/]: ontology not found: {path}")
        raise typer.Exit(EXIT_INPUT_INVALID)
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        console.print(f"[red]error[/]: invalid YAML in {path}: {e}")
        raise typer.Exit(EXIT_INPUT_INVALID) from e
    try:
        ontology = Ontology.model_validate(data)
    except ValidationError as e:
        console.print(f"[red]error[/]: ontology failed schema validation:\n{e}")
        raise typer.Exit(EXIT_INPUT_INVALID) from e
    canonical = json.dumps(
        ontology.model_dump(mode="json"),
        sort_keys=True,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return ontology, digest


def _read_taxonomy(path: Path) -> Taxonomy:
    if not path.is_file():
        console.print(f"[red]error[/]: taxonomy not found: {path}")
        raise typer.Exit(EXIT_INPUT_INVALID)
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        console.print(f"[red]error[/]: invalid YAML in {path}: {e}")
        raise typer.Exit(EXIT_INPUT_INVALID) from e
    try:
        return Taxonomy.model_validate(data)
    except ValidationError as e:
        console.print(f"[red]error[/]: taxonomy failed schema validation:\n{e}")
        raise typer.Exit(EXIT_INPUT_INVALID) from e


def _resolve_cc11_threshold() -> float:
    raw = os.environ.get("CC11_THRESHOLD_RATIO")
    if raw is None:
        return DEFAULT_CC11_THRESHOLD_RATIO
    try:
        value = float(raw)
    except ValueError:
        console.print(
            f"[red]error[/]: CC11_THRESHOLD_RATIO must be a float; got: {raw!r}"
        )
        raise typer.Exit(EXIT_INPUT_INVALID) from None
    if value <= 1.0:
        console.print(
            f"[red]error[/]: CC11_THRESHOLD_RATIO must be > 1.0; got: {value}"
        )
        raise typer.Exit(EXIT_INPUT_INVALID)
    return value


@app.command()
def audit(
    ontology: Path = typer.Option(
        ...,
        "--ontology",
        help="Path to the candidate ontology YAML.",
    ),
    previous: Path = typer.Option(
        None,
        "--previous",
        help="Path to the previous ontology YAML — enables CC-07 (Drift Delta).",
    ),
    taxonomy: Path = typer.Option(
        None,
        "--taxonomy",
        help="Path to the registered verb taxonomy YAML — enables CC-10 "
        "(Hallucinated Verbs).",
    ),
    reports_dir: Path = typer.Option(
        Path("./reports"),
        "--reports-dir",
        help="Directory under which reports/<sha256>/ artifacts are written.",
    ),
    queries_dir: Path = typer.Option(
        None,
        "--queries-dir",
        help="Directory containing CC-NN.cypher files. Defaults to the bundled set.",
    ),
    neo4j_uri: str = typer.Option(
        "bolt://127.0.0.1:7687",
        "--neo4j-uri",
        envvar="NEO4J_URI",
        help="Bolt URI of the auditor sandbox.",
    ),
    neo4j_user: str = typer.Option(
        "neo4j",
        "--neo4j-user",
        envvar="NEO4J_USER",
    ),
    neo4j_password: str = typer.Option(
        "auditor_local_only",
        "--neo4j-password",
        envvar="NEO4J_PASSWORD",
        hide_input=True,
    ),
    hmac_key: str = typer.Option(
        "",
        "--hmac-key",
        envvar="AUDITOR_HMAC_KEY",
        help="HMAC-SHA256 key for the report signature. "
        "Unset → status forced to REQUIRES_REVIEW.",
        hide_input=True,
    ),
) -> None:
    """Audit a candidate ontology against the certification criteria."""
    console.print(f"[bold]harness-auditor[/] v{__version__}")

    ontology_obj, digest = _read_ontology(ontology)
    console.print(f"  ontology      : {ontology}")
    console.print(
        f"  domain        : {ontology_obj.domain.name} v{ontology_obj.domain.version}"
    )
    console.print(f"  sha256        : {digest}")

    resolved_queries_dir = queries_dir or packaged_queries_dir()
    if not resolved_queries_dir.is_dir():
        console.print(
            f"[red]error[/]: queries directory not found: {resolved_queries_dir}"
        )
        raise typer.Exit(EXIT_INPUT_INVALID)
    console.print(f"  queries dir   : {resolved_queries_dir}")

    cc11_threshold = _resolve_cc11_threshold()
    console.print(f"  CC-11 ratio   : {cc11_threshold:.2f}x (graph mean)")

    reports_dir.mkdir(parents=True, exist_ok=True)

    driver = GraphDatabase.driver(neo4j_uri, auth=(neo4j_user, neo4j_password))
    try:
        try:
            driver.verify_connectivity()
        except (ServiceUnavailable, AuthError) as e:
            console.print(f"[red]error[/]: Neo4j unreachable at {neo4j_uri}: {e}")
            raise typer.Exit(EXIT_INFRA_ERROR) from e

        previous_obj: Ontology | None = None
        taxonomy_obj: Taxonomy | None = None
        if previous is not None:
            previous_obj, prev_digest = _read_ontology(previous)
            console.print(f"  previous ont  : {previous} (sha256: {prev_digest[:12]}…)")
        if taxonomy is not None:
            taxonomy_obj = _read_taxonomy(taxonomy)
            console.print(
                f"  taxonomy      : {taxonomy} "
                f"(domain={taxonomy_obj.domain}, {len(taxonomy_obj.verbs)} verbs)"
            )

        try:
            with driver.session() as session:
                session.run("MATCH (n) DETACH DELETE n")
                load(session, ontology_obj)
                if previous_obj is not None:
                    load_previous(session, previous_obj)
                if taxonomy_obj is not None:
                    load_taxonomy(session, taxonomy_obj)
                criteria = run_all(
                    session,
                    resolved_queries_dir,
                    query_params={"threshold_ratio": cc11_threshold},
                )
        except LoaderMismatchError as e:
            console.print(f"[red]error[/]: loader sanity check failed: {e}")
            raise typer.Exit(EXIT_INFRA_ERROR) from e
        except Neo4jError as e:
            console.print(f"[red]error[/]: Neo4j query error: {e}")
            raise typer.Exit(EXIT_INFRA_ERROR) from e
    finally:
        driver.close()

    report = build_report(
        ontology_sha256=digest,
        domain=ontology_obj.domain.name,
        domain_version=ontology_obj.domain.version,
        criteria=criteria,
        hmac_key_present=bool(hmac_key),
    )
    out_dir = write_artifacts(report, reports_dir, hmac_key or None)

    _print_summary(report, out_dir)

    if report.certification_status == CertificationStatus.PASSED:
        raise typer.Exit(EXIT_OK)
    raise typer.Exit(EXIT_VERDICT_FAILURE)


_VERDICT_COLOR = {
    "PASSED": "green",
    "REQUIRES_REVIEW": "yellow",
    "FAILED": "red",
}
_CRITERION_COLOR = {
    "PASS": "green",
    "WARN": "yellow",
    "FAIL": "red",
    "ERROR": "red",
    "SKIP": "white",
}


def _print_summary(report: AuditReport, out_dir: Path) -> None:
    status = report.certification_status.value
    color = _VERDICT_COLOR.get(status, "white")
    console.print()
    console.print(f"[bold {color}]verdict[/]: {status}")
    console.print(
        f"  PASS: {report.passed}  WARN: {report.warned}  "
        f"FAIL: {report.failed}  SKIP: {report.skipped}"
    )
    console.print(f"  latency       : {report.total_latency_ms:.1f} ms")
    console.print(f"  report dir    : {out_dir}")

    for c in report.criteria:
        cc = _CRITERION_COLOR.get(c.status.value, "white")
        console.print(
            f"  [{cc}]{c.status.value:<5}[/] "
            f"{c.criterion_id} · {c.name} "
            f"({c.severity.value}, {c.latency_ms:.1f} ms)"
        )
        if c.status != CriterionStatus.PASS:
            console.print(f"        {c.message}")


if __name__ == "__main__":
    app()
