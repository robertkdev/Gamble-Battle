# Roles Thresholds — Reference and Rationale

This document explains the metric thresholds used by the role_* identity tests,
how they are structured in `tests/rga_testing/metrics/roles/roles_thresholds.json`,
and what relaxations apply by scenario.

Goals
- Centralize numeric thresholds (no magic numbers in code).
- Make intent clear so tuning and regressions are easy to track.
- Support scenario-specific relaxations (e.g., burst/peel windows).

Normalized targets (reference)
- Assumptions: team EHP = 100, team sustained DPS = 100, mirror fight ≈24s.
- EHP share, sustained DPS share, and burst share (first 4s = 100) by role:
  - Tank: EHP 30%, Sustained 6%, Burst 6%, Focus TTK ≈ 12s
  - Brawler: EHP 20%, Sustained 20%, Burst 16%, Focus TTK ≈ 8s
  - Marksman: EHP 15%, Sustained 30%, Burst 14%, Focus TTK ≈ 6s
  - Mage: EHP 10%, Sustained 24% (AOE-gated), Burst 30%, Focus TTK ≈ 5s
  - Assassin: EHP 10%, Sustained 16% (front-loaded), Burst 30%, Focus TTK ≈ 5s
  - Support: EHP 15%, Sustained 4%, Burst 4%, Focus TTK ≈ 7s

These appear in `roles_thresholds.json` under `targets.roles.*` for reporting and tuning context and may be used by future metrics. Existing role identity metrics continue to read their specific thresholds from `roles.*.metrics`.

File layout (JSON)
- Root keys: `roles`, `goals` (optional), `approaches` (optional)
- Each role entry has:
  - `k_of_n` (optional): `{ "k": int, "n": int }` when the role evaluates multiple conditions.
  - `metrics`: a dictionary of metric configs, described per role below.
  - `fallback` (optional): alternative requirements used when preferred kernels are not supported.

Scenario relaxations
- Any metric may specify `relaxations` per scenario label (`neutral`, `burst`, `peel`, `counter`, `kite`, ...):
  - `multiplier` (multiply the base requirement)
  - `offset` (additive adjustment)
  - `min_value` or `floor`, `max_value` or `ceil` (explicit caps)
  - Metric helpers resolve to the relaxed value transparently.

Role metrics
- Tank
  - `metrics.focus_survival_s` (preferred): minimum focused-survival time (per-unit kernel).
  - Fallbacks:
    - `fallback.time_alive_s`: minimum time alive when focus kernel unsupported.
    - Optional `fallback.soak_index_range`: [min, max] acceptable soak range.
- Brawler
  - `metrics.sustained_damage_rate.comparison`:
    - `median_multiplier` and/or `z_min` vs peers; leadership indicates sustained DPS.
  - `metrics.can_take_damage.composite_any`:
    - Any of: `focus_survival_s`, `hits_survived` (side average), with relaxations by scenario.
  - `fallback.all` (ordered): e.g., `time_alive_s`, `soak_index_range`.
- Marksman
  - `metrics.sustained_damage_rate.comparison`: leader multiplier/z.
  - `metrics.backline_zone_share` (preferred) with scenario relaxations; proxy via ranged presence when zones unsupported.
  - `metrics.team_damage_share` (auxiliary): used as additional evidence, not required.
  - k-of-n: typically `{ "k": 2, "n": 2 }` — sustained + positional presence required.
- Assassin
  - `metrics.first_backline_contact`:
    - `pass_fraction`: fraction of sims with rank-1 backline contact for side.
    - `time_s`: time bound for first contact (relaxed for peel scenarios).
- Mage
  - `metrics.periodicity.any`: one of `top_2s_damage_share`, `peak_over_mean` (per-side medians).
  - `metrics.frontline_first.time_window_s`: 0–4s emphasis via kernel; proxy via frontline-target share when kernel unsupported.
- Support
  - `metrics.buff_presence` (events): `events_per_ally_min` with `requires_events`.
  - `metrics.proxies.any`: `ehp_ratio` (healing+shield vs opp damage), and/or `peel_saves`.

Authoring tips
- Keep thresholds coarse and scenario labels minimal; prefer relaxations to hard per-scene values.
- Use per-cost overrides (`per_cost`) sparingly and leave gaps for interpolation.
- Test new thresholds under `RoleMatrixProbe` and keep the report as an artifact.
