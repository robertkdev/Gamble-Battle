# Performance Audit - 2026-07-03

Scope: Godot 4.5 Gamble Battle runtime, focused on combat simulation and player-facing combat/UI paths.

## Evidence Collected

- `tests/perf/Perf1v1.tscn` baseline before changes: `time_ms=496`, `frames=901`, signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after allocation fixes: `time_ms=472`, `434`, `447`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after movement/telemetry pass: `time_ms=373`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf6v6.tscn` baseline before movement changes:
  - neutral: `median_ms=2975`, `p95_ms=3128`, `frames=514`, signature `-3997862279252171970:232`.
  - burst: `median_ms=2905`, `p95_ms=2980`, `frames=526`, signature `5578449822537178089:232`.
  - peel: `median_ms=2253`, `p95_ms=2472`, `frames=544`, signature `1121549412794869883:232`.
  - total: `total_ms=24211`, aggregate signature `4480953857527108889:18`, inconsistent cases `0`, errors `[]`.
- `tests/perf/Perf6v6.tscn` after movement/telemetry pass:
  - neutral: `median_ms=2599`, `p95_ms=2856`, `frames=514`, same signature `-3997862279252171970:232`.
  - burst: `median_ms=1987`, `p95_ms=2409`, `frames=526`, same signature `5578449822537178089:232`.
  - peel: `median_ms=2179`, `p95_ms=2393`, `frames=544`, same signature `1121549412794869883:232`.
  - total: `total_ms=20888`, same aggregate signature `4480953857527108889:18`, inconsistent cases `0`, errors `[]`.
- Partial `tests/perf/Perf1v1Sweep.tscn` showed `delta_s=0.05` variants preserved the baseline signature, while `delta_s=0.25` changed aggregate signatures. Coarser simulation steps are not safe as a default yet.
- `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` after changes: `PASS`, `failed=0`, `skipped=0`, `errors=0`, `wall_ms=10079`.
- `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` after movement/telemetry pass: `PASS`, `failed=0`, `skipped=0`, `errors=0`, `wall_ms=9757`.
- `tests/perf/PerfCombatUiSignals.tscn` before UI refresh gating: sampled combat had `team_stats_updated=6`, `stats_updated=8`, `unit_stat_changed=6`, `position_updated=155-157`, `UnitView.update_from_unit_calls=105`, `UnitView.bar_refresh_calls=114`, `UnitView.sprite_refresh_calls=9`, `UnitView.texture_load_attempts=9`, `TraitsPresenter.rebuild_calls=2`, `TraitsPresenter.rebuild_skips=5`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after UI refresh gating: same short combat shape with `team_stats_updated=6`, `stats_updated=8`, `unit_stat_changed=6`, `position_updated=155`, `UnitView.update_from_unit_calls=28`, `UnitView.bar_refresh_calls=37`, `UnitView.sprite_refresh_calls=9`, `UnitView.texture_load_attempts=9`, `TraitsPresenter.rebuild_calls=2`, `TraitsPresenter.rebuild_skips=5`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after UI refresh pass: `time_ms=441`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf6v6.tscn` after UI refresh pass: aggregate signature stayed `4480953857527108889:18`, inconsistent cases `0`, errors `[]`. The run was wall-time noisy (`total_ms=24740`) and should be interpreted as a determinism/regression check, not a new simulation-speed baseline.
- `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` after UI refresh pass: `PASS`, `failed=0`, `skipped=0`, `errors=0`, `wall_ms=10781`.

## Changes Made

- `tests/perf/Perf6v6.gd` / `tests/perf/Perf6v6.tscn`
  - Added a repeatable base-only 6v6 benchmark over representative neutral, burst, and peel boards.
  - Reports median, p95, min/max, frame count, deterministic per-case signatures, and an aggregate signature.
- `scripts/game/combat/systems/target_controller.gd`
  - Changed target-array synchronization from per-call rebuilds to in-place resizing.
  - This removes repeated hot-loop allocation from `current_target()`, which movement calls for every unit.
- `scripts/game/combat/systems/cooldown_scheduler.gd`
  - Changed cooldown-array synchronization from per-frame rebuilds to in-place resizing.
  - Avoids per-frame `Array[float]` allocation during `advance()`.
  - Avoids `slice()` allocation in `_order_for()` when order arrays already match team size.
- `scripts/game/combat/movement/movement_state.gd`
  - Changed integer capacity helpers to resize existing arrays in place instead of rebuilding slot/target memory arrays every frame.
- `scripts/game/combat/movement/collision_resolver.gd`
  - Reuses typed scratch buffers for combined positions, alive flags, step caps, and team/index tags.
  - Replaced nested per-unit tag arrays with parallel typed buffers.
- `scripts/game/combat/movement/movement_service2.gd`
  - Reuses per-frame alive, target, step-cap, group, and previous-slot scratch buffers across movement updates.
- `scripts/game/combat/movement/strategies/slot_strategy.gd`
  - Bounded grouped slot assignment: small groups keep exact permutation, medium groups use exact bitmask DP, oversized groups use deterministic greedy fallback.
  - Prevents factorial spikes as board sizes or same-target piles grow.
- `scripts/game/combat/combat_engine.gd` and `tests/rga_testing/core/lockstep_simulator.gd`
  - Added explicit position/target telemetry toggles.
  - Base-only headless jobs disable unused movement/target telemetry; role/UI-capable paths keep telemetry enabled.
- `tests/perf/PerfCombatUiSignals.gd` / `tests/perf/PerfCombatUiSignals.tscn`
  - Added a player-facing combat diagnostics scene that counts core combat/UI signals and diagnostic refresh counts for unit views and trait presentation.
- `scripts/ui/combat/unit_view.gd`
  - Split sprite refresh from bar refresh and caches the sprite path.
  - HP/mana updates no longer retry sprite texture loading when the unit identity and sprite path are unchanged.
  - Added diagnostics-only counters for `update_from_unit`, sprite refresh, bar refresh, and texture-load attempts.
- `scripts/ui/traits/traits_presenter.gd`
  - Added a board-trait signature so combat stat updates skip trait rebuilds when the team's trait composition is unchanged.
  - Added diagnostics-only counters for real rebuilds and skipped rebuilds.
- `scripts/ui/combat/controller/combat_controller.gd`
  - Added a compact HUD team snapshot signature.
  - Broad `stats_updated` / `team_stats_updated` handlers now skip duplicate full-HUD refreshes when targeted `unit_stat_changed` handlers have already repainted the changed unit bars.
- `tests/visual/combat_view_theme_playtest.gd`
  - Added explicit `CombatView` teardown/free on exit. The scene still reports renderer/resource cleanup errors under the MCP run, so it is not used as the clean validation source for this pass.

## Current Hotspots

1. Combat movement is the primary optimization surface.
   - `MovementService2._update_impl()` computes alive flags, target groups, slot maps, steering, avoidance, and collision resolution every simulation step.
   - The largest obvious per-frame buffer rebuilds are now handled, but `SlotStrategy.assign_for_target()` still creates per-target dictionaries and result payloads.

2. Targeting does meaningful per-candidate scoring.
   - `Targeting.pick_by_priority()` walks live enemies and may score ally peel pressure and nearby units.
   - The `target_recheck_interval_s=0.35` throttle is important. Do not move this to per-frame retargeting.

3. Telemetry and UI signals are broad.
   - Combat emits position, target, hit, stat, and team-stat signals.
   - Headless base-only RGA now disables unused position/target telemetry.
   - Player-facing HUD refreshes now skip duplicate broad stat/team-stat repaints, but `position_updated` still fires roughly 155 times in the short diagnostics combat.
   - UI listeners should keep using diagnostics gates before further repaint or signal-throttling changes.

4. Simulation cadence is sensitive.
   - `delta_s=0.25` is much faster but changed signatures in the sweep.
   - Treat coarse stepping or adaptive stepping as experimental until it has matchup-level acceptance thresholds, not just timing wins.

## Recommended Next Optimizations

1. Add actor-bar diagnostics to quantify remaining arena `UnitActor.update_bars()` churn and decide whether value-level bar caches are worthwhile.
2. Evaluate player-facing `position_updated` coalescing/throttling. Keep motion smoothness checks in the loop; this is a visual optimization, not just a signal-count target.
3. Add a small shared texture/fallback cache in `TextureUtils` if shop, stats panel, trait icon, or title/menu captures show repeated texture generation/load pressure.
4. Profile `SlotStrategy.assign_for_target()` result dictionary churn under larger or forced same-target boards.
5. Add larger-board stress coverage if the design will support more than 6v6, since worst-case movement/slot scaling is now bounded but not deeply tuned.
6. Continue adaptive/coarse stepping only behind acceptance tests; `delta_s=0.25` changed signatures in the sweep.

## Guardrails

- Do not make `delta_s=0.25` or larger a default optimization without balance/RGA acceptance work.
- Preserve deterministic signatures for headless perf scenes when changing allocation, targeting, movement, or telemetry paths.
- Validate multi-unit behavior after combat hot-loop edits with `RoleMatrixProbe6v6.tscn` or a broader RGA smoke.
