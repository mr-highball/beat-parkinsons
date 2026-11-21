# Round 1 research handoff for Gemini Neon

**Checkpoint P156 · November 21, 2026 UTC**

Continue the evidence investigation across all 1,000 frozen Round 1 hypotheses. Review the [root instructions](../../AGENTS.md), [experiment instructions](AGENTS.md), and [evidence scorecard](EVIDENCE-SCORECARD.md) before changing any research records. Work in one agent. Round 1 comes before evidence review of later rounds.

The catalog additions are in commit `d0f03dfe0`. The review, manifest and exact coverage replay are in commit `987bb4dcb`.

## Current state

- The [manifest](manifest.md) records 939 Unknown, 27 Maybe True, 34 Maybe False, zero True and zero False. Unknown includes different levels of search and evidence coverage. The manifest and per-claim ledger show those differences.
- Claim [0188](statements/0188.txt), raw fig and Parkinson drooling, remains Unknown. The [P156 packet](followup/fig-drooling-2016-originals-nov20-156/README.md) covers seven original bodies, nine related assessments and the later Portuguese study's supplemental results. The [remaining original pairs](followup/fig-drooling-2016-originals-nov20-156/open-cluster-pairs.tsv) list 92 of the original 562 pairs, including 12 access or identity holds.
- The native replay has 41,490 original claim–source pairs queued across 26,071 distinct source keys. Oracle catalog revision 267 indexes 37,236 research files. The latest lookup batch found two exact local records across 17 first-pass questions. [Replay receipt](followup/context-coverage/replay-summary.txt) · [Lookup accounting](followup/fig-drooling-2016-originals-nov20-156/lookup-merge.txt)
- The historical scans record one binary ptyalism observation. The 2016 posture cohort measured angles, the 2017 Swedish registry rated drooling, and the 2026 Lisbon cohort measured both posture and saliva loss. The 2026 paper and its two supplements share a study family with likely overlap with the 2025 clinical reports. These sources do not compare raw fig exposure with a Parkinson drooling outcome. [Period observations](../../research/2015-2019/Observations/Posture-Wearables-and-Saliva-Outcomes.md)
- The native freeze verifier checked all 1,000 claims and the 2,000 historical query records. The freeze SHA-256 is `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`. Those historical queries do not exhaust the deeper review. [Exact coverage](followup/context-coverage/README.md) · [Assessment ledger](followup/assessments.tsv)

## First assignment

1. Use Oracle MCP first. Check `oracle_status`, call `oracle_evidence_rubric` for Round 1 claim `0188`, then run `oracle_query` with `ingredient: "fig"`, `symptom: "drooling"` and `scope: "assessed"`. Use `oracle_claim` with `assessment_limit: 8` or the exact `assessment_study` key to read the relevant ledger evidence. The [local launcher](../oracle-coverage/README.md#local-launcher) exposes the same methods when a client does not have the MCP server registered.
2. Resume with the eight priority-six 2015 provider-date rows in the [remaining claim queue](followup/fig-drooling-2016-originals-nov20-156/open-cluster-pairs.tsv). Use these exact keys to pin the set before browsing. `PMCID:PMC4591846`, `PMID:26260390`, `PMID:26324905`, `PMID:26411967`, `PMID:27340683`, `PMID:30363518`, `PMID:30363545`, `PMID:30713897`. Check archived texts with `oracle_find_sources`, then verify missing originals through lawful primary routes. The AES source is a collection, so verify the member boundaries and document the actual coverage. Use the publication details in each original to date new catalog files.
3. Carry forward the [open trails](followup/fig-drooling-2016-originals-nov20-156/open-trails.tsv), including the 2017 ANA proceedings and the older case tables. Record the original body, abstract, title or access-only depth for each source. Continue earlier years and other claims using the saved priority and follow-up records after this group. The eight sources are a starting checkpoint within the full investigation.

## Evidence and publishing workflow

For each claim, treat its direction as a premise to challenge. Search both directions and follow relevant citations and citing publications while they add evidence. Exhaust accessible provider pages and reconcile returned counts. Use complementary indexing sources, trial registries, synonyms, and relevant cultural or conversational searches. Distinguish missing or inaccessible evidence from opposing evidence.

Record who observed the result, the actual comparison, measurement and uncertainty, competing findings, preparation and population fit, and source family. A defensible directional lean qualifies for Maybe under the shared rubric. For a new or revised verdict, complete the scorecard and run `oracle_check_scorecard` before publication. Separately record related or excluded original-source matches without assigning a verdict on that basis.

Place new paraphrased primary-source text and registration records in the first public five-year bucket in [research](../../research). Link each from the period index and add observations when it changes the understanding of previous periods. Put tradition, first-person accounts and public forum summaries in their own [cultural and experiential folders](../../research/Cultural-and-Experiential.md). Preserve precise provenance, avoid personal identifiers, and record repeat citations under one study family.

Use the [native exact queue workflow](followup/context-coverage/README.md) to import verified pairs and replay coverage. Keep temporary downloads and generated full queues under the ignored build directories. Log one initial Oracle outcome per question in the [coverage ledger](../oracle-coverage/README.md). Rebuild the Oracle index after committing new catalog records. Validate the freeze, ledgers and manifest, and commit each verified checkpoint with a descriptive subject and body.
