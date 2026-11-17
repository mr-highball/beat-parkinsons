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

- Give internet research to Pinky, Slinky, and Binky as independent assignments become available.
- Assign Blimbo source searches and preparation for the research agents or for Dexter. Bring in The Brain when a difficult reasoning or quality review assignment can proceed while Dexter handles other work.
- Reuse the named agents for follow-ups. Give each agent a distinct deliverable, parallelize work that advances the experiment, and leave agents idle when their roles have no substantive work.
- Use the project agent profiles for [Pinky](.codex/agents/pinky.toml), [Slinky](.codex/agents/slinky.toml), [Binky](.codex/agents/binky.toml), [Blimbo](.codex/agents/blimbo.toml), and [The Brain](.codex/agents/the_brain.toml). If the dispatch tool takes model settings directly, specify the model and reasoning effort from the profile and give the agent the context it needs for the assignment.

# Research commits

Commit verified research and experiment updates incrementally. Use a descriptive subject and include the material source additions, verdict changes, or open evidence gaps in the commit body. Keep temporary downloads and build outputs in the ignored build directories.

# Oracle-first research

- Dexter, Pinky, Binky, Slinky, Blimbo, and The Brain use [Parkinson’s oracle](experiments/tools/parkinsons-oracle/README.md) as the first knowledge base for each evidence question. Consult it before broad file scans or web discovery. During blind generation, use only the experiment inputs.
- For claim evidence, start with `oracle_query` using the ingredient, symptom, and `scope: "assessed"`. Retrieve the needed `oracle_claim` assessments and coverage. For a specific paper or registration, search the indexed catalog by stable identifier and check the actual source passage. Check earlier experiments for reusable work while preserving the exact exposure, preparation, population, and endpoint.
- Use the local MCP launcher when the session has no direct oracle tools. The [launcher example](experiments/oracle-coverage/README.md#local-launcher) and the same read-only tools apply to all project agents. Use small replies to locate evidence, then page and follow supporting, opposing, and open trails as needed. A local match does not close any required external search.
- Record one first-pass result per evidence question as a hit, partial, miss, or unavailable. Send the outcome, query, citation, and unresolved dimension to Dexter for the [coverage ledger](experiments/oracle-coverage/README.md). Log repeat searches as part of the same question. Keep tool and index failures separate from catalog gaps.
- At each research checkpoint, compare strict hit rates for comparable batches and record the denominator. When rates decline, identify recurring partials and misses by exposure, symptom, and missing evidence. Prioritize those gaps for catalog expansion, while keeping the experiment’s existing review order and search coverage requirements. Verify index health before interpreting the trend and refresh the index after committed catalog updates.

# Publication privacy

Keep personal identifiers out of material prepared for public release. Supply local network bindings through runtime arguments and keep personal files outside Git. Before publishing, check the release files, generated search assets, dependency references, and Git history for identifying details. Resolve any findings before uploading.
