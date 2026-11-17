# Parkinson’s oracle

The oracle is a local Free Pascal MCP server for the Parkinson’s research catalog and food experiments. Use it to retrieve assessed claims, inspect conflicting evidence and find local documents before opening more web searches.

## How the lookup works

- Symptom and ingredient postings narrow a request to candidate claims. Each experiment supplies canonical words and aliases. The oracle verifies each round’s freeze hash and reads claims and assessments from one Git commit.
- WFC evaluates independent identity, hypothesis and evidence passes. The final pass selects exactly the rows that satisfy all three. Every row has one valid decision, so the solver's seed cannot determine a finding. The engine produces an empty options array when the constraints have no match.
- SQLite FTS5 keeps a separate inverted index of local Markdown, text and TSV files under `research/`. Its matches are document leads. It returns short local locators with the index snapshot and coverage.
- Direction filters the original hypothesis wording. A Maybe verdict preserves the recorded weak lean and rationale. A False verdict challenges that hypothesis and carries no automatic claim for the reverse effect.

## MCP tools

| Tool | Input example | Result |
| --- | --- | --- |
| `oracle_query` | `{"symptom":"tremors"}` | Directional local matches, candidate count, assessment counts and a first citation |
| `oracle_claim` | `{"round":1,"id":"0904","assessment_limit":8}` | Frozen statement, verdict and rationale, citations, queue counts, and a page of assessments |
| `oracle_search_catalog` | `{"terms":"black tea tremor","period":"2010-2014","limit":8}` | Ranked local documents containing the requested words |
| `oracle_status` | `{}` | Published claim revision, assessed and unreviewed counts, and the text index’s coverage and refresh record |
| `oracle_filter_options` | `{}` | Canonical symptom, ingredient, and preparation choices, with their aliases |

Query scope defaults to `directional`, which requires a True, False, Maybe True or Maybe False verdict with a nonpending assessment. Use `assessed` to inspect records with at least one nonpending assessment, including Unknown, or `frozen` to include hypotheses still awaiting review. Filter by the canonical `preparation`, `round`, `direction` or `verdict` as needed. Results use stable round and claim-ID order. Follow `next_offset` to page through larger result sets.

Use `{"symptom":"tremors","trend":"eases"}` to look up evidence that may point toward relief. Set `trend` to `worsens` for evidence of worsening. The trend uses the card arrows, which require support for the claim being tested. Evidence against a claim leaves the opposite effect open. The `direction` filter applies to the original hypothesis wording.

Use `oracle_claim` for the relevant study outcomes and access gaps. If the claim search is empty or the evidence is unresolved, search the text catalog with alternate spellings, preparation names or endpoint terminology. A lexical hit needs source-level review. A gap in the indexed catalog is a reason to continue discovery, with the index timestamp and its read errors in view.

Omit both assessment paging arguments to return the full evidence list in one reply. With paging, `assessment_limit` accepts 1–100 rows and defaults to 8 when only `assessment_offset` is supplied. Results keep ledger order and include the full claim rationale, verdict references, assessment counts and queue counts. Pass `next_assessment_offset` as the next `assessment_offset` until it is null. If the claim revision changes, start again at offset 0. Check all relevant pages for supporting, opposing and pending evidence.

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

Refresh the text index after adding local research. This reuses the existing index and checks the local inventory for changes:

```powershell
& ./build/parkinsons-oracle/bin/parkinsons-oracle.exe index (Get-Location).Path
```

The catalog refresh records its own timestamp and failed reads. Check `oracle_status` before treating the index as current.
Refresh also installs the read-error index in existing catalogs. This avoids scanning every indexed document for the diagnostic count on each search.

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
