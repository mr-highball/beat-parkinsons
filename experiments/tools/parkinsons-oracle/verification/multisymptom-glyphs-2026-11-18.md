# Multiple symptoms and generated glyphs

The Nyx web interface now retains multiple symptom pills and matches any selected symptom. Shared ingredient, preparation, scope and effect filters apply to each symptom before combining the results. Individual pill removal and quick-choice toggling preserve the remaining selections. The guidance and result heading describe the OR behavior.

The production browser adapter follows all claim pages, deduplicates by round and frozen ID, and sorts before global pagination. Catalog leads use separate symptom queries, interleave results and deduplicate paths across pages. Culture filtering continues through later batches; it does not stop at the first nonmatching batch. Source counts avoid summing overlapping totals. Cached pages belong to the current search snapshot, and new searches reset the caches. Changed revisions or superseded in-flight requests cannot be merged into a new response.

Fourteen transparent PNG glyphs were generated with the built-in imagegen tool. The selected [masters, prompts and SHA-256 manifest](../web/assets/glyphs/README.md) are tracked. The native build embeds compressed masks into the stylesheet, preserves all alpha values and dimensions, and needs no additional image route. Separate icons identify All research, Studies & analyses and Culture & experience. The former generic tab mask rule was overriding the individual icon choices; the new rules select the mask through a tab-specific property.

## Verified

- Native selection/identity fixtures: **11 checks passed** with range, overflow and I/O checking.
- The same fixtures transpiled with pas2js and executed in Node: **11 checks passed**.
- Production OR-adapter transport fixtures: **312 checks passed**, including a 154-claim overlapping union, claims beyond the first 100, final partial pages, 250 unique catalog paths across overlapping streams, source-kind filtering after the first batch, cached previous pages, mixed revisions, superseded callbacks and premature backend pagination.
- Live API probe against committed research revision `efd2d7988d433229f12d5937bd9af434dfbaab00`: **420 distinct frozen tremor-or-pain claims**, **8 easing claim results** with both the black-tea tremor and walnut-oil pain findings retained, and **16 unique source leads** across two pages. The probe uses the production OR adapter, not a separate union implementation.
- Nyx browser compilation and native glyph build succeeded: **14 glyphs**, **5,093,389 master bytes**, **930,872 encoded mask bytes** before base64, and **22,015,224 alpha pixels compared** after decoding.
- Catalog refresh: revision **71**, **35,079 indexed files**, **0 read errors**. PMID 28214539 resolves to the existing Lumbee selected factual extract after its corrected metadata header. This is not a full-text archive claim.
- Build and test outputs remain in ignored build directories. No native listener or running server executable was replaced, and the native MCP/API query schema remains unchanged.

These are compiler, native, generated-JavaScript and API checks. Mobile browser interaction and visual layout verification remain pending. No GitHub Pages publication is claimed.
