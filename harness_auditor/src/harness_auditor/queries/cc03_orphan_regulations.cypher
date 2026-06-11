// ============================================================================
// CC-03 · Orphan Regulations  (pure Cypher · single statement)
// ============================================================================
//
// A regulation declared in the ontology but never REFERENCED by any constraint.
// Regulations marked `informational: true` are exempt — they may be cited for
// background context without being enforced by an executable rule.
//
// Mechanism : pure Cypher pattern match.
// Severity  : MEDIUM. Advisory — orphan regulations dilute coverage metrics
//             but do not directly break runtime behaviour.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology:
//     []                              -- status = PASS
//
// Ontology with an orphan regulation `BANK_INTERNAL_POLICY_01`:
//     [
//       { regulation: "BANK_INTERNAL_POLICY_01",
//         name: "Internal Policy 01",
//         celex: null }
//     ]
// ============================================================================

MATCH (r:Regulation)
WHERE NOT EXISTS { MATCH (:Constraint)-[:REFERENCES]->(r) }
  AND coalesce(r.informational, false) = false
RETURN r.code  AS regulation,
       r.name  AS name,
       r.celex AS celex
ORDER BY r.code;
