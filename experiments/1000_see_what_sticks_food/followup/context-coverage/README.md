# Exact claim–source coverage for the original Europe PMC searches

The full per-pair and source-grouped queues regenerate under the experiment's ignored `build/context-coverage/output/` directory. Keep the curated exact ledger, per-claim counters, provenance and replay summary in Git; do not copy the full generated queues into this source folder.

The original searches produced 69,107 result appearances across 2,000 expressions. There are 61,252 distinct frozen claim and provider-key pairs across 34,099 source keys. Results map to 679 claims. The other 321 have zero returns in this original search layer and can still have follow-up searches, other providers or evidence assessments. The inventory leaves the original provider keys intact and reports ambiguous identifier aliases separately. [Original lexical screen](../claim-query-screen.tsv) · [All 1,000 claim denominators](coverage-by-claim.tsv) · [Ambiguous identifiers](ambiguous-source-aliases.tsv)

| Strongest recorded exact review | Pairs |
| --- | ---: |
| Local body or other primary-source context | 13,919 |
| Exact assessment with basis unspecified | 129 |
| Abstract context | 217 |
| Title or index | 186 |
| Pending or access-only disposition | 202 |
| No imported exact review | 46,599 |
| **Total** | **61,252** |

The native replay keeps 46,987 pairs queued across 29,781 sources. That includes 186 title or index reviews, 202 pending pairs and 46,599 pairs with no imported exact decision. The sunflower-oil review resolves 45 original pairs across thirteen full sources and six frozen claims. [Source and coverage review](../sunflower-executive-nov19-48/README.md). The original 2018 obesity congress HTML resolves 38 claim-source pairs after member and index verification. [Obesity congress review](../eco-obesity-originals-nov19-47/README.md). The 2011 SGIM and 2004 EASD bodies resolve 55 original pairs across 44 claims. [Completed member review](../sgim-easd-originals-nov19-46/README.md). Three 2018–2019 proceedings resolve 85 body-level pairs across 64 claims. [Proceedings review](../shared-proceedings-nov19-45/README.md). The 1985 Hamburg proceedings resolved 36 earlier pairs after embedded-text and page-column comparison. Fourteen original pairs for 0413 remain open. [Hamburg source and OCR coverage](../hamburg-neurology-ocr-nov19-44/README.md) · [Strawberry source routes](../strawberry-falls-berry-trials-nov19-42/remaining-evidence.tsv). The access packets preserve cases where the indexed PMCID identifies a different publication, including the Köles review and the iron-deficiency case letter. The priority-three journal bodies still open are linked in the original-source packets. The three reviewed PRIME protocol pairs have a separate study-result trail. There are 8,685 pairs joined to an archived text path and 16,343 with neither an indexed abstract nor an archived path in this join. The queue records archived body boundaries, indexed access and official PMC eligibility independently. [Replay counts](replay-summary.txt) · [Fig and turkey PDF scope](../tremor-fig-nov19-30/README.md) · [Resumed archive and turkey review](../tremor-turkey-nov19-31/README.md) · [Recent priority-three rechecks](../oracle-cumin-meals-and-originals-nov17/priority-three-access.tsv) · [Pending PRIME outcomes](../protocols-and-source-bodies-nov17/prime-result-followup.md) · [PMC eligibility receipts](../../../../research/PMC-Text-Retrieval.tsv)


Checkpoint 12 records 17 contextual decisions at verified body or abstract depth and preserves the remaining full-body routes. The full searches, focused result membership and genuine exposure assessments are linked from the checkpoint. [Checkpoint 12](../lemon-balm-depression-nov18-12/README.md)

Checkpoint 13 authenticates the STACCATO abstract and author-name collision, and tracks the remaining body and registry routes. [Checkpoint 13](../lemon-balm-depression-nov18-13/README.md)

Checkpoint 14 resolves four additional original collections at full-text depth. Five inspected sources retain scan, font-encoding or supplement-access gaps. [Original collection review](../lemon-balm-depression-nov18-14/README.md)

Checkpoint 15 recovers the 279-page physiology proceedings and clears four original source pairs at body depth. The ARO title listing stays queued. The three new related assessments preserve preparation and endpoint fit. [Source recovery and comparator ledger](../lemon-balm-depression-nov18-15/README.md)

Checkpoint 16 authenticates six sources and advances 53 original pairs across 34 claims, including nine related exposure contexts. [Review depth and surviving access gaps](../lemon-balm-depression-nov18-16/README.md)

Checkpoint 17 excludes 20 lexical mismatches at original-body depth across five conference collections. Seven originals retain member, scan or figure-access gaps. Two related Prunus comparisons remain outside the original result overlay. [Evidence scope and open routes](../lemon-balm-depression-nov18-17/README.md)

Checkpoint 18 resolves 82 exact pairs at original-body depth across six conference collections. Eleven preserve actual flavor or odor inputs without converting them into graded food effects. The clinical article, two index sources and five PDF collections retain explicit access or depth gaps. [Original source and study-family review](../lemon-balm-depression-nov18-18/README.md)

Checkpoint 19 resolves 155 body-level pairs and one abstract-level pair. Two official PDFs restored complete collection text. The other three collections retain access gaps. The trial registration links two postoperative tea outcomes outside the original search overlay. [Source depths, related evidence and access routes](../lemon-balm-depression-nov18-19/README.md)

Checkpoint 20 verifies twelve original bodies, including two complete archived proceedings PDFs. Ninety-two pairs reach body depth. Four other originals stay queued with explicit publication routes. [Original boundaries, related trials and remaining gaps](../lemon-balm-depression-nov18-20/README.md)

Checkpoint 21 resolves five exact pairs through the complete SGIM abstracts and two original review reprints. The UEG posters retain separate individual member findings and an open whole-collection mapping. [Original boundaries and result follow-through](../lemon-balm-depression-nov19-21/README.md)

The November 19 saffron follow-through rechecked all 13 priority-three pairs. Its linked trials contribute separate related assessments. The original source queue retains documented access gaps. [Priority originals and trial boundaries](../saffron-registrations-and-outcomes-nov19/README.md)

The tremor item checkpoint advances 16 baked-turkey original pairs, nine body-level and seven author-abstract exclusions. The 0392 original queue has 33 remaining pairs. [Original contexts and access holds](../tremor-item-followthrough-nov19-28/README.md)

The next mustard and turkey checkpoint advances 17 more original turkey pairs. Seven use original bodies and ten use author abstracts. Sixteen baked-turkey pairs remain in the native queue. [Scope and source receipts](../tremor-mustard-nov19-29/README.md)

## Intake for exact source reviews

Compile [the Free Pascal intake](../../tools/foodexperiment.contextintake.lpr) using the experiment tools unit path and output directories under `build/`. From the repository root, pass the current native context queue, canonical exact-review ledger, six-column proposal TSV, repository-relative packet directory and a distinct staged-ledger output path, in that order. Use the header in [exact-reviews.tsv](exact-reviews.tsv). The proposal locator must be a public source URL or an existing local research path. The reviewer records the verified depth.

The program rejects duplicate and out-of-queue pairs or a downgrade before writing. Both `title` and `title_and_index` input bases emit canonical `title_and_index`; the original proposal file stays unchanged. Index-only records remain queued. Queued related or excluded title records may advance to verified abstract or full-text depth, while settled deeper records cannot be overwritten through intake. Existing pending rows that reach greater depth replace their canonical entry. Unchanged pending depth preserves the old ledger row and the new receipt remains available in the packet. Verify the staged rows and rerun the native context replay after publishing the canonical ledger. [Native title-depth fixtures](../../tools/foodexperiment.contextintake.tests.lpr)

## Contextual reviews

The eleventh lemon balm checkpoint records five exclusions at verified depths. One reaches the original body and four authenticate the author abstract. Six original-body access holds for 0133 and a separate freezing pair remain explicit. Two new indirect clinical assessments retain the acute outcome and preparation limits. [Source decisions, registered product comparisons and open trails](../lemon-balm-depression-nov18-11/README.md)

The ninth lemon balm checkpoint verifies 68 more original pairs, retains 12 source holds, and corrects 13 settled source roles without changing their review depth or the original queue keys. Genuine ingredients and derived preparations remain visible despite endpoint gaps. [Source-role audit, walnut pain and clinical limits](../lemon-balm-depression-nov17-09/README.md)

The eighth lemon balm checkpoint verifies 152 original pairs, including 11 for 0133 and 141 independently reviewed shared-source pairs. One assigned ACTS collection remains held. Primary formula reconciliation separates Carmint from GJS, and the STW5 originals preserve distinct gastrointestinal, biochemical and psychiatric endpoints. [Source identity and original outcomes](../lemon-balm-depression-nov17-08/README.md)

The seventh lemon balm checkpoint verifies 131 original pairs, including 15 for 0133 and 116 independently reviewed shared-source pairs, with nine assigned access or collection-completeness holds. The recovered GHQ depression table has a favorable post-treatment contrast and unreconciled statistics. Shared registry and aggregate trajectories constrain the PMS reports to one overlapping family. [Original tables and source coverage](../lemon-balm-depression-nov17-07/README.md)

The sixth lemon balm checkpoint verifies 57 original pairs and retains 11 assigned access gaps. Seven reviews address 0133 and 50 address independently checked shared-source pairs. The Lemcog primary calmness comparison and the recovered UMIN protocol remain distinct from a brewed Parkinson depression outcome. [Originals and clinical follow-through](../lemon-balm-depression-nov17-06/README.md)

The fifth lemon balm checkpoint verifies 108 original claim–source pairs and retains five source access gaps. Thirteen original reviews address brewed lemon balm and depression. Ninety-five address separately reviewed food and symptom pairs using the same originals. The confirmed Fatali trial reports anxiety while its registered depression contrast remains open. [Original and related source reviews](../lemon-balm-depression-nov17-05/README.md)

The fourth lemon balm checkpoint verifies 87 original claim–source pairs and preserves four assigned access holds. The shared-book checks cover 73 additional pairs after independently reviewing each food and endpoint. Five official Iranian registry identities clarify the prior evidence and access limits. [Original reviews and registry follow-through](../lemon-balm-depression-nov17-04/README.md)

The third lemon balm checkpoint verifies 89 claim–source pairs and retains 23 original access holds. Ingredient and endpoint review reused six authenticated conference books for 77 exact pairs beyond the priority claim. The original registry and study audit documents two newly identified brewed depression protocols. [Scope and source evidence](../lemon-balm-depression-nov17-03/README.md)

The second lemon balm checkpoint verifies 53 additional exact dispositions. The packet distinguishes complete standalone conference abstracts from journal main bodies and retains eight access holds. The supplemental PubMed searches preserve all 28 returned memberships and author-abstract or verified original depth. [Exact and complementary source review](../lemon-balm-depression-nov17-02/README.md)

The resumed lemon balm checkpoint verifies 49 individual main-text dispositions across six claims. The additional literature and registry screens preserve ingredient, analyzable symptom and study-family boundaries. Four original scope holds remain. [Coverage and evidence](../lemon-balm-depression-nov17/README.md)

The fifteenth tremor checkpoint verifies 109 additional original main bodies and preserves 19 assigned apple holds. The original MENASA result trail remains open. [Original document checks](../tremor-priority-nov17-15/README.md)

The fourteenth tremor checkpoint verifies 503 original main bodies and completes the 968-key fixed local fig archive. Twelve access holds stay open. A separate human exposure review identifies reused celery-leaf plasma results and records the food-form limitations. [Exact scope and celery findings](../tremor-priority-nov17-14/README.md)

The thirteenth tremor checkpoint authenticated 394 original pairs. The archived fig tranche includes a separate 120-key main-text verification that replaced provisional passage-only receipts. Fourteen exact scope holds remain. [Original scope, review depth and access](../tremor-priority-nov17-13/README.md)

The twelfth tremor checkpoint authenticated 111 individual main texts across seven ingredients, with eight assigned holds. The complementary searches verified query and rank membership independently of the original overlay. [Exact reviews and source accounting](../tremor-priority-nov17-12/README.md)

The eleventh tremor checkpoint authenticated 71 full originals across four frozen claims. Its 70 access gaps distinguish proceedings with incomplete member coverage from individual paper access. All surviving queue rows replayed unchanged. [Source decisions and access holds](../tremor-priority-nov17-11/README.md)

The tenth tremor checkpoint authenticated 50 more archived fig papers and the author-posted Apple Watch study. All 51 exact pairs left the queue. The clinical and food-source checks added related context and followed distinct symptom definitions. [Original decisions and endpoint checks](../tremor-priority-nov17-10/README.md)

The ninth tremor checkpoint authenticated 50 archived fig and 29 apple originals. The assigned Science smartwatch paper was held at replay because both publisher routes returned 403. The other queue rows replayed unchanged. [Source decisions and first route](../tremor-priority-nov17-09/README.md)

The eighth tremor checkpoint authenticated 40 archived fig texts and 15 externally retrieved originals. Ten assigned fig scan gaps remain open. All surviving queue rows replayed unchanged. [Original boundaries and harmane follow-through](../tremor-priority-nov17-08/README.md)

The seventh tremor checkpoint reaches full-body depth on 41 fig, 25 turkey and 12 tea pairs. The 14 assigned fig scan gaps remain in the queue. All surviving queue rows replayed unchanged. [Exact original reviews and source trails](../tremor-priority-nov17-07/README.md)

Official archival and version routes supplied complete bodies for four previously open rest-tremor pairs. The rosemary index hold remains separate. [Archive and version recovery](../tremor-priority-nov17-06/README.md)

The fifth rest-tremor checkpoint closes 37 pairs at verified collection or original-body depth. It covers 24 raw-fig rows, 11 baked-turkey rows and two original olive-oil holds. All surviving queue rows replayed unchanged. [Dutch results and source boundaries](../tremor-priority-nov17-05/README.md)

The fourth rest-tremor checkpoint closes 49 pairs at original-body depth. The new black-tea primary-source assessment moves one additional pair to exact assessment with basis unspecified. All remaining queue rows replayed unchanged. [Methods coverage, original-source checks and access holds](../tremor-priority-nov17-04/README.md)

The third rest-tremor checkpoint verifies 28 raw-fig false matches by original passage and follows all returned PubMed records and alias retries across the 26 claims. [PubMed coverage and original evidence](../tremor-priority-nov17-03/README.md)

The second rest-tremor checkpoint closed 23 original pairs across fig, turkey and apple. The U.S. registry screen covers all 26 frozen rest-tremor claims by exposure and deepens the four earlier access and outcome checks. [Exact reviews and clinical registry results](../tremor-priority-nov17-02/README.md)

The first rest-tremor checkpoint closed 44 original pairs. Twenty-four raw fig sources had no matched intake and a balanced second batch sampled ten other claims. Three body gaps and one protocol result remain open. [Tremor review and audit](../tremor-priority-nov17-01/README.md)

Fifty original articles supplied 53 exact reviews. Eleven bodies were recovered through alternate routes, while nine assigned original access gaps remain. The dried-sage follow-through reconciles two trials, their registry identities and reported outcome limits. [Evidence and open access](../oracle-dried-sage-insomnia-and-originals-nov17/README.md)

Forty-six authenticated main texts supplied 46 decisions and 19 assigned pairs remain open. The sage safety follow-through records indexed and original depth for every returned appearance, including ambiguous botanical names and unassigned pain endpoints. [Source review and open access](../oracle-sage-pain-safety-and-originals-nov17/README.md)

Fifty-six authenticated original main texts supplied 65 exact decisions. Alternate official PMC and publisher routes recovered nine previously held papers. The rolled-oat follow-through separates compound, mixture and cohort findings from the exact clinical claim. [Reviewed scope and open clinical routes](../oracle-oats-insomnia-and-originals-nov17/README.md)

Sixty-six authenticated main texts supplied 76 pair-level decisions. Publisher, institutional and NLM archival routes recovered six previously inaccessible papers. The fresh-shiso follow-through checked original patent tables and specific registry-to-protocol ingredient conflicts. [Source scope and outcomes](../oracle-shiso-constipation-and-originals-nov17/README.md)

Seventy-one original main texts supplied 84 exact decisions. The boxing methods and discussion were accessible, while two pairs remain pending at the complete-results depth. The clinical follow-through distinguished 24-hour and clinic pressure from standing lightheadedness. [Original review and search scope](../oracle-red-cabbage-orthostasis-and-originals-nov17/README.md)

Sixty-six original papers supplied 73 exact decisions. The official PMC reader recovered two bodies represented by front matter in the downloaded XML and closed three of those pairs. The celery case and trial follow-through distinguishes general adverse events from measured visual hallucination frequency. [Exact scope and clinical evidence](../oracle-celery-hallucinations-and-originals-nov17/README.md)

Forty original papers supplied 42 exact decisions. The oregano anxiety follow-through distinguished clinical anxiety scales from composite scores, oxidative biomarkers, and experimental behavior. [Exact scope and clinical follow-through](../oracle-oregano-anxiety-and-originals-nov17/README.md)

Thirty original main bodies supplied 41 exact decisions. The sunflower-oil follow-through reconciled 64 literature appearances and 28 registry entries and refined the comparator and endpoint boundaries for Parkinson depressive symptoms. [Original scope and clinical outcomes](../oracle-sunflower-and-originals-nov17/README.md)

Twenty originals supplied 40 body-level decisions. The cumin follow-through verified original patent examples, distinguished duplicate reports of a mixed-tablet trial, and traced the non-food comparator in the constipation review. [Exact scope and outcomes](../oracle-cumin-meals-and-originals-nov17/README.md)

Twenty-two originals supplied 58 main-body decisions. The tea follow-through records which studies used scent, beverage tasting, or isolated supplementation. The separate potato review keeps the meal ingredients and diary outcomes open. [Original scope and outcome checks](../oracle-tea-smell-and-originals-nov17/README.md)

Thirty more original main bodies supplied 60 exact dispositions. The banana follow-through screened 12 literature appearances and five registry records and verified the earlier levodopa case citation. All three banana verdicts stayed the same. [Original reviews and follow-through](../oracle-banana-and-originals-nov17/README.md)

Thirty originals supplied 60 main-body decisions. The brown-rice follow-through reconciled 27 focused literature appearances and eight registered studies and distinguished seated post-meal pressure from symptoms on standing. [Verified scope and clinical evidence](../oracle-brown-rice-and-originals-nov17/README.md)

Twenty-eight original papers supplied 56 full-text decisions. The pea cognition companion review screened all 64 results from the recorded U.S. registry expression, including a pea-protein comparator the earlier screen missed. [Original bodies and clinical follow-through](../oracle-pea-paprika-and-originals-nov17/README.md)

Seventeen original main bodies supplied 34 exact decisions. Another five source identities retain 47 queued pairs pending complete authenticated bodies. [Scope, dispositions and access](../oracle-2019-originals-nov17/README.md)

Twenty-seven original bodies supplied 46 exact decisions. The clinical comparisons preserve the difference between outcomes stated in a paper's conclusion and outcomes the study measured. [Walnut, peanut and original-source review](../oracle-nut-outcomes-and-originals-nov17/README.md)

Seventeen original bodies supplied 34 exact decisions. Newly retrieved originals include the AHA report and EASE LID 3. Access records preserve the unresolved Sellitto, Horgan, Beach and author-Sage identities. [Sage and priority-four archive follow-through](../oracle-sage-pain-and-priority-four-nov17/README.md)

Twenty-two archived bodies supplied 47 exact decisions. The green-tea follow-through reconciled all five focused appearances and linked two dated registrations to their original capsule trials. [Matcha and original-source reviews](../oracle-matcha-and-originals-nov17/README.md)

Twenty-four original bodies supplied 72 exact decisions. The focused follow-through reconciled seven appearances and cataloged three dated trial registrations. [Ginger bowel and clinical source reviews](../oracle-ginger-bowel-and-clinical-nov17/README.md)

Eighteen archived originals supplied 54 exact full-text decisions. A recovered 2018 original trial separately gives constipation-domain results for ginger capsules in IBS. [Original scope, dispositions and study outcomes](../oracle-ginger-constipation-and-context-nov17/README.md)

The 2022 Italian Neurology proceedings supplied 33 original member-level decisions, including the Moli-sani coffee cohort subsequently published with incidence estimates. The separate 2025 ESOC and 2014 FEBS collections remain open. [Original scope, dispositions and study linkage](../oracle-henderson-and-sin-nov17/README.md)

The 2018 stroke, EASD, Biophysics and ECO original collections and a veterinary chapter supplied 131 exact body or complete member decisions. The distinct 2025 stroke supplement still has 35 pairs open. [Original outcomes and scope](../oracle-stroke-and-exposure-nov17/README.md)

Three conference collections and three sources for the virgin-coconut claim supplied 106 exact decisions at original member or body depth. The stroke supplement yielded three verified members and retains all 31 pairs for claim-specific review. [Exact scope and replay](../oracle-conference-members-nov17/README.md)

Sixteen archived sources supplied 48 exact original-body dispositions. Clinical papers distinguish medication, disease, symptom and preparation context. The CIIS 2023 proceedings were read at individual presentation boundaries. [Exact scope and replay](../oracle-outcome-boundaries-nov17/README.md)

The food and oil preparation follow-through reviewed 69 exact pairs across 21 sources. Sixty-eight reached primary or local-body context and left the original queue. The MENASA black-tea and rest-tremor pair remains pending after review of the original questionnaire. [Exact scope and verification](../oracle-food-oils-context-nov17/README.md)

Three conference collections and twelve journal articles supplied 63 full-text decisions. The replay preserved all outstanding priority-three bodies and other queue memberships. [Exact scope and validation](../oracle-clinical-design-next-nov17/README.md)

Four conference volumes and nine other articles supplied 74 full-text decisions. The complete official bodies resolved ten pairs whose local copies contained front matter. The native replay preserved every other queued pair. [Exact scope and verification](../oracle-neurobehavior-context-nov17/README.md)

The 2017 headache proceedings and 2022 GSA abstract book, together with five archived clinical articles, supplied 99 full-text decisions. The replay preserved all remaining pair dispositions. [Exact scope and verification](../oracle-review-clusters-nov17/README.md)

Eight archived clinical sources supplied 16 exact full-text decisions. Thirteen priority-three pairs remain open after checking ten source identities, including a newly identified preprint access route. [Source dispositions and remaining bodies](../oracle-clinical-context-nov17/README.md)

The full SGIM 2016 proceedings supplied 40 exact body-level decisions. The 44 FEBS Journal supplement pairs were checked at access-only depth and remain queued. [Collection scope and verification](../pepper-screen-and-sgim-nov17/README.md#original-collections)

Full text for 2 source keys supplied 84 exact decisions. The SGIM 2014 and Global Advances 2018 collections were reviewed at individual presentation boundaries. The 2021 FEBS Open Bio poster collection still has 43 access-only pairs. [Source access and scope](../unmatched-clinical-leads-nov17/collection-access.md)

Full text for 3 source keys supplied 144 exact decisions. The ESHG 2022, SGIM 2024 and FEBS 2025 source bodies were used at individual presentation boundaries. [Source access and scope](../complementary-sources-nov17/collection-access.md)

Full text for 4 source keys supplied 123 exact decisions. The complete GSA 2021 and SGIM 2020 proceedings resolved 88 of these, including all 45 GSA access cases. Thirteen priority-three pairs remain queued. [Source bodies and screening](../protocols-and-source-bodies-nov17/proceedings-access.md)

Full text for 8 source keys supplied 119 exact decisions. The last three IUPHAR pairs were reviewed and cleared from that collection queue. The 45 GSA 2021 access gaps were still open at that checkpoint. [Exact scope and remaining members](../oregano-and-original-bodies-nov17/README.md#original-search-collections-and-source-bodies)

Full text for 5 source keys supplied 101 exact decisions. Three IUPHAR pairs were still queued at that checkpoint. The 45 GSA 2021 access gaps were still open at that checkpoint. [Exact scope and remaining members](../collection-followthrough-nov17/README.md#original-search-collections)

Full text for 4 sources supplied 132 exact decisions. Forty-three IUPHAR pairs were still queued at that checkpoint. [Exact scope and remaining members](../mixed-diet-and-collections-nov17/README.md#original-search-collections)

Full text for 5 sources supplied 109 exact decisions. The supplemental and mixed-diet evidence limits remain documented alongside the original dispositions. [Exact scope and access](../provider-followthrough-nov17/README.md#shared-sources-and-open-work)

Full text for 5 sources supplied 101 exact decisions, including the last potato pair for 0020. The iron-deficiency letter and aluminum review retain 55 access gaps. [Exact scope and access](../independent-tables-and-shared-nov17/README.md#shared-original-sources-and-access)

7 authenticated sources supplied 197 full-text decisions. The Köles review remains open for its 29 pairs while authentic full-text access is unresolved. [Exact scope and access](../walnut-pepper-and-shared-evidence-nov16/README.md#shared-original-sources)

Six authenticated review bodies provided 170 exact decisions. The clinical citation check distinguished constituent and nutrient lists, different oils, and published outcome boundaries. An older editorial remains open for all 30 pairs. [Scope and open access](../chervil-and-shared-originals-nov16/README.md#original-source-dispositions)

A complete veterinary reference chapter supplied 53 body-level exclusions. The clinical disease match is a cardiac eponym. The separate 56 poster pairs remain open with a preliminary scope receipt. [Original identity and boundaries](../shared-collections-nov16/README.md)

The newest review made 78 exact full-text dispositions across two shared review articles and three clinical papers. The olfaction consensus supplied an original mixed-odor trail, and the other sources clarified ingredient, procedure and outcome boundaries. [Scope and source evidence](../shared-bodies-and-rosemary-nov16/README.md#original-source-screening)

One retrieved natural-compounds review supplied all 47 original full-text dispositions. Its ingredient-source and isolated-constituent links retain secondary context. The 41 associated access checks for two other source keys confirmed mismatched conference assignments, and those pairs remain open. [Exact scope and access receipts](../ginger-constipation-and-source-context-nov16/README.md#shared-original-source)

The pepper pain and clinical-context review added 20 original full-text decisions and kept four historical pairs open at the available depth. Two scan or archival-PDF sources supplied novel clinical context for tremor and drooling without a relevant food comparison. [Exact scope and original sources](../pepper-body-and-original-clinical-nov16/dispositions.tsv)

The ingredient formulation and clinical-context review added 25 original full-text decisions. The apple task and mixed-meal and mixed-extract studies establish exposure context without matching the frozen comparison. Cranberry and caffeine access gaps are recorded separately. [Exact scope and original sources](../cafe-pd-cranberry-and-originals-nov16/dispositions.tsv)

The coffee and clinical-context review added 30 original full-text decisions. Coffee as a cash crop, Parkinson as a botanical author name, composite symptoms and unrelated food uses required original-source checks. Listed item-level supplements remain open where documented. [Exact scope and original sources](../coffee-and-original-clinical-context-nov16/dispositions.tsv)

The rosemary and clinical-context review added 25 original full-text decisions. The two previously staged hallucinosis originals were imported. New Parkinson case histories record coffee and fatigue context alongside diagnostic limits. [Exact scope and original sources](../rosemary-preparations-and-original-context-nov16/dispositions.tsv)

The original clinical outcomes checkpoint reconciled 35 priority-four pairs at full-text depth. It includes original clinical papers on hallucination onset, rest tremor and apathy, along with exclusions for ingredient or endpoint collisions. [Exact decisions and scope](../date-models-and-original-outcomes-nov16/dispositions.tsv)

The date, fig and corn-oil checkpoint reconciled four original full-text decisions and retained one pending publisher route. The completed originals comprise the two LIFE protocol pairs and the two corn-oil lexical matches from the SMT C1100 safety trial. [Exact source results and access](../date-fig-and-corn-oil-nov16/dispositions.tsv)

Four original proceedings pairs reached full collection context, preserving three access or encoding gaps. [Abstract boundaries and exact reviews](../potato-oregano-celery-evidence-nov16/README.md)

Sixty-six pairs reached full primary context across 33 source groups. Two additional pairs remain open for the Beach clinical table. Queue priorities now include 13 at priority three and 3,914 at priority four. [Exact reviews and remaining source routes](../ranked-symptom-outcomes-nov16/README.md)

Thirty-eight of 40 reserved pairs across 20 records reached original body depth. Two open review pairs retain the prior title/index depth in the canonical replay and have a separate author-abstract receipt. Queue priorities include 13 at priority three and 3,980 at priority four. [Ranked clinical review and body access](../ranked-clinical-outcomes-nov16/README.md)

Twenty-two previously abstract-stage pairs reached original-body depth across eleven publications. The two Beach pairs remain open. The queue holds 13 priority-three and 4,018 priority-four pairs. [Exact upgrades and open author body](../ranked-original-depth-nov16/README.md)

Sixteen pairs reached full primary context across eight original source groups. The queue holds 13 priority-three and 4,040 priority-four pairs. [Original cases and exact decisions](../ranked-context-case-boundaries-nov16/README.md)

Fifty-six source pairs reached full primary context across twenty groups. Five older originals supplied the final fifteen source decisions. That replay held 13 priority-three and 4,056 priority-four pairs. [Recovered reports and exact scope](../ranked-recovered-originals-nov16/README.md)

The ranked source pass reached full original bodies for all 60 selected pairs. That replay held 13 priority-three and 4,112 priority-four pairs. [Ranked scope and original access](../ranked-thyme-berry-integration-nov16/README.md)

The ranked source pass reached full original bodies for all 60 selected pairs. That replay held 13 priority-three and 4,172 priority-four pairs. [Ranked scope and original access](../ranked-vegetable-berry-integration-nov16/README.md)

The ranked source pass reached full original bodies for all 60 selected pairs. That replay held 13 priority-three and 4,232 priority-four pairs. [Ranked scope and original access](../openalex-fruit-context-recheck-nov16/README.md)

The ranked source pass reached full original bodies for all 60 selected pairs. That replay held 13 priority-three and 4,292 priority-four pairs. [Ranked scope and original access](../fruit-context-and-ranked-sources-nov16/README.md)

The recovered original surgery report completed three pending full-text reviews. That replay held 13 priority-three and 4,352 priority-four pairs. [Exact context and access](../stn-and-recovered-clinical-context-nov16/README.md)

Seven previously pending pairs now have verified full-page readings from two original journal papers. That replay held 13 priority-three and 4,355 priority-four pairs. [Page order and exact dispositions](../cranberry-openalex-and-scans-nov16/README.md)

The cranberry and ginger checkpoint checked 80 exact pairs and reached primary-source depth for 68. That replay held 13 priority-three and 4,362 priority-four pairs. [Exact reviews and coverage](../cranberry-ginger-source-review-nov16/README.md)

The corn oil and clinical packet checked 40 original pairs at full text. Twelve of those reached body depth through three recovered originals. That replay held 13 priority-three and 4,413 priority-four pairs. [Exact scope and originals](../corn-oil-clinical-nov16/README.md)

The clinical packet checked 189 original pairs, including 182 at full text. It recovered a previously pending Alzheimer article for five pairs and verified shelf access for both orthopedic cases. Seven priority-three pairs remain pending in this scope. That replay held 13 priority-three and 4,453 priority-four pairs. [Exact scope and originals](../lemongrass-oils-nov16/README.md)

The orange and MEDI-PD packet checked 55 original pairs, of which 48 reached full text. It resolves both former orange access gaps. Seven abstract contexts were still open at this checkpoint. Two of those retain a stronger prior title review in the overlay. A separate new assessment linked a Parkinson prescription study to its original source row. That replay held 13 priority-three and 4,635 priority-four pairs. [Exact source records](../orange-medi-pd-nov16/README.md)

The black bean and cinnamon packet checked 60 original pairs. Fifty-seven reached full text. Three remain pending, including the ginger review whose abstract leaves the primary paper identity unresolved. That replay held 13 priority-three and 4,683 priority-four pairs. [Exact and focused review](../olfaction-sleepiness-nov16/README.md)

The community packet adds 25 full original dispositions across five source keys. The exact replay verified that every other overlay decision was preserved. That replay held 13 priority-three and 4,740 priority-four pairs. [Community originals and assessments](../claim-audit-integration-nov16/README.md)

The carrier and rehabilitation packet added 42 original bodies across 14 source keys and 40 claims. Thirty checked matches to a single inaccessible case letter remain queued. The full queue holds 13 priority-three and 4,765 priority-four pairs. [Carrier original routes](../priority-four-carriers-nov16/README.md)

The clinical packet completed 51 original bodies across 11 source groups and 25 claims. It added 51 exact rows and left no residual pairs in its checked scope. The full queue holds 13 priority-three and 4,807 priority-four pairs. [Clinical original routes](../priority-four-clinical-nov16/README.md)

The priority-three follow-through and first priority-four clusters checked 108 pairs. Fifty-six reached body depth and 52 remain pending in these packets. That replay held 13 priority-three and 4,858 priority-four pairs. [Priority-three follow-through](../priority-three-tail-nov16/README.md) · [First priority-four clusters](../priority-four-source-clusters-nov16/README.md)

The ginger, green tea, barley and clove checkpoint completed 48 body-level reviews from 50 original pairs. All 12 focused Europe PMC expressions reconciled 16 appearances, including two expressions completed on retry. The priority-three queue now contains 30 pairs. [Current scope and source trails](../priority-ginger-green-barley-clove-nov16/README.md)

The orange, sage, tea, oils and spearmint review finished all 80 priority-three source pairs. The native queue now contains 78 priority-three pairs. All ten focused Europe PMC searches completed, with 36 appearances reviewed. [Source review and open evidence trails](../priority-orange-sage-nov16/README.md)

The saffron, cranberry, ginger and turmeric checkpoint added 61 priority-three body decisions. All ten focused expressions completed, with 32 appearances reconciled. The native priority-three queue now contains 158 pairs. [Original access and focused search](../priority-cranberry-ginger-nov16/README.md)

The motor, thyme and oil checkpoint added 17 priority-three full-body decisions and closed the original protocol read on three priority-one PRIME pairs. The Wood review awaits full-body access. All 12 focused Europe PMC expressions completed, with 14 appearances reconciled. The priority-three queue now contains 219 pairs. [Pinned scope and dispositions](../priority-motor-thyme-nov16/README.md)

The fruit, oil and spearmint checkpoint completed all 46 priority-three body decisions, including 13 related and 33 excluded records. The native priority-three queue has 236 remaining pairs. [Pinned scope and dispositions](../priority-fruit-oils-nov16/README.md)

The saffron, coffee and cardamom review reconciled 74 priority-three pairs with 69 full-body decisions. Three distinct saffron review papers account for five body-access gaps. The global priority-three queue holds 282 pairs. [Pinned scope and dispositions](../priority-saffron-coffee-nov16/README.md)

This review completed 46 original body decisions and retained one rosemary source at abstract depth. Ten dated research records and nine assessments were added. The weak lean against worsening for dark chocolate and anxiety, claim 0100, increased from 51 to 52 after reviewing two additional clinical contrasts outside Parkinson disease. The original search queue holds 55,302 pairs. [Claim and source review](../priority-black-tea-herbs-nov16/README.md)

The priority-three review resolved 49 original pairs, covering brewed green tea and smell, dried sage and insomnia, and extra-virgin olive oil and constipation. Ten study assessments were added. Claim 0060 moved to Maybe False at 51 because a registered oral sage trial supplied a weak favorable sleep-quality comparison, with substantial limits for Parkinson insomnia. [Original sources and judgments](../priority-green-sage-nov16/README.md)

The next checkpoint completed 65 veterinary-chapter pairs and 22 priority-three olive-oil pairs. It added seven study assessments and rechecked three Unknown judgments. The original search queue now holds 55,397 exact pairs across 32,768 sources. [Source evidence and remaining trails](../veterinary-context-nov16/README.md)

The first broader source audit added 156 full-body exact decisions from the 2024 and 2025 GSA books, a veterinary herbal chapter and a dairy-cattle reporting guide. The checked source ID collision and conference boundaries are recorded. Sixty-five veterinary-chapter pairs carried into the next checkpoint. [Source clusters and remaining scope](../post-first-review-nov16/README.md)

The twenty-ninth scope closes 50 of 52 current exact pairs. The 1908 BMJ scan and 2007 conference issue remain open. Six earlier source pairs were closed from three recovered collection bodies. [Full-text coverage and source identity](../masked-twenty-ninth-nov16/original-source-notes.md)

The twenty-eighth scope added 70 original body or collection decisions and one original abstract decision. Twenty-five exact pairs remain access-only in this checkpoint, and the author-abstract decision retains an open body route. The recovered Hunter article resolves the 1950 paprika index trail. [Original sources and remaining access](../masked-twenty-eighth-nov16/README.md#original-sources-and-claim-reviews)

The twenty-seventh scope closed 37 original body, collection or index pairs. The annual index directed review to the original 1950 paprika article. [Exact scope and recovered scans](../masked-twenty-seventh-nov16/README.md#original-source-decisions-and-claim-reviews)

Five additional bodies from the twenty-sixth scope were recovered. The replay added four previously access-only cases and upgraded one abstract decision. [Recovery and original locators](../masked-twenty-seventh-nov16/prior-body-recovery.md)

The twenty-sixth scope contains 43 exact claim and source pairs. It adds 37 body or collection decisions and two author-abstract decisions. Four pairs remain access-only, and the two abstract decisions still have open body routes. [Exact scope and open access](../masked-twenty-sixth-nov16/README.md#provider-and-original-source-coverage)

The twenty-fifth scope added 77 full body or original-collection decisions across 89 claim and source pairs. Twelve exact sources remain access-only. [Exact scope and open access](../masked-twenty-fifth-nov16/README.md#provider-and-original-source-coverage)

The twenty-fourth scope added 104 body or original-collection decisions and nine author-abstract decisions across 129 exact pairs. Sixteen exact pairs remain access-only, and 25 original-body routes remain open. [Exact scope and remaining access](../masked-twenty-fourth-nov16/README.md#provider-and-original-source-coverage)

The twenty-third scope added 56 body or original-collection reviews and one author-abstract decision across 59 exact pairs. Two exact pairs remain pending, and a separate abstract-reviewed record still needs its original body. [Exact scope and remaining access](../masked-twenty-third-nov16/README.md#provider-and-original-source-coverage)

The twenty-second scope added 134 original body decisions and one original abstract review across 140 exact pairs. Five pairs remain access-only and six original-body routes remain open. [Exact scope and access](../masked-twenty-second-nov16/README.md#provider-and-original-source-coverage)

The twenty-first scope added 54 original-body or presentation decisions and six abstract-level reviews. Twelve exact pairs remain open, with 18 original-body routes including the reviewed abstracts. [Exact scope and remaining access](../masked-twenty-first-nov16/README.md#provider-and-exact-source-coverage)

The twentieth scope added 80 original body or presentation decisions and six author-abstract reviews. Eleven exact pairs remain unresolved, and 17 source routes remain open for original bodies. The original replay includes all 61,252 claim-source keys. [Exact scope and access](../masked-twentieth-nov16/README.md#provider-and-exact-source-coverage)

The nineteenth scope added 61 original body or presentation decisions and one author-abstract review across 72 exact keys. It retains ten exact gaps and 11 body routes. Prior verified collection bodies and original page scans clarified false lexical matches. [Exact scope and reviewed access](../masked-nineteenth-nov16/README.md#provider-and-source-coverage)

The eighteenth scope added 40 body reviews, two individual original presentation contexts and seven author abstracts across 83 exact pairs. Thirty-four exact reviews and 41 body routes remain open. [Exact source coverage](../masked-eighteenth-nov16/README.md#search-and-original-sources)

The seventeenth scope imported 106 exact body decisions and four author abstracts. It retains 84 exact pairs and 88 outstanding full-body routes. The prior Null lifestyle disposition was corrected at the same verified source depth. [Current original-source coverage](../masked-seventeenth-nov16/README.md#provider-and-original-source-coverage)

The sixteenth group added 71 exact body reviews and three author-abstract reviews. It retains 37 exact pairs in the queue and 40 full-body access gaps including the three abstract-reviewed sources. [Current exact review](../masked-sixteenth-nov16/README.md#provider-and-exact-source-coverage)

The fifteenth group resolved 54 bodies and two original author abstracts. It retains 29 exact pairs and preserves two abstract-reviewed full-body trails separately. [Coverage and pending originals](../masked-fifteenth-nov16/README.md#provider-and-exact-source-coverage)

The fourteenth continuation resolved three more exact original bodies and leaves 4,456 current pairs open. Eight inherited pairs and the separate AES print-collection gap retain updated primary locators. [Latest exact reviews and access](../masked-fourteenth-resume-nov16/README.md#exact-source-access)

The fourteenth pass resolved 14 current-group bodies, four inherited bodies and one inherited author-abstract review. At that checkpoint the queue contained 4,459 exact pairs, heavily concentrated in the raw-fig query. Eight inherited exact pairs and a separate AES deeper collection check remain recorded. [Source coverage and limits](../masked-fourteenth-nov16/README.md#search-and-source-coverage)

The thirteenth checkpoint resolved 16 current-group bodies and two inherited ninth-group articles. Three priority-four pairs and 230 priority-six pairs remain open in the current set. The inherited ninth-group access ledger retains 13 records. [Sources and open routes](../masked-thirteenth-nov16/README.md#search-and-exact-source-review)

The twelfth group resolved 37 exact source pairs in its current scope and 23 shared lemon-balm pairs. Seven additional bodies resolved older ninth-group entries, leaving 15 in that access ledger. [Current evidence and source routes](../masked-twelfth-nov16/README.md#search-and-exact-source-review)

The eleventh group closed 45 of the 67 remaining ninth-group exact pairs. That checkpoint left 22 unfinished identities and source paths. [Review and open access](../masked-eleventh-nov16/README.md#search-and-exact-source-access)

The tenth group added nine original-body reviews. Concurrent work closed 172 ninth-group pairs at primary-body or author-abstract depth and one more eighth-group body. That checkpoint left 67 ninth-group and 18 eighth-group pairs. [Current reports and access routes](../masked-tenth-nov16/README.md)

The ninth group closed 29 higher-priority original pairs. Concurrent access work on the preceding group closed 63 more. Two priority-four and 237 priority-six pairs remain in the ninth group, with one priority-four and 18 priority-six in the eighth group. [Group receipts and remaining sources](../masked-ninth-nov16/README.md)

The eighth group closed 13 exact original-body pairs. The Sellitto priority-four body and 81 priority-six pairs remain open. [Eighth group coverage](../masked-eighth-nov16/README.md)

The seventh existing-assessment group closed seven higher-priority body pairs. Concurrent access reviews resolved ten second-group bodies and four fifth-group bodies. Four second-group and 72 fifth-group priority-six pairs remain open. [Seventh group](../masked-seventh-nov15/README.md) · [Fifth group access review](../masked-fifth-priority-six-nov15/README.md)

The sixth group closed 13 higher-priority pairs. The same replay closed 21 second-group full bodies, 17 cross-group Krijt pairs and one first-group conference pair. An archive title safeguard now holds proceedings carrying an individual article identity. [Review and archive receipts](../masked-sixth-nov15/README.md)

The fifth existing-assessment group closed 16 pairs, including 14 full texts and two original abstracts. The second group added 36 original full-text decisions, initially leaving 35 at priority six. [Fifth group](../masked-fifth-nov15/README.md) · [Second group access review](../masked-second-nov15/README.md#original-body-recovery)

The fourth existing-assessment group closed its 25 priority-four and priority-five pairs at the recorded full-text or abstract depth. It retains 175 original priority-six pairs. [Fourth group review](../masked-fourth-nov15/README.md)

The third existing-assessment group closed 16 non-fig exact pairs, including 14 full texts and two original abstracts. One examined letter remains open with an identifier discrepancy. [Third group context and access limits](../masked-third-nov15/README.md)

The second existing-assessment group closed all five of its priority-four and priority-five pairs using original bodies. The initial checkpoint left 71 priority-six pairs for the group. [Read scope and original locators](../masked-second-nov15/README.md)

The first existing-assessment group closed 47 original full-body pairs and 19 abstract-only pairs. The first access replay resolved 87 priority-six pairs. A later pass resolved 148 more and an alternate-route pass resolved 36. Forty-seven remain with explicit resume states. [Access and evidence receipts](../masked-first-nov15/README.md)

The pain and oil pass resolved 34 original full-body pairs, including the recovered Li preprint. The priority-three queue has 351 pairs after the later black tea, chocolate, olive oil and herb review. [Original source review and strict verification](../pain-dream-oils-nov15/README.md)

The gait and dream-enactment pass resolved 91 original full-body pairs and recovered both formerly unjoined papers. The priority-three queue has 502 pairs. [Strict verification and outcome notes](../gait-and-dream-nov15/README.md)

The urgency and olfaction pass resolved 69 original body pairs and left one gated review open. The priority-three queue now contains 593 pairs. [Evidence and strict verification](../urgency-olfaction-nov15/README.md)

The cumin and motor-outcome review resolved 95 archived or independently retrieved body pairs, including a recovered turmeric review. The evidence ledger matches one additional original pair. The original priority-three queue contains 662 pairs. [Evidence and replay receipts](../kiwi-turmeric-nov15/README.md)

The stride, saffron and fatigue review resolved 66 body pairs, including a recovered review, with one inaccessible original in scope. The live assessment join adds a related crocetinate original from the focused PubMed run. Priority three now contains 757 pairs. [Source comparisons and native verification](../stride-saffron-nov15/README.md)

The bowel and motor follow-up gives 19 additional exact full-body exclusions, including the reviewed cranberry cite to an experiment on mulberry. The archive-backed priority-three queue has 823 pairs. The focused soybean query has a separate screening ledger and retains its pending scope. [Original source notes and search receipts](../plum-and-oil-nov15/README.md)

The banana, egg and fatigue review resolved 71 exact original-source pairs. One archived review gives related piperine context. The other 70 pair decisions exclude unrelated exposures or endpoints, including the recovered piperine-derivative review. The archive-backed priority-three queue now contains 842 pairs. [Evidence and remaining questions](../food-off-time-fatigue-nov15/README.md#review-coverage) · [Native verification](../food-off-time-fatigue-nov15/verification.txt)

The facial expression, falls and anxiety replay resolved 114 exact original-source pairs. Two previously unjoined originals were recovered, and the other bodies are already archived. Five supplied related source context and 109 were excluded. The archive-backed priority-three queue contains 913 pairs. [Original decisions and source limits](../facial-falls-voice-nov15/README.md#coverage-and-open-trails)

Ninety original-search pairs received full-body decisions, including the recovered Amro publisher PDF. Four related pairs preserve existing compound and clinical case evidence context, and 86 were excluded. The Wood review remains open for the body. The archive-backed priority-three queue contains 1,027 pairs. [Original-source decisions and coverage](../posture-pain-urgency-nov15/README.md#coverage-and-open-access)

Sixty-one original-search pairs received full-body decisions, including two previously unjoined sources. Two related review citations reuse earlier coconut-oil observations. Fifty-nine pairs were excluded. The archive-backed priority-three queue contains 1,117 pairs. [Original-source decisions and coverage](../falls-rigidity-and-pain-nov15/README.md#search-coverage-and-unresolved-trails)

Forty-five original-search pairs received exact primary-source decisions. Forty-four use full original bodies and one uses original figures and the abstract. The archive-backed priority-three queue has 1,178 pairs. [Original results and retrieval boundaries](../fatigue-motor-and-mood-nov15/README.md)

Twenty-two original-search pairs received body decisions. Four retained related source context, including a cinnamon leaf catalepsy comparison and the prior marjoram trial. The archive-backed priority-three queue now has 1,223 pairs. [Original outcomes and access](../motor-apathy-falls-nov15/README.md)

Twenty-four original-search pairs received body or primary-source dispositions, including one recovered manuscript. The combined replay also imports one additional exact assessment. The archive-backed priority-three queue has 1,245 pairs. [Body decisions and research checkpoint](../motor-sleep-and-pain-nov15/README.md)

Fifteen original-query source pairs received full-text dispositions, including two previously unjoined bodies. The archive-backed priority-three queue has 1,270 pairs. [Source checks and local extracts](../urinary-food-function-nov15/README.md)

Thirty original body decisions cover common sage, basil and grapefruit. One supplies a related high-dose animal safety observation for sage. The archive-backed priority-three queue has 1,285 pairs. An apple search hit for spiral analysis and a salvinorin A review remain unjoined to a local body. [Scientific comparisons](../comparison-outcome-boundaries-nov15/README.md)

Twenty-four original archived bodies received exact decisions across six claims. The archive-backed priority-three queue has 1,315 pairs. The grape animal studies supply two related outcomes. [Original comparisons](../whole-food-symptom-boundaries-nov15/README.md)

Twenty-two new exact original-source assignments cover swallowing, drooling, and rice-bran-oil contexts. The archive-backed priority-three queue includes 1,339 pairs. A related animal study used purified tocotrienols, and the verified primary does not identify rice bran oil as the administered material. [Source and outcome review](../tremor-oral-outcomes-nov15/README.md)

Twenty-four new body decisions have exact claim and original provider-key matches. The archive-backed priority-three queue has 1,362 pairs. The original GSA program disambiguates the blueberry and constipation mentions. [Source and comparison review](../preparation-and-pain-nov15/README.md)

The next context review resolved 20 body-backed pairs and brought the archive-backed priority-three queue to 1,385. The three PRIME pairs still await results after a fresh official registry check. [Full-text scope and registry receipt](../diet-outcome-specific-nov15/README.md#coverage-and-next-source-access)

The oil review updates 25 full-text pairs, including comparisons with actual oral corn and soybean oil. Ten have related context and fifteen concern another exposure, comparator or outcome. The archive-backed priority-three queue contains 1,404 pairs. [Oil comparators and identity checks](../clinical-preparation-nov15/README.md#search-and-archive-context)

Thirteen full-text dispositions bring available archived priority-three pairs to 1,429. Twelve concern sunflower oil in distinct exposures or outcomes. One locates the actual corn-oil vehicle comparator within reviewed cannabidiol results. [Exact source context](../culinary-symptom-nov15/README.md#exact-archive-context-and-search-coverage)

The archived swallowing review for 0124 cites the already assessed inhaled black pepper oil trial. The exact body review reduces priority three to 1,442 pairs. [Context and source](../endpoint-sources-nov15/README.md)

A 19-pair human clinical source review added five related and 14 excluded full-text decisions. The remaining priority-three group contains 1,443 pairs. Primary comparisons distinguish composite motor outcomes and mixed dietary interventions from separately measured food and symptom effects. [Primary source context](../peanut-and-pomegranate-visual-nov15/README.md#exact-context-review) · [Exact decisions](exact-reviews.tsv)

The fish review promoted 17 title/index-only pairs to exact body decisions. Five were related and twelve were excluded. The remaining priority-three group contains 1,462 pairs. [Fish review and primary sources](../ginger-anxiety-and-fish-nov15/README.md#fish-and-vitamin-d-context) · [Exact decisions](exact-reviews.tsv)

The ginger clinical-context replay closed 18 exact archived pairs across six sources. It counted ten exclusions and eight related dispositions. The remaining priority-three group contains 1,479 pairs. [Clinical context and source trail](../clinical-checkpoint-nov15/README.md) · [Exact dispositions](exact-reviews.tsv)

The three priority-one pairs have exact full-text protocol dispositions. PRIME plans to measure gastrointestinal symptoms, stride length and walking speed while recommending extra-virgin olive oil within a broader diet. The November 15 official registry snapshot had no posted results. The Guk coffee/fatigue pair was closed as related after checking how the primary report models symptoms. Six full-text and 13 abstract reviews resolved all 19 priority-two lexical matches for dried date pain. Their reported exposures were unrelated to date fruit intake. The fruit-specific evidence search remains open. The remaining priorities retain every returned pair, including the 44,288 in the priority-six group with neither lexical flag. [Exact reviews](exact-reviews.tsv) · [Priority one](priority-1-local.tsv) · [Date pain screen](date-pain-screen.md) · [Earlier date query recovery](../date-metadata-screen.md)

The outside-query PMC sweep has a separate vocabulary and report. Its 3,194 exact contextual dispositions do not exhaust the original query inventory or describe sources that were never returned. [Outside-query method and coverage](../archive-body-sweep.md)

The new source-grouped replay file `context-queue-by-source.tsv` gives queued-pair counts by priority and archive join. The per-pair ledger remains authoritative for individual dispositions. The previous pass added 45 exact full-text decisions from three clinical review sources and the original almond-oil and rosemary searches. That snapshot retained 2,021 priority-three pairs. [Clinical review follow-up and source corrections](mediterranean-curcumin-audit-2026-11-15.md) · [Almond oil](../almond-oil-local-route-replay/README.md) · [Rosemary](../rosemary-hallucinations-tremor-replay/README.md) [Detailed priority-three sources](priority3-2026-11-15.md) · [Peach follow-up](../peach-remaining-endpoint-replay/README.md)

A full native routing trial found additional human-source labels but no valid new priority-one or priority-two dietary pairs. Three priority increases were driven by the temporal phrase “to date.” Individual abstract review resolved those three pairs, and nine local body reviews resolved the original baked-apple matches. The indexed date and fig matcher passed 18 controls and placed 1,839 pairs in priority three in that replay. It preserves every open pair. [Clinical routing trial](routing-audit-2026-11-15/README.md) · [Temporal phrase reviews](date-temporal-phrase-followup.md) · [Indexed date and fig routing](indexed-fruit-routing-2026-11-15/README.md)

Thirteen additional body decisions resolve six raw-cucumber pairs, five toasted-cumin pairs and two scrambled-egg pairs. Some sources use sea cucumber or black cumin, and some use egg-shaped as an imaging description. That pass left 1,831 open priority-three pairs. [Raw cucumber](../cucumber-postural-instability-replay/README.md) · [Toasted cumin](../cumin-toasted-dyskinesia-replay/README.md) · [Scrambled egg](../scrambled-egg-hallucination-replay/README.md)

The preceding checkpoint added 65 exact reviews. The 27 shared-DOI results were independently reviewed under their individual PMIDs, with the shared aliases still unresolved. Additional full-text checks distinguish egg studies, cardiovascular terminology, lentil odor, a person named Ginger and separate peanut-oil and hallucination presentations. [Shared DOI audit](ambiguous-source-audit-2026-11-15/README.md) · [Egg conference screens](../scrambled-egg-hallucination-replay/README.md) · [Exact decisions](exact-reviews.tsv)

The preceding checkpoint added 43 full-text decisions for potato, salmon, rosemary, shrimp, sage, spinach and spearmint. Two potato records joined to conference bodies with conflicting publication identifiers. The verified publisher PDF supplied an exact decision for one. The other still requires its own primary body. Official PMC pages and a Cambridge PDF supplied presentation context for four more potato-query records. Both native replays now hold links with corroborated identity conflicts. Three deliberate conflict fixtures were held, and the production snapshot retained nine DOI advisories and had zero active holds. [Identity audit](archive-identity-2026-11-15/README.md) · [Current provenance advisories](archive-identity-conflicts.tsv) · [Four verified conference contexts](../boiled-potato-sleepiness-replay/primary-body-contexts-2026-11-15.md) · [Exact decisions](exact-reviews.tsv)

The preceding conference checkpoint added 67 exact primary-context decisions. The World Parkinson Congress review resolved 57 pairs following inspection of independently numbered presentations. Five date and fig pairs stay open. The IUNS collection supplied six saffron citation exclusions and one related strawberry-leaf cell study. Three original grapefruit results came from a tablet flavor listing and separate conference presentations. The 1994 collection required OCR of 53 pages and visual checks on three. [Shared conference audit](shared-collection-audit-2026-11-15/README.md) · [1994 OCR receipt](../grapefruit-stride-replay/1994-ocr-context.md) · [Exact decisions](exact-reviews.tsv)

The SGIM 2025 review resolved 58 additional exact pairs across 2,166 original numbered presentations. A turmeric liver-injury report provides related evidence for claim 0812. Fifty-seven pairs were excluded after checking the relevant presentation context. Three fruit pairs remain open. The native replay preserved all 61,252 original memberships and the prior archive joins. [SGIM verification](sgim2025-context-audit/README.md) · [Exact decisions](exact-reviews.tsv)

The IUNS primary PDF review resolved another 75 pairs in its edible-oil and spice subsets. Its two related presentations concern perioperative fatigue after an MCT and carbohydrate solution and post-exercise soreness with a turmeric extract formulation. The review assigned 73 contextual exclusions and left 81 food and herb memberships in this same source open. The native replay retained every original pair and its archive access state. [Conference verification](iuns-2026-oils-spices-audit/README.md) · [Exact decisions](exact-reviews.tsv)

The next primary-context pass resolved 25 exact pairs from the 2017 Parkinson molecular review and 79 food or herb pairs from the Cambridge IUNS collection. Three title-only reviews moved to full text. The IUNS review retained two related contexts for oat and mixed-fruit trials. Their questionnaire composites leave the sleep or abdominal pain item estimates unreported. Two African thyme exact pairs remain open on species and preparation identity. The native replays preserve all 61,252 original claim–source pairs and their archive access fields. [Molecular review verification](molecular-review-2017/README.md) · [IUNS review and original outcomes](iuns-2026-food-herb-audit/README.md) · [Exact decision ledger](exact-reviews.tsv)

The honey–herb review supplied 24 full-text dispositions, including 21 contextual exclusions and three low-fit citations. The 2023 full article distinguishes Nigella from ordinary cumin, topical sesame wound outcomes from pain, and the mixed saffron syrup from separately measured insomnia. The replay preserved all original memberships and archive-access fields. [Honey–herb exact audit](honey-herb-review-2024/README.md)

The frailty review supplied 21 full-text dispositions, including 15 exclusions and six related citation routes. Fried's original frailty definition uses three of five criteria, and the distinct Altemor comparison used a risk screen without an observed fall estimate in the abstract. Two cinnamon pairs remain open on the cited chapter's original contents. [Frailty exact audit](frailty-review-2024/README.md) · [Open pairs](frailty-review-2024/open-exact-pairs.tsv)

The 2019 dietary supplement review supplied 24 full-text decisions covering all its remaining open pairs. Eighteen were contextual exclusions and six were related primary-source trails. The retraction route, original flaxseed aggregate scale discrepancy and explicit watermelon plural were independently checked. The original provider inventory retained every membership. A separate isolated inflection test found 24 priority changes and retained the exact pair keys. [Review audit](dietary-supplements-review-2019/README.md) · [Inflection diagnostic](inflection-broad-audit/README.md)

The six November 15 review clusters closed 104 remaining original pairs, including 12 upgrades from title indexing. The full native typed-form replay adds 28 jointly reviewed archive pairs and keeps all original memberships and access paths. The live priority distribution reflects both the new dispositions and the typed exposure cues. [Cluster review evidence](nov15-review-clusters/README.md) · [Typed exposure validation](inflection-broad-audit/README.md) · [New archive dispositions](../archive-body-2026-11-15-typed-inflection-dispositions.tsv)

Eight more reviews supplied 102 exact decisions. Primary citations separate compounds from their food sources, distinguish preparation and route, and retain the source bodies that still need checking. The native replay retains all 61,252 pairs and 8,685 archive joins. [Second source cluster review](nov15-second-clusters/README.md) · [Exact decision ledger](exact-reviews.tsv)

Four mobility sources supplied 24 decisions after checking each clinical symptom context and the text behind the sage or date match. Four human sources supplied five more related pairs. The native replay kept all 61,252 original memberships and 8,685 archive joins. [Mobility and human-source review](mobility-and-human-context-nov15/README.md)

The next pass added 25 oil records and 32 sage or date contextual exclusions from archived primary bodies. It separated source roles, current outcome papers and endpoint timing. The replay kept every original membership and archive join. [Oil and rehabilitation evidence](oils-and-rehabilitation-nov15/README.md)

The olfaction pass added 22 verified body contexts and five exact kale-source decisions. The later original report resolves the scents for one cohort and the registration records a different protocol. The two unread 1991 scans remain open. [Olfactory evidence and access audit](olfactory-methods-nov15/README.md)

## Reproduce and update

Run from the repository root with the Athena Free Pascal toolchain.

    & ./experiments/1000_see_what_sticks_food/tools/build-contextqueue.ps1

The default overlay is the recovered original query layer at `build/claim-search-complete-date-overlay/ingredient_results.tsv` within the experiment. The runner accepts an equivalent experiment-relative `-Overlay` input. The complete inventory and queue are generated under `build/context-coverage/output`, alongside the per-claim summary and priority slices. The replay pairs assessments and earlier screening records only where there is an exact claim and unambiguous source match. The stored tables and fingerprints describe the current published replay. [Native source](../../tools/foodexperiment.contextqueue.lpr) · [Inputs](review-inputs.tsv) · [Input fingerprints](input-sha256.tsv)

Add one line per exact pair to `exact-reviews.tsv`. Keep the claim `id` and `source_key` from the overlay. Use `excluded`, `related`, `supports`, `opposes`, `inconclusive` or `pending` for `result_role`, and `full_text`, `primary_source`, `abstract`, `title_and_index`, `assessment_unspecified` or `access_only` for `review_basis`. Use `access_only` with `pending`. Reference an existing repository-relative file and give the specific exposure, outcome, population or access reason. The replay rejects invalid keys, duplicates, invalid roles or bases, missing files and empty rationales. An exact disposition changes one claim–source pair. Clinical verdicts remain decisions in the experiment evidence ledger.

Checkpoint 23 resolves 127 exact pairs in four complete posted originals, with 92 related contexts and 35 exclusions. It preserves ten sampled collection routes and the remaining 364 pairs at their current access depth. [Originals, companion reports and native replay](../shared-original-collections-nov19-23/README.md)

Checkpoint 24 verifies six original pairs for poached chicken and fatigue at body depth, including the poultry substitution study. The mitochondrial case remains in the original queue with its available abstract and PDF-access limits. [Sources, decisions and replay](../chicken-fatigue-registered-nov19-24/README.md)

Checkpoint 25 reviews 19 original banana–apathy pairs at body depth and preserves seven remaining access routes. [Source scope and assessments](../banana-apathy-source-depth-nov19-25/README.md)

Checkpoint 26 resolves eight original strawberry–falls pairs at body depth and leaves 112 collection-source pairs open. Five retain related food or plant context and three resolve different uses of the word strawberry. [Scope, exact decisions and replay](../strawberry-falls-source-depth-nov19-26/README.md)
