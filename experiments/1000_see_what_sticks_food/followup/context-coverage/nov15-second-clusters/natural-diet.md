# Exact source-context audit — 2026-11-15

Both original full reviews were inspected: research/2015-2019/Source-Text/PMC6282143.txt (PMID 30596091, 2018-11-22, DOI 10.1155/2018/4067597), and research/2020-2024/Source-Text/PMC11276798.txt (PMID 39062777, 2024-07-09, DOI 10.3390/ijms25147530). Exact `rg -n '30596091|39062777' followup/claim-local-text-screen.tsv` identifies 26 distinct source–claim pairs, 13 per source; claim-query-screen.tsv has the same pairs. Earlier title screens and historical external first-20 subset are different provenance. All original local-text memberships say citation trail; none below justifies a claim direction.

## Row-specific decisions: 2018 review, PMID 30596091

Source line 76 lists luteolin as occurring in parsley, thyme and olive oil, and describes constituent experiments. It also names troxerutin in coffee and flavonoids in citrus. These are compound–source associations, not exposure to the named food/preparation. In particular, source reference 43 is a retracted mouse study (see below).

| ID | Frozen pair | Source-specific scope and proposed disposition |
|---|---|---|
|0050|fresh parsley / constipation worsens|Luteolin source; no human parsley, constipation, or direction. Citation trail only.|
|0072|extra-virgin olive oil / constipation reduces|Luteolin source; no specified oil grade, constipation or intervention. Citation trail only.|
|0121|brewed coffee / fatigue worsens|Troxerutin source, cited rodent neuroprotection; no brewed coffee or fatigue contrast. Citation trail only.|
|0198|fresh parsley / rigidity reduces|Luteolin source and preclinical models; no parsley/rigidity comparison. Citation trail only.|
|0203|dried parsley / pain worsens|Luteolin source; no dried parsley or pain comparison. Citation trail only.|
|0332|fresh parsley / fatigue worsens|Luteolin source; no fatigue comparison. Citation trail only.|
|0343|cold-pressed olive oil / anxiety reduces|Luteolin source; no pressing or anxiety comparison. Citation trail only.|
|0362|dried thyme / anxiety reduces|Luteolin source; no dried thyme or anxiety comparison. Citation trail only.|
|0611|fresh thyme / dyskinesia reduces|Luteolin source; no fresh thyme or dyskinesia comparison. Citation trail only.|
|0629|cold-pressed olive oil / bradykinesia reduces|Luteolin source; preclinical motor claims concern isolated compounds, no oil or clinical bradykinesia. Citation trail only.|
|0870|dried parsley / dyskinesia worsens|Luteolin source; no dried parsley or dyskinesia comparison. Citation trail only.|
|0878|raw orange / constipation worsens|Orange peel and hesperidin are noted as flavonoid sources; constituent neurotoxin models, no raw whole orange or constipation outcome. Citation trail only.|
|0897|extra-virgin olive oil / insomnia worsens|Luteolin source; no oil grade or insomnia comparison. Citation trail only.|

## Row-specific decisions: 2024 review, PMID 39062777

This review addresses aging and cancer broadly; ingredients, isolated substances and cellular pathways are discussed in separate passages. It is not a clinical dietary Parkinson study.

| ID | Frozen pair | Source-specific scope and proposed disposition |
|---|---|---|
|0066|refined canola oil / fatigue worsens|Table line 596 identifies canola oil as alpha-linolenic acid source, citing NIH general fact sheet [332]; no oil grade, fatigue or PD contrast.|
|0181|dried cherry / fatigue worsens|Line 586 mentions cyanogenic glycosides in wild cherry; no dried cherry exposure or fatigue test.|
|0251|ground turmeric / fall frequency worsens|Curcumin as turmeric constituent and other tissue research; no ground turmeric or falls comparison.|
|0485|dried saffron / fatigue worsens|Safranal from saffron/iris in skin-aging context; no dried saffron or fatigue comparison.|
|0495|roasted kale / fall frequency worsens|Kale listed as a sulforaphane source in an osteoclast pathway, no roasted kale or falls comparison.|
|0604|raw apricot / pain worsens|Line 538 describes bitter apricot extract and amygdalin against pancreatic cancer cells, not raw fruit or pain. See primary reference 540 below.|
|0609|refined soybean oil / fall frequency reduces|Line 596 source of alpha-linolenic acid, no defined refining, consumption trial or fall outcome.|
|0639|cold-pressed flaxseed oil / pain reduces|Line 596 ALA source, no defined pressing or pain comparison.|
|0812|ground turmeric / pain reduces|Curcumin and turmeric extracts in other disease contexts, no ground turmeric and PD pain contrast.|
|0890|cold-pressed canola oil / pain reduces|ALA source, no cold-pressed oil or pain comparison.|
|0948|brewed green tea / fatigue worsens|EGCG/extract in cardiovascular, AD, cancer or skin contexts, not brewed tea and PD fatigue.|
|0984|ground saffron / fall frequency worsens|Safranal constituent in skin context; no ground saffron or falls comparison.|
|1000|steamed broccoli / fall frequency reduces|Broccoli sprouts listed as sulforaphane source in osteoclast context; no steamed broccoli or falls comparison.|

## Primary-trail integrity and scope

2018 review reference 41: Chen et al. 2008-10-19, PMID 18952146, DOI 10.1016/j.neulet.2008.10.046, https://pubmed.ncbi.nlm.nih.gov/18952146/ . Its original abstract describes isolated luteolin in lipopolysaccharide-exposed primary mesencephalic neuron–glia cultures, not human Parkinson disease or consumption of parsley, thyme or oil. No participant-relevant food endpoint follows.

2018 review reference 43: Patil et al. 2014, PMID 25087727, DOI 10.1016/j.neuropharm.2014.07.012, is now RETRACTED. Its original Europe PMC indexed record and publisher notice https://www.sciencedirect.com/science/article/abs/pii/S0028390821004317 identify image manipulation, and say the authors acknowledged serious errors and agreed to retraction. Do not cite the old review's claims about this experiment as credible affirmative primary evidence; the 2018 review predates the retraction.

2024 review reference 540: Aamazadeh et al. 2020-02-05, PMID 32026321, DOI 10.1007/s11033-020-05286-w, https://pubmed.ncbi.nlm.nih.gov/32026321/ . The original abstract evaluates bitter apricot ethanolic extract and amygdalin in PANC-1 pancreatic cancer and normal 293/KDR cells; it is not a Parkinson, pain or raw-fruit ingestion study. The review text calls the extract methanolic, whereas the primary title and abstract call it ethanolic. The exact sample preparation requires the primary methods, not resolution by copying the review; this conflict has no bearing on a raw apricot pain result.

2024 review reference 332 is NIH Office of Dietary Supplements https://ods.od.nih.gov/factsheets/Omega3FattyAcids-Consumer/ , a general fact sheet describing ALA-containing plant oils, not a PD trial. Botanical sources and biochemical or cellular findings do not demonstrate either beneficial or harmful food effects on the named clinical outcomes.

## Receipt and remaining scope

Accessed full archived review bodies and official NLM/Europe PMC records on 2026-11-15. Europe PMC exact PMID searches for 30596091, 39062777, 18952146, 25087727, and 32026321 confirmed identities; core result for 25087727 begins RETRACTED and contains the notice. Additional web queries: `"25087727" luteolin apigenin mice motor oral dose`; `"32026321" bitter apricot ethanolic extract PANC cells`; `"18952146" luteolin microglial activation primary neuron rat`; `"30596091" luteolin olive oil thyme parsley clinical trial Parkinson`; `"25087727" "retracted" image manipulation Patil`. Publisher or full primary methods of the remaining nonretracted originals were not examined; they are unnecessary to conclude that the specific isolated/cell experiments are not tests of the frozen culinary exposures. No systematic all-literature search or clinical verdict is claimed, and no canonical files changed.
