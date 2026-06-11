// ============================================================================
// CC-05 · Precedence Collision  (pure Cypher · single statement)
// ============================================================================
//
// Two or more constraints attached to the same verb that share the same
// `precedence_level`. At runtime the evaluator's tie-breaking is
// implementation-defined; a tie therefore breaks determinism guarantees
// and the harness verdict becomes non-reproducible.
//
// Mechanism : pure Cypher aggregate (group by (verb, precedence_level)).
// Severity  : HIGH.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology:
//     []                              -- status = PASS
//
// Ontology with two constraints at precedence 90 on the same verb:
//     [
//       { verb: "transfer_funds",
//         precedence_level: 90,
//         collision_size: 2,
//         constraints: ["duplicate_precedence_rule", "high_amount_requires_sca"] }
//     ]
// ============================================================================

MATCH (c:Constraint)-[:HAS_CONSTRAINT_OF]->(v:Verb)
WITH v.name AS verb, c.precedence_level AS precedence_level, c.name AS constraint
  ORDER BY constraint
WITH verb, precedence_level, collect(constraint) AS constraints
WHERE size(constraints) > 1
RETURN verb,
       precedence_level,
       size(constraints) AS collision_size,
       constraints
ORDER BY verb, precedence_level;
