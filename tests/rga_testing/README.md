# RGA Testing

Headless, modular simulation pipeline for role:goal:approach testing. Generates NDJSON telemetry with aggregates (and optional events) using the same CombatEngine as BalanceRunner.

## Profiles & Config Layering

You can compose settings from three layers. Later layers override earlier ones:

1) Base config file (optional): `--config=path/to/base.json|.tres`
2) Profile (optional): `--profile=designer_quick|ci_full` or `--profile=res://path/to/profile.json`
3) CLI overrides (optional): flags like `--repeats=5 --timeout=90 --out=user://rga.ndjson`

Precedence: base -> profile -> CLI.

Examples
- Quick run with the built-in designer profile:
  - `godot --headless -s tests/rga_testing/main.gd -- --profile=designer_quick`
- CI-style profile with a few CLI overrides:
  - `godot --headless -s tests/rga_testing/main.gd -- --profile=ci_full --repeats=5 --out=user://out/tmp.ndjson`
- Custom base config plus a profile:
  - `godot --headless -s tests/rga_testing/main.gd -- --config=res://my_base.json --profile=designer_quick`
- No profile, only CLI (uses defaults + overrides):
  - `godot --headless -s tests/rga_testing/main.gd -- --repeats=3 --timeout=60 --abilities=false`

Common CLI flags
- `--run_id`, `--sim_seed_start`, `--deterministic`, `--team_sizes` (CSV of ints)
- `--repeats`, `--timeout`, `--abilities`, `--ability_metrics`, `--out`
- Filters: `--role`, `--goal`, `--approach`, `--cost`, `--ids` (e.g., `a:b,c:d`)

Notes
- Profiles live in `tests/rga_testing/config/profiles/` (e.g., `designer_quick.json`, `ci_full.json`).
- Config files may be JSON or TRES; both are loaded into a Dictionary then merged.
- The pipeline logs the final merged settings before running.


