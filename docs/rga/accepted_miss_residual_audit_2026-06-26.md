# RGA Accepted-Miss Residual Audit - 2026-06-26

Source checked: current repo state plus regenerated `user://identity_reports/*.json`, `outputs/audit_playtest/rga_accepted_misses_2026_06_25/`, and the local HEAD refresh export at `outputs/audit_playtest/rga_accepted_misses_2026_06_26_head_refresh/`.

## Current State

`tests/rga_testing/tools/Export-AcceptedMisses.ps1` currently reports:

- `reports=22`
- `spans=2`
- `ramp_spans=0`
- `non_ramp_goal_ramp=0`

The affected unit still passes its aggregate role, primary goal, and assigned approach verdicts in the current report artifacts. The remaining rows are lower-level evidence gaps that survived the prior diagnostic cleanup passes.

## Resolved In This Pass

Teller's prior `goal_marksman_sustained_dps_team_damage_share` residual is now diagnostic, not an accepted miss. The 2026-06-26 all-unit smoke still records whole-fight team share at `0.20 / 0.25`, but it also records direct sustained-window proof with `goal_marksman_sustained_dps_sustained_3_10s_team_share=0.31 / 0.25` and `goal_marksman_sustained_dps_sustained_3_10s_rate=155.14 / 8.0`. `MarksmanSustainedWindowKernelProbe.tscn` guards the new `early_0_3s_*` and `sustained_3_10s_*` combat-pattern telemetry and verifies that sustained-window share plus rate can make burst-biased whole-fight damage share diagnostic with `alternate_sustained_window_evidence_satisfied`.

Hexeon's prior `a_first_frac` residual is now diagnostic, not an accepted miss. The current all-unit smoke still records the side-level opening proxy at `0.33 / 0.60`, but the same subject passes direct assassin access with `subject_first_backline_frac=1.00 / 0.60`, while `assassin.backline_elimination`, `access_backline`, `burst`, and `execute` all pass. `AssassinOpeningRoleProbe.tscn` now guards the subject-level path and verifies that a side-level `a_first_frac` miss is diagnostic with `alternate_subject_backline_evidence_satisfied` when the audited subject proves backline access.

Kythera's prior `goal_team_fortification_buff_uptime_targets` residual is now passing, not an accepted miss. `goal_primary_test.gd` now treats source-owned same-team fortification telemetry as valid fortification-target uptime for `tank.team_fortification`, while preserving ally-to-other requirements for support amp/peel metrics. `TeamFortificationBuffGoalProbe.tscn` guards self/team fortification telemetry, `KytheraSiphonCanonicalStackProbe.tscn` proves Siphon emits real source-owned fortification records through the permanent MR stack, and `RoleMatrixProbe6v6Kythera.tscn` now expects the buff-uptime span to pass.

## Residual Rows

| Unit | Row | Aggregate evidence that already passes | Current audit decision | Closure evidence needed |
| --- | --- | --- | --- | --- |
| Totem | `goal_peel_carry_peel_saves` 0 / 1 | `support.peel_carry` passes through carry damage prevention, ally protection events/magnitude, CC immunity, cooldown trade, and threat draw; `peel`, `cc_immunity`, and `amp` approaches pass. | Live peel-save attribution debt. Direct protection is strong, but the explicit goal-level save proxy is still absent in the all-unit report. | Create or tune a carry-threat case where Totem earns direct goal-level peel-save attribution, or revise the goal if direct protection should fully replace save proxy evidence. |
| Totem | `goal_peel_carry_interrupt_events` 0 / 1 | Same Totem aggregate support evidence as above; cooldown and CC-immunity diagnostics are already demoted when alternate evidence proves the aggregate. | Live interrupt-context debt. The current all-unit threat context proves protection, but not an interruptible carry threat. | Add an interruptible carry-threat scenario or tune the ability/encounter so Totem can prove direct interrupt evidence. |

## Current Root-Cause Recheck

Rechecked on 2026-06-26 against the current generated reports under `user://identity_reports/*.json` and the matching unit/ability resources.

| Unit | Current report detail | Code/resource evidence | Audit implication |
| --- | --- | --- | --- |
| Totem | `totem.json` runs `neutral`, `peel`, and `threat`; the two failed spans are `goal_peel_carry_peel_saves=0 / 1` and `goal_peel_carry_interrupt_events=0 / 1`. The same goal passes carry damage prevention `2154 / 25`, ally protection events `283 / 1`, ally protection magnitude `7361 / 25`, CC-immunity applied `70 / 1`, cooldown trade `4.33s / 1.0`, and threat-draw casters `1 / 1`. | `data/identity/unit_identities/totem_identity.tres` still declares `support.peel_carry` with `peel`, `cc_immunity`, and `amp`; `scripts/game/abilities/impls/totem_cleanse.gd` cleanses, shields, grants CC immunity, amps an allied carry, and then damages Totem's target. `TotemCleanseLiveProbe.tscn` now verifies the real cast removes a carry debuff, emits source-owned cleanse/CC-immunity telemetry, passes aggregate support/peel consumers, and still emits no direct save/interrupt evidence. | The residual is specific save/interrupt attribution debt. Totem's current kit proves protection strongly, but closing the two rows honestly requires a scenario/kit path that creates direct peel-save attribution and interrupt evidence, or a design decision that those narrower spans are not required for this support goal. |

## Live Design Source Cross-Check

Cross-checked on 2026-06-26 against the authenticated live Google design doc. The temporary plain-text download used for this narrow evidence check was removed after extraction.

| Unit | Live design source signal | Residual audit impact |
| --- | --- | --- |
| Totem | The design doc defines Cleanse as targeting the living ally who has dealt the most damage, cleansing debuffs, and damaging Totem's current target. The `peel_carry` goal metrics define peel saves as interrupts or displacements that prevent lethal damage. | The interrupt/save residuals are a real kit-vs-metric mismatch, not missing generic support proof. Close by adding cleanse-as-save instrumentation/scenario evidence, adding an actual interrupt/displacement path, or revising the goal contract for Totem. |

## Current Verification Refresh

Rechecked on 2026-06-26 after the live Main-flow capture checkpoint:

- `TeamFortificationBuffGoalProbe.tscn`: `PASS`, `errors=[]`; same-team self/source-owned fortification telemetry now satisfies the fortification-target span while no-buff and buff-only controls keep the aggregate contract honest.
- `KytheraSiphonCanonicalStackProbe.tscn`: `PASS`, `errors=[]`; Siphon still consumes canonical Aegis stacks, drains MR, applies permanent MR to Kythera, and now records `fortification_targets=2` for the source-owned self fortification path.
- `RoleMatrixProbe6v6Kythera.tscn`: `PASS`, `errors=[]`; expected-span checks now require team EHP/s, damage-prevention, and `goal_team_fortification_buff_uptime_targets` to pass.
- `TotemCleanseLiveProbe.tscn`: `PASS`, `errors=[]`; real Cleanse removes the carry debuff, records source-owned cleanse and CC-immunity, passes direct support/peel consumers, and preserves the current no-save/no-interrupt residual shape.
- `RoleMatrixProbe6v6Totem.tscn`: `PASS`, `errors=[]`; expected-span checks preserved the current contract where ally protection events/magnitude and CC-immunity pass while goal-level peel-save and interrupt spans fail.
- `RoleMatrixSmoke.tscn`: `PASS (22 units)`, `errors=[]`; this restored the canonical all-unit `user://identity_reports/*.json` report set used by the export.
- `tests/rga_testing/tools/Export-AcceptedMisses.ps1`: `reports=22 spans=2 ramp_spans=0 non_ramp_goal_ramp=0`.
- `AcceptedMissGuardCoverageSmoke.tscn`: `PASS`, `errors=[]`, `gap_kinds=2 accepted_spans=2 mapped_gap_kinds=2`.

The refreshed evidence keeps the residuals in the same category: current product/design debt around Totem's direct save/interrupt proof shape, not missing generic RGA coverage.

Post production-clock all-starter checkpoint refresh on 2026-06-26, using local main base commit `82ec91a`, kept the same residual shape:

- `RoleMatrixSmoke.tscn`: `PASS (22 units)`, `errors=[]`.
- `tests/rga_testing/tools/Export-AcceptedMisses.ps1 -OutputDir outputs/audit_playtest/rga_accepted_misses_2026_06_26_head_refresh`: `reports=22 spans=2 ramp_spans=0 non_ramp_goal_ramp=0`.
- `AcceptedMissGuardCoverageSmoke.tscn`: `PASS`, `errors=[]`, `gap_kinds=2 accepted_spans=2 mapped_gap_kinds=2`.

The two exported accepted spans remain Totem `goal_peel_carry_peel_saves` and `goal_peel_carry_interrupt_events`; no new residual unit or gap kind was introduced by the production-clock Main-flow audit work.

Focused recheck on 2026-06-26 at local HEAD `6c7b761` kept the same conclusion:

- `RoleMatrixProbe6v6Totem.tscn`: `PASS`, `errors=[]`; expected-span checks still keep ally-protection and CC-immunity passing while goal-level peel-save and interrupt spans fail.
- `TotemCleanseLiveProbe.tscn`: `PASS`, `errors=[]`; real Cleanse removes the carry debuff and emits cleanse/CC-immunity support telemetry, but still records `cc_events=0`, `goal_save_failed=true`, and `goal_interrupt_failed=true`.
- `AcceptedMissGuardCoverageSmoke.tscn`: `PASS`, `errors=[]`, `gap_kinds=2 accepted_spans=2 mapped_gap_kinds=2`.

This refresh did not change the residual category: Totem's current kit proves direct protection, while the remaining direct save/interrupt proof still requires product/scenario tuning or a goal-contract decision.

## Guard Coverage

Every remaining gap kind is mapped by `tests/rga_testing/validation/accepted_miss_guard_coverage_smoke.gd` to committed validation coverage:

- `peel_carry_goal_save_proxy_absent`: `TotemCleanseLiveProbe.tscn`, `TotemPeelCarryAcceptedMissProbe.tscn`, `SupportCarryThreatScenarioPackSmoke.tscn`, `RoleMatrixProbe6v6Totem.tscn`
- `peel_interrupt_context_absent`: `TotemCleanseLiveProbe.tscn`, `TotemPeelCarryAcceptedMissProbe.tscn`, `SupportCarryThreatScenarioPackSmoke.tscn`, `RoleMatrixProbe6v6Totem.tscn`

The same guard smoke also verifies the detail CSV contains only the exact current Totem peel-save/interrupt residual rows, and checks that this document stays aligned with the regenerated export by naming each current gap kind, affected unit, and metric label.

## Audit Conclusion

The remaining accepted misses are not missing harness coverage. They are live Totem content, scenario, threshold, or identity-definition debt. Do not close them by adding more generic fallback diagnostics unless the design source explicitly says the narrower span is optional for that unit or goal.
