# RGA Accepted-Miss Residual Audit - 2026-06-26

Source checked: current repo state plus regenerated `user://identity_reports/*.json` and `outputs/audit_playtest/rga_accepted_misses_2026_06_25/`.

## Current State

`tests/rga_testing/tools/Export-AcceptedMisses.ps1` currently reports:

- `reports=22`
- `spans=4`
- `ramp_spans=0`
- `non_ramp_goal_ramp=0`

All three affected units still pass their aggregate role, primary goal, and assigned approach verdicts in the current report artifacts. The remaining rows are lower-level evidence gaps that survived the prior diagnostic cleanup passes.

## Resolved In This Pass

Teller's prior `goal_marksman_sustained_dps_team_damage_share` residual is now diagnostic, not an accepted miss. The 2026-06-26 all-unit smoke still records whole-fight team share at `0.20 / 0.25`, but it also records direct sustained-window proof with `goal_marksman_sustained_dps_sustained_3_10s_team_share=0.31 / 0.25` and `goal_marksman_sustained_dps_sustained_3_10s_rate=155.14 / 8.0`. `MarksmanSustainedWindowKernelProbe.tscn` guards the new `early_0_3s_*` and `sustained_3_10s_*` combat-pattern telemetry and verifies that sustained-window share plus rate can make burst-biased whole-fight damage share diagnostic with `alternate_sustained_window_evidence_satisfied`.

## Residual Rows

| Unit | Row | Aggregate evidence that already passes | Current audit decision | Closure evidence needed |
| --- | --- | --- | --- | --- |
| Hexeon | `a_first_frac` 0.333 / 0.6 | `assassin.backline_elimination` passes through first action, kill count, and peak 1s DPS; `access_backline`, `burst`, and `execute` approaches pass. | Live opening-presence debt. Do not demote without design approval because the assassin role still wants stronger side-level early presence. | Tune opening access/scenario/threshold until the live all-unit report reaches the assassin opening target, or update the role expectation from the design source. |
| Kythera | `goal_team_fortification_buff_uptime_targets` 0 / 1 | `tank.team_fortification` passes via team EHP per second and damage prevented per second; `damage_reduction` and `debuff` approaches pass. | Live kit/identity/context debt. Kythera is tagged for fortification but her current Siphon kit is self MR drain plus enemy debuff/mitigation, not source-owned ally buff/shield uptime. | Add or tune source-owned ally fortification telemetry, retag/re-goal Kythera after design review, or explicitly redefine the goal so debuff/mitigation fortification does not require ally buff uptime. |
| Totem | `goal_peel_carry_peel_saves` 0 / 1 | `support.peel_carry` passes through carry damage prevention, ally protection events/magnitude, CC immunity, cooldown trade, and threat draw; `peel`, `cc_immunity`, and `amp` approaches pass. | Live peel-save attribution debt. Direct protection is strong, but the explicit goal-level save proxy is still absent in the all-unit report. | Create or tune a carry-threat case where Totem earns direct goal-level peel-save attribution, or revise the goal if direct protection should fully replace save proxy evidence. |
| Totem | `goal_peel_carry_interrupt_events` 0 / 1 | Same Totem aggregate support evidence as above; cooldown and CC-immunity diagnostics are already demoted when alternate evidence proves the aggregate. | Live interrupt-context debt. The current all-unit threat context proves protection, but not an interruptible carry threat. | Add an interruptible carry-threat scenario or tune the ability/encounter so Totem can prove direct interrupt evidence. |

## Current Root-Cause Recheck

Rechecked on 2026-06-26 against the current generated reports under `user://identity_reports/*.json` and the matching unit/ability resources.

| Unit | Current report detail | Code/resource evidence | Audit implication |
| --- | --- | --- | --- |
| Hexeon | `hexeon.json` runs `burst`, `counter`, and `neutral`; the only failed span is `a_first_frac=0.333 / 0.6`. Subject-level first backline access passes at `1.0 / 0.6`, and `assassin.backline_elimination` passes with first action `1.6s`, kill count `1`, and peak 1s DPS `268`. | `data/identity/unit_identities/hexeon_identity.tres` still declares `assassin.backline_elimination` with `access_backline`, `burst`, and `execute`; `scripts/game/abilities/impls/hexeon_prismatic_guillotine.gd` prioritizes backline enemies, blinks near the target, executes low-HP enemies, and can recast on execute. | The residual is not missing assassin/backline telemetry or execute proof. It is the side-level opening-presence threshold/scenario: Hexeon proves direct backline access when he acts, but the side-level first-action fraction remains below the assassin expectation. |
| Kythera | `kythera.json` runs `burst`, `counterplay`, `fortify`, and `neutral`; the only failed span is `goal_team_fortification_buff_uptime_targets=0 / 1`. The same goal passes through team EHP per second `309.7 / 2.0` and damage prevented per second `265.5 / 1.0`, while `damage_reduction` and `debuff` approaches pass. | `data/identity/unit_identities/kythera_identity.tres` still declares `tank.team_fortification` with `damage_reduction` and `debuff`; `scripts/game/abilities/impls/kythera_siphon.gd` drains MR from the current enemy, deals scheduled tick damage, and permanently grants Kythera the siphoned MR. It does not source an ally buff/shield uptime event. | The residual is a kit/goal-shape mismatch unless the design says debuff/mitigation fortification can replace ally buff uptime. The current implementation fortifies through self durability and enemy debuffing, not source-owned ally buff uptime. |
| Totem | `totem.json` runs `neutral`, `peel`, and `threat`; the two failed spans are `goal_peel_carry_peel_saves=0 / 1` and `goal_peel_carry_interrupt_events=0 / 1`. The same goal passes carry damage prevention `2154 / 25`, ally protection events `283 / 1`, ally protection magnitude `7361 / 25`, CC-immunity applied `70 / 1`, cooldown trade `4.33s / 1.0`, and threat-draw casters `1 / 1`. | `data/identity/unit_identities/totem_identity.tres` still declares `support.peel_carry` with `peel`, `cc_immunity`, and `amp`; `scripts/game/abilities/impls/totem_cleanse.gd` cleanses, shields, grants CC immunity, amps an allied carry, and then damages Totem's target. It does not apply a Totem-owned interrupt/CC effect, and the report's derived team peel-save count stays at 0. | The residual is specific save/interrupt attribution debt. Totem's current kit proves protection strongly, but closing the two rows honestly requires a scenario/kit path that creates direct peel-save attribution and interrupt evidence, or a design decision that those narrower spans are not required for this support goal. |

## Live Design Source Cross-Check

Cross-checked on 2026-06-26 against the authenticated live Google design doc. The temporary plain-text download used for this narrow evidence check was removed after extraction.

| Unit | Live design source signal | Residual audit impact |
| --- | --- | --- |
| Hexeon | The design doc defines Hexeon as a mage assassin whose Prismatic Guillotine blinks to the lowest-HP enemy, executes at threshold, can retarget/recast on execute, and gains brief damage reduction. The `backline_elimination` goal metrics prioritize TTK on carry from first contact, success within 5 seconds, escape after kill, and peel tools burned. | The design source supports the assassin/backline identity, but it does not make the side-level `a_first_frac` proxy the primary goal proof. Keep the residual open, but review whether the side-level opening-presence threshold should be tuned around subject-level access and TTK evidence. |
| Kythera | The design doc defines Siphon as Magic Resist drain from the target plus permanent MR gain for Kythera. The `team_fortification` goal metrics call out team eHP/s through shield/DR uptime, fortification uptime, and damage prevented over mana/time. | The failed ally-buff uptime span is expected from the current kit shape. Closing this honestly needs an ally-fortification event path, a retag/goal review, or a formal decision that self durability plus enemy debuffing is valid team fortification for Kythera. |
| Totem | The design doc defines Cleanse as targeting the living ally who has dealt the most damage, cleansing debuffs, and damaging Totem's current target. The `peel_carry` goal metrics define peel saves as interrupts or displacements that prevent lethal damage. | The interrupt/save residuals are a real kit-vs-metric mismatch, not missing generic support proof. Close by adding cleanse-as-save instrumentation/scenario evidence, adding an actual interrupt/displacement path, or revising the goal contract for Totem. |

## Guard Coverage

Every remaining gap kind is mapped by `tests/rga_testing/validation/accepted_miss_guard_coverage_smoke.gd` to committed validation coverage:

- `assassin_opening_presence_below_target`: `AssassinOpeningRoleProbe.tscn`, `AssassinOpeningScenarioPackSmoke.tscn`
- `peel_carry_goal_save_proxy_absent`: `TotemPeelCarryAcceptedMissProbe.tscn`, `SupportCarryThreatScenarioPackSmoke.tscn`
- `peel_interrupt_context_absent`: `TotemPeelCarryAcceptedMissProbe.tscn`, `SupportCarryThreatScenarioPackSmoke.tscn`
- `team_fortification_buff_uptime_absent`: `TeamFortificationBuffGoalProbe.tscn`, `TeamFortificationScenarioPackSmoke.tscn`

The same guard smoke also verifies this document stays aligned with the regenerated export by checking each current gap kind, affected unit, and metric label.

## Audit Conclusion

The remaining accepted misses are not missing harness coverage. They are live content, scenario, threshold, or identity-definition debt. Do not close them by adding more generic fallback diagnostics unless the design source explicitly says the narrower span is optional for that unit or goal.
