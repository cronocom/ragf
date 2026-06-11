// ============================================================================
// CC-08 · Authority Gradient  (pure Cypher · single statement)
// ============================================================================
//
// Each verb's `min_amm_level` must be monotonic with its `risk_level`:
//
//     risk_level   →   required min_amm_level
//     low                       ≥ 1
//     medium                    ≥ 2
//     high                      ≥ 3
//     critical                  ≥ 4
//
// A verb tagged `risk_level: critical` with `min_amm_level: 1` is
// structurally invalid: critical-class actions cannot be delegated to
// assisted-level agents. The mapping is the canonical RAGF v2.4 default;
// a domain that needs a different mapping should fork this query.
//
// Mechanism : pure Cypher with a CASE expression.
// Severity  : HIGH; escalates to CRITICAL when any offending verb has
//             `risk_level = 'critical'`.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology:
//     []                              -- status = PASS
//
// Verb `withdraw_emergency_cash` declared as critical with min_amm_level 2:
//     [
//       { verb: "withdraw_emergency_cash",
//         risk_level: "critical",
//         min_amm_level: 2,
//         required_min_amm: 4 }
//     ]
// ============================================================================

MATCH (v:Verb)
WITH v,
     CASE v.risk_level
       WHEN 'low'      THEN 1
       WHEN 'medium'   THEN 2
       WHEN 'high'     THEN 3
       WHEN 'critical' THEN 4
       ELSE 0
     END AS required_min_amm
WHERE v.min_amm_level < required_min_amm
RETURN v.name           AS verb,
       v.risk_level     AS risk_level,
       v.min_amm_level  AS min_amm_level,
       required_min_amm AS required_min_amm
ORDER BY required_min_amm DESC, v.name;
