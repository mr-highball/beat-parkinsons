# Potato source identity audit

## PMID 20532731

Sellitto and colleagues' *A subtle case of iron-deficiency anemia* is DOI `10.1007/s11739-010-0412-7`, *Internal and Emergency Medicine* 6(2):191–192, April 2011. Springer gives first publication as June 8, 2010. Its publisher landing provides citation and indexing context but only previews the subscription article. The university repository identifies the authors and the 2011 issue year and lists no attached file. The exact full article body remains unverified. [PubMed](https://pubmed.ncbi.nlm.nih.gov/20532731/) · [Springer](https://link.springer.com/article/10.1007/s11739-010-0412-7) · [University repository](https://iris.unicampania.it/handle/11591/184695)

Europe PMC's current MED record supplies `PMC7103256`. The PMC landing shows the same PMID backlink, and an earlier indexed PubMed page showed the reciprocal link. Current official PubMed eFetch lists no PMC ArticleId. PMC's archived text and Springer's printed PDF instead identify Pergolini's *Posters*, DOI `10.1007/s11739-011-0736-y`, volume 6 supplement 2, pages S191–S392, the 112th Italian Society of Internal Medicine National Congress held in Rome on October 22–25, 2011. The NLM Cloud TXT lists that DOI and the PMCID with an empty PMID field. [PMC record](https://pmc.ncbi.nlm.nih.gov/articles/PMC7103256/) · [Springer conference PDF](https://link.springer.com/content/pdf/10.1007%2Fs11739-011-0736-y) · [Congress citation in an author's institution](https://iris.uniroma1.it/handle/11573/437647)

The conference PDF includes potato in Aruanno and colleagues' two-patient plant-food allergy poster (S191–S192). Its excessive daytime sleepiness text is from De Rui and colleagues' separate cirrhosis poster. These are boundaries within the collection. Preserve the original 0794 pair and its bibliographic access gap. Use the Sellitto DOI if obtaining its exact primary copy or seek an NLM link correction. [Springer conference PDF](https://link.springer.com/content/pdf/10.1007%2Fs11739-011-0736-y)

## PMID 21969099

Wood's three-page tegaserod editorial is DOI `10.1007/s00210-011-0694-y`, *Naunyn-Schmiedeberg's Archives of Pharmacology* 385(1):1–3, January 2012, online October 4, 2011. The exact PDF discusses tegaserod for constipation-predominant irritable bowel syndrome and cardiovascular risk, including commentary on in-vitro platelet and artery work. It supplies no boiled-potato or Parkinson daytime-sleepiness evidence. The exact contextual exclusion is recorded for 0794 at full-text depth. [PubMed](https://pubmed.ncbi.nlm.nih.gov/21969099/) · [Exact Springer PDF](https://link.springer.com/content/pdf/10.1007/s00210-011-0694-y.pdf)

Europe PMC's current MED record supplies `PMC7100643`; current official PubMed eFetch lists no PMC ArticleId. PMC's archived text, official PubMed eFetch and publisher identify the archive body as the *Abstracts of the 78th Annual Meeting of the German Society for Experimental and Clinical Pharmacology and Toxicology*, March 19–22, 2012, Dresden. Its exact identifiers are `PMID:22349181`, `PMC7100643`, DOI `10.1007/s00210-012-0736-0`, volume 385 supplement 1, pages 1–116. Presentation 449 tests potato chips in five healthy men and measures urinary mercapturic acids after the meal. It is a separate conference presentation about food-contaminant exposure, with a different preparation, population and outcome than 0794. [PubMed 22349181](https://pubmed.ncbi.nlm.nih.gov/22349181/) · [PMC record](https://pmc.ncbi.nlm.nih.gov/articles/PMC7100643/) · [Springer conference PDF](https://link.springer.com/content/pdf/10.1007/s00210-012-0736-0.pdf)

## Native guard

The original overlay includes 30 exact pairs for PMID 20532731 and nine for PMID 21969099. The current local-text ledger joins neither PMCID. The source identifier problem is present in both original-query rows for 0794 in the recovered overlay. It does not itself change an assessment or verdict.

Before the guard, `foodexperiment.depth` resolved local bodies by PMCID and could emit lexical flags from a wrongly associated body. `foodexperiment.contextqueue` accepted those rows by exact claim and overlay source key. A mismatched body with the expected PMCID field could therefore be assigned to the exact pair.

The context queue now applies a guard that reads the bounded provenance header once per source/path. When both sides have explicit values, a contradictory PMID, PMCID, or screen-row PMCID holds the body join. A differing DOI also holds unless the explicit PMID, PMCID, and normalized title all agree. That corroborated case keeps body routing and reports a DOI advisory. Every conflict or advisory appears with both sides' identifiers and the disposition in `archive-identity-conflicts.tsv`. Pairs stay eligible for review and their disposition is intact. Older headers with absent identity fields are permitted and are not evidence of an identity match. A retained DOI advisory may still require review of the indexed version or translated text before an exact-version evidence assessment.

The depth pass now applies the same check before counting a body join. A held join leaves the exact search pair open and preserves the separate archived publication for the independent body sweep. The successful fixture exposed both proceedings as independent lexical candidates. The matching German proceedings joined when represented under their own verified PMID. External provider identifiers and previously recorded evidence dispositions retain their original provenance. [Producer fixtures and production counts](depth-native-verification.txt) · [Seven report fingerprints](depth-production-sha256.tsv)

## Validation

- Same source snapshot and overlay on both builds. All eight existing output tables were identical. The 61,252 pair inventory, including 39 pairs bearing one of the case PMIDs, was preserved.
- A blanket DOI disagreement hold would have displaced nine currently joined pairs from seven sources. Five source records differ by article version, one by bilingual DOI suffix and one by a journal DOI alias. With same title and explicit PMID and PMCID, all nine remain routed and appear in the advisory receipt.
- Fixture stock replay joined the two real PMC accession TXT files to the exact 0794 PMID rows. A third fixture uses a wrong PMCID on a screen row for 0290. The guarded replay held exactly these three. Both original 0794 pairs remained, with no review decision changes across all 61,252 rows.
- `verify.log` records the native full-inventory assertions. `contextqueue-archive-identity.patch` passes a read-only git apply check from the repository root. Source is under `src/`. The 0794 Wood review cites this source audit and the exact publisher PDF.

## Receipts

`raw/nlm-pubmed.xml`, `raw/nlm-pubmed.headers`, `raw/europe-pmc-current.json` and its headers preserve the live official responses. The exact original primary source TXT files used in the isolated replay were copied from the earlier acquisition under `build/boiled-potato-sleepiness-replay/original-bodies`. The three fixture rows are the final rows of `fixture-repo/experiments/1000_see_what_sticks_food/followup/claim-local-text-screen.tsv`. They intentionally simulate untrusted join input and are for testing only.

