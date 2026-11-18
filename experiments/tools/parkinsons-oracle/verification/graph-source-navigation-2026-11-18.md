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

The follow-up audit found that the initial direction fixtures used `support` and `oppose`, while ledger rows use `supports` and `opposes`. The graph now matches the actual schema. Both real saffron assessment links labeled `opposes` show “Challenges hypothesis” without implying an inverse effect. The revised native and transpiled direction fixtures pass 15 checks each, and the real-model fixture passes 18 checks.

The mobile follow-up limits touch handling to the graph surface. Pinch and drag use the Nyx camera. A short stationary touch selects a node. The layout has vertical connectors on narrow screens, a wrapping toolbar and a Home action centered on the selected node. Capture-phase activation allows the native node button to open a branch even when its component consumes the bubbling click.

- Native and transpiled touch state fixtures pass 23 checks each. They cover anchor-preserving pinch, drag, tap jitter, capture cancellation and transitioning from pinch to one-finger drag.
- The live browser at a 390 CSS pixel viewport opened Tremors and Black tea together in the 322-pixel-wide canvas. The first node grew from 220 to 275 pixels with Zoom in and returned to 220 pixels with Home. Browser viewport scale stayed at 1. Computed touch action was `none` on the graph and its nodes and `auto` on the page.
- In that browser, activating the actual Black tea node opened its studies. PMID22855866 exposed recorded outcomes, and its source opened and returned to the same study view. The viewport override was restored after the check.
- Physical two-finger pinch on a phone remains unverified. The browser-scale receipt above uses the graph's button, while the two-contact camera behavior is checked by the native and transpiled fixtures.
