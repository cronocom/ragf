# ADR-002 · Monorepo as the Default Layout for RAGF Components

- **Status**: Accepted
- **Date**: 2026-06-12
- **Decider**: Yamil Rodríguez Montaña (Founder & Managing Partner, Reflexio)
- **Consulted**: Adversarial review across three RAGF v2.4 iterations and
  the harness_auditor v0.1.0 → v0.2.0 release cycle.

---

## Context

The RAGF project ships several related but operationally independent
components:

| Component | Role | Lifecycle independence |
|---|---|---|
| `papers/` | Academic publication (LaTeX + PDF) | Versioned by paper revision (v2.3, v2.4, …) |
| `gateway/` | Runtime Validation Gate (FastAPI service) | Versioned by service release |
| `ragf_core/` | Extended analysis modules (escalation, governance, state) | Co-versioned with the gateway today |
| `harness_auditor/` | Pre-deployment structural certification (CLI + library) | Independently versioned (v0.2.0 as of this ADR) |
| `benchmark/` | Empirical experiments cited by the paper | Frozen artefacts (re-runnable) |
| `shared/` | Cross-component models and contracts | Co-versioned with the monorepo |

These components are not equally mature, not equally consumed downstream,
and not equally fast-moving. They share, however, a single conceptual
spine: the RAGF thesis that governance harnesses — not the LLMs they
wrap — are the certifiable layer.

The question is whether they should live in a single git repository or
be split into independent repositories.

---

## Decision

**The RAGF components live in a single monorepo at `github.com/cronocom/ragf`** (currently `cronocom/rafg`, rename pending), with the following conventions:

1. **Component-prefixed tags**. Releases are tagged as
   `<component>-vX.Y.Z`:
   - `harness-auditor-v0.3.0` for the next auditor release.
   - `gateway-v1.0.0` if and when the runtime is cut as a release.
   - The first auditor release, `v0.2.0`, predates this convention and
     stays without prefix. The convention applies prospectively.
2. **Per-component CHANGELOGs**. Each component owns its own
   `CHANGELOG.md` (cf. `harness_auditor/CHANGELOG.md`). The repo root
   has no aggregate CHANGELOG.
3. **Shared tooling, not shared packaging**. The root `pyproject.toml`
   defines shared ruff / mypy / pytest configuration (cf. ADR-002 §
   pyproject decision). It does NOT declare the monorepo as an
   installable Python distribution. Each component carries its own
   packaging metadata if it is intended to be installable.
4. **Per-component Makefiles delegated from a root orchestrator**.
   `make test-auditor` at the root delegates to
   `make -C harness_auditor test`. The root Makefile does not duplicate
   per-component logic.
5. **Future contract layer**. When the cross-component ontology contract
   is introduced (see § Future work), it lives in `shared/` and is
   imported by both `gateway/` and `harness_auditor/`. Drift between
   consumers is detected by CI, not by good intentions.

---

## Consequences

### Positive

- **Coherence**. Reviewers of the AIES 2026 paper can navigate from
  paper to runtime to auditor to benchmark in one repo. A reader who
  arrives via the paper finds the operational artefacts; a reader who
  arrives via the auditor's release page finds the paper.
- **Atomic cross-component changes**. A change that requires both
  `gateway/` and `harness_auditor/` to move in lock-step lands as one
  PR, not as a coordination dance across repos.
- **One source of truth for the shared contract**. The Pydantic models
  in `shared/` (and the future ontology schema contract) are imported by
  both consumers; there is no version-skew risk that exists in split
  repos.
- **Lower governance overhead**. One issue tracker, one Discussions
  forum, one CI provider, one access-control surface.

### Negative

- **Cross-component noise in the issue tracker**. An issue specific to
  the auditor and an issue specific to the runtime share a tracker.
  Mitigated by labels / area tags (e.g. `area:auditor`, `area:runtime`).
- **CI cost concentration**. A single CI provider account budgets the
  minutes for the whole repo. If runtime integration tests become
  expensive, they compete with auditor tests for the same budget.
  Mitigated by path-filtered CI workflows (Fase B / C of the cleanup).
- **Confusion about what is "the project"**. Downstream consumers may
  not know whether they want `pip install harness-auditor` (a slice) or
  the whole monorepo (the runtime stack). Mitigated by the README at
  the repo root distinguishing the components explicitly.
- **Discoverability cost for the auditor**. Someone who finds the
  monorepo via the paper may not realise that the auditor is also a
  releasable, installable, citable artefact in its own right. Mitigated
  by the auditor's own GitHub Release pages and the README distinction.

### Neutral / accepted

- The monorepo is the right answer **today**, when the components are
  young and the design is still evolving. It may not be the right
  answer **tomorrow** — see § Trigger conditions for re-evaluation.

---

## Rejected alternative · Independent repositories per component

The alternative considered was splitting into:

- `github.com/cronocom/ragf-paper`
- `github.com/cronocom/ragf-gateway`
- `github.com/cronocom/harness-auditor`
- `github.com/cronocom/ragf-benchmark`

**Why this was rejected for now**:

- The harness_auditor is one week old as a public release. Adoption is
  measured in tens of users, not thousands. Splitting prematurely
  optimizes for an audience that does not yet exist.
- The shared ontology contract (Fase C work) is not yet articulated.
  Splitting before that contract exists locks two repos into a
  version-skew problem that the contract is specifically designed to
  prevent.
- The paper and the auditor coevolve. As long as the auditor's
  empirical results (the benchmark, the 11 CCs taxonomy) inform the
  paper and the paper informs the auditor's design, they belong in
  the same place.

**This rejection is not permanent.** See § Trigger conditions.

---

## Trigger conditions for re-evaluation

This decision should be revisited if any of the following becomes true:

1. **The harness_auditor reaches ≥50 GitHub stars or ≥10 unique
   downstream consumers** (PyPI installs, conference adopters,
   citations from non-author work). At that scale, the operational
   benefits of a dedicated repo (cleaner issue tracker, focused
   discussions, independent CI budget) start to outweigh the coherence
   benefits of a monorepo.
2. **The release cadence of the auditor and the runtime diverge by
   more than 6 months**. If one component ships quarterly and the
   other ships annually, the monorepo's atomic-change benefit is
   no longer being exercised.
3. **The shared ontology contract becomes stable and rarely changes**.
   Once the contract is at v2.0+ and frozen across multiple consumer
   versions, the version-skew risk of a split repo is no longer
   prohibitive.
4. **A second auditor maintainer joins** and the cross-component
   review burden becomes a coordination bottleneck for one of the
   two consumer codebases.

When any two of these conditions are met simultaneously, this ADR
should be revisited. The expected outcome at that point is a documented
split with redirects, deprecation paths, and a migration window of at
least one release cycle.

---

## Implementation notes (Fase A of the cleanup, June 2026)

The conventions in § Decision are implemented across these files:

| Convention | Implementation |
|---|---|
| Root `pyproject.toml` as tooling hub | [`pyproject.toml`](../../pyproject.toml) |
| Root `Makefile` as orchestrator | [`Makefile`](../../Makefile) |
| Per-component CHANGELOG | [`harness_auditor/CHANGELOG.md`](../../harness_auditor/CHANGELOG.md) (canonical example) |
| Component-prefixed tags | Prospective from `harness-auditor-v0.3.0` onwards |
| Benchmark as its own component | [`benchmark/README.md`](../../benchmark/README.md) |

---

## Related decisions

- [`harness_auditor/docs/decisions/ADR-001-gds-scope.md`](../../harness_auditor/docs/decisions/ADR-001-gds-scope.md)
  — Why GDS is scoped to CC-11 only within the auditor. Pre-dates this
  ADR and is unaffected by the monorepo decision.

## Future work (referenced from this ADR)

- **Ontology contract layer** (`shared/ontology_contract/`). Planned
  for the Fase C cleanup. Will be the subject of its own ADR-003 once
  the design is settled.
- **Path-filtered CI workflows**. Planned for Fase B. Will be tracked
  in a CI-specific ADR or noted in the workflow files themselves.
- **TestPyPI / PyPI publication of the harness_auditor**. Pending a
  decision on long-term maintenance commitment; expected once the
  auditor reaches v0.5.0 or accrues external contributors.
