# Neo4j vs PostgreSQL · Validation Latency Benchmark

Empirical comparison of two storage backends for the RAGF Semantic
Authority Layer, measured at constant workload over a controlled dataset.

This benchmark was run in February 2026 to inform the architectural choice
of Neo4j as the substrate for the RAGF runtime gate (`gateway/`) and for
the pre-deployment auditor (`harness_auditor/`). The full write-up is in
[`RAGF_Neo4j_Article_FINAL_2.docx`](RAGF_Neo4j_Article_FINAL_2.docx).

---

## What this measures

For two equivalent ontology representations — one graph-native (Neo4j),
one relational with normalized tables (PostgreSQL) — we measure the
end-to-end latency of validation queries that the RAGF Validation Gate
issues on every action proposal.

Concretely, three categories of query are timed:

1. **Verb groundedness lookup** — does this verb have a `MUST_SATISFY`
   edge to a regulation? (CC-01 equivalent.)
2. **Constraint reachability** — given an action's parameter, is there a
   constraint that governs it? (CC-02 equivalent.)
3. **Authority gradient resolution** — what is the minimum AMM level
   required for this verb given its risk class? (CC-08 equivalent.)

These three queries cover the dominant latency contributors of the
runtime gate. Other CCs (cycles, centrality, drift) are NOT in this
benchmark because they execute at audit time, not at runtime — the gate
serves traffic; the auditor certifies the harness before traffic starts.

---

## Headline results

| Query class | Postgres p50 | Neo4j p50 | Speedup (raw) | Both within RAGF gate? |
|---|---|---|---|---|
| Verb groundedness | ~0.8 ms | ~3.5 ms | Postgres 4.4x faster | ✓ both sub-30 ms |
| Constraint reachability | ~1.1 ms | ~4.2 ms | Postgres 3.8x faster | ✓ both sub-30 ms |
| Authority gradient | ~0.7 ms | ~4.0 ms | Postgres 5.8x faster | ✓ both sub-30 ms |

**Reading the numbers**: Postgres is faster in absolute terms on these
three query classes. Both backends operate well within the 30 ms p95 RAGF
gate budget documented in [`papers/RAGF_v2_5.pdf`](../papers/RAGF_v2_5.pdf).

See [`results/benchmark_results.json`](results/benchmark_results.json) for
the raw per-iteration timings and
[`results/scale_benchmark_results.json`](results/scale_benchmark_results.json)
for the scale-test data (500 verbs / 200 regulations, seed=42).

---

## Why Neo4j is still the choice

The runtime latency cost of Neo4j is real. The decision to use Neo4j is
made *despite* that cost, for reasons the benchmark does NOT measure but
that govern the categorical choice:

- **Pre-deployment certification is the bottleneck for adoption in
  regulated industries, not runtime latency.** Postgres can answer
  "does this verb satisfy this regulation?" faster than Neo4j; neither
  can answer "are there `SUPERSEDES` cycles in this entire ontology" or
  "which constraints are central enough that an edit cascades over the
  graph?" without a graph-native engine. The 11 Certification Criteria
  documented in
  [`harness_auditor/docs/CRITERIA.md`](../harness_auditor/docs/CRITERIA.md)
  include four (CC-02 cross-pattern, CC-04 cycles, CC-07 set-difference
  drift, CC-11 PageRank centrality) that are awkward or impossible to
  express in pure SQL at any reasonable performance.
- **Both backends are well within the RAGF latency budget** (p95 < 30 ms).
  Postgres being faster in raw latency does not translate to operator-
  observable improvements once the full validation pipeline is included
  (HMAC signing, audit ledger write, escalation routing).
- **A single storage substrate** for both runtime enforcement and
  pre-deployment certification simplifies the operational footprint:
  one schema, one set of ontology constraints, one DBA skillset. A
  split-stack (Postgres for runtime, Neo4j for the auditor) doubles
  this footprint with no measured win.

The honest summary: **Postgres would win on this dimension if pre-
deployment structural certification were not part of the architecture.**
The architecture explicitly includes it (cf. paper § 1 + harness_auditor
v0.2.0), so the trade-off lands in Neo4j's favour.

---

## How to reproduce

### Prerequisites

- Docker + Docker Compose (for the Neo4j and PostgreSQL containers)
- Python 3.11+
- Install runtime requirements: `make install` from the repo root

### Steps

```bash
cd /Users/ianmont/Dev/ragf     # repo root

# Bring up both backends (this assumes docker-compose.yml has services
# for both neo4j and a postgres instance; if Postgres is not declared
# yet, see the "Adapting the benchmark" section below).
make up

# Load the PSD2-derived baseline ontology + the synthetic scale dataset
python3 benchmark/ontology/psd2_data.py            # PSD2 baseline (17 v / 7 r / 5 c)
python3 benchmark/ontology/scale_generator.py      # Scale (500 v / 200 r, seed=42)

# Run the benchmarks
python3 benchmark/queries/run_benchmark.py         # Baseline benchmark (1,000 iterations/query)
python3 benchmark/queries/run_scale_benchmark.py   # Scale benchmark

# Regenerate the figures
python3 benchmark/queries/plot_results.py

# Tear down when done
make down
```

Total wall-clock time on a recent macOS laptop: ~12 minutes (3 min
container start + 8 min benchmark + 1 min plotting).

The figures land in `benchmark/results/`:
- [`fig1_baseline_latency.png`](results/fig1_baseline_latency.png) —
  per-query latency comparison at baseline (17 v / 7 r / 5 c).
- [`fig2_scale_complexity.png`](results/fig2_scale_complexity.png) —
  how each backend scales as the ontology grows.
- [`fig3_summary_table.png`](results/fig3_summary_table.png) —
  consolidated summary including p50 / p95 / p99.

### Adapting the benchmark

The benchmark code is in `benchmark/queries/`. It is parameterized for
ontology size and iteration count via the CLI (`--n-iterations`,
`--seed`); see `--help` on each script. Adapting it to a different
ontology requires implementing two methods on the loader interfaces:
`load_ontology()` and `query_class(name)` — see `ontology/neo4j_loader.py`
and `ontology/postgres_loader.py` for the canonical implementations.

---

## Relationship to the rest of the monorepo

This benchmark feeds into two artefacts of the monorepo:

- **The paper** ([`papers/RAGF_v2_5.pdf`](../papers/RAGF_v2_5.pdf))
  cites these numbers when justifying the choice of Neo4j for the RAGF
  Semantic Authority Layer.
- **The harness_auditor** ([`harness_auditor/`](../harness_auditor/))
  inherits the same backend choice. The benchmark numbers here are part
  of the rationale for why structural certification — and the eleven CCs
  in particular — is implemented in Cypher on Neo4j rather than as a
  SQL-based linter.

---

## Honest limitations

- The benchmark times three query classes. The full RAGF gate executes
  many more (authority chains, escalation routing, audit signature). The
  numbers here are the dominant contributors but NOT the complete cost.
- The scale test goes to 500 verbs / 200 regulations. Production fintech
  ontologies on the order of 5,000 verbs / 1,500 regulations are NOT in
  this benchmark; the trend should hold but is unverified at that scale.
- Both backends run in unloaded Docker containers on a laptop. Production
  cloud-hosted instances with concurrent traffic will behave differently;
  the *ratios* should remain comparable, the *absolutes* will not.
- The query plans are at the mercy of the respective optimizers. The
  Postgres queries were hand-tuned with `EXPLAIN ANALYZE`; the Cypher
  queries rely on Neo4j's default planner. Neither set was systematically
  tuned to the point of diminishing returns.
