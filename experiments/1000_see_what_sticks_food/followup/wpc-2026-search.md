# World Parkinson Congress 2026 proceedings

The publisher released the supplement online on May 22, 2026. The PMC Cloud Service version 1 JATS XML contained 2,652,418 bytes, MD5 `c5b9a87b40a153c06186b5b27d71120a`, and SHA-256 `6d731bf59c5f1190f44bd2a0e701c6081a04a6dd4d7d8339e5a09595a84eb684`. The NLM plain-text object contained 2,383,851 bytes and matched the provider MD5 `3ca324f80d24438d68f2660d08505a9d`. The CC BY-NC supplement falls outside the archive's reuse profile. The research bucket holds original notes and links. The local ignored build directory holds the input XML and extracted presentation text for replay. [Publisher supplement, PMID 42175618](https://pmc.ncbi.nlm.nih.gov/articles/PMC13360760/) · [Version metadata](https://pmc-oa-opendata.s3.amazonaws.com/PMC13360760.1/PMC13360760.1.json) · [Version XML](https://pmc-oa-opendata.s3.amazonaws.com/PMC13360760.1/PMC13360760.1.xml)

The native parser reconciled 881 numbered presentations from 965 body sections. The 84 other sections are session headings and the author index. The inventory contains 16 pre-congress courses, 131 oral sessions, 654 regular posters and 80 late-breaking posters. Two distinct presentations have the printed code O47. The inventory retains both records with internal keys `O47` and `O47-2`. Each presentation's title and body blocks are screened together. The index excludes structured bibliographies and keeps contributor lines when those lines share the abstract body. [Presentation inventory](wpc-2026-inventory.tsv)

The broad diet, swallowing, botanical and food vocabulary flagged 85 presentations. The frozen ingredient vocabulary and related forms flagged 22, and the symptom vocabulary flagged 330. Ten presentations contained at least one ingredient and one symptom, including six with terms for a particular frozen claim. The union of broad and ingredient flags yielded 102 presentations, all of which have an individual contextual disposition. The English olfaction vocabulary includes anosmia, hyposmia and smell loss. The French ligature `œ` is folded to `oe`, which keeps `œuf` from matching the initials UF in institutional affiliations. The French HAL and ABES snapshots were also replayed after the matcher change. [Topic vocabulary](wpc-2026-topics.tsv) · [Document screen](wpc-2026-lexical-screen.tsv) · [Contextual dispositions](wpc-2026-reviews.tsv) · [Coverage by frozen claim](wpc-2026-claim-coverage.tsv)

Four of the exact pairs came from names or affiliations. The other two came from a qualitative mention of evening caffeine avoidance within a fatigue management program and from a cinnamon diagnostic odor in a cohort that excluded diagnosed Parkinson’s. The nutrition, swallowing and lifestyle leads produced dated results, protocols and registry links. The independent review of swallowing posters used a supplementary term set and provides further primary references. The remaining trails include complete tables for Ghosh’s food-frequency study, posted results for the SENSS and MediPD trials, and further indexing of Movement Disorder Society abstracts and citation families. [Dated congress and primary notes](../../../research/2025-2029/Food-Experiment-Food-Followup.md#world-parkinson-congress-nutrition-and-gastrointestinal-session) · [Swallowing poster review](../../../research/2025-2029/Food-Experiment-Choking-Followup.md#world-parkinson-congress-swallowing-poster-screen) · [Open trails](open-trails.tsv)

## Replay

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$input = "$experiment/build/wpc-2026/PMC13360760.1.xml"
$output = "$experiment/build/wpc-2026/replay"
$followup = "$experiment/followup"
& "$experiment/tools/build-followup.ps1"
& "$experiment/tools/build-scan.ps1"
$proceedings = "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.proceedings.exe"
$scan = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.scan.exe"
& $proceedings $input "$followup/wpc-2026-topics.tsv" $output
& $scan scan-index $experiment "$output/abstracts.tsv" "$followup/hal-lexical-vocabulary.tsv" "$output/lexical-screen.tsv"
& $proceedings audit "$output/inventory.tsv" "$output/lexical-screen.tsv" "$followup/wpc-2026-reviews.tsv"
```
