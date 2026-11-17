# WHO ICTRP public export audit

The public basic form returned 4,471 trials for `Parkinson` on November 12, 2026. The public all-record XML action produced 4,471 trial elements, and the native parser verified distinct TrialIDs and internal numbers. A second full export for `Parkinsonism` added 209 TrialIDs, including 22 flagged by the exposure screen. A quoted `"Parkinson disease"` search exported 3,302 rows already present in the first search. Across the three reported result sets there were 8,104 appearances and 4,680 distinct TrialIDs. The public advanced condition form returned an error page and supplied no count. [Query counts, export timestamps and hashes](who-ictrp-retrieval.tsv) · [Official search portal](https://trialsearch.who.int/) · [WHO query guidance](https://www.who.int/tools/clinical-trials-registry-platform/the-ictrp-search-portal/search-tips)

The `Parkinson` snapshot covers 18 providers, including 78 TCTR, 91 ReBEC and 102 ChiCTR rows. It includes known exact controls NCT05469997, TCTR20210303005, TCTR20230204001, RBR-36q469s, NCT05084365, and ISRCTN13221188. The Iranian standardized ginger trial IRCT20251028067794N1 did not appear as an exact accession. These results supply complementary discovery. They depend on the registered terms, provider import dates, and the search expressions, so national inventories and direct registry outcome checks remain open. [WHO portal provider import dates](https://trialsearch.who.int/) · [Iranian trial and its direct registration](../../../research/2025-2029/Food-Experiment-Iran-Registry-Followup.md#standardized-ginger-powder-in-parkinson-disease)

WHO provides a research download through the search portal and publishes conditions on use and redistribution. The XML files and unfiltered registry records remain under the ignored build directory. The experiment keeps the retrieval counts, dispositions and original study summaries with links to the first-party registries. Three linked articles have local summaries and verified primary links, with full-text rights recorded separately. [WHO download terms](https://www.who.int/tools/clinical-trials-registry-platform/network/who-data-set/downloading-records-from-the-ictrp-database) · [Candidate screening](who-ictrp-screening.md) · [ClinicalTrials.gov crosswalk](who-ictrp-ctg-dispositions.tsv) · [Source reuse checks](who-ictrp-source-reuse.md)

## Native replay

The Windows Free Pascal exporter submits the public basic form and streams the all-record XML response to a new file. It checks the count, export action, response type and XML root. The native parser then verifies the reported count against the actual records. The native replays returned the same 331 `Parkinsonism` and 4,471 `Parkinson` TrialIDs as the original exports, including the same 324 exposure candidates for `Parkinson`. The 26.6 MB replay took about nine minutes from the provider export timestamp to the finished file.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$exportDir = "$experiment/build/who-ictrp"
New-Item -ItemType Directory -Force $exportDir | Out-Null
& "$experiment/tools/build-followup.ps1"
$tools = "$experiment/build/followup-3.3.1-i386-win32/bin"
& "$tools/foodexperiment.whoexport.exe" Parkinson "$exportDir/parkinson-replay.xml"
& "$tools/foodexperiment.whoexport.exe" Parkinsonism "$exportDir/parkinsonism-replay.xml"
& "$tools/foodexperiment.whoexport.exe" '"Parkinson disease"' "$exportDir/exact-parkinson-disease-replay.xml"
```
