# Evidence scorecard

Version 1

Use this rubric for every new verdict and reassessment in the food experiment series. Start with `oracle_evidence_rubric` at the beginning of an evidence-review session. Use the round and claim ID to check prior application. Evaluate the frozen ingredient, preparation, population and symptom under the same rules whether the hypothesis predicts easing or worsening. Continue the experiment's required search and coverage work separately from rating the evidence you have.

## Who observed what

| Source | Record | What can contribute |
| --- | --- | --- |
| Trial or controlled experiment | Investigators, assigned exposure and comparison, setting, endpoints, size analyzed, effect and reported uncertainty, attrition and relevant funding or conflicts | An inspectable outcome contrast. Separate human Parkinson, other human, animal and laboratory results. |
| Observational study | Who measured the outcome, sampling and inclusion, exposure timing, adjustment, missing data and uncertainty | A measured association. Check confounding, reverse causation, concurrent treatment and selection. |
| Treating clinician or clinical case report | Who observed the patient, how diagnosis and outcome were established, timing, exposure, medication and other changes | A documented patient trajectory. A withdrawal or rechallenge can improve attribution, with confounders still recorded. |
| Patient, caregiver or forum participant | Firsthand experience, direct caregiver observation or secondhand suggestion, and what is reported about diagnosis, dose or preparation, symptom timing, medication and alternatives | An identifiable before-and-after, repeated response or other informative comparison can be a weak signal. Unverified identity or diagnosis lowers certainty. Preserve privacy and avoid copying handles or personal details. |
| Traditional practitioner, community member or cultural record | Who described the use, who observed an outcome, source date, community and practice context, terms for the ingredient and symptom, handling and preparations, and distinct accounts of benefit or harm | A traceable firsthand observation with a credible symptom and exposure link can contribute a weak signal. Reported customary use, ceremonies and folklore also help discovery and interpretation. Record the source's own symptom terms and uncertainty about a modern diagnosis. |
| Professional opinion, review, news, sponsor statement, registry or protocol | Original evidence behind each claim, lineage, and publication or results status | Find or verify underlying reports. A registry with identifiable outcome data may be a primary record. An opinion, planned endpoint, promotional statement or repeated citation alone supplies no effect sign. |

Record role and provenance separately from design. A credential matters when it explains how a diagnosis or measurement was established. The actual observation and its comparison determine how far the account can support efficacy. Traceable authorship or authentic documentation establishes provenance. For each result check the specific source passage and record material bias, missing data, reliability, effect units and uncertainty. Record favorable and adverse reports under the same criteria. Keep safety and tolerability observations even when they address a different dose, population or endpoint than the efficacy claim.

## Rate each fit independently

| Dimension | Direct | Partial | Remote | Unusable for direction |
| --- | --- | --- | --- | --- |
| Exposure | Exact ingredient, route and culinary preparation | Same food with uncertain grade, dose or preparation | Different plant part, extract, major processing change or isolated constituent with a documented link | Ingredient absent, mistaken identity or shared exposure with no separate contrast |
| Population | Diagnosed human Parkinson disease | Other human population or uncertain diagnosis with a relevant symptom | Parkinson-relevant animal model | Cell-only or unrelated population for the symptom inference |
| Outcome | Frozen symptom or phenotype separately assessed | Symptom family or pooled measure with plausible overlap | Mechanistic or broad motor proxy | Symptom absent, eligibility only or baseline only |
| Attribution | Named exposure isolated against an informative comparison | Informative observational or within-person contrast with plausible alternative explanations | Bundled or heavily confounded contrast | No meaningful exposure contrast or unresolved intervention identity |
| Result reliability | Inspectable, coherent estimate with uncertainty and adequate reporting | Inspectable sign with material imprecision or reporting limitations | Qualitative or graphical sign with major uncertainty | Missing, unreadable or internally incompatible result |

Assess the effect in the source's own population and comparison first. Record the observed sign as easing, worsening, null, mixed or unreported. Then record which sign, if any, is eligible to inform the frozen claim and explain the transfer. An imprecise estimate may still inform a minimal lean when its direction is interpretable and the transfer is defensible. For example, a visually near-neutral tile with uncertain food preparation, a pooled endpoint and no pairwise estimate or uncertainty stays contextual. A better matched result or a documented exposure or symptom bridge can change that decision. A null result, a mixed or unresolved comparison, no reported results and no records found each supply no sign by themselves.

## Count independent observations

- Use one family per underlying study population and comparison lineage, independently observed account, or traceable cultural lineage. One trial with several timepoints, doses, papers, abstracts, supplements or registry entries is one family. A review, repost or retelling of the same observation belongs with that family. Record the primary locator and cite companion reports in the rationale or assessment ledger.
- Before counting independent corroboration, check enrollment, setting, dates and cohort names for shared participants. For conversations and folklore, check repeated stories, quoted sources, shared accounts and whether purportedly separate observers actually witnessed separate events. Put uncertain families in a separate count. Observations may merit follow-up while their independence is unresolved.
- Count families by source type and direction. Keep sample size and its unit separate. Report analyzed people or animals where known, and document arm counts, timepoints and recurring reports from one person in the notes. Mark unavailable denominators. Keep totals for incompatible populations, outcomes and source types separate. Search results and citations lead to sources, and the number of results has no efficacy weight.
- Independent agreement can strengthen a plausible direction when methods and outcomes are compatible. Weight the closest credible comparison most heavily. Multiple low-attribution accounts stay low-attribution evidence. Preserve the strongest contrary finding and explain whether it weakens the tier or leaves the claim open.

## Choose the tier

| Score anchor | Tier key | Decision test |
| --- | --- | --- |
| 50 | `open` | No interpretable direction survives transfer, or the best evidence leaves neither direction more defensible. |
| 50.005 | `minimal_signal` | An interpretable directional comparison survives with a specific bridge to the claim. Major gaps in exposure, population, symptom, attribution or reliability limit the inference. |
| 51 | `limited_clinical_link` | A result in diagnosed Parkinson disease directly assesses the frozen symptom and provides an interpretable direction. A measured link connects the tested exposure to the ingredient. Material exposure differences, design, imprecision or conflict keep the finding tentative. |
| 55 | `direct_clinical_signal` | An informative comparison isolates the named exposure and measures the frozen symptom in diagnosed Parkinson disease. Remaining bias, imprecision or conflicting results make the direction provisional. |
| 60 | `strong_directional_evidence` | A direct clinical comparison and sufficiently rigorous, precise and consistent evidence support a definitive direction. Justify the strength of the comparison, the amount and consistency of evidence and how the strongest contrary observations were addressed. |

Use these anchors for new and reassessed claims. They are ordinal review tiers. A tier has no statistical calibration and estimates no probability, effect magnitude or chance of individual benefit. Report measured effect sizes, units and uncertainty separately. Two claims can share a tier because both satisfy the same decision test. Never add fit ratings as points or assign extra decimals to break a tie. An older score stays historical pending an individual reassessment.

Record the effect on the symptom separately from its relation to the original hypothesis. A weak signal toward easing produces Maybe True for a reducing hypothesis and Maybe False for a worsening hypothesis. A definitive direction uses True or False on the same basis. Unsupported, inconclusive or shared exposure comparisons remain Unknown.

## Record and check the decision

1. Locate current assessments and primary sources using Oracle. Reuse evidence from earlier rounds after checking the exact preparation, population and endpoint. Complete and record the relevant source checks, including conflicting reports and access or search gaps in the existing ledgers.
2. Record the claim's material evidence families in `followup/scorecard-sources.tsv` in its round folder. Keep the detailed [assessment ledger](followup/assessments.tsv) for all screened studies. Include material conflicts and limitations even if the family supplies no eligible direction. Complete source provenance and links before assigning an anchor.
3. Record the rubric version, tier, chosen effect and rationale in `followup/scorecards.tsv`. Explain why the leading source supports the tier and why conflicting evidence or a missing bridge does or does not change it. Apply the verdict to the existing verdict ledger and verify it against the freeze. Before handing off or publishing a proposed verdict, run `oracle_check_scorecard` with the exact draft rows for that claim and the revision from the claim-specific rubric lookup. Check that the returned verdict, anchor and family counts agree with the proposal, and verify the evidence rationale against the sources. After publication, use `oracle_evidence_rubric` to verify the committed result. Keep historical review coverage separately from scorecard coverage.
4. If a new source or a rubric revision materially changes a claim's basis, rerate the affected claim, update its source rows and decision, and preserve the history in the review records and Git.

### Ledger fields

Use one header, tab-separated UTF-8 text, a fixed-width claim ID and one physical line per row. Within each round keep one current scorecard per claim and one source row per claim and family. Source references are project-relative, using the dated research record or experiment note that contains the actual comparison. The initial files contain applied examples. [Decisions](followup/scorecards.tsv) · [Source families](followup/scorecard-sources.tsv)

- The decision fields are `id`, `rubric_version`, `tier`, `symptom_effect` and `rationale`. Use `none` for an open direction and `eases` or `worsens` for eligible directions.
- The source fields identify the `family`, source `kind`, `reporter` role and `provenance` (`original`, `traceable` or `untraced`). The `observed_effect` describes the underlying relevant comparison and can be `eases`, `worsens`, `null`, `mixed` or `unreported`. The `claim_effect` is `none`, `eases` or `worsens`. Use one of `direct`, `partial`, `remote` and `unusable` for each of the five fits. Use `confirmed` or `uncertain` for independence. Use the analyzed `n` with its `unit` (such as `people`, `animals` or `accounts`), or leave `n` blank if missing or inapplicable. The `local_reference` and `rationale` explain the comparison, material gaps and why any sign was carried forward.
- A project scorecard assesses an actual source comparison. Oracle checks ledger structure, consistency of signed inputs, tier prerequisites and agreement with the published verdict. Reviewers decide what the evidence supports and whether coverage is sufficient.

The project rubric borrows the practice of grouping reports by underlying study, evaluating directness, bias, consistency and imprecision, and appraising different forms of testimony in context. The anchors and verdict mapping are project conventions. [Cochrane Handbook on study selection](https://www.cochrane.org/authors/handbooks-and-manuals/handbook/current/chapter-04) · [Cochrane Handbook on certainty](https://www.cochrane.org/authors/handbooks-and-manuals/handbook/current/chapter-14) · [JBI critical appraisal tools](https://jbi.global/critical-appraisal-tools)
