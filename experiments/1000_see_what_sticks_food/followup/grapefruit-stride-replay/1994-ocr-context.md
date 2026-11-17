# Exact 53-page PMC1364906 OCR follow-up — 2026-11-15

Claim 0853 concerns raw grapefruit and shortened stride severity. This receipt records the exact source review.

## Coverage and method

The 53 sequential official PMC scan URLs (471P–523P), their source-page number, image byte sizes and SHA-256 hashes are recorded in [page inventory](1994-page-inventory.tsv). All 53 retrieved successfully. The project's existing `foodexperiment.mdsocr.exe`, using `foodexperiment.winocr` and Windows English OCR, ran as:

`foodexperiment.mdsocr.exe images-native.tsv images ocr en-US`

Its [OCR coverage](1994-ocr-coverage.tsv) records all 53 as recognized, zero pending and zero without text. Original images and OCR text are in the ignored staging directory. The inventory links the official page images. Each OCR text filename includes the image SHA-256 and can be joined to the ledger. Search terms used against all 53 OCR texts: `grape.?fruit|citrus|naring|bergam|parkinson|levodopa|l.?dopa|gait|walking|freezing|festination|mobility|cyclosporin|felodipine|nifedipine`, case insensitive. Hits by page: 472P and 473P nifedipine; 479P cyclosporin; 497P grapefruit and cyclosporin; 500P felodipine; 504P Parkinson; 505P Parkinson and gait; 506P Parkinson, L-dopa, gait and walking. These are lexical leads, not the number of presentations or a guarantee against OCR error. Legible original page images 497P, 505P and 506P were visually reviewed to determine boundaries and findings. OCR rearranges columns, drops words and misreads symbols and names; no claim of full visual review of all 53 pages.

## Verified source context

* [497P, Van Rooij et al., “The effect of grapefruit juice on the pharmacokinetics of cyclosporine-A (CyA) in renal transplantation patients”](https://cdn.ncbi.nlm.nih.gov/pmc/blobs/1854/1364906/beebc2e75da6/brjclinpharm00021-0099.png): 12 renal transplant patients in an open two-way crossover took 150 ml grapefruit juice or water every 3 h starting 7.5 h before CyA. Blood pharmacokinetics were measured; peak CyA was higher during juice and the metabolite-to-CyA AUC ratio lower, while CyA AUC was not significantly different. This presentation does not study raw grapefruit, a Parkinson population or stride length.
* [505P](https://cdn.ncbi.nlm.nih.gov/pmc/blobs/1854/1364906/8c6add6b953c/brjclinpharm00021-0107.png)–[506P](https://cdn.ncbi.nlm.nih.gov/pmc/blobs/1854/1364906/2db1ca974ec7/brjclinpharm00021-0108.png), O’Neill et al., “Siblings of elderly sufferers have a tendency towards idiopathic Parkinsonism: shared xenobiotic exposure or inheritance?”: assessed gait and standing sway in siblings of Parkinsonism patients and matched controls. Reports group differences including stride length; it is a separate abstract and does not test grapefruit intake. The adjacent Harrison et al. abstract at 506P concerns reaction time and brief L-dopa withdrawal, not grapefruit or stride intervention.
* OCR identifies Parkinson in a separate 504P neuroleptic and psychiatric-patient eye-movement abstract; no grapefruit or stride intervention is presented in that OCR context. Further image verification was not needed for the two decisive presentations above.

The verified presentations have separate cohorts, exposures and outcomes. OCR can miss terms and reorder columns. The contextual disposition uses the identified passages and three visually verified pages.

## Prior access record correction

The earlier receipt left 52 pages uninspected. All 53 images have now been retrieved and processed by OCR; visual checks remain limited to the three pages stated above. PMC1364906 remains distinct from Br J Pharmacol 112 supplement PMC1909990/PMID 8186917.
