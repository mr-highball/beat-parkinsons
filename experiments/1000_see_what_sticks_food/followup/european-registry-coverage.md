# European trial registries

## CTIS

The November 12, 2026 public CTIS API scan reconciled all pages returned for five separately submitted search terms. Parkinson returned 81 trials, Parkinsonism six, Parkinsonian eight, and the two historical terms returned zero. All 88 deduplicated trials returned public details. Screening used titles, conditions, trial products and endpoints, followed by record-level assessment of plausible food exposures. The search surfaced a pharmaceutical cannabis comparison with sesame and linseed oil as the placebo blend. A separate fed-state study measured absorption of an investigational drug in healthy volunteers. [Query ledger](ctis-query.tsv) · [Inventory](ctis-inventory.tsv) · [CTIS search guidance](https://euclinicaltrials.eu/search-tips-and-guidance/?lang=en)

## EU Clinical Trials Register

The November 12 retry retrieved the complete legacy protocol index for two broad queries. Parkinson returned 443 rows across 23 pages and Parkinsonism returned 259 rows across 13 pages. There were 457 distinct trial IDs, including 282 with a results link. The two distinct entries with blank titles were checked on their national protocol pages. The first lexical title screen identified sage, omega-3, a high-fat meal interaction, and two transdermal nicotine protocols. The separate Article 45 tab reconciled all six returned document references and found no dietary Parkinson comparison. [Access ledger](european-registry-access.tsv) · [Parkinson inventory](eudract-parkinson.tsv) · [Parkinsonism inventory](eudract-parkinsonism.tsv) · [Detail dispositions](eudract-dispositions.tsv) · [Article 45 audit](eudract-article45-coverage.md)

The official attachment endpoint served the five-page 2019 sage report. Its available outcomes concern cognition and salivation. A 2016 sponsor attachment supplied the fed-to-fasted pharmacokinetic contrast for ropinirole, already reported in a 2008 FDA review. The completed Gemelli omega-3 protocol and the 2014 Pomponi report share the site and clinical objectives, with linkage unconfirmed. [Sage outcomes](../../../research/2015-2019/Food-Experiment-Herb-Spice-Followup.md#sage-cognitive-trial-results-attachment) · [Ropinirole results](../../../research/2015-2019/Food-Experiment-European-Registry-Followup.md#ropinirole-meal-study-sponsor-summary) · [Gemelli protocol assessment](../../../research/2005-2009/Food-Experiment-European-Registry-Followup.md#omega-3-capsules-and-parkinson-mood-symptoms)

## German Clinical Trials Register

The BfArM bulk export dated November 12, 2026 contained 22,856 rows and 22,846 unique IDs. All 10 repeated IDs shared first and duplicate update dates and registry statuses. None occurred in the Parkinson-related inventory. The scan searched German and English titles, conditions, descriptions, arms, outcomes and eligibility text for Parkinson terminology, along with ICD-10 G20 codes. It found 271 title or condition matches, 91 matches in other eligible fields, and 287 records mentioning Parkinson’s only in their exclusion criteria. The scanner flagged 129 records for dietary or ingredient terms, including 53 exclusion-only Parkinson matches. The screen used the clinical fields of plausible records to distinguish assigned food, dietary bundles, formulations, diagnostic challenges and mentions unrelated to the exposure. [Export documentation](https://www.bfarm.de/SharedDocs/Downloads/EN/BfArM/DRKS/drks-help-application-public.pdf?__blob=publicationFile) · [Query ledger](drks-query.tsv) · [Repeated ID ledger](drks-duplicates.tsv) · [Manual dispositions](european-registry-dispositions.tsv)

The archive SHA-256 was `47241855573f2c5323bc11ce044b9f2a76e628ed2db24c16ebc8bfcd1f6f97cd`. The JSON member SHA-256 was `a83df29a53fadea676af3a605f965b15c023f46b0f956ba27736d230bed22a78`. The export and detailed screening fields are retained in the experiment’s build directory.

The most relevant newly traced outcomes were the resistant starch supplement extension and the motor and olfaction results from the same fatty acid and prebiotic trial that reported constipation separately. The interventions were formulated supplements or combined diets. [2015–2019 research](../../../research/2015-2019/Food-Experiment-European-Registry-Followup.md) · [2020–2024 research](../../../research/2020-2024/Food-Experiment-European-Registry-Followup.md) · [2025–2029 research](../../../research/2025-2029/Food-Experiment-European-Registry-Followup.md)

Run from the repository root. The DRKS command takes the JSON member extracted from the public download archive. Use the downloaded member name for the new snapshot.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
& "$experiment/tools/build-ctis.ps1"
& "$experiment/tools/build-drks.ps1"
& "$experiment/tools/build-followup.ps1"
& "$experiment/build/ctis-3.3.1-i386-win32/bin/foodexperiment.ctis.exe" "$experiment/build/ctis-search-refresh"
& "$experiment/build/drks-3.3.1-i386-win32/bin/foodexperiment.drks.exe" $experiment "$experiment/build/drks-search/DRKS_all_20261112.json" "$experiment/build/drks-search-refresh"
$eudract = "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.eudract.exe"
& $eudract "$experiment/build/eudract/park" Parkinson
& $eudract "$experiment/build/eudract/parkinsonism" Parkinsonism
```
