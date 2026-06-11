// ============================================================================
// CC-06 · Coverage Map  (pure Cypher · single statement)
// ============================================================================
//
// Per-verb regulatory coverage. For each verb that declares one or more
// `MUST_SATISFY` regulations, compute:
//
//     coverage = (#declared regulations with ≥1 enforcing constraint on this verb)
//                / (#declared regulations)
//
// A verb whose coverage falls below the hard-coded threshold (0.85, matching
// the AgentSave dictionary default) is reported, along with the regulation
// codes it failed to cover so the operator can write the missing constraint
// or remove the spurious MUST_SATISFY edge.
//
// Verbs with zero declared MUST_SATISFY are not reported here; they belong
// to CC-01 (Verb Groundedness) instead.
//
// Mechanism : pure Cypher aggregate with OPTIONAL MATCH.
// Severity  : MEDIUM. Advisory.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology (every verb covered):
//     []                              -- status = PASS
//
// `transfer_funds` declares 3 regulations, only 2 of which have a referencing
// constraint:
//     [
//       { verb: "transfer_funds",
//         declared_count: 3,
//         matched_count: 2,
//         coverage: 0.6666...,
//         uncovered: ["BANK_INTERNAL_POLICY_01"] }
//     ]
// ============================================================================

MATCH (v:Verb)-[:MUST_SATISFY]->(r:Regulation)
OPTIONAL MATCH (v)<-[:HAS_CONSTRAINT_OF]-(c:Constraint)-[:REFERENCES]->(r)
WITH v, r, count(c) > 0 AS is_covered
WITH v,
     count(r) AS declared_count,
     count(CASE WHEN is_covered THEN 1 END) AS matched_count,
     collect(CASE WHEN NOT is_covered THEN r.code END) AS uncovered_raw
WITH v,
     declared_count,
     matched_count,
     [code IN uncovered_raw WHERE code IS NOT NULL] AS uncovered,
     toFloat(matched_count) / toFloat(declared_count) AS coverage
WHERE coverage < 0.85
RETURN v.name        AS verb,
       declared_count,
       matched_count,
       coverage,
       uncovered
ORDER BY coverage, v.name;
