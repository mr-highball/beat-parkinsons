# Research handoff — sequential baton for Codex (Milestone 5 complete)

**Milestone checkpoint · November 21, 2026 UTC · Branch `feature/trying-neon`**

This file is the active sequential handoff baton between Antigravity and Codex. Overwrite only at major milestone completions. Review [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), [series evidence sequence](../1000_see_what_sticks_food_round_2/series-work.md), and [evidence scorecard](EVIDENCE-SCORECARD.md). Stay in single-agent mode unless delegation is explicitly requested; keep Free Pascal (FPC) first for tooling and Oracle MCP first for research.

## Milestone 5 completed (13th Directional Symptom Unlocked + 11 Deep Checked V1 Scorecards + Live Trial Watch)

- **Unlocked `olfactory impairment severity` as the 13th directional Parkinson's symptom (50th directional Round 1 verdict):**
  - Cataloged full NCBI PMC JATS XML primary texts for two independent 12-week randomized placebo-controlled human curcumin olfaction trials ([Nasution et al. 2026](../../research/2025-2029/Source-Text/2026-PMID42602430-Nasution-Curcumin-Hemodialysis-Olfaction.txt), `PMID:42602430`, `PMC13474629`, `n=48` hemodialysis RCT, Bonferroni Sniffin' Sticks composite TDI delta `+3.56 p=0.010` and `+4.00 p=0.002` vs `+0.875` placebo; and [Malekmakan et al. 2023](../../research/2020-2024/Source-Text/2023-PMID36967933-Malekmakan-Curcumin-CKD-Olfaction.txt), `PMID:36967933`, `PMC10031463`, `n=58` double-blind CKD RCT, QOD `p=0.045`, self-assessment `p=0.047`, `20%` vs `0%` normosmia shift `p=0.032`).
  - Validated via `oracle_check_scorecard` and published **[0588](statements/0588.txt)** (`grated turmeric -> worsens olfactory impairment severity`) as **`Maybe False` (`50.005`, `minimal_signal`)** — non-Parkinson renal cohorts and formulated curcumin capsules keep the tier minimal while recording two concordant human RCTs opposing worsening.
- **Published 10 additional checked `open` (`Unknown`, `50`) v1 scorecards** across high-assessment zero-directional claims (`0805` turmeric/attention, `0147` broccoli/attention, `0542` strawberry/attention, `0359` turmeric/rigidity, `0979` cinnamon/olfaction, `0001` olive oil/postural instability, `0175` fig/visual hallucinations [440 assessments], `0758` date/apathy [40 assessments], `0196` banana/apathy [24 assessments], `0062` cilantro/orthostatic lightheadedness [22 assessments]), all `11/11` passing `oracle_check_scorecard` (`valid_draft`) and merged atomically via `foodexperiment.scorecardmerge.exe`.
- **Merged `11` Oracle-first `claim_evidence` lookups (`10/11` strict hits, `11/11` leads)** -> **`9,189` total questions across `441` batches** (`experiments/oracle-coverage/lookups.tsv`, `batches.tsv`).
- **Live ClinicalTrials.gov v2 trial watch checkpoint (2026-11-21):**
  - `NCT07882108` (Ginger-PD): `RECRUITING`, `hasResults=false`, last updated `2026-10-21`.
  - `NCT07213856` (NUTRI-GUT-PD): `RECRUITING`, `hasResults=false`, last updated `2026-06-16`.
  - `NCT07097103` (PRIME): `NOT_YET_RECRUITING`, `hasResults=false`, last updated `2026-07-30`.
  - `NCT07214428` (Grape Powder): `ACTIVE_NOT_RECRUITING`, `hasResults=false`, last updated `2026-08-11`.

## Current verified state

- **Round 1 verdicts ([manifest.md](manifest.md)):** `950` Unknown, `23` Maybe True, `27` Maybe False (`108` checked v1 scorecards covering all `33` symptoms; **`50` directional verdicts across `13` symptoms**; `0` unscorecarded directional claims; `0` mismatches; freeze SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`).
- **Exact context overlay ([replay-summary.txt](followup/context-coverage/replay-summary.txt)):** `41,337` queued pairs across `25,970` sources (`0` P1, `0` P2, `12` P3, `1,705` P4, `3,077` P5, `36,543` P6; `19,560` `body_or_primary_context_reviewed`; `226` `abstract_context_reviewed`; `0` archive identity discrepancies).
- **Research catalog:** `37,249` indexed files (Oracle rev `273`, `0` read errors) + `112/112` cultural/experiential records passing `research.culture`.
- **Cross-round readiness:** `foodexperiment.roundtransfer` (`8/8` tests) maps `4,016 / 5,930` (`67.7%`) Rounds 2–7 claims (`736 / 1,000` in Round 2) to Round 1 evidence ([round-transfer-readiness-nov21](followup/round-transfer-readiness-nov21/README.md)).

## Active next milestone

- **Milestone 6 (Active next):** Run `foodexperiment.pmcscreen.exe` across the remaining non-homograph Priority-5 queue (`~735` pairs across the other 12 directional symptoms), clear verified `zero_body_collision` + body collisions, catalog any standout clinical studies, refresh Oracle catalog, update `findings.md`, `manifest.md`, `WORK.md`, and run final end-to-end verification + publication privacy audit.
