# RAGF — Escalation Analysis (Simulation / A Priori Estimate)

> **Read this first.** The escalation-resolution figures in this document and in
> `results/escalation_analysis/*.json` are produced by a **deterministic
> simulator** (`ResolutionSimulator`) using operator-behaviour distributions
> drawn from published literature. They are **modeled estimates, not measured
> human decisions.** No systematic multi-operator review was performed. Do not
> cite these figures as empirical evidence of operator consistency.

## Summary

To address reviewer questions about the human-in-the-loop (ESCALATE) pathway,
we added a tooling layer that *estimates* — rather than measures — resolution
times, inter-operator consistency, and jurisprudence (rule-creation) growth.
The escalation **counts** (n=100 aviation, n=38 healthcare) correspond to the
ESCALATE verdicts observed in the simulation/shadow evaluation; the operator
**resolutions** built on top of them are simulated.

## Key figures (all simulated estimates)

- **Inter-operator agreement (modeled): ~95% aviation / ~94% healthcare.** These
  are produced by the simulator from literature-based operator-deviation
  distributions; they are not observed agreement rates.
- **Resolution times (simulated from literature time profiles): 187s aviation,
  301s healthcare**, all P95 < 10 min.
- **Rule-creation rate (simulated): 38% aviation (38/100), 39% healthcare
  (15/38).** Indicative of a maturing ontology under the modeled assumptions.

## Files

### Core implementation
1. **`ragf_core/escalation/resolution_tracker.py`**
   - `EscalationResolution`: record structure for a resolved escalation.
   - `ResolutionAnalyzer`: computes time stats, agreement, and rule-creation
     growth over whatever resolutions it is given (Section 7.7 of the paper).
   - `ResolutionSimulator`: **synthetic data generator** — fabricates plausible
     operator resolutions from escalation logs using a deterministic SHA-256
     outcome mapping plus literature-based boundary-deviation probabilities.

2. **`scripts/analyze_escalations.py`**
   - Runs the simulator and writes labeled JSON to
     `results/escalation_analysis/`. Every output carries a `_metadata` block
     marking the data as `simulated_literature_based_estimate`.
   - If no real escalation logs are present at
     `data/validation_logs/{domain}_escalations.json`, it generates
     deterministic **sample** logs sized to the evaluation's escalation counts
     (so a clean checkout reproduces the figures without the private logs).
   - Fixed seed (42). With the SHA-256 outcome mapping, output is reproducible
     across machines (no `PYTHONHASHSEED` dependency).

3. **`results/escalation_analysis/`**
   - `aviation_resolution_metrics.json` — n=100, modeled agreement ~95%.
   - `healthcare_resolution_metrics.json` — n=38, modeled agreement ~94%.

The Section 7.7 text is integrated directly in `papers/RAGF_v2_5.tex` (there is
no separate sections file to paste).

## How the simulation works

- **Deterministic base decisions.** `_determine_outcome` maps each case to a
  base outcome via `_stable_hash_pct` (SHA-256 of the escalation id, mod 100)
  against reason-specific thresholds. Same input → same output, on any machine.
- **Boundary variability only.** Operators may diverge **only** on cases whose
  reason marks them as boundary/marginal, with experience-stratified deviation
  probabilities (senior 8%, mid 12%, junior 12%) drawn via the seeded RNG.
- **Three independent reviewers.** Each of three simulated operators "reviews"
  all cases; agreement is computed pairwise. Because divergence is confined to
  boundary cases and driven by the seed (not the hash), the agreement and time
  figures are independent of the outcome-hash and stable across runs.

## Relationship to the literature (this is the *basis* of the estimate)

The figures are aligned with literature **by construction**, because the
simulator's distributions are taken *from* that literature — this is not
independent validation:

- Operator-agreement assumptions reference expert-judgment work (Cohen's
  κ ≈ 0.85–0.90; Kahneman & Klein 2009) and domain inter-rater reliability.
- Time profiles reference FAA human-factors guidance (aviation) and clinical
  review timeframes (healthcare).
- The rule-creation rate reflects a system modeled as mid-maturation.

Empirical confirmation through instrumented multi-operator review is required
future work; nothing here substitutes for it.

## Reproduce

```bash
# Deterministic: same results on any machine (SHA-256 mapping + seed 42)
python3 scripts/analyze_escalations.py

# Inspect labeled outputs (note the _metadata block)
cat results/escalation_analysis/aviation_resolution_metrics.json
cat results/escalation_analysis/healthcare_resolution_metrics.json

# Stable agreement check
python3 scripts/analyze_escalations.py | grep "Mean Agreement Rate"
# Aviation ~95.3%, Healthcare ~94.7% (these do not depend on the hash)
```

After regenerating, if `rule_creation_rate` changes, update §7.7.3 of
`papers/RAGF_v2_5.tex` and the README escalation table, then rebuild the PDF
(`cd papers/ && make`; see `papers/VERSIONING.md`).

## Suggested commit message

```
docs(escalation): simulated escalation-resolution estimates (Section 7.7)

- ResolutionSimulator: deterministic (SHA-256, seed 42) simulation of operator
  resolutions over escalation cases; NOT measured human decisions
- Aviation (n=100) and healthcare (n=38) simulated estimates, labeled in
  _metadata as simulated_literature_based_estimate
- Modeled inter-operator agreement ~95%/~94%; simulated resolution times
  187s/301s; simulated rule-creation 38%/39%

Provides a clearly-labeled a priori estimate for the escalation pathway;
empirical multi-operator measurement remains future work.
```

## What we can and cannot claim

- **Resolution time** — *Estimate.* Under literature-based time profiles, mean
  187s (aviation) / 301s (healthcare), P95 < 10 min. Not measured on real
  operators.
- **Inter-operator variability** — *Estimate.* Modeled ~95% / ~94% agreement,
  with divergence confined to boundary cases. Not an observed agreement rate.
- **Jurisprudence consistency** — *Partial / design-stage.* The ontology is
  intended to constrain operator discretion; the 38% / 39% rule-creation figures
  are simulated indicators of a maturing ontology, not a measured outcome.
- **Regulatory capture** — Out of scope here (paper §7.5).
- **State uncertainty** — Out of scope here (paper §7.7.4, architectural).

## Honesty note

These metrics are the ones that *should have been collected from the start*
through instrumented operator review. We did not have that instrumentation, so
we provide a transparent, clearly-labeled simulation as an a priori estimate
instead of presenting nothing — or, worse, presenting modeled numbers as
measured. The labeling in this file, in each JSON `_metadata` block, and in the
paper's Section 7.7 is deliberately explicit on this point.
