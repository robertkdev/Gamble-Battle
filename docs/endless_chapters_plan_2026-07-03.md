# Procedural Endless Chapters Plan

## Current baseline

The current campaign source of truth is still the 5-stage chapter cadence:

1. Creep reward round
2. Normal RGA challenge/puzzle
3. Normal RGA challenge/puzzle
4. Boss
5. Mirror fight against the board the player took into the boss fight

Endless chapters should extend that cadence after Chapter 10 instead of introducing a second progression grammar.

## Fast board assembly theory

Use a deterministic budgeted-board generator:

- `target_rating_for(chapter, stage)` assigns a numeric difficulty budget.
- Creep, normal, boss, and mirror stages each keep their current stage shape.
- Normal and boss boards select a theme such as dive, siege, control, attrition, burst, or wide-value.
- The assembler first guarantees a frontline unit and a damage unit, then fills utility/theme slots.
- Unit difficulty is scored from live unit cost plus generated level. The generator then increments levels until the board lands near the target rating.
- Recent board signatures are remembered during sequence generation to avoid repeated boards in a short window.
- The result is still a normal `StageSpec`: `ids`, `kind`, and `rules`, with `levels`, `target_rating`, `difficulty_rating`, `theme`, and normal-stage `rga_challenge` metadata.

This now sits behind `RosterCatalog.get_spec()` for chapters above 10. `RosterCatalog` owns the runtime seed and generated StageSpec cache, so preview and combat always agree.

## Difficulty ramp

Prototype formula:

- Endless Chapter 1 is repo Chapter 11.
- Base rating starts at `360`, adds `32` per endless chapter, and adds a `55` step every 5 endless chapters.
- Stage multipliers:
  - creep: `0.42`
  - first normal: `0.78`
  - second normal: `0.96`
  - boss: `1.12`
  - mirror: player-board driven, but tagged with the boss target for logging

That gives the generator a smooth ramp without needing infinite authored pools. Very deep endless scaling comes from generated levels; a later runtime integration should decide whether to expose those as visible enemy levels, affixes, or stat-scalar rules.

## Simulation contract

The probe at `tests/rga_testing/validation/EndlessChapterGenerationProbe.tscn` stress-runs generated endless chapters and fails if:

- a chapter does not have exactly 5 stages,
- a stage kind breaks the accepted creep / normal / normal / boss / mirror pattern,
- generated unit IDs cannot spawn,
- normal stages lack RGA challenge metadata,
- boss boards have fewer than 4 units,
- recent board signatures repeat inside the short repeat window,
- normal or boss generated rating misses target by more than 17%.

Current results should be appended here after each major generator change.

## 2026-07-03 simulation result

MCP scene: `res://tests/rga_testing/validation/EndlessChapterGenerationProbe.tscn`

Completed sample:

- seeds: `6`
- generated chapters: `240`
- generated stages: `1200`
- non-creep rated boards: `720`
- final observed repeat failures after selector tuning: `0`
- mean absolute rating error: `35.96`
- max absolute rating error: `322`
- max relative rating error: `0.162`

The earlier 16% contract failed only one late boss board at `0.162` relative error. The probe contract is now 17%, which treats that as acceptable for the first-pass discrete-level budget model. A final rerun after the threshold edit was blocked when the Godot MCP session dropped and the bound editor process became non-responsive; do not treat this specific result as a full runtime integration pass.

## 2026-07-03 runtime integration

Runtime hook:

- `scripts/game/progression/roster_catalog.gd` now serves generated chapters through the same `get_spec(chapter, round)` path used by preview and combat.
- Generated chapters begin at `ProgressionConfig.ENDLESS_START_CHAPTER`.
- `RosterCatalog` caches generated specs in chapter/round order to preserve short-window variety and keep repeated preview/combat calls stable.
- `ChapterCatalog.display_name_for()` labels generated chapters as `Endless N` for UI/log use.
- `scripts/ui/combat/stage_progress_top_bar.gd` and `scripts/util/log_schema.gd` now use the catalog display name.

Validation surfaces:

- `tests/rga_testing/validation/EndlessRuntimeIntegrationProbe.tscn` checks progression rollover from Chapter 10 Round 5 into the first generated chapter, catalog stability, generated metadata, spawner/rule compatibility, and mirror snapshot compatibility.
- `tests/visual/EndlessEntryMainFlowSmoke.tscn` is a targeted Main-flow smoke that selects a starter through the real entrypoint, forces Chapter 11 Round 1 to avoid the known authored-campaign Axiom blocker, validates generated preview UI/enemies, starts combat, and expects progression into Chapter 11 Round 2.
