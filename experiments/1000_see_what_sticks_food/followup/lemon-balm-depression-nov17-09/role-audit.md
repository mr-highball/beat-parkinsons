# Reproduce the source-role audit

The current exact ledger has 11,671 rows: 9,114 excluded, 2,353 related and 204 pending. The audit retains all excluded pairs, grouped into 4,287 source keys and 6,390 source × ingredient groups. Rationale-language flags prioritize 3,408 rows; the other 5,706 remain in scope.

All 15 rechecks concern PMID21340000 / PMC3039966, DOI 10.3390/ijms12010506. Its original tables contain olive-oil constituents, black tea, rosemary, Salvia officinalis polyphenols, cranberry juice, brown-rice bran and grape-seed extract. The 13 genuine material leads are related despite preparation and symptom gaps. Two culinary-cumin pairs remain excluded because the source names black cumin/thymoquinone, a different botanical. This source-role audit creates no clinical estimate or independent cohort.

Eight of the 13 corrected pairs were unflagged. The remaining inventory therefore preserves both flagged and unflagged rows: 9,112 pairs, comprising 3,408 flagged and 5,704 unflagged. Two retained exclusions are independently rechecked. Thirteen exact adopted related proofs are counted separately, rather than wrongly requiring them to remain excluded. [Proof rows](role-rechecked-dispositions.tsv) · [Historical baseline summary](role-audit-summary.txt) · [Successful current summary](role-audit-current.txt)

The 11,603-row historical summary belongs to the pre-intake ledger and must not be presented as current. Current-input SHA256 is `79ebf87eab2fe654234fb4c339c7a71a933bc6cf493fbc76a2f0091689c979b7`; all 15 proofs hash to `4c7a13bae084c14075beaae0d831c31b6ee10ee895f4475abbe1cb02f1733d7b`. A later ledger needs its own snapshot and full replay.

From the repository root, using native FPC and a fresh ignored output directory:

```powershell
$e = 'experiments/1000_see_what_sticks_food'
$run = "$e/build/source-role-audit"
$compiler = (Get-Command fpc -CommandType Application).Source
New-Item -ItemType Directory -Force "$run/units", "$run/bin", "$run/output" | Out-Null
Copy-Item -LiteralPath "$e/followup/context-coverage/exact-reviews.tsv" -Destination "$run/exact-input.tsv"
Copy-Item -LiteralPath "$e/freeze.tsv" -Destination "$run/freeze-input.tsv"
Copy-Item -LiteralPath "$e/followup/lemon-balm-depression-nov17-09/role-rechecked-dispositions.tsv" -Destination "$run/proofs-input.tsv"
Get-FileHash "$run/exact-input.tsv", "$run/freeze-input.tsv", "$run/proofs-input.tsv"
& $compiler -B -Sa -Cr -Co -Ci -gl "-Fu$e/tools" "-FU$run/units" "-FE$run/bin" "$e/tools/foodexperiment.excludedroleaudit.lpr"
& "$run/bin/foodexperiment.excludedroleaudit.exe" "$run/freeze-input.tsv" "$run/exact-input.tsv" "$run/output" "$run/proofs-input.tsv"
```

`all-excluded-inventory.tsv` preserves every excluded row. `all-unreviewed-excluded.tsv` retains the complete remaining scope; `flagged-unreviewed-candidates.tsv` is only the narrower reading-order list. Source and source × ingredient tables provide uncapped group denominators. The audit does not infer original-source content or access failure from keywords.

The [revision utility](../../tools/foodexperiment.contextrevise.lpr) takes a baseline ledger, pinned before rows, verified correction rows and a distinct staged output path. It permits only guarded excluded-to-related revisions, preserves all nonselected bytes/order and the selected evidence basis, and refuses in-place input overwrite. The current 13 corrections are already adopted; do not apply them again. [Original revision receipt](role-revision.txt) · [Ten revision fixtures](revision-fixtures.txt)

The [audit utility](../../tools/foodexperiment.excludedroleaudit.lpr) now accepts exactly matching already-adopted related proofs as well as still-excluded proofs. Changed adopted content, changed retained exclusions, changed bases, pending selected rows, duplicates or absent keys fail before inventory writes. [Eleven audit fixtures](audit-fixtures.txt) cover those boundaries, old unapplied proofs and preservation of both flagged and unflagged remaining rows. The [audit tests](../../tools/foodexperiment.excludedroleaudit.tests.lpr) take the audit executable, frozen claims and a fresh fixture directory; the [revision tests](../../tools/foodexperiment.contextrevise.tests.lpr) take the revision executable and a fresh fixture directory. Compile all with the same native unit path and ignored output convention.
