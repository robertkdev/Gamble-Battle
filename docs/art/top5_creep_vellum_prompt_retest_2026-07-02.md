# Top-5 Creep/Vellum Prompt Retest - 2026-07-02

## Scope

The user preferred Creep v5 over the Bloodborne/porcelain hybrid and asked to try the Creep/Vellum prompt approach on the current top-five unit-art examples:

1. Omenry
2. Juno Vale
3. Sable
4. Saffron
5. Orielle

These are research candidates only. They are not live replacements and are not accepted proofs.

## Files

- Review sheet with Creep v5 anchor: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/top5_creep_vellum_prompt_retest_sheet.png`
- 96 px board-scale sheet: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/top5_creep_vellum_prompt_retest_board96_sheet.png`
- Omenry: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/omenry_creep_vellum_prompt_v1_raw.png`
- Juno Vale: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/juno_vale_creep_vellum_prompt_v1_raw.png`
- Sable: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/sable_creep_vellum_prompt_v1_raw.png`
- Saffron: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/saffron_creep_vellum_prompt_v1_raw.png`
- Orielle: `outputs/art_pipeline/style_validation/top5_creep_vellum_prompt_retest_2026_07_02/orielle_creep_vellum_prompt_v1_raw.png`

## Telegram

- Sheet: `538`
- Omenry: `539`
- Juno Vale: `540`
- Sable: `541`
- Saffron: `542`
- Orielle: `543`
- 96 px board sheet: `544`

The first sheet send failed once as `sendPhoto` due a transient HTTP send error, then succeeded as `sendDocument`. The failed attempt did not produce a message id.

## Prompt Approach

Each unit was generated separately, not as a contact sheet. The goal was to preserve the top-five unit identity/archetype format while replacing the Bloodborne/porcelain pull with the darker Creep v5 plus Vellum-family gate.

Common prompt rules:

```text
Use Creep v5 plus Vellum-family matte gothic game-unit art.
Keep the unit's tragic occult job, signature props, and board-readable full-body silhouette.
Use dry, dark, nihilistic occult folklore; 10 percent more grounded realism than cartoon fantasy.
Use powder-matte skin, matte charcoal cloth, black waxed canvas, dry torn cloth, stained parchment, dull bone, soot, ink, tarnished metal, scuffed dull leather, and broad heavy shadows.
Reject sweaty skin, wet highlights, glossy leather, shiny latex, plastic skin, polished splash-art reflections, lacquered armor, reflective armor, bright specular highlights, chrome, porcelain doll/statue skin, clean Bloodborne polish, and theatrical cathedral glamour.
De-shining must preserve dry detail richness, layered material storytelling, scratches, dust, worn edges, stitching, cracks, grime, and hand-painted surface breakup.
Use flat #f84401 safety-orange background, no floor, no shadow, no text, no extra characters.
```

## Quick Raw-Field Check

All five raws have clean review-grade borders for future cutout testing. The 8 px border sample was `100.00%` within RGB distance 20 of #f84401 for all five.

| Unit | Dimensions | 8 px border mean RGB |
| --- | --- | --- |
| Omenry | 1023x1537 | `(247,63,0)` |
| Juno Vale | 1024x1536 | `(245,64,0)` |
| Sable | 1023x1537 | `(249,65,0)` |
| Saffron | 1024x1536 | `(248,59,0)` |
| Orielle | 1024x1536 | `(250,65,0)` |

This is not a full cutout audit.

## Art Read

The retest confirms the user's read: Creep v5 is a better north star than the porcelain hybrid for this darker direction. The new prompts reduce the porcelain/Bloodborne look across the top-five set, but they overcorrect by collapsing several humanoid units into a shared black-cloak, hood, parchment, and tarnished-trinket template.

Per-unit read:

- Omenry: best human fit from the retest. Darker, drier, and less porcelain than the prior top-five direction. Remaining risk is boot/rifle/leather edge shine and too much generic black-cloak density.
- Juno Vale: improved from the contact-sheet/matte-post origin because it is now a single-unit prompt with stronger occult-map identity. Remaining risk is that she looks too close to Omenry in silhouette and costume language.
- Sable: weakest identity result. Matte/dark improved, but Sable collapses toward Omenry as another black-cloaked rifle unit and loses the distinct ink-black scholar identity.
- Saffron: strongest overall candidate in this retest. The apothecary-priest identity survives, and the dry cloth/plague-healer read fits the world. Remaining risk is amber-bottle/glass gloss and some floating-object clutter.
- Orielle: darker than the porcelain set, but still too elegant/pale and less Creep-like. The debt-mage identity remains, but the face and pose still carry refined gothic aristocrat polish.

## Lesson

Do not simply apply the Creep/Vellum gate globally as a style paste. It fixes the porcelain/gloss problem, but it can erase unit-specific silhouette language.

Next prompt iteration should keep the hard Creep/Vellum material gate, then add stricter anti-convergence rules:

- Omenry: preserve oracle-gunner; okay to keep hood and feathers.
- Juno Vale: no rifle/hunter silhouette; make the star-map archivist readable through posture, map geometry, and scholar tools.
- Sable: no hooded prophet; make the ink-black rifle scholar compact, academic, and contract-marked rather than feathered or oracle-like.
- Saffron: keep apothecary-priest, but make amber glass dusty/dull and reduce floating clutter.
- Orielle: make the debt-mage more manipulative, tired, and materially dry; reduce porcelain face and noble glamour.

The result should combine Creep's simple horror identity lesson with Vellum's material/detail veto, while protecting each unit's unique role silhouette.
