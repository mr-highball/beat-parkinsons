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

# Local research lookup

Use [Parkinson’s oracle](experiments/tools/parkinsons-oracle/README.md) for relevant local claim and catalog lookups when its MCP server is available. Inspect the claim’s assessment and coverage records before drawing a directional conclusion. Continue with the experiment’s documented evidence workflow when local results leave a question open.

# Publication privacy

Keep personal identifiers out of material prepared for public release. Supply local network bindings through runtime arguments and keep personal files outside Git. Before publishing, check the release files, generated search assets, dependency references, and Git history for identifying details. Resolve any findings before uploading.
