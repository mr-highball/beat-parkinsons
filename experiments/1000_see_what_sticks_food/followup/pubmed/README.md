# PubMed ingredient and constituent follow-up

The November 12, 2026 UTC search paired the experiment’s 142 ingredient and 27 related-compound queries with PubMed title, abstract, and selected MeSH terms. After retrying the Brussels sprouts query, all 169 queries reconciled their reported counts with returned ranks. The search returned 4,186 PMID appearances across 2,988 distinct PMIDs. Forty-seven queries returned zero hits. PubMed omitted at least one unindexed quoted phrase in 14 queries. The query table retains the original expression and PubMed’s translation. [Queries](pubmed_queries.tsv) · [Ranked IDs](pubmed_ids.tsv) · [Search requests](pubmed_partitions.tsv) · [Brussels sprouts retry](query-retry-pubmed_queries.tsv)

PubMed ESummary supplied bibliography for all distinct PMIDs after a targeted retry recovered the missing National Academies book entry, PMID 24983057. Of the 2,988 PMIDs, 2,732 matched the ingredient-first Europe PMC run by PMID or DOI. The other 256 were new to that comparison. They can still occur elsewhere in the local archive or in earlier search lanes. EFetch returned XML for all 256 in five batches, with abstract text for 227 and no abstract for 29. Abstract text remains in the ignored build directory. [Bibliography](pubmed_records.tsv) · [ESummary batches](pubmed_summary_batches.tsv) · [Book retry](summary-retry-pubmed_records.tsv) · [Abstract batches](pubmed_abstract_batches.tsv)

The title screen consulted abstracts for plausible human symptom evidence and traced the strongest candidates to primary reports or related literature. Four records absent from the ingredient-first Europe PMC run supplied indirect human evidence, and one had already been assessed in the edible oil follow-up. The additional reports give context for coffee and fatigue (`0121`), asparagus and swallowing, drooling, or fatigue (`0433`, `0647`, `0837`), and yogurt and handwriting (`0832`). The leek case followed from the asparagus literature and gives indirect context for `0661` and `0741`. The screened findings yielded no new directional evidence for a frozen ingredient, preparation, and symptom combination. [Novel source dispositions](pubmed_novel_dispositions.tsv) · [1992 caffeine letter](../../../../research/1990-1994/Food-Experiment-PubMed-Followup.md) · [2000 combination treatment](../../../../research/2000-2004/Food-Experiment-PubMed-Followup.md) · [Asparagus case](../../../../research/2010-2014/Food-Experiment-PubMed-Followup.md) · [Yogurt and leek studies](../../../../research/2020-2024/Food-Experiment-PubMed-Followup.md)

The 1992 caffeine letter was accessible through an external copy despite the missing PubMed abstract. The asparagus letter’s case details come from a citing clinical series. Its primary text remains an access gap. Older indexed items with no abstract, untranslated wording, unindexed phrases, and ingredient mentions confined to article bodies limit this screen. The primary leek case, for example, was found through the asparagus trail while the PubMed query for leek returned zero results. [Novel source dispositions](pubmed_novel_dispositions.tsv) · [Leek case note](../../../../research/2020-2024/Food-Experiment-PubMed-Followup.md#leek-and-bean-sprouts-in-a-jejunal-tube-phytobezoar)

A later native replay found and fixed a UTF-8 input error for multilingual terms on Windows. All 169 inputs in the original snapshot are ASCII. In the separate four-query multilingual fixture, the corrected reader retrieved 11 PMID appearances, up from two. The provider still drops some unindexed aliases from its query translation. [Multilingual replay and ASCII regression](../umbellifer-search-2026-11-12/README.md)

## Native verification and rerun

The verifier applies the Brussels sprouts retry to the query table, loads the retry bibliography, and checks query totals, contiguous ranks, repeated appearances, PMID coverage, and one disposition per novel PMID.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
& "$experiment/tools/build-pubmed.ps1"
$pubmed = "$experiment/build/pubmed-3.3.1-i386-win32/bin"
& "$pubmed/foodexperiment.pubmedaudit.exe" "$experiment/followup/pubmed"
```

Use the ingredient query and result tables from the native Europe PMC ingredient run to capture a new snapshot. Pass an optional query ID or `summary:PMID` after the output path for a targeted retry. The abstract tool accepts an ESummary record table and an output directory. Keep the captured ledgers when rerunning because the live indexes can change. [PubMed E-utilities reference](https://www.ncbi.nlm.nih.gov/books/NBK25501/)

```powershell
$ingredient = "$experiment/build/ingredient-search"
$output = "$experiment/build/pubmed-new"
& "$pubmed/foodexperiment.pubmed.exe" `
  "$ingredient/ingredient_queries.tsv" "$ingredient/ingredient_results.tsv" `
  "$experiment/tools/pubmed-mesh.tsv" $output
& "$pubmed/foodexperiment.pubmedabstracts.exe" "$output/pubmed_records.tsv" $output
```
