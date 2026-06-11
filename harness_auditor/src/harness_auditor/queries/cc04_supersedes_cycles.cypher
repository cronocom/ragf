// ============================================================================
// CC-04 · SUPERSEDES Cycles  (pure Cypher · single statement)
// ============================================================================
//
// Detects cycles in the SUPERSEDES relationship between constraints. A cycle
// is a governance contradiction: A overrides B, B overrides C, C overrides A.
// At runtime the evaluator would loop or pick an arbitrary order, neither of
// which is admissible under the deterministic-behaviour guarantees referenced
// in the RAGF v2.4 paper.
//
// Mechanism : pure Cypher. Variable-length pattern `(c)-[:SUPERSEDES*1..50]->(c)`
//             enumerates every path that returns to its starting constraint.
//             Cypher 5 enforces relationship-uniqueness within a pattern, so
//             each elementary cycle is matched exactly once per member node;
//             we then canonicalise the members (sorted) and DISTINCT to
//             collapse the redundant entries into a single row per cycle.
//             Self-supersedes (A → A) is also caught and reported as a
//             component of size 1.
//
// Severity  : CRITICAL — semantically inadmissible regardless of context.
//
// Bounds    : path length capped at 50. Any realistic governance ontology
//             whose SUPERSEDES graph contains a cycle longer than that has
//             pathologies CC-04 will not be the most useful symptom for.
//
// Pre-req   : none. Works on a vanilla Neo4j 5.x with no plugins.
//
// ----------------------------------------------------------------------------
// Why the canonicalisation works (rotational deduplication)
// ----------------------------------------------------------------------------
// A cycle A → B → C → A is matched THREE TIMES by the variable-length pattern,
// once per starting node — producing the cycles [A,B,C], [B,C,A], [C,A,B].
// All three are rotations of the same underlying cycle. We collapse them by
// sorting the members lexicographically and DISTINCT-ing:
//
//   `WITH cycle, member ORDER BY member` orders the row stream by member
//   name. The subsequent `collect(member)` preserves that order, so all
//   three groupings produce the IDENTICAL list `[A,B,C]`. `DISTINCT` then
//   drops the duplicates and we emit exactly one row per cycle.
//
// Editing this block is delicate: the order-preservation of `collect` after
// an `ORDER BY` is the entire correctness argument. Replace at your own risk.
// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology (examples/fintech_minimal.yaml):
//     []                              -- status = PASS
//
// Seeded-faults ontology (A → B → C → A):
//     [
//       { members: ["high_amount_emergency_rule",
//                   "pep_overrides_threshold",
//                   "threshold_baseline_rule"],
//         component_size: 3 }
//     ]
//     -- Status = FAIL, severity = CRITICAL.
// ============================================================================

MATCH path = (c:Constraint)-[:SUPERSEDES*1..50]->(c)
WITH [n IN nodes(path)[..-1] | n.name] AS cycle
UNWIND cycle AS member
WITH cycle, member ORDER BY member
WITH cycle, collect(member) AS sorted_members
RETURN DISTINCT
       sorted_members         AS members,
       size(sorted_members)   AS component_size
ORDER BY component_size DESC, members;
