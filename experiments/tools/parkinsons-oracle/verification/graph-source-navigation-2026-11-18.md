# Research graph and clickable study references

Study titles, assessment references and claim citations now open their saved source. The live reader strips reference fragments from the file request and restores the originating evidence view. Portable citations keep their repository URL and fragment. Reading a source from the graph preserves the explored nodes, connections, selection and camera for the return path.

The graph uses the Nyx Canvas workspace with ordinary Nyx buttons and Drawing paths. Its pan, zoom, Fit and Home controls reuse the library's camera implementation. Selecting a node reveals its connections; further connections are available through explicit paging with counts. A connection explorer supplies ordinary text buttons alongside the spatial view. Focus this branch reduces the displayed web around the selected node without changing the underlying model.

The data comes from the committed WFC-backed oracle claim model. All **6,930 frozen claims** are included. At research snapshot `3f4b7b3b2333c057460b904545d627507bf57ec7`, the projection contains **4,524 nodes** and **18,927 links**: 6,930 claim links plus three links for each of 3,999 assessments. Node kinds are symptom, ingredient, exact ledger study key and saved source document. This is a projection of recorded assessments and their reference files; it does not label all indexed catalog documents as assessed articles or infer additional diagnoses from word matches. Distinct ledger keys remain distinct, and a shared note can cover several studies.

Qualified easing/worsening judgments produce green/red claim links. A supporting assessment keeps the direction it supports and is labeled as hypothesis support. Related, inconclusive and pending assessments remain gray. An opposing assessment does not generate an inverse efficacy claim. The connection cards retain symptom, preparation, study fit, full assessment text and its saved reference. Graph exploration explicitly includes open questions beyond a result list's narrower filters.

## Executed checks

- **14 native and 14 transpiled** evidence-direction checks passed, including uncertainty, pending evidence and the prohibition on reversing opposed hypotheses.
- **15 real-model projection checks** passed. These include all 210 tremor hypotheses, the exact frozen 0904 wording and preparation, the qualified black-tea relief edge, and the NCT00461942 source and fatigue/rest-tremor assessment links. The latter remain related context, not positive or negative efficacy findings.
- Native SHA-256 and Node's built-in UTF-8 SHA-256 agree on the complete embedded model before JSON parsing. At the above snapshot the model is **5,843,460 bytes**, digest `22a04b5d2cf830f46adc4e43fd72a36c1480c0e37e89c16575939e220250d5fe`. This checks every byte, including Unicode and escaping across generated literal boundaries.
- Existing **312 OR transport checks** still pass. No native API/listener change is needed.
- The saved Tea-Followup and Black-Tea-Motor reference files open through the live source-reader API, returning 1,973 and 3,260 characters respectively. These API checks establish readable paths, not browser click execution.
- Nyx web compilation succeeds for embedded/live and portable/static modes. Portable mode reuses the existing `claims.json` instead of embedding a duplicate model. Browser assets must be rebuilt after research commits; text re-indexing alone does not update the embedded graph. The UI displays its revision and checks the current oracle revision.
- Compiler, include, model and test outputs are under ignored build directories. Frozen claims, evidence judgments and research files were not modified by this interface change.

Browser input, touch gestures, visual layout and mobile source-return interaction remain unverified under the existing browser-access guard. No visual acceptance or public deployment is claimed. These checks distinguish compiled UI wiring, executed model semantics, readable API sources and actual browser interaction.
