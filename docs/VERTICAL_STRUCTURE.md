# VERTICAL_STRUCTURE — RAGF Framework Conventions

**Canonical reference for adding, structuring, and promoting a regulatory vertical in RAGF.**

Version: 1.0 · Status: Canonical · Audience: technical integrators, framework contributors, internal developers · Tone: RFC

Whenever a vertical (healthcare, fintech, aviation, pharma, e-commerce, employment, …) is added to RAGF, its artifacts must conform to this document. Where another file disagrees with this one, this file wins and the other file is to be corrected. This document complements `docs/AMM.md`: AMM defines the maturity model, this document defines the structural and procedural contract.

---

## 1. What RAGF is, as an artifact

RAGF is a **monorepo with two public artifacts**:

| Artifact | Distribution | Purpose | Audience |
|---|---|---|---|
| **`ragf` CLI** | installable Python distribution (`pip install ragf`) | author, audit, compile, and validate regulatory ontologies | integrator, ontology author, CI/CD |
| **`gateway`** | service (FastAPI + Neo4j; deployable via Docker) | runtime Validation Gate that issues verdicts over agent actions | runtime operators, deploying organisations |

The CLI is the **authoring and certification surface**. The gateway is the **runtime enforcement surface**. They share the YAML ontology contract: the CLI produces and certifies it; the gateway consumes the Cypher compiled from it.

This split is intentional. Not all components of RAGF need to be `pip install`-able, and not all need to run as a service. The CLI bundles the artifacts a regulated ontology author needs at their desk; the gateway bundles the artifacts a regulated production environment needs to enforce in real time.

---

## 2. The canonical authoring flow

Every regulatory vertical in RAGF — without exception — passes through this flow before its ontology may serve a single production verdict.

```
  ┌────────────────────┐
  │ YAML authored      │  ← human authorship; legal-technical review
  │  (single source    │
  │   of truth)        │
  └─────────┬──────────┘
            │
            ▼
  ┌────────────────────┐
  │ ragf audit         │  ← runs CC-01..CC-11 on YAML loaded into
  │                    │     ephemeral Neo4j sandbox
  └─────────┬──────────┘
            │
       blocking CCs pass?
            │
            ▼
  ┌────────────────────┐
  │ ragf compile       │  ← deterministic YAML → Cypher generation
  └─────────┬──────────┘
            │
            ▼
  ┌────────────────────┐
  │ ragf validate      │  ← load to staging Neo4j; smoke test
  └─────────┬──────────┘
            │
            ▼
  ┌────────────────────┐
  │ Promote to gateway │  ← cypher artifact loaded into production Neo4j
  └────────────────────┘
```

The YAML is the **contractual artifact**: it is what a legal or compliance team reviews, signs off on, and treats as the authoritative statement of what obligations the gateway will enforce. The Cypher is the **executional artifact**: it is what the runtime motor consumes. The auditor guarantees the YAML is well-formed; the compiler guarantees the Cypher is a faithful translation of the YAML.

A vertical whose YAML has not been audited, or whose Cypher was not produced by `ragf compile` from an audited YAML, **is not a RAGF vertical**. It is, at best, a prototype.

---

## 3. The YAML contract

The YAML is the single source of truth for any RAGF regulatory ontology. The schema is fixed; it is what the `harness_auditor` validates against, and what the compiler reads.

### 3.1 Top-level structure

```yaml
schema_version: "1.0"

domain:
  name: <slug>                    # canonical vertical slug, lowercase + underscores
  version: <semver>
  description: <one-line>

regulations:
  - code: <UPPER_SNAKE>
    name: <human-readable>
    description: <one-paragraph>
    celex: <EU CELEX id, if applicable>

verbs:
  - name: <lower_snake>
    description: <one-line>
    risk_level: <low|medium|high|critical>     # action risk; see §6
    required_amm_level: <1..5>                  # canonical name; not min_amm_level
    requires_human_approval: <boolean>
    must_satisfy:
      - <REGULATION_CODE>
      - …
    payload_schema:
      - name: <field>
        type: <float|int|string|boolean>
        required: <boolean>
        description: <one-line>

constraints:
  - id: <UPPER_SNAKE>
    verb: <verb_name>
    references: <REGULATION_CODE>
    parameter: <payload_field>
    operator: <eq|neq|gt|gte|lt|lte|in|matches>
    value: <literal>
    decision_if_violated: <DENY|ESCALATE>        # ALLOW is forbidden; see §6
    precedence_level: <integer>
    supersedes:
      - <CONSTRAINT_ID>
```

### 3.2 Schema versioning

The schema version is declared in the YAML's first key. Breaking changes to the schema produce a new major (`schema_version: "2.0"`). Backwards-compatible additions produce a new minor (`schema_version: "1.1"`).

The `ragf` CLI declares which schema versions it supports in its `--version` output. A YAML at `schema_version: "1.0"` will be processable by CLI v1.x.y for any `y`. A YAML at `schema_version: "2.0"` requires CLI v2.0+.

### 3.3 Cross-references with `docs/AMM.md`

The field name in this document is `required_amm_level`, in conformance with the canonical `docs/AMM.md`. **The legacy field name `min_amm_level` (still present in the auditor's internal schema as of v0.2.0) is deprecated.** During the deprecation window — defined as the entirety of CLI v1.x — `ragf audit` accepts both spellings and emits a `DeprecationWarning` whenever `min_amm_level` is encountered, naming the offending verb and YAML line. **Support for `min_amm_level` is removed in CLI v2.0**: a YAML that still uses it will exit with code 5 (schema malformed; see §7.1) under v2.0.

This window gives the auditor and any external integrator one major-version cycle to migrate to the canonical spelling. The deprecation warning is silent by default in CI runs that opt out of `PYTHONWARNINGS`; for hard enforcement during the v1.x window, integrators can run `ragf audit --strict-deprecation`, which promotes the warning to a failure and exits with code 2 (FAILED).

---

## 4. Directory convention

Every vertical leaves identical footprints in five places. The slug `<vertical>` is shared verbatim across all of them.

```
gateway/ontologies/<vertical>/
gateway/ontologies/<vertical>/<vertical>.yaml          # canonical YAML — the contract
gateway/ontologies/<vertical>/seed.cypher              # generated by `ragf compile`; not hand-edited
gateway/ontologies/<vertical>/README.md                # vertical-level README

gateway/validators/<vertical>/
gateway/validators/<vertical>/__init__.py
gateway/validators/<vertical>/<rule_family>_validator.py
gateway/validators/<vertical>/README.md

gateway/pregates/<vertical>/                           # only if vertical needs pre-gates (see §5)
gateway/pregates/<vertical>/__init__.py
gateway/pregates/<vertical>/<pregate_name>.py
gateway/pregates/<vertical>/README.md

tests/unit/<vertical>/
tests/integration/<vertical>/                          # when integration tests apply

docs/verticals/<vertical>.md                           # the canonical document of the vertical
```

The slug is the coordinate that makes a vertical findable in one filesystem search. `find . -type d -name healthcare` should return every directory belonging to that vertical, and `find . -type d -name healthcare | xargs ls` should give a complete inventory.

### 4.1 Slug rules

- Lowercase ASCII only.
- Underscores, not hyphens.
- One word where possible; if two are unavoidable, joined by underscore.
- Reserved slugs (used or planned): `aviation`, `fintech`, `healthcare`, `pharma`, `aviation_defense`, `employment`, `ecommerce`.

### 4.2 The Cypher seed is generated, not hand-written

`seed.cypher` is the output of `ragf compile <vertical>.yaml`. It is committed to the repository for reproducibility and so a fresh Neo4j can be seeded without re-running the compiler, but it is **not** the artifact a contributor edits. Any change to a vertical's ontology happens in the YAML; the Cypher is regenerated.

This is enforced by convention, not yet by tooling. A future CI check (`ragf verify-compile`) will ensure that the committed `seed.cypher` matches what `ragf compile` would produce from the current YAML. Until that exists, manual discipline applies.

---

## 5. Pre-gates

Some verticals — typically those with regulated data access regimes or non-delegable professional acts — require **pre-gates**: deterministic checks that run before the main Validation Gate evaluation chain. They are distinct from validators in the parallel bundle: pre-gates run sequentially, *before* the verb is matched against the ontology.

A pre-gate is the right structure when the answer to one of these questions is yes:

- Does the access to data, independent of any action, trigger regulatory obligations? (→ data category pre-gate)
- Does a class of verbs require active credential verification against an external registry, not just role assignment? (→ credential pre-gate)
- Does the vertical's regulatory stack admit multiple simultaneously active norms with non-linear precedence? (→ precedence resolution; typically not a pre-gate but a layer over constraint evaluation)

Pre-gates live in `gateway/pregates/<vertical>/`. They are loaded by the `decision_engine` based on `action.domain` and executed in declared order before FASE 1 (semantic validation). Each pre-gate respects the same fail-closed contract as the rest of the gate: any error, timeout, or external dependency failure yields `DENY`.

Verticals without pre-gates (e.g., aviation, fintech today) do not have the directory at all. Its absence is informative: it declares that the vertical's regulatory stack does not require pre-execution gates beyond the standard validation chain.

---

## 6. Risk vocabulary: separation of axes

In conformance with `docs/AMM.md` §6, RAGF treats three risk axes as semantically distinct. The same words may not be reused across axes.

| Axis | Lives in | Values | Example field |
|---|---|---|---|
| **Maturity risk** | `MaturityLevel.risk_tier` | `very_low`, `low`, `high`, `very_high`, `extreme` | (in `schema.cypher`) |
| **Action risk** | the YAML verb `risk_level` | `low`, `medium`, `high`, `critical` | `verbs[].risk_level` |
| **Audit criticality** | the auditor's CC-08 gradient | (operator-internal) | enforced by `cc08_authority_gradient.cypher` |

The collision between the maturity-risk tier `CRITICAL` (assigned to AMM L3 in the current `schema.cypher`) and the action-risk level `critical` (assigned to high-stakes verbs) is **known and declared as debt**: see `docs/AMM.md` §6. Until resolved, references to "critical" in cross-component reasoning must qualify the axis.

### 6.1 Forbidden values

- `decision_if_violated: ALLOW` is **never** valid in a YAML constraint. The auditor's CC-09 rejects it. Fail-closed semantics permit `DENY` and `ESCALATE` as outcomes; an `ALLOW` constraint is a contradiction in terms.
- `risk_level` and `risk_tier` must not be confused in the same artifact. The YAML uses `risk_level` for verbs; the Neo4j level node uses `risk_tier` (after the rename declared as debt in `docs/AMM.md`).

---

## 7. The CLI surface (v1.0)

Three subcommands ship in v1.0. The scope is deliberately tight: the framework guarantees topology and compilation before extending to runtime deployment.

```
ragf audit <yaml>            # CC-01..CC-11 against ephemeral Neo4j sandbox
ragf compile <yaml>          # deterministic YAML → Cypher seed
ragf validate <yaml>         # compile + smoke-test against local staging Neo4j
```

### 7.1 `ragf audit`

Wraps the existing `harness_auditor`. Loads the YAML into a disposable Neo4j sandbox, evaluates each of CC-01 through CC-11, emits an HMAC-signed report. Optional `--attest` produces an Ed25519-signed attestation bundle.

Exit codes are deliberately granular so a CI pipeline can act on each class without parsing stdout:

| Code | Meaning | Action expected from CI |
|------|---------|-------------------------|
| `0` | `PASSED` — all blocking CCs pass | proceed to compile |
| `1` | `REQUIRES_REVIEW` — advisory CCs flag issues; blocking CCs pass | proceed with caution; surface report to reviewer |
| `2` | `FAILED` — at least one blocking CC fails | halt; require ontology author to address findings |
| `3` | infrastructural error (sandbox unreachable, Neo4j start failed, network) | halt and retry; do not interpret as ontology problem |
| `4` | schema version incompatible — CLI does not support the YAML's `schema_version` | halt; point user to compatibility matrix (§8) |
| `5` | schema malformed — YAML is syntactically invalid, missing required fields, or uses removed legacy spellings (e.g. `min_amm_level` under v2.0) | halt; require ontology author to fix YAML structure |

Codes 4 and 5 are intentionally distinct because they imply different remediations: code 4 means *the YAML is valid but you need a different CLI version*; code 5 means *the YAML itself needs editing*. A CI pipeline that conflates them would point the user to the wrong fix.

Code 3 is the fail-closed signal for transient infrastructure issues and is the only code on which automatic retry is appropriate. Any other non-zero code is a hard failure that requires human action.

### 7.2 `ragf compile`

Reads a `schema_version: "1.x"` YAML and emits a Cypher seed. Deterministic: same YAML in, same Cypher out, byte-identical. This is what makes the future CI check `ragf verify-compile` possible.

Output goes to `gateway/ontologies/<vertical>/seed.cypher` by default; `--output <path>` overrides.

**Compilation requires proof of prior audit.** By default, `ragf compile <yaml>` looks for an Ed25519-signed attestation bundle produced by a previous `ragf audit --attest` run over the same YAML. The bundle must:

1. Be signed by a key the CLI trusts (configured via `RAGF_TRUSTED_KEYS` or `--trusted-key`).
2. Reference the YAML by content hash (SHA-256), so a modified YAML invalidates the bundle.
3. Carry a `PASSED` or `REQUIRES_REVIEW` outcome on blocking CCs.

Lookup order for the bundle:

1. Explicit: `--attestation <path>`.
2. Conventional: a sibling file named `<yaml>.attestation` in the same directory.
3. Cache: the user's local attestation cache (`~/.ragf/attestations/`), keyed by YAML hash.

If no valid bundle is found, compilation refuses with exit code `2` (FAILED) and the message *"No valid audit attestation for `<yaml>` (hash `<sha256>`). Run `ragf audit --attest` first, or pass `--re-audit` to audit inline."*

**The `--re-audit` flag** bypasses the bundle requirement by running `ragf audit` inline against an ephemeral sandbox, gating compilation on the result. This is the convenience path for local development and is **not recommended for CI/CD**: a CI pipeline should explicitly orchestrate `audit --attest` followed by `compile`, so the attestation bundle is itself a CI artifact and the chain of custody is visible in the pipeline log.

The rationale is architectural: the chain `YAML → audit → compile → seed.cypher` is itself a signed pipeline. Each step produces a signed artifact consumed by the next. Compilation without prior audit would break the chain and produce a Cypher seed whose provenance is not verifiable. The default behaviour preserves the chain; `--re-audit` is an explicit, opt-in convenience that does not weaken the contract for anyone using the framework as intended.

This positions RAGF cleanly against the broader question reviewers and integrators will ask: *can your tool prove that what it deployed is what was approved?* Yes — the attestation bundle is the proof, and `ragf compile` refuses to operate without it.

### 7.3 `ragf validate`

Composes `compile` with a smoke test: loads the freshly compiled Cypher into a local Neo4j (started via the bundled docker-compose), runs a minimal verdict cycle against a representative action, asserts the verdict is returned within the latency budget and that the audit chain is intact.

Useful for local development and for CI gates. Not a substitute for full integration tests of the gateway, which remain in `tests/integration/<vertical>/`.

### 7.4 What is NOT in v1.0

- `ragf deploy` (push to a running gateway) — planned for v1.1.
- `ragf serve` (run the gateway from the CLI) — planned for v1.1.
- `ragf diff` (semantic diff between YAML versions) — planned for v1.2.

The v1.0 scope guarantees that an integrator can author, certify, and prepare an ontology. Deployment to production runtime is handled by the gateway's own deployment process (Docker, CI/CD) and is intentionally out of CLI scope until topology and compilation are proven stable.

---

## 8. Compatibility matrix

Stable contract between CLI versions and YAML schema versions:

| CLI version | YAML schema versions accepted | Notes |
|---|---|---|
| v1.0.x | 1.0 | initial release |
| v1.1.x | 1.0, 1.1 | additive YAML extensions |
| v2.0.x | 2.0, with `--legacy-1.x` opt-in for 1.x | breaking change in schema |

A YAML opened by a CLI that does not support its schema version exits with code `4` (incompatible schema) and points the user to the version that does.

### 8.1 Gateway compatibility

The Cypher format produced by `ragf compile` is versioned via a header comment:

```cypher
// RAGF Cypher Seed v1.0 — compiled from <vertical>.yaml v<vertical_version>
// CLI: ragf v1.0.3
// Generated: <ISO-8601>
```

The gateway declares the Cypher format versions it accepts in its `/health` response. Cypher seeds with a format version newer than the gateway supports are rejected by the gateway on load, fail-closed.

---

## 9. Engine assumption

**RAGF v1.x assumes Neo4j 5.x as the official graph engine for ontology integrity and audit guarantees.**

This is a deliberate scoping decision. Guaranteeing deterministic graph execution across Neo4j, Memgraph, and a hypothetical PostgreSQL graph extension simultaneously in v1.0 would dilute focus during the most critical phase of the framework's maturation.

### 9.1 Repository pattern as declared debt

The architecture isolates all Neo4j queries behind a repository layer. **Today, this pattern is partially implemented**: `gateway/neo4j_client.py` is directly coupled to `decision_engine`, and the abstraction boundary is informal. The repository pattern is **declared technical debt**, tracked for resolution alongside the broader saneamiento of the codebase (see §11).

When the repository layer is fully extracted, alternative engines may be implemented provided they pass the `harness_auditor` certification criteria against an identical reference YAML. Until that point, RAGF v1.x is Neo4j-only by contract.

### 9.2 What this means for an integrator

A vertical author writes against the YAML contract, not against Neo4j. The YAML schema (§3) does not expose Neo4j semantics. An author who never opens a Cypher file is operating correctly. The Neo4j dependency surfaces only at runtime, inside the gateway.

---

## 10. Adding a new vertical: checklist

For framework contributors and internal developers, the operational sequence to add a new vertical:

1. Choose the canonical slug (lowercase, underscored; reserve it in §4.1).
2. Author `<vertical>.yaml` at `schema_version: "1.0"`. Start from `gateway/ontologies/fintech/fintech_minimal.yaml` (once that is migrated; see §11) or from the auditor's `examples/fintech_minimal.yaml`.
3. Run `ragf audit <vertical>.yaml`. Iterate until all blocking CCs pass.
4. Run `ragf compile <vertical>.yaml`. Commit the generated `seed.cypher` alongside the YAML.
5. Implement vertical-specific validators under `gateway/validators/<vertical>/`. Each validator gets a `*_validator.py` module and an entry in the vertical's README.
6. If the vertical requires pre-gates (see §5), implement them under `gateway/pregates/<vertical>/` and register them in `decision_engine` for the `action.domain` slug.
7. Write `docs/verticals/<vertical>.md`: regulatory scope, AMM levels exercised, pre-gates declared, known limitations.
8. Write `tests/unit/<vertical>/` and, where integration applies, `tests/integration/<vertical>/`. The auditor's `examples/<vertical>_seeded_faults.yaml` pattern is encouraged for negative tests.
9. Update this document's §4.1 reserved slugs and the project's main README with the new vertical's status.

A vertical that completes steps 1–9 is **a RAGF-certified vertical**. A vertical that completes only steps 1–4 is **a candidate vertical** and should be documented as such.

---

## 11. Declared debt

The following items are known deficits between this document's normative position and the current state of the repository. They are tracked, not ignored.

| ID | Debt | Affects | Resolution path |
|---|---|---|---|
| VS-D1 | `aviation_seed.cypher` is a flat file with no corresponding YAML and was never audited. | `gateway/ontologies/aviation_seed.cypher` | Migrate to `gateway/ontologies/aviation/aviation.yaml`, run `ragf audit`, regenerate `seed.cypher`. Scheduled for post-fintech consolidation. |
| VS-D2 | `gateway/ontologies/fintech/` is an empty directory; the canonical fintech YAML lives in `harness_auditor/examples/`. | fintech vertical | Move or copy `fintech_minimal.yaml` to `gateway/ontologies/fintech/fintech.yaml` as the canonical fintech contract. |
| VS-D3 | `harness_auditor` uses `min_amm_level` and `REQUIRES_AMM`; the canonical names are `required_amm_level` and `REQUIRES_AMM_LEVEL`. | auditor + aviation seed | Migrate auditor schemas and Cypher queries; introduce deprecation warnings for the legacy spellings during the transition window. |
| VS-D4 | Repository pattern for Neo4j access is informal: `gateway/neo4j_client.py` is directly coupled to `decision_engine`. | engine pluggability | Extract a `NeoRepository` protocol; refactor `decision_engine` to depend on the protocol; introduce a `Neo4jRepository` concrete implementation. |
| VS-D5 | `src_v2/` is marked "Legacy code under deprecation review" in `pyproject.toml` but still present. | code organisation | Delete `src_v2/` and remove it from `pyproject.toml` exclude lists. |
| VS-D6 | Monorepo destination (single `[project]` block in root `pyproject.toml`, `src/ragf/` layout with `auditor`, `compiler`, `cli` as modules) is not yet realised. | distribution | Add `[project]` and `[build-system]` to root `pyproject.toml`. Consolidate `harness_auditor/src/harness_auditor/` under `src/ragf/auditor/`. Create `src/ragf/compiler/` and `src/ragf/cli/`. |
| VS-D7 | `ragf verify-compile` CI check does not exist; YAML→Cypher consistency relies on contributor discipline. | reproducibility | Implement as a CI hook once `ragf compile` is stable. |

Each item should reference a tracked issue in the repository's issue system. Items resolve in the order above unless dependencies force otherwise: VS-D6 must precede VS-D4 cleanly; VS-D2 unblocks the fintech vertical's compliance with §10; VS-D1 unblocks aviation's.

---

## 12. Conformance checklist for the next vertical

Before opening a PR that adds a vertical, verify:

- [ ] Canonical slug chosen and reserved in §4.1.
- [ ] YAML authored at `schema_version: "1.0"` using canonical field names (`required_amm_level`, not `min_amm_level`).
- [ ] `ragf audit` returns `PASSED` on all blocking CCs.
- [ ] `ragf compile` produces a `seed.cypher` matching what the gateway expects.
- [ ] All five directory footprints (§4) are present where applicable; absences are intentional and documented.
- [ ] Pre-gates either implemented under `gateway/pregates/<vertical>/` or declared as not required in the vertical's README.
- [ ] Risk vocabulary respects the axis separation of §6.
- [ ] `docs/verticals/<vertical>.md` exists and documents AMM coverage, regulatory scope, and known limitations.
- [ ] Tests cover the verdicts the auditor cannot — runtime behaviour, validator logic, pre-gate behaviour under degraded conditions.
- [ ] AMM coverage statement is honest: if only L2–L4 are exercised, the vertical's README says so (per `docs/AMM.md` §7).

A vertical meeting this checklist is the contractually correct way to extend RAGF.
