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
- `tests/perf/PerfCombatUiSignals.tscn` before actor value caching: `UnitActor.update_bars_calls=678`, `UnitActor.bar_apply_calls=678`, `UnitActor.bar_skip_calls=0`, `UnitActor.texture_refresh_calls=21`, `UnitActor.texture_load_attempts=21`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after actor value caching: similar short combat with `UnitActor.update_bars_calls=729`, `UnitActor.bar_apply_calls=29`, `UnitActor.bar_skip_calls=700`, `UnitActor.texture_refresh_calls=7`, `UnitActor.texture_skip_calls=14`, `UnitActor.texture_load_attempts=7`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after removing actor bar refresh from position sync: same short combat shape with `position_updated=159`, `UnitActor.update_bars_calls=48`, `UnitActor.bar_apply_calls=26`, `UnitActor.bar_skip_calls=22`, `UnitActor.texture_refresh_calls=7`, `UnitActor.texture_skip_calls=14`, `UnitActor.texture_load_attempts=7`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after adding actor position diagnostics but before signal-driven arena movement: same short combat shape with `position_updated=159`, `UnitActor.position_update_calls=2058`, `position_apply_calls=1970`, `position_skip_calls=88`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after signal-driven arena movement: same short combat shape with `position_updated=159`, `UnitActor.position_update_calls=159`, `position_apply_calls=159`, `position_skip_calls=0`, `UnitActor.update_bars_calls=48`, `bar_apply_calls=26`, `bar_skip_calls=22`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after UI refresh pass: `time_ms=441`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after actor value caching: `time_ms=408`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf6v6.tscn` after UI refresh pass: aggregate signature stayed `4480953857527108889:18`, inconsistent cases `0`, errors `[]`. The run was wall-time noisy (`total_ms=24740`) and should be interpreted as a determinism/regression check, not a new simulation-speed baseline.
- `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` after UI refresh pass: `PASS`, `failed=0`, `skipped=0`, `errors=0`, `wall_ms=10781`.
- `tests/perf/PerfSlotStrategy.tscn` baseline before exact-solver optimization:
  - count 6: `iterations=180`, `time_ms=2160`, signature `8275061979637129334`.
  - count 12: `iterations=24`, `time_ms=2925`, signature `3289842425429315166`.
  - count 18: `iterations=18`, `time_ms=95`, signature `7774132243377850894`.
  - count 24: `iterations=12`, `time_ms=180`, signature `9108547909708289276`.
  - total: `total_ms=5360`, aggregate signature `5330865502362346199`, errors `[]`.
- `tests/perf/PerfSlotStrategy.tscn` after exact-solver optimization:
  - count 6: `iterations=180`, `time_ms=137`, same signature `8275061979637129334`.
  - count 12: `iterations=24`, `time_ms=2153`, same signature `3289842425429315166`.
  - count 18: `iterations=18`, `time_ms=107`, same signature `7774132243377850894`.
  - count 24: `iterations=12`, `time_ms=169`, same signature `9108547909708289276`.
  - total: `total_ms=2566`, same aggregate signature `5330865502362346199`, errors `[]`.
- `tests/perf/PerfSlotStrategy.tscn` now reports repeated samples per case with median/p95/min/max. Latest sampled run kept aggregate signature `5330865502362346199`, errors `[]`: count 6 median `321ms` p95 `351ms`; count 12 median `5008ms` p95 `5154ms`; count 18 median `185ms` p95 `200ms`; count 24 median `254ms` p95 `275ms`; median total `5768ms`.
- Rejected slot-solver experiments: on-demand assignment-cost calculation preserved signatures but regressed total time to `27570ms`; DP-buffer reuse alone preserved signatures but did not beat the committed solver under the noisy current run. Keep the current cost-matrix + DP implementation until a stronger algorithmic change is proven by the repeated-sample benchmark.
- `tests/perf/PerfSlotStrategy.tscn` after exact bounded-DP pruning kept aggregate signature `5330865502362346199`, errors `[]`: count 6 median `67ms` p95 `72ms`; count 12 median `264ms` p95 `339ms`; count 18 median `86ms` p95 `118ms`; count 24 median `158ms` p95 `166ms`; median total `575ms`.
- A behavior-changing order-preserving matcher experiment was rejected: it cut median total to `371ms`, but changed the 18/24-attacker signatures and changed `Perf6v6` burst from signature `5578449822537178089:232` / aggregate `4480953857527108889:18` to burst `8234090816251820645:232` / aggregate `-7790542692891220099:18`.
- `tests/perf/Perf6v6.tscn` after slot-strategy optimization: aggregate signature stayed `4480953857527108889:18`, inconsistent cases `0`, errors `[]`, `total_ms=12507`.
- `tests/perf/Perf6v6.tscn` after exact bounded-DP pruning stayed stable with aggregate signature `4480953857527108889:18`, inconsistent cases `0`, errors `[]`, `total_ms=14567`.
- `tests/perf/PerfLargeBoard.tscn` after exact bounded-DP pruning stayed stable with aggregate signature `7144113503220431359:12`, inconsistent cases `0`, errors `[]`: 8v8 median `3230ms`, p95 `4252ms`; 12v12 median `3744ms`, p95 `4997ms`; total `16236ms`.
- `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` after exact bounded-DP pruning: `PASS`, `failed=0`, `skipped=0`, `errors=0`, `wall_ms=12320`.
- `tests/perf/Perf1v1.tscn` after exact bounded-DP pruning kept signature `-6199507685307107293:55`, `frames=901`, `time_ms=563`, errors `[]`.
- `tests/perf/Perf6v6.tscn` after arena target-resolver fast path stayed stable with aggregate signature `4480953857527108889:18`, inconsistent cases `0`, errors `[]`, `total_ms=14374`.
- `tests/perf/PerfLargeBoard.tscn` after arena target-resolver fast path stayed stable with aggregate signature `7144113503220431359:12`, inconsistent cases `0`, errors `[]`: 8v8 median `3157ms`, p95 `4110ms`; 12v12 median `3852ms`, p95 `4268ms`; total `15401ms`.
- `tests/perf/Perf1v1.tscn` after arena target-resolver fast path kept signature `-6199507685307107293:55`, `frames=901`, `time_ms=425`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after slot-strategy optimization: `time_ms=459`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` after slot-strategy optimization: `PASS`, `failed=0`, `skipped=0`, `errors=0`, `wall_ms=7358`.
- `tests/perf/PerfTextureUtils.tscn` after shared texture cache:
  - `texture_iterations=600`, `circle_iterations=600`, `time_ms=14`.
  - diagnostics: `texture_cache_size=1`, `circle_cache_size=1`, `try_load_requests=600`, `path_cache_hits=599`, `resource_load_attempts=1`, `file_load_attempts=0`, `circle_requests=600`, `circle_cache_hits=599`, `circle_generations=1`.
  - signature `3777858830557683578`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after shared texture cache: `time_ms=551`, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after shared texture cache still completed and reported the expected optimized refresh shape, but current dirty/uncommitted stage-progress UI work emitted loader errors for `res://assets/ui/stage_icons/*`. Treat that as unrelated validation contamination until the stage icon resources/imports are fixed or that work is reverted.
- `tests/perf/Perf1v1.tscn` after position-sync bar refresh removal: `time_ms=421`, then `483` after typed-signature cleanup, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/perf/Perf1v1.tscn` after signal-driven arena movement: `time_ms=382`, then `470` after typed cleanup, `frames=901`, same signature `-6199507685307107293:55`, errors `[]`.
- `tests/visual/CombatArenaBoundsSmoke.tscn` before bounds-only resync failed because engine arena bounds stayed at `[P: (360.0, 91.0), S: (754.0, 622.0)]` after the visible planning board settled to `[P: (360.0, 91.0), S: (420.0, 622.0)]`.
- `tests/visual/CombatArenaBoundsSmoke.tscn` after bounds-only resync prints `CombatArenaBoundsSmoke: OK`; the stale-bounds assertion is fixed, but the scene still reports dummy-renderer resource cleanup diagnostics at exit, so it is not an empty-error validation gate yet.
- `tests/perf/PerfCombatUiSignals.tscn` after bounds-only resync stayed clean with errors `[]`: `position_updated=159`, `UnitActor.position_update_calls=159`, `position_apply_calls=159`, `update_bars_calls=50`, `bar_apply_calls=28`, `bar_skip_calls=22`.
- `tests/perf/Perf1v1.tscn` after bounds-only resync kept signature `-6199507685307107293:55`, `frames=901`, `time_ms=440`, errors `[]`.
- `tests/visual/UIThemeSmoke.tscn` after the stage-progress icon loader and bounds-resync work passed with `UIThemeSmoke: OK`, errors `[]`.
- `tests/perf/PerfCombatUiSignals.tscn` after hidden unit-panel processing was disabled stayed clean with errors `[]`: same short-combat shape with `position_updated=159`, `UnitActor.position_update_calls=159`, `UnitActor.update_bars_calls=50`, and hidden `UnitPanel` diagnostics `dynamic_refresh_calls=0`, `dynamic_refresh_skips=0`.
- `tests/visual/StatsPanelClickSmoke.tscn` still prints `StatsPanelClickSmoke: OK` after unit-panel process gating. Explicit Main/CombatView teardown was added to the harness, but the scene still reports unchanged dummy-renderer cleanup diagnostics, so treat it as functional-only evidence rather than an empty-error gate.
- `tests/perf/PerfCombatUiSignals.tscn` after arena container bounds caching stayed clean with errors `[]`: same optimized short-combat shape with `position_updated=159`, `UnitActor.position_update_calls=159`, `UnitActor.position_apply_calls=159`, and hidden `UnitPanel` diagnostics `dynamic_refresh_calls=0`, `dynamic_refresh_skips=0`.
- `tests/visual/CombatArenaBoundsSmoke.tscn` after arena container bounds caching still prints `CombatArenaBoundsSmoke: OK`; dummy-renderer cleanup diagnostics remain unchanged, so the scene remains functional-only evidence rather than an empty-error gate.
- `tests/perf/PerfLargeBoard.tscn` after slot and cache work:
  - 8v8: `samples_per_case=2`, `median_ms=3108`, `p95_ms=4001`, `frames=901`, `sim_s=45.050000`, result `team_a`, alive `8:4`, signature `7184874536639686372:300`, consistent `true`.
  - 12v12: `samples_per_case=2`, `median_ms=3492`, `p95_ms=3523`, `frames=258`, `sim_s=12.900000`, result `team_a`, alive `12:0`, signature `3567836549670627538:428`, consistent `true`.
  - total: `total_ms=14136`, aggregate signature `7144113503220431359:12`, inconsistent cases `0`, errors `[]`.

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
  - Bounded grouped slot assignment: groups up to 12 attackers use exact bitmask DP, oversized groups use deterministic greedy fallback.
  - Prevents factorial spikes as board sizes or same-target piles grow.
  - Follow-up optimization removed the factorial exact solver and uses the exact bitmask DP path for all groups up to 12 attackers.
  - DP masks are cached by group size and DP working arrays are bulk-initialized to reduce repeated setup cost.
  - Exact bounded-DP pruning now skips base rotations whose row-min lower bound cannot beat the current best cost, and prunes DP states that cannot beat the same incumbent. This preserves previous assignment semantics while cutting the expensive 12-attacker measured case sharply.
- `scripts/game/combat/systems/target_controller.gd`
  - `resolver_for_arena()` now returns a live cached target directly when the stored target is still valid, falling back to the full `current_target()` path only for stale, missing, or dead targets.
  - This avoids per-frame movement resolver overhead from repeated target-array sync/recursion-guard work in the common live-target case.
- `tests/perf/PerfSlotStrategy.gd`
  - Upgraded the benchmark to repeated samples per case with median/p95/min/max reporting so solver changes are not judged from a single noisy timing sample.
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
- `scripts/ui/combat/unit_actor.gd`
  - Added diagnostics for arena actor bar and texture refreshes.
  - Caches actor bar value signatures so per-frame arena sync can keep moving actors while skipping unchanged ProgressBar/tick/visibility assignments.
  - Caches actor texture signatures so `set_unit()` plus immediate `set_size_px()` no longer reloads the same sprite texture.
  - Added actor position diagnostics and skips duplicate base screen-position applications.
- `scripts/ui/combat/arena_controller.gd`
  - Per-position arena sync now moves actors and updates visibility only.
  - Actor HP/mana/shield bars are updated by stat/team-stat signal handlers instead of every position sync.
  - Typed the arena view inputs and actor script reference while preserving the existing `UnitSlotView`/`UnitActor` contract.
- `scripts/ui/combat/arena_bridge.gd`
  - Connects to `CombatManager.position_updated` and applies movement only to the changed actor.
  - Keeps per-frame actor visibility refreshes and falls back to the old position-array polling path if engine position telemetry is unavailable.
  - Typed touched bridge locals and view inputs while preserving the existing arena setup behavior.
  - Resyncs engine movement bounds when the visible planning-board rect changes after UI layout settles, without rebuilding unit positions or reprime-targeting.
- `scripts/game/combat/movement/movement_state.gd`, `movement_service2.gd`, `movement_service.gd`, `combat_engine.gd`, and `scripts/combat_manager.gd`
  - Added a bounds-only arena update path so UI layout changes can update movement clamps without resetting positions, target state, or mentor-pairing inputs.
- `tests/visual/combat_arena_bounds_smoke.gd`
  - Explicitly tears down and frees the Main scene before quitting. Dummy renderer cleanup diagnostics still remain under MCP, but the stale-bounds assertion now passes.
- `scripts/ui/combat/arena_bridge.gd`
  - Caches the last synced arena container bounds and skips redundant per-frame layout property writes while bounds are unchanged.
  - Resets the cache on arena exit so future arena entries still initialize layout normally.
- `scripts/ui/combat/stats/unit_panel.gd` and `scripts/ui/combat/stats/stats_panel.gd`
  - Disabled hidden unit-detail panel `_process()` work by default; StatsPanel enables live unit refresh only while unit-detail mode is visible.
  - Added unit-panel diagnostics for live refresh calls/skips.
- `tests/perf/PerfCombatUiSignals.gd`
  - Reports hidden unit-panel refresh diagnostics alongside existing unit view, actor, and traits diagnostics.
- `tests/visual/stats_panel_click_smoke.gd`
  - Adds explicit Main/CombatView teardown before quitting; dummy-renderer cleanup diagnostics still remain under MCP.
- `scripts/util/texture_utils.gd`
  - Added shared caches for successfully loaded textures and generated circle fallback textures.
  - Added `clear_cache()` plus diagnostics counters/snapshot helpers.
  - Does not cache missing paths, so newly created/imported files can still become available without clearing a stale miss.
- `tests/perf/PerfTextureUtils.gd` / `tests/perf/PerfTextureUtils.tscn`
  - Added a focused cache benchmark covering repeated real texture loads and repeated generated fallback requests.
- `tests/perf/PerfLargeBoard.gd` / `tests/perf/PerfLargeBoard.tscn`
  - Added deterministic 8v8 and 12v12 stress coverage through the existing headless simulator.
  - Uses base telemetry only, repeated samples, deterministic signatures, and aggregate consistency checks.
- `tests/visual/combat_view_theme_playtest.gd`
  - Added explicit `CombatView` teardown/free on exit. The scene still reports renderer/resource cleanup errors under the MCP run, so it is not used as the clean validation source for this pass.

## Current Hotspots

1. Combat movement is the primary optimization surface.
   - `MovementService2._update_impl()` computes alive flags, target groups, slot maps, steering, avoidance, and collision resolution every simulation step.
   - The largest obvious per-frame buffer rebuilds are now handled, and the exact slot solver no longer uses factorial permutation search.
   - `SlotStrategy.assign_for_target()` still creates per-target dictionaries and result payloads; this is now a lower-priority cleanup than higher-level movement/position signal behavior unless larger-board stress coverage shows it dominates again.

2. Targeting does meaningful per-candidate scoring.
   - `Targeting.pick_by_priority()` walks live enemies and may score ally peel pressure and nearby units.
   - The `target_recheck_interval_s=0.35` throttle is important. Do not move this to per-frame retargeting.

3. Telemetry and UI signals are broad.
   - Combat emits position, target, hit, stat, and team-stat signals.
   - Headless base-only RGA now disables unused position/target telemetry.
   - Player-facing HUD refreshes now skip duplicate broad stat/team-stat repaints, arena actors skip unchanged bar/texture applications, and arena movement is applied from position signals instead of per-frame full-team polling.
   - `position_updated` still fires roughly 155 times in the short diagnostics combat, but the UI now applies those 159 events directly instead of issuing roughly 2058 actor position setter calls.
   - UI listeners should keep using diagnostics gates before further repaint or signal-throttling changes.

4. Simulation cadence is sensitive.
   - `delta_s=0.25` is much faster but changed signatures in the sweep.
   - Treat coarse stepping or adaptive stepping as experimental until it has matchup-level acceptance thresholds, not just timing wins.

## Recommended Next Optimizations

1. Clean up remaining dummy-renderer teardown diagnostics in `CombatArenaBoundsSmoke.tscn` if that scene must become a strict empty-error gate; its stale-bounds assertion now passes.
2. Consider engine-level `position_updated` coalescing only if telemetry consumers or visual profiling prove the remaining 159 events are material; the UI no longer polls every actor every frame.
3. Use `PerfLargeBoard.tscn` as the regression/stress gate before future movement changes above 6v6.
4. Profile remaining `SlotStrategy.assign_for_target()` result dictionary churn only if larger-board stress shows slot payload construction is still material.
5. Continue adaptive/coarse stepping only behind acceptance tests; `delta_s=0.25` changed signatures in the sweep.

## Guardrails

- Do not make `delta_s=0.25` or larger a default optimization without balance/RGA acceptance work.
- Preserve deterministic signatures for headless perf scenes when changing allocation, targeting, movement, or telemetry paths.
- Validate multi-unit behavior after combat hot-loop edits with `RoleMatrixProbe6v6.tscn` or a broader RGA smoke.
