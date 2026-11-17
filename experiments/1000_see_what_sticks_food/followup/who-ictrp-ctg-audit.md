# ClinicalTrials.gov crosswalk for the WHO Parkinson export

The WHO public basic `Parkinson` export processed November 12, 2026 at 09:13:15 (WHO `Export_date`) supplied 324 exposure candidates from 4,471 distinct rows. This crosswalk covers the 212 exact ClinicalTrials.gov identifiers among those flags, of 3,054 ClinicalTrials.gov identifiers in the full export. The other 112 exposure candidates and any additional `Parkinsonism` records are tracked in the WHO screening ledger. [Export and accession audit](who-ictrp-export-audit.md) [WHO candidate screening](who-ictrp-screening.md)

| ClinicalTrials.gov coverage | Records |
| --- | ---: |
| Exact unique identifiers in WHO exposure queue | 212 |
| Dated official ClinicalTrials.gov extract verified by identifier | 212 |
| Existing candidate and disposition ledger match | 31 |
| Of those existing matches, recent outcome recheck | 9 |
| New record-level review of WHO flags | 181 |
| Pending individual record-level review | 0 |
| Official extracts with posted results, including other intervention categories | 39 |

The 181 records without an existing exact review comprised 90 contextual mentions, 86 broad food-term hits, three SAGE drug-name collisions and two drug pharmacokinetics rows involving grape-associated resveratrol. Of the 90 contextual records, 20 had posted registry results for the registered intervention or assessment. The ClinicalTrials.gov extracts were retrieved November 12 at 02:45:27 UTC from data processed November 10 at 10:00:05 UTC. Dates and result flags in the ledger come from those direct extracts. WHO mirror metadata and later official updates can differ. An absent posted summary flag describes the archived record. Exact trial-linked literature searches were performed for selected plausible exposures and reported individually. [Record-level crosswalk](who-ictrp-ctg-dispositions.tsv) [Existing exact registry dispositions](registry-dispositions.tsv) [Existing outcome rechecks](clinicaltrials-results-recheck.tsv)

## Source-linked findings

- NCT01563913 first posted March 27, 2012, posted its first results May 29, 2018 and last updated June 29, 2018 in the archived direct record. The posted forceplate endpoint records dyskinesia in 3 of 9 assessed participants taking isolated DHA and 6 of 15 taking sugar placebo. The sample declined during follow-up and the table lacks a decisive between-group contrast. The isolated compound gives no baked-trout estimate for claim 0113. [DHA registration and preparation](../../../research/2010-2014/Food-Experiment-WHO-CTG-Followup.md#isolated-dha-and-dyskinesia-registration) [DHA result and source links](../../../research/2015-2019/Food-Experiment-WHO-CTG-Followup.md#isolated-dha-and-dyskinesia-results) [ClinicalTrials.gov first-results metadata](https://clinicaltrials.gov/api/v2/studies/NCT01563913)
- PARKA NCT04322461 first posted March 26, 2020 and last updated June 3, 2025 in the archived direct record. That version lists a commercial MCT supplement with exercise and has no posted results. The exact-NCT 2025 AD/PD abstract SHIFT 01-102 describes D-beta-hydroxybutyrate and nicotinamide riboside with exercise, reporting 17% attention and psychomotor speed change in ten Parkinson participants. The administered exposure remains unresolved and the abstract gives no refined coconut oil estimate for claim 0598. [PARKA registration](../../../research/2020-2024/Food-Experiment-WHO-CTG-Followup.md#parka-supplement-and-exercise-registration) [PARKA conference abstract and source links](../../../research/2025-2029/Food-Experiment-WHO-CTG-Followup.md#parka-conference-outcome-and-supplement-discrepancy)
- NCT01016470 links a 2012 full report with favorable fatigue scores for the two-supplement mixture VIUSID and ALZER. The paper lists generic mint with numerous other constituents and differs from the registration in naming fatigue as primary. The trial gives no fresh spearmint estimate for claim 0518. [Registration](../../../research/2005-2009/Food-Experiment-WHO-CTG-Followup.md#viusid-and-alzer-trial-registration) [2012 outcome](../../../research/2010-2014/Food-Experiment-WHO-CTG-Followup.md#viusid-and-alzer-fatigue-outcome)
- NCT04512599 evaluates a mixed prebiotic bar containing rice bran fiber. It gives no rice bran oil exposure and the constipation and stool-frequency comparisons were inconclusive for claim 0801. The oat, corn, wheat and sorghum bran drink trial has no posted results. [Rice bran fiber and bowel outcomes](../../../research/2020-2024/Food-Experiment-WHO-CTG-Followup.md#prebiotic-fiber-bar-registration-and-outcomes) [Mixed bran drink registration](../../../research/2020-2024/Food-Experiment-WHO-CTG-Followup.md#bran-and-psyllium-registrations)
- NCT05700838 is a single-arm cough training study. Its exact-NCT article verifies that aerosolized capsaicin was a stimulus in the reflex cough assessment. Neither this study nor the continuing airway rehabilitation trial NCT05700825 evaluates oral ground cayenne for swallowing difficulty, claim 0724. [Outcome and study methods](../../../research/2020-2024/Food-Experiment-WHO-CTG-Followup.md#aerosolized-capsaicin-as-a-cough-test-stimulus)
- NCT04983290 registers a texture-modified mixed food plan and NCT05238545 registers a gluten-free diet in Parkinson disease and multiple system atrophy. No posted results or linked primary outcomes were located. [Texture-modified food plan](../../../research/2020-2024/Food-Experiment-WHO-CTG-Followup.md#texture-modified-food-plan-registration) [Gluten-free trial](../../../research/2020-2024/Food-Experiment-WHO-CTG-Followup.md#gluten-free-diet-in-parkinson-disease-and-multiple-system-atrophy)

## Replay

From the repository root, the native `foodexperiment.whoctg` program reads the screened WHO candidate file, the existing direct registry ledgers and dated trial extracts. It verifies record identifiers, input widths and review note paths and writes one row per exact WHO ClinicalTrials.gov identifier. The fourth input can be the saved crosswalk or a five-column authored review file with fields `nct_id`, `exposure_role`, `assessment`, `publication_status`, and `research_note`. The following replay writes to a separate output.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$out = "$experiment/build/who-ictrp-ctg"
New-Item -ItemType Directory -Force $out | Out-Null
& fpc -B -Pi386 -Twin32 -Sa -Cr -Co -Ci "-Fu$experiment/tools" "-FU$out" "-FE$out" "$experiment/tools/foodexperiment.whoctg.lpr"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$source = "$experiment/build/who-ictrp/screen/who-ictrp-candidates.tsv"
$saved = "$experiment/followup/who-ictrp-ctg-dispositions.tsv"
& "$out/foodexperiment.whoctg.exe" $experiment $source "$out/replay.tsv" $saved
```
