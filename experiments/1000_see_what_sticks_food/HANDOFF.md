# Research handoff — sequential baton for Codex (Round 1 100% Exhaustive Research & `Unknown (Researched)` Complete)

**Milestone checkpoint · November 21, 2026 UTC · Branch `feature/trying-neon`**

This file is the active sequential handoff baton between Antigravity and Codex. Overwrite only at major milestone completions. Review [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), [series evidence sequence](../1000_see_what_sticks_food_round_2/series-work.md), and [evidence scorecard](EVIDENCE-SCORECARD.md). Stay in single-agent mode unless delegation is explicitly requested; keep Free Pascal (FPC) first for tooling and Oracle MCP first for research.

## Milestones completed on `feature/trying-neon`

1. **Prior Phases A–D, Milestones 1–6 & Track A (FPC infrastructure, P1–P5 clearance, auto-synced Nyx UI, Tremors-upfront & Maybe-Ease v1 audits):** Built `oracle_backlog`, `foodexperiment.scorecardmerge`, `foodexperiment.homographscreen` (`10/10`), `foodexperiment.roundtransfer` (`8/8`, mapping `4,016 / 5,930` expansion claims across Rounds 2–7 including `736 / 1,000` in Round 2), `foodexperiment.pmcscreen` (`10/10`), and generalized `foodexperiment.review` (`1..9999`); wired automatic Nyx Web UI rebuilds into `experiments/tools/parkinsons-oracle/build.ps1`; completed `26/26` `rest tremor severity` v1 coverage and unlocked symptoms #12–#15 (`urinary urgency frequency`, `olfactory impairment severity`, `shortened stride severity`, `muscle rigidity severity`).
2. **Phase 1 — `Unknown (Researched)` Metadata Architecture across FPC Tools, Oracle MCP, Nyx Web UI & All 7 Rounds' `AGENTS.md`:**
   - Built native FPC verifier `foodexperiment.researchstatus` (`foodexperiment.auditstatus.pas`, `foodexperiment.researchstatus.lpr`, `10/10` tests) enforcing `lab_clinical_checked=yes`, `cultural_checked=yes`, `scorecard_checked=yes`, valid ISO UTC date, non-empty `search_basis`, and verified `recorded` v1 scorecards before any claim earns `researched` (`Unknown (Researched)`).
   - Extended `foodexperiment.scorecardmerge.lpr` with atomic `--batch` mode (`7/7` tests) preserving 4-argument single-claim compatibility.
   - Wired `followup/research-status.tsv` and `"Unknown (Researched)"` end-to-end into `parkinsons-oracle` MCP (`display_verdict`, `research_status`, `research_audit`, `unknown_researched`, `unknown_unresearched`, filter support) and the pas2js Nyx Web UI (`oraclegraphmodel.pas`, `oracleweb.lpr`, `oraclestatic.pas`, `graph.tests` `19/19`).
   - Updated `AGENTS.md` across Rounds 1–7 codifying `followup/research-status.tsv` and `verify-complete` while leaving all frozen `.tsv` and `.sha256` files in Rounds 2–7 completely untouched.
3. **Phase 2 — Deep Audit of Round 1 Priority-5 `body_match` Full Texts (`439` pairs):**
   - Cataloged 5 preclinical PD papers (`PMID:29576695` Ramkumar 2018 demethoxycurcumin, `PMID:30013404` Fahimi 2018 *Morus nigra* LID resolving *Rubus* homonymy, `PMID:32899274` Siracusa 2020 Hidrox olive polyphenol, `PMID:37484231` Liu 2023 curcumin dosage, `PMID:41878684` Mu 2026 curcumin nanoparticles).
   - Validated (`oracle_check_scorecard`) and batch-merged 7 `minimal_signal/eases` flips — unlocking **16th symptom `attention impairment`** ([0836](statements/0836.txt) toasted Sichuan pepper, `Maybe False`, `PMID:31835620`) and **17th symptom `dystonia severity`** ([0327](statements/0327.txt) ground cayenne pepper, `Maybe True`, `PMID:16258648`), plus `0117`, `0210`, `0348`, `0507`, and `0810`.
4. **Phase 3 — Exhaustive Live 2026 External Lab/Clinical Discovery across All 141 Round 1 Ingredients & 16 Zero-Directional Symptoms:**
   - Checked `74` live PubMed & ClinicalTrials.gov v2 identifiers via `oracle_find_sources` (`39/74` local hits; `16/16` PD nutrition trials with results already archived; `35` unarchived PMIDs screened via `efetch`).
   - Cataloged 11 newly surfaced primary papers (`PMID:21769642` Kabuto 2011 post-lesion oral zingerone/eugenol + L-DOPA contrary safety record added to `0778`; `PMID:27430236` Chompoopong 2016; `PMID:27752803` Malik 2016 *Nigella sativa* haloperidol EPS; `PMID:30159851` Haeri 2019 crocin; `PMID:34802467` Bohn 2021 `n = 60` double-blind null bilberry/red-grape pegboard RCT confirming `0712` open; `PMID:38903548` Kousha 2024; `PMID:39168304` Zhang 2024; `PMID:39294525` Hajji-Louati 2024; `PMID:41252180` Akhlaghi 2026; `PMID:41661604` Zhang 2026 JAMA; `PMID:42638917` Yang 2026 UK Biobank) and flipped `0503` (ground nigella seed / bradykinesia, `Maybe False 50.005`).
5. **Phase 4 — Exhaustive Cultural, Traditional & Experiential Expansion (`128 / 128` Mapped & Verified):**
   - Cataloged 8 peer-reviewed ethnobotanical, traditional, qualitative, and ceremonial records (`PMID:27544001`, `PMID:28088492`, `PMID:33246117`, `PMID:34031820`, `PMID:37532071`, `PMID:42059527`, `PMID:42047406`, `PMID:41071416`; deduplicating `PMID:42813362` against existing Cocks 2025 record) and 8 anonymized public Parkinson's UK forum conversations (2009–2026, zero personal identifiers/handles).
   - Verified `128 / 128` cultural files via `research.culture.exe . 2025` and mapped `128 / 128` (`100%`) cultural files into `experiments/tools/parkinsons-oracle/cultural-graph-topics.tsv`.
6. **Phase 5 — Complete 100% (`1,000 / 1,000`) Round 1 v1 Scorecarding & `Unknown (Researched)` Publication:**
   - Validated (`oracle_check_scorecard`) two final converging `minimal_signal/eases` flips: [0074](statements/0074.txt) (cold-pressed pumpkin seed oil / depression: Gossell-Williams 2011 `PMID:21545273` + 2024 chronic-stress rats, `Maybe True 50.005`) and [0551](statements/0551.txt) (dried shiso / insomnia: three independent rodent *Perilla* sleep studies incl. `PMID:33246117` + TCM insomnia context, `Maybe True 50.005`).
   - Atomically merged all `860` remaining claims via `foodexperiment.scorecardmerge.exe --batch` (`total_scorecards=1000`, `3,786` source rows, `status=recorded`) and published [followup/research-status.tsv](followup/research-status.tsv) (`total_frozen=1000`, `researched=1000`, `unknown_researched=930`, `unknown_unresearched=0`, `directional_researched=70`).

## Current verified state (Round 1 100% Exhaustively Researched)

- **Round 1 verdicts ([manifest.md](manifest.md), [research-status.tsv](followup/research-status.tsv)):**
  - **`1,000 / 1,000` (`100%`) checked v1 scorecards** (`3,786` source-family rows; `0` mismatches; `0` unscorecarded claims) and **`1,000 / 1,000` `researched`** (`unknown_unresearched=0`).
  - **`70` directional verdicts (`37` Maybe True, `33` Maybe False) across `17` Parkinson's symptoms** (`2` direct clinical signal, `3` limited clinical link, `65` minimal signal — `69` easing leans, `1` worsening lean).
  - **`930` `Unknown (Researched)`** (`tier=open`, `50`), verified across lab/clinical and cultural/experiential axes.
  - Round 1 freeze SHA-256 preserved verbatim: `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`. All 6 expansion freezes (`round_2`–`round_7`) verified untouched.
- **Research catalog, Nyx Web UI & Oracle coverage:** All newly added lab (`+16`) and cultural (`+16`) records indexed cleanly (`0` read errors) with `build/parkinsons-oracle/web/` (`app.js`, `graph.json` + `.gz`) synchronized via `experiments/tools/parkinsons-oracle/build.ps1 -RefreshCatalog` · `128 / 128` cultural files verified & mapped · `9,905` logged Oracle-first lookups across `450` batches (`experiments/oracle-coverage/`).
- **Native FPC & pas2js tooling (all checked suites passing with zero warnings):**
  - `experiments/tools/parkinsons-oracle/build.ps1` (Oracle + auto-synced Nyx Web UI; all 10 Oracle & UI test suites passing)
  - `experiments/1000_see_what_sticks_food/tools/build-researchstatus.ps1` (`10/10`)
  - `experiments/1000_see_what_sticks_food/tools/build-scorecardmerge.ps1` (`7/7`, including `--batch`)
  - `experiments/1000_see_what_sticks_food/tools/build-homographscreen.ps1` (`10/10`)
  - `experiments/1000_see_what_sticks_food/tools/build-roundtransfer.ps1` (`8/8`)
  - `experiments/1000_see_what_sticks_food/tools/build-pmcscreen.ps1` (`10/10`)
  - `experiments/1000_see_what_sticks_food/tools/foodexperiment.review.lpr` (`1..9999`)

## Suggested next priorities for Codex

1. **Merge or review `feature/trying-neon` into `master`** once the user signs off on this completed Round 1 milestone.
2. **Open Round 2 (`experiments/1000_see_what_sticks_food_round_2`)** upon explicit user sign-off (`series-work.md`); `foodexperiment.roundtransfer` already pre-maps `736 / 1,000` (`73.6%`) Round 2 claims to verified Round 1 evidence, and `followup/research-status.tsv` + `foodexperiment.researchstatus` + `foodexperiment.scorecardmerge --batch` are ready for immediate Round 2 execution.
3. **Monitor live clinical trials for posted results** that could shift Round 1 open or minimal-signal claims: `NCT07882108` (Ginger-PD), `NCT07213856` (NUTRI-GUT-PD), `NCT07097103` (PRIME), `NCT07214428` (Grape Powder), and `UMIN000055134`.
