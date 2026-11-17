# ISRCTN search and screening

The November 12, 2026 search queried the ISRCTN default XML API for `Parkinson OR Parkinsonism OR Parkinsonian OR "paralysis agitans" OR "shaking palsy"` across indexed trial text. A one-record probe reported 492. The native scanner made 39 sequential date-partition requests and subdivided responses reporting more than 50 records. The 20 final date partitions yielded 492 unique registrations. Their reported counts reconciled against the parent partitions and unrestricted probe. `dateApplied` partitions use submission dates, while the inventory’s date column uses public identifier assignment. The search covers the returned text query, and trials with other terminology may remain outside it. [ISRCTN API documentation](https://www.isrctn.com/editorial/retrieveFile/81786542-9920-48a0-8fce-09f8428ab843/37855)

The inventory records title, condition, study type and exposure flags for all 492 records. There were 161 records naming Parkinson’s or a search synonym in the condition field, and 166 records with an exposure flag across the full inventory. The screening checked titles and conditions, then examined intervention, eligibility and outcome fields for plausible leads, including mixed populations and the unflagged *Withania somnifera* title. Text flags include incidental matches such as dates, place names, test materials, medication instructions and exclusions. The manual dispositions preserve relevant records and representative exclusions. Report searches used registry identifiers, intervention names, scientific titles and investigators where available. [Query ledger](isrctn-query.tsv) · [Inventory](isrctn-inventory.tsv) · [Manual dispositions](isrctn-dispositions.tsv)

The closest culinary match was the caffeinated versus decaffeinated instant coffee trial. Its posted conference abstract gives attention results in healthy older adults and dementia with Lewy bodies. The frozen coffee claim specifies brewed coffee and fatigue severity, so it remains open. Further registry and publication follow-up remains open for the records marked results open in the disposition ledger. [2010–2014 research](../../../research/2010-2014/Food-Experiment-ISRCTN-Followup.md) · [2015–2019 research](../../../research/2015-2019/Food-Experiment-ISRCTN-Followup.md) · [2020–2024 research](../../../research/2020-2024/Food-Experiment-ISRCTN-Followup.md) · [2025–2029 research](../../../research/2025-2029/Food-Experiment-ISRCTN-Followup.md)

Run from the repository root to retrieve a fresh snapshot. The output directory holds the query log, trial inventory, screening fields and raw XML responses for rescreening.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
& "$experiment/tools/build-isrctn.ps1"
$isrctn = "$experiment/build/isrctn-3.3.1-i386-win32/bin/foodexperiment.isrctn.exe"
& $isrctn $experiment "$experiment/build/isrctn-search-refresh"
```
