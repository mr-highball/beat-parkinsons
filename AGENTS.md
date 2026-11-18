# Execution mode

Dexter works in single-agent mode following the graph interface checkpoint. Do not spawn, resume or assign new work to subagents unless the user explicitly requests it. The role profiles below remain available for such a request; their existence does not authorize delegation. Preserve completed research handoffs for Dexter to resume.

# Project team

| Role | Model and reasoning | Responsibility |
| --- | --- | --- |
| Dexter | Primary Codex agent | Coordinate and own the experiments. Verify research, evidence judgments, catalog updates, and final deliverables across the project. |
| Pinky | GPT-6.1 Terra, High | Search the internet for assigned questions and summarize the primary sources, exact results, and limits. |
| Slinky | GPT-6.1 Terra, High | Search the internet for assigned questions and summarize the primary sources, exact results, and limits. |
| Binky | GPT-6.1 Terra, High | Run independent internet research in parallel with Pinky and summarize the primary sources, exact results, and limits. |
| Blimbo | GPT-6 Luna, High | Support Pinky, Binky, and Slinky with source searches and materials for evidence review. |
| The Brain | GPT-6.1 Sol, Ultra | Take higher-level reasoning, difficult evidence judgments, or independent quality review when Dexter is occupied. |

Use only Pinky, Slinky, Binky, Blimbo, and The Brain as subagents unless the user authorizes another. Dexter assigns all delegated work and verifies the results before publishing.

- When the user explicitly authorizes delegation, give internet research to Pinky, Slinky, and Binky as independent assignments become available.
- Under that explicit authorization, assign Blimbo source searches and preparation, or bring in The Brain for difficult reasoning or quality review.
- Reuse the named agents for follow-ups. Give each agent a distinct deliverable, parallelize work that advances the experiment, and leave agents idle when their roles have no substantive work.
- Use the project agent profiles for [Pinky](.codex/agents/pinky.toml), [Slinky](.codex/agents/slinky.toml), [Binky](.codex/agents/binky.toml), [Blimbo](.codex/agents/blimbo.toml), and [The Brain](.codex/agents/the_brain.toml). If the dispatch tool takes model settings directly, specify the model and reasoning effort from the profile and give the agent the context it needs for the assignment.

# Research commits

Commit verified research and experiment updates incrementally. Use a descriptive subject and include the material source additions, verdict changes, or open evidence gaps in the commit body. Keep temporary downloads and build outputs in the ignored build directories.

# Inclusive evidence collection

- Collect cultural and traditional practices, ceremonial accounts, local knowledge and public personal reports alongside formal studies. Preserve favorable, unfavorable and no-benefit accounts. Follow the [cultural and experiential record policy](research/Cultural-and-Experiential.md).
- Store these records separately under each period's `Cultural-and-Experiential/` folder, using the source's publication date and an explicit date basis. Distinguish a historical practice's claimed age from the date of the document actually inspected.
- Include relevant public Reddit and other forum discussions under `Cultural-and-Experiential/Conversations/`. Preserve the original thread locator, approximate or exact date basis and a privacy-safe account of what participants observed. Let the available source information determine the rest of the format.
- Label source kind, authenticity, symptom specificity and efficacy uncertainty separately. Traditional or personal claims have lower evidential weight for treatment effects than controlled clinical studies. Repetition of a claim is not independent confirmation, and documenting a belief does not verify efficacy.
- Preserve the frozen experiments. Catalog relevant practices and ingredients outside their vocabulary without inventing completed assessments or changing frozen pairs. Cross-link existing studies rather than duplicating cohorts.
- The public research view includes findings, Unknowns and unreviewed questions by default, with clear labels. Offer explicit filters without silently excluding unresolved material. Surface catalog-source leads beyond the frozen claim set and distinguish them from assessed findings.

# Oracle-first research

- Dexter, Pinky, Binky, Slinky, Blimbo, and The Brain use [Parkinson’s oracle](experiments/tools/parkinsons-oracle/README.md) as the first knowledge base for each evidence question. Consult it before broad file scans or web discovery. During blind generation, use only the experiment inputs.
- For claim evidence, start with `oracle_query` using the ingredient, symptom, and `scope: "assessed"`. Retrieve the needed `oracle_claim` assessments and coverage. For known PMIDs, PMCIDs, DOIs, NCT IDs or ACTRN, ISRCTN, IRCT and DRKS registrations, use `oracle_find_sources` to locate archived texts in one request. Check the actual source passage. Use `oracle_search_catalog` for citation trails, catalog notes and alternate terms. Check earlier experiments for reusable work while preserving the exact exposure, preparation, population, and endpoint.
- Use the local MCP launcher when the session has no direct oracle tools. The [launcher example](experiments/oracle-coverage/README.md#local-launcher) and the same read-only tools apply to all project agents. When checking one known ledger study, use `oracle_claim` with its exact `assessment_study` key. For initial triage of a claim with many assessments, use `assessment_limit: 8`. Follow `next_assessment_offset` while the revision matches or request all assessments when the review needs them. A local match does not close any required external search.
- Record one first-pass result per evidence question as a hit, partial, miss, or unavailable. Send the outcome, query, citation, and unresolved dimension to Dexter for the [coverage ledger](experiments/oracle-coverage/README.md). Log repeat searches as part of the same question. Keep tool and index failures separate from catalog gaps.
- At each research checkpoint, compare strict hit rates for comparable batches and record the denominator. When rates decline, identify recurring partials and misses by exposure, symptom, and missing evidence. Prioritize those gaps for catalog expansion, while keeping the experiment’s existing review order and search coverage requirements. Verify index health before interpreting the trend and refresh the index after committed catalog updates.
- Fix verified oracle inefficiencies when they materially slow research. Compare equivalent requests against the same data before and after each fix. Verify that evidence, result order and freshness checks still work. Report response bytes, lookup timing and any measured model tokens separately.

# Publication privacy

Keep personal identifiers out of material prepared for public release. Supply local network bindings through runtime arguments and keep personal files outside Git. Before publishing, check the release files, generated search assets, dependency references, and Git history for identifying details. Resolve any findings before uploading.
