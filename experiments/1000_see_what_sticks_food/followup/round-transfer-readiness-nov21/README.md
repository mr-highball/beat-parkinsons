# Native FPC Cross-Round Evidence Transfer Readiness (Rounds 2–7)

This packet records the checked Free Pascal cross-round evidence index mapper ([`foodexperiment.transfer.pas`](../../tools/foodexperiment.transfer.pas), [`foodexperiment.roundtransfer.lpr`](../../tools/foodexperiment.roundtransfer.lpr), [`foodexperiment.roundtransfer.tests.lpr`](../../tools/foodexperiment.roundtransfer.tests.lpr), [`build-roundtransfer.ps1`](../../tools/build-roundtransfer.ps1)) built to satisfy the cross-round index contract in [`series-work.md`](../../../1000_see_what_sticks_food_round_2/series-work.md).

## Safety and epistemic guarantees

- Verifies `freeze.tsv` against `freeze.sha256` on BOTH source and target rounds before emitting any index.
- Hard-rejects any cross-round duplicate `(ingredient, symptom)` pair across all 6,930 hypotheses.
- Preserves distinct food matrices (`walnut` vs `walnut oil`, `almond` vs `almond oil`, `sesame seed` vs `sesame oil`, `cilantro` vs `coriander seed`, `celery stalk` vs `celery leaf`) in separate `matrix_*` columns without inflating same-ingredient counts.
- Ignores `excluded` study rows in `assessments.tsv` and never copies verdicts or invents completed assessments across preparations or symptoms.
- Unit and CLI integration suite passes `8/8` checks under checked FPC flags (`-B -Sa -Cr -Co -Ci -gl -O2`) with zero compiler warnings.

## Verified cross-round reuse across Rounds 2–7 (`5,930` frozen claims)

| Round | Target claims | `direct_ingredient_scorecard` | `ingredient_assessed` | `matrix_related` | `cold_start_zero_dir_symptom` | `cold_start` | Reusable total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Round 2 | 1,000 | 157 | 546 | 33 | 168 | 96 | **736 (73.6%)** |
| Round 3 | 1,000 | 157 | 521 | 66 | 164 | 92 | **744 (74.4%)** |
| Round 4 | 1,000 | 126 | 437 | 66 | 235 | 136 | **629 (62.9%)** |
| Round 5 | 1,000 | 96 | 409 | 66 | 273 | 156 | **571 (57.1%)** |
| Round 6 | 1,000 | 145 | 395 | 64 | 252 | 144 | **604 (60.4%)** |
| Round 7 | 930 | 102 | 562 | 68 | 126 | 72 | **732 (78.7%)** |
| **Total** | **5,930** | **783** | **2,870** | **363** | **1,218** | **696** | **4,016 (67.7%)** |

## Round 2 immediate high-yield clusters (`157` `direct_ingredient_scorecard` + `33` `matrix_related`)

- `barley` (`31` Round 2 claims; `1` Round 1 directional scorecard, `18` assessments)
- `black tea` (`30` Round 2 claims; `2` Round 1 directional scorecards [`0082`, `0904`], `40` assessments incl. Postuma 2012 `NCT00459420`)
- `banana` (`30` Round 2 claims; `1` Round 1 directional scorecard, `44` assessments)
- `blueberry` (`29` Round 2 claims; `1` Round 1 directional scorecard, `23` assessments)
- `anise seed` (`20` Round 2 claims; `2` Round 1 directional scorecards, `33` assessments)
- `basil` (`17` Round 2 claims; `1` Round 1 directional scorecard, `48` assessments)
- `almond` (`33` Round 2 claims; matrix-distinct sibling `almond oil`, `22` Round 1 assessments)

## Reproducing per-round transfer maps (ignored `build/` output)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File experiments\1000_see_what_sticks_food\tools\build-roundtransfer.ps1
& experiments\1000_see_what_sticks_food\build\roundtransfer-3.3.1-i386-win32\bin\foodexperiment.roundtransfer.exe `
  experiments\1000_see_what_sticks_food `
  experiments\1000_see_what_sticks_food_round_2 `
  build\round-transfer-maps\round_2_transfer_index.tsv
```

Full summary table: [series-transfer-summary.tsv](series-transfer-summary.tsv)
