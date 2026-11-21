# Parkinson’s oracle

The oracle is a local Free Pascal MCP server for the Parkinson’s research catalog and food experiments. Use it to retrieve assessed claims, inspect conflicting evidence and find local documents before opening more web searches.

## Evidence review rules

Call `oracle_evidence_rubric` once at the beginning of evidence review. With no
arguments it returns the rubric text, its version, the pinned Git revision,
and structured tier anchors, TSV columns, accepted field values and source kind
constraints. Each `minimum_source_tier` is a structural prerequisite. The rules
explain the additional judgments needed before selecting a tier. Use
`include_rules: false` for the compact structured reference after reading the
rules. The draft checker uses the same anchors and column definitions.
Send both `round` and `id` to see the published verdict, scorecard, source-family
rows, and counts by direction and source kind. A claim lookup omits the full
rubric by default. Set `include_rules: true` to include it alongside the claim.

A `recorded` status means the rubric version, required source fits, expected
verdict and score agree with the published data. `no_scorecard` means the
current rubric has yet to be applied in the ledger. `historical_scorecard`
identifies an earlier rubric version, and `verdict_mismatch` flags a discrepancy
with the published verdict or score. Search coverage and efficacy remain separate
review questions. [Canonical rubric and ledger format](../../1000_see_what_sticks_food/EVIDENCE-SCORECARD.md)

Use `oracle_check_scorecard` before handing off or publishing a proposed verdict.
Pass the `revision` returned by the claim lookup and the claim's draft tables as
`decision_tsv` and `sources_tsv`. Each string includes its TSV header. Supply one
decision row and only that claim's material source-family rows. An open claim
with no material families uses the source header alone. A `valid_draft` returns
the expected verdict, score anchor and family counts for that frozen hypothesis.
The check uses the same tier prerequisites as the published lookup. Reviewers
remain responsible for source fidelity, competing evidence and completeness.
Keep opinions, secondary reports, result-free records and customary use as
context. Grade any traceable underlying observation under its own evidence family.
After a revision conflict, fetch the current claim and reconcile the draft before
retrying. When the managed session has an earlier tool list, use the
[local launcher](../../oracle-coverage/README.md#local-launcher).

## How the lookup works

- Symptom and ingredient postings narrow a request to candidate claims. Each experiment supplies canonical words and aliases. The oracle verifies each round’s freeze hash and reads claims and assessments from one Git commit.
- The claim index solves the WFC identity, hypothesis and evidence passes once for all eight input combinations. Each lookup evaluates the three inputs for its candidates and applies the solved decision table. Every combination has one valid decision, independent of seed. The same decisions determine evidence scopes in the static model.
- SQLite FTS5 keeps a separate inverted index of local Markdown, text and TSV files under `research/`. Its matches are document leads. It returns short local locators with the index snapshot and coverage.
- Direction filters the original hypothesis wording. A Maybe verdict preserves the recorded weak lean and rationale. Maybe False records a lean in the opposite direction. A definitive False verdict carries only the challenge to the original claim.

## MCP tools

| Tool | Input example | Result |
| --- | --- | --- |
| `oracle_query` | `{"symptom":"tremors"}` | Directional local matches, candidate count, assessment counts and a first citation |
| `oracle_ingredient_effects` | `{"symptoms":["constipation","tremors"]}` | All 210 ingredients grouped by easing, worsening, mixed evidence, or no clear direction, with preparation and references for directional findings |
| `oracle_claim` | `{"round":1,"id":"0904","assessment_limit":8}` | Frozen statement, verdict and rationale, citations, queue counts, and a page of assessments |
| `oracle_claim` with a study key | `{"round":1,"id":"0121","assessment_study":"PMID:37294324"}` | Assessments for that exact study key and the same claim-wide metadata |
| `oracle_evidence_rubric` | `{}` or `{"round":1,"id":"0904"}` | Canonical review rules or a specific claim's applied tier, observed direction, and source families |
| `oracle_check_scorecard` | `round`, `id`, `revision`, `decision_tsv`, `sources_tsv` | Validate one proposed verdict and calculate its anchor and verdict from the frozen direction before publication |
| `oracle_search_catalog` | `{"terms":"black tea tremor","period":"2010-2014","limit":8}` | Ranked local documents containing the requested words |
| `oracle_find_sources` | `{"identifiers":["PMID:40647065","NCT04986982"]}` | Every archived document whose source metadata matches each supplied identifier |
| `oracle_read_source` | `{"path":"research/2025-2029/Cultural-and-Experiential/Conversations/2025-Reddit-Coffee-Tea-Energy-and-Tremor.txt"}` | Indexed UTF-8 source text, with a byte cursor for longer documents |
| `oracle_status` | `{}` | Published claim revision, assessed, unreviewed and v1 scorecard counts, and the text index’s coverage and refresh record |
| `oracle_backlog` | `{}` | Review backlog across all rounds: directional claims awaiting v1 scorecards, scorecard mismatches, per-round counts and zero-directional symptoms |
| `oracle_filter_options` | `{}` | Canonical symptom, ingredient, and preparation choices, with their aliases |

Query scope defaults to `directional`, which requires a True, False, Maybe True or Maybe False verdict with a nonpending assessment. Use `assessed` to inspect records with at least one nonpending assessment, including Unknown, or `frozen` to include hypotheses still awaiting review. Filter by the canonical `preparation`, `round`, `direction`, `verdict`, or `scorecard_status` (`recorded`, `no_scorecard`, `historical_scorecard`, `verdict_mismatch`) as needed. Pass `include_culture: false` on `oracle_query` or `oracle_claim` to omit the `culture_sources` array when inspecting study ledgers or paging assessments without repeating cultural summaries. Results use stable round and claim-ID order. Follow `next_offset` to page through larger result sets.

The numeric `confidence` field is a reviewer score. A defensible lean such as 50.005 qualifies for a Maybe verdict. The symptom effect follows the finding relative to the frozen hypothesis, so Maybe False on a worsening hypothesis can appear under “May ease”.

Use `{"symptom":"tremors","trend":"eases"}` to look up evidence that may point toward relief. Set `trend` to `worsens` for evidence of worsening. The trend uses the card arrows, which require support for the claim being tested. Evidence against a claim leaves the opposite effect open. The `direction` filter applies to the original hypothesis wording.

Use `oracle_claim` for the relevant study outcomes and access gaps. If the claim search is empty or the evidence is unresolved, search the text catalog with alternate spellings, preparation names or endpoint terminology. A lexical hit needs source-level review. A gap in the indexed catalog is a reason to continue discovery, with the index timestamp and its read errors in view.

The shortcuts `hallucination`, `hallucinations` and `seeing things` select
visual hallucination frequency, the outcome in the frozen claims. The
response gives the canonical outcome. Use catalog search for other modalities.

### Exact source identifiers

For known identifiers, send up to 100 PMIDs, PMCIDs, DOIs, NCT IDs or trial IDs
from ANZCTR (ACTRN), ISRCTN, IRCT, DRKS, UMIN and the Thai Clinical Trials Registry
(TCTR) to `oracle_find_sources`. Bare numeric identifiers are PMIDs. Each result
includes the normalized identifier and matching paths in sorted order.
Results follow the input order, including identifiers with zero archive matches.
The three additional registries require a matching source filename, an exact
registration field or leading ID, and the official registry address in the
source header. Use text search for other archives and citation trails.
The tool indexes leading publication metadata from `Source-Text` text files and
matching registry provenance from `Source-Text/Trials` exports. Dated cultural
text files also support exact publication lookup when their leading metadata
includes a matching PMC, PubMed or DOI source URL. A match can be a curated
extract or collection, so confirm the actual source and its depth. Use full-text
search for citation mentions, conversations and archives without structured
publication metadata.

UMIN extracts require the matching nine-digit UMIN identifier in recognized leading
provenance and an official UMIN record URL. Receipt numbers beginning with `R` are
separate from the trial ID. A filename and receipt URL alone leave identity open.
Results and status companion extracts return under the same identifier. Each path
retains its own publication period and coverage.

### Study assessments

For a known study, send `assessment_study` with its case-sensitive ledger key and omit the paging arguments. The result reports `matching_assessments` and returns all rows for that key in ledger order. A found claim can have zero matches. The rationale, citations, verdict and coverage counts still apply to the whole claim.

Omit the study key and both assessment paging arguments to return the full evidence list in one reply. With paging, `assessment_limit` accepts 1–100 rows and defaults to 8 when only `assessment_offset` is supplied. Results keep ledger order and include the full claim rationale, verdict references, assessment counts and queue counts. Pass `next_assessment_offset` as the next `assessment_offset` until it is null. If the claim revision changes, start again at offset 0. Check all relevant pages for supporting, opposing and pending evidence.

### Cultural and conversational lookup

Claim lookups and symptom or ingredient queries include a `culture_sources` array in the same response. Each record supplies a local path, its source kind, the available date and original URL, a short summary, and the account’s stated limits when recorded. The `ingredient_match` and `symptom_match` flags identify the matched topics. The account's recorded direction and the study verdict retain their own fields. Catalog lookup also returns a `cultural` metadata object for each matching account.

The [cultural graph topic table](cultural-graph-topics.tsv) connects reviewed accounts to the existing ingredient and symptom vocabulary. Link labels describe the topic discussed, which can be broader than the exact preparation or symptom in an experimental claim. All committed cultural text records enter the graph, including accounts awaiting topic annotation. Open any cultural catalog card's connections to read the account and follow its available topics.

Use `oracle_search_catalog` before broader file searches or web discovery. Search by source category and use the text terms for the exposure or outcome.

| `source_kind` | Indexed collection |
| --- | --- |
| `all` (default) | Entire text catalog, including notes and citation trails |
| `cultural` | Dated UTF-8 text records across the cultural and experiential categories |
| `conversations` | Reddit, Parkinson’s UK and other community discussions |
| `traditional_practices` | Traditional remedies, practitioner texts and ethnobotany |
| `ceremonial_accounts` | Ritual, prayer and ceremonial contexts |
| `personal_reports` | Individual accounts and patient-reported experience |
| `local_knowledge` | Other local accounts, practices and explanatory beliefs |
| `source_text` | Archived source texts, including study papers and registry records |

Search for tremor-related cultural records with `{"terms":"tremor","source_kind":"cultural","limit":20}`. To find 2025–2029 conversations about coffee and tremor, use `{"terms":"coffee tremor","source_kind":"conversations","period":"2025-2029","limit":20}`. Category follows the dated catalog path. Period, totals and pagination apply within the selected category. Searches across all categories also include collection indexes and observations.

Results give the local text path and period. Pass the exact `path` to `oracle_read_source` to check the source, date basis, reported outcome and limits. The reader returns up to 16 KiB of UTF-8 text at a time. Pass the returned `next_offset` as `offset` until there is no next cursor or you have the relevant passage. The reader requires an indexed research path and detects files changed since indexing. Refresh the catalog before retrying a changed source.

Continue with the original sources or external discovery for unresolved questions. Catalog matches carry no claim verdict. Keep the initial lookup and later retries under one evidence question in the [coverage ledger](../../oracle-coverage/README.md). Use its [local launcher](../../oracle-coverage/README.md#local-launcher) when the session’s cached tool schema lacks the category filter or source reader. A fresh MCP connection advertises both.

The [native catalog fixtures](catalog.sourcekinds.tests.lpr) cover every category, period and page filters, and the effect of a refresh on cached results and exact publication identifiers. Run the compiled fixture with a fresh directory under the ignored build output.

## Build and connect

From the repository root in PowerShell:

```powershell
git submodule update --init -- experiments/tools/vendor/wfc
& ./experiments/tools/parkinsons-oracle/build.ps1 -Compiler 'path-to-fpc' -RefreshCatalog
```

The Windows build uses native Free Pascal and system SQLite with FTS5 contentless deletion support (SQLite 3.43 or later). Set `FPC` or install it on PATH to omit the compiler argument. Results, compiler output and the SQLite database live under `build/parkinsons-oracle/`, which Git ignores. The WFC submodule pins the solver version.

The repository includes project MCP configuration for a trusted Codex workspace. For a machine-level registration, use the built program and the absolute repository path:

```powershell
$OracleBinary = (Resolve-Path ./build/parkinsons-oracle/bin/parkinsons-oracle.exe).Path
codex mcp add parkinsons-oracle -- $OracleBinary serve (Get-Location).Path
codex mcp get parkinsons-oracle
```

Codex reads MCP configuration at session startup. The server uses newline-delimited JSON-RPC over stdio. It makes local reads and leaves research files untouched. [Codex MCP setup](https://developers.openai.com/codex/mcp) · [MCP stdio protocol](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)

## Refresh

The server reloads claim data when the repository’s committed revision changes. An in-progress evidence review stays in the working tree until publication.

Each reload resolves the committed revision, checks which evidence tables exist and reads the round files with one Git batch process. Required files and tracked evidence tables must be readable. The loader hashes the exact committed freeze bytes for every round.

On Windows, repeat claim lookups can confirm an ordinary loose branch by comparing its current HEAD, ref and repository configuration bytes with a Git-verified snapshot. Changed files, packed-only refs, detached HEADs and linked worktrees use a fresh Git revision check. The shortcut has no time-based freshness window.

Refresh the text index after adding local research. This reuses the existing index and checks the local inventory for changes:

```powershell
& ./build/parkinsons-oracle/bin/parkinsons-oracle.exe index (Get-Location).Path
```

The catalog refresh records its own timestamp and failed reads. Check `oracle_status` before treating the index as current.
Refresh also installs the read-error index in existing catalogs. This avoids scanning every indexed document for the diagnostic count on each search.
The first refresh after adding `oracle_find_sources` builds the source identifier
index. Later refreshes update identifiers from changed documents in the same
transaction as the full-text index. If a legacy executable refreshes the catalog,
run `index` with the current build before using `oracle_find_sources` again.
A refresh backfills verified ClinicalTrials.gov extracts with older header
formats. The first refresh with TCTR support also indexes Thai trial extracts
whose leading metadata identifies the same trial as their filename using a
direct official record or XML URL.

The local server retains up to four recent catalog searches, each with its total and up to 100 ranked rows. Return to a result page after checking citations and the server can reuse those rows if the search expression, period and catalog revision agree. A new catalog revision invalidates both ranked results and empty searches. The server reads current catalog diagnostics on every lookup.

### Local performance checks

On catalog revision 17 and the claim snapshot at `465998da`, round 1 claim 0290 had
142 assessments. Selecting its `Yamamoto JSMCN 2024 O-244` row reduced MCP tool
text from 67,547 to 3,062 UTF-8 bytes. The selected response kept the claim-wide
verdict, citations and counts. Measure the decoded tool text when comparing
payloads. These sizes do not measure model tokens.

On the same catalog, the unfiltered term `Parkinson` matched 32,411 documents.
At eight results per page, the warm median for the first adjacent page fell
from 104.2 to 4.4 ms across nine repetitions. The initial page took about
104 ms before and 102 ms after. The timed runs used the same index and compared
the returned text, including total and next offset. A separate refresh check
confirmed that already-running servers observed changed results after a new revision.

On catalog revision 20, the `Parkinson` search matched 32,413 documents. After
three intervening searches (`31211448`, `black tea` and `PMC8345445`), returning
to the next eight results took a median of 96.46 ms with one retained search and
0.52 ms with four. The 2020–2024 search fell from 88.42 to 0.96 ms. Each median
covers nine warm local MCP calls against the same snapshot. The compared tool
replies were byte-identical. A separate refresh fixture checked ranking, a
previously empty search and live read-error diagnostics. These timings measure
local lookup latency. Response size is identical across the two versions.

On catalog revision 23, a ten-PMID original-source batch took ten full-text
searches at three results per page. Those calls returned 4,139 UTF-8 bytes of
decoded tool text and 18 lexical matches. The exact archive batch took one call
and returned 930 bytes with three source paths. Across 11 warm local MCP runs,
the median batch time fell from 9.07 ms to 0.73 ms. The existing full-text tool
returned byte-identical results on the same snapshot. A separate migration
fixture verified that citation mentions do not qualify as archive IDs and that
running servers see changes, deletions and read errors after refresh.

Across catalog revisions 34 and 35, an exact registry lookup with a text-search
fallback was replaced by one exact batch. Both builds used the same 34,790
documents. The four-ID fixture fell from 1,318 to 761 UTF-8 bytes of decoded
tool text. The median of 11 warm runs fell from 2.03 to 0.70 ms. A sweep of
5,400 NCT-named candidates found 5,297 exact paths, up from 5,099. It recovered
106 of 140 older-format candidates and retained every previously returned path.

Broad symptom-effect searches use claim IDs grouped by recorded trend in the
pinned claim index. They still apply the requested evidence scope, preserve
round and claim order, and return the requested page and exact total. The
local browser requests eight claims at a time. Claim lookups and catalog
requests use separate locks, so a cold catalog or a source search can finish
independently of a claim page. When a live claim page times out, the browser
offers a retry after ten seconds.

In a controlled HTTP check, an exclusive lock on a throwaway catalog held
status for about 2.3 seconds in both versions. The eight-row May ease page
fell from 2,062 ms to 33 ms and arrived before the lock was released. All
48 compared MCP responses were byte-for-byte equal across pages, scopes
and additional filters. Across 100 warm MCP runs per build, median response
time for the first May ease page fell from 1.10 ms to 0.74 ms. The served
JavaScript was 2.2 MB with gzip in the live build. A mobile Chromium run
returned the first page in about half a second after submission and verified
paging, claim details, the graph and retry after an interrupted search.

On commit `f7d48e7b4` (catalog revision 267, hierarchical branch `feature/trying-neon`),
adding `include_culture: false` reduced `oracle_query` (`fig`, `drooling`, `assessed`, `limit: 5`)
from 15,782 to 1,530 decoded UTF-8 bytes (-90.3%) and `oracle_claim` (`round: 1`, `id: "0188"`,
`assessment_limit: 8`) from 19,183 to 4,931 bytes (-74.3%) while preserving exact `options`,
`assessments` and result order. Supporting hierarchical loose branch refs in the Windows HEAD
pin cut warm median lookup latency across 11 repetitions from 28.13 ms to 1.11 ms (`include_culture: true`)
and 0.54 ms (`include_culture: false`). `oracle_backlog` returned the live 7-round backlog
(18,977 bytes) in 3.37 ms median. Verified with [backlog fixtures](backlog.tests.lpr).

## Compare ingredients across symptoms

Select one or more symptoms and choose **Compare ingredients** from the results or graph. The comparison includes all ingredients for the selected symptoms and keeps the exact preparation beside each finding. **May ease** and **May worsen** group ingredients with one recorded direction across the selection. **Mixed effects** keeps ingredients with both directions together. **No clear direction** lists remaining ingredients, with a name filter and access to each gallery. Use **See evidence** to open the reviewed claim, its rationale and studies. An unresolved symptom remains open even if the ingredient has a directional finding for another symptom.

The `oracle_ingredient_effects` MCP tool accepts canonical symptom names and their recognized aliases. Repeated aliases resolve to one symptom. Its `may_ease`, `may_worsen` and `mixed` arrays contain ingredient groups with preparation-specific `findings` and the selected `unresolved_symptoms` for that ingredient. The top-level `unresolved` lists all remaining ingredient names. `ingredient_count` counts the complete vocabulary and `directional_ingredient_count` counts the ingredients with a directional finding. The top-level `unresolved_symptoms` lists selected symptoms with no directional finding from any ingredient. Use each finding's `round` and `claim_id` with `oracle_claim` to review the underlying evidence. The grouped view uses the published verdict and evidence trend. Opposing a proposed direction without evidence of an inverse effect leaves the direction open.

The live server and portable browser use the same Pascal grouping code. The comparison is an evidence lookup for ingredient selection. Effects of combined ingredients and finished recipes remain separate research questions.

### Ingredient photos and shopping tips

Search result cards include a small ingredient photo. Tap it to open the carousel in the same card. The carousel is also available in claim details, ingredient comparisons and ingredient nodes in the graph. Swipe or use the arrow buttons to browse the two culinary preparations. Tap a photo to enlarge it in place. The Shopping tip banner expands to show the full shopping or storage tip and its source.

All 210 canonical ingredients have a gallery, including ingredients with no clear direction in the comparison. The web builder derives a 128 × 128 JPEG for each ingredient from its first gallery frame. The carousel uses the full-size photos. Real photos include public-domain credits and generated illustrations are labeled. [Photo provenance, coverage and prompts](web/assets/ingredients/README.md).

## Browser interface

The browser initially includes all findings, Unknowns and frozen questions awaiting review. The All research, Studies & analyses, and Culture & experience tabs separate source collections without treating a reported practice as a verified effect. Source documents outside the frozen ingredient list appear alongside the claim results. Unreviewed directions remain hypotheses, and effect filters apply to graded claim cards.

Cultural and personal records have their own styling and original line glyph, with source type, date, reported experience and uncertainty in the text record. The collection follows the [cultural and experiential policy](../../../research/Cultural-and-Experiential.md). Older source material still awaiting cultural curation remains discoverable in All research and Search sources. A collection gap does not establish absence of a practice.

Public forum summaries appear in Culture & experience and Search sources with a Conversation badge and chat-bubble glyph. The live reader links to the original article or discussion when the archived header supplies a web address. Web addresses in the visible source text are also clickable and open in a new tab. The portable model links to the archived record through the configured repository.

Source-kind paging examines catalog batches until the page is filled or the result set ends. A nonmatching batch does not close the search, and cursor positions retain unconsumed rows. The shared Pascal presentation unit has native fixtures for source classification, query terms and pagination boundaries. Browser assets use Nyx and the web target. Fourteen distinct [imagegen glyph masters and their prompts](web/assets/glyphs/README.md) supply the navigation, research tabs, evidence indicators and helper controls. The native build embeds lossless alpha masks into the stylesheet, so portable builds need no image endpoint.

The Nyx web target uses the same claim and catalog service as MCP. The local workbench offers common symptom pills, a browse list and suggestions for symptoms, ingredients and preparations. Under Symptom effect, choose May ease, May worsen, or Any trend before searching. The filters match the arrows on the cards. May ease and May worsen can search across all symptoms with the ingredient and symptom fields blank. Each result identifies its symptom and opens its study assessments and citations. Claim results appear as soon as they are ready. Related sources load below them while the visible cards remain in place. The local server binds to the loopback address by default. The local web build also prepares gzip copies of the scripts and stylesheet. The server uses them for browsers that accept gzip and can serve the original files on their existing URLs.

Choose multiple symptom pills to find research for any selected symptom: Tremors **or** Pain, for example. Adding a symptom keeps the previous pills. Clicking a selected quick choice or its removal pill removes only that symptom. Typing another symptom keeps the current selection. Ingredient, preparation, evidence scope and effect filters apply to each selected symptom before the results are combined.

The browser's shared OR adapter supports both the live API and the portable static model. It follows every claim page for each symptom, merges by round and frozen claim ID, sorts in stable round/ID order, then paginates the union. Related catalog leads are interleaved across symptoms and deduplicated by document path, with lazy batch loading and cached previous pages. A merged source page reports its page count rather than adding overlapping per-symptom totals. New searches reset these caches. In-flight replies from superseded searches and mixed revisions are rejected; a completed merged query remains a snapshot until the next search. Single-symptom and MCP API requests retain their existing schema.

The [selection fixtures](selection.tests.lpr) run natively and after transpilation. The [transport fixtures](web/multi.tests.lpr) cover OR union, common filters, duplicates, later pages, source-kind filtering, revision changes and incomplete backend pagination. The optional [live probe](web/multi.live.lpr) takes the local API URL as its runtime argument and exercises the production adapter. These checks do not substitute for visual mobile-browser review.

In Search sources, choose Open source to read the indexed file as text. Long documents have Previous part and Next part controls. Back to results restores the catalog page you were reading.

Study titles and saved references in claim details are clickable. The live app opens the local text reader and returns to the claim afterward; portable builds open the configured repository citation. Reference fragments are retained in portable links and removed from live reader file paths.

Choose **Graph view** from symptom and ingredient results or **See connections** on a claim or a catalog source. A claim can open the graph at its ingredient or a specific study. The live reader can also open the graph for a saved source. Back returns to the view that opened the graph, including when a second graph is opened from a source or claim. Portable source links open the configured repository in a separate tab.

The Nyx canvas arranges entities in symptom, ingredient, study, saved-source and cultural-account groups. Each group uses a distinct glyph and shaded card. Selecting a node highlights its connections and leaves the surrounding links visible. Links fan out from separate points along each card, and diamonds and arrows mark the start and destination of highlighted evidence links. Select any node to explore its recorded connections in either direction. The list below the canvas has one card per connected item, with all its assessments and counts for each group. Use the previous-node button to retrace a link, or **Focus this branch** to redraw around the selected item. Open hypotheses remain available. The results view separates ingredient claims from catalog sources, and claim details group evaluated, related and pending evidence.

On a narrow screen the graph opens top-to-bottom so the selected node and its first connection are readable together. Within the canvas, drag with one finger to pan or pinch with two fingers to zoom. A short stationary tap opens a node. The surrounding page uses the browser's normal touch behavior. Home centers the selected node at readable size, and Fit content shows the entire explored web.

Green **May ease** and red **May worsen** links show the recorded qualified direction. Amber **Claim challenged** labels mark evidence opposing the proposed effect and leave the opposite direction uncertain. Gray links carry related, inconclusive, pending and source relationships. Where the same two items have several directional or challenge signals, a single purple connector leads to their individual entries. The connection cards retain the preparation, symptom, study key, assessment and source reference. Saved sources link through recorded assessments or explicit claim citations. A catalog source without either relationship displays its current graph coverage. Exact ledger study keys remain distinct.

The graph projects the same committed claim model used by the oracle, including all 6,930 frozen pairs. The local web build exports `graph.json` and its gzip copy. The browser loads the snapshot when the first graph is opened and reuses it for later graph views. Claim searches use the paginated live API without downloading the graph. Portable builds use their existing `claims.json` for both search and graph. The interface shows the model revision and checks it against the oracle. Rebuild the web assets to update the local graph snapshot after research commits.

```powershell
git submodule update --init -- experiments/tools/vendor/nyx
& ./experiments/tools/parkinsons-oracle/web/build.ps1 -Compiler 'path-to-pas2js' -Runtime 'path-to-rtl.js'
& ./build/parkinsons-oracle/bin/parkinsons-oracle.exe web (Get-Location).Path 8795
```

Open [the local workbench](http://127.0.0.1:8795/) while the server is running. Pass `-UnitRoot` with the pas2js packages folder when the compiler has no configured unit paths. The web build was verified with the August 4 pas2js compiler source revision `d7f522a5611b13f37164c5eac87ade49b2f5b324` and package revision `fa10c59214cd226c60af465c831d66a7321f0214`. [Nyx’s browser toolchain record](../vendor/nyx/docs/component-documentation.md) · [Free Pascal pas2js source](https://gitlab.com/freepascal.org/fpc/pas2js)

### Access from another device

Start a listener with your computer's private IPv4 address and subnet prefix.
Enter the binding at the prompt so it stays out of the repository.

```powershell
$LanBinding = Read-Host 'Enter the private IPv4 address and subnet prefix in address/prefix format'
& ./build/parkinsons-oracle/bin/parkinsons-oracle.exe web (Get-Location).Path 8795 $LanBinding
```

Open the URL printed at startup on a phone connected to that subnet. The server checks
the TCP peer's address and the request origin. This read-only listener shares the
oracle with devices on that subnet. If the computer's firewall filters inbound
traffic, allow TCP only for this listener on the private network.

## Build the public site

Commit the research and evidence updates you want published. Run the site build
from the repository root with the same Free Pascal, SQLite, and pas2js toolchain
used for the local oracle.

```powershell
git submodule update --init -- experiments/tools/vendor/wfc experiments/tools/vendor/nyx
& ./experiments/tools/parkinsons-oracle/build-pages.ps1 -Compiler 'path-to-fpc' -Pas2js 'path-to-pas2js' -Runtime 'path-to-rtl.js' -UnitRoot 'path-to-pas2js-packages' -RepositoryUrl 'https://github.com/OWNER/REPO'
```

The command checks the research checkout, refreshes the existing SQLite index,
evaluates the committed claim and review ledgers using WFC, and compiles the Nyx
app and its model. Treat changes in the research or the published ledgers as
build inputs. Re-run this command and deploy its output for each revision you
want to publish.

The command reports the new artifact path, revision, and byte size. Serve that
directory locally with a static web server. Before uploading the artifact to
GitHub Pages, check the compiled data, linked source files, dependency notices,
and Git history for personal identifiers. Generated files stay in the ignored
`build/parkinsons-oracle/` tree.
The browser takes its claim data from the published model and downloads catalog
index segments on demand. Catalog results contain every query word, appear in
path order, and link to the matching research files at the build's Git commit.
Browser search approximates SQLite's Unicode tokenization. The public artifact
contains source locators and review assessments alongside the search index.

Pass `-RepositoryUrl` with the GitHub repository approved for public citations.
The default build displays repository-relative source paths. Readers need access
to the cited repository and commit to open those files.
[GitHub Pages publishing sources](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
