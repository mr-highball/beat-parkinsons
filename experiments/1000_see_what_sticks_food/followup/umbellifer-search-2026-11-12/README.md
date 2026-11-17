# Umbellifer herb search on 2026-11-12

The [ingredient plan](terms/ingredients.tsv) covers fresh and dried cilantro, dill weed, chervil and lovage leaf. Europe PMC returned 12 records across four title and abstract queries. PubMed returned 11 PMIDs across four searches that also included Parkinson indexing terms. UTC timestamps in the ledgers fall on November 13.

| Ingredient | Europe PMC | PubMed before correction | PubMed after correction |
| --- | ---: | ---: | ---: |
| Cilantro | 6 | 0 | 7 |
| Dill weed | 3 | 2 | 2 |
| Chervil | 0 | 0 | 0 |
| Lovage leaf | 3 | 0 | 2 |

## PubMed replay

The old native reader interpreted a UTF-8 search TSV using the Windows default encoding. The [original query ledger](pubmed-before/pubmed_queries.tsv) preserves the resulting corrupt text and PubMed's quote warnings. The [corrected query ledger](pubmed-fixed/pubmed_queries.tsv) preserves the intended aliases, including `パクチー`, `любисток`, `شوید` and `кервель`. A native i386-win32 build with Free Pascal 3.3.1 retrieved nine more PMIDs after the correction. The original and corrected runs retrieved their respective reported result counts without pagination gaps.

The `translation` and `warnings` fields show how the provider actually interpreted each request. Several non-English aliases remain absent from the translated queries, including Japanese and Persian variants. PubMed also folds accents and reports some variants as unindexed. Separate regional and full-text checking is documented in the [dated research note](../../../../research/2025-2029/Food-Experiment-Umbellifer-Herbs.md). One Parkinson study named chervil in its menu appendix despite zero chervil title or abstract hits.

The [ASCII dill fixture](ascii-queries.tsv) returned identical submitted queries, provider translations, status, counts and exact PMID rows in the [original](ascii-before/pubmed_queries.tsv) and [corrected](ascii-after/pubmed_queries.tsv) native executables. The two PMIDs were 17508142 and 18838108. Those reports use dill pickle odor as a smell-test stimulus.

## Reproduction

Build the native tools using `tools/build-ingredients.ps1` and `tools/build-pubmed.ps1` from the experiment directory. Run the compiled `foodexperiment.ingredients` with the arguments `<terms-dir> <new-output-dir> 2 ingredients`. Run `foodexperiment.pubmed` with `<ingredient-queries-tsv> <ingredient-results-tsv> <mesh-tsv> <new-output-dir>`, using `tools/pubmed-mesh.tsv` for the mapping. For the ASCII regression, substitute `ascii-queries.tsv` for the first argument. The preserved [Europe PMC result ledger](europe-pmc/ingredient_results.tsv) includes all record IDs and bibliographic columns. Its abstract cells are blank. PubMed uses the Europe PMC result IDs to check overlap.
