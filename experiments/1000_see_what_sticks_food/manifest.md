# Parkinson's food thought experiment results

Verdicts are tracked for **1,000** frozen statements. Confidence values are reviewer judgments.

- Frozen SHA-256 `0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f`
- [Statement verdict ledger](verdicts.tsv)
- [First-pass search ledger](queries.tsv) with 2000 completed records and 1000 statements covered
- [Local file coverage](local-coverage.tsv)
- [Local candidate screening](local-screening.tsv)
- [Counts by category and claim direction](results-summary.tsv)

## Verdict counts

| Verdict | Local review | Current verdict |
| --- | ---: | ---: |
| Unknown | 1000 | 939 |
| Maybe True | 0 | 27 |
| Maybe False | 0 | 34 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

Twenty-nine Round 1 claims carry a checked version 1 evidence scorecard ([scorecards.tsv](followup/scorecards.tsv), [scorecard-sources.tsv](followup/scorecard-sources.tsv)); scores on those claims denote ordinal review tiers (50 open, 50.005 minimal signal, 51 limited clinical link, 55 direct clinical signal, 60 strong directional evidence). Fifty remaining legacy directional claims are scheduled for systematic v1 scorecard migration using Oracle MCP first.

### Highlighted checked v1 findings

- **Ground saffron and Parkinson depression ([0063](statements/0063.txt), Maybe False, 55 — direct clinical signal):** Randomized 92-person Parkinson trial of fixed oral Sargol stigma powder tablets favored lower DASS depression (-4.58 points, 95% CI -8.34 to -0.81), opposing the frozen worsening hypothesis. Independent Tehran trial also favored Hamilton depression with two inconclusive secondary scales.
- **Dried saffron and Parkinson fatigue ([0485](statements/0485.txt), Maybe False, 55 — direct clinical signal):** Same 92-person Parkinson trial favored lower Parkinson Fatigue Scale scores (-9.20 points, 95% CI -13.76 to -4.65); original public registration omitted the standalone fatigue scale until a post-receipt revision, keeping the signal provisional.
- **Brewed black tea and Parkinson rest tremor ([0904](statements/0904.txt), Maybe True, 51 — limited clinical link):** Parkinson placebo comparison isolates rest tremor with a small favorable isolated-caffeine point estimate (CI spanning zero), linked by chromatography to brewed black tea; open-label mixed responses limit transfer.
- **Brewed green tea and Parkinson fatigue ([0948](statements/0948.txt), Maybe True, 51 — limited clinical link):** Uncontrolled 14-completer Parkinson cohort recorded higher mean Fatigue Severity Scale scores (28.4 to 32.1) over three months, contrasting with a postoperative brewed-tea trial outside Parkinson disease.
- **Extra-virgin olive oil and Parkinson constipation ([0072](statements/0072.txt), Maybe True, 50.005 — minimal signal):** Double-blind randomized trial in 140 analyzed adults with functional constipation (Joukar et al. 2025, PMC12694839) favored raw extra-virgin over refined olive oil on Rome III severity (-4.22, p < 0.001) and week-4 Bristol stool form (+1.14, p < 0.001) while excluding neurological disease, lacking an oil-free arm and omitting polyphenol assay. Parkinson Mediterranean diet trials (MEDI-PD p = 0.600; KIM shared olive oil) did not isolate olive oil.
- **Minimal easing leans outside Parkinson disease (50.005):** Brewed coffee and fatigue ([0121](statements/0121.txt), Maybe False), ground saffron and insomnia ([0218](statements/0218.txt), Maybe True), raw celery stalk and rest tremor ([0281](statements/0281.txt), Maybe False), cold-pressed olive oil and anxiety ([0343](statements/0343.txt), Maybe True), grated ginger and constipation ([0581](statements/0581.txt), Maybe False), and raw blueberry and constipation ([0746](statements/0746.txt), Maybe True).

### Search coverage and limits

- **First-pass baseline:** All 30,593 baseline archive files were read with zero extraction failures ([local-coverage.tsv](local-coverage.tsv)), and 2,000 neutral Europe PMC queries covered all 1,000 frozen statements ([queries.tsv](queries.tsv)).
- **Exact context overlay:** The uncapped original Europe PMC overlay spans 61,252 claim–source pairs across 679 claims (321 claims had zero hits). Four polysemous tokens (date, sage, orange, ig, 20 claims) account for 68.5% of the remaining queued pairs; non-homograph clinical review, v1 scorecard migration and discovery across the 17 zero-directional symptoms take priority over manual Priority-6 homograph clearing. [Context coverage](followup/context-coverage/README.md) · [Study assessments](followup/assessments.tsv)
- **Historical checkpoint archive:** The complete chronological log of checkpoints through P156 is preserved verbatim in [followup/checkpoint-log.md](followup/checkpoint-log.md).

## Directional verdicts

- [0019](statements/0019.txt) **Maybe True** (51%) Consuming toasted nigella seed reduces depressive symptom severity in people with Parkinson's disease.
- [0025](statements/0025.txt) **Maybe False** (51%) Consuming fresh sage worsens pain severity in people with Parkinson's disease.
- [0039](statements/0039.txt) **Maybe False** (51%) Consuming cold-pressed sesame oil worsens anxiety severity in people with Parkinson's disease.
- [0060](statements/0060.txt) **Maybe False** (51%) Consuming dried sage worsens insomnia severity in people with Parkinson's disease.
- [0063](statements/0063.txt) **Maybe False** (55%) Consuming ground saffron worsens depressive symptom severity in people with Parkinson's disease.
- [0065](statements/0065.txt) **Maybe True** (51%) Consuming cold-pressed walnut oil reduces pain severity in people with Parkinson's disease.
- [0072](statements/0072.txt) **Maybe True** (50.005%) Consuming extra-virgin olive oil reduces constipation severity in people with Parkinson's disease.
- [0082](statements/0082.txt) **Maybe True** (51%) Consuming brewed black tea reduces bradykinesia severity in people with Parkinson's disease.
- [0100](statements/0100.txt) **Maybe False** (52%) Consuming plain dark chocolate worsens anxiety severity in people with Parkinson's disease.
- [0110](statements/0110.txt) **Maybe False** (51%) Consuming refined coconut oil worsens postural instability severity in people with Parkinson's disease.
- [0121](statements/0121.txt) **Maybe False** (50.005%) Consuming brewed coffee worsens fatigue severity in people with Parkinson's disease.
- [0128](statements/0128.txt) **Maybe False** (51%) Consuming fresh rosemary worsens depressive symptom severity in people with Parkinson's disease.
- [0133](statements/0133.txt) **Maybe True** (51%) Consuming brewed lemon balm reduces depressive symptom severity in people with Parkinson's disease.
- [0139](statements/0139.txt) **Maybe False** (51%) Consuming ground nigella seed worsens fatigue severity in people with Parkinson's disease.
- [0141](statements/0141.txt) **Maybe True** (51%) Consuming cold-pressed flaxseed oil reduces anxiety severity in people with Parkinson's disease.
- [0144](statements/0144.txt) **Maybe True** (51%) Consuming toasted sesame oil reduces pain severity in people with Parkinson's disease.
- [0161](statements/0161.txt) **Maybe True** (52%) Consuming ground cinnamon reduces pain severity in people with Parkinson's disease.
- [0168](statements/0168.txt) **Maybe True** (51%) Consuming ground nutmeg worsens constipation severity in people with Parkinson's disease.
- [0171](statements/0171.txt) **Maybe False** (51%) Consuming toasted fennel seed worsens fatigue severity in people with Parkinson's disease.
- [0180](statements/0180.txt) **Maybe False** (51%) Consuming ground nigella seed worsens insomnia severity in people with Parkinson's disease.
- [0181](statements/0181.txt) **Maybe False** (51%) Consuming dried cherry worsens fatigue severity in people with Parkinson's disease.
- [0199](statements/0199.txt) **Maybe False** (51%) Consuming ground anise seed worsens pain severity in people with Parkinson's disease.
- [0218](statements/0218.txt) **Maybe True** (50.005%) Consuming ground saffron reduces insomnia severity in people with Parkinson's disease.
- [0225](statements/0225.txt) **Maybe True** (51%) Consuming grated turmeric reduces swallowing difficulty severity in people with Parkinson's disease.
- [0229](statements/0229.txt) **Maybe False** (51%) Consuming virgin coconut oil worsens fatigue severity in people with Parkinson's disease.
- [0262](statements/0262.txt) **Maybe True** (51%) Consuming cold-pressed sesame oil reduces depressive symptom severity in people with Parkinson's disease.
- [0267](statements/0267.txt) **Maybe False** (51%) Consuming refined sunflower oil worsens swallowing difficulty severity in people with Parkinson's disease.
- [0277](statements/0277.txt) **Maybe False** (51%) Consuming ground anise seed worsens fatigue severity in people with Parkinson's disease.
- [0281](statements/0281.txt) **Maybe False** (50.005%) Consuming raw celery stalk worsens rest tremor severity in people with Parkinson's disease.
- [0309](statements/0309.txt) **Maybe False** (51%) Consuming raw banana worsens anxiety severity in people with Parkinson's disease.
- [0329](statements/0329.txt) **Maybe False** (51%) Consuming poached egg worsens fall frequency in people with Parkinson's disease.
- [0340](statements/0340.txt) **Maybe False** (51%) Consuming toasted cumin worsens attention impairment in people with Parkinson's disease.
- [0343](statements/0343.txt) **Maybe True** (50.005%) Consuming cold-pressed olive oil reduces anxiety severity in people with Parkinson's disease.
- [0362](statements/0362.txt) **Maybe True** (51%) Consuming dried thyme reduces anxiety severity in people with Parkinson's disease.
- [0404](statements/0404.txt) **Maybe False** (51%) Consuming cold-pressed sesame oil worsens fatigue severity in people with Parkinson's disease.
- [0406](statements/0406.txt) **Maybe True** (51%) Consuming brewed lemongrass worsens daytime sleepiness severity in people with Parkinson's disease.
- [0470](statements/0470.txt) **Maybe False** (51%) Consuming cold-pressed flaxseed oil worsens constipation severity in people with Parkinson's disease.
- [0485](statements/0485.txt) **Maybe False** (55%) Consuming dried saffron worsens fatigue severity in people with Parkinson's disease.
- [0513](statements/0513.txt) **Maybe False** (51%) Consuming virgin coconut oil worsens daytime sleepiness severity in people with Parkinson's disease.
- [0560](statements/0560.txt) **Maybe True** (51%) Consuming ground cumin reduces constipation severity in people with Parkinson's disease.
- [0581](statements/0581.txt) **Maybe False** (50.005%) Consuming grated ginger worsens constipation severity in people with Parkinson's disease.
- [0629](statements/0629.txt) **Maybe True** (51%) Consuming cold-pressed olive oil reduces bradykinesia severity in people with Parkinson's disease.
- [0639](statements/0639.txt) **Maybe True** (51%) Consuming cold-pressed flaxseed oil reduces pain severity in people with Parkinson's disease.
- [0642](statements/0642.txt) **Maybe False** (51%) Consuming grated turmeric worsens walking slowness in people with Parkinson's disease.
- [0659](statements/0659.txt) **Maybe True** (51%) Consuming fresh summer savory reduces pain severity in people with Parkinson's disease.
- [0663](statements/0663.txt) **Maybe True** (51%) Consuming poached salmon reduces anxiety severity in people with Parkinson's disease.
- [0725](statements/0725.txt) **Maybe True** (51%) Consuming grated ginger reduces pain severity in people with Parkinson's disease.
- [0746](statements/0746.txt) **Maybe True** (50.005%) Consuming raw blueberry reduces constipation severity in people with Parkinson's disease.
- [0812](statements/0812.txt) **Maybe True** (51%) Consuming ground turmeric reduces pain severity in people with Parkinson's disease.
- [0814](statements/0814.txt) **Maybe True** (51%) Consuming fresh basil reduces insomnia severity in people with Parkinson's disease.
- [0838](statements/0838.txt) **Maybe False** (51%) Consuming virgin coconut oil worsens apathy severity in people with Parkinson's disease.
- [0860](statements/0860.txt) **Maybe False** (51%) Consuming raw grape worsens anxiety severity in people with Parkinson's disease.
- [0874](statements/0874.txt) **Maybe False** (51%) Consuming poached trout worsens depressive symptom severity in people with Parkinson's disease.
- [0878](statements/0878.txt) **Maybe False** (51%) Consuming raw orange worsens constipation severity in people with Parkinson's disease.
- [0883](statements/0883.txt) **Maybe False** (51%) Consuming fresh sage worsens fatigue severity in people with Parkinson's disease.
- [0889](statements/0889.txt) **Maybe False** (51%) Consuming ground cinnamon worsens walking slowness in people with Parkinson's disease.
- [0904](statements/0904.txt) **Maybe True** (51%) Consuming brewed black tea reduces rest tremor severity in people with Parkinson's disease.
- [0913](statements/0913.txt) **Maybe True** (51%) Consuming cold-pressed flaxseed oil reduces bradykinesia severity in people with Parkinson's disease.
- [0948](statements/0948.txt) **Maybe True** (51%) Consuming brewed green tea worsens fatigue severity in people with Parkinson's disease.
- [0949](statements/0949.txt) **Maybe False** (51%) Consuming frozen raspberry worsens executive function impairment in people with Parkinson's disease.
- [0953](statements/0953.txt) **Maybe False** (51%) Consuming boiled barley worsens anxiety severity in people with Parkinson's disease.
