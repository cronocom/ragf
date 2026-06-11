// ============================================================================
// CC-10 · Hallucinated Verbs  (pure Cypher · single statement)
// ============================================================================
//
// Detects verbs in the ontology that are not present in the registered
// taxonomy for the declared domain. A verb absent from the taxonomy is, by
// construction, unauthorised governance surface area: nothing in the upstream
// registry vouches for its existence, so the harness cannot certify it.
//
// The taxonomy is loaded via `loader.load_taxonomy()` and projected as
// `(:TaxonomyEntry {domain: <domain>, verb_name: <verb>})` nodes. When the
// auditor is invoked without `--taxonomy`, the runner detects the absence
// of any TaxonomyEntry node and SKIPs CC-10 entirely.
//
// Mechanism : pure Cypher set difference.
// Severity  : CRITICAL.
//
// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// Clean ontology against a complete taxonomy:
//     []                              -- status = PASS
//
// Ontology with `withdraw_emergency_cash` not in the taxonomy:
//     [
//       { verb: "withdraw_emergency_cash",
//         risk_level: "critical",
//         domain: "fintech_minimal" }
//     ]
// ============================================================================

MATCH (d:Domain)
MATCH (v:Verb)-[:BELONGS_TO]->(d)
WHERE NOT EXISTS {
  MATCH (t:TaxonomyEntry {domain: d.name, verb_name: v.name})
}
RETURN v.name        AS verb,
       v.risk_level  AS risk_level,
       d.name        AS domain
ORDER BY v.name;
