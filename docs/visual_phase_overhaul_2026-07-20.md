# Visual Phase Overhaul

This pass implements the full visual review in two layers.

## Phase 1: validated hierarchy and readability

- Enlarge combat actors and shop portraits.
- Simplify starter selection and make committed selection persistent.
- Strengthen local combat focal contrast while preserving the dark world.
- Reclaim unused side-rail space for the board.
- Clarify the main-menu, wager, victory, and unit-inspection hierarchies.
- Standardize portrait staging, typography, spacing, and material semantics.

## Phase 2: juror challenge pass

- Audit brightness locally rather than applying a global exposure lift.
- Normalize portrait presentation without erasing intentional character variation.
- Validate responsive clipping and overlay behavior at compact and wide viewports.
- Reduce state-independent dead space while preserving intentional title atmosphere.
- Validate combat impact through event-synchronized temporal captures.
- Recheck current runtime fonts and assets instead of relying on older screenshots.

## Acceptance

The authoritative result is the player-facing Godot runtime. Structural maps may
diagnose control bounds, but cannot close typography, contrast, art cohesion, or
combat-impact findings. Final review must include menu, starter selection, shop,
combat, unit inspection, wager, and result states plus a combat temporal sheet.

## Shared visual tokens

`scripts/ui/gothic_ui_assets.gd` is the semantic source for the pass:

- Display 36, title 28, heading 20, body 16, metadata 14, microcopy 12.
- Spacing steps 4, 8, 12, 16, 24, and 32 pixels.
- Text, muted text, gold action, blood warning, player-blue, and enemy-red
  colors communicate meaning; texture choice must not replace those signals.
- Raised decision surfaces use the shared semantic surface helper. Decorative
  screens may keep bespoke framing, but body text and interaction states follow
  the same tokens.

This is deliberately a normalization layer, not a global theme replacement.
Portrait diversity and intentional dark negative space remain valid when crop,
contrast, and decision hierarchy pass the runtime review.

## Implemented runtime evidence

- Starter selection keeps a text-and-color committed marker while another unit
  is inspected; the preview panel no longer changes height between states.
- Compact 1280x720 and 1366x768 layouts use narrower side rails, a four-column
  item grid, compact metric labels, and 120x86 shop cards without clipped names,
  prices, or scoreboard headings.
- Combat actors, team rims, local hit rings, ability traces, and the arcane
  impact signature are stronger without globally lifting the scene exposure.
- The post-win intermission bar states the result and consequence before the
  normal planning layout returns. Defeat, stalemate, boss victory, and final
  run-loss states now have player-facing consequence evidence; boss victory
  explicitly states that the boss fell and the chapter cleared.
- Friendly and enemy unit inspection now presents `BASE > CURRENT (DELTA)`
  for the combat stat grid, making item, trait, and encounter changes auditable.
- Event-synchronized combat captures use `t000`, `t080`, and `t360` filenames;
  `outputs/visual_iter/attack_visuals_pass/temporal_manifest.json` records the
  same timing for all four signature groups plus strict 1280x720 and 1366x768
  arcane cells.
- The production system menu is captured over combat, unit inspection, and
  victory at both compact resolutions. Purchase denial/success and minimum,
  maximum, and locked wager states are also covered.
- `outputs/visual_iter/gothic_ui_asset_audit/identity_manifest.json` records all
  19 active Gothic textures, import/load/dimension status, fallback behavior,
  and the honest font policy: Godot default-theme font with semantic size roles.

Authoritative runtime checks passed: `UnitSelectPreviewVisualSmoke` (6 captures),
`CompactViewportVisualAuditSmoke` (13 captures),
`AttackVisualSignatureCapture` (4 groups / 2 compact sizes / 18 captures),
`PostCombatPlanningBeatSmoke` (5 captures), `ShopPurchaseFeedbackSmoke`
(2 captures), `BettingEconomySmoke`, `LossScreenSmoke`,
`UnitStatComparisonCapture`, `GothicUIAssetAudit`, and
`SystemMenuHoverStabilitySmoke`.

## Board disposition

The art-direction reviewer and UX/readability reviewer both returned Phase 1
and Phase 2 PASS after the persistent selection and temporal arc repairs. The
skeptical juror then re-audited the expanded result/decision matrix, compact
temporal cells, player-facing overlay states, and runtime identity manifest and
returned Phase 1 PASS / Phase 2 PASS with no acceptance blocker remaining.

## Phase 4: premium combat presentation

Phase 4 adds presentation-only weight to the existing combat simulation; damage,
targeting, projectile arrival, and round timing remain gameplay-authoritative.

- Combat portraits now sit on grounded contact shadows and use deterministic,
  asynchronous idle motion instead of moving in lockstep.
- Attack events drive a bounded anticipation, strike, and recovery pose. Exact
  projectile arrival drives directional hit recoil or a staged lethal collapse,
  and arena visibility waits for the death reaction to finish.
- Hit flashes follow the moving portrait while the impact ring remains grounded
  to the actor footprint.
- Blunt, cleave, precision, arcane, and support attacks use stable family profiles
  with different contact geometry, color, spread, and persistence. The renderer
  caps simultaneous impact accents so large fights remain legible.
- Victory, defeat, stalemate, and boss victory use a restrained cue-driven
  consequence ceremony. Its progress rail is part of the result card rather than
  a detached HUD element, and the normal planning layout is restored afterward.

Authoritative Phase 4 runtime checks passed: `CombatMotionPresentationSmoke`,
`CombatVfxReadabilitySmoke`, `AttackVisualSignatureCapture` (four attack groups,
two compact resolutions, 24 framebuffer captures), and
`PostCombatPlanningBeatSmoke` (six consequence captures), all with no Godot
errors. The final evidence packet is under
`outputs/visual_debug/vdh_runs/phase4-final-4/packet/`; source captures are under
`outputs/visual_iter/attack_visuals_pass/` and
`outputs/visual_iter/post_combat_planning_beat_pass/`.
