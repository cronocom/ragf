// ============================================================================
// CC-07 · Drift Delta  (pure Cypher · single statement)
// ============================================================================
//
// Detects constraints present in the previous ontology version but absent
// from the current one. A silently removed constraint is a regression in
// semantic coverage: the harness will quietly stop enforcing whatever rule
// the dropped constraint expressed.
//
// Requires that the previous ontology has been loaded via
// `loader.load_previous()` before the runner fires. Previous-version nodes
// carry the `Prev` suffix on every label (Domain → DomainPrev, etc.) so
// they coexist with the current graph without aliasing.
//
// When the auditor is invoked without `--previous`, the runner detects the
// absence of any `ConstraintPrev` node and SKIPs CC-07 entirely.
//
// Mechanism : pure Cypher set difference between Constraint and
//             ConstraintPrev, anchored on constraint name.
// Severity  : HIGH; escalates to CRITICAL when any removed constraint had
//             `decision_if_violated = 'DENY'` (a tightened gate was lifted).
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// No drift (current == previous in constraint identities):
//     []                              -- status = PASS
//
// `pep_requires_edd` was dropped in this version:
//     [
//       { removed_constraint: "pep_requires_edd",
//         verb: "transfer_funds",
//         prev_decision: "ESCALATE",
//         prev_severity: "high",
//         prev_regulation: "AMLD_ART18_EDD" }
//     ]
// ============================================================================

MATCH (c_prev:ConstraintPrev)-[:HAS_CONSTRAINT_OF]->(v_prev:VerbPrev)
WHERE NOT EXISTS { MATCH (c:Constraint {name: c_prev.name}) }
RETURN c_prev.name                  AS removed_constraint,
       v_prev.name                  AS verb,
       c_prev.decision_if_violated  AS prev_decision,
       c_prev.severity              AS prev_severity,
       c_prev.regulation            AS prev_regulation
ORDER BY c_prev.name;
