# Non-Homograph Priority-3 Audit and Priority-4 Full-Text Reconciliation (Nov 21)

This packet audits all `12` remaining Priority-3 pairs (`9` distinct sources) and clears all `33` Open Access full-text non-homograph Priority-4 pairs across Round 1 (`18` distinct frozen claims, including `11` zero-directional symptom claims across `falls`, `bradykinesia`, `dyskinesia`, `dystonia`, `olfaction`, `postural instability`, and `speech intelligibility`).

## Priority-3 Oracle-first audit (`12` pairs across `9` sources)

- First-pass `oracle_find_sources` and `oracle_search_catalog` matched **`9/9` Priority-3 sources (`100%`)** already archived at abstract or citation-list depth in Oracle catalog revision `270`:
  - `AGR:IND609044984` (`0063`, `0218`, `0417`, `0485`): `research/2025-2029/Source-Text/2025-Kaur-Gupta-Parkinson-Herbal-Review-References.txt`
  - `PMID:38446350` (`0063`), `PMID:39577115` (`0063`), `PMID:32725282` (`0128`), `PMID:20359261` (`0271`), `PMID:20874701` (`0485`), `PMID:25796668` (`0722`), `PMID:31476432` (`0937`), `PMID:42785532` (`0948`).
- Official NCBI PubMed verification confirmed all `8` Priority-3 PMIDs lack an open PMCID (paywalled journals), so they remain honestly queued at abstract/bibliography depth without inflating review depth to `full_text`.

## Priority-4 non-homograph full-text clearance (`33` pairs resolved; `71` access/mismatch holds preserved)

- First-pass `oracle_find_sources` across all `72` distinct Priority-4 non-homograph sources (`71` PMIDs + `PMCID:PMC13675721`) found `3` existing Oracle records (the three French NS-Park/DIGPD `Melissa` author-collision studies: `PMID:38578434`, `PMID:41612959`, `PMID:42715510`) and `69` misses (`12/81` combined P3+P4 strict hit rate logged in [Oracle coverage](../../../oracle-coverage/README.md)).
- Official NCBI PMC JATS XML (`efetch.fcgi?db=pmc`) with strict `<article-id pub-id-type="pmid">` verification retrieved complete full-text bodies for all `33` Open Access non-homograph P4 articles (`33` pairs):
  - **`32` `excluded` at `full_text` depth:** Verified author/collaborator collisions (`David P. Salmon`, `Krolak-Salmon`, `V. Broccoli`, `Cherry O. Onaiwu`, `Basil A. Eldadah`, `Rosemary Burke`), software collisions (`MANGO` MRI viewer, `ManGO` KU Leuven data repository, `Salmon v1.3.0`), geographic/language collisions (`Turkey`), figure color (`salmon`), geometric shape (`banana-like shape`), typographical error (`video-EGG`), idiom (`chicken-egg dilemma`), and wrong botanical species (`Indian winter cherry` / *Withania somnifera*).
  - **`1` `related` at `full_text` depth (`0948`, `PMID:33154736`, `PMC7586315`):** Han Chinese PRKN family case report cataloged in [2020-PMID33154736-PRKN-Family-Green-Tea-History.txt](../../../../research/2020-2024/Source-Text/2020-PMID33154736-PRKN-Family-Green-Tea-History.txt), recording descriptive baseline green-tea history ("Never" vs "Quit") alongside onset fatigue complaints without any tea intervention or fatigue scale.
- **Explicit access and identity holds preserved (`71` remaining non-homograph P4 pairs):**
  - `33` pairs belong to two known PMC congress-supplement identity mismatches where the linked PMCID holds a multi-abstract supplement rather than the indexed single article (`PMID:20532731` -> `PMC7103256` *Internal and Emergency Medicine Posters*, 27 pairs; `PMID:15896867` -> `PMC7134330` *ECB12 Biotechnology Congress*, 6 pairs) — intentionally kept queued rather than auto-excluded.
  - `38` pairs (`37` PMIDs) are paywalled or non-OA PMC records; batched PubMed XML inspection confirmed **`0/38`** mention the food ingredient in title or abstract (`14` are author/affiliation collisions visible in PubMed metadata), and they remain honestly queued pending full-text access.

## Queue reconciliation and replay

- Reconciled cleanly via `foodexperiment.contextintake.exe` (`33 checked; 0 still queued; 33 new; Total 18,633`) and replayed via `build-contextqueue.ps1`. [Exact dispositions](dispositions.tsv) · [Pinned scope](pinned-scope.tsv) · [Remaining pairs](open-cluster-pairs.tsv) · [Native replay verification](native-replay-verification.txt)
