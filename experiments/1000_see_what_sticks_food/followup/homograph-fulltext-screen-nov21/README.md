# Deterministic FPC Homograph Full-Text Collision Screen (Nov 21)

This packet records the first production pass of the checked Free Pascal homograph collision verifier ([`foodexperiment.homograph.pas`](../../tools/foodexperiment.homograph.pas), [`foodexperiment.homographscreen.lpr`](../../tools/foodexperiment.homographscreen.lpr)) over the freshly replayed Europe PMC context queue (`date`, `fig`, `sage`, `orange`).

## Verification benchmark

- Unit suite (`foodexperiment.homograph.tests.lpr`): 10/10 passed under checked FPC flags (`-B -Sa -Cr -Co -Ci -gl -O2`).
- Empirical full-text benchmark on all already-reviewed archived homograph pairs (`all-overlay-pairs.tsv`):
  - `checked_excluded=2067`, `caught_excluded=1527` (73.9% precision-first recall on archived full-text exclusions).
  - `checked_related=332`, `related_flagged=254`: manual audit of all 254 flagged rationales confirmed **0 genuine food/exposure papers** were misclassified (all 254 were earlier zero-exposure context rows marked `related` for Parkinson symptom discussion).
- Empirical abstract-only benchmark (`benchmark-abstract`) identified `PMID:42123391` as a paper whose abstract had a temporal `"to date"` collision while its full text cited *Phoenix dactylifera*. Accordingly, `triage-abstract` is strictly read-only for surfacing unarchived botanical-term leads and never emits auto-exclusion proposals.

## Queue screen and reconciliation

- Archived full-text homograph pairs screened in the fresh queue: `53` eligible (`31` verified `excluded` at `full_text` basis, `2` protected for botanical/food terms [`naringenin`, `citrus`], `20` kept as `ambiguous` for manual review).
- Reconciled cleanly through `foodexperiment.contextintake.exe`: `31 checked; 0 still queued; 31 new; 0 upgraded; 0 retained; Total 18,581`. [Exact dispositions](dispositions.tsv) · [Pinned scope](pinned-scope.tsv) · [Remaining pairs](open-cluster-pairs.tsv)
- Read-only `triage-abstract` across `21,648` unarchived homograph abstracts surfaced `19` prioritized `food_term_lead` pairs (including `Salvia` leads for claims `0025` and `0883`, and `orange juice`/`hesperidin` leads for `0878`) without auto-excluding any unarchived source.
