# Research handoff — sequential baton for Codex (Milestone 4 complete)

**Milestone checkpoint · November 21, 2026 UTC · Branch `feature/trying-neon`**

This file is the active sequential handoff baton between Antigravity and Codex. Overwrite only at major milestone completions. Review [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), [series evidence sequence](../1000_see_what_sticks_food_round_2/series-work.md), and [evidence scorecard](EVIDENCE-SCORECARD.md). Stay in single-agent mode unless delegation is explicitly requested; keep Free Pascal (FPC) first for tooling and Oracle MCP first for research.

## Milestone 4 completed (FPC PMC JATS XML Screener + P5 Zero-Directional-Symptom Pass)

- **Built native FPC PMC JATS XML full-text screener** ([foodexperiment.pmcxml.pas](tools/foodexperiment.pmcxml.pas), [foodexperiment.pmcscreen.lpr](tools/foodexperiment.pmcscreen.lpr), [foodexperiment.pmcscreen.tests.lpr](tools/foodexperiment.pmcscreen.tests.lpr) `10/10` tests passing with zero warnings, [build-pmcscreen.ps1](tools/build-pmcscreen.ps1)): verifies `<article-id pub-id-type="pmid">`, holds congress supplements (`collection_hold`) and stubs (`no_body`), checks canonical ingredients + botanical/phytochemical aliases with strict word boundaries, and automates `zero_body_collision` full-text exclusions with zero false exclusions.
- **Screened all `243` non-homograph Priority-5 pairs on the `21` zero-directional symptoms** (`217` sources, `207` unique PMCIDs retrieved via batched NCBI PMC JATS XML):
  - Reconciled **`70` full-text pairs** (`30` automated `zero_body_collision` + `35` verified body collisions [`UPSIT`/`Sniffin' Sticks` odor cards, `tdTomato`/`mCherry` tags, `OATs`/`BASIL`/`EGG`, `Ugo Basil`, `Turkey`, lab vehicles] + `5` `related` 6-shogaol + levodopa mouse pairs) into [p5-zerodir-pmcscreen-nov21](followup/p5-zerodir-pmcscreen-nov21/README.md).
  - Cataloged two primary preclinical 6-shogaol + levodopa mouse PD papers (`research/2020-2024/Source-Text/2024-PMID39092515-6Shogaol-Levodopa-Mouse-Olfaction.txt` and `research/2025-2029/Source-Text/2026-PMID42375089-6Shogaol-Levodopa-Gut-Motility.txt`).
  - Merged `217` Oracle-first lookups (`8/217` strict hits) -> **`9,178` total questions across `440` batches**.

## Current verified state

- **Round 1 verdicts ([manifest.md](manifest.md)):** `951` Unknown, `23` Maybe True, `26` Maybe False (`97` checked v1 scorecards covering all `33` symptoms; `0` unscorecarded directional claims; `0` mismatches; freeze SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`).
- **Exact context overlay ([replay-summary.txt](followup/context-coverage/replay-summary.txt)):** `41,337` queued pairs across `25,970` sources (`0` P1, `0` P2, `12` P3, `1,705` P4, `3,077` P5, `36,543` P6; `19,560` `body_or_primary_context_reviewed`; `226` `abstract_context_reviewed`; `0` archive identity discrepancies).
- **Research catalog:** `37,247` indexed files (Oracle rev `272`, `0` read errors) + `112/112` cultural/experiential records passing `research.culture`.
- **Cross-round readiness:** `foodexperiment.roundtransfer` (`8/8` tests) maps `4,016 / 5,930` (`67.7%`) Rounds 2–7 claims (`736 / 1,000` in Round 2) to Round 1 evidence ([round-transfer-readiness-nov21](followup/round-transfer-readiness-nov21/README.md)).

## Active next milestones

1. **Milestone 5 (Active next):** Publish checked v1 scorecards across high-evidence zero-directional Round 1 candidates — led by **`0588` (`grated turmeric -> worsens olfactory impairment severity`)** unlocking `olfactory impairment severity` as the **13th directional symptom** via Nasution et al. 2026 (`PMID:42602430`, `PMC13474629`, `n=48` hemodialysis RCT, Sniffin' Sticks TDI `p=0.010`/`p=0.002`) + Malekmakan et al. 2023 (`PMID:36967933`, `PMC10031463`, `n=58` double-blind CKD RCT) — plus checked v1 scorecards for `0805`, `0147`, `0542`, `0359`, `0979`, `0001`, `0175`, `0758`, `0196`, `0062` and live status log on the `5` watched clinical trials.
2. **Milestone 6:** Run `foodexperiment.pmcscreen.exe` across the remaining non-homograph Priority-5 queue (`~735` pairs) to clear zero-body collisions and capture high-signal clinical studies across all remaining Round 1 symptoms.
