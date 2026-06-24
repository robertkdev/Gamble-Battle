# RGA Validation — Entry Points

Run these scenes via MCP for headless validation and reports.

- Role Matrix Probe (per-unit orchestrator)
  - Scene: `tests/rga_testing/validation/RoleMatrixProbe.tscn`
  - Args (examples):
    - `-- unit_id=bonko` (minimal)
    - `-- unit_id=bonko scenario_packs_to_run=neutral,burst opponents_per_pack=1 max_sims=12`
    - `-- unit_id=bonko dump_json=1` (raw metric JSON)

- Full Probe 6v6 (subject-as-slot substitution)
  - Scene: `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn`
  - Default profile is wired for 6v6 with subject substituted into each role slot, 3 seeds per scenario, and `max_sims=12` for quick runs.
  - To adjust quickly via MCP before running:
    - Set repeats/seeds or cap sims: edit `RoleMatrixProbe` node props (e.g., `max_sims=18`, `repeats=3`).
  - Produces rows in a single file: `user://rga_out.jsonl` (overwritten each run), and a report at `user://identity_reports/<unit>.json`.
  - Targeted 6v6 scenes:
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Axiom.tscn` - support peel/sustain/amp.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Hexeon.tscn` - assassin access_backline/burst/execute.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Nyxa.tscn` - marksman long_range/ramp/aoe.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Paisley.tscn` - mage wombo/aoe/peel.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Faeling.tscn` - mage area_denial_zone/aoe/zone.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Volt.tscn` - mage pick_burst/burst/lockdown.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Grint.tscn` - tank engage/disrupt/damage_reduction.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Berebell.tscn` - brawler disrupt/reposition/sustain.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Repo.tscn` - tank lockdown/damage_reduction/burst.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Veyra.tscn` - tank damage_reduction/sustain/ramp.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Sari.tscn` - marksman long_range/ramp/on_hit_effect.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Kythera.tscn` - tank damage_reduction/debuff/sustain.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Korath.tscn` - tank damage_reduction/redirect/engage.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Teller.tscn` - marksman long_range/debuff/ramp.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Totem.tscn` - support peel/amp/cc_immunity.

- On-hit telemetry positive control
  - Scene: `tests/rga_testing/validation/OnHitProcProbe.tscn`
  - Fixed 6v6 team with two active Vindicator units; fails if the subject records no explicit `on_hit_proc` events.

- Disruption telemetry positive control
  - Scene: `tests/rga_testing/validation/DisruptionKernelProbe.tscn`
  - Directly drives `DerivedStatsAggregator` and fails if post-control forced reposition, target swap, formation break, or follow-up kill attribution is missing.

- DoT tick telemetry positive control
  - Scene: `tests/rga_testing/validation/DotTickKernelProbe.tscn`
  - Directly drives `CombatEngine.dot_tick_applied` plus a source-attributed DoT debuff and a synthetic neutral-vs-anti-DoT payload; fails if source-owned tick count, tick damage, touched targets, source duration, active uptime, target receipt, direct `approach_dot` evaluation, or anti-DoT scenario-delta spans are missing.

- Reset telemetry positive control
  - Scene: `tests/rga_testing/validation/ResetMechanicKernelProbe.tscn`
  - Directly drives `CombatEngine.reset_triggered`, paired post-reset hit events, and a synthetic neutral-vs-counter payload; fails if reset event count, chain length, reset timing, touched targets, post-first-reset impact, reset counter-scenario deltas, or direct `approach_reset_mechanic` evaluation is missing.

- Execute bonus telemetry positive control
  - Scene: `tests/rga_testing/validation/ExecuteBonusKernelProbe.tscn`
  - Directly drives `CombatEngine.execute_bonus_applied` and paired hit events; fails if execute bonus event count, bonus damage, bonus damage share, low-HP kill conversion, or direct `approach_execute` evaluation is missing.

- Hexeon live execute threshold positive control
  - Scene: `tests/rga_testing/validation/HexeonExecuteLiveProbe.tscn`
  - Runs Hexeon's real `Prismatic Guillotine` implementation in low-HP and above-threshold cases; fails if the low-HP target is not executed, the above-threshold target is executed, threshold compliance telemetry is wrong, or direct `approach_execute` evaluation does not consume the live evidence.

- Ramp state telemetry positive control
  - Scene: `tests/rga_testing/validation/RampStateKernelProbe.tscn`
  - Directly drives `CombatEngine.ramp_state_changed` and fails if ramp event count, max stacks, time-to-peak, peak/window duration, direct `approach_ramp`, or direct goal-level ramp consumption is missing.

- Mage sustained-DPS goal positive/negative control
  - Scene: `tests/rga_testing/validation/MageSustainedDpsGoalProbe.tscn`
  - Feeds `goal_primary` a direct sustained-magic positive case with DoT, zone, and ramp evidence plus an AoE-DPS-only negative case; fails if `mage.sustained_dps` accepts AoE-only damage without a direct sustained mechanism.

- Amp output telemetry positive control
  - Scene: `tests/rga_testing/validation/AmpOutputKernelProbe.tscn`
  - Applies a source-attributed damage amp to an ally, runs a real buffed projectile hit, and fails if source-owned output events, output delta, beneficiaries, direct `approach_amp`, or direct `support.team_amplification` goal consumption is missing.

- Untargetable telemetry positive control
  - Scene: `tests/rga_testing/validation/UntargetableKernelProbe.tscn`
  - Directly drives `CombatEngine.targetability_window` and `CombatEngine.targetability_threat_interaction`, and fails if untargetable frame share, key-threat dodge rate, cooldown trade, or direct `approach_untargetable` evaluation is missing.

- Cooldown-pressure telemetry positive control
  - Scene: `tests/rga_testing/validation/CooldownPressureKernelProbe.tscn`
  - Directly drives `CombatEngine.ability_committed` plus CC-immunity evidence, and fails if cooldowns forced, cooldown seconds, key cooldown count, threat-draw caster/ability diversity, key-threat share, trade efficiency, direct cooldown-quality spans, or direct `approach_cc_immunity` counter-cooldown evaluation is missing.

- Counterplay-pressure telemetry positive control
  - Scene: `tests/rga_testing/validation/CounterplayPressureKernelProbe.tscn`
  - Directly drives `CombatEngine.debuff_applied`, `CombatEngine.cc_taxed`, and `CombatEngine.cleanse_applied`; fails if forced-cleanse attribution, cleanse-bait rate, tenacity tax, direct `approach_lockdown`/`approach_debuff` counterplay spans, or synthetic cleanse/high-tenacity scenario-delta spans are missing.

- Totem live cleanse positive control
  - Scene: `tests/rga_testing/validation/TotemCleanseLiveProbe.tscn`
  - Runs Totem's real `Cleanse` implementation against a genuinely debuffed allied carry; fails if the debuff is not removed, source-owned cleanse/CC-immunity telemetry is missing, enemy cleanse-pressure attribution is missing, or direct `approach_peel`, `approach_cc_immunity`, `role_support_identity`, and `support.peel_carry` goal consumption do not pass.

- Redirect threat-swap telemetry positive control
  - Scene: `tests/rga_testing/validation/RedirectThreatKernelProbe.tscn`
  - Directly drives `CombatEngine.target_start`, `CombatEngine.target_end`, and `CombatEngine.redirect_semantic_applied`; fails if enemy focus starts, target swaps onto the subject, focus duration, explicit taunt/body-block/end-risk evidence, or direct `approach_redirect` evaluation is missing.

- Zone exposure telemetry positive control
  - Scene: `tests/rga_testing/validation/ZoneExposureKernelProbe.tscn`
  - Directly drives `CombatEngine.zone_exposure_applied`; fails if source-owned zone/hazard exposure events, unique targets, duration, damage, radius, direct `approach_zone`, or direct `mage.area_denial_zone` goal consumption is missing.

- Identity catalog coverage
  - Scene: `tests/rga_testing/validation/ApproachCatalogCoverage.tscn`
  - Loads every metric descriptor and fails if an `IdentityKeys.APPROACHES` entry lacks an `approach_*` metric or if a doc goal resource is missing.

- Role semantic catalog coverage
  - Scene: `tests/rga_testing/validation/RoleSemanticCatalogProbe.tscn`
  - Directly feeds all six role identity metrics synthetic positive and negative payloads; fails if any role cannot pass on purpose-built evidence, if an empty/control payload passes, or if the expected role span prefix is missing.

- Goal-primary semantic catalog coverage
  - Scene: `tests/rga_testing/validation/GoalPrimaryCatalogProbe.tscn`
  - Directly feeds `goal_primary` synthetic positive and negative payloads for all 22 Google-doc primary goals; fails if any mapped goal cannot pass on purpose-built evidence, if an empty/control payload passes, or if the expected goal span prefix is missing.

- Approach semantic catalog coverage
  - Scene: `tests/rga_testing/validation/ApproachSemanticCatalogProbe.tscn`
  - Directly feeds every Google-doc approach metric synthetic positive and negative payloads; fails if any approach cannot pass on purpose-built evidence, if an empty/control payload passes, or if the expected approach span prefix is missing.

- Quick sanity (wrapper)
  - Scene: `tests/rga_testing/validation/QuickProbe.tscn`
  - One unit (default: bonko), neutral scenarios, small run; prints PASS/FAIL and exits.

- RGA Testing main (pipeline + optional metrics)
  - Scene: `tests/rga_testing/RGATesting.tscn`
  - Pick a profile in the inspector (e.g., `rga_roles_derived`).

- CI smoke (optional)
  - Scene: `tests/rga_testing/ci/RoleMatrixSmoke.tscn` (attach `RoleMatrixSmoke.gd`)
  - Runs RoleMatrixProbe programmatically for 1 unit per role with minimal seeds; asserts report files exist.

Artifacts
- Telemetry rows: `user://rga_out.jsonl` (or configured `out_path` ending with .jsonl/.ndjson; file is cleared each run)
- Probe reports: `user://identity_reports/<unit>.json`

Notes
- Latest doc-vs-test comparison: `docs/rga/test_notes_2026-06-23.md`
- Role/goal/approach coverage matrix: `docs/rga/role_goal_approach_coverage_2026-06-23.md`
- Current doc-name approach metrics include `access_backline`, `long_range`, `peel`, `zone`, `sustain`, `damage_reduction`, `lockdown`, `burst`, `execute`, `aoe`, `ramp`, `disrupt`, `engage`, `reposition`, `amp`, `cc_immunity`, `debuff`, `on_hit_effect`, `redirect`, `dot`, `reset_mechanic`, and `untargetable`.
- All catalog approach tags have executable verdict paths and now have an all-approach semantic catalog gate. `RoleSemanticCatalogProbe.tscn` proves all six role identity metrics can pass on purpose-built evidence, reject an empty/control payload, and emit an expected role span. `ApproachSemanticCatalogProbe.tscn` proves each Google-doc approach metric can pass on purpose-built evidence, rejects an empty/control payload, and emits an expected approach span. Some live roster tags still fail for content reasons. `GoalPrimaryCatalogProbe.tscn` proves every Google-doc primary goal branch can pass on goal-specific evidence and rejects an empty/control payload. `zone` now prefers direct source-owned lingering-zone/hazard exposure, with `ZoneExposureKernelProbe.tscn` as the positive control; positioning occupancy remains only a fallback/diagnostic. Faeling is now tagged to `mage.area_denial_zone` and passes live `zone` plus direct area-denial goal checks through Eavesdropping spin exposure. `mage.sustained_dps` now requires damage share plus direct DoT, zone, ramp, or on-hit evidence, with `MageSustainedDpsGoalProbe.tscn` guarding against AoE-only false positives; no current mage primary identity owns that goal. Paisley and Volt were retagged away from `zone` after checking the Google Doc: Paisley's Bubbles is ally shielding plus split bubble damage, and Volt's Arc Lock is single-target damage plus stun, not persistent area denial. `redirect` now has direct absorb/redirect telemetry, enemy-focus/target-swap evidence, and explicit taunt/body-block/end-risk spans, with `RedirectThreatKernelProbe.tscn` as the positive control; current live Korath evidence proves the body-blocking redirect path from real diverted damage, and taunt-command/threat-swap submodes remain future live-kit coverage if assigned. Goal-level disruption now has direct post-control enemy response telemetry for target swaps, forced reposition, formation spread, and follow-up kills, with `DisruptionKernelProbe.tscn` as the positive control. `execute` now prefers direct execute bonus damage/share telemetry when current rows provide it, with `ExecuteBonusKernelProbe.tscn` as the signal positive control and `HexeonExecuteLiveProbe.tscn` as the live low-HP-vs-above-threshold guard. `ramp` now prefers direct stack/window state telemetry for both approach-level checks and ramp-bearing goals, with `RampStateKernelProbe.tscn` as the positive control. `dot` now prefers direct tick ownership and uptime/duration telemetry and exposes neutral-vs-anti-DoT scenario deltas when matching scenario labels are present, with `DotTickKernelProbe.tscn` as the positive control. `reset_mechanic` now prefers direct reset/recast telemetry plus post-first-reset impact and neutral-vs-counter scenario deltas when current rows provide them, with `ResetMechanicKernelProbe.tscn` as the positive control. `untargetable` now prefers direct targetability-window and threat-dodge telemetry when current rows provide it, with `UntargetableKernelProbe.tscn` as the positive control. `cooldown_pressure` now records committed ability responses targeted at a subject plus threat-draw diversity, key-threat share, and cooldown-trade efficiency, with `CooldownPressureKernelProbe.tscn` as the positive control. `counterplay_pressure` now records forced cleanses, cleanse-bait rate, tenacity tax, CC-immunity tax, and neutral-vs-cleanse/high-tenacity scenario deltas, with `CounterplayPressureKernelProbe.tscn` as the positive control.
- `amp` now exposes direct output-delta/events/beneficiary spans when `amp_output_applied` telemetry is present, with `AmpOutputKernelProbe.tscn` as the positive control. Latest live Axiom proves team amplification through source-attributed Pupil output lift, and latest live Totem proves the support peel-carry path through source-attributed ally shield, real debuff removal, CC-immunity, amp, and downstream output evidence; `TotemCleanseLiveProbe.tscn` guards the explicit debuffed-carry cleanse path.

Legacy
- See `../legacy/` for deprecated probes kept until parity is confirmed.
