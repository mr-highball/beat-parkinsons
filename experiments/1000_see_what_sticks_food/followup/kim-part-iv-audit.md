# KIM Part IV association audit

The KIM trial's 2026 Results describe no association between *Roseburia hominis* abundance and MDS-UPDRS Parts II or IV after multiple-testing correction. Its Discussion describes an association with lower Part IV scores. The public supplementary code specifies diet-stratified univariable random-intercept models and requests an adjusted q-value within each diet. The supplement provides the analysis code without the resulting model table. [Results](../../../research/2025-2029/Source-Text/PMC13738181.txt#L214) · [Discussion](../../../research/2025-2029/Source-Text/PMC13738181.txt#L254) · [Supplementary analysis code](https://pmc-oa-opendata.s3.amazonaws.com/PMC13738181.1/mmc3.zip)

## Public data check

The October 26, 2026 Borealis release provides the original clinical, sample mapping, raw taxonomy count, and normalized abundance inputs under CC BY 4.0. The native replay checks their repository MD5 values and joins the samples by the keys specified in the published code. The released taxonomy counts supply the feature labels used by the supplementary code's separately named taxonomy input. It checks presence in the normalized sample table, excludes the 11 duplicate fresh-frozen samples named in the supplement, and verifies the clinical join on participant, visit, age, and sex. The resulting 148 sequencing samples match the article's reported sample count. [Public dataset version 1](https://doi.org/10.5683/SP4/EKV3YZ) · [Report and data note](../../../research/2025-2029/Food-Experiment-Oil-Followup.md#kim-public-dataset)

The replay computes relative abundance from the single matching genus and species row divided by all reads for each sample, then standardizes it across the 148 samples. It fits one restricted maximum likelihood model for each clinical, biomarker, or weight predictor within each diet, with a participant random intercept and available cases for that predictor. These models use the Part IV score at each visit. They estimate a repeated-measure association between the score and abundance, with no diet treatment effect or change-score predictor.

| Diet | Part IV observations | Participants | Abundance SD per Part IV point | Standard error | Normal Wald p | BH q |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Mediterranean ketogenic | 76 | 40 | −0.09083 | 0.04037 | .02444 | .36660 |
| MCT-supplemented Mediterranean | 72 | 40 | −0.03120 | 0.02678 | .24398 | .66791 |

The replay uses normal Wald probabilities and Benjamini–Hochberg correction over the 15 substantive predictors in each diet. The published R code loads lmerTest, and its exact degrees of freedom, package versions, model output, and treatment of the participant identifier in the adjustment family are unavailable. An inverse association before adjustment in the ketogenic period and inconclusive adjusted results in both periods could explain the difference in wording. The published table or author clarification would be needed to confirm that explanation. The sample contains fractionated MCT supplementation and whole-diet comparisons. This check supplies no isolated oil or dyskinesia severity estimate. [All 30 aggregate model rows](kim-part-iv-model.tsv) · [Native replay](../tools/foodexperiment.kim.lpr) · [Model code](../tools/foodexperiment.kimmodel.pas)

## Replay

Use version 1 originals of clinical file 1184838, sample mapping 1184834, normalized abundance 1184837, and taxonomy counts 1184836. The repository's original download format preserves the recorded checksums. The default Dataverse tabular export can have different bytes.

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$inputDir = "$experiment/build/kim-dataverse"
New-Item -ItemType Directory -Force $inputDir | Out-Null
Invoke-WebRequest 'https://borealisdata.ca/api/access/datafile/1184838?format=original' -OutFile "$inputDir/KIM_clinical-original.csv"
Invoke-WebRequest 'https://borealisdata.ca/api/access/datafile/1184834?format=original' -OutFile "$inputDir/KIM_metadata-original.csv"
Invoke-WebRequest 'https://borealisdata.ca/api/access/datafile/1184837?format=original' -OutFile "$inputDir/KIM_normalized_abundance-original.tsv"
Invoke-WebRequest 'https://borealisdata.ca/api/access/datafile/1184836?format=original' -OutFile "$inputDir/KIM_taxonomic_counts-original.csv"
& "$experiment/tools/build-followup.ps1"
& "$experiment/build/followup-3.3.1-i386-win32/bin/foodexperiment.kim.exe" $inputDir > "$inputDir/model-replay.tsv"
```

The checked build matched the analytic slope, variance ratio, and standard error for a balanced repeated-measures fixture, plus the zero-random-variance boundary and four-value false discovery rate fixture. Two runs over the four release files produced byte-identical aggregate tables.
