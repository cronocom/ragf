// ============================================================================
// CC-09 · Fail-Closed Defaults  (pure Cypher · single statement)
// ============================================================================
//
// Any constraint with `decision_if_violated = 'ALLOW'` inverts the
// governance semantic: the rule becomes a permission instead of a
// restriction. The Pydantic ontology schema already rejects `ALLOW` at YAML
// load time (the `Decision` enum exposes only `ESCALATE` and `DENY`), so
// this CC exists to catch drift introduced *after* schema validation —
// e.g., a CI job that writes constraints directly via Cypher, an operator
// editing through the Neo4j Browser, or an APOC import bypassing the
// loader.
//
// Mechanism : pure Cypher pattern match.
// Severity  : CRITICAL — semantically inverts the harness verdict.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology (loaded through the auditor's loader):
//     []                              -- status = PASS
//
// After a drifted CREATE bypassing the schema:
//     [
//       { constraint: "rogue_allow_constraint",
//         verb: "transfer_funds",
//         regulation: "PSD2_ART97_SCA",
//         decision_if_violated: "ALLOW" }
//     ]
// ============================================================================

MATCH (c:Constraint)-[:HAS_CONSTRAINT_OF]->(v:Verb)
WHERE c.decision_if_violated = 'ALLOW'
RETURN c.name                  AS constraint,
       v.name                  AS verb,
       c.regulation            AS regulation,
       c.decision_if_violated  AS decision_if_violated
ORDER BY c.name;
