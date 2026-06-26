# RGA Accepted-Miss Residual Audit - 2026-06-26

Source checked: current repo state plus regenerated `user://identity_reports/*.json` and `outputs/audit_playtest/rga_accepted_misses_2026_06_25/`.

## Current State

`tests/rga_testing/tools/Export-AcceptedMisses.ps1` currently reports:

- `reports=22`
- `spans=3`
- `ramp_spans=0`
- `non_ramp_goal_ramp=0`

Both affected units still pass their aggregate role, primary goal, and assigned approach verdicts in the current report artifacts. The remaining rows are lower-level evidence gaps that survived the prior diagnostic cleanup passes.

## Resolved In This Pass

Teller's prior `goal_marksman_sustained_dps_team_damage_share` residual is now diagnostic, not an accepted miss. The 2026-06-26 all-unit smoke still records whole-fight team share at `0.20 / 0.25`, but it also records direct sustained-window proof with `goal_marksman_sustained_dps_sustained_3_10s_team_share=0.31 / 0.25` and `goal_marksman_sustained_dps_sustained_3_10s_rate=155.14 / 8.0`. `MarksmanSustainedWindowKernelProbe.tscn` guards the new `early_0_3s_*` and `sustained_3_10s_*` combat-pattern telemetry and verifies that sustained-window share plus rate can make burst-biased whole-fight damage share diagnostic with `alternate_sustained_window_evidence_satisfied`.

Hexeon's prior `a_first_frac` residual is now diagnostic, not an accepted miss. The current all-unit smoke still records the side-level opening proxy at `0.33 / 0.60`, but the same subject passes direct assassin access with `subject_first_backline_frac=1.00 / 0.60`, while `assassin.backline_elimination`, `access_backline`, `burst`, and `execute` all pass. `AssassinOpeningRoleProbe.tscn` now guards the subject-level path and verifies that a side-level `a_first_frac` miss is diagnostic with `alternate_subject_backline_evidence_satisfied` when the audited subject proves backline access.

## Residual Rows

| Unit | Row | Aggregate evidence that already passes | Current audit decision | Closure evidence needed |
| --- | --- | --- | --- | --- |
| Kythera | `goal_team_fortification_buff_uptime_targets` 0 / 1 | `tank.team_fortification` passes via team EHP per second and damage prevented per second; `damage_reduction` and `debuff` approaches pass. | Live kit/identity/context debt. Kythera is tagged for fortification but her current Siphon kit is self MR drain plus enemy debuff/mitigation, not source-owned ally buff/shield uptime. | Add or tune source-owned ally fortification telemetry, retag/re-goal Kythera after design review, or explicitly redefine the goal so debuff/mitigation fortification does not require ally buff uptime. |
| Totem | `goal_peel_carry_peel_saves` 0 / 1 | `support.peel_carry` passes through carry damage prevention, ally protection events/magnitude, CC immunity, cooldown trade, and threat draw; `peel`, `cc_immunity`, and `amp` approaches pass. | Live peel-save attribution debt. Direct protection is strong, but the explicit goal-level save proxy is still absent in the all-unit report. | Create or tune a carry-threat case where Totem earns direct goal-level peel-save attribution, or revise the goal if direct protection should fully replace save proxy evidence. |
| Totem | `goal_peel_carry_interrupt_events` 0 / 1 | Same Totem aggregate support evidence as above; cooldown and CC-immunity diagnostics are already demoted when alternate evidence proves the aggregate. | Live interrupt-context debt. The current all-unit threat context proves protection, but not an interruptible carry threat. | Add an interruptible carry-threat scenario or tune the ability/encounter so Totem can prove direct interrupt evidence. |

## Current Root-Cause Recheck

Rechecked on 2026-06-26 against the current generated reports under `user://identity_reports/*.json` and the matching unit/ability resources.

| Unit | Current report detail | Code/resource evidence | Audit implication |
| --- | --- | --- | --- |
| Kythera | `kythera.json` runs `burst`, `counterplay`, `fortify`, and `neutral`; the only failed span is `goal_team_fortification_buff_uptime_targets=0 / 1`. The same goal passes through team EHP per second `309.7 / 2.0` and damage prevented per second `265.5 / 1.0`, while `damage_reduction` and `debuff` approaches pass. | `data/identity/unit_identities/kythera_identity.tres` still declares `tank.team_fortification` with `damage_reduction` and `debuff`; `scripts/game/abilities/impls/kythera_siphon.gd` drains MR from the current enemy, deals scheduled tick damage, and permanently grants Kythera the siphoned MR. It does not source an ally buff/shield uptime event. | The residual is a kit/goal-shape mismatch unless the design says debuff/mitigation fortification can replace ally buff uptime. The current implementation fortifies through self durability and enemy debuffing, not source-owned ally buff uptime. |
| Totem | `totem.json` runs `neutral`, `peel`, and `threat`; the two failed spans are `goal_peel_carry_peel_saves=0 / 1` and `goal_peel_carry_interrupt_events=0 / 1`. The same goal passes carry damage prevention `2154 / 25`, ally protection events `283 / 1`, ally protection magnitude `7361 / 25`, CC-immunity applied `70 / 1`, cooldown trade `4.33s / 1.0`, and threat-draw casters `1 / 1`. | `data/identity/unit_identities/totem_identity.tres` still declares `support.peel_carry` with `peel`, `cc_immunity`, and `amp`; `scripts/game/abilities/impls/totem_cleanse.gd` cleanses, shields, grants CC immunity, amps an allied carry, and then damages Totem's target. It does not apply a Totem-owned interrupt/CC effect, and the report's derived team peel-save count stays at 0. | The residual is specific save/interrupt attribution debt. Totem's current kit proves protection strongly, but closing the two rows honestly requires a scenario/kit path that creates direct peel-save attribution and interrupt evidence, or a design decision that those narrower spans are not required for this support goal. |

## Live Design Source Cross-Check

Cross-checked on 2026-06-26 against the authenticated live Google design doc. The temporary plain-text download used for this narrow evidence check was removed after extraction.

| Unit | Live design source signal | Residual audit impact |
| --- | --- | --- |
| Kythera | The design doc defines Siphon as Magic Resist drain from the target plus permanent MR gain for Kythera. The `team_fortification` goal metrics call out team eHP/s through shield/DR uptime, fortification uptime, and damage prevented over mana/time. | The failed ally-buff uptime span is expected from the current kit shape. Closing this honestly needs an ally-fortification event path, a retag/goal review, or a formal decision that self durability plus enemy debuffing is valid team fortification for Kythera. |
| Totem | The design doc defines Cleanse as targeting the living ally who has dealt the most damage, cleansing debuffs, and damaging Totem's current target. The `peel_carry` goal metrics define peel saves as interrupts or displacements that prevent lethal damage. | The interrupt/save residuals are a real kit-vs-metric mismatch, not missing generic support proof. Close by adding cleanse-as-save instrumentation/scenario evidence, adding an actual interrupt/displacement path, or revising the goal contract for Totem. |

## Current Verification Refresh

Rechecked on 2026-06-26 after the live Main-flow capture checkpoint:

- `RoleMatrixProbe6v6Kythera.tscn`: `PASS`, `errors=[]`; expected-span checks preserved the current contract where team EHP/s and damage-prevention pass while `goal_team_fortification_buff_uptime_targets` fails.
- `RoleMatrixProbe6v6Totem.tscn`: `PASS`, `errors=[]`; expected-span checks preserved the current contract where ally protection events/magnitude and CC-immunity pass while goal-level peel-save and interrupt spans fail.
- `RoleMatrixSmoke.tscn`: `PASS (22 units)`, `errors=[]`; this restored the canonical all-unit `user://identity_reports/*.json` report set used by the export.
- `tests/rga_testing/tools/Export-AcceptedMisses.ps1`: `reports=22 spans=3 ramp_spans=0 non_ramp_goal_ramp=0`.
- `AcceptedMissGuardCoverageSmoke.tscn`: `PASS`, `errors=[]`, `gap_kinds=3 accepted_spans=3 mapped_gap_kinds=3`.

The refreshed evidence keeps the residuals in the same category: current product/design debt around Kythera's fortification proof shape and Totem's direct save/interrupt proof shape, not missing generic RGA coverage.

## Guard Coverage

Every remaining gap kind is mapped by `tests/rga_testing/validation/accepted_miss_guard_coverage_smoke.gd` to committed validation coverage:

- `peel_carry_goal_save_proxy_absent`: `TotemPeelCarryAcceptedMissProbe.tscn`, `SupportCarryThreatScenarioPackSmoke.tscn`, `RoleMatrixProbe6v6Totem.tscn`
- `peel_interrupt_context_absent`: `TotemPeelCarryAcceptedMissProbe.tscn`, `SupportCarryThreatScenarioPackSmoke.tscn`, `RoleMatrixProbe6v6Totem.tscn`
- `team_fortification_buff_uptime_absent`: `TeamFortificationBuffGoalProbe.tscn`, `TeamFortificationScenarioPackSmoke.tscn`, `RoleMatrixProbe6v6Kythera.tscn`

The same guard smoke also verifies the detail CSV contains only the exact current Kythera buff-uptime and Totem peel-save/interrupt residual rows, and checks that this document stays aligned with the regenerated export by naming each current gap kind, affected unit, and metric label.

## Audit Conclusion

The remaining accepted misses are not missing harness coverage. They are live content, scenario, threshold, or identity-definition debt. Do not close them by adding more generic fallback diagnostics unless the design source explicitly says the narrower span is optional for that unit or goal.
