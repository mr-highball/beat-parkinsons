# Parkinson's food thought experiment results

Verdicts are tracked for **1,000** frozen statements. Confidence values are reviewer judgments.

- Frozen SHA-256 `b90e6cdcd54abc4c1522cf4d5d68a42e8d7eb531bf5e8b8df49529082b6648db`
- [Statement verdict ledger](verdicts.tsv)
- [First-pass search ledger](queries.tsv) with 2000 completed records and 1000 statements covered
- [Counts by category and claim direction](results-summary.tsv)

## Verdict counts

| Verdict | Local review | Current verdict |
| --- | ---: | ---: |
| Unknown | 1000 | 886 |
| Maybe True | 0 | 57 |
| Maybe False | 0 | 57 |
| True | 0 | 0 |
| False | 0 | 0 |

## Findings and limits

All 1,000 frozen Round 2 claims (`0001`–`1000`) have been researched using the Oracle-first workflow, Round 1 evidence transfer, 2,000 neutral Europe PMC queries ([queries.tsv](queries.tsv)), live PubMed and ClinicalTrials.gov v2 sweeps, and inclusive cultural/traditional/public forum collection, and every claim carries a validated v1 evidence scorecard ([scorecards.tsv](followup/scorecards.tsv)) and completion audit row ([research-status.tsv](followup/research-status.tsv)).

Round 2 spans 36 unique ingredients (9 pantry-expansion foods appearing across all 33 symptoms plus 27 shared Round 1 exposures covering their non-overlapping reserved symptoms). Raw cross-round percentages are not directly comparable to Round 1 without category and ingredient standardization: Round 2 contains `807` food, `94` spice, `59` oil, and `40` herb claims.

| Verdict / Tier | Count | Notes |
| --- | ---: | --- |
| `Maybe True` | 57 | Directional evidence aligns with frozen hypothesis direction |
| `Maybe False` | 57 | Directional evidence opposes frozen hypothesis direction |
| `Unknown` (`Unknown (Researched)`) | 886 | Exhaustively checked; no defensible net directional lean (`open`, anchor `50`) |
| **Total frozen claims** | **1,000** | `500` frozen `reduces` / `500` frozen `worsens` |

By v1 scorecard tier and direction:
- **`limited_clinical_link` (anchor `51`):** `4` claims (`2` easing leans, `2` worsening leans)
- **`minimal_signal` (anchor `50.005`):** `110` claims (`108` easing leans, `2` worsening leans)
- **`open` (anchor `50`, displayed as `Unknown (Researched)`):** `886` claims
- **Symptom breadth:** `114` directional claims across `20` distinct symptoms and `27` ingredients (`9` ingredients remained `100%` `Unknown (Researched)`: `adzuki beans`, `allspice`, `amaranth`, `avocado oil`, `black beans`, `black-eyed peas`, `bok choy`, `canola oil`, `cantaloupe`).
- **Category breakdown:** `food` (`47` Maybe True, `50` Maybe False, `710` Unknown / `807` total), `spice` (`8` Maybe True, `4` Maybe False, `82` Unknown / `94` total), `herb` (`1` Maybe True, `3` Maybe False, `36` Unknown / `40` total), `oil` (`1` Maybe True, `0` Maybe False, `58` Unknown / `59` total).

### Highlighted checked v1 findings

- **Cooked beef and Parkinson daily OFF time ([0476](statements/0476.txt), Maybe False, 51 — limited clinical link, worsens):** Direct Parkinson clinical protein-redistribution and levodopa-competition studies demonstrate that large neutral amino acids from daytime meat/protein meals impair levodopa transport and worsen motor fluctuations / OFF time (opposing the frozen `reduces` hypothesis), while protein redistribution improves ON/OFF stability.
- **Brewed black tea and Parkinson daytime sleepiness ([0618](statements/0618.txt), Maybe False, 51 — limited clinical link, eases):** Randomized double-blind Parkinson caffeine trials (including Postuma et al. 2012 `PMID:22855866`, `n = 61`, bridged via brewed black tea infusion chromatography) show improved daytime somnolence ratings on caffeine versus placebo, opposing the frozen `worsens` hypothesis while leaving brewed-tea matrix transfer provisional.
- **Brewed black tea and Parkinson muscle rigidity ([0631](statements/0631.txt), Maybe True, 51 — limited clinical link, eases):** Same Parkinson randomized caffeine literature reports modest UPDRS motor/rigidity improvements linked to brewed black tea via chromatography, tempered by longer-term follow-up uncertainty (`Postuma 2017`) and isolated-caffeine exposure indirectness.
- **Brewed black tea and Parkinson dyskinesia ([0622](statements/0622.txt), Maybe False, 51 — limited clinical link, worsens):** Longer-term Parkinson randomized caffeine trial follow-up (`Postuma 2017`) and clinical reports associate chronic higher caffeine intake with increased dyskinesia severity, opposing the frozen `reduces` hypothesis.
- **Brewed black tea worsening leans at minimal signal ([0629](statements/0629.txt) insomnia severity, [0641](statements/0641.txt) urinary urgency frequency, both Maybe False at `50.005`):** Clinical caffeine sleep-disruption and bladder-irritant/urgency trials bridged to brewed black tea oppose frozen `reduces` hypotheses, demonstrating balanced two-sided scoring when evidence leans adverse.
- **Beetroot (`9` minimal-signal easing leans across `0504`–`0536`):** Nitrate-rich beetroot juice trials and rodent motor/mood studies support minimal easing leans across executive function, fatigue, walking slowness, and related domains while strictly preserving null human motor/orthostatic trials and non-PD population limits.
- **Brown rice (`9` minimal-signal easing leans across `0829`–`0858`):** Human randomized trials of cooked brown rice, ultra-high hydrostatic pressurized brown rice (`Matsuzaki 2025` `PMID:40901038`, `Kuroda 2019` `PMID:31619653`), and rice bran/germ extracts (`Huh 2025` `PMID:40409466`, `Um 2019` `PMC6710429`, `Jung 2020` `PMC7606135`) support minimal easing leans across apathy, anxiety, constipation, daytime sleepiness, depression, executive function, fatigue, insomnia, and pain, tempered by preparation and non-PD transfer limits.
- **Buckwheat groats (`8` minimal-signal easing leans across `0890`–`0919`):** Controlled human and PD-model rutin/buckwheat studies support minimal easing leans across anxiety, bradykinesia, constipation (`PMC10815896`), depression, executive function, fatigue, pain (`PMID:28582812`), and postural instability, while preserving null/mixed findings (`White 2026` `NCT07245784`) and diabetic neuropathy case cautions.
- **Broccoli and Brussels sprouts (`6` minimal-signal easing leans each):** Randomized human sulforaphane/broccoli-sprout trials (`Yanaka 2018` `PMID:29371757`, `Ghazizadeh-Hashemi 2021` `PMID:34033171`, `Nouchi 2022` `PMID:35966784`, BRIO `NCT03878368`) and PD mouse models (`Zhou 2016`, `Morroni 2013`, `Xie 2026`) support minimal easing leans across anxiety, bradykinesia, constipation, depression, pain, and postural instability, while preserving GI flatulence context and keeping bundled broccoli-seed tea reports contextual.
- **Additional minimal-signal easing leans (`72` claims at `50.005`):** Spanning `apple` (`7`), `almond` (`6`), `black pepper` (`5`), `blueberry` (`5`, with opposing `Velichkov 2024` preserved), `anise seed` (`4`), `asparagus` (`4`, incl. `Misu 2026` `PMID:42571331` EEG sleep RCT), `banana` (`4`), `barley` (`4`), `annatto` (`3`), `artichoke` (`3`), `basil` (`3`), `blackberry` (`3`, incl. `Zhang 2023` NHANES sleep `PMID:38140374`), `beef` (`1` easing), `butternut squash` (`2`), `button mushroom` (`2`, strictly *Agaricus bisporus* only), `almond oil` (`1`), `apricot` (`1`, flesh separated from cyanogenic bitter kernels), `arugula` (`1`), `bay leaf` (`1`, *Laurus nobilis* only), `bell pepper` (`1`, capsaicin-free sweet *Capsicum annuum* only), and `Brazil nut` (`1`).

### Key exclusions, safety boundaries, and open findings

- **Strict botanical and preparation boundaries:** Excluded toxic cyanogenic bitter apricot kernels (`PMID:25708890`, `PMID:39207944`) from culinary dried apricot flesh; separated sweet bell pepper from pungent capsaicin trials; separated *Phaseolus vulgaris* black beans from *Glycine max* black soybeans and *Vicia faba*; separated *Agaricus bisporus* from lion's mane/cordyceps/pooled mushrooms; separated *Asparagus officinalis* from *A. racemosus*; separated *Laurus nobilis* from *Cinnamomum tamala* and toxic cherry laurel; distinguished food-grade canola oil from 1981 aniline-adulterated Spanish Toxic Oil Syndrome (`PMID:41040954`) and kept canola oil executive function `open` amid conflicting human vs. mouse evidence (`Lauretti & Praticò 2017` vs. `Diekmann 2026`/`Zhang 2021`).
- **Open findings (`886` claims):** All `886` open claims carry `verdict = Unknown` and `research_status = researched` (displaying as `Unknown (Researched)` in Parkinson's Oracle MCP and the Nyx web UI), with explicit unresolved exposure, endpoint, and Parkinson-population gaps recorded per claim in [research-status.tsv](followup/research-status.tsv).

### Search coverage and limits

- **Oracle-first & transfer baseline:** Audited all 36 Round 2 ingredients against catalog revision `280` (`39,299` indexed files) and transferred applicable Round 1 evidence across the 27 shared exposures before external retrieval. First-pass coverage rates are logged in [experiments/oracle-coverage/](../oracle-coverage/README.md).
- **External clinical & scientific retrieval:** Completed `2,000 / 2,000` neutral Europe PMC queries ([queries.tsv](queries.tsv), `0` failed queries), full live PubMed XML and ClinicalTrials.gov v2 sweeps across all 36 ingredients, and archived `624` newly extracted primary source texts under chronological `research/YYYY-YYYY/Source-Text/` buckets.
- **Inclusive cultural & experiential collection:** Archived `66` new traditional-practice, local-knowledge, personal-report, and anonymized public forum conversation records (Reddit `r/Parkinsons`, Parkinson's UK Discourse, Cure Parkinson's HealthUnlocked) under `research/YYYY-YYYY/Cultural-and-Experiential/`, bringing total verified cultural records to `209` (`research.culture` PASS) with full topic mapping in `experiments/tools/parkinsons-oracle/cultural-graph-topics.tsv`.
- **Ledger depth:** `1,000` v1 scorecards, `3,326` scorecard source-family rows, `3,338` per-claim study assessments, `0` scorecard mismatches against live `oracle_check_scorecard`, and `1,000 / 1,000` passing `foodexperiment.researchstatus verify-complete`.

## Directional verdicts

- [0054](statements/0054.txt) **Maybe False** (50.005%) Consuming roasted almond worsens anxiety severity in people with Parkinson's disease.
- [0058](statements/0058.txt) **Maybe False** (50.005%) Consuming raw almond worsens constipation severity in people with Parkinson's disease.
- [0066](statements/0066.txt) **Maybe True** (50.005%) Consuming raw almond reduces executive function impairment in people with Parkinson's disease.
- [0068](statements/0068.txt) **Maybe False** (50.005%) Consuming roasted almond worsens fatigue severity in people with Parkinson's disease.
- [0071](statements/0071.txt) **Maybe False** (50.005%) Consuming roasted almond worsens insomnia severity in people with Parkinson's disease.
- [0076](statements/0076.txt) **Maybe True** (50.005%) Consuming roasted almond reduces pain severity in people with Parkinson's disease.
- [0090](statements/0090.txt) **Maybe True** (50.005%) Consuming cold-pressed almond oil reduces constipation severity in people with Parkinson's disease.
- [0141](statements/0141.txt) **Maybe True** (50.005%) Consuming ground anise seed reduces anxiety severity in people with Parkinson's disease.
- [0143](statements/0143.txt) **Maybe True** (50.005%) Consuming ground anise seed reduces constipation severity in people with Parkinson's disease.
- [0145](statements/0145.txt) **Maybe False** (50.005%) Consuming ground anise seed worsens depressive symptom severity in people with Parkinson's disease.
- [0157](statements/0157.txt) **Maybe True** (50.005%) Consuming ground anise seed reduces shortened stride severity in people with Parkinson's disease.
- [0161](statements/0161.txt) **Maybe True** (50.005%) Consuming ground annatto reduces anxiety severity in people with Parkinson's disease.
- [0168](statements/0168.txt) **Maybe False** (50.005%) Consuming ground annatto worsens depressive symptom severity in people with Parkinson's disease.
- [0183](statements/0183.txt) **Maybe True** (50.005%) Consuming ground annatto reduces pain severity in people with Parkinson's disease.
- [0194](statements/0194.txt) **Maybe False** (50.005%) Consuming baked apple worsens anxiety severity in people with Parkinson's disease.
- [0197](statements/0197.txt) **Maybe False** (50.005%) Consuming baked apple worsens bradykinesia severity in people with Parkinson's disease.
- [0198](statements/0198.txt) **Maybe False** (50.005%) Consuming baked apple worsens constipation severity in people with Parkinson's disease.
- [0201](statements/0201.txt) **Maybe False** (50.005%) Consuming raw apple worsens depressive symptom severity in people with Parkinson's disease.
- [0207](statements/0207.txt) **Maybe False** (50.005%) Consuming raw apple worsens fatigue severity in people with Parkinson's disease.
- [0215](statements/0215.txt) **Maybe False** (50.005%) Consuming raw apple worsens pain severity in people with Parkinson's disease.
- [0216](statements/0216.txt) **Maybe False** (50.005%) Consuming raw apple worsens postural instability severity in people with Parkinson's disease.
- [0229](statements/0229.txt) **Maybe False** (50.005%) Consuming dried apricot worsens constipation severity in people with Parkinson's disease.
- [0256](statements/0256.txt) **Maybe True** (50.005%) Consuming steamed artichoke reduces anxiety severity in people with Parkinson's disease.
- [0260](statements/0260.txt) **Maybe False** (50.005%) Consuming cooked artichoke worsens constipation severity in people with Parkinson's disease.
- [0278](statements/0278.txt) **Maybe False** (50.005%) Consuming steamed artichoke worsens pain severity in people with Parkinson's disease.
- [0308](statements/0308.txt) **Maybe False** (50.005%) Consuming raw arugula worsens pain severity in people with Parkinson's disease.
- [0318](statements/0318.txt) **Maybe True** (50.005%) Consuming steamed asparagus reduces anxiety severity in people with Parkinson's disease.
- [0325](statements/0325.txt) **Maybe False** (50.005%) Consuming roasted asparagus worsens depressive symptom severity in people with Parkinson's disease.
- [0329](statements/0329.txt) **Maybe True** (50.005%) Consuming grilled asparagus reduces executive function impairment in people with Parkinson's disease.
- [0333](statements/0333.txt) **Maybe False** (50.005%) Consuming roasted asparagus worsens insomnia severity in people with Parkinson's disease.
- [0372](statements/0372.txt) **Maybe True** (50.005%) Consuming raw banana reduces constipation severity in people with Parkinson's disease.
- [0381](statements/0381.txt) **Maybe True** (50.005%) Consuming raw banana reduces fatigue severity in people with Parkinson's disease.
- [0384](statements/0384.txt) **Maybe False** (50.005%) Consuming baked banana worsens insomnia severity in people with Parkinson's disease.
- [0389](statements/0389.txt) **Maybe False** (50.005%) Consuming raw banana worsens pain severity in people with Parkinson's disease.
- [0403](statements/0403.txt) **Maybe True** (50.005%) Consuming boiled barley reduces constipation severity in people with Parkinson's disease.
- [0406](statements/0406.txt) **Maybe True** (50.005%) Consuming boiled barley reduces depressive symptom severity in people with Parkinson's disease.
- [0413](statements/0413.txt) **Maybe True** (50.005%) Consuming boiled barley reduces fatigue severity in people with Parkinson's disease.
- [0416](statements/0416.txt) **Maybe True** (50.005%) Consuming cooked barley reduces insomnia severity in people with Parkinson's disease.
- [0431](statements/0431.txt) **Maybe False** (50.005%) Consuming dried basil worsens anxiety severity in people with Parkinson's disease.
- [0434](statements/0434.txt) **Maybe False** (50.005%) Consuming dried basil worsens depressive symptom severity in people with Parkinson's disease.
- [0443](statements/0443.txt) **Maybe True** (50.005%) Consuming fresh basil reduces pain severity in people with Parkinson's disease.
- [0448](statements/0448.txt) **Maybe False** (50.005%) Consuming ground bay leaf worsens anxiety severity in people with Parkinson's disease.
- [0476](statements/0476.txt) **Maybe False** (51%) Consuming cooked beef reduces daily off time in people with Parkinson's disease.
- [0503](statements/0503.txt) **Maybe True** (50.005%) Consuming cooked beef reduces walking slowness in people with Parkinson's disease.
- [0506](statements/0506.txt) **Maybe True** (50.005%) Consuming pickled beetroot reduces attention impairment in people with Parkinson's disease.
- [0507](statements/0507.txt) **Maybe True** (50.005%) Consuming roasted beetroot reduces bradykinesia severity in people with Parkinson's disease.
- [0516](statements/0516.txt) **Maybe False** (50.005%) Consuming boiled beetroot worsens executive function impairment in people with Parkinson's disease.
- [0518](statements/0518.txt) **Maybe False** (50.005%) Consuming boiled beetroot worsens fatigue severity in people with Parkinson's disease.
- [0523](statements/0523.txt) **Maybe False** (50.005%) Consuming pickled beetroot worsens muscle rigidity severity in people with Parkinson's disease.
- [0526](statements/0526.txt) **Maybe True** (50.005%) Consuming roasted beetroot reduces pain severity in people with Parkinson's disease.
- [0529](statements/0529.txt) **Maybe True** (50.005%) Consuming pickled beetroot reduces rest tremor severity in people with Parkinson's disease.
- [0530](statements/0530.txt) **Maybe True** (50.005%) Consuming boiled beetroot reduces shortened stride severity in people with Parkinson's disease.
- [0536](statements/0536.txt) **Maybe True** (50.005%) Consuming pickled beetroot reduces walking slowness in people with Parkinson's disease.
- [0554](statements/0554.txt) **Maybe True** (50.005%) Consuming roasted bell pepper reduces pain severity in people with Parkinson's disease.
- [0592](statements/0592.txt) **Maybe True** (50.005%) Consuming ground black pepper reduces anxiety severity in people with Parkinson's disease.
- [0594](statements/0594.txt) **Maybe False** (50.005%) Consuming cracked black pepper worsens bradykinesia severity in people with Parkinson's disease.
- [0596](statements/0596.txt) **Maybe True** (50.005%) Consuming ground black pepper reduces depressive symptom severity in people with Parkinson's disease.
- [0597](statements/0597.txt) **Maybe True** (50.005%) Consuming ground black pepper reduces dyskinesia severity in people with Parkinson's disease.
- [0605](statements/0605.txt) **Maybe False** (50.005%) Consuming cracked black pepper worsens postural instability severity in people with Parkinson's disease.
- [0613](statements/0613.txt) **Maybe True** (50.005%) Consuming brewed black tea reduces anxiety severity in people with Parkinson's disease.
- [0615](statements/0615.txt) **Maybe False** (50.005%) Consuming brewed black tea worsens attention impairment in people with Parkinson's disease.
- [0616](statements/0616.txt) **Maybe False** (50.005%) Consuming brewed black tea worsens constipation severity in people with Parkinson's disease.
- [0618](statements/0618.txt) **Maybe False** (51%) Consuming brewed black tea worsens daytime sleepiness severity in people with Parkinson's disease.
- [0619](statements/0619.txt) **Maybe True** (50.005%) Consuming brewed black tea reduces depressive symptom severity in people with Parkinson's disease.
- [0622](statements/0622.txt) **Maybe False** (51%) Consuming brewed black tea reduces dyskinesia severity in people with Parkinson's disease.
- [0624](statements/0624.txt) **Maybe True** (50.005%) Consuming brewed black tea reduces executive function impairment in people with Parkinson's disease.
- [0626](statements/0626.txt) **Maybe False** (50.005%) Consuming brewed black tea worsens fatigue severity in people with Parkinson's disease.
- [0627](statements/0627.txt) **Maybe True** (50.005%) Consuming brewed black tea reduces freezing of gait frequency in people with Parkinson's disease.
- [0629](statements/0629.txt) **Maybe False** (50.005%) Consuming brewed black tea reduces insomnia severity in people with Parkinson's disease.
- [0631](statements/0631.txt) **Maybe True** (51%) Consuming brewed black tea reduces muscle rigidity severity in people with Parkinson's disease.
- [0634](statements/0634.txt) **Maybe True** (50.005%) Consuming brewed black tea reduces pain severity in people with Parkinson's disease.
- [0641](statements/0641.txt) **Maybe False** (50.005%) Consuming brewed black tea reduces urinary urgency frequency in people with Parkinson's disease.
- [0676](statements/0676.txt) **Maybe False** (50.005%) Consuming raw blackberry worsens anxiety severity in people with Parkinson's disease.
- [0691](statements/0691.txt) **Maybe False** (50.005%) Consuming raw blackberry worsens insomnia severity in people with Parkinson's disease.
- [0695](statements/0695.txt) **Maybe False** (50.005%) Consuming frozen blackberry worsens postural instability severity in people with Parkinson's disease.
- [0704](statements/0704.txt) **Maybe False** (50.005%) Consuming frozen blueberry worsens anxiety severity in people with Parkinson's disease.
- [0706](statements/0706.txt) **Maybe False** (50.005%) Consuming raw blueberry worsens attention impairment in people with Parkinson's disease.
- [0710](statements/0710.txt) **Maybe True** (50.005%) Consuming frozen blueberry reduces depressive symptom severity in people with Parkinson's disease.
- [0715](statements/0715.txt) **Maybe True** (50.005%) Consuming raw blueberry reduces executive function impairment in people with Parkinson's disease.
- [0724](statements/0724.txt) **Maybe False** (50.005%) Consuming frozen blueberry worsens pain severity in people with Parkinson's disease.
- [0777](statements/0777.txt) **Maybe True** (50.005%) Consuming roasted Brazil nut reduces executive function impairment in people with Parkinson's disease.
- [0798](statements/0798.txt) **Maybe True** (50.005%) Consuming raw broccoli reduces anxiety severity in people with Parkinson's disease.
- [0800](statements/0800.txt) **Maybe True** (50.005%) Consuming raw broccoli reduces bradykinesia severity in people with Parkinson's disease.
- [0801](statements/0801.txt) **Maybe True** (50.005%) Consuming raw broccoli reduces constipation severity in people with Parkinson's disease.
- [0804](statements/0804.txt) **Maybe True** (50.005%) Consuming raw broccoli reduces depressive symptom severity in people with Parkinson's disease.
- [0818](statements/0818.txt) **Maybe False** (50.005%) Consuming raw broccoli worsens pain severity in people with Parkinson's disease.
- [0819](statements/0819.txt) **Maybe True** (50.005%) Consuming roasted broccoli reduces postural instability severity in people with Parkinson's disease.
- [0829](statements/0829.txt) **Maybe True** (50.005%) Consuming steamed brown rice reduces anxiety severity in people with Parkinson's disease.
- [0830](statements/0830.txt) **Maybe True** (50.005%) Consuming cooked brown rice reduces apathy severity in people with Parkinson's disease.
- [0833](statements/0833.txt) **Maybe False** (50.005%) Consuming cooked brown rice worsens constipation severity in people with Parkinson's disease.
- [0835](statements/0835.txt) **Maybe True** (50.005%) Consuming steamed brown rice reduces daytime sleepiness severity in people with Parkinson's disease.
- [0836](statements/0836.txt) **Maybe True** (50.005%) Consuming cooked brown rice reduces depressive symptom severity in people with Parkinson's disease.
- [0840](statements/0840.txt) **Maybe True** (50.005%) Consuming steamed brown rice reduces executive function impairment in people with Parkinson's disease.
- [0842](statements/0842.txt) **Maybe True** (50.005%) Consuming cooked brown rice reduces fatigue severity in people with Parkinson's disease.
- [0845](statements/0845.txt) **Maybe False** (50.005%) Consuming cooked brown rice worsens insomnia severity in people with Parkinson's disease.
- [0849](statements/0849.txt) **Maybe False** (50.005%) Consuming steamed brown rice worsens pain severity in people with Parkinson's disease.
- [0859](statements/0859.txt) **Maybe True** (50.005%) Consuming steamed brussels sprouts reduces anxiety severity in people with Parkinson's disease.
- [0862](statements/0862.txt) **Maybe True** (50.005%) Consuming steamed brussels sprouts reduces bradykinesia severity in people with Parkinson's disease.
- [0863](statements/0863.txt) **Maybe False** (50.005%) Consuming steamed brussels sprouts worsens constipation severity in people with Parkinson's disease.
- [0866](statements/0866.txt) **Maybe True** (50.005%) Consuming steamed brussels sprouts reduces depressive symptom severity in people with Parkinson's disease.
- [0879](statements/0879.txt) **Maybe False** (50.005%) Consuming roasted brussels sprouts worsens pain severity in people with Parkinson's disease.
- [0880](statements/0880.txt) **Maybe False** (50.005%) Consuming steamed brussels sprouts worsens postural instability severity in people with Parkinson's disease.
- [0890](statements/0890.txt) **Maybe True** (50.005%) Consuming toasted buckwheat groats reduces anxiety severity in people with Parkinson's disease.
- [0892](statements/0892.txt) **Maybe False** (50.005%) Consuming toasted buckwheat groats worsens bradykinesia severity in people with Parkinson's disease.
- [0893](statements/0893.txt) **Maybe False** (50.005%) Consuming cooked buckwheat groats worsens constipation severity in people with Parkinson's disease.
- [0896](statements/0896.txt) **Maybe False** (50.005%) Consuming cooked buckwheat groats worsens depressive symptom severity in people with Parkinson's disease.
- [0900](statements/0900.txt) **Maybe True** (50.005%) Consuming toasted buckwheat groats reduces executive function impairment in people with Parkinson's disease.
- [0902](statements/0902.txt) **Maybe True** (50.005%) Consuming toasted buckwheat groats reduces fatigue severity in people with Parkinson's disease.
- [0910](statements/0910.txt) **Maybe False** (50.005%) Consuming toasted buckwheat groats worsens pain severity in people with Parkinson's disease.
- [0911](statements/0911.txt) **Maybe True** (50.005%) Consuming cooked buckwheat groats reduces postural instability severity in people with Parkinson's disease.
- [0927](statements/0927.txt) **Maybe False** (50.005%) Consuming baked butternut squash worsens depressive symptom severity in people with Parkinson's disease.
- [0934](statements/0934.txt) **Maybe False** (50.005%) Consuming baked butternut squash worsens fatigue severity in people with Parkinson's disease.
- [0968](statements/0968.txt) **Maybe False** (50.005%) Consuming cooked button mushroom worsens insomnia severity in people with Parkinson's disease.
- [0973](statements/0973.txt) **Maybe True** (50.005%) Consuming roasted button mushroom reduces postural instability severity in people with Parkinson's disease.
