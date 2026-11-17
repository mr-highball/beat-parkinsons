# Iranian Registry of Clinical Trials follow-up

On November 12, 2026, the broad English and Persian searches returned 806 rows across 33 pages and 619 distinct registrations. Adding condition-field searches, ICD-10 G20, and Parkinsonism raised the combined set to 1,172 rows across 50 pages and 634 distinct registrations. The broad search returns some records outside Parkinson’s because the index also searches supporting text. The first title screen prioritized dietary interventions and botanical constituents. The detail ledger records sources evaluated in depth. [English search](https://irct.ir/search/result?query=Parkinson) · [Persian search](https://fa.irct.ir/search/result?query=%D9%BE%D8%A7%D8%B1%DA%A9%DB%8C%D9%86%D8%B3%D9%88%D9%86) · [Query ledger](irct-queries.tsv) · [Detail dispositions](irct-dispositions.tsv)

The direct registry records establish that the Tehran saffron capsule trial was registered in 2022 and the Isfahan saffron powder trial in 2024. The new ground-ginger lead matches the population and uses a standardized powder tablet, with total MDS-UPDRS as the primary endpoint. An item-level report or trial data would be needed to evaluate dyskinesia or stride length. [Saffron registrations](../../../research/2020-2024/Food-Experiment-Registry-Followup.md#iranian-registration-of-the-saffron-powder-trial) · [Ginger registration](../../../research/2025-2029/Food-Experiment-Iran-Registry-Followup.md#standardized-ginger-powder-in-parkinson-disease)

The registry led to a 2023 fava bean extract report and a licorice trial report first published in 2019. Neither ingredient was in the frozen pool. The two Mediterranean diet reports may overlap and estimate whole-diet effects. Recruitment is listed as complete for the four-arm curcumin comparison, the separate trehalose trial and the protein timing intervention. Their outcome publications remain open. [Fava bean report](../../../research/2020-2024/Food-Experiment-Broad-Bean-Followup.md#fava-bean-extract-versus-levodopa-in-a-fixed-sequence) · [2018–2019 registrations and licorice report](../../../research/2015-2019/Food-Experiment-Iran-Registry-Followup.md) · [2020–2024 registrations](../../../research/2020-2024/Food-Experiment-Registry-Followup.md#curcumin-with-and-without-resistance-training)

The registry's index summaries can omit individual intervention ingredients or outcomes. Further work includes additional Persian spellings and checking other title-screen candidates, results, and mixture ingredients. Every page returned for each recorded expression was retrieved and verified against the reported ranges. Raw pages and normalized index rows are stored under the experiment’s build directory.

Four targeted English and Persian date-palm searches retrieved all 84 reported appearances across six pages and 60 distinct IDs. They recovered the previously unlocated registry record for the topical osteoarthritis thesis and identified other pain and fatigue studies. [Date-palm retrieval and citation audit](date-palm-registry-recheck.md) · [Detail dispositions](irct-dispositions.tsv)

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
& "$experiment/tools/build-irct.ps1"
$irct = "$experiment/build/irct-3.3.1-i386-win32/bin/foodexperiment.irct.exe"
& $irct search irct.ir "$experiment/build/irct/english-full" Parkinson
& $irct search fa.irct.ir "$experiment/build/irct/persian-full" --query-file "$experiment/followup/irct-parkinson-fa.txt"
& $irct search irct.ir "$experiment/build/irct/english-condition" '@health_condition_description:Parkinson'
& $irct search fa.irct.ir "$experiment/build/irct/persian-condition" --query-file "$experiment/followup/irct-parkinson-condition-fa.txt"
& $irct search irct.ir "$experiment/build/irct/icd10-g20" '@health_condition_icd10_code:G20'
& $irct search irct.ir "$experiment/build/irct/parkinsonism" Parkinsonism
& $irct detail irct.ir "$experiment/build/irct/details" 13400 29414 5726 17642 29684 35857 45058 65247 75378 78559 87235 89515
```
