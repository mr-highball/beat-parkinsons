# Beat Parkinson’s

> **Explore the live interactive research app & recipes:**
> **[https://mr-highball.github.io/beat-parkinsons/](https://mr-highball.github.io/beat-parkinsons/)**
>
> *No installation required—search Parkinson’s symptoms and foods, inspect primary studies and historical/cultural records, explore the interactive connection graph, and browse 1,100+ low-to-medium effort recipes directly in your browser.*

Beat Parkinson’s is an **open-source, research-first effort** to collect, organize, verify, and publish disparate Parkinson’s research across centuries—giving people living with Parkinson’s disease, caregivers, clinicians, and researchers transparent access to primary evidence, unresolved gaps, and practical kitchen resources.

*Educational resource notice: This project organizes published studies, clinical trial records, historical texts, and documented community accounts to help readers prepare informed questions for their care team. It does not provide medical advice, diagnosis, or treatment recommendations.*

---

## Mission & Research-First Approach

Information about Parkinson’s disease—especially around food, herbs, spices, culinary oils, and non-motor or motor symptoms—is scattered across centuries of medical archives, modern PubMed and Europe PMC papers, clinical trial registries, ethnobotanical texts, and patient discussions. Popular summaries often cherry-pick positive headlines, hide null results, or strip away study design and preparation details.

This repository takes a **research-first, audit-friendly approach**:

1. **Collect disparate articles across centuries into chronological buckets (`research/`):**
   - Primary literature, clinical trials, historical transcriptions, and cultural/experiential accounts are filed into **5-year chronological windows** spanning **1595–2029** (inspected early-modern context in `1595–1599` and `1660–1664`, plus a continuous 5-year series from `1865–1869` through `2025–2029`).
   - Every saved text retains its original publication date, provenance header, license/source link, and coverage scope.
   - The archive currently indexes **39,000+ local research files**, backed by **133,596+ Europe PMC metadata records**, **5,075+ ClinicalTrials.gov registrations**, and **25,000+ locally archived UTF-8 study, historical, and trial texts**.
2. **Preserve both formal studies and cultural/lived experience—separately and honestly:**
   - Controlled clinical and preclinical studies live under each period’s `Source-Text/` directory.
   - Traditional practices, ceremonial records, local knowledge, and public forum conversations live separately under `Cultural-and-Experiential/` (following [research/Cultural-and-Experiential.md](research/Cultural-and-Experiential.md)).
   - Favorable, unfavorable, null, and inconclusive observations are kept side by side, and `Unknown (Researched)` and unreviewed claims remain visible by default rather than being hidden.
3. **Blind frozen hypotheses & reproducible evidence grading (`experiments/`):**
   - Across **7 rounds**, the food experiment generated **6,930 frozen claims** pairing **210 canonical ingredients** with **33 Parkinson’s symptoms** before looking up literature, pinning each freeze with a SHA-256 hash.
   - Every graded claim follows the versioned [evidence scorecard](experiments/1000_see_what_sticks_food/EVIDENCE-SCORECARD.md), linking exact study keys, preparations, competing evidence, and rationales.
4. **Practical resources for daily life:**
   - All **44 positive-lean ("May ease") ingredients** are backed by **1,100 low-to-medium effort recipes** (25 per ingredient across Breakfast, Lunch, Dinner, Smoothies, and Juices—with protein-appropriate splits for chicken and salmon) in [1000_see_what_sticks_food_all_recipes](experiments/1000_see_what_sticks_food_all_recipes/README.md).
   - Supplemental ingredients on recipe cards are color-coded with directional research indicators and link directly to their underlying research in a new tab, and every recipe opens as a scalable, printable cooking sheet.

---

## Technical Architecture & Wave Function Collapse (WFC)

The core toolchain is written in **native Free Pascal** (`fpc`) and transpiled to the browser with **`pas2js`**, built around two pinned Git submodules:

- **[`wfc`](https://github.com/mr-highball/wfc)** (`experiments/tools/vendor/wfc`) — Wave Function Collapse constraint solver
- **[`nyx`](https://github.com/mr-highball/nyx)** (`experiments/tools/vendor/nyx`) — UI, modal, interactive canvas, and browser renderer

### How WFC Is Used

1. **Deterministic Claim & Scope Decision Tables (`parkinsonsoracle.claims.pas`):**
   - Query matching across *identity* (symptom, ingredient, preparation, round), *hypothesis direction*, and *evidence scope* (`directional`, `assessed`, `frozen`) is modeled as a three-pass WFC constraint system.
   - At index load time, the solver collapses all eight boolean input combinations once into a deterministic, seed-independent decision table. Both the local MCP server and the static GitHub Pages bundle execute the exact same solved decision logic.
2. **Constrained Multi-Ingredient Recipe Selection (`parkinsonsoracle.recipes.pas`):**
   - Recipe listing slots are modeled as a WFC lattice constrained by the primary ingredient (`core_ingredient`), any arbitrary companion ingredients added by the reader, and meal category (`All`, `Breakfast`, `Lunch`, `Dinner`, `Smoothies`, `Juices`).
   - Collapsing the lattice guarantees non-repeating recipe decks, spreads results evenly across categories in `All` view, and powers deterministic seed-driven shuffling (`Show different ideas`) alongside real-ingredient look-ahead autocomplete.
3. **Blind Experiment Generation (`experiments/1000_see_what_sticks_food`):**
   - Uses deterministic seeded sampling over frozen ingredient and symptom vocabularies prior to evidence review so claim coverage stays verifiable and free of selection bias.

### Portable Static Site & Local Workbench

The browser application (`experiments/tools/parkinsons-oracle/web/oracleweb.lpr`) compiles via `pas2js 3.3.1` to run in two modes from the same Pascal codebase:

- **Static GitHub Pages build** (`.github/workflows/pages.yml`): exports a self-contained model (`claims.json`, sharded binary FTS postings, `recipes.json`, inlined alpha-mask glyphs, and ingredient galleries) requiring zero backend servers.
- **Local HTTP workbench** (`parkinsons-oracle web`): serves the same Nyx UI backed directly by the local SQLite FTS5 catalog and live Git-pinned claim index.

---

## Parkinson’s Oracle MCP Server

The repository includes **Parkinson’s Oracle**, a local, read-only **[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** server over newline-delimited JSON-RPC stdio. Researchers, developers, and AI agents can query graded claims, check evidence rubrics, validate draft scorecards, and search all 39,000+ archived research files locally without web scraping.

### Available MCP Tools

| Tool | Purpose |
| --- | --- |
| `oracle_query` | Search claims by symptom, ingredient, preparation, trend (`eases`/`worsens`), scope (`directional`/`assessed`/`frozen`), verdict, or round. |
| `oracle_ingredient_effects` | Group all 210 ingredients across one or more symptoms into `may_ease`, `may_worsen`, `mixed`, and `unresolved`. |
| `oracle_claim` | Inspect a frozen claim’s rationale, citations, queue counts, and study assessments (supports pagination or exact `assessment_study` lookup). |
| `oracle_evidence_rubric` | Return canonical review rules, rubric version, tier anchors, or a specific claim’s recorded scorecard and source families. |
| `oracle_check_scorecard` | Validate draft `decision_tsv` and `sources_tsv` rows against the pinned claim revision and rubric rules before committing. |
| `oracle_search_catalog` | Full-text SQLite FTS5 search across `research/` filtered by 5-year period and `source_kind` (`source_text`, `cultural`, `conversations`, etc.). |
| `oracle_find_sources` | Batch exact-identifier lookup for up to 100 PMIDs, PMCIDs, DOIs, NCT, ACTRN, ISRCTN, IRCT, DRKS, UMIN, or TCTR IDs. |
| `oracle_read_source` | Read indexed UTF-8 research files in paged 16 KiB slices with staleness detection. |
| `oracle_status` | Report committed claim revision, review/scorecard progress, and SQLite index freshness/diagnostics. |
| `oracle_backlog` | Summarize remaining review queues, scorecard gaps, and per-round counts. |
| `oracle_filter_options` | List canonical symptoms, ingredients (with aliases and directional lean counts), and preparations. |

See [experiments/tools/parkinsons-oracle/README.md](experiments/tools/parkinsons-oracle/README.md) for full tool schemas, query examples, and benchmarks.

### Connecting the MCP Server

After bootstrapping on Windows (see below):

**Codex CLI** (or use the project’s checked-in `.codex/config.toml` in a trusted workspace):
```powershell
$OracleBinary = (Resolve-Path ./build/parkinsons-oracle/bin/parkinsons-oracle.exe).Path
codex mcp add parkinsons-oracle -- $OracleBinary serve (Get-Location).Path
```

**Generic MCP client config** (Claude Desktop, Claude Code, Cursor, Antigravity, etc.):
```json
{
  "mcpServers": {
    "parkinsons-oracle": {
      "command": "C:/path/to/beat-parkinsons/build/parkinsons-oracle/bin/parkinsons-oracle.exe",
      "args": ["serve", "C:/path/to/beat-parkinsons"]
    }
  }
}
```

---

## Bootstrapping the Toolchain (Humans & Agents)

### Prerequisites

- **Git** (with submodule support)
- **Free Pascal (`fpc`) 3.2.2+** (Windows bootstrap can optionally install verified FPC 3.2.2 locally into `build/` via `-InstallFpc`)
- **Windows SQLite (`winsqlite3.dll`, SQLite 3.43+ FTS5)** — built into modern Windows, required for the local MCP/SQLite server binary
- **Python 3.8+** *(optional)* — only needed if running `research/collect_*.py` archive refresh scripts

### 1. Clone the repository (including submodules)

```bash
git clone --recursive https://github.com/mr-highball/beat-parkinsons.git
cd beat-parkinsons
```

If you already cloned without `--recursive`, the bootstrap scripts automatically initialize `experiments/tools/vendor/wfc` and `experiments/tools/vendor/nyx`.

### 2. Run the bootstrap script

#### Windows (PowerShell)

```powershell
# Initialize submodules, build pinned SHA-256-verified pas2js 3.3.1,
# build parkinsons-oracle.exe + Nyx web app, index the catalog, and run all unit tests:
./scripts/bootstrap.ps1 -RefreshCatalog -RunTests
```

If Free Pascal is not installed on your machine yet, add `-InstallFpc` to download and install verified FPC 3.2.2 inside the ignored `build/` directory:

```powershell
./scripts/bootstrap.ps1 -InstallFpc -RefreshCatalog -RunTests
```

Start the local web workbench (http://127.0.0.1:8795/):

```powershell
& ./build/parkinsons-oracle/bin/parkinsons-oracle.exe web (Get-Location).Path 8795
```

#### Linux & macOS (Bash)

```bash
# Install Free Pascal if needed:
#   Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y fpc
#   macOS:         brew install fpc

# Initialize submodules, build pinned SHA-256-verified pas2js 3.3.1,
# build the Nyx web bundle & embed assets, and run all 7 strict unit test suites:
./scripts/bootstrap.sh --run-tests
```

> **Platform note:** All 7 strict portability unit tests, the pinned `pas2js 3.3.1` compiler, the WFC/recipe/graph generators, the complete Nyx web bundle, and the Python literature collectors run natively on **Windows, Linux, and macOS**. The local SQLite FTS5 / MCP stdio server executable (`parkinsons-oracle.exe`) currently links Windows `winsqlite3.dll` and Win32 directory APIs; cross-platform SQLite/POSIX support is a welcome contribution area.

### 3. Quick Start for Coding Agents

If you are an AI coding agent bootstrapping into this workspace:

1. Read [`AGENTS.md`](AGENTS.md) first for repository layout, submodule rules, Oracle-first research procedures, inclusive evidence standards, and privacy checks.
2. Run `./scripts/bootstrap.ps1 -RefreshCatalog -RunTests` (Windows) or `./scripts/bootstrap.sh --run-tests` (Linux/macOS) to initialize `wfc` and `nyx`, compile the pinned `pas2js 3.3.1` toolchain, and confirm a green baseline.
3. Connect to `parkinsons-oracle` over MCP (or via `experiments/tools/parkinsons-oracle/serve.ps1`) and consult `oracle_evidence_rubric` before any evidence review.

---

## Repository Structure

```text
beat-parkinsons/
├── README.md                                        # Project overview & quick start
├── AGENTS.md                                        # High-level contributor & agent guidelines
├── scripts/
│   ├── bootstrap.ps1                                # Windows toolchain & Oracle bootstrap
│   └── bootstrap.sh                                 # Linux/macOS toolchain & web/test bootstrap
├── research/                                        # Chronological archive (1595–2029)
│   ├── README.md                                    # Archive structure, indexes & collector commands
│   ├── Cultural-and-Experiential.md                 # Policy for cultural & lived-experience records
│   ├── 1595-1599/ ... 2025-2029/                    # 5-year buckets (Source-Text/ & Cultural-and-Experiential/)
│   └── collect_*.py, build_source_catalog.py        # Public API literature & trial collectors
├── experiments/
│   ├── 1000_see_what_sticks_food/                   # Round 1 frozen claims, scorecard & follow-up ledgers
│   ├── 1000_see_what_sticks_food_round_2..7/        # Rounds 2–7 frozen claims & ledgers (6,930 total)
│   ├── 1000_see_what_sticks_food_all_recipes/       # Shared recipe store (1,100 recipes across 44 ingredients)
│   ├── oracle-coverage/                             # First-pass Oracle lookup hit-rate ledger
│   └── tools/
│       ├── parkinsons-oracle/                       # MCP server, WFC models, tests & Nyx web app
│       └── vendor/
│           ├── wfc/                                 # Git submodule: mr-highball/wfc
│           └── nyx/                                 # Git submodule: mr-highball/nyx
└── .github/workflows/pages.yml                      # Reproducible GitHub Pages CI/CD pipeline
```

---

## Contributing

Contributions are warmly welcome across research, curation, recipes, and engineering:

- **Evidence reviews & archive expansion:** Add verified primary studies, clinical trial texts, historical transcriptions, or cultural/experiential accounts to their publication-date bucket under `research/`, preserving full provenance headers and null/competing results.
- **Recipes:** Add low-to-medium effort, Parkinson’s-friendly recipes following the `parkinsons-oracle-recipes-1` JSON schema in [1000_see_what_sticks_food_all_recipes](experiments/1000_see_what_sticks_food_all_recipes/README.md).
- **Tooling & portability:** Improve accessibility, browser UX, WFC tooling, test coverage, or Linux/macOS native SQLite/MCP server parity.

Before opening a pull request:
1. Run all portability unit tests (`./scripts/bootstrap.ps1 -RunTests` or `./scripts/bootstrap.sh --run-tests`).
2. Keep temporary outputs inside ignored `build/` directories.
3. Verify that no personal identifiers, private IPs, or local machine paths appear in tracked files or commit history.
