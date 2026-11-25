# Parkinson's food thought experiment results

Verdicts are tracked for **1,000** frozen statements. Confidence values are reviewer judgments.

- Frozen SHA-256 `77946aaccb5956b512ceb33c9bf729ead6113f26f34f6412be3bc5b3702f386f`
- [Statement verdict ledger](verdicts.tsv)
- [First-pass search ledger](queries.tsv) with 2000 completed records and 1000 statements covered
- [Counts by category and claim direction](results-summary.tsv)

## Verdict counts

| Verdict | Local review | Current verdict |
| --- | ---: | ---: |
| Unknown | 1000 | 906 |
| Maybe True | 0 | 53 |
| Maybe False | 0 | 41 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

All 1,000 frozen Round 3 claims (`0001`–`1000`) have been researched using the Oracle-first workflow, Rounds 1–2 evidence transfer, 2,000 neutral Europe PMC queries ([queries.tsv](queries.tsv)), live PubMed XML and ClinicalTrials.gov v2 sweeps, and inclusive cultural/traditional/public forum collection, and every claim carries a validated v1 evidence scorecard ([scorecards.tsv](followup/scorecards.tsv)) and completion audit row ([research-status.tsv](followup/research-status.tsv)).

Round 3 spans 37 unique ingredients (10 new pantry-expansion ingredients—9 across all 33 symptoms plus 25 reserved symptoms for `dill seed`—and 27 shared Round 1/2 exposures covering their non-overlapping reserved symptoms). Raw cross-round percentages are not directly comparable across rounds without category and ingredient standardization: Round 3 contains `553` food, `237` spice, `173` herb, and `37` oil claims.

| Verdict / Tier | Count | Notes |
| --- | ---: | --- |
| `Maybe True` | 53 | Directional evidence aligns with frozen hypothesis direction (`3` `limited_clinical_link`, `50` `minimal_signal`) |
| `Maybe False` | 41 | Directional evidence opposes frozen hypothesis direction (`5` `limited_clinical_link`, `36` `minimal_signal`) |
| `Unknown` (`Unknown (Researched)`) | 906 | Exhaustively checked; no defensible net directional lean (`open`, anchor `50`) |
| **Total frozen claims** | **1,000** | `500` frozen `reduces` / `500` frozen `worsens` |

By v1 scorecard tier and direction:
- **`limited_clinical_link` (anchor `51`):** `8` claims (`3` easing leans, `5` worsening leans)
- **`minimal_signal` (anchor `50.005`):** `86` claims (`79` easing leans, `7` worsening leans)
- **`open` (anchor `50`, displayed as `Unknown (Researched)`):** `906` claims
- **Symptom breadth:** `94` directional claims across `19` distinct symptoms and `29` ingredients (`8` ingredients remained `100%` `Unknown (Researched)`: `cardamom`, `cauliflower`, `chervil`, `chives`, `coconut oil`, `collard greens`, `corn oil`, `culinary star anise`).
- **Category breakdown:** `food` (`25` Maybe True, `26` Maybe False, `502` Unknown / `553` total), `spice` (`19` Maybe True, `9` Maybe False, `209` Unknown / `237` total), `herb` (`9` Maybe True, `6` Maybe False, `158` Unknown / `173` total), `oil` (`0` Maybe True, `0` Maybe False, `37` Unknown / `37` total).

### Highlighted checked v1 findings

- **Animal-protein meals and Parkinson daily OFF time ([0379](statements/0379.txt) poached chicken, [0502](statements/0502.txt) cooked clams, [0574](statements/0574.txt) baked cod — all Maybe False at `51`; [0718](statements/0718.txt) pasteurized cow's milk — Maybe True at `51`; limited clinical link, worsens):** Direct Parkinson clinical protein-redistribution and levodopa-competition trials (`Barichella 2006`, `Tsui 1989`, `Carter 1989`, `Eriksson 1988`), bridged via human postprandial large neutral amino acid (LNAA) kinetics (`Uhe 1992` `PMID:1542005`, `Soucy & Leblanc 1999` `PMID:10073471`, `Milan 2024` `PMID:38452857`, `Burke 2012` `PMID:22807528`, `Quaresma 2023` `PMID:37125032`), demonstrate that daytime animal-protein intake competes with levodopa absorption/transport and can worsen motor fluctuations / OFF time (tempered by patient-level heterogeneity in `Virmani 2016` and `Cucca 2015`). Consistent with Round 2 legume calibration, canned chickpeas (`0410`) stayed `open` given lower ileal digestibility and blunted EAA surges (`Kashyap 2019/2024`, `Kouw 2022`).
- **Brewed coffee — four clinical-tier links (`51`) plus strict decaffeinated separation (`0599`–`0630`):** Direct Parkinson crossover and randomized caffeine trials support `limited_clinical_link` (`51`) easing leans for brewed coffee on attention impairment ([0601](statements/0601.txt), Maybe True, `Sharma 2022` `PMID:35006304` + `Haskell-Ramsay 2018`), daytime sleepiness ([0605](statements/0605.txt), Maybe False, `Postuma 2012/2017`), and muscle rigidity ([0617](statements/0617.txt), Maybe True, `Postuma 2012`, tempered by 6-month `Postuma 2017`), alongside a `limited_clinical_link` (`51`) **worsening** lean on dyskinesia ([0609](statements/0609.txt), Maybe False, `Postuma 2017` Café-PD MDS-UPDRS 4.1+4.2 + `Shoulson & Chase 1975`). Brewed coffee also carried `minimal_signal` (`50.005`) **worsening** leans for anxiety ([0599](statements/0599.txt)), insomnia ([0615](statements/0615.txt), NEJM CRAVE `Marcus 2023`), and urinary urgency ([0628](statements/0628.txt)), whereas `decaffeinated` coffee received zero caffeine transfer and yielded a single `minimal_signal` easing lean on constipation ([0603](statements/0603.txt), Maybe True, direct decaf trials `Dulskas 2015`, `Rao 1998`, `Brown 1990`, tempered by null `Nasseri 2023`).
- **Additional two-sided worsening leans at minimal signal (`50.005`):** Ground cayenne pepper worsened nocturnal awakenings/insomnia ([0168](statements/0168.txt), Maybe True, `Stuck 2016` controlled PSG oral capsaicin awakening trial) and urinary urgency ([0177](statements/0177.txt), Maybe True, VA controlled cohort `Jarman 2023` `N=425` + `Shorter 2007`); pasteurized cow's milk carried a worsening lean on constipation ([0717](statements/0717.txt), Maybe False, elimination/challenge RCTs `Iacono 1998`, `Dehghani 2012`, `Mohammadi Bourkheili 2021`, tempered by adult null `Greenway 2026`); and plain dark chocolate carried a worsening lean on constipation ([0918](statements/0918.txt), Maybe False, `Fox 2019` `PMID:30912735` 72% dark vs. white chocolate crossover + `Muller-Lissner 2005`, strictly separating fiber-enriched cocoa husk drinks).
- **Plain dark chocolate easing leans (`5` minimal-signal claims at `50.005`):** Human cocoa/dark-chocolate trials supported minimal easing leans on attention ([0916](statements/0916.txt)), depressive symptoms ([0921](statements/0921.txt)), executive function ([0926](statements/0926.txt)), fatigue ([0928](statements/0928.txt), `Nemoto 2022` + `Sathyapalan 2010`, noting PD pilot `Coe 2022` CI spanning null), and walking slowness ([0944](statements/0944.txt), tempered by `Chou 2026` COSMOS null), while Parkinson motor symptoms stayed `open` per null `Wolz 2012` (`PMID:22584952`).
- **Pantry-expansion ingredients (`10` new ingredients, `39` directional claims):**
  - `celery seed` (`9` minimal-signal easing leans across `0197`–`0229`, strictly flagging `Zhou 2019` Table II duplications & `Azimi 2023` retraction)
  - `cashew` (`6` minimal-signal easing leans across `0092`–`0124`)
  - `coriander seed` (`6` minimal-signal easing leans across `0664`–`0696`, strictly separated from cilantro leaf and anchored by `Delavar Kasmaei 2016` `PMID:26889386`)
  - `culinary lavender` (`5` minimal-signal easing leans across `0804`–`0836`, oral lavender tea/Silexan trials balanced against double-blind null `Nikfarjam 2017`)
  - `chamomile` (`4` minimal-signal easing leans across `0260`–`0292`, balanced against null insomnia trial `Zick 2011`)
  - `clams` (`1` `limited_clinical_link` worsening `0502` + `3` minimal-signal easing leans)
  - `chia seed` (`3` minimal-signal easing leans incl. `Poltiyelova 2025` constipation with dry-chia esophageal impaction caveat `Simmelink 2017`)
  - `dill seed` (`2` minimal-signal easing leans incl. `0998` pain)
  - `collard greens` (`0 / 33` directional; confirmed low glucosinolate/sulforaphane profile via `Ðulovic 2023`) and `culinary star anise` (`0 / 33` directional; documented neurotoxic *Illicium anisatum* adulteration seizure cases `PMID:15492355`, `14762034`, `12014242`).
- **Additional minimal-signal easing leans across shared exposures (`37` claims at `50.005`):** Spanning `cherry` (`4`), `cayenne pepper` (`3` easing + `2` worsening), `chicken` (`3` easing + `1` clinical worsening), `celery leaf` (`3`), `cinnamon` (`3`), `cantaloupe` (`2`), `celery stalk` (`2`), `cilantro` (`2`), `date` (`2`, strictly *Phoenix dactylifera* whole fruit), `caraway` (`1`, excluding peppermint+caraway combinations), `carrot` (`1`, auditing & excluding contradictory `Fazdria 2024` `PMC10983098`), `chickpeas` (`1`), `clove` (`1`), `cranberry` (`1`, `0770` urinary urgency balanced against Cochrane `Williams 2023`), `cucumber` (`1`, `0794` pain), `cumin` (`1`, `0883` pain, strictly *Cuminum cyminum*), and `curry leaf` (`1`, `0908` pain, strictly *Murraya koenigii*).

### Key exclusions, safety boundaries, and open findings

- **Strict botanical, plant-part, matrix, and homonym boundaries:** Strictly separated `celery seed` (`0197`–`0229`), `celery stalk` (`0230`–`0259`), `celery leaf` (`0179`–`0196`), and synthetic pharmaceutical `dl-3-n-butylphthalide` (NBP); separated `coriander seed` (`0664`–`0696`) from `cilantro` leaf (`0458`–`0482`); separated *Cuminum cyminum* (`cumin`) from *Nigella sativa* ("black cumin"); separated *Murraya koenigii* (`curry leaf`) from commercial turmeric/curry-powder blends (`Ng 2006`); separated culinary *Gadus morhua* (`cod`) fillet from cod liver oil; separated *Allium schoenoprasum* (`chives`) from Chinese chives (*Allium tuberosum*, `Takemoto 2024`) and garlic/onion cohorts; separated *Elettaria cardamomum* (green cardamom) from *Amomum subulatum* (black cardamom, `Thomas 2026`); excluded peppermint+caraway multi-herb combinations (`Menthacarin`/`COLM-SST`) from monotherapy `caraway`; separated whole *Phoenix dactylifera* (`date`) fruit from calendar-date homonyms, date seeds, and date spathes; identified `corn oil` (`16 / 16` open) as an inert placebo capsule / solvent vehicle across neurological RCTs; kept `coconut oil` (`21 / 21` open) consistent with Round 1 (`FAIR-2` null `Diekmann 2026`); kept `cauliflower` (`31 / 31` open) distinct from broccoli-sprout sulforaphane supplements; excluded topical dental clove oil and pre- vs. post-lesion eugenol motor conflicts; and audited/excluded compromised or retracted papers (`Fazdria 2024`, `Al-Dalaeen 2026`, `Patel 2025`, retracted `PMID:33550058` / `PMID:36654869`).
- **Open findings (`906` claims):** All `906` open claims carry `verdict = Unknown` and `research_status = researched` (displaying as `Unknown (Researched)` in Parkinson's Oracle MCP and the Nyx web UI), with explicit unresolved exposure, preparation, endpoint, and Parkinson-population gaps recorded per claim in [research-status.tsv](followup/research-status.tsv).

### Search coverage and limits

- **Oracle-first & transfer baseline:** Audited all 37 Round 3 ingredients against catalog revision `282` (`39,989` indexed files) and transferred applicable Rounds 1–2 evidence across the 27 shared exposures before external retrieval. First-pass coverage rates are logged in [experiments/oracle-coverage/](../oracle-coverage/README.md).
- **External clinical & scientific retrieval:** Completed `2,000 / 2,000` neutral Europe PMC queries ([queries.tsv](queries.tsv), `0` failed queries, `1,129` with hits, `2,848` unique PMIDs), full live PubMed XML and ClinicalTrials.gov v2 sweeps across all 37 ingredients, and archived `729` newly extracted primary source texts under chronological `research/YYYY-YYYY/Source-Text/` buckets.
- **Inclusive cultural & experiential collection:** Archived `86` new traditional-practice, local-knowledge, personal-report, and anonymized public forum conversation records (Parkinson's UK Discourse, Cure Parkinson's HealthUnlocked, peer-reviewed ethnobotanical records) under `research/YYYY-YYYY/Cultural-and-Experiential/`, bringing total verified cultural records to `295` (`research.culture` PASS) with full topic mapping in `experiments/tools/parkinsons-oracle/cultural-graph-topics.tsv`.
- **Ledger depth:** `1,000` v1 scorecards, `3,982` scorecard source-family rows, `3,661` per-claim study assessments, `0` scorecard mismatches against live `oracle_check_scorecard`, and `1,000 / 1,000` passing `foodexperiment.researchstatus verify-complete`.

## Directional verdicts

- [0001](statements/0001.txt) **Maybe True** (50.005%) Consuming raw cantaloupe reduces attention impairment in people with Parkinson's disease.
- [0011](statements/0011.txt) **Maybe False** (50.005%) Consuming raw cantaloupe worsens executive function impairment in people with Parkinson's disease.
- [0043](statements/0043.txt) **Maybe True** (50.005%) Consuming toasted caraway reduces pain severity in people with Parkinson's disease.
- [0070](statements/0070.txt) **Maybe True** (50.005%) Consuming raw carrot reduces bradykinesia severity in people with Parkinson's disease.
- [0092](statements/0092.txt) **Maybe False** (50.005%) Consuming roasted cashew worsens anxiety severity in people with Parkinson's disease.
- [0095](statements/0095.txt) **Maybe True** (50.005%) Consuming roasted cashew reduces bradykinesia severity in people with Parkinson's disease.
- [0099](statements/0099.txt) **Maybe False** (50.005%) Consuming roasted cashew worsens depressive symptom severity in people with Parkinson's disease.
- [0102](statements/0102.txt) **Maybe True** (50.005%) Consuming roasted cashew reduces dyskinesia severity in people with Parkinson's disease.
- [0114](statements/0114.txt) **Maybe True** (50.005%) Consuming roasted cashew reduces pain severity in people with Parkinson's disease.
- [0115](statements/0115.txt) **Maybe True** (50.005%) Consuming roasted cashew reduces postural instability severity in people with Parkinson's disease.
- [0157](statements/0157.txt) **Maybe True** (50.005%) Consuming ground cayenne pepper reduces bradykinesia severity in people with Parkinson's disease.
- [0165](statements/0165.txt) **Maybe True** (50.005%) Consuming ground cayenne pepper reduces fatigue severity in people with Parkinson's disease.
- [0168](statements/0168.txt) **Maybe True** (50.005%) Consuming ground cayenne pepper worsens insomnia severity in people with Parkinson's disease.
- [0171](statements/0171.txt) **Maybe False** (50.005%) Consuming ground cayenne pepper worsens olfactory impairment severity in people with Parkinson's disease.
- [0177](statements/0177.txt) **Maybe True** (50.005%) Consuming ground cayenne pepper worsens urinary urgency frequency in people with Parkinson's disease.
- [0190](statements/0190.txt) **Maybe False** (50.005%) Consuming fresh celery leaf worsens postural instability severity in people with Parkinson's disease.
- [0192](statements/0192.txt) **Maybe False** (50.005%) Consuming dried celery leaf worsens rest tremor severity in people with Parkinson's disease.
- [0196](statements/0196.txt) **Maybe False** (50.005%) Consuming dried celery leaf worsens walking slowness in people with Parkinson's disease.
- [0197](statements/0197.txt) **Maybe False** (50.005%) Consuming ground celery seed worsens anxiety severity in people with Parkinson's disease.
- [0200](statements/0200.txt) **Maybe False** (50.005%) Consuming ground celery seed worsens bradykinesia severity in people with Parkinson's disease.
- [0204](statements/0204.txt) **Maybe True** (50.005%) Consuming ground celery seed reduces depressive symptom severity in people with Parkinson's disease.
- [0211](statements/0211.txt) **Maybe True** (50.005%) Consuming ground celery seed reduces fatigue severity in people with Parkinson's disease.
- [0214](statements/0214.txt) **Maybe True** (50.005%) Consuming ground celery seed reduces insomnia severity in people with Parkinson's disease.
- [0217](statements/0217.txt) **Maybe False** (50.005%) Consuming ground celery seed worsens olfactory impairment severity in people with Parkinson's disease.
- [0219](statements/0219.txt) **Maybe True** (50.005%) Consuming ground celery seed reduces pain severity in people with Parkinson's disease.
- [0220](statements/0220.txt) **Maybe True** (50.005%) Consuming ground celery seed reduces postural instability severity in people with Parkinson's disease.
- [0222](statements/0222.txt) **Maybe False** (50.005%) Consuming ground celery seed worsens rest tremor severity in people with Parkinson's disease.
- [0233](statements/0233.txt) **Maybe True** (50.005%) Consuming cooked celery stalk reduces bradykinesia severity in people with Parkinson's disease.
- [0253](statements/0253.txt) **Maybe True** (50.005%) Consuming raw celery stalk reduces postural instability severity in people with Parkinson's disease.
- [0260](statements/0260.txt) **Maybe False** (50.005%) Consuming brewed chamomile worsens anxiety severity in people with Parkinson's disease.
- [0267](statements/0267.txt) **Maybe True** (50.005%) Consuming brewed chamomile reduces depressive symptom severity in people with Parkinson's disease.
- [0277](statements/0277.txt) **Maybe True** (50.005%) Consuming brewed chamomile reduces insomnia severity in people with Parkinson's disease.
- [0282](statements/0282.txt) **Maybe True** (50.005%) Consuming brewed chamomile reduces pain severity in people with Parkinson's disease.
- [0294](statements/0294.txt) **Maybe True** (50.005%) Consuming dried cherry reduces attention impairment in people with Parkinson's disease.
- [0303](statements/0303.txt) **Maybe False** (50.005%) Consuming raw cherry worsens executive function impairment in people with Parkinson's disease.
- [0307](statements/0307.txt) **Maybe False** (50.005%) Consuming dried cherry worsens insomnia severity in people with Parkinson's disease.
- [0312](statements/0312.txt) **Maybe False** (50.005%) Consuming dried cherry worsens pain severity in people with Parkinson's disease.
- [0345](statements/0345.txt) **Maybe False** (50.005%) Consuming soaked chia seed worsens constipation severity in people with Parkinson's disease.
- [0348](statements/0348.txt) **Maybe True** (50.005%) Consuming soaked chia seed reduces depressive symptom severity in people with Parkinson's disease.
- [0363](statements/0363.txt) **Maybe True** (50.005%) Consuming soaked chia seed reduces pain severity in people with Parkinson's disease.
- [0374](statements/0374.txt) **Maybe False** (50.005%) Consuming roasted chicken worsens anxiety severity in people with Parkinson's disease.
- [0379](statements/0379.txt) **Maybe False** (51%) Consuming poached chicken reduces daily off time in people with Parkinson's disease.
- [0381](statements/0381.txt) **Maybe False** (50.005%) Consuming poached chicken worsens depressive symptom severity in people with Parkinson's disease.
- [0386](statements/0386.txt) **Maybe True** (50.005%) Consuming poached chicken reduces executive function impairment in people with Parkinson's disease.
- [0409](statements/0409.txt) **Maybe True** (50.005%) Consuming canned chickpeas reduces constipation severity in people with Parkinson's disease.
- [0458](statements/0458.txt) **Maybe True** (50.005%) Consuming fresh cilantro reduces bradykinesia severity in people with Parkinson's disease.
- [0476](statements/0476.txt) **Maybe False** (50.005%) Consuming fresh cilantro worsens postural instability severity in people with Parkinson's disease.
- [0484](statements/0484.txt) **Maybe True** (50.005%) Consuming ground cinnamon reduces bradykinesia severity in people with Parkinson's disease.
- [0486](statements/0486.txt) **Maybe False** (50.005%) Consuming ground cinnamon worsens depressive symptom severity in people with Parkinson's disease.
- [0492](statements/0492.txt) **Maybe True** (50.005%) Consuming ground cinnamon reduces postural instability severity in people with Parkinson's disease.
- [0500](statements/0500.txt) **Maybe True** (50.005%) Consuming cooked clams reduces bradykinesia severity in people with Parkinson's disease.
- [0502](statements/0502.txt) **Maybe False** (51%) Consuming cooked clams reduces daily off time in people with Parkinson's disease.
- [0511](statements/0511.txt) **Maybe True** (50.005%) Consuming cooked clams reduces fatigue severity in people with Parkinson's disease.
- [0514](statements/0514.txt) **Maybe True** (50.005%) Consuming cooked clams reduces insomnia severity in people with Parkinson's disease.
- [0532](statements/0532.txt) **Maybe True** (50.005%) Consuming ground clove reduces depressive symptom severity in people with Parkinson's disease.
- [0574](statements/0574.txt) **Maybe False** (51%) Consuming baked cod reduces daily off time in people with Parkinson's disease.
- [0599](statements/0599.txt) **Maybe False** (50.005%) Consuming brewed coffee reduces anxiety severity in people with Parkinson's disease.
- [0601](statements/0601.txt) **Maybe True** (51%) Consuming brewed coffee reduces attention impairment in people with Parkinson's disease.
- [0603](statements/0603.txt) **Maybe True** (50.005%) Consuming decaffeinated coffee reduces constipation severity in people with Parkinson's disease.
- [0604](statements/0604.txt) **Maybe False** (50.005%) Consuming brewed coffee worsens daily off time in people with Parkinson's disease.
- [0605](statements/0605.txt) **Maybe False** (51%) Consuming brewed coffee worsens daytime sleepiness severity in people with Parkinson's disease.
- [0609](statements/0609.txt) **Maybe False** (51%) Consuming brewed coffee reduces dyskinesia severity in people with Parkinson's disease.
- [0613](statements/0613.txt) **Maybe True** (50.005%) Consuming brewed coffee reduces freezing of gait frequency in people with Parkinson's disease.
- [0615](statements/0615.txt) **Maybe False** (50.005%) Consuming brewed coffee reduces insomnia severity in people with Parkinson's disease.
- [0617](statements/0617.txt) **Maybe True** (51%) Consuming brewed coffee reduces muscle rigidity severity in people with Parkinson's disease.
- [0628](statements/0628.txt) **Maybe True** (50.005%) Consuming brewed coffee worsens urinary urgency frequency in people with Parkinson's disease.
- [0630](statements/0630.txt) **Maybe False** (50.005%) Consuming brewed coffee worsens walking slowness in people with Parkinson's disease.
- [0664](statements/0664.txt) **Maybe True** (50.005%) Consuming ground coriander seed reduces anxiety severity in people with Parkinson's disease.
- [0667](statements/0667.txt) **Maybe False** (50.005%) Consuming toasted coriander seed worsens bradykinesia severity in people with Parkinson's disease.
- [0671](statements/0671.txt) **Maybe True** (50.005%) Consuming toasted coriander seed reduces depressive symptom severity in people with Parkinson's disease.
- [0681](statements/0681.txt) **Maybe True** (50.005%) Consuming toasted coriander seed reduces insomnia severity in people with Parkinson's disease.
- [0686](statements/0686.txt) **Maybe True** (50.005%) Consuming toasted coriander seed reduces pain severity in people with Parkinson's disease.
- [0687](statements/0687.txt) **Maybe True** (50.005%) Consuming ground coriander seed reduces postural instability severity in people with Parkinson's disease.
- [0717](statements/0717.txt) **Maybe False** (50.005%) Consuming pasteurized cow's milk reduces constipation severity in people with Parkinson's disease.
- [0718](statements/0718.txt) **Maybe True** (51%) Consuming pasteurized cow's milk worsens daily off time in people with Parkinson's disease.
- [0770](statements/0770.txt) **Maybe False** (50.005%) Consuming dried cranberry worsens urinary urgency frequency in people with Parkinson's disease.
- [0794](statements/0794.txt) **Maybe False** (50.005%) Consuming pickled cucumber worsens pain severity in people with Parkinson's disease.
- [0804](statements/0804.txt) **Maybe True** (50.005%) Consuming brewed culinary lavender reduces anxiety severity in people with Parkinson's disease.
- [0811](statements/0811.txt) **Maybe True** (50.005%) Consuming brewed culinary lavender reduces depressive symptom severity in people with Parkinson's disease.
- [0818](statements/0818.txt) **Maybe True** (50.005%) Consuming dried culinary lavender reduces fatigue severity in people with Parkinson's disease.
- [0821](statements/0821.txt) **Maybe True** (50.005%) Consuming dried culinary lavender reduces insomnia severity in people with Parkinson's disease.
- [0826](statements/0826.txt) **Maybe True** (50.005%) Consuming brewed culinary lavender reduces pain severity in people with Parkinson's disease.
- [0883](statements/0883.txt) **Maybe False** (50.005%) Consuming ground cumin worsens pain severity in people with Parkinson's disease.
- [0908](statements/0908.txt) **Maybe False** (50.005%) Consuming cooked curry leaf worsens pain severity in people with Parkinson's disease.
- [0916](statements/0916.txt) **Maybe True** (50.005%) Consuming plain dark chocolate reduces attention impairment in people with Parkinson's disease.
- [0918](statements/0918.txt) **Maybe False** (50.005%) Consuming plain dark chocolate reduces constipation severity in people with Parkinson's disease.
- [0921](statements/0921.txt) **Maybe False** (50.005%) Consuming plain dark chocolate worsens depressive symptom severity in people with Parkinson's disease.
- [0926](statements/0926.txt) **Maybe False** (50.005%) Consuming plain dark chocolate worsens executive function impairment in people with Parkinson's disease.
- [0928](statements/0928.txt) **Maybe True** (50.005%) Consuming plain dark chocolate reduces fatigue severity in people with Parkinson's disease.
- [0944](statements/0944.txt) **Maybe False** (50.005%) Consuming plain dark chocolate worsens walking slowness in people with Parkinson's disease.
- [0948](statements/0948.txt) **Maybe False** (50.005%) Consuming dried date worsens constipation severity in people with Parkinson's disease.
- [0951](statements/0951.txt) **Maybe True** (50.005%) Consuming dried date reduces depressive symptom severity in people with Parkinson's disease.
- [0976](statements/0976.txt) **Maybe True** (50.005%) Consuming toasted dill seed reduces anxiety severity in people with Parkinson's disease.
- [0998](statements/0998.txt) **Maybe False** (50.005%) Consuming ground dill seed worsens pain severity in people with Parkinson's disease.
