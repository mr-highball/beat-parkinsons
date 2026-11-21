# Native FPC PMC JATS XML Screener and Priority-5 Zero-Directional-Symptom Pass (Nov 21)

This packet introduces the checked Free Pascal NCBI PMC JATS XML full-text screener ([`foodexperiment.pmcxml.pas`](../../tools/foodexperiment.pmcxml.pas), [`foodexperiment.pmcscreen.lpr`](../../tools/foodexperiment.pmcscreen.lpr), [`foodexperiment.pmcscreen.tests.lpr`](../../tools/foodexperiment.pmcscreen.tests.lpr), [`build-pmcscreen.ps1`](../../tools/build-pmcscreen.ps1)) and applies it across the Priority-5 non-homograph queue targeting the `21` zero-directional Parkinson symptoms (`243` pairs across `217` sources, `207` unique PMCIDs).

## FPC screener precision guarantees (`10/10` checked tests, zero compiler warnings)

- Verifies `<article-id pub-id-type="pmid">` against the queued PMID (auto-holding `pmid_mismatch`).
- Detects conference abstract supplements and multi-`<sub-article>` bundles (`collection_hold`) and short/missing full-text stubs (`no_body`).
- Checks BOTH the canonical ingredient AND an explicit botanical/phytochemical alias lexicon (e.g., `turmeric` -> `curcuma`, `curcumin`, `curcuminoid`, `demethoxycurcumin`, `bisdemethoxycurcumin`; `broccoli` -> `brassica oleracea`, `sulforaphane`, `glucoraphanin`) with strict word boundaries.
- Emits automated `excluded` (`full_text`) proposals ONLY for `zero_body_collision` (`title_abs_hits = 0` AND `body_hits = 0` across all aliases in a verified full body >= 400 chars), surfacing every paper with >= 1 title/abstract/body match as `body_match` with context snippets for direct review.

## Oracle-first lookup and full-text reconciliation

- **Oracle-first lookup (`217` sources across `21` zero-directional symptoms):** `8/217` strict hits (`PMID:20157723`, `PMID:23140444`, `PMID:23661325`, `PMID:25578290`, `PMID:26035833`, `PMID:31119595`, `PMID:32889602`, `PMID:39741957`) and `209` misses, logged in [Oracle coverage](../../../oracle-coverage/README.md).
- **Batched NCBI PMC JATS XML retrieval (`207` unique PMCIDs):** `174` complete full-text bodies + `33` non-OA stubs (`36` pairs held honestly as `no_body`; `0` PMID mismatches; `0` collection holds).
- **`foodexperiment.pmcscreen.exe` + full-text audit reconciled `70` full-text pairs (`65` `excluded` + `5` `related`):**
  - `30` automated `zero_body_collision` full-text exclusions (strictly author/affiliation/reference hits).
  - `35` verified body collisions: diagnostic sniff-test odor items (`UPSIT` / `Sniffin' Sticks` cinnamon and saffron cards across `11` pairs), fluorescent/reagent tags (`tdTomato`, `tomato lectin`, `cherry-KDEL`, `Cherry-NSG1`), abbreviations/equipment (`OATs` transporters, `BASIL` trial acronym, `Ugo Basil RotaRod`, `EGG` electrogastrography), idioms (`chicken-and-egg` / `hen-egg`), country/author mentions (`Turkey`, `Dr. Melissa Armstrong`, `Jonathan Trout`), laboratory solvents (`corn oil` hormone injection, `sunflower oil` rotenone vehicle), and commercial macaque banana-flavored grain pellets.
  - `5` verified `related` preclinical 6-shogaol + levodopa PD mouse pairs (`0271`, `0626`, `0868`), with two new primary records cataloged:
    - [2024-PMID39092515-6Shogaol-Levodopa-Mouse-Olfaction.txt](../../../../research/2020-2024/Source-Text/2024-PMID39092515-6Shogaol-Levodopa-Mouse-Olfaction.txt) (`PMC11392672`, oral 6-shogaol + levodopa buried-food olfaction improvement in MPTP/probenecid mice)
    - [2026-PMID42375089-6Shogaol-Levodopa-Gut-Motility.txt](../../../../research/2025-2029/Source-Text/2026-PMID42375089-6Shogaol-Levodopa-Gut-Motility.txt) (`PMC13324408`, oral 6-shogaol + levodopa gut-motility restoration in MPTP/probenecid mice)

## Queue reconciliation and replay

- Reconciled cleanly via `foodexperiment.contextintake.exe` (`70 checked; 0 still queued`) and replayed via `build-contextqueue.ps1`. [Exact dispositions](dispositions.tsv) · [Pinned scope](pinned-scope.tsv) · [Remaining pairs](open-cluster-pairs.tsv) · [Native replay verification](native-replay-verification.txt)
