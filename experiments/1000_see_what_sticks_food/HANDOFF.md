# Round 1 research handoff — sequential baton (Milestone 2 complete)

**Milestone checkpoint · November 21, 2026 UTC · Branch `feature/trying-neon`**

This file is the sequential handoff baton between Antigravity and Codex. Review the [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), and [evidence scorecard](EVIDENCE-SCORECARD.md) before altering research records. Work in single-agent mode unless delegation is explicitly requested. Use Free Pascal (FPC) first for all repository tooling, and query Parkinson's Oracle MCP before external discovery.

## Milestones completed on `feature/trying-neon`

### Milestone 1 — Unarchived botanical-lead triage
- Resolved all `19` surfaced `food_term_lead` pairs (`17` `full_text` from official NCBI PMC JATS XML + `2` `abstract` for OA:N reviews) via `foodexperiment.contextintake.exe` into [botanical-triage-leads-nov21](followup/botanical-triage-leads-nov21/README.md).
- Cataloged `5` primary records (`PMID:41550165` sclareol mouse formalin assay + 2026 corrigendum `PMID:42898092`, `PMID:36229501` orange-odor sleep trial, `PMID:34422074` *Ziziphus jujuba* rat cognition, `PMID:40694049` published Altemor elderly falls/cognition pilot linked to `NCT06352099`, `PMID:41346684` hesperidin review) and published checked `open` v1 scorecard for `0259` (`raw orange -> worsens fall frequency`).

### Milestone 2 — Priority-3 audit & Priority-4 non-homograph Open-Access clearance
- **Priority-3 audit (`12` pairs across `9` sources):** Oracle-first lookup confirmed **`9/9` (`100%`)** are already archived at abstract or citation-list depth; PubMed confirmed all `8` P3 PMIDs lack an open PMCID (paywalled journals), so they remain honestly queued without overstating review depth.
- **Priority-4 non-homograph clearance (`104` -> `71` remaining pairs):** Reconciled all **`33` Open Access full-text non-homograph P4 pairs** (`32` verified `excluded` across author/software/color/geographic/typo collisions + `1` `related` [`0948`, `PMID:33154736`, cataloged in `research/2020-2024/Source-Text/2020-PMID33154736-PRKN-Family-Green-Tea-History.txt`]) via `foodexperiment.contextintake.exe` into [p4-nonhomograph-fulltext-nov21](followup/p4-nonhomograph-fulltext-nov21/README.md).
- **Zero remaining Open Access non-homograph P4 backlog:** All `71` remaining non-homograph P4 pairs are explicitly classified holds (`33` pairs in two known PMC congress-supplement identity mismatches `PMC7103256` / `PMC7134330`, plus `38` paywalled/non-OA bodies where PubMed XML confirmed `0/38` mention the food in title or abstract).
- **Oracle coverage ledger:** Merged `81` lookups (`12/81` strict hit rate: `9/9` P3, `3/72` P4) -> `8,961` total questions across `439` batches.

## Current verified state

- **Round 1 verdicts ([manifest.md](manifest.md)):** `951` Unknown, `23` Maybe True, `26` Maybe False, `0` True, `0` False across all `1,000` frozen statements (freeze SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`, verified intact).
- **V1 Scorecards ([scorecards.tsv](followup/scorecards.tsv)):** `97` checked v1 scorecards covering all `33` symptoms (`49` directional across `12` symptoms: `2` direct clinical signal at `55`, `3` limited clinical link at `51`, `44` minimal signal at `50.005`; `48` checked `open` at `50`; `0` unscorecarded directional claims; `0` mismatches).
- **Exact context overlay ([replay-summary.txt](followup/context-coverage/replay-summary.txt)):** `41,407` queued pairs across `26,005` sources (`0` P1, `0` P2, `12` P3, `1,705` P4 [all remaining OA P4 pairs are homographs; non-homograph P4 holds = `33` congress-mismatch + `38` paywalled], `3,147` P5, `36,543` P6; `19,490` `body_or_primary_context_reviewed`; `226` `abstract_context_reviewed`; `0` archive identity discrepancies).
- **Research catalog:** `37,245` indexed files (Oracle rev `271`, `0` read errors) + `112/112` cultural/experiential records passing `research.culture`.

## Next active milestone

1. **Milestone 3 (Active next):** Build, unit-test, and run a native Free Pascal cross-round evidence transfer mapper (`foodexperiment.roundtransfer.lpr` + `foodexperiment.roundtransfer.tests.lpr` + `build-roundtransfer.ps1`) implementing the [series-work.md](../1000_see_what_sticks_food_round_2/series-work.md) cross-round index contract across Rounds 2–7 (`5,930` frozen claims), mapping reusable Round 1 v1 scorecards, study assessments, and matrix-distinct ingredient overlaps without copying verdicts across preparations.
2. **Ongoing trial watch:** Ginger-PD (`NCT07882108`), NUTRI-GUT-PD (`NCT07213856`), PRIME (`NCT07097103`), `NCT07214428`, `UMIN000055134`.
