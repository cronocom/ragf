// ============================================================================
// CC-01 · Verb Groundedness
// ============================================================================
//
// Detects verbs that exist in the ontology but are not anchored to any
// regulation via a MUST_SATISFY edge. An ungrounded verb is a governance
// hallucination: the harness will accept actions of that verb without any
// regulatory reference to apply, defeating the certifiability claim.
//
// Mechanism : pure Cypher pattern match (no GDS required).
// Severity  : HIGH for production ontologies. The auditor escalates to
//             CRITICAL if the verb has min_amm_level >= 3 (i.e. the verb is
//             permitted at delegated autonomy levels without normative anchor).
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// On a clean ontology (e.g. examples/fintech_minimal.yaml):
//     []                              -- empty result set, status = PASS
//
// On the seeded-faults ontology (examples/fintech_seeded_faults.yaml):
//     [
//       { verb: "approve_internal_transfer",
//         risk_level: "high",
//         min_amm_level: 3,
//         requires_human_approval: false }
//     ]
//     -- Non-empty result. Status = FAIL.
//     -- Because min_amm_level >= 3, severity is escalated to CRITICAL.
// ============================================================================

MATCH (v:Verb)-[:BELONGS_TO]->(:Domain)
WHERE NOT (v)-[:MUST_SATISFY]->(:Regulation)
RETURN v.name                     AS verb,
       v.risk_level               AS risk_level,
       v.min_amm_level            AS min_amm_level,
       v.requires_human_approval  AS requires_human_approval
ORDER BY v.min_amm_level DESC, v.name ASC;
