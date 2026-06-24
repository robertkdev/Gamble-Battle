# Role Matrix Probe — MVP Design

Purpose
- Provide a single, reproducible entry point that evaluates one subject unit across curated, role‑targeted scenarios and emits clear per‑role verdicts (PASS/LEAN/FAIL) with concise, numeric reasons.

Scope (MVP)
- One subject per run; focused scenario matrix per role (diagnostic, not exhaustive).
- Deterministic headless runs with a small seed sweep to stabilize medians.
- Console summary plus JSON report artifact suitable for diffing and post‑hoc analysis.

Inputs
- `unit_id: String` — subject unit resource id or key; resolves to its `UnitProfile`.
- `profile: Dictionary` — optional snapshot override for identity fields (role/goal/approaches/cost/level); default pulled from catalog at load time.
- `seeds: PackedInt32Array` — explicit seeds; if empty, generate default sweep (6–8 seeds).
- Optional knobs (exposed via exported props on runner):
  - `roles_to_run: Array[String]` — subset of roles to evaluate (e.g., ["Tank", "Marksman"]).
  - `scenario_packs_to_run: Array[String]` — named scenario packs to include per role.
  - `max_sims: int` — global cap to bound runtime.
  - `include_swapped: bool` — also run A/B side swap sampling (off by default).
  - `max_opponents: int` — per‑scenario opponent count cap to limit team sizes.
  - `repeats: int` — repeat a scenario+seed tuple for variance checks (default 1).

Scenario Packs (per role)
- Defined in `tests/rga_testing/config/role_scenarios.gd` (or JSON) as small, high‑signal packs:
  - Tank/Brawler: neutral, burst, peel; start: front.
  - Marksman: kite/poke, open field, backline start; start: back.
  - Assassin: dive, counter; emphasize time window; start: flexible.
  - Mage: periodicity‑friendly, mixed lanes.
  - Support: peel present; optional buff events.
- Each scenario pack entry specifies: `label`, map params, subject starting lane (front/back), tactical intents, and any required caps.
- Scheduling rule (MVP): Only schedule scenarios relevant to the role under evaluation.

Team Shells
- Library in `tests/rga_testing/validation/team_shells.gd` provides light structure to fire kernels and reduce noise:
  - `subject + peel_tank`
  - `subject + healer`
  - `subject + diver`
  - neutral filler combinations
- Support selection via `role_filter`, avoid pairing subject with itself, sizes: 1v1 / 2v2 / 3v3.

Opponent Selection
- Selectors in `tests/rga_testing/validation/opponent_selectors.gd`:
  - Balanced opponent set (by roles)
  - Counter set (stress subject)
  - Light set (confidence check)
- Pick N per scenario pack (configurable); sample without replacement; avoid duplicate subjects.

Seed Strategy and Determinism
- Default 6–8 seeds; engine determinism toggles enabled.
- Persist `run_id`, `sim_index`, and `seeds` in context; support resume/skip via rows path.

Metrics to Run
- Build a `RoleMetrics` context per run and execute all `role_*` metrics with subject filtering:
  - Tank, Brawler, Marksman, Assassin, Mage, Support
- Consistency expectations (MVP): subject‑centric spans, thresholds sourced from central configuration (e.g., `roles_thresholds.json`), documented in `docs/rga/roles_thresholds.md`.

Runner Responsibilities (RoleMatrixProbe)
- New scene: `tests/rga_testing/validation/RoleMatrixProbe.tscn` with script `RoleMatrixProbe.gd` (typed, exported props).
- Plan runs → build jobs → invoke `HeadlessSimPipeline` → collect rows → assemble `RoleMetrics` context → run metrics filtered to subject.
- Schedule only relevant scenarios per role; run sequentially with progress prints; optional A/B swap.

Outputs
- Console summary (compact):
  - Subject header: unit, role/goal, level/cost; seeds, scenarios[], caps, rows path.
  - One block per metric with reasons lines: numbers vs thresholds and OK/FAIL flags.
  - Optional `--dump_json` flag to print raw metric results for debugging.
- JSON report: save to `user://identity_reports/<unit_id>.json`.
  - High‑level schema (MVP):
    ```json
    {
      "run_id": "uuid",
      "subject": {
        "unit_id": "bonko",
        "role": "Marksman",
        "goal": "sustained_dps",
        "approaches": ["backline", "kite"],
        "cost": 3,
        "level": 1
      },
      "meta": {
        "seeds": [11,13,17,19,23,29],
        "scenarios": ["marksman.kite_poke", "marksman.open_field"],
        "team_shells": ["subject+peel_tank", "neutral_2v2"],
        "opponent_selector": "balanced",
        "include_swapped": false,
        "rows_path": "user://rga_rows/bonko-<run_id>.csv"
      },
      "roles": {
        "Marksman": {
          "status": "PASS",
          "pass_rate": 0.67,
          "margin": 0.12,
          "samples": 30,
          "reasons": [
            "sustained_dps 0.58 ≥ 0.50",
            "backline_presence 0.71 ≥ 0.60"
          ],
          "span_labels": ["kite_poke", "open_field"],
          "deltas": {"time_alive_ms": "+4500"}
        }
      }
    }
    ```

Verdict Rubric (MVP)
- Compute `pass_rate` from role metric results across scheduled samples for that role.
- PASS: `pass_rate ≥ 0.60` (configurable) OR strong positive margins on primary requirements across ≥50% of samples.
- LEAN: `pass_rate ≥ 0.40` OR positive margins but inconsistent across samples.
- FAIL: otherwise.
- Always include 2–4 concise reasons with numeric comparisons (e.g., `soak_index 0.62 ≥ 0.40; time_alive low`).

Performance Budget and Knobs
- Target minutes per unit on default profile: small packs × 6–8 seeds, sequential runs.
- Expose knobs via exported props: `repeats`, `include_swapped`, `max_opponents`, `roles_to_run`, `scenario_packs_to_run`, `max_sims`.
- Provide two profiles: `quick_probe` (dev loop) and `full_probe` (deeper runs).

Non‑Goals (MVP)
- Exhaustive scenario coverage; heavy parallelism; automated tuning. These can follow once MVP stabilizes.

Validation
- Run via MCP using validated scenes (e.g., `tests/rga_testing/validation/RoleMatrixProbe.tscn`). Ensure `get_debug_output().errors` is empty before submission.
