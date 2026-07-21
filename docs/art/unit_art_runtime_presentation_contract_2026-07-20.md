# Unit Art Runtime Presentation Contract - 2026-07-20

Status: active Phase 3 runtime-presentation contract. It does not approve or replace portrait artwork.

## Reference hierarchy

- Vellum remains the sole primary and ultimate character-style anchor.
- Paisley's accepted proof remains the secondary contrast anchor, not the averaged target and not an instruction to replace the live Paisley asset.
- Creep v5 is the approved live Creep and a narrow reference for dissociated smooth-alien horror. It does not demote Vellum or become a general secondary anchor.
- Other accepted proofs remain narrow process evidence. Current candidates remain review-only until the user explicitly approves a live promotion.

## Runtime presentation rule

Every player-facing portrait surface must use `scripts/ui/unit_art_presentation.gd` and `data/ui/unit_art_presentation_profiles.json`.

The presenter:

- keeps the exact live source PNG;
- derives a padded alpha-content region so mixed source canvases occupy UI frames consistently;
- preserves detached identity effects because the full non-zero-alpha extent participates in framing;
- uses centered aspect-preserving layout and neutral `Color.WHITE` portrait modulation;
- caches normalized textures so alpha-bound inspection is not repeated per frame;
- leaves team and faction recognition to external bases, rims, frames, labels, and lighting.

Do not recolor an entire portrait blue or red to communicate team. Do not hide style drift with contrast, saturation, outline, or opacity shaders. Runtime framing improves presentation consistency; it does not turn an unapproved portrait candidate into accepted art.

## Approval boundary

No Phase 3 runtime-presentation change authorizes copying a file from `outputs/art_pipeline/` into `assets/units/`, editing a live PNG, or changing `data/units/*.tres` portrait paths. The two legacy provenance files `korath (1).png` and `sari (3).png` are not live runtime references.

The live Creep asset must continue to match the approved v5 source unless the user explicitly reverses that decision. Totem v26, Repo v3, and the other current candidates remain unapproved.

## Visual acceptance

- All 51 playable profiles have a presentation profile and a resolving canonical sprite path.
- Raw and normalized portraits are inspected side by side at 96 px.
- Checker, black, white, and battlefield contexts preserve silhouette and detached identity effects.
- Starter selection, shop, bench/board, combat actors, inspection, and scoreboard surfaces share the same normalized framing.
- No portrait is clipped, unexpectedly recolored, or made dependent on ignored review outputs.
- A live asset hash audit proves presentation work did not alter portrait PNGs.

The full roster still needs human-reviewed art convergence over later phases. Passing this contract means the current art is presented consistently and safely, not that every portrait has reached Vellum-level authorship.
