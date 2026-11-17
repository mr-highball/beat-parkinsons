# French national thesis catalog

The theses.fr live search timed out. The November 12, 2026 ABES national export provided an independent discovery route. The official gzip resource contained 634,428,584 bytes and matched the provider SHA-1. The snapshot ledger also records a SHA-256 for replay. The native reader decompressed and parsed all 487,633 JSON records and verified the gzip footer at the end. The export includes some older cataloged records despite the dataset title specifying French doctoral theses since 1985. [Official dataset and scope](https://www.data.gouv.fr/datasets/theses-soutenues-en-france-depuis-1985) · [Snapshot and checksums](theses-fr-snapshot.tsv)

The native screen retained 1,081 unique national thesis numbers with the Parkinson word stem, *paralysie agitante* or *shaking palsy* in a title, abstract or indexed subject. Of those, 947 had an indexed abstract and 532 were marked accessible by the provider. Condition-word matches include passing references and Wolff–Parkinson–White records. All 1,081 were then screened for the experiment’s ingredient and symptom vocabulary with additional French terms and English clinical endpoint variants. Sixteen records had an ingredient match and 251 had a symptom match. No record matched both terms for a frozen claim. Full-text references and missing metadata can still contain pertinent evidence. [Condition result inventory](theses-fr-results.tsv) · [Lexical screen](theses-fr-lexical-screen.tsv) · [Coverage across 1,000 claims](theses-fr-lexical-claim-coverage.tsv)

A broader title-and-abstract probe for diet, meals, swallowing and related terms surfaced 50 records. The 1989 Bellonnet thesis specifically concerns diet and motor fluctuations in levodopa-treated patients. Its national record resolves to Sudoc 043189318 with two print holdings and no recovered abstract or full text. The 2024 Clermont-Auvergne clove thesis reports animal motor outcomes and likely overlaps with the 2023 paper. The Bordeaux grapevine thesis is a cross-index match to HAL and describes isolated-compound laboratory results. [Primary checks and open leads](theses-fr-priority.tsv) · [1989 thesis record and holdings](../../../research/1985-1989/Food-and-Nutrition.md#1989--clermont-ferrand-thesis-on-diet-and-levodopa-motor-fluctuations) · [Clove thesis](../../../research/2020-2024/Food-Experiment-Botanical-Model-Followup.md#2024-clermont-auvergne-clove-thesis)

The Rennes and Paris-Saclay theses match HAL records. The Rennes thesis and its two related papers test isolated olive oil phenols in cell and chemical assays. The two papers underlying the Paris-Saclay results use genetic proxies and case status for coffee and dairy. The Strasbourg–Amsterdam thesis is partly accessible through the partner university, and the linked research papers document beef fat intake as an outcome of dopamine manipulation. Separate studies in the thesis measure pain, mood and movement after brain lesions. These primary checks identify outcomes that broad topic-word searches can conflate. [Rennes thesis trail](../../../research/2020-2024/Food-Experiment-HAL-Followup.md#2020-public-deposit-of-the-rennes-olive-phenol-thesis) · [Paris-Saclay companion studies](../../../research/2020-2024/Food-Experiment-HAL-Followup.md#genetic-proxies-for-coffee-and-dairy-intake-in-courage-pd) · [Strasbourg and Amsterdam thesis](../../../research/2020-2024/Food-Experiment-HAL-Followup.md#beef-fat-selection-after-dopamine-depletion-in-rats)

The snapshot includes metadata for doctoral theses. DUMAS, university repositories, and other sources provide additional coverage of master's reports and items outside the national collection. Defense dates from the export are kept as bibliographic fields. When cataloging a source, the notes distinguish them from separately verified dates of public release. Raw indexed abstracts and the gzip stay under the ignored build directory.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
& "$experiment/tools/build-followup.ps1"
& "$experiment/tools/build-scan.ps1"
$catalog = "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.theses.exe"
$scanner = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.scan.exe"
$input = "$experiment/build/theses-fr/2026-11-12-theses-soutenues.jsonl.gz"
$replay = "$experiment/build/theses-fr/replay"
& $catalog $input $replay
& $scanner scan-index $experiment "$replay/abstracts.tsv" `
  "$experiment/followup/hal-lexical-vocabulary.tsv" "$replay/lexical-screen.tsv"
```
