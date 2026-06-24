RGA2 — Formula Tests

Deterministic, formula-first validation of role baselines and derived targets.

What it does
- Loads constants and per-role targets from fixtures.
- Computes EHP over a 24s horizon using DR K=100 (mixed 50/50) and (shields, heals).
- Computes sustained DPS = autos (AD*AS*crit) + ability DPS (sum of damage_per_cast/cooldown).
- Compares computed values to the targets with small absolute tolerances.

How to run (via MCP)
- Scene: `tests/rga2/FormulaRunner.tscn`
- Configure in the Inspector:
  - `constants_path` (default provided)
  - `targets_path` (default provided)
  - `roles_to_check` (empty = all)
  - `tolerance_dps`, `tolerance_ehp`
  - `quit_on_finish` (true recommended for CI)

Notes
- Role profile stats remain the source of truth for raw baselines. The fixture mirrors the published tables and includes test-time cadence/crit/AS.
- Abilities/AS/Crit used here are test inputs; do not author these into role profiles.
- Extend by adding new roles, costs, or goals/approaches into the fixtures and adding new formula checks if needed.
