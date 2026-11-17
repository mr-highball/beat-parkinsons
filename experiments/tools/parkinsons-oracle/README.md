# Parkinson’s oracle

The oracle is a local Free Pascal MCP server for the Parkinson’s research catalog and food experiments. Use it to retrieve assessed claims, inspect conflicting evidence and find local documents before opening more web searches.

## How the lookup works

- Symptom and ingredient postings narrow a request to candidate claims. Each experiment supplies canonical words and aliases. The oracle verifies each round’s freeze hash and reads claims and assessments from one Git commit.
- The claim index solves the WFC identity, hypothesis and evidence passes once for all eight input combinations. Each lookup evaluates the three inputs for its candidates and applies the solved decision table. Every combination has one valid decision, independent of seed. The same decisions determine evidence scopes in the static model.
- SQLite FTS5 keeps a separate inverted index of local Markdown, text and TSV files under `research/`. Its matches are document leads. It returns short local locators with the index snapshot and coverage.
- Direction filters the original hypothesis wording. A Maybe verdict preserves the recorded weak lean and rationale. A False verdict challenges that hypothesis and carries no automatic claim for the reverse effect.

## MCP tools

| Tool | Input example | Result |
| --- | --- | --- |
| `oracle_query` | `{"symptom":"tremors"}` | Directional local matches, candidate count, assessment counts and a first citation |
| `oracle_claim` | `{"round":1,"id":"0904","assessment_limit":8}` | Frozen statement, verdict and rationale, citations, queue counts, and a page of assessments |
| `oracle_claim` with a study key | `{"round":1,"id":"0121","assessment_study":"PMID:37294324"}` | Assessments for that exact study key and the same claim-wide metadata |
| `oracle_search_catalog` | `{"terms":"black tea tremor","period":"2010-2014","limit":8}` | Ranked local documents containing the requested words |
| `oracle_find_sources` | `{"identifiers":["PMID:40647065","NCT04986982"]}` | Every archived document whose source metadata matches each supplied identifier |
| `oracle_status` | `{}` | Published claim revision, assessed and unreviewed counts, and the text index’s coverage and refresh record |
| `oracle_filter_options` | `{}` | Canonical symptom, ingredient, and preparation choices, with their aliases |

Query scope defaults to `directional`, which requires a True, False, Maybe True or Maybe False verdict with a nonpending assessment. Use `assessed` to inspect records with at least one nonpending assessment, including Unknown, or `frozen` to include hypotheses still awaiting review. Filter by the canonical `preparation`, `round`, `direction` or `verdict` as needed. Results use stable round and claim-ID order. Follow `next_offset` to page through larger result sets.

Use `{"symptom":"tremors","trend":"eases"}` to look up evidence that may point toward relief. Set `trend` to `worsens` for evidence of worsening. The trend uses the card arrows, which require support for the claim being tested. Evidence against a claim leaves the opposite effect open. The `direction` filter applies to the original hypothesis wording.

Use `oracle_claim` for the relevant study outcomes and access gaps. If the claim search is empty or the evidence is unresolved, search the text catalog with alternate spellings, preparation names or endpoint terminology. A lexical hit needs source-level review. A gap in the indexed catalog is a reason to continue discovery, with the index timestamp and its read errors in view.

The shortcuts `hallucination`, `hallucinations` and `seeing things` select
visual hallucination frequency, the outcome in the frozen claims. The
response gives the canonical outcome. Use catalog search for other modalities.

For known identifiers, send up to 100 PMIDs, PMCIDs, DOIs, NCT IDs or trial IDs
from ANZCTR (ACTRN), ISRCTN, IRCT and DRKS to `oracle_find_sources`. Bare numeric
identifiers are PMIDs. Each
result includes the normalized identifier and matching paths in sorted order.
Results follow the input order, including identifiers with zero archive matches.
The three additional registries require a matching source filename, an exact
registration field or leading ID, and the official registry address in the
source header. Use text search for other archives and citation trails.
The tool indexes leading publication metadata from `Source-Text` text files and
matching registry provenance from `Source-Text/Trials` exports. A match can be
a curated extraction or collection, so confirm the actual article and its depth.
Use full-text search for mentions in references, narrative notes and archives
without structured headers.

For a known study, send `assessment_study` with its case-sensitive ledger key and omit the paging arguments. The result reports `matching_assessments` and returns all rows for that key in ledger order. A found claim can have zero matches. The rationale, citations, verdict and coverage counts still apply to the whole claim.

Omit the study key and both assessment paging arguments to return the full evidence list in one reply. With paging, `assessment_limit` accepts 1–100 rows and defaults to 8 when only `assessment_offset` is supplied. Results keep ledger order and include the full claim rationale, verdict references, assessment counts and queue counts. Pass `next_assessment_offset` as the next `assessment_offset` until it is null. If the claim revision changes, start again at offset 0. Check all relevant pages for supporting, opposing and pending evidence.

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
run `index` with the current build before using `oracle_find_sources` again. The first refresh with DRKS support backfills existing official registry extracts.

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

## Browser interface

The Nyx web target uses the same claim and catalog service as MCP. The local workbench offers common symptom pills, a browse list and suggestions for symptoms, ingredients and preparations. Under Symptom effect, choose May ease, May worsen, or Any trend before searching. The filters match the arrows on the cards. Selecting a result opens its study assessments and citations. The local server binds to the loopback address by default.

In Search sources, choose Open source to read the indexed file as text. Long documents have Previous part and Next part controls. Back to results restores the catalog page you were reading.

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
