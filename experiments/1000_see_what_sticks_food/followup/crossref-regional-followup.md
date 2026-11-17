# Citation recovery for OpenAlex records without abstracts

The November 12, 2026 replay attempted exact publisher-deposited Crossref lookup for all 77 works without an abstract in the regional OpenAlex snapshot. Sixty-seven returned an exact DOI record, nine had no DOI in the input, and one returned HTTP 404 from Crossref. The latter DOI is registered with DataCite and identifies the same Javeriana thesis as W2531234133. None of the 67 exact Crossref records contains a deposited abstract. These statuses describe bibliographic deposits and leave primary-source access separate. [Exact lookup ledger](crossref-regional-metadata.tsv) · [Original OpenAlex coverage](openalex-regional-context-coverage.tsv) · [DataCite record](https://api.datacite.org/dois/10.60794/s4tk-wy89) · [Crossref REST documentation](https://www.crossref.org/documentation/retrieve-metadata/rest-api/)

Forty works supplied 1,300 deposited reference rows. Of these, 1,063 carry structured DOIs, representing 1,046 distinct DOIs. Each row retains its citing work ID and position. The same cited work can occur in more than one source. The native screen uses the deposited article title, or the unstructured citation and journal where a title is missing. Its language field comes from the citing work. It screens citation text, which may be incomplete, against all frozen labels. [References](crossref-regional-references.tsv) · [Lexical output](crossref-regional-reference-lexical.tsv) · [All 1,000 claims](crossref-regional-reference-claim-coverage.tsv)

The screen found 43 named exposure or constituent appearances and no joint lexical matches. Each of the 43 has a contextual disposition. The separate diet and swallowing vocabulary flagged 234 rows, of which 21 are also in the exposure screen. All 234 have exact citation-level dispositions. The ledger distinguishes deposited-title screens from original abstract, full-text or table reviews. This stage remains sensitive to whether a cited title names the food and symptom. [Exposure dispositions](crossref-regional-reference-screen.tsv) · [Broader topic flags](crossref-regional-reference-topics.tsv) · [234 contextual reviews](crossref-regional-reference-topic-reviews.tsv)

Desport's 2013 review deposits 26 references. Its low-protein foods citation leads to the already cataloged Barichella crossover. Its Warsaw swallowing citation leads to related 2002 and 2003 reports of water swallowing and esophageal transit, with possible cohort overlap. A separate Hamburg stimulation crossover reports aspiration counts by named test bolus. It gives one biscuit aspiration with stimulation off and water aspirations under all three conditions. The Milan Nutri-Park paper separates an example menu from the measured protein-distribution and clinical outcomes. Its publisher version is now archived as licensed text. [Desport preview and references](https://www.sciencedirect.com/science/article/abs/pii/S0985056213000472) · [Barichella trial](../../../research/2005-2009/Food-Experiment-Multilingual-Followup.md#20062007-meal-studies-and-the-food-level-comparison) · [Warsaw studies](../../../research/2000-2004/Food-Experiment-French-Reference-Followup.md#water-swallowing-and-esophageal-transit-in-the-warsaw-reports) · [Hamburg and Milan studies](../../../research/2020-2024/Food-Experiment-French-Reference-Followup.md)

Follow-up located the 1999 Japanese dysphagia abstract and verified original issue holdings. Its citation trail led to a 2000 government report naming sugar solution, agar and cookies as swallowing test boluses. The 1990 nutritional swallowing study and both Leopold and Kagel reports have verified primary abstracts and unresolved full methods. A recovered 2013 Campinas report uses lemon juice and cornstarch biscuit and gives conflicting summary and participant-level values. The original paper is archived as licensed text. [Japanese cohort and food records](../../../research/1995-1999/Food-Experiment-Japanese-Swallowing-Followup.md) · [Japanese grant report](../../../research/2000-2004/Food-Experiment-Japanese-Swallowing-Followup.md) · [Campinas source](../../../research/2010-2014/Food-Experiment-Crossref-Swallowing.md)

The food questionnaire follow-up recovered the 2022 MVP supplementary item table and flagged a conflict between the paper’s fatigue text and table. In a separate clinical case, a historical manufacturer guide lists corn oil in both formulas used before and after a multicomponent tube-feeding change. The primary case did not verify the batches or quantify the oil intake. [MVP item analysis](../../../research/2020-2024/Food-Experiment-Clinical-Nutrition-Followup.md) · [Tube feeding case and product guide](../../../research/2005-2009/Food-Experiment-Clinical-Nutrition-Followup.md)

The Global Index Medicus search endpoint again returned HTTP 403 on a standard request. Other open trails include the 1988 broad-bean abstract, the body of Raguthu’s letter, and references whose original methods or tables remain inaccessible. [Open source trails](open-trails.tsv) · [Global Index Medicus](https://www.globalindexmedicus.net/)

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$followup = "$experiment/followup"
$capture = "$experiment/build/crossref-regional-2026-11-12"
& "$experiment/tools/build-followup.ps1"
& "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.crossref.exe" `
  "$followup/openalex-regional-context-coverage.tsv" `
  "$followup/openalex-regional-results.tsv" $capture

$vocabularies = @('openalex-spanish-vocabulary.tsv', 'openalex-portuguese-vocabulary.tsv',
  'openalex-french-vocabulary.tsv', 'hal-lexical-vocabulary.tsv')
$terms = @(Get-Content "$followup/$($vocabularies[0])" -TotalCount 1
  foreach ($vocabulary in $vocabularies) {
    Get-Content "$followup/$vocabulary" | Select-Object -Skip 1
  })
$terms | Set-Content "$capture/reference-terms.tsv" -Encoding utf8NoBOM
$scan = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.scan.exe"
& $scan scan-index $experiment "$capture/reference-index.tsv" "$capture/reference-terms.tsv" `
  "$capture/reference-lexical-replay.tsv"
& $scan scan-topics "$capture/reference-index.tsv" "$followup/mds-2026-topics.tsv" `
  "$capture/reference-topics-replay.tsv"
& "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.crossref.exe" audit-topics `
  "$capture/reference-topics-replay.tsv" "$capture/reference-topic-reviews-replay.tsv" `
  "$followup/crossref-regional-reference-topic-reviews.tsv"
```
