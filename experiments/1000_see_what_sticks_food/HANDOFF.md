# Round 1 research handoff — post `feature/trying-neon`

**Milestone checkpoint · November 21, 2026 UTC**

Continue the Parkinson's evidence investigation across Round 1 and prepare the transition to Rounds 2–7. Review the [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), and [evidence scorecard](EVIDENCE-SCORECARD.md) before changing any research records. Work in single-agent mode unless delegation is explicitly requested. Use Free Pascal (FPC) first for all repository tooling, and query Parkinson's Oracle MCP before external discovery.

## Current verified state

- **Round 1 verdicts ([manifest.md](manifest.md)):** `951` Unknown, `23` Maybe True, `26` Maybe False, `0` True, `0` False across all `1,000` frozen statements (freeze SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`, verified intact).
- **V1 Scorecard completion ([scorecards.tsv](followup/scorecards.tsv), [scorecard-sources.tsv](followup/scorecard-sources.tsv)):** `96` checked version 1 scorecards spanning all `33` Parkinson's symptoms with **`0` unscorecarded directional verdicts** and **`0` ledger mismatches**:
  - `2` `direct_clinical_signal` (`55`): `0063` (ground saffron / depression, Maybe False), `0485` (dried saffron / fatigue, Maybe False).
  - `3` `limited_clinical_link` (`51`): `0082` (brewed black tea / bradykinesia, Maybe True), `0904` (brewed black tea / rest tremor, Maybe True), `0948` (brewed green tea / fatigue, Maybe True).
  - `44` `minimal_signal` (`50.005`): `20` Maybe True, `24` Maybe False across 12 symptoms — including newly unlocked `0916` (ground cinnamon / urinary urgency frequency, Maybe True) grounded in `NCT03532789` (Chen et al. 2020) and `PMC8716214`.
  - `47` checked `open` (`50`, `Unknown`) scorecards, including `13` legacy `51` claims downgraded on audit and `16` flagship audits across zero-directional symptoms.
- **Native FPC tooling built & verified:**
  - `parkinsons-oracle` (catalog revision `269`, `37,239` indexed files, `0` read errors): supports `oracle_backlog`, `include_culture` compact mode, precomputed v1 `scorecard_status` filters, and fast Windows hierarchical feature-branch HEAD pinning (`~0.5–1.1 ms`).
  - `foodexperiment.scorecardmerge` (`5/5` tests): atomic FPC merger for `scorecards.tsv`, `scorecard-sources.tsv`, and `verdicts.tsv`.
  - `foodexperiment.homographscreen` (`10/10` tests): precision-first full-text homograph collision verifier (`date`, `fig`, `sage`, `orange`; `0` genuine food false exclusions across `2,399` reviewed benchmark pairs; `31` newly queued archived collisions reconciled) plus read-only `triage-abstract` lead finder (`19` unarchived botanical-term leads surfaced).
  - `foodexperiment.review` (1,000-claim balanced Round 1 + 930-claim unbalanced Round 7 synthetic fixtures passing): generalized from hardcoded `1000` / `125x8` to dynamic freeze-derived claim counts (`1..9999`), ready for Rounds 2–7 (`5,930` additional frozen claims across `6,930` total).
  - `research.culture`: `112/112` cultural/experiential records pass validation cleanly.
- **Exact context overlay & Oracle coverage:** `41,459` queued original pairs across `26,043` sources (`0` P1, `0` P2, `12` P3, `1,738` P4, `3,152` P5, `36,557` P6; `19,440` `body_or_primary_context_reviewed`). Oracle coverage ledger logs `8,861` first-pass questions across `437` batches. [Replay receipt](followup/context-coverage/replay-summary.txt) · [Coverage ledger](../oracle-coverage/README.md)

## Next high-value runway

1. **Triage the 19 unarchived botanical-term leads** surfaced by `foodexperiment.homographscreen triage-abstract` (`Salvia`, `orange juice`, `hesperidin`, `citrus`, `ziziphus` across `date`, `sage`, `orange`, `fig`), using Oracle MCP first and retrieving lawful primary full texts where unarchived.
2. **Clear remaining Priority 3 (`12` pairs) and non-homograph Priority 4 (`1,738` pairs) Europe PMC clinical leads** via `oracle_backlog` and `followup/context-coverage/README.md`, prioritizing clinical studies across the `21` currently zero-directional symptoms (`apathy`, `attention`, `daily off time`, `daytime sleepiness`, `dream enactment`, `drooling`, `dyskinesia`, `dystonia`, `falls`, `freezing of gait`, `hand dexterity`, `low voice volume`, `muscle rigidity`, `olfaction`, `orthostatic lightheadedness`, `postural instability`, `reduced facial expressiveness`, `shortened stride`, `small handwriting`, `speech intelligibility`, `visual hallucinations`).
3. **Monitor recruiting/pending clinical trials** for primary result publication: Ginger-PD (`NCT07882108`), NUTRI-GUT-PD (`NCT07213856`), PRIME (`NCT07097103`), `NCT07214428`, and `UMIN000055134`.
4. **Launch Rounds 2–7 evidence review (`5,930` claims)** once Round 1 non-homograph high-priority leads are resolved, starting with Oracle-first cross-round evidence transfer and using the now-generalized `foodexperiment.review` and `foodexperiment.scorecardmerge` toolchain.

## Evidence and publishing workflow

1. Start every evidence-review session with `oracle_status`, `oracle_backlog`, and `oracle_evidence_rubric`, then query `oracle_query`, `oracle_claim`, `oracle_find_sources`, `oracle_search_catalog`, and `oracle_read_source` before web search.
2. Treat every claim direction as a premise to test in both directions. Validate every new or revised verdict via `oracle_check_scorecard`, merge atomically via `foodexperiment.scorecardmerge`, apply/verify/summarize via `foodexperiment.review`, and log first-pass lookup outcomes via `oraclecoverage.merge`.
3. Place new paraphrased primary-source records in the earliest public five-year bucket under [research](../../research) and cultural/experiential records under `Cultural-and-Experiential/`, verifying `research.culture` and rebuilding the Oracle catalog after every catalog commit.
4. Preserve all frozen hashes (`freeze.sha256`), avoid personal identifiers in public files or commits, and keep temporary downloads and build outputs inside ignored `build/` directories.
