# Movement Disorder Society 2026 abstract archive

The society's title-sorted meeting archive returned 2,072 distinct abstract URLs across all 208 linked pages. The native collector verified page numbers, positions and unique URLs, and saved the byte count and SHA-256 for each cached page. Offline replay reproduced both inventory files byte for byte. The journal's separate listing repeated a URL across pages before the tenth page was complete. The title-sorted meeting view supplied the reconciled list. The WordPress IDs in the body inventory identify online records. The meeting schedule separately assigns presentation numbers. [Society abstract archive](https://www.mdsabstracts.org/meetings/2026-international-congress/?viewby=title) · [Journal supplement](https://movementdisorders.onlinelibrary.wiley.com/toc/15318257/2026/41/S1) · [Official schedule](https://www.mdscongress.org/Abstract-Schedule.pdf) · [Page ledger](mds-2026-pages.tsv) · [URL inventory](mds-2026-links.tsv)

All 2,072 abstract bodies were retrieved and screened. Of those, 161 matched a broader topic term, 36 matched a frozen ingredient or related term, and 1,033 matched a symptom term. The topic and ingredient union yielded 184 records, each reviewed in context. Four abstracts produced six lexical pairs across five frozen claims. Two abstracts use cinnamon as a diagnostic odor, one uses Rocket sign for a neurological finding in progressive supranuclear palsy, and one cites SAGE Publications in a fatigue study. The body screen excludes page navigation and publication boilerplate and retains citations embedded in the abstract. The evidence audit compares exact review keys against the union of the two screens. [Body retrieval inventory](mds-2026-inventory.tsv) · [Topic terms](mds-2026-topics.tsv) · [Topic screen](mds-2026-topic-screen.tsv) · [Lexical screen](mds-2026-lexical-screen.tsv) · [Coverage across 1,000 claims](mds-2026-claim-coverage.tsv) · [Individual reviews](mds-2026-reviews.tsv)

The body collector caches each successful source response separately. The final collector pass recovered the remaining publisher-hosting-alias records and produced zero pending URLs. An independent offline replay reproduced both the abstract and inventory hashes. The inventory lists 1,860 unique attachment URLs for 745 records, including 77 of the 184 flagged abstracts. A separate image inventory reconciles all 1,860 attachment URLs. Copyrighted HTML and extracted abstracts stay in the ignored build directory. [Attachment collection and screening](mds-2026-attachments.md)

The separate 55-page late-breaking booklet has 24 numbered abstracts. All 24 have contextual reviews keyed to their starting PDF pages. It supplies outcomes for the 57-person Prague gluten-free diet trial, the vutiglabridin clinical trial and the isolated pea lectin model. The Prague registry has no posted results. The official PDF was 6,875,905 bytes with SHA-256 `31c5804a0b1034dbdcaedbef4f5d90f0ef8dac6478ea87071996ee682fb8d1f4`. [Official late-breaking booklet](https://mdscongress.org/IC26-LBAs.pdf) · [Individual booklet reviews](mds-2026-late-breaking.tsv) · [Dated clinical trial reports](../../../research/2025-2029/Food-Experiment-WHO-CTG-Followup.md#twelve-month-gluten-free-diet-outcomes-in-prague) · [Dated model reports](../../../research/2025-2029/Food-Experiment-Botanical-Model-Followup.md#pea-lectin-and-motor-and-memory-proxies-in-rats)

The ketogenic diet poster’s forest plots include two single-group studies alongside randomized comparisons. The local record links all five original studies and gives the named foods and item-level outcomes available from the original trials. The papers assign entire diets. [Congress and primary study audit](../../../research/2025-2029/Food-Experiment-MDS-Diet-Followup.md#ketogenic-diet-motor-synthesis-and-its-primary-inputs)

## Replay

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$cache = "$experiment/build/mds-2026/title"
$screen = "$experiment/build/mds-2026/next-screen"
$followup = "$experiment/followup"
& "$experiment/tools/build-followup.ps1"
& "$experiment/tools/build-scan.ps1"
$mds = "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.mds.exe"
$scan = "$experiment/build/scan-3.3.1-i386-win32/bin/foodexperiment.scan.exe"
& $mds title-list $cache
& $mds collect $cache
& $mds replay $cache $screen
& $scan scan-topics "$screen/abstracts.tsv" "$followup/mds-2026-topics.tsv" "$screen/topics.tsv"
& $scan scan-index $experiment "$screen/abstracts.tsv" "$followup/hal-lexical-vocabulary.tsv" "$screen/lexical.tsv"
& $mds audit "$screen/topics.tsv" "$screen/lexical.tsv" "$followup/mds-2026-reviews.tsv"
```

Run one collector per cache. Replay can use a separate output directory while collection continues. A replay with pending bodies or a review audit with pending dispositions returns exit code 2 and preserves its outputs. Review audit output lists the pending record IDs.

| Replayed file | SHA-256 |
| --- | --- |
| Abstract body index | `0efd60d7865bae0d8eb2379a9298ae19a56e4e077fc2b79e08849852394d9bac` |
| Body retrieval inventory | `d7f48ef491bf399b5ff5105eb3124ef2169473ca6dc058bd4bb2e33ae683640c` |
