# AMM — Agentic Maturity Model

**Canonical reference. This document is the single source of truth for the Agentic Maturity Model in RAGF.**

Version: 1.0 · Status: Canonical · Supersedes: scattered definitions in `docs/ARCHITECTURE.md`, inline enum comments, and ontology seed comments.

Whenever any artifact — code, ontology, paper, slide, or downstream vertical (RAGF-H healthcare, fintech, aviation) — refers to AMM levels, names, or the required-vs-granted distinction, it must conform to this document. Where another file disagrees with this one, this file wins and the other file is to be corrected.

---

## 1. Purpose

The Agentic Maturity Model (AMM) is a five-level scale that classifies the **autonomy granted to an agent class**. It is the authorization surface of the Validation Gate: every governed action carries a *required* AMM level, every agent carries a *granted* AMM level, and the gate authorizes the action only when the granted level meets or exceeds the required level.

The AMM replaces binary trust ("trusted / untrusted") with a graduated surface. Maturity here means the robustness of the governance scaffolding around an agent class, not the sophistication of its reasoning engine.

---

## 2. The five canonical levels

These names are canonical. They are defined in `shared/models.py` as `AMMLevel(IntEnum)` and instantiated as `MaturityLevel` nodes in `gateway/ontologies/schema.cypher`. **No other names are valid.** In particular, the names *Assisted / Supervised / Delegated / Autonomous / Adaptive* used in early RAGF-H drafts are NOT canonical and must be replaced by the names below.

| Value | Canonical name | One-line meaning | Risk tier (of the level) |
|------:|----------------|------------------|--------------------------|
| 1 | **Passive Knowledge** | Read-only queries; no execution. | VERY_LOW |
| 2 | **Human Teaming** | AI proposes; a human executes. | LOW |
| 3 | **Actionable Agency** | AI executes actions, each gated by the Validation Gate; only an `ALLOW` verdict permits commitment. | CRITICAL |
| 4 | **Autonomous Orchestration** | AI coordinates multiple sub-agents / actions under governance. | VERY_HIGH |
| 5 | **Full Systemic Autonomy** | Self-regulating system. | EXTREME |

The numeric values 1–5 are stable and must never change; downstream logic (`required_level <= granted_level`, the DPG conditions such as `agent_amm >= 3`) depends on the integers, not the names.

---

## 3. The semantics of L3 (binding definition)

L3 is the current target level for regulated deployment and the most frequently misdescribed. This definition is binding.

**An L3 (Actionable Agency) agent is authorized to *execute* actions — but every action passes through the Validation Gate, and the action is committed to a system of record only if the gate returns `ALLOW`.**

L3 is therefore *not* "the agent proposes and a human validates." That is L2 (Human Teaming). The distinction:

- **L2 Human Teaming:** the agent's output is a proposal; a *human* is the checkpoint that decides whether to execute.
- **L3 Actionable Agency:** the agent's output is an action; the *deterministic gate* is the checkpoint that decides whether it commits. No human is in the per-action loop; humans intervene only on `ESCALATE`.

This is consistent with the runtime: `gateway/decision_engine.py` emits a `Verdict` and never executes; execution is performed by the caller *after* receiving `ALLOW`. The gate is the authority over commitment, not the executor.

> **Correction required.** `docs/ARCHITECTURE.md` currently contains a description of L3 as "the agent proposes, the gate validates," which is the L2 semantics. That line must be corrected to the binding definition above. The section 1.1 framing in ARCHITECTURE.md ("conversational assistants at L2 → action-capable agents at L3") is already correct and should be kept.

---

## 4. Required vs. granted: the field that was overloaded

Two distinct quantities were historically both called `amm_level`. They are different and must be named differently.

| Concept | Canonical field name | Where it lives | Meaning |
|---|---|---|---|
| Level **granted** to an agent | `agent_amm_level` | the request / `Verdict` context | the autonomy this agent class is trusted with |
| Level **required** by an action | `required_amm_level` | the `Action` node in the ontology | the minimum autonomy an action demands |

**Authorization rule:** an action is AMM-authorized iff `required_amm_level <= agent_amm_level`.

Notes on current state (to be normalized — see §6):
- The API already uses the unambiguous `agent_amm_level` (`shared/models.py`). This is correct and is the model for the rest of the system.
- The field `amm_level` on `Verdict` currently means the *granted* level. It must be renamed `agent_amm_level` for consistency; the bare name `amm_level` is prohibited going forward because it does not say which of the two quantities it holds.
- `ActionPrimitive` does not carry the required level inline; the required level is resolved from the ontology. This is correct and should stay.

---

## 5. The Neo4j relationship: one name only

The relationship linking an action to its minimum maturity level has three spellings in the repository today. Only one is canonical.

| Spelling | Where seen | Status |
|---|---|---|
| `REQUIRES_AMM_LEVEL` | `docs/ARCHITECTURE.md`, `schema.cypher` schema block | **CANONICAL** |
| `REQUIRES_AMM` | `gateway/ontologies/aviation_seed.cypher` | deprecated → migrate |
| `min_amm_level` (property) | `harness_auditor` ontology schema | deprecated → migrate to `required_amm_level` |

Canonical pattern:

```cypher
(:Action {required_amm_level: 3})-[:REQUIRES_AMM_LEVEL]->(:MaturityLevel {value: 3})
```

The action property is `required_amm_level` (not `requires_amm`, not `amm_level`, not `min_amm_level`). The level node's numeric identity is `MaturityLevel.value`.

---

## 6. Risk vocabulary: three separate axes, three separate words

The word "critical" currently collides across three independent axes. They must never share a vocabulary, because in a clinical vertical a fourth meaning (clinical severity) will collide too.

| Axis | What it describes | Field | Example values | Owner |
|---|---|---|---|---|
| **Maturity risk** | how dangerous a *level* is | `MaturityLevel.risk_tier` | VERY_LOW … EXTREME | `schema.cypher` |
| **Action risk category** | the nature of an *action* | `Action.risk_category` | OPERATIONAL, SAFETY, INFORMATIONAL, STRATEGIC | ontology seeds |
| **Action criticality** | the audit gradient of an *action* | (auditor) | the auditor requires criticality≥L4 gradient | `harness_auditor` |

The known collision: the gateway marks the **L3 level** as `CRITICAL` (maturity risk), while the auditor's CC08 authority-gradient check states that a **critical action** requires at least L4 (action criticality). These are not in conflict once the axes are named apart — they are two different "criticals." Action: rename the `MaturityLevel` L3 risk tier away from the bare word `CRITICAL` (suggested: `HIGH` for the level, reserving `CRITICAL` for action criticality), or qualify both consistently (`level_risk: CRITICAL` vs `action_criticality: CRITICAL`). Until renamed, any cross-component reasoning over the word "critical" is ambiguous.

---

## 7. Operational coverage note

The five levels exist in the model. The reference runtime does not exercise all five uniformly.

- **L2, L3, L4 are assigned to actions** in the aviation ontology (`aviation_seed.cypher`): L2 for informational verbs (`query_weather`, `calculate_fuel_requirement`), L3 for gated operational acts (`reroute_flight`, `adjust_altitude`, `schedule_maintenance`), L4 for orchestration (`optimize_fleet_allocation`).
- **L1 and L5 are defined but not yet assigned** to any action in the current ontologies. L1 (read-only) and L5 (self-regulating) are part of the model for completeness and forward compatibility, but no production verb is mapped to them today.

Any paper or claim that validates "L1–L4" or "L1–L5" must state this honestly: the scale is five, the exercised range is L2–L4. RAGF-H must say the same when it spans "AMM levels 1–4."

---

## 8. Mapping to the published base paper's three operational modes

The published base paper (*RAGF: Boundary Enforcement…*, Zenodo) presents a three-mode operational taxonomy in its autonomy table: **Advisory**, **Supervised Autonomous**, **Fully Autonomous**. This is not a competing model and not a contradiction. It is a coarse operational framing that emphasizes the deployment frontier; the AMM is the fine-grained scale beneath it. The mapping:

| Base paper mode | AMM level(s) | Note |
|---|---|---|
| Advisory | L1–L2 | human is the checkpoint |
| Supervised Autonomous | **L3** | the gate is the checkpoint; RAGF's target |
| Fully Autonomous | L4–L5 | stronger guarantees than runtime validation alone |

Downstream papers (including RAGF-H) should reference the AMM five-level scale and, where helpful, note that L3 corresponds to the base paper's *Supervised Autonomous* mode. RAGF-H's five-level usage is thus consistent with the base paper, not an unexplained expansion of it.

---

## 9. Conformance checklist for any artifact citing AMM

Before committing code, an ontology seed, or a paper draft that references AMM, verify:

- [ ] Level names are exactly the five in §2 (Passive Knowledge / Human Teaming / Actionable Agency / Autonomous Orchestration / Full Systemic Autonomy).
- [ ] L3 is described as "executes under gate validation," never "proposes."
- [ ] Granted level is `agent_amm_level`; required level is `required_amm_level`; the bare `amm_level` is not used.
- [ ] The Neo4j relationship is `REQUIRES_AMM_LEVEL`; the action property is `required_amm_level`.
- [ ] Risk wording does not reuse a single word across maturity risk, action risk category, and action criticality.
- [ ] Any "L1–Lx validated" claim is reconciled with the L2–L4 exercised range (§7).
