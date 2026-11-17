# Food thought experiment rules

## Generation

- Follow the native Free Pascal and work-record guidance in [Athena](../tools/vendor/athena/README.md#standards-map). Use Pascal for generation, scanning, evidence ledgers, and validation. Shell scripts may build and run the Pascal tools.
- Define the generation vocabulary without opening the research archive or looking up outcomes. The generator must use only the experiment inputs. When an independent blind vocabulary pass is needed, delegate it to The Brain with only the experiment inputs.
- Generate exactly 1,000 hypotheses. Use 250 each for foods, herbs, spices, and edible oils. Each category must contain 125 reducing and 125 worsening claims.
- Give each claim one ingredient, one compatible ordinary culinary preparation, and one Parkinson’s symptom or symptom outcome. Use each ingredient and symptom pair once. Use fixed-width IDs and the same UTF-8 text format for every statement. Treat the statements as intentionally arbitrary research hypotheses.
- Verify every generated file, then freeze the ordered claim fields and record the seed, input hashes, and claim hash. Evidence review starts only after the freeze. Keep the original directions and wording during review.

## Evidence assessment

- Scan the entire local research catalog after the freeze. Log file coverage, unavailable full text, and any read or extraction failures. Search both directions and deduplicate reports of the same study.
- Evaluate human Parkinson’s evidence against the named ingredient, preparation, and symptom. Record related preparations, isolated constituents, combined interventions, other endpoints, and nonhuman studies as indirect leads.
- Start with at least two targeted external searches for each locally Unknown or Maybe claim, then broaden them as needed. Share a query only when it covers each mapped claim. Record its date, text, results, screening depth, and provider or access limits. Save new relevant sources or original summaries in the appropriate local research period before citing them.
- Use True or False at 60% confidence or above. Use Maybe True or Maybe False above 50% and below 60%. Use Unknown when credible evidence does not favor a direction. Confidence is a reviewer judgment. A missing study or an inconclusive null finding does not establish the opposite direction. Use Maybe for a defensible weak lean that falls in its score band, including estimates with a clear, limited transfer to the frozen claim. Describe the bridging evidence and competing findings. Keep Unknown when the evidence leaves no defensible direction.
- Record a concise rationale and resolvable local evidence paths for every directional verdict. Record the search and scope limits when a verdict remains Unknown. Preserve findings that conflict with the chosen verdict.

## Follow-up evidence review

- Treat the frozen direction as a working premise. Search for evidence that supports it, challenges it, or qualifies when it applies. A verified finding requires evidence that bears on the claim. An untested premise stays open.
- Exhaust accessible pages for the recorded searches and reconcile returned counts. Use the first-pass searches, broader ingredient searches, relevant compounds, alternative names, trial registries, and other appropriate sources. Continue following plausible references and citing papers while they produce new evidence. The original run screened up to 20 results per query and followed references once. Preserve those limits in the historical ledgers.
- For each language used in a search, verify that the native matcher handles its script and that the vocabulary covers the frozen ingredients and symptoms. Keep broader context reviews for records that fail a lexical pair match. Record where a provider lacks an abstract or an original report is inaccessible.
- Keep a resumable record of coverage, case-level or group-level results, conflicting evidence, preparation and endpoint fit, access gaps, and open trails. A zero-hit query, missing abstract, or inconclusive result leaves the hypothesis open. Record evidence outside the frozen ingredient set in the research catalog when relevant.
- Place every new study or local source text under `research/YYYY-YYYY` using its first public publication date, or its first public registry posting date for a registration. Link the entry from its period index and the applicable experiment records. Distinguish the date of newly released results from the date of the registration they belong to.
- Preserve the first-pass ledgers and the frozen claim wording. Publish revised verdicts only when the assessed evidence warrants a change under the original verdict thresholds. Verify the freeze, verdict files, and research references after each publication.

## Completion

- Verify the frozen hash and all 1,000 immutable claim fields. Validate the verdict count, references, and required search coverage before publishing the manifest.
- Report all five verdict totals, coverage limits, and the strongest unexpected supported improvements, worsening effects, and reversals. Link any highlighted result to its claim and source.
- Give future experiments their own folder-local `AGENTS.md` covering generation, freeze, evidence, and completion. Adapt the topic and rules to that experiment.

## Project team

Dexter coordinates the experiment and verifies the evidence and deliverables. Assign independent internet research and source reviews to Pinky, Slinky, and Binky (GPT-6.1 Terra, high reasoning). Assign Blimbo (GPT-6 Luna, high reasoning) supporting searches, source checks, and evidence packet preparation. Delegate difficult reasoning and independent quality review to The Brain (`gpt-6.1-sol`, `ultra`) when Dexter can advance other work. Reuse these five agents under the [project team rules](../../AGENTS.md). The user must authorize any other subagent.
