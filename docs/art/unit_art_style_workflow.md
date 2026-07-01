# Gamble Battle Unit Art Style Workflow

This guide is the locked workflow for recreating existing Gamble Battle units and making new unit or gameplay assets that align with the current premium gothic direction.

It is intentionally stricter than a normal prompt note. Future runs should start from this document, `docs/art/unit_art_prompt_cases.json`, and the proof ledger at `docs/art/unit_art_proof_matrix.json`, then record any new accepted or rejected proof before claiming the workflow is stronger.

## Current Best Anchor

The current best Vellum direction is the primary style reference. Treat it as the ultimate reference unless the user explicitly replaces it:

- Raw style anchor: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_selected_raw.png`
- Main comparison: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_comparison.png`
- Best current cutout proof: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_final.png`
- Cutout method comparison: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_cleanliness_comparison.png`

Status: this anchor is the best direction, not a final live replacement. It is goth and close to the target, but the outfit can still hold more black-leather shine than desired. Future prompts must push dry, powder-matte, real-material surfaces harder than this anchor.

Reference hierarchy:

1. Vellum is the primary/ultimate style anchor for character rendering, detail richness, mood, and material language.
2. Paisley is a secondary contrast anchor: use her to prove brighter/stranger units can still sit in the same dry gothic style, not to dilute Vellum's mood.
3. The Vellum contract token is a material/detail proof for small non-character assets. It is slightly warmer and more parchment/beige dominant, so do not use it as the main character palette anchor.
4. Later accepted/current proofs are coverage examples for specific silhouette, material, or cutout risks. They are not equal global style anchors unless the user explicitly promotes them.

As the proof pool grows, do not average all passing images together. That muddies the target. Every future candidate must be checked side by side against Vellum first, then Paisley and any narrowly relevant proof examples.

The required comparison artifact is the Vellum-first side-by-side comparison: Vellum raw anchor beside the candidate at the same size before any broader pool scan. A candidate can pass a narrow silhouette/material test without becoming part of the main style target.

## Locked Art Target

Use this style target for every character unless the user explicitly changes direction:

- Western dark gothic fantasy board-game unit art.
- About 10 percent more grounded realism than the cartoon/comic passes.
- Premium tabletop miniature/card-painting finish, not anime, gacha, shiny splash art, or plastic mobile-game rendering.
- Dry, de-shined material language: powder-matte skin, velvet, heavy cloth, dull aged metal, parchment, soot, ink, matte gouache, dry brush, and blocky shadow shapes.
- Dramatic goth silhouette and mood, but not chaotic detail. At 96 px board scale the head, torso, hands, weapon/prop, and major magic shape must still read.
- Full-body centered figure on a flat solid safety-orange `#f84401` background when a cutout is needed.
- No floor, cast shadow, vignette, texture, smoke background, scenery, text, logo, watermark, or crop.

The important correction from the last Vellum loop is that more detail is not the same as less shine. If the character looks sweaty, oily, glossy, wet, plastic, lacquered, or like polished leather, regenerate the raw image. Do not try to fix surface gloss with alpha cleanup.

The 2026-06-30 style-drift audit added the opposite guardrail: less shine is not the same as less detail. Do not simplify the unit into smooth low-detail shapes just to remove gloss. The target is high-detail dry gothic illustration: Vellum and Paisley have layered fabric, parchment, dry edge wear, small occult material details, and hand-painted surface breakup without looking wet. Future candidates must match that richness, not only the darker palette.

## Hard Matte Gothic Gate

The Grint tank/weapon proof exposed a stricter failure mode: a raw can preserve the unit identity but still fail because it drifts into clean fantasy/cartoon rendering. This is a style failure even when the cutout works.

Reject the raw image before cutout if any of these are true:

- Armor or weapons read as polished bevels, shiny plate, bright specular dots, chrome, lacquer, or clean fantasy gear instead of dull dirty metal, chipped paint, soot, grime, and dry brushed gouache.
- The body reads as cartoon, comic-book, toy-like, cute, mobile-game, gacha, superhero, or over-rounded caricature rather than grounded adult gothic tabletop art.
- The lighting reads as glossy splash-art rim light, wet skin shine, cinematic bloom, or plastic contrast instead of low-sheen ambient light with broad heavy shadow.
- The surface finish looks airbrushed, smooth, rubbery, waxy, or freshly rendered instead of rough, dusty, matte, aged, and tactile.

For tanks and weapon-heavy units, preserve mass and props without making the armor shinier or more heroic. A correct Grint-like result should feel like a grimy battered gatekeeper miniature painted in matte gouache, not a clean fantasy riot knight.

## Style Range Anchors

Creep is the current horror-side anchor. The Google design doc lists him as a planned Assassin unit with Exile / Executioner traits and the Evesdropping ability: a lowest-health dash into rapid spinning strikes, unstoppable and damage-reduced while spinning, with Exile extending the spin and chaining to the next lowest-health enemy on takedown. The repo currently stores him at `data/other_units/other/creep.tres` as hidden/enemy-only, but art direction should treat him as a real planned unit, not a generic creep-wave monster. His original identity depends on a smooth oval alien face, black hollow eye sockets, smooth gray-blue alien skin, and black blade tendrils. Do not turn him into a ripped-apart corpse, flayed anatomy study, wet gore monster, or generic dead-flesh horror creature. Also do not stop at identity restoration: the Creep pass must look dry, chalky, absorptive, and low-sheen beside Vellum and Paisley. A smooth alien face with slick head/body highlights is still a style-gate failure.

Use Creep to prove that units can be creepy humanoid, demon, cursed, or body-horror figures while still staying readable and premium. Use Paisley as the contrast-side anchor: she can be brighter and stranger, but her contrast should sit inside the same dry gothic material rules rather than pulling the whole game into cartoon gloss. There is no accepted final Creep proof after the 2026-06-30 style-drift audit; `creep_vellum_primary_detail_refit_2026_06_30` is the current review candidate only, not a live replacement or global style anchor. `creep_smooth_alien_refit_2026_06_29` restored identity better but stayed too shiny/creature-concept, `creep_hard_matte_smooth_alien_refit_2026_06_30` reduced wetness but kept too much slick creature-sculpt anatomy and shiny tendril read, and `creep_smooth_alien_matte_match_refit_2026_06_30` restored smooth skin but became too under-detailed and simplified beside Vellum and Paisley.

## Required Inputs

For an existing character:

- Current source texture from `assets/units/<unit>.png`.
- Unit id, display name, and traits from `data/units/<unit>.tres` or an art-bearing planned/hidden unit resource such as `data/other_units/other/creep.tres`.
- The current best Vellum raw anchor above as the style reference.
- Any accepted prior generated proof for that unit, if one exists.

For a future character:

- Unit name and role fantasy.
- Traits or faction words.
- Shape language: tall/wide/small, weapon/prop, pose, magic motif.
- Board-readability priority: what must read at 96 px.
- Whether the output needs a transparent final sprite, a raw concept only, or both.

For non-character assets:

- Asset class: ability icon, trait emblem, item, prop, projectile, token, UI ornament, or board element.
- Required silhouette and size target.
- Whether it needs transparency.

## Prompt Contract

Start every character prompt from this contract, then add unit-specific identity:

```text
Create a full-body centered Gamble Battle unit character in western dark gothic fantasy board-game art, about 10 percent grounded realism, premium tabletop-card painting, dry powder-matte skin, de-shined velvet cloth, dull aged metal, parchment, soot, ink, matte gouache, dry brush, high-detail matte gothic illustration, layered fabric, parchment, and dry edge wear, hand-painted surface breakup, Vellum/Paisley anchor-level detail richness, heavy occlusion shadows, clean readable game-board silhouette, flat solid safety-orange #f84401 background, no text, logo, watermark.
```

Add the hard matte goth gate near the top for every unit, especially tanks and weapon-heavy units:

```text
Render with grim low-sheen gothic realism, grounded adult proportions, rough dry material texture, dull dirty metal, chipped paint, soot, grime, matte gouache, low-specular ambient light, and broad heavy shadow. Do not use cartoon/comic rendering, clean fantasy splash-art polish, toy-like proportions, bright specular highlights, smooth airbrushed armor, polished bevels, or heroic mobile-game lighting.
```

Add the anchor-detail gate before the final surface rule:

```text
Detail-richness rule: de-shining must preserve tactile dry detail, layered costume/material storytelling, small gothic accents, dry scratches, dust, worn edges, and hand-painted texture. Match Vellum/Paisley's high-detail dry gothic illustration quality, not just the darker palette. Do not simplify the unit into low-detail smooth shapes or a palette-only match.
```

Add identity after the contract:

```text
Preserve the existing unit identity: [name], [traits], [current silhouette and props]. Reinterpret the unit into the locked style without changing the recognizable pose, body type, main prop, or magic motif.
```

Add de-shine enforcement near the end:

```text
Surface rule: absolutely no sweaty skin, wet highlights, glossy leather, shiny latex, plastic skin, polished splash-art reflections, lacquered armor, or bright rim-light shine. Any highlight must look like dry paint on real cloth, parchment, dust, bone, or dull metal.
```

Add scale enforcement:

```text
Board-scale rule: keep detail grouped into large readable shapes; avoid confetti detail, tangled micro-straps, tiny background particles, and noisy floating fragments.
```

Negative prompt or avoid list:

```text
sweaty, glossy, shiny, wet, oily, plastic, latex, lacquered, polished leather, reflective armor, bright specular highlights, polished bevels, smooth airbrushed armor, cartoon, comic-book, toy-like proportions, clean fantasy render, heroic mobile-game lighting, anime, gacha, chibi, cute mascot, neon cyberpunk, mobile-game splash art, low-detail smooth creature model, over-smoothed simplified matte shapes, palette-only match, hyper-detailed chaos, busy background, textured background, floor shadow, cropped body, text, logo, watermark
```

Do not replace "flat solid safety-orange #f84401 background" with "orange backdrop" or "warm background." The exact flat color wording matters because textured or smoky backgrounds were the main cause of fringe and cutout damage.

## Existing Unit Recipes

Use `docs/art/unit_art_prompt_cases.json` as the canonical prompt pack. It currently includes first-pass recipes for:

- Vellum current best direction.
- Kythera, preserving the mummy-ribbon/Vindicator identity.
- Paisley, preserving bubbles and Kaleidoscope/Blessed identity while aging the style up.
- A generic future unit.
- A non-character ability/token asset.

When adding a unit, add one prompt case to the JSON first, run `tools/art/validate_unit_art_workflow_doc.py`, then generate. This makes prompt drift visible before spending generation time.

Visual proof log:

- `docs/art/unit_art_workflow_test_log_2026-06-29.md` records the first representative workflow tests for Kythera, Paisley, and a Vellum contract-mark token. Read it before changing the prompt contract because it captures the failure cases that shaped the current wording.
- `docs/art/unit_art_proof_matrix.json` is the machine-readable proof ledger. It records accepted/current candidates, rejected examples, artifact paths, coverage groups, remaining stress-test gaps, the next recommended unit, and each proof's `reference_role`. Update it whenever a proof is accepted, rejected, demoted, or promoted. The only global character anchor is the Vellum primary reference in `style_contract.reference_policy`; later proofs stay `narrow_proof_only`, `review_candidate_not_anchor`, or `negative_example` unless the user explicitly promotes them.
- `docs/art/unit_art_style_drift_audit_2026-06-30.md` records the correction that Vellum, Paisley, and the token remain the real style references; many later candidates match palette/cutout constraints but lose the anchor-level detail richness.
- `docs/art/unit_art_candidate_style_triage_2026-07-01.md` records the current candidate-pool triage against Vellum/Paisley/token metrics. It does not approve or reject by itself; it flags rows that need extra visual review before they can influence prompts or live assets.
- `docs/art/unit_art_workflow_completion_audit_2026-06-30.md` records the current conservative completion state. It is the quickest way to see which roster entries have accepted proofs, which are still current candidates, which have no visual proof, which asset classes remain under-proven, and why the larger goal should stay active.
- `docs/art/unit_art_review_queue_2026-06-30.md` records the current human-review queue. It puts Creep first as the next gate, lists candidate backlog entries, and defines approval/rejection criteria so a future agent does not have to infer the review decision from chat history.
- `docs/art/unit_art_future_agent_handoff.md` is the no-context continuation surface. Give this to a future agent first when the thread is compacted, interrupted, or resumed from a new session.
- `tools/art/apply_unit_art_review_decision.py` applies a user's approve/reject/request-revision decision to `docs/art/unit_art_proof_matrix.json`. Use it after human review instead of hand-editing the proof ledger. The helper can accept a current candidate as a narrow proof, reject it as a negative example, or keep it as a revision candidate, but it does not promote any proof into a global style anchor.
- `tools/art/build_unit_style_drift_audit.py` rebuilds the Vellum/Paisley/token comparison sheets, the required Vellum-first side-by-side comparison sheet, and foreground-detail metrics. Use it whenever a candidate is being promoted to a proof after the style-drift correction. The generated sheets and CSV include each proof's `reference_role` so passing images do not silently become equal anchors.
- `tools/art/build_unit_art_candidate_triage.py` rebuilds the candidate-pool triage from the foreground detail metrics. Use it after an all-current style audit so low-detail or low-contrast candidates do not quietly become prompt references.
- `tools/art/build_unit_art_review_queue.py` rebuilds the review queue from the proof ledger. Use it after changing a candidate status so the next human decision remains explicit.
- Current stress-test progression: Grint hardened the non-cartoon tank/metal gate, Creep hardened the smooth-alien horror identity gate but remains unresolved pending review of `creep_vellum_primary_detail_refit_2026_06_30`, Korath tested haloed/divine matte armor, Luna proved the bright support/caster palette can be translated into muted stained-glass gothic material, Morrak tested the long polearm/scythe plus huge blade board-scale risk after correcting a false mounted-horse identity lock, Teller tested thin contract/mogul silhouette plus formalwear gloss risk, Bo tested first-try large red-black demon-brute scale without wet monster skin or shiny lava drift, Axiom tested compact occult scholar scale without glossy-feather/cute-owl/generic-wizard drift, Volt tested attached hand-lightning without neon superhero or detached particle-confetti drift, Vykos tested pale/sanguine flesh without wet gore, shiny anatomy, or corpse-horror drift, Brute tested stone/bone guardian bulk without chrome armor, glossy wet rock, generic golem drift, or unreadable over-bulk, Bonko tested small wiry raider/oversized weapon scale without cute goblin, comedy mascot, sports-bat, polished cannon, or unreadable tiny-weapon drift, Hexeon tested time/blade energy without neon particle confetti, busy prism shards, glossy glass armor, or polished black latex body, Totem tested dry wood/nature guardian material without glossy varnished wood, toy totem, generic druid, foliage blob, chrome armor, or unreadable bark fringe, and Sari tested grayscale spectral tendrils without smoke-only, cute ghost, werewolf, glossy latex, hair-spaghetti, or unreadable tendril-cloud drift. Brute also proved that a tiny post-BiRefNet orange-clean step can be acceptable when it removes isolated safety-orange remnants without changing the unit. The Creep audit proved that smooth alien skin and low-sheen tendrils still need Vellum/Paisley-level dry micro-texture, occult material detail, and hand-painted richness; the current Creep review candidate tests that correction but is not approved yet. Hexeon proved that a compositionally correct raw still fails if black mineral skin reads glossy; require dry charcoal/chalk/gouache wording before accepting prismatic assassin units. Totem proved that cyan magical markings can stay bright enough to read while the bark remains dry and matte. Sari proved that grouped tendril hair and ghost arms can survive BiRefNet and 96 px board scale if the prompt rejects loose confetti wisps and smoke-only silhouettes. The next gate is human review of the Creep Vellum-primary detail candidate, not Veyra or broader roster expansion.

Full roster matrix:

- `docs/art/unit_art_roster_prompt_matrix.json` is the current identity-lock matrix for all 22 playable unit resources plus Creep, an art-bearing planned unit currently stored as a hidden/enemy-only resource at `data/other_units/other/creep.tres`. It records each unit's source image, traits, coverage group, visual identity, preserve list, drift risks, and prompt addendum. Use it when recreating older characters so the global style contract does not erase the original unit identity.
- `tools/art/build_unit_roster_prompt_packet.py` converts any matrix entry into a ready-to-use generation packet with the locked global style contract, unit preserve list, unit avoid list, default BiRefNet command, and acceptance checks. Use this for normal roster recreation rather than hand-assembling prompts from scratch.
- `tools/art/build_unit_roster_contact_sheet.py` renders the current roster/contact sheet used to check the matrix against the live sprites.
- `tools/art/build_unit_style_drift_audit.py --proof-id <proof_id> --output-dir <dir>` compares a candidate proof directly against the Vellum/Paisley/token references. Without `--proof-id`, it compares accepted/current narrow proofs against the anchors while keeping Paisley/token in the reference strip; add `--include-rejected` when reviewing failures.
- `tools/art/build_unit_art_workflow_completion_audit.py` builds the conservative completion audit from the roster matrix and proof ledger. Use it to see which roster entries have accepted proofs, which are only current candidates, which have no visual proof, which asset classes remain under-proven, and why the larger workflow goal is or is not complete.

## End-to-End Validation

Before handoff, run the repo-local art workflow validation runner:

```powershell
python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_<date>
```

The runner is intentionally repo-local and non-generative. It validates the workflow docs and proof policy, rebuilds all roster prompt packets, verifies that generated packets include the Vellum-first reference hierarchy, rebuilds all-current and focused style-drift audit sheets, verifies that the audit CSV keeps Vellum/Paisley/token as the only reference rows, rebuilds candidate style triage, compiles the art tools, and writes `workflow_validation_report.md`.

The runner does not launch Godot because this repo requires Godot execution through MCP only. After the runner passes, still run the appropriate MCP scene, usually `tests/rga_testing/validation/RoleMatrixProbe.tscn`, then inspect `get_debug_output()` and require `errors=[]`.

## Generation Review Loop

1. Generate the raw square image first. Keep the raw file even if the cutout fails.
2. Reject the raw image immediately if the skin or outfit reads sweaty, wet, glossy, shiny, plastic, latex, or polished.
3. Reject the raw image if the background is textured, smoky, scenic, shadowed, or not flat safety-orange.
4. Make a contact sheet at full size and board scale. Check 1024 px, 256 px, and 96 px readability.
5. Run or update the style-drift audit contact sheet when a candidate is meant to become a new proof. Compare it directly against Vellum first in the Vellum-first pairwise sheet, then Paisley and any narrowly relevant proof examples, for high-detail dry gothic richness, not just non-shiny palette match.
6. Rebuild candidate style triage after the all-current audit. If a candidate is flagged as high-risk, do not use it as prompt context until it survives human Vellum-first review.
7. Only after the raw image passes style review, run background removal.
8. Review the cutout on checker, black, white, and in a board-scale preview.
9. Do not replace `assets/units/*.png` until the raw and cutout both pass review and the user approves the swap.

## Background Removal Decision Tree

Use this with `docs/art/unit_art_pipeline_2026-06-28.md`.

Default for premium orange-backed unit art:

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input <raw.png> --output <cutout.png> --mask-output <mask.png> --review-output <review.png> --device cuda --input-size 1024 --feather 0.6 --defringe-orange --foreground-ml --despill-orange
```

Method guidance:

- Use BiRefNet with `--foreground-ml --despill-orange` first for Vellum-like complex units with hair, parchment, ribbons, bubbles, ink, fingers, or detached magic shapes.
- Use defringe-only as a comparison proof, not the preferred final, when orange spill remains but the cutout shape is good.
- Use connected-orange keying only when the background is a clean flat border-connected field and the foreground has few intentional orange fragments. It can damage parchment, wax, bubbles, fire, and fragmented magic.
- For Paisley-like detached bubbles or detached magic identity effects, first try to fix the prompt so the key effects physically touch or overlap the hands/body. If the raw is otherwise accepted but BiRefNet drops detached identity effects, create a connected-orange foreground mask and union it with the BiRefNet mask using `tools/art/combine_unit_alpha_masks.py`, then inspect for extra fragments at board scale.
- Use chroma key only as a control or emergency fallback. It contaminated the newer Vellum colors and is not the selected path for complex premium units.
- If every cutout method leaves fringe, fix the raw generation prompt first. A textured or smoky orange background is a generation failure, not an alpha problem.

The "perfected cutout approach" from the successful pass is not gone: it is the refined BiRefNet command with foreground estimation and focused orange despill. For the latest Vellum de-shine run, that approach beat defringe-only, global chroma key, connected-orange, hybrid clipping, and tightened-alpha variants.

## File Conventions

Use this folder pattern for a style test:

```text
outputs/art_pipeline/style_validation/<unit_or_asset>_<route>_<yyyy_mm_dd>/
```

Use these names inside the folder:

```text
<slug>_raw.png
<slug>_comparison.png
<slug>_cutout_birefnet_foregroundml_despill.png
<slug>_mask_birefnet_foregroundml_despill.png
<slug>_review_birefnet_foregroundml_despill.png
<slug>_board_preview.png
<slug>_notes.md
```

If a generated route is rejected, keep a short note with the failure reason. Do not overwrite rejected raws; they are useful negative examples.

## Acceptance Checklist

Raw image:

- The goth direction is present.
- The character is about 10 percent more real-life grounded than the cartoon pass.
- Skin is powder-matte or dry-painted, not sweaty.
- Clothing is cloth, velvet, parchment, bone, or dull metal, not glossy leather or latex.
- Highlights are sparse and dry, not wet rim-light shine.
- The source unit identity is still recognizable.
- The background is flat solid safety-orange `#f84401`.
- The full body fits in the square with no cropping.
- The board-scale read works at 96 px.

Cutout:

- No obvious orange fringe around hair, hands, weapon, ribbons, parchment, bubbles, or magic.
- No green/gray global chroma contamination.
- Intentional detached details are preserved when they matter to identity.
- Checker, black, and white previews all look acceptable.
- The board preview does not shrink the unit into unreadability.

Token or icon assets:

- Seals, wax, metal, gems, and ink are matte or chalky unless the user explicitly requests gloss.
- Markings are decorative abstract shapes only, not readable letters, numbers, or rune alphabets.
- The token reads at small icon scale without relying on tiny inscription detail.
- The output does not become a character portrait unless the case asks for one.

Handoff:

- Record accepted raw, selected cutout, review sheet, and failure notes.
- Update `docs/art/unit_art_proof_matrix.json` with status, coverage groups, artifact paths, and failure reason if rejected.
- Update `docs/art/unit_art_prompt_cases.json` if the wording changed.
- Run `tools/art/run_unit_art_workflow_validation.py`, then run the required Godot validation through MCP.
- Update the canonical brain for meaningful accepted or rejected decisions.

## Future Agent Quick Start

1. Read this file.
2. Read `docs/art/unit_art_pipeline_2026-06-28.md`.
3. Read `docs/art/unit_art_proof_matrix.json` to see accepted proofs, rejected traps, coverage gaps, and the next recommended stress test.
4. Open `docs/art/unit_art_roster_prompt_matrix.json` for existing or planned unit identity locks.
5. Generate a roster prompt packet with `python tools\art\build_unit_roster_prompt_packet.py --unit-id <unit_id> --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_<date>`.
6. For non-roster assets or new style routes, open `docs/art/unit_art_prompt_cases.json` and pick the closest reusable case.
7. Generate raw concepts from the packet without weakening the dry material and flat-orange rules.
8. Reject glossy or textured-background raws before cutout.
9. Run the refined BiRefNet cutout command.
10. Inspect the review sheet and board-scale preview before claiming success.
11. Run the style-drift audit for any candidate being promoted: `python tools\art\build_unit_style_drift_audit.py --proof-id <proof_id> --output-dir outputs\art_pipeline\style_validation\style_drift_audit_<date>_<unit>`. The resulting sheet must keep Vellum visually first and must not treat the growing pool of passing proofs as an averaged style target.
12. Apply the user's proof decision with `python tools\art\apply_unit_art_review_decision.py --proof-id <proof_id> --decision accept|reject|request_revision --reason "<reason>"` before handoff.
13. Run `python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_<date>` and the required MCP Godot validation before final handoff.

The style should drift less when the prompt keeps repeating dry material words. Do not replace them with generic quality boosters like "high detail," "cinematic," "beautiful lighting," "rendered," "sleek," "polished," or "ultra realistic." Those words tend to bring back shine.
