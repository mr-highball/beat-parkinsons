# IUNS food and herb presentation audit

The original publisher body for `PMCID:PMC13439031`, DOI `10.1017/jns.2026.10126`, is the 2025 IUNS-ICN Paris abstract collection first published online on 23 July 2026. It is the publisher's combined Proceedings, rather than a single intervention. The Cambridge PDF and layout extraction used for this review are under `build/potato-body-access-followup/`. The archive pipeline state remains `no_archived_text_join` for these exact pairs. The PDF independently provides the local original body.

- [Publisher record](https://www.cambridge.org/core/journals/journal-of-nutritional-science/article/special-collection-abstracts-from-iunsicn-paris-2025/C51F3C05B11BD8180F05A3C37B4292A0)
- [Publisher PDF](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/C51F3C05B11BD8180F05A3C37B4292A0/S2048679026101268a.pdf/special-collection-abstracts-from-iuns-icn-paris-2025.pdf)
- PDF SHA256 `252F82878DFC300CD7B6ED761B3058AB7E3B7BAA7BA981A9CA9ED788D387A93F`
- Layout text SHA256 `631E387E9ED075043D4F5AC0D31B2B3E78E851007236BAC086B761F446E35572`

The exact denominator was 81 remaining food and herb memberships at the 59,199-open-pair snapshot. The native scanner separated 2,366 numbered SOAP, OAP and EPO presentations from three navigation spans. It routed 254 numbered presentations containing at least one direct ingredient or existing related exposure term, plus four further sections with explicit Parkinson wording. `iuns-presentation-flags.tsv` retains each claim's routed presentation codes and starting layout lines. `iuns-pair-totals.tsv` retains all 81 source memberships. The reasons below identify exposures and methods within original presentation boundaries. References and names in one abstract do not supply the exposure or endpoint for other abstracts.

The published exact review table contains 77 contextual exclusions and two low-fit related results for this collection. Two exact pairs stay open. No preparation-specific Parkinson symptom estimate was identified. The oat crossover and mixed fruit constipation trial provide one new low-fit assessment candidate each, keyed to their individual reports.

## Remaining two exact pairs

- **0226 and 0362 thyme.** `SOAP20_4:L43511` on printed page 224 identifies “African thyme” as one of several types of aromatic seasoning in a field, literature and composition study. The original PDF gives no taxonomic name for this ingredient. Its nearby binomial relates to African basil. The cited 2021 laboratory article analyzes fruit and bulb of identified non-thyme species and a separate spice bark. It cannot identify the unnamed thyme sample. Fresh/dried preparation and the exact plant identity remain unresolved. The next documentary route is the plant list or voucher from the cited field work or the author's underlying survey. The presented generic health claims do not establish Parkinson olfaction or anxiety outcomes. [Cited 2021 article](https://pmc.ncbi.nlm.nih.gov/articles/PMC7884570/).

## Contextual reasons

### Apricot and grape

- **apricot 0604.** SOAP08_01 tests dried prunes, raisins and apricots together and a fruit-juice mixture in 150 adults with Rome IV functional constipation. The PAC-SYM includes abdominal pain. Only aggregate findings were recovered, with no isolated raw apricot contrast. EPO7_105 separately records apricot kernels in a breast cancer complementary-medicine survey. [Dated original source context](../../../../../research/2025-2029/Food-Experiment-Mixed-Fruit-Constipation.md).
- **grape.** SOAP08_01 compares a mixed dried fruit intervention containing raisins and a multi-fruit juice intervention containing grape juice in functional constipation. EPO3_043 studies pigment retention in grape peel extract. Those preparations and endpoints do not evaluate raw or frozen grape for anxiety or daytime sleepiness.

### Bitter vegetables

- **arugula.** EPO1_016 surveys 879 Australian adults about willingness to increase consumption of bitter foods, with rocket among the example vegetables. Its taste and acceptance responses do not measure falls, fatigue or impaired olfaction.
- **brussels sprouts.** EPO1_016 includes Brussels sprouts among example bitter foods in a consumer acceptance survey. Its responses concern taste and willingness to eat, rather than clinical olfaction after eating roasted Brussels sprouts.
- **eggplant.** EPO1_016 includes eggplant among example bitter foods in a consumer acceptance survey. The outcomes concern taste acceptance and willingness to consume, rather than olfactory impairment after eating baked eggplant.

### Asparagus and banana

- **asparagus.** EPO5_376 estimates how labeling affects consumers’ willingness to pay for fresh white asparagus. Its consumer-choice outcome does not test swallowing difficulty with steamed asparagus or fatigue with roasted asparagus.
- **banana.** EPO2_022 records organic banana use in institutional procurement and EPO5_233 documents banana in preschool lunchboxes. EPO2_025 uses food flavor or sensory acceptance in insect-product formulations. These contexts do not test anxiety after eating raw banana.

### Barley and oats

- **barley.** EPO1_012 measures postprandial glucose effects of oat and barley beta-glucan and EPO3_038 studies composition after malting and germination. Neither tests anxiety after eating boiled barley.
- **oats 0095.** EPO6_170 compares oat-based fermented and nonfermented foods in mild metabolic deterioration, with cardiometabolic outcomes and an aggregate psychological-distress score. EPO1_012 measures postprandial glucose with beta-glucan. These outcomes do not test fall frequency after eating rolled oats.
- **oats 0174.** EPO6_170 uses the GHQ-12 in the same crossover reported in PMID:42574785. The standard questionnaire contains a worry-related sleep-loss item, with no item-specific result recovered. Both interventions use oat flour, oat bran and faba protein. Record related context with no direction for insomnia following rolled-oat consumption in Parkinson disease. [Dated original and supplemental results](../../../../../research/2025-2029/Food-Experiment-Fermented-Oat-Crossover.md).

### Herbs

- **basil.** SOAP38_11 tests food recipes on cultured cells and includes basil in a tomato sauce. EPO3_010 formulates children’s foods using Ocimum gratissimum, and EPO8_199 tests basil essential oil against vaginal pathogens. These preparations and outcomes do not address effects of eating fresh or dried basil on the seven specified Parkinson symptoms.
- **lemon balm.** EPO8_149 uses natural deep eutectic solvents to extract and profile phenolics in Melissa officinalis. Other Melissa hits are personal names. The extraction assay does not measure depressive symptoms after drinking brewed lemon balm.
- **rosemary.** OAP43_06 and SOAP08_15 analyze additive exposures, including rosemary extract E392, against cancer and type 2 diabetes outcomes. Other rosemary hits include author names. These presentations do not test ground or fresh rosemary for walking slowness, depression or constipation.
- **sage.** OAP3_02 uses the WHO Study on Global AGEing and Adult Health (SAGE). EPO3_047 studies compounds in flour and EPO8_149 refers to Salvia officinalis in the citation context of a lemon balm extraction assay. These uses do not test eating sage for pain, insomnia, olfaction, falls or fatigue.

### Teas and coffee

- **black tea.** SOAP32_14 examines kidney disease incidence and mortality using a flavonoid-rich dietary score that includes black tea. EPO7_051 studies green tea with citrus polyphenols in mice fed an obesogenic diet. These outcomes do not estimate Parkinson walking slowness after brewed black tea.
- **coffee.** OAP39_05 estimates coffee and tea associations with dysmenorrhea. EPO6_022 examines beverage intake and reflux, EPO7_146 addresses metabolic syndrome, and EPO1_001 analyzes caffeine by anxiety, insomnia and eating-disorder status. Their beverage or nutrient outcomes do not measure Parkinson fatigue after brewed coffee.
- **green tea.** EPO6_022 examines beverage intake and incident reflux. EPO7_051 studies an obesity setting with tea and citrus polyphenols and OAP2_01 tests a fortified tea in rat cardiotoxicity. These outcomes do not measure Parkinson olfaction or fatigue after brewed green tea.

### Berry and cherry

- **blueberry.** OAP36_07 reports preliminary wild-blueberry intervention findings in metabolic syndrome. OAP52_09 studies a flavonoid-rich diet and biological aging, and EPO6_147 measures intra-articular inflammation and recovery with blueberry supplementation around knee replacement. These outcomes do not address constipation after eating raw blueberry.
- **cherry.** OAP45_05 reviews sleep latency, efficiency, duration, awakenings and quality in general adults and refers to Jerte Valley cherry products. SOAP51_02 uses simulated in vitro digestion. The sleep outcomes and products do not estimate fatigue after eating dried cherry.

### Broccoli

- **broccoli.** EPO8_061 lists broccoli among dietary sources in its introduction, then applies isolated quercetin to peroxide-challenged PC12 cells. Parkinson disease appears as broader motivation. Experimental sulforaphane and food-preparation blocks address other endpoints. No matched presentation evaluates falls after eating steamed broccoli.

### Carrot cauliflower and cabbage

- **carrot.** EPO3_081 assays lacto-fermented carrots and cabbage for antioxidant properties. EPO3_065 studies a food lipid-carrier formulation and SOAP26_09 follows nutritional restoration in restrictive anorexia nervosa. These settings and outcomes do not estimate executive function, constipation, daytime sleepiness or clinical olfaction from the frozen carrot preparations.
- **cauliflower.** EPO3_009 tests acidic ethanol purple-cauliflower extracts in antioxidant and oxidative-injury assays. SOAP13_15 examines stability of food-derived microRNA. These settings do not test anxiety after eating roasted cauliflower.
- **red cabbage.** EPO3_081 examines lacto-fermented carrots and purple cabbage for antioxidant activity and EPO8_049 measures nutrient and antioxidant characteristics. These analytical outcomes do not test depression after eating cooked red cabbage.

### Meat and egg

- **chicken.** OAP29_03 uses chicken in a comparative pig ileal amino-acid digestibility study and EPO5_067 examines diet and hip fracture. Food-production presentations concern composition or procurement. These contexts do not evaluate fatigue after eating poached chicken.
- **egg.** EPO8_072 studies cognitive task performance with egg consumption in healthy older adults and adjusts for sleepiness. EPO4_018 examines maternal egg intake and child outcomes, while OAP2_08 tests early complementary feeding. These outcomes do not measure Parkinson falls or walking slowness after poached egg.
- **turkey.** OAP22_01, SOAP51_03 and EPO3_049 refer to Turkey as a study or participant country. OAP8_05 uses Turkey in a citation and EPO3_102 uses it as a product origin in food-safety surveillance. These are geographic uses with no baked-turkey olfaction experiment.

### Fish and shrimp

- **cod.** OAP8_01 compares vitamin D content of UV-treated black soldier fly larvae with cod liver oil, and EPO2_087 maps cod imports and micronutrient supply. These contexts do not test grilled cod for fatigue or baked cod for olfactory impairment.
- **salmon.** OAP45_05 covers sleep studies that include Atlantic salmon in general adults. SOAP19_14 studies farmed salmon feed and EPO2_087 maps seafood supply. These contexts do not estimate anxiety after eating poached salmon.
- **sardines.** EPO5_600 reports microbiome and cytokine outcomes in the iFISH food intervention with tuna and sardines in women with low habitual fish consumption. EPO6_103 studies lipid metabolism in a sprat-feeding experiment. These settings do not address baked-sardine anxiety or canned-sardine fatigue.
- **shrimp.** SOAP34_08 measures cultural salience of indigenous foods, including stream shrimp. EPO3_021 studies tropomyosin immunoreactivity after processing shrimp and other invertebrates. These outcomes do not test falls or constipation after eating boiled shrimp.
- **trout.** EPO3_019 cites enzyme-inhibitory peptides from rainbow trout viscera hydrolysate. The actual assays use milkfish frame hydrolysates and measure DPP-IV inhibition and antioxidant activity. These contexts do not test grilled trout for daytime sleepiness or poached trout for depression.

### Dark chocolate

- **dark chocolate.** EPO2_182 compares cricket chitin with maltodextrin delivered in cacao patties in both periods among adults with irritable bowel syndrome. The contrast is the added material and the reported outcomes concern gastrointestinal tolerability. SOAP32_14 assesses kidney disease and mortality using a flavonoid-rich dietary score. Neither estimates anxiety from plain dark chocolate.

### Pulses grains and millet

- **edamame.** EPO1_106 studies dietary salt reduction and urinary salt measures, with edamame mentioned in the dietary context. EPO3_094 analyzes color, flavor components and antioxidant activity of grilled and boiled edamame. Their biochemical and sensory outcomes do not measure olfactory impairment after eating steamed edamame.
- **lentils.** EPO2_139 measures preferences and consumption of pulses, EPO2_140 models nutrition and environmental life-cycle impacts, and EPO3_003 develops muffins from grain and pulse flours. These settings do not evaluate insomnia, walking slowness, anxiety, daytime sleepiness or olfaction with boiled or canned lentils.
- **millet.** EPO3_067 uses pearl millet in school porridge to measure composition and sensory acceptability and OAP40_08 compares nutrient profiles across finger millet. These outcomes do not test pain after eating boiled millet.
- **quinoa.** EPO3_052 examines bread with germinated buckwheat flour and references quinoa-related work. EPO3_123 surveys street foods, and SOAP51_01 scales production of quinoa peptides for a metabolic application. These outcomes do not test walking slowness after eating boiled quinoa.

### Leafy vegetables and zucchini

- **kale.** EPO2_127 records kale and chard yields, sales, and household self-consumption in a backyard-production initiative. Those outcomes do not measure falls or clinical olfaction after roasted kale.
- **swiss chard.** EPO2_127 records chard production, sale, and household self-consumption in a backyard-agriculture initiative. Its outcomes describe crop yields and household economics rather than olfaction after eating steamed Swiss chard.
- **zucchini.** EPO2_094 uses zucchini in a local-food environmental and nutrition model. Its modeled outcomes do not measure executive function after eating grilled zucchini.

### Mango and orange

- **mango.** OAP48_05 studies intravenous iron for pica in pregnancy and uses unripe mango as a reported pica context. EPO4_004 analyzes nutrient composition and iron bioaccessibility, and EPO5_391 tests acceptability of supplement prototypes. Those outcomes do not measure insomnia, fatigue or depression from eating raw or dried mango.
- **orange.** SOAP06_13 cites a polyphenol-rich orange juice trial in a depression/anxiety review. OAP57_04 contains a company name and several food blocks use orange to describe the flesh color of another ingredient. These contexts do not address falls or constipation after eating raw orange.

### Potato and sweet potato

- **potato 0290.** OAP11_01 compares cooking methods and fats for baked and fried potatoes using estimated glycemic index. OAP63_03 evaluates body weight change across broader preparation groups. These presentations measure carbohydrate digestion or weight, rather than clinical swallowing with baked potato.
- **potato 0915.** OAP63_03 groups roasted potatoes with fried preparations and measures five-year weight change. OAP11_01 measures estimated glycemic index across cooking methods and fats. Neither evaluates insomnia with roasted potato, and the weight cohort does not isolate roasted potato.
- **sweet potato.** EPO3_018 studies infant complementary-diet planning, EPO5_111 measures food composition and sensory characteristics, and EPO5_561 interviews program planners about vitamin A supplementation. These settings do not test fatigue after eating boiled sweet potato.

### Shiitake

- **shiitake mushroom.** OAP28_08 irradiates mushrooms with UVB and evaluates acetylcholinesterase activity in vitro. This laboratory endpoint does not test swallowing difficulty after eating roasted shiitake.

### Tomato

- **tomato.** EPO8_032 reports food-development results for UV-treated vitamin D biofortified tomato soup and plans a healthy-volunteer plasma-vitamin-D study. EPO3_131 tests tomato phenolics in starch digestion and SOAP38_11 uses recipe preparations in cell assays. These outcomes do not address executive function from eating cooked tomato.

## Primary presentation and access checks

The PDF page images under `raw/` visually confirm the presentation labels and nearby methods and outcomes for `SOAP20_4` (printed page 224), `SOAP08_01` (665), `EPO6_170` (1305) and `EPO8_061` (1595). In `SOAP20_4`, the printed line confirms the separation between the African basil binomial and the vernacular thyme description. `EPO8_061` confirms broccoli in the introduction and isolated quercetin in the cell method. The latter is the one routed food/herb presentation with explicit Parkinson wording. The previously reviewed strawberry leaf presentation is already catalogued. The brown-alga presentation `EPO8_081` has consistent methods and results with the already indexed 2024 original, PMID:38999824, and the exposure lies outside this freeze. The EPIC4ND preprint on dietary niacin and tryptophan is catalogued as a separate cohort alongside the Norwegian proposal. [Brown-alga original](https://pmc.ncbi.nlm.nih.gov/articles/PMC11243082/) · [EPIC4ND preprint](https://assets-eu.researchsquare.com/files/rs-9436550/v1/58b32f43-8920-4867-b8e1-692aa0f3beb9.pdf).

Some PDF blocks use American and British spellings, common names or genus information. The scope is the source-linked 81 memberships at the frozen queue snapshot and their routed textual contexts with manual follow-up. Lexical counts and routing state indicate where to read. An uncued synonym, incomplete study report or independently authored full paper can change an exact disposition. The two ambiguous thyme rows remain eligible for follow-up.

## Reproducing the native validation

From the experiment root, the stage scripts are under `build/iuns-food-herb-final-audit/src`. FPC 3.3.1 on i386-win32 compiled the binaries. The prior collection-specific tool serves as the basis for the presentation segmentation. The isolated queue binary adds path overrides solely for the assessment and strict-exact input files and preserves their original receipt identities. `base-assessments.tsv` is the previously published 2,570-row table (SHA256 `FABDB6599D488A709133A71AE49C25B9811CC46FCF4081BAB4E642E3033E84AA`). `base-exact-reviews.tsv` holds the published strict table (SHA256 `E09C4602FBE63A89B07C9484F99B147D5EE3C5CCB81270200A94A8F14CFC105F`). Pinning them prevents unrelated concurrent changes from shifting either dispositions or receipt line locators. `control/` holds the original published exact inventory and queue. `control-replay/` and `variant/` contain the isolated reproductions. The variant adds the staged strict table only.

```powershell
$stage = 'build/iuns-food-herb-final-audit'
$overlay = 'build/claim-search-complete-date-overlay/ingredient_results.tsv'
foreach ($tool in 'screen-iuns-food-herb','stage-approved-iuns-reviews','contextqueue-exact-snapshot','verify-iuns-review-import') {
    fpc -B -Pi386 -Twin32 '-Fu./tools' "-FU$stage/bin" "-FE$stage/bin" "$stage/src/$tool.lpr"
}
& "$stage/bin/screen-iuns-food-herb.exe" iuns-text 'build/potato-body-access-followup/PMC13439031-cambridge.txt' PMCID:PMC13439031 "$stage/control/context-queue.tsv" . "$stage/iuns"
& "$stage/bin/stage-approved-iuns-reviews.exe" $stage
& "$stage/bin/contextqueue-exact-snapshot.exe" . $overlay "$stage/control-replay" "$stage/control-inputs.tsv" "$stage/base-exact-reviews.tsv" "$stage/base-assessments.tsv"
& "$stage/bin/contextqueue-exact-snapshot.exe" . $overlay "$stage/variant" "$stage/variant-inputs.tsv" "$stage/base-exact-reviews.tsv" "$stage/base-assessments.tsv"
& "$stage/bin/verify-iuns-review-import.exe" $stage
```

The native verifier checks every key and every changed row against the strict staged table, including review state, expected role and archive status preservation. The original exact inventory contains 61,252 memberships. The control queue has 59,199 open pairs. Applying the 79 staged rows alone yields 59,120 open pairs. The collection retains 0226 and 0362 pending exact thyme identification.

## Primary follow-through

The university repository supplied the full CC BY oat journal text and the original publisher supplement. The GHQ-12 aggregate improved within the gurt period, while the direct product comparison was inconclusive. No sleep-item estimate is published. The mixed fruit trial measured PAC-SYM without a separate abdominal pain result. Both trials are counted once across their registries and reports. [Oat original and supplement](../../../../../research/2025-2029/Food-Experiment-Fermented-Oat-Crossover.md) · [Mixed fruit original and registry](../../../../../research/2025-2029/Food-Experiment-Mixed-Fruit-Constipation.md)

The original cited Djiazet case study of Cameroonian spices lists 24 fruit, root or bark samples without identifying the abstract plant. Its other cited original studies describe four samples of three other species. A botanical authority uses African thyme for Coleus amboinicus, but no study-specific voucher or preparation connects that name to SOAP20_4. The 2021 author thesis remains an unverified primary access route. [Cameroon field study](https://doi.org/10.1186/s42779-019-0030-6) · [Original chemical study](https://pmc.ncbi.nlm.nih.gov/articles/PMC7884570/) · [Botanical authority](https://pza.sanbi.org/coleus-amboinicus) · [Exact reviews](../exact-reviews.tsv) · [Native verification](verify.log)
