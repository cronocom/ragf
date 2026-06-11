# Examples

Two ontologies ship with the auditor for self-validation and demos:

| File | Expected verdict | Purpose |
|---|---|---|
| `fintech_minimal.yaml` | `PASSED` | Reference clean ontology — must satisfy all 10 CCs |
| `fintech_seeded_faults.yaml` | `FAILED` | Three deliberate defects, one per shipped CC |

The seeded-faults file is the canonical regression fixture: any time a new CC
is added to the auditor, this file should be extended with a fault that
triggers it. The CI gate runs both files on every PR; a regression that lets
the seeded-faults file pass is a release blocker.

## Running them locally

```bash
make up
make audit ONTOLOGY=examples/fintech_minimal.yaml         # PASSED
make audit ONTOLOGY=examples/fintech_seeded_faults.yaml   # FAILED
make down
```

## Adding a new example

1. Place the YAML under `examples/`.
2. Document in this README which CC(s) it is meant to exercise and the
   expected verdict.
3. Add an entry to `tests/test_examples.py` that asserts the verdict matches.
