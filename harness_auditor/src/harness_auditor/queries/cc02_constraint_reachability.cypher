// ============================================================================
// CC-02 · Constraint Reachability
// ============================================================================
//
// Detects constraints that are declared but cannot be evaluated at runtime
// because the field they intend to check is not part of the corresponding
// verb's payload_schema (Field node connected to the Verb by HAS_FIELD).
//
// A "non-reachable" constraint is a silent governance gap: the harness loads
// it, the evaluator skips it (no payload field matches `parameter`), and the
// verdict is computed as if the rule did not exist. CC-02 surfaces that.
//
// Mechanism : pure Cypher; two-step pattern. First find the constraint and
//             its parameter; then assert that a corresponding Field exists
//             in the verb's payload.
// Severity  : HIGH. Constraints with severity=critical and result_if_violated
//             = DENY are escalated to CRITICAL.
//
// Note      : `required_field`-type constraints are excluded — for that type,
//             absence of the field IS the trigger, not a defect.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// On a clean ontology:
//     []                              -- status = PASS
//
// On the seeded-faults ontology:
//     [
//       { constraint: "high_amount_requires_sca",
//         verb:       "transfer_funds",
//         parameter:  "amount_eur",          -- field name in constraint
//         severity:   "high",
//         decision_if_violated: "ESCALATE",
//         expected_field_missing: "amount_eur"
//       }
//     ]
//     -- The seeded fault renames the payload field to `amount` while the
//     -- constraint references `amount_eur`, breaking reachability.
//     -- Status = FAIL, severity escalated based on (severity, decision).
// ============================================================================

MATCH (c:Constraint)-[:HAS_CONSTRAINT_OF]->(v:Verb)
WHERE c.type IN ['threshold', 'conditional_threshold', 'amm_level_check']
  AND c.parameter IS NOT NULL
  AND NOT EXISTS {
        MATCH (v)-[:HAS_FIELD]->(f:Field)
        WHERE f.name = c.parameter
      }
RETURN c.name                     AS constraint,
       v.name                     AS verb,
       c.parameter                AS parameter,
       c.severity                 AS severity,
       c.decision_if_violated     AS decision_if_violated,
       c.parameter                AS expected_field_missing
ORDER BY
  CASE c.severity
    WHEN 'critical' THEN 0
    WHEN 'high'     THEN 1
    WHEN 'medium'   THEN 2
    WHEN 'low'      THEN 3
    ELSE 4
  END,
  c.name;
