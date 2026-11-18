# Generated oracle glyphs

These fourteen transparent PNG masters were generated with the built-in imagegen tool on 2026-11-18 UTC. No external image-generation API or CLI was used. Labels remain visible text; the glyphs are decorative CSS masks, not the sole indicator of a control or evidence direction.

The selected files are original generation outputs. The native [glyph encoder](../../../glyphs.embed.lpr) preserves every alpha value and image dimension while encoding monochrome masks into the built stylesheet. It verifies the encoded masks by decoding and comparing all alpha pixels. RGB color is supplied by CSS. No image server, extra route or external image request is needed, including in the portable Pages build.

## Selected set

| File | Use and requested subject |
| --- | --- |
| [all.png](all.png) | three overlapping research cards arranged as a tidy stack, top card with a small branching knowledge mark; do not use a microscope or a leaf |
| [study.png](study.png) | a clearly recognizable scientific microscope in side view, simple chunky silhouette with open negative space |
| [culture.png](culture.png) | two overlapping rounded speech bubbles with a small simple leaf between them, representing shared knowledge and lived experience; absolutely no human figures, hats, ethnic motifs, clothing or text |
| [symptoms.png](symptoms.png) | an abstract upright human upper body with a simple pulse or tremor wave across its middle; calm neutral medical symbol, no anatomical details |
| [sources.png](sources.png) | an open reference book with a small magnifying glass at its lower right; clearly different from a microscope |
| [eases.png](eases.png) | one bold downward arrow beside a short wavy symptom line becoming calmer; minimal and unambiguous down direction |
| [worsens.png](worsens.png) | one bold upward arrow beside a short wavy symptom line becoming stronger; minimal and unambiguous up direction |
| [unclear.png](unclear.png) | one large clean question mark inside an incomplete circular ring |
| [search.png](search.png) | one simple round magnifying glass, diagonal handle, generous open lens |
| [filters.png](filters.png) | three parallel vertical slider tracks with large round controls at different positions |
| [guide.png](guide.png) | an open small guidebook with a simple lowercase information i in one page; the i is a symbol, no other text |
| [reference.png](reference.png) | one document sheet with a folded corner and a prominent bookmark ribbon |
| [ingredient.png](ingredient.png) | a simple culinary spoon crossing a short sprig with two leaves |
| [preparation.png](preparation.png) | a plain mixing bowl with one spoon and two simple steam curves |

[SHA-256 manifest](sha256.tsv) records the selected master files. The initially generated human-profile culture icon was replaced by the speech-bubble design above; it is not included in this set.

## Prompt set

For `all.png` and `study.png`, substitute the corresponding subject from the table into this exact template. The generation key for `study.png` was `studies`.

```text
Use case: logo-brand. Asset type: production web UI glyph, ${key} navigation. Create ONE original icon: ${subject}. A consistent calm research-library icon family: flat solid near-black #142b21 forms and thick rounded monoline strokes, no gradients, no shadows, no texture, no letters, no numbers, no background, no border or enclosing tile. Genuine transparent background. Centered square composition with generous equal transparent padding; symbol occupies 72% of width and height. Must stay clearly identifiable at 24 to 32 CSS pixels. Crisp clean edges and simple bold geometry, few details. Only the single requested symbol. This will be used as a CSS alpha mask; all meaningful visible marks must be opaque, negative space transparent.
```

For the other twelve files, substitute the file stem and corresponding table subject into this template. The final culture file used the generation key `culture`.

```text
Use case: logo-brand. Asset type: production web UI glyph, ${key}. Create ONE original icon: ${subject}. Match a calm research-library family: flat solid near-black #142b21 forms and thick rounded monoline strokes, generous open negative space. No gradients, no shadows, no texture, no decorative border, no enclosing tile. Genuine transparent background. Centered square composition with equal transparent padding, symbol occupying 72% of width and height. Must stay recognizable at 24 to 32 CSS pixels. Simple crisp bold geometry with very few details. Only the requested single symbol. No letters or numbers except the explicitly requested information i or question mark. Used as a CSS alpha mask: opaque visible marks and transparent negative space.
```
