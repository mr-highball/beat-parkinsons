# Agent & Contributor Guidelines

This document defines high-level repository layout, toolchain bootstrap, submodule policy, research methodology, and publication standards for contributors and coding agents working in `beat-parkinsons`.

## Repository layout

| Path | Purpose |
| --- | --- |
| `research/` | Chronological Parkinson’s literature and cultural/experiential archive bucketed into 5-year windows (`1595–1599`, `1660–1664`, and continuous `1865–1869` through `2025–2029`), plus Python retrieval and cataloging scripts. |
| `experiments/1000_see_what_sticks_food` (and `_round_2`..`_round_7`) | Frozen food-and-symptom claim experiments (6,930 claims across 7 rounds), SHA-256 freeze files, verdict ledgers, evidence scorecards, and per-claim assessment tables. |
| `experiments/1000_see_what_sticks_food_all_recipes/` | Shared JSON recipe store (`parkinsons-oracle-recipes-1`) backing the Parkinson’s Oracle recipe browser and printable recipe sheets. |
| `experiments/oracle-coverage/` | First-pass Oracle lookup coverage ledger and batch hit-rate summaries. |
| `experiments/tools/parkinsons-oracle/` | Native Free Pascal MCP stdio server, SQLite FTS5 catalog indexer, WFC claim/recipe models, unit tests, and Nyx/`pas2js` browser web application (`web/`). |
| `experiments/tools/vendor/wfc/` | Pinned Git submodule for the Wave Function Collapse constraint solver (`mr-highball/wfc`). |
| `experiments/tools/vendor/nyx/` | Pinned Git submodule for the UI, modal, canvas, and browser renderer (`mr-highball/nyx`). |
| `scripts/` | Cross-platform toolchain bootstrap scripts (`bootstrap.ps1` for Windows, `bootstrap.sh` for Linux/macOS). |
| `build/` | Ignored local compiler outputs, pinned `pas2js` build, SQLite catalog database, and static site staging artifacts. |

## Submodules

The repository pins two external Free Pascal libraries as Git submodules:

- `experiments/tools/vendor/wfc` — deterministic WFC constraint solver used by the claim decision table, blind statement generator, and multi-ingredient recipe selector.
- `experiments/tools/vendor/nyx` — UI and browser canvas/modal framework transpiled via `pas2js`.

Initialize both before building or testing:

```bash
git submodule update --init --recursive -- experiments/tools/vendor/wfc experiments/tools/vendor/nyx
```

Treat vendored submodules as pinned upstream dependencies. Do not modify files inside `experiments/tools/vendor/*` to work around application-level issues; adapt application code under `experiments/tools/parkinsons-oracle/` or update the submodule pin deliberately against an upstream commit.

## Toolchain bootstrap & verification

Bootstrap the toolchain from the repository root before building, running tests, or launching the Oracle:

- **Windows (PowerShell):**
  ```powershell
  ./scripts/bootstrap.ps1 -RefreshCatalog -RunTests
  ```
  Pass `-InstallFpc` if Free Pascal is not yet installed locally; verified FPC 3.2.2 and the pinned SHA-256-verified `pas2js 3.3.1` compiler are placed under the ignored `build/parkinsons-oracle/` directory.
- **Linux / macOS (Bash):**
  ```bash
  ./scripts/bootstrap.sh --run-tests
  ```
  Builds the pinned `pas2js 3.3.1` toolchain, runs all 7 strict portability unit tests, and builds the Nyx web bundle. (The local SQLite FTS5 / MCP server executable currently links Windows `winsqlite3.dll`.)

Before committing code or recipe changes:

1. Compile and run all portability unit tests with strict Free Pascal checks (`-Mdelphi -Sa -Cr -Co -Ci -gl`): `compat.tests.lpr`, `graph.tests.lpr`, `presentation.tests.lpr`, `selection.tests.lpr`, `rubric.tests.lpr`, `ingredients.tests.lpr`, and `recipes.tests.lpr`.
2. Rebuild the web bundle (`experiments/tools/parkinsons-oracle/build.ps1` on Windows or `./scripts/bootstrap.sh` on Linux/macOS) and verify zero compiler/console errors.
3. Keep all temporary downloads, compiled binaries, SQLite indexes, and scratch artifacts inside ignored `build/` directories.

## Oracle-first research workflow

Use [Parkinson’s Oracle](experiments/tools/parkinsons-oracle/README.md) as the first knowledge base for every evidence question before broad filesystem scans or external web searches (during blind hypothesis generation, use only experiment inputs):

- Call `oracle_evidence_rubric` at the start of an evidence review session for the current rubric version, tier anchors, and TSV rules, and look up the claim's current published record (`round`, `id`) before rerating.
- Start claim evidence lookups with `oracle_query` (`scope: "assessed"`) and `oracle_claim` (`assessment_limit: 8` for triage, or exact `assessment_study` for one study key). Use `oracle_find_sources` for batch exact-ID lookup (PMID, PMCID, DOI, NCT, ACTRN, ISRCTN, IRCT, DRKS, UMIN, TCTR), `oracle_search_catalog` for citation trails and alternate terms, and `oracle_read_source` to inspect archived texts.
- For cultural, traditional, and experiential material, start with `oracle_search_catalog` using `source_kind: "cultural"` or `source_kind: "conversations"`, then search externally for unresolved perspectives.
- Validate every proposed or updated verdict with `oracle_check_scorecard` before committing, and verify the committed record through MCP afterward.
- When a managed MCP connection lacks a needed tool or schema update, invoke the same read-only tools via the [local launcher](experiments/oracle-coverage/README.md#local-launcher).
- Record first-pass lookup outcomes (`hit`, `partial`, `miss`, `unavailable`) in the [coverage ledger](experiments/oracle-coverage/README.md), distill verified material source gaps into indexed chronological text records, and refresh the catalog index after committed archive updates.

## Inclusive evidence collection

- Apply the [evidence scorecard](experiments/1000_see_what_sticks_food/EVIDENCE-SCORECARD.md) in every round. Any defensible directional lean qualifies for a `Maybe` verdict; record observed direction, competing evidence, and transferability to the frozen exposure and symptom.
- Collect cultural and traditional practices, ceremonial accounts, local knowledge, and public personal reports alongside formal studies, preserving favorable, unfavorable, and no-benefit accounts under each period’s `Cultural-and-Experiential/` directory per [Cultural-and-Experiential.md](research/Cultural-and-Experiential.md).
- Place relevant public forum discussions under `Cultural-and-Experiential/Conversations/` with the original thread locator, explicit date basis, and a privacy-safe summary of observations.
- Distinguish publication date from claimed historical age, and separate source kind, authenticity, symptom specificity, and efficacy uncertainty. Traditional or personal accounts carry lower evidential weight for treatment effects than controlled clinical studies; documenting an account does not establish efficacy.
- Preserve frozen experiments. Never mutate frozen claim wording, pair vocabularies, or `.sha256` freeze proofs; cross-link reusable cohorts rather than duplicating them.
- Keep findings, `Unknown (Researched)`, and unreviewed questions visible by default in public views with clear labels and explicit filters—never silently exclude unresolved material.

## Commits & publication privacy

- Commit verified research, recipe, and code updates incrementally with descriptive subjects and clear summaries of source additions, verdict changes, or open evidence gaps in the commit body.
- Keep personal identifiers, local machine paths, private network addresses, and untracked personal files out of tracked sources, generated search assets, dependency notices, and Git history. Pass local network bindings strictly via runtime arguments. Verify all modified files before pushing or publishing.
