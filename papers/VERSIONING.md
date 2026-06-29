# Versioning Policy — RAGF Paper & Repository

## Principles

1. **Never rewrite published history.** Corrections move the repo *forward*
   with new commits. Do not `rebase`/`force-push` over commits that already
   exist on the remote. Transparent correction is an asset under review, not a
   liability.
2. **File names must match content versions.** The source and the PDF must
   carry the same version number as the content they represent.
3. **One canonical "latest" PDF.** Exactly one PDF is the current version;
   superseded versions are archived, not deleted.

## Naming convention

- Source:  `papers/RAGF_vMAJOR_MINOR.tex`  (e.g. `RAGF_v2_5.tex`)
- PDF:     `papers/RAGF_vMAJOR_MINOR.pdf`  (must be regenerated from the source)
- Archived versions live in `papers/archive/`.

> ⚠️ The previous state was confusing: `RAGF_v2_3.tex` actually compiled to
> "v2.4", and two near-identical PDFs existed (`RAGF_v2_4.pdf` and
> `RAGF_v2_3_v2_4.pdf`). From v2.5 onward, source and PDF version numbers
> always match, and build artifacts with double version numbers are removed.

## What to keep / archive / delete

| Item | Action |
|---|---|
| Current source + PDF (e.g. `RAGF_v2_5.tex`/`.pdf`) | Keep in `papers/` |
| Legitimate prior versions (`RAGF_v2_4.pdf`, old `.tex`) | Move to `papers/archive/` |
| Duplicate build artifact `RAGF_v2_3_v2_4.pdf` | Delete (not a real version) |
| Git history | Never rewrite |

## Build flow

```bash
cd papers/
make            # 4-pass build with bibliography
# Output: RAGF_vX_Y.pdf  (regenerate after EVERY .tex edit)
```

Editing the `.tex` without rebuilding leaves the PDF stale — and the committee
reads the PDF. Always regenerate and commit the PDF together with the source.

## Release checklist (per version bump)

1. Apply edits to the source, rename to the new version if content changed
   materially.
2. `make` → regenerate the matching PDF.
3. Update README links and the `## Version History` section.
4. Move the superseded PDF to `papers/archive/`.
5. Commit with a message describing *what changed and why*.
