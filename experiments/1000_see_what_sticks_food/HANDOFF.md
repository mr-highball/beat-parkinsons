# Research handoff — sequential baton for Codex

**Milestone checkpoint · November 21, 2026 UTC · Branch `feature/trying-neon`**

This file is the active sequential handoff baton between Antigravity and Codex. Overwrite this file at major milestone completions so each handoff carries exact altered files, verified counts, runnable FPC commands, and the next prioritized queue.

Review the [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), [series evidence sequence](../1000_see_what_sticks_food_round_2/series-work.md), and [evidence scorecard](EVIDENCE-SCORECARD.md) before changing research records. Work in single-agent mode unless delegation is explicitly requested. Keep Free Pascal (FPC) first for all repository tooling (`experiments/tools/vendor/athena/`), and query Parkinson's Oracle MCP before external discovery.

---

## Verified baseline snapshot

- **Round 1 verdicts ([manifest.md](manifest.md)):** `951` Unknown, `23` Maybe True, `26` Maybe False, `0` True, `0` False across all `1,000` frozen statements (`freeze.sha256` = `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`, verified intact; all six expansion round freeze hashes Rounds 2–7 = `5,930` claims also verified intact with zero cross-round duplicates).
- **V1 Evidence Scorecards ([scorecards.tsv](followup/scorecards.tsv), [scorecard-sources.tsv](followup/scorecard-sources.tsv)):** **`97` checked v1 scorecards** covering **all `33` Parkinson's symptoms**, with **`0` unscorecarded directional claims** and **`0` ledger mismatches**:
  - `2` `direct_clinical_signal` (`55`): `0063` (ground saffron / depression, Maybe False), `0485` (dried saffron / fatigue, Maybe False).
  - `3` `limited_clinical_link` (`51`): `0082` (brewed black tea / bradykinesia, Maybe True), `0904` (brewed black tea / rest tremor, Maybe True), `0948` (brewed green tea / fatigue, Maybe True).
  - `44` `minimal_signal` (`50.005`): `20` Maybe True, `24` Maybe False across `12` symptoms (including newly unlocked `0916` ground cinnamon / urinary urgency frequency).
  - `48` checked `open` (`50`, `Unknown`): `13` downgraded legacy `51` claims, `16` zero-directional symptom flagship audits, `0259` (raw orange / falls: Sim 2018 null cohort + Altemor multi-ingredient pilot `PMID:40694049` / `NCT06352099`), plus earlier baseline `open` scorecards.
- **Research catalog & Oracle coverage:**
  - Oracle catalog revision **`271`**: `37,245` indexed files, `0` read errors.
  - Cultural/experiential catalog: `112/112` records pass `research.culture.exe`.
  - Oracle coverage ledger ([lookups.tsv](../oracle-coverage/lookups.tsv), [batches.tsv](../oracle-coverage/batches.tsv)): `8,961` logged first-pass questions across `439` batches.
- **Exact context overlay ([replay-summary.txt](followup/context-coverage/replay-summary.txt)):**
  - `61,252` exact claim-source pairs (`19,490` `body_or_primary_context_reviewed`, `226` `abstract_context_reviewed`, `41,407` queued across `26,005` sources).
  - Priority breakdown: `0` P1, `0` P2, **`12` P3** (`9/9` sources already archived at abstract/citation depth, paywalled without open PMCID), **`1,705` P4** (`0` Open Access non-homograph pairs remaining — non-homograph P4 holds are strictly `33` congress-supplement identity mismatches [`PMC7103256`, `PMC7134330`] + `38` paywalled/non-OA bodies with `0/38` food mentions in PubMed title/abstract), `3,147` P5, `36,543` P6.

---

## Major alterations delivered on `feature/trying-neon`

### New & upgraded native FPC toolchain (zero authored Python/Node scripts)
1. **Parkinson's Oracle MCP (`experiments/tools/parkinsons-oracle/`):** Added `oracle_backlog`, compact `include_culture` mode, precomputed v1 `scorecard_status` filters, and fast Windows hierarchical feature-branch HEAD pinning (`28.13 ms` -> `0.54–1.11 ms`). All 7 FPC test suites pass (`rubric`, `selection`, `ingredients`, `presentation`, `backlog`, `oraclecoverage.merge` `15/15`, `catalog.sourcekinds` `21/21`).
2. **Atomic Scorecard Merger ([foodexperiment.scorecardmerge.lpr](tools/foodexperiment.scorecardmerge.lpr), [build-scorecardmerge.ps1](tools/build-scorecardmerge.ps1)):** Atomic FPC merger for `scorecards.tsv`, `scorecard-sources.tsv`, and `verdicts.tsv` (`5/5` tests).
3. **Homograph Collision Verifier ([foodexperiment.homograph.pas](tools/foodexperiment.homograph.pas), [foodexperiment.homographscreen.lpr](tools/foodexperiment.homographscreen.lpr), [build-homographscreen.ps1](tools/build-homographscreen.ps1)):** Precision-first full-text verifier for `date`, `fig`, `sage`, `orange` (`10/10` tests; `0` genuine food false exclusions across all `2,399` reviewed benchmark pairs) + read-only `triage-abstract` lead finder.
4. **Generalized Round 1–7 Review Tool ([foodexperiment.review.lpr](tools/foodexperiment.review.lpr), [foodexperiment.review.tests.lpr](tools/foodexperiment.review.tests.lpr)):** Replaced hardcoded `1000` / `125x8` limits with dynamic freeze-derived claim counts (`1..9999`), preserving strict `125x8` enforcement for Round 1 while passing both 1,000-claim Round 1 and 930-claim unbalanced Round 7 synthetic fixtures.
5. **Cross-Round Evidence Transfer Mapper ([foodexperiment.transfer.pas](tools/foodexperiment.transfer.pas), [foodexperiment.roundtransfer.lpr](tools/foodexperiment.roundtransfer.lpr), [build-roundtransfer.ps1](tools/build-roundtransfer.ps1)):** Verifies freeze hashes on both source and target rounds, enforces zero cross-round duplicate `(ingredient, symptom)` pairs, preserves matrix-distinct botanical siblings separately (`walnut` vs `walnut oil`, `almond` vs `almond oil`, etc.), and maps reusable Round 1 scorecards/assessments onto Rounds 2–7 (`8/8` checked tests, zero compiler warnings).

### Completed evidence batches & packets
- **V1 scorecard migration & zero-directional symptom sweep:** Migrated all `50` legacy directional claims (`0` unscorecarded directional claims remaining), audited all `17` previously zero-directional symptoms (unlocking `0916` ground cinnamon / urinary urgency), and added `0259` raw orange / falls (`97` total v1 scorecards).
- **Homograph & botanical triage packets:** [homograph-fulltext-screen-nov21](followup/homograph-fulltext-screen-nov21/README.md) (`31` archived full-text exclusions) and [botanical-triage-leads-nov21](followup/botanical-triage-leads-nov21/README.md) (all `19` surfaced unarchived botanical leads resolved; `5` new primary records cataloged including `PMID:40694049` / `NCT06352099` and `PMID:41550165` + corrigendum `PMID:42898092`).
- **Priority-3 audit & Priority-4 non-homograph clearance:** [p4-nonhomograph-fulltext-nov21](followup/p4-nonhomograph-fulltext-nov21/README.md) (`9/9` P3 verified archived/paywalled; all `33` OA non-homograph P4 full texts resolved; `PMID:33154736` cataloged).
- **Cross-round transfer readiness:** [round-transfer-readiness-nov21](followup/round-transfer-readiness-nov21/README.md) (`4,016 / 5,930` [`67.7%`] expansion claims and `736 / 1,000` [`73.6%`] Round 2 claims mapped to reusable Round 1 evidence).

---

## Immediate next steps for Codex

1. **Merge or checkpoint `feature/trying-neon` into `master`** (once user approves) so all future Rounds 2–7 branches start from this verified FPC toolchain and `97`-scorecard baseline.
2. **Choose between two clean high-yield paths (do NOT spin on P6 homographs):**
   - **Path A — Open Round 2 evidence review (`1,000` frozen claims, [round_2/README.md](../1000_see_what_sticks_food_round_2/README.md)):** Regenerate the Round 2 transfer index into `build/round-transfer-maps/round_2_transfer_index.tsv` via `foodexperiment.roundtransfer.exe`, and start with the `157` `direct_ingredient_scorecard` claims (`barley` 31, `black tea` 30, `banana` 30, `blueberry` 29, `anise seed` 20, `basil` 17) — especially the `black tea` claims targeting the `21` currently zero-directional symptoms (e.g., `daily off time`, `daytime sleepiness`, `dyskinesia`, `freezing of gait`, `muscle rigidity`, `apathy`, `attention`) where `Postuma 2012 NCT00459420` and related PD caffeine/tea studies are ALREADY archived in Oracle!
   - **Path B — Clear non-homograph Priority-5 Open Access clinical leads in Round 1:** Run the exact same strict-PMID NCBI PMC JATS XML check used in Milestone 2 on the non-homograph subset of the `3,147` Priority-5 queue, prioritizing the `21` zero-directional symptoms before opening Round 2.
3. **Monitor pending/recruiting PD clinical trials for result readouts:** Ginger-PD (`NCT07882108`), NUTRI-GUT-PD (`NCT07213856`), PRIME (`NCT07097103`), `NCT07214428`, and `UMIN000055134`.

## Key reproducible commands

```powershell
# 1. Rebuild Oracle & inspect backlog
powershell -NoProfile -ExecutionPolicy Bypass -File experiments\tools\parkinsons-oracle\build.ps1 -RefreshCatalog
& build\parkinsons-oracle\bin\parkinsons-oracle.exe backlog .

# 2. Generate Round 2 cross-round evidence transfer map (ignored build/ output)
powershell -NoProfile -ExecutionPolicy Bypass -File experiments\1000_see_what_sticks_food\tools\build-roundtransfer.ps1
& experiments\1000_see_what_sticks_food\build\roundtransfer-3.3.1-i386-win32\bin\foodexperiment.roundtransfer.exe `
  experiments\1000_see_what_sticks_food `
  experiments\1000_see_what_sticks_food_round_2 `
  build\round-transfer-maps\round_2_transfer_index.tsv

# 3. Verify Round 1 ledgers, statements, scorecards, and cultural records
& experiments\1000_see_what_sticks_food\build\food-experiment-review\i386-win32-3.3.1\bin\foodexperiment.review.exe verify experiments\1000_see_what_sticks_food
& build\cultural-catalog\bin\research.culture.exe . 2025
```
