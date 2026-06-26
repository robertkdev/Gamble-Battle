# RGA Validation — Entry Points

Run these scenes via MCP for headless validation and reports.

- Role Matrix Probe (per-unit orchestrator)
  - Scene: `tests/rga_testing/validation/RoleMatrixProbe.tscn`
  - Args (examples):
    - `-- unit_id=bonko` (minimal)
    - `-- unit_id=bonko scenario_packs_to_run=neutral,burst opponents_per_pack=1 max_sims=12`
    - `-- unit_id=bonko dump_json=1` (raw metric JSON)
  - Live counterplay scenarios: quick/full RoleMatrix runs now treat `counterplay`, `cleanse`, and `high_tenacity_cleanse` labels as response-pressure scenarios. Quick probes add a synthetic `shared.counterplay_response` pack when the label is requested; full 6v6 probes force Totem and Veyra into the opposing response shell. Non-counterplay quick metrics evaluate against baseline rows only, while `approach_debuff` and `approach_lockdown` evaluate against the combined baseline-plus-counterplay rows so scenario-delta evidence does not dilute unrelated engage/goal gates.

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

- Completed item effect registry smoke
  - Scene: `tests/rga_testing/validation/CompletedItemEffectRegistrySmoke.tscn`
  - Loads completed item resources and fails if any declared runtime effect lacks a registered `EffectRegistry` handler, or if a completed item declares an unsupported `stat_mods` key.

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

- Execute bonus approach accepted-miss probe
  - Scene: `tests/rga_testing/validation/ExecuteBonusApproachProbe.tscn`
  - Proves real Hexeon/Morrak `execute` approach rows can consume direct execute-bonus events, bonus damage share, low-HP kill conversion, and overkill guardrails. Low-share positive-bonus rows stay diagnostic when direct execute evidence proves the aggregate, while zero-bonus aggregate controls still preserve the failed bonus-share span.

- Hexeon live execute threshold positive control
  - Scene: `tests/rga_testing/validation/HexeonExecuteLiveProbe.tscn`
  - Runs Hexeon's real `Prismatic Guillotine` implementation in low-HP and above-threshold cases; fails if the low-HP target is not executed, the above-threshold target is executed, threshold compliance telemetry is wrong, or direct `approach_execute` evaluation does not consume the live evidence.

- Assassin opening role positive control
  - Scene: `tests/rga_testing/validation/AssassinOpeningRoleProbe.tscn`
  - Drives `CombatEngine.position_updated` through `BacklineAccessKernel`; fails unless the real Hexeon assassin role emits passing side-level `a_first_frac` and subject-level `subject_first_backline_frac` spans for early backline access, and rejects a late/access-losing control.

- Ramp state telemetry positive control
  - Scene: `tests/rga_testing/validation/RampStateKernelProbe.tscn`
  - Directly drives `CombatEngine.ramp_state_changed` and fails if ramp event count, max stacks, time-to-peak, peak/window duration, direct `approach_ramp`, or direct goal-level ramp consumption is missing.

- Ramp approach accepted-miss probe
  - Scene: `tests/rga_testing/validation/RampApproachProbe.tscn`
  - Proves real Sari/Veyra `ramp` approach rows can consume direct ramp-state events, max stacks, peak duration, and window duration. Also proves low stack-max rows stay diagnostic when ramp events plus peak/window duration already satisfy `approach_ramp`, while weak controls still fail.

- Veyra Harden canonical stack probe
  - Scene: `tests/rga_testing/validation/VeyraHardenCanonicalStackProbe.tscn`
  - Proves the scheduled Harden end effect consumes canonical `TraitKeys.AEGIS` stacks, not only the old `aegis_stacks` fallback, and applies the permanent max-HP stack.

- Kythera Siphon canonical stack probe
  - Scene: `tests/rga_testing/validation/KytheraSiphonCanonicalStackProbe.tscn`
  - Proves the real Siphon cast consumes canonical `TraitKeys.AEGIS` stacks for drain rate, executes scheduled tick/end events, drains target MR, and applies Kythera's permanent MR stack.

- Cashmere Ledger canonical stack probe
  - Scene: `tests/rga_testing/validation/CashmereLedgerCanonicalStackProbe.tscn`
  - Proves the real Arcane Ledger cast consumes canonical `TraitKeys.ARCANIST` stacks for damage scaling without relying on the old `arcanist_stacks` fallback.

- Paisley Bubbles canonical stack probe
  - Scene: `tests/rga_testing/validation/PaisleyBubblesCanonicalStackProbe.tscn`
  - Proves the real Bubbles cast consumes canonical `TraitKeys.KALEIDOSCOPE` and `TraitKeys.ARCANIST` stacks for both low-HP ally shielding and split magic damage without relying on old stack-key fallbacks.

- Morrak Reaping Line canonical stack probe
  - Scene: `tests/rga_testing/validation/MorrakReapingLineCanonicalStackProbe.tscn`
  - Proves the real Reaping Line cast consumes canonical `TraitKeys.STRIKER` and `TraitKeys.EXECUTIONER` stacks for line damage scaling and the low-HP execute threshold without relying on old stack-key fallbacks.

- Hexeon Guillotine canonical stack probe
  - Scene: `tests/rga_testing/validation/HexeonGuillotineCanonicalStackProbe.tscn`
  - Proves the real Prismatic Guillotine cast consumes canonical `TraitKeys.KALEIDOSCOPE` stacks for damage scaling and canonical `TraitKeys.EXECUTIONER` stacks for the low-HP execute threshold without relying on old stack-key fallbacks.

- Bonko empower contract probe
  - Scene: `tests/rga_testing/validation/BonkoEmpowerContractProbe.tscn`
  - Proves the current Bonk cast applies the Bonko empower tag with the expected hit count, damage/heal/mana metadata, and direct ramp-state telemetry. Bonko no longer reads legacy Striker stack helpers in the cast path.

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

- Counterplay context triage smoke
  - Scene: `tests/rga_testing/validation/CounterplayContextTriageSmoke.tscn`
  - Synthetic counterplay guard for Brute, Volt, Grint, Kythera, and Sari; fails if the current debuff/lockdown counterplay spans stop passing when cleanse/high-tenacity response pressure is present.
  - The live RoleMatrix smoke now exercises this pressure for debuff/lockdown identities. The 2026-06-25 run confirmed Grint's `counterplay` scenario passes debuff scenario-delta spans without breaking `tank.initiate_fight`; low response-pressure rows on Kythera, Sari, Brute, and Volt are now diagnostic when direct debuff/lockdown evidence already satisfies the aggregate.

- Counterplay accepted-miss probe
  - Scene: `tests/rga_testing/validation/CounterplayAcceptedMissProbe.tscn`
  - Feeds Kythera/Sari debuff rows and Brute/Volt lockdown rows through their real approach metrics; fails unless response-pressure rows pass cleanse/high-tenacity spans, direct debuff/lockdown aggregate controls keep low response spans diagnostic while the approaches pass, and weak controls fail.

- Totem live cleanse positive control
  - Scene: `tests/rga_testing/validation/TotemCleanseLiveProbe.tscn`
  - Runs Totem's real `Cleanse` implementation against a genuinely debuffed allied carry; fails if the debuff is not removed, source-owned cleanse/CC-immunity telemetry is missing, enemy cleanse-pressure attribution is missing, or direct `approach_peel`, `approach_cc_immunity`, `role_support_identity`, and `support.peel_carry` goal consumption do not pass.

- Totem peel-carry accepted-miss probe
  - Scene: `tests/rga_testing/validation/TotemPeelCarryAcceptedMissProbe.tscn`
  - Feeds the real Totem identity through `approach_peel`, `approach_cc_immunity`, `role_support_identity`, and `support.peel_carry`; fails unless full team-save/EHP/CC-prevention/interrupt/cooldown evidence passes, direct-protection aggregate controls keep the current lower-level miss spans failing while the aggregate consumers pass, and a weak payload fails all consumers.

- Redirect threat-swap telemetry positive control
  - Scene: `tests/rga_testing/validation/RedirectThreatKernelProbe.tscn`
  - Directly drives `CombatEngine.target_start`, `CombatEngine.target_end`, and `CombatEngine.redirect_semantic_applied`; fails if enemy focus starts, target swaps onto the subject, focus duration, explicit taunt/body-block/end-risk evidence, or direct `approach_redirect` evaluation is missing.

- Korath redirect accepted-miss probe
  - Scene: `tests/rga_testing/validation/KorathRedirectAcceptedMissProbe.tscn`
  - Feeds the real Korath `redirect` approach direct target-swap, explicit threat-swap, and taunt evidence; fails unless those submode spans can pass, a direct body-block aggregate control keeps those missing submode spans diagnostic while `approach_redirect` passes, and a direct-supported weak payload fails even when proxy incoming-share evidence is present.

- Frontline body-block goal positive control
  - Scene: `tests/rga_testing/validation/FrontlineBodyBlockGoalProbe.tscn`
  - Directly drives `CombatEngine.damage_redirected` and `redirect_semantic_applied`; fails unless the real Brute `tank.frontline_absorb` goal consumes both direct body-block events and enough prevented damage, while event-only, damage-only, and weak-prevention controls fail.

- Brute frontline fallback diagnostic probe
  - Scene: `tests/rga_testing/validation/BruteFrontlineShareGoalProbe.tscn`
  - Feeds the real Brute `tank.frontline_absorb` goal direct incoming-share evidence; fails unless the damage-taken-share span can pass, an aggregate prevention-plus-frontline-position control keeps low damage-share and absent body-block spans diagnostic while the goal passes, and a weak frontline control fails.

- Grint engage-success goal accepted-miss probe
  - Scene: `tests/rga_testing/validation/GrintEngageSuccessGoalProbe.tscn`
  - Feeds the real Grint `tank.initiate_fight` goal direct engage-success evidence; fails unless the success-target span can pass, an aggregate distance-plus-first-action control keeps the success-target span failing while the goal passes, and a weak initiate control fails.

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

- Team-fortification buff goal positive control
  - Scene: `tests/rga_testing/validation/TeamFortificationBuffGoalProbe.tscn`
  - Directly drives `CombatEngine.buff_applied`; fails unless the real Kythera `tank.team_fortification` goal emits a passing ally-buff span when source-owned ally-buff telemetry is present, preserves an aggregate no-buff pass through EHP/prevention with a failed buff span, and rejects buff-only or weak controls.

- Skirmish-dive backline goal positive control
  - Scene: `tests/rga_testing/validation/SkirmishDiveBacklineGoalProbe.tscn`
  - Directly drives `CombatEngine.hit_applied` through `PerUnitKpisKernel`; fails unless the real Bo `brawler.skirmish_dive` goal emits a passing backline-contact span when most damage lands on an untagged backline target, and rejects an all-frontline control.

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

- Probe report compiler smoke
  - Scene: `tests/rga_testing/validation/ProbeReportCompilerSubjectSideSmoke.tscn`
  - Synthetic fast check that report diagnostics keep audited-side spans and exclude opponent-side aggregates such as `b_unit_pass_count`, suffix labels such as `magic_share_med_b`, and direct-attrition diagnostics for non-attrition brawler identities.

- Unit identity map doc smoke
  - Scene: `tests/rga_testing/validation/UnitIdentityMapDocSmoke.tscn`
  - Compares `docs/unit_identity_map.md` against current playable `UnitCatalog` identity metadata so stale role/goal/approach retags do not mislead audits.

- Goal primary ramp applicability smoke
  - Scene: `tests/rga_testing/validation/GoalPrimaryRampApplicabilitySmoke.tscn`
  - Ensures goal-level ramp diagnostics are emitted for ramp-tagged identities and skipped for non-ramp identities that pass the same primary goal through other assigned evidence.

- Probe report hard-peel applicability smoke
  - Scene: `tests/rga_testing/validation/ProbeReportCompilerHardPeelApplicabilitySmoke.tscn`
  - Ensures saved accepted-miss diagnostics keep cleanse/CC-immunity hard-peel subspans only for identities that claim `support.peel_carry` or `cc_immunity`, while preserving team peel-save scenario diagnostics for soft peel identities.

- Accepted-miss guard coverage smoke
  - Scene: `tests/rga_testing/validation/AcceptedMissGuardCoverageSmoke.tscn`
  - Reads the regenerated `outputs/audit_playtest/rga_accepted_misses_2026_06_25/accepted_gap_kind_summary.csv` and fails if the current 12 accepted-miss gap kinds are not each mapped to one or more validation scenes, or if the accepted span count is not 14. Regenerate the export with `tests/rga_testing/tools/Export-AcceptedMisses.ps1` before running this smoke.

- Peel team-save proxy probe
  - Scene: `tests/rga_testing/validation/PeelTeamSaveProxyProbe.tscn`
  - Proves one derived team peel-save passes the shared proxy path for `approach_peel`, `role_support_identity`, and `support.peel_carry`, and rejects a zero-save control payload.

- Soft-peel team-save accepted-miss probe
  - Scene: `tests/rga_testing/validation/SoftPeelTeamSaveAcceptedMissProbe.tscn`
  - Proves real Axiom/Paisley soft-peel rows can pass from direct team-save evidence, and keeps low team-save fallback spans diagnostic when ally-protection evidence already keeps the consumers passing.

- EHP ratio path probe
  - Scene: `tests/rga_testing/validation/EhpRatioPathProbe.tscn`
  - Proves EHP ratio pass paths for `approach_sustain`, `approach_peel`, support-role team EHP proxy, and support-role subject EHP diagnostic, and rejects weak controls.

- AoE targeting kernel probe
  - Scene: `tests/rga_testing/validation/AoeTargetingKernelProbe.tscn`
  - Proves grouped same-time hits record direct multi-target evidence for `targets_hit_median`, `max_targets_hit`, `multi_target_groups`, and `aoe_dps`, and that `approach_aoe` passes on that telemetry.

- AoE multi-target accepted-miss probe
  - Scene: `tests/rga_testing/validation/AoeMultiTargetApproachProbe.tscn`
  - Proves real Luna/Morrak/Nyxa/Paisley/Teller `aoe` approach rows can consume clustered same-time hit groups for a passing target-median span. Also preserves aggregate-pass controls where the same identities pass `approach_aoe` through max-target evidence while the median target span remains diagnostic.

- AoE clustered scenario probe
  - Scene: `tests/rga_testing/validation/AoeClusteredScenarioProbe.tscn`
  - Proves live clustered RoleMatrix contexts for Luna/Morrak/Nyxa/Paisley/Teller pass `approach_aoe` through direct max-target and/or AoE-DPS evidence while low all-hit median rows remain diagnostic.

- Brawler direct attrition probe
  - Scene: `tests/rga_testing/validation/BrawlerDirectAttritionProbe.tscn`
  - Proves `role_brawler_identity` can pass through direct attrition evidence when frontline damage share, sustain EHP, and pressure evidence are all present, including burst peak-DPS/share pressure, and rejects a weak negative payload.

- Burst window kernel probe
  - Scene: `tests/rga_testing/validation/BurstWindowKernelProbe.tscn`
  - Proves concentrated combat-pattern hits record direct `peak_1s_damage_share`, `peak_1s_dps`, overkill, and counterplay-window telemetry for `approach_burst`, rejects diffuse damage, and keeps low peak-share rows diagnostic when peak DPS already proves the burst approach.

- Pick-burst kill goal probe
  - Scene: `tests/rga_testing/validation/PickBurstKillGoalProbe.tscn`
  - Proves lethal combat-pattern hits feed `kill_count` into the real Cashmere `mage.pick_burst` goal span, while a nonlethal aggregate pass keeps the kill-count span failing and a diffuse control fails the goal.

- Wombo combo goal probe
  - Scene: `tests/rga_testing/validation/WomboComboGoalProbe.tscn`
  - Proves real Luna/Paisley `mage.wombo_combo_burst` goal rows consume direct combat-pattern peak-share and multi-target evidence plus control-mobility CC event evidence. Also preserves aggregate-pass controls where Luna's missing CC-sync proxy and Paisley's low peak-share span stay diagnostic when alternate Wombo evidence satisfies the 2-of-3 goal aggregate.

- Reposition movement kernel probe
  - Scene: `tests/rga_testing/validation/RepositionMovementKernelProbe.tscn`
  - Proves direct movement signals record `max_step_tiles`, `post_cast_displacement_tiles`, total path distance, and reposition steps for `approach_reposition`, keeps low max-step/post-cast rows diagnostic when alternate path-distance evidence satisfies the k-of-n approach, and rejects weak movement.

- Engage CC timing kernel probe
  - Scene: `tests/rga_testing/validation/EngageCcTimingKernelProbe.tscn`
  - Proves direct control-mobility signals record early displacement, first action, and first CC timing for `approach_engage`, keeps low or missing first-CC rows diagnostic when displacement plus first-action evidence satisfies the k-of-n engage approach, and rejects a weak no-engage control payload.

- Mage periodicity kernel probe
  - Scene: `tests/rga_testing/validation/MagePeriodicityKernelProbe.tscn`
  - Proves magic hit components record top-2s magic damage share and magic peak-over-mean for `role_mage_identity`, keeps low magic-share rows diagnostic when peak-over-mean already proves mage periodicity, and rejects diffuse magic damage.

- Marksman positioning role probe
  - Scene: `tests/rga_testing/validation/MarksmanPositioningRoleProbe.tscn`
  - Proves `role_marksman_identity` can pass through sustained DPS leadership plus direct backline/ranged positioning, emits low auxiliary candidate/subject damage-share rows and low side-backline rows as diagnostics when subject ranged/time-on-target evidence proves marksman positioning, and rejects weak marksman evidence.

- Marksman sustained-DPS goal probe
  - Scene: `tests/rga_testing/validation/MarksmanSustainedDpsGoalProbe.tscn`
  - Proves real Sari/Teller `marksman.sustained_dps` goal rows can consume direct team damage share, range/time-on-target, survival, and Sari ramp-state evidence. Also preserves aggregate-pass controls where Sari/Teller pass while team damage share is below target, and proves Sari's low ramp-stack span stays diagnostic when alternate ramp-state proof is enough.

Artifacts
- Telemetry rows: `user://rga_out.jsonl` (or configured `out_path` ending with .jsonl/.ndjson; file is cleared each run)
- Probe reports: `user://identity_reports/<unit>.json`
  - `diagnostics.lower_level_fail_spans` lists applicable subject-side role/goal/approach span misses that were accepted by aggregate verdicts, with `lower_level_fail_span_count` for backlog triage. Non-applicable goal ramp spans, soft-peel hard-peel subspans, auxiliary marksman role share spans, alternate marksman side-backline spans, and direct-attrition spans for non-attrition brawlers are suppressed from saved diagnostics.
  - Role, goal, and approach verdict objects also include `span_details` and `failed_span_count` for local inspection without parsing console logs.
- Accepted-miss export: run `tests/rga_testing/tools/Export-AcceptedMisses.ps1` from the repo root to regenerate the ignored `outputs/audit_playtest/rga_accepted_misses_2026_06_25/` CSV and JSON summary from current `user://identity_reports/*.json`. The row CSV includes `topic`, `audit_gap_kind`, and `audit_next_action` for every recognized accepted span, plus `support_peel_triage`, `support_peel_gap_kind`, and `support_peel_next_action` for the support/peel bucket. The generated `accepted_gap_kind_summary.csv` rolls those rows up by gap kind with counts, affected topics, units, labels, block types, and representative next action, and the generated README renders that rollup as a Markdown table. The JSON summary includes the same `audit_gap_kind_details` plus `primary_topic_counts`, `audit_gap_kind_counts`, `support_peel_triage_counts`, and `support_peel_gap_kind_counts`, so the backlog can be reviewed by scenario/content group and next tuning action instead of only by keyword.
- `AcceptedMissGuardCoverageSmoke.tscn` is the executable coverage manifest for the current accepted-miss audit state. It expects the regenerated summary to contain 12 gap kinds and 14 accepted spans, and it verifies every exported gap kind maps to committed validation-scene coverage.

Notes
- Latest doc-vs-test comparison: `docs/rga/test_notes_2026-06-23.md`
- Role/goal/approach coverage matrix: `docs/rga/role_goal_approach_coverage_2026-06-23.md`
- Current doc-name approach metrics include `access_backline`, `long_range`, `peel`, `zone`, `sustain`, `damage_reduction`, `lockdown`, `burst`, `execute`, `aoe`, `ramp`, `disrupt`, `engage`, `reposition`, `amp`, `cc_immunity`, `debuff`, `on_hit_effect`, `redirect`, `dot`, `reset_mechanic`, and `untargetable`.
- All catalog approach tags have executable verdict paths and now have an all-approach semantic catalog gate. `RoleSemanticCatalogProbe.tscn` proves all six role identity metrics can pass on purpose-built evidence, reject an empty/control payload, and emit an expected role span. `AssassinOpeningRoleProbe.tscn` specifically proves Hexeon's assassin role can pass side-level `a_first_frac` and subject-level `subject_first_backline_frac` from real `BacklineAccessKernel` position telemetry, so the current Hexeon opening-presence row is live opening-access scenario debt rather than missing metric support. `BrawlerDirectAttritionProbe.tscn` specifically proves the brawler role can pass through direct attrition evidence when frontline damage share, sustain EHP, and pressure evidence are all present, including burst peak-DPS/share pressure; direct-attrition diagnostics are now only saved for attrition-DPS brawlers, and Mortem is the remaining live direct-sustain attrition row. `MagePeriodicityKernelProbe.tscn` proves the mage role can pass through direct magic hit-component periodicity when top-window magic share and peak-over-mean evidence are present, and keeps low magic-share rows diagnostic when alternate peak-over-mean evidence proves mage identity. `MarksmanPositioningRoleProbe.tscn` proves the marksman role can pass through sustained DPS leadership plus backline/ranged presence while keeping team damage share and alternate side-backline rows diagnostic-only when subject ranged/time-on-target evidence proves positioning; current Sari/Teller sustained-DPS goal share rows are live output debt rather than missing metric support. `ApproachSemanticCatalogProbe.tscn` proves each Google-doc approach metric can pass on purpose-built evidence, rejects an empty/control payload, and emits an expected approach span. Some live roster tags still fail for content reasons. `GoalPrimaryCatalogProbe.tscn` proves every Google-doc primary goal branch can pass on purpose-built evidence and rejects an empty/control payload. `PeelTeamSaveProxyProbe.tscn` proves one derived team peel-save passes the shared proxy path for `approach_peel`, `role_support_identity`, and `support.peel_carry`, while `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves real Axiom/Paisley soft-peel rows can pass from team-save evidence and keeps low team-save fallback rows diagnostic when direct ally-protection/support evidence already proves the aggregate. Totem's goal-level peel-save row remains live peel-carry scenario debt. `EhpRatioPathProbe.tscn` proves EHP ratio paths for `approach_sustain`, `approach_peel`, support-role team EHP proxy, and support-role subject EHP diagnostic; low EHP fallback rows are now diagnostic when effective HPS, direct ally-protection, or support-event evidence already proves the aggregate, so the old Berebell/Vykos/Paisley/Totem/Axiom EHP accepted-miss group is closed. `burst` has direct combat-pattern peak-window telemetry for peak 1s share, peak 1s DPS, overkill, and counterplay timing, with `BurstWindowKernelProbe.tscn` as the positive control; low peak-share rows now remain diagnostic when peak DPS already proves the approach, so the old Berebell/Hexeon/Mortem/Vykos burst peak-share accepted-miss group is closed. `reposition` has direct control-mobility telemetry for max step, post-cast displacement, total path distance, and reposition steps, with `RepositionMovementKernelProbe.tscn` as the positive control; low max-step/post-cast rows now remain diagnostic when total path distance satisfies the k-of-n approach, so the old Berebell/Bo/Mortem reposition accepted-miss groups are closed. `engage` has direct control-mobility telemetry for early displacement, first action, and first CC timing, with `EngageCcTimingKernelProbe.tscn` as the positive control; low or missing first-CC rows now remain diagnostic when displacement plus first-action evidence satisfies the k-of-n approach, so the old Brute/Grint/Korath engage timing accepted-miss group is closed. `GrintEngageSuccessGoalProbe.tscn` proves Grint's initiate-fight goal can pass direct engage-success evidence while preserving the current low-success-target aggregate pass shape. `aoe` has direct grouped-hit telemetry for targets-hit median, max targets hit, multi-target groups, and AoE DPS, with `AoeTargetingKernelProbe.tscn` as the signal positive control, `AoeMultiTargetApproachProbe.tscn` proving low median becomes diagnostic when alternate max-target evidence satisfies the approach, and `AoeClusteredScenarioProbe.tscn` proving live Luna/Morrak/Nyxa/Paisley/Teller clustered contexts pass by direct max-target and/or AoE-DPS evidence. `zone` now prefers direct source-owned lingering-zone/hazard exposure, with `ZoneExposureKernelProbe.tscn` as the positive control; positioning occupancy remains only a fallback/diagnostic. Faeling is now tagged to `mage.area_denial_zone` and passes live `zone` plus direct area-denial goal checks through Eavesdropping spin exposure. `mage.sustained_dps` now requires damage share plus direct DoT, zone, ramp, or on-hit evidence, with `MageSustainedDpsGoalProbe.tscn` guarding against AoE-only false positives; no current mage primary identity owns that goal. Paisley and Volt were retagged away from `zone` after checking the Google Doc: Paisley's Bubbles is ally shielding plus split bubble damage, and Volt's Arc Lock is single-target damage plus stun, not persistent area denial. `redirect` now has direct absorb/redirect telemetry, enemy-focus/target-swap evidence, and explicit taunt/body-block/end-risk spans, with `RedirectThreatKernelProbe.tscn` as the positive control; current live Korath evidence proves the body-blocking redirect path from real diverted damage, and missing target-swap, taunt-command, and threat-swap submodes are diagnostic when body-block evidence already proves the aggregate. Goal-level disruption now has direct post-control enemy response telemetry for target swaps, forced reposition, formation spread, and follow-up kills, with `DisruptionKernelProbe.tscn` as the positive control. `execute` now prefers direct execute bonus damage/share telemetry when current rows provide it, with `ExecuteBonusKernelProbe.tscn` as the signal positive control, `HexeonExecuteLiveProbe.tscn` as the live low-HP-vs-above-threshold guard, and `ExecuteBonusApproachProbe.tscn` as the Hexeon/Morrak guard that keeps low bonus-share rows diagnostic when real bonus damage plus low-HP conversion proves execute while preserving zero-bonus failures. `ramp` now prefers direct stack/window state telemetry for both approach-level checks and ramp-bearing goals, with `RampStateKernelProbe.tscn` as the signal positive control, `RampApproachProbe.tscn` proving low approach stack rows stay diagnostic when ramp events plus peak/window duration prove the aggregate, and `MarksmanSustainedDpsGoalProbe.tscn` proving Sari's low goal ramp-stack row stays diagnostic under the same alternate ramp-state evidence. `dot` now prefers direct tick ownership and uptime/duration telemetry and exposes neutral-vs-anti-DoT scenario deltas when matching scenario labels are present, with `DotTickKernelProbe.tscn` as the positive control. `reset_mechanic` now prefers direct reset/recast telemetry plus post-first-reset impact and neutral-vs-counter scenario deltas when current rows provide them, with `ResetMechanicKernelProbe.tscn` as the positive control. `untargetable` now prefers direct targetability-window and threat-dodge telemetry when current rows provide it, with `UntargetableKernelProbe.tscn` as the positive control. `cooldown_pressure` now records committed ability responses targeted at a subject plus threat-draw diversity, key-threat share, and cooldown-trade efficiency, with `CooldownPressureKernelProbe.tscn` as the positive control. `counterplay_pressure` now records forced cleanses, cleanse-bait rate, tenacity tax, CC-immunity tax, and neutral-vs-cleanse/high-tenacity scenario deltas, with `CounterplayPressureKernelProbe.tscn` as the positive control.
- `PickBurstKillGoalProbe.tscn` proves lethal combat-pattern telemetry can feed the real Cashmere `mage.pick_burst` kill-count span, while the nonlethal aggregate pass keeps that span failing; current Cashmere/Volt pick-burst kill-count rows are live kill-securing/scenario debt rather than missing metric support.
- `TotemPeelCarryAcceptedMissProbe.tscn` proves real Totem `support.peel_carry` rows can pass all support/peel consumers with team-save, EHP, CC-prevention, interrupt, and cooldown evidence; it also preserves aggregate-pass controls where direct protection keeps the approach, role, and goal passing while goal team-save, CC-prevention, interrupt, and cooldown-efficiency spans remain below target and approach/role team-save plus low-EHP fallback rows stay diagnostic.
- `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves real Axiom/Paisley soft-peel rows can pass from team-save evidence; it also preserves aggregate-pass controls where Axiom's support role and Axiom/Paisley `approach_peel` keep passing through direct ally-protection evidence while low team-save fallback rows are diagnostic.
- `CounterplayAcceptedMissProbe.tscn` proves Kythera/Sari `debuff` and Brute/Volt `lockdown` rows can pass their response-pressure spans when cleanse/high-tenacity evidence is present; it also preserves aggregate-pass controls where direct debuff or lockdown evidence passes the approach while low cleanse-pressure, bait-rate, scenario-delta, and high-tenacity response rows remain diagnostic instead of accepted misses.
- `ExecuteBonusApproachProbe.tscn` proves real Hexeon/Morrak `execute` approach rows can pass on direct execute-bonus events, bonus share, low-HP kill conversion, and overkill guardrails; it also proves low bonus-share rows stay diagnostic when real bonus damage plus low-HP conversion proves execute, while zero-bonus aggregate controls still preserve a failed `subject_execute_bonus_damage_share` span.
- `RampApproachProbe.tscn` proves real Sari/Veyra `ramp` approach rows can pass on direct ramp-state events, full stack max, peak duration, and window duration; it also proves low `subject_ramp_stack_max` rows stay diagnostic when alternate ramp-state events plus peak/window duration prove the aggregate.
- `AoeMultiTargetApproachProbe.tscn` proves real Luna/Morrak/Nyxa/Paisley/Teller `aoe` approach rows can pass on clustered same-time hits with a passing target-median span; it also preserves aggregate-pass controls where the same identities pass while `subject_targets_hit_median` remains diagnostic. `AoeClusteredScenarioProbe.tscn` verifies the live clustered RoleMatrix contexts pass through direct max-target and/or AoE-DPS evidence with the all-hit median reported as diagnostic instead of a failed accepted span.
- `WomboComboGoalProbe.tscn` proves real Luna/Paisley `mage.wombo_combo_burst` goal rows can consume direct peak-share, multi-target, and CC-event evidence; it also preserves aggregate-pass controls where Luna passes without CC-sync and Paisley passes with a low peak-share span while the missing third evidence path is diagnostic rather than an accepted miss.
- `MarksmanSustainedDpsGoalProbe.tscn` proves real Sari/Teller `marksman.sustained_dps` goal rows can consume direct team damage share, range/time-on-target, survival, and Sari ramp-state evidence; it preserves aggregate-pass controls where Sari/Teller pass with low team damage share, and proves Sari's low ramp-stack span stays diagnostic when alternate ramp-state evidence proves the aggregate.
- `FrontlineBodyBlockGoalProbe.tscn` proves real redirect-kernel telemetry can feed Brute's `tank.frontline_absorb` body-block event and prevented-damage spans, while event-only, damage-only, and weak-prevention controls fail; low body-block rows are now diagnostic when alternate prevention plus frontline presence already proves the goal.
- `BruteFrontlineShareGoalProbe.tscn` proves Brute's `tank.frontline_absorb` damage-taken-share span can pass from direct incoming-share evidence; it also preserves an aggregate-pass control where prevention plus frontline presence pass the goal while low damage-share and absent body-block spans remain diagnostic.
- `KorathRedirectAcceptedMissProbe.tscn` proves Korath's `redirect` target-swap, explicit threat-swap, and taunt spans can pass from direct redirect evidence; it also preserves an aggregate-pass control where body-block evidence passes `approach_redirect` while those three missing submode spans remain diagnostic.
- `GrintEngageSuccessGoalProbe.tscn` proves Grint's `tank.initiate_fight` engage-success span can pass from direct success-target evidence; it also preserves an aggregate-pass control where engage distance plus first-action timing keep the goal passing while `goal_initiate_fight_engage_success_targets` remains below target.
- `TeamFortificationBuffGoalProbe.tscn` proves source-owned `buff_applied` telemetry can feed Kythera's `tank.team_fortification` ally-buff span, while an aggregate EHP/prevention pass still preserves the failed buff span when no ally buff is present; the current Kythera buff-uptime row is live fortification-context debt rather than missing metric support.
- `SkirmishDiveBacklineGoalProbe.tscn` proves per-unit hit attribution can feed Bo's `brawler.skirmish_dive` backline-contact span through `damage_to_frontline_pct`, while an all-frontline damage control fails; the current Bo dive-contact row is live backline-access scenario debt rather than missing metric support.
- `amp` now exposes direct output-delta/events/beneficiary spans when `amp_output_applied` telemetry is present, with `AmpOutputKernelProbe.tscn` as the positive control. Latest live Axiom proves team amplification through source-attributed Pupil output lift, and latest live Totem proves the support peel-carry path through source-attributed ally shield, real debuff removal, CC-immunity, amp, and downstream output evidence; `TotemCleanseLiveProbe.tscn` guards the explicit debuffed-carry cleanse path.

Legacy
- See `../legacy/` for deprecated probes kept until parity is confirmed.
