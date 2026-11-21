# Round 1 research handoff — sequential baton (Milestone 1 complete)

**Milestone checkpoint · November 21, 2026 UTC · Branch `feature/trying-neon`**

This file is the sequential handoff baton between Antigravity and Codex. Review the [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), and [evidence scorecard](EVIDENCE-SCORECARD.md) before altering research records. Work in single-agent mode unless delegation is explicitly requested. Use Free Pascal (FPC) first for all repository tooling, and query Parkinson's Oracle MCP before external discovery.

## Milestone 1 completed (Unarchived botanical-lead triage)

- **Resolved all `19` surfaced `food_term_lead` pairs** (`17` distinct PMIDs across claims `0025`, `0259`, `0370`, `0502`, `0878`, `0883`, `0906`) flagged by `foodexperiment.homographscreen triage-abstract`: `17` pairs verified at `full_text` depth from official NCBI PMC JATS XML (`15` OA articles) and `2` OA:N reviews honestly verified at `abstract` depth (`PMID:21444610`, `PMID:42613903`). Reconciled via `foodexperiment.contextintake.exe` into [botanical-triage-leads-nov21](followup/botanical-triage-leads-nov21/README.md).
- **Cataloged `5` primary source records** (Oracle catalog refreshed to revision `270`, `37,244` files, `0` read errors):
  - `research/2020-2024/Source-Text/2023-PMID41550165-Prottay-Sclareol-Formalin-Pain.txt` (`PMC12710028` + 2026 journal batch corrigendum `PMID:42898092`)
  - `research/2020-2024/Source-Text/2022-PMID36229501-Orange-Odor-Sleep-Quality.txt` (`PMC9562345`)
  - `research/2020-2024/Source-Text/2021-PMID34422074-Ziziphus-Jujuba-Rat-Cognition.txt` (`PMC8373493`)
  - `research/2025-2029/Source-Text/2025-PMID40694049-Giovannini-Altemor-Elderly-Falls-Cognition.txt` (links published Altemor crossover pilot RCT directly to existing `NCT06352099`)
  - `research/2025-2029/Source-Text/2025-PMID41346684-Zhao-Hesperidin-Neuroprotection-Review.txt` (`PMC12673667`)
- **Published checked v1 scorecard for `0259` (`raw orange -> worsens fall frequency`, `open`, `Unknown`, `50`):** Combined null Sim et al. 2018 citrus falls cohort (`HR 1.01`, `95% CI 0.99-1.04`) and the multi-ingredient Altemor pilot (`PMID:40694049`, `NCT06352099`, `n = 36` non-PD elderly, paywalled tables).
- **Updated Oracle coverage ledger:** `8,880` questions across `438` batches (`+19` questions, `1/19` strict hit rate via `NCT06352099`).

## Current verified state

- **Round 1 verdicts ([manifest.md](manifest.md)):** `951` Unknown, `23` Maybe True, `26` Maybe False, `0` True, `0` False across all `1,000` frozen statements (freeze SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`, verified intact).
- **V1 Scorecards ([scorecards.tsv](followup/scorecards.tsv)):** `97` checked v1 scorecards covering all `33` symptoms (`49` directional across `12` symptoms: `2` direct clinical signal at `55`, `3` limited clinical link at `51`, `44` minimal signal at `50.005`; `48` checked `open` at `50`; `0` unscorecarded directional claims; `0` mismatches).
- **Exact context overlay ([replay-summary.txt](followup/context-coverage/replay-summary.txt)):** `41,440` queued pairs across `26,038` sources (`0` P1, `0` P2, `12` P3, `1,738` P4 [only `104` non-homograph pairs across `72` sources], `3,147` P5, `36,543` P6; `19,457` `body_or_primary_context_reviewed`; `226` `abstract_context_reviewed`; `0` archive identity discrepancies).
- **Native FPC toolchain:** `parkinsons-oracle` (rev `270`), `foodexperiment.review` (generalized `1..9999` for Rounds 1–7), `foodexperiment.scorecardmerge`, `foodexperiment.homographscreen`, `foodexperiment.contextintake`, `foodexperiment.contextqueue`, `oraclecoverage.merge`, `research.culture` (`112/112`).

## Next active milestones

1. **Milestone 2 (Active next):** Clear the remaining non-homograph Priority-4 clinical queue (`104` pairs across `72` sources — `90` pairs with PMCIDs, heavily concentrated in identity-collision clusters like `PMID:20532731` [27 pairs] and `PMID:15896867` [6 pairs], author/software collisions `salmon`/`mango`/`turkey`, and genuine PD studies!) plus document honest abstract/access boundaries on the `12` paywalled Priority-3 pairs (`9` sources).
2. **Milestone 3:** Build and test a native FPC cross-round evidence transfer mapper (`foodexperiment.roundtransfer.lpr` + unit suite) mapping Round 1's `97+` v1 scorecards and `5,701+` study assessments onto Round 2 (`1,000` claims) and Rounds 3–7 (`4,930` claims) without copying verdicts across preparations.
3. **Ongoing trial watch:** Ginger-PD (`NCT07882108`), NUTRI-GUT-PD (`NCT07213856`), PRIME (`NCT07097103`), `NCT07214428`, `UMIN000055134`.
