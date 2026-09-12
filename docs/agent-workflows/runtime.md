# Blood Will Pay: runtime

All code and resource paths are relative to the selected repository root. Verify live tool schemas and selected checkout paths before using examples.

## Running (MCP Only)
- Agents MUST run the project exclusively via MCP `run_project(projectPath="<abs_project_dir>", scene="<scene>.tscn")`.
- Do not pass `.` for `projectPath`; it resolves relative to the MCP host process and may not be the repo root.
- Example (this repo): `projectPath="C:\Users\Flipm\Documents\blood-will-pay"`.
- Choose the scene appropriate for the task; do not assume `scenes/Main.tscn`.
- Never invoke the `godot` executable or pass `-s`; if the editor is needed, use MCP `launch_editor(projectPath)`.

Common scenes to run via MCP
- Game: `scenes/Main.tscn`
- RGA regression harness: `tests/rga_testing/RGATesting.tscn`
- Role matrix probe (1v1): `tests/rga_testing/validation/RoleMatrixProbe.tscn`
- Role matrix probe (6v6): `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn`
- Perf harness (optional): `tests/perf/Perf1v1.tscn`, `tests/perf/Perf1v1Sweep.tscn`

Output locations
- Prefer writing to `user://...` paths.
- Defaults: RGA outputs -> `user://rga_out.jsonl` (single file or per-run directory).

## MCP Quickstart
- Preferred Codex/Godot loop
  - Use `godot-ai` first when the editor is open and live inspection matters: `session_manage`, `editor_state`, `logs_read`, `project_run`, `editor_screenshot`, scene/script tools, and game eval.
  - Use the legacy `godot` MCP as the fallback runner and project utility layer, especially from a fresh Codex session before `godot-ai` has loaded.
  - On every fresh, replaced, or newly selected checkout, launch the editor through MCP before the first project run, then require `Tools\Test-GodotEditorHydration.ps1 -ProjectPath "<selected-project-path>" -AsJson` to return `ready: true`. Never start `Main.tscn` while this gate reports missing script classes or imported resources; doing so can produce false SVG-loader and external-class parser failures.
  - For visual verification, run the scene with `godot-ai project_run`, wait for `editor_state.game_capture_ready == true`, then capture `editor_screenshot(source="game")`.
  - Codex config has both MCP servers: `godot` for local process control and `godot-ai` at `http://127.0.0.1:8000/mcp` for live-editor control.

- Core operations
  - `run_project(projectPath, scene?)`, `stop_project()` (debug mode; inspect `get_debug_output()` after run)
  - `create_scene(rootNodeType, projectPath, scenePath)`, `save_scene(scenePath, newPath?)`
  - `add_node(nodeName, nodeType, parentNodePath?, projectPath, scenePath, properties?)`
  - `edit_node(nodePath, projectPath, scenePath, properties)` (set exported props before running a scene)
  - `remove_node(nodePath, projectPath, scenePath)`
  - `load_sprite(nodePath, scenePath, texturePath, projectPath)`
  - Info/maintenance: `list_projects`, `get_project_info`, `get_godot_version`, `get_debug_output`, `launch_editor`, `update_project_uids`, `get_uid`, `export_mesh_library`

- Paths and typing
  - `projectPath` must be an absolute path to the directory containing `project.godot`. Use MCP `list_projects` to discover valid projects (e.g., search `C:\Users\Flipm\Documents`). Resource paths remain project-relative (e.g., `tests/rga_testing/validation/RoleMatrixProbe.tscn`).
  - Provide correctly typed values in `properties` (e.g., `position: Vector2(64, 64)`, `rotation: 0.0`, `texture: Resource`), or `null` to clear.

- Run scenes examples
  - RGA regression suite: `run_project(projectPath="C:\Users\Flipm\Documents\blood-will-pay", scene="tests/rga_testing/RGATesting.tscn")`
  - Role matrix (1v1): `run_project(projectPath="C:\Users\Flipm\Documents\blood-will-pay", scene="tests/rga_testing/validation/RoleMatrixProbe.tscn")`
  - Role matrix (6v6): `run_project(projectPath="C:\Users\Flipm\Documents\blood-will-pay", scene="tests/rga_testing/validation/RoleMatrixProbe6v6.tscn")`

- Safety
  - Do not hand-edit `.uid`/`.import` files. Use MCP `update_project_uids` or the editor via MCP.
  - Keep changes minimal and focused.
  - In tools/headless, guard autoload usage (see `_has_autoload(...)` pattern in `scripts/game/shop/shop.gd`).

## Test Authoring Patterns
- Use a small scene with a `Node` and a script that runs in `_ready()` then calls `get_tree().quit()`.
- Prefer configuration via resources or `user://` files; avoid reliance on command-line arguments.

## Validation Tips
- Fast sanity checks via MCP (validated)
  - Quick: run `tests/rga_testing/validation/RoleMatrixProbe.tscn` (1v1) or `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` and inspect `get_debug_output()`.
  - Full regression: run `tests/rga_testing/RGATesting.tscn`.
- Stat lint: automatically runs via `roles_gate`. For manual spot checks use `tests/lint/UnitStatLint.tscn` after touching `data/units/*.tres`.
- Stat audit: run `tests/rga_testing/validation/UnitStatAudit.tscn` to diff live unit stats against role baselines.
- For resource changes, open the project via MCP `launch_editor(projectPath)` to validate UIDs/resources.
- When changing container types, run a minimal test scene via MCP to catch mismatches early.

### Pre-Submit Debug Run (Runtime-Affecting Changes)
- For gameplay, script, resource, or runtime-affecting changes, run at least one appropriate scene via MCP in debug before submitting. For instruction-only or documentation-only changes, review content, references, scope, and `git diff --check`; do not launch a game solely for those edits.
- Immediately call `get_debug_output()` and ensure the `errors` array is empty.
- If any script parse errors, assertions, or engine errors appear (e.g., "SCRIPT ERROR", "ASSERT FAILED"), do not submit; fix issues or adjust the scene.
- Suggested defaults:
  - General unit validation: `tests/rga_testing/validation/RoleMatrixProbe.tscn`
  - Full regression: `tests/rga_testing/RGATesting.tscn`
  - Targeted systems: add/extend a purpose-built scene under `tests/rga_testing/...`

### Troubleshooting
- Not a valid Godot project: . � Use an absolute `projectPath` (e.g., `C:\Users\Flipm\Documents\blood-will-pay`) or discover via `list_projects`.
- Scene parse errors � Ensure required scripts/resources parse under Godot 4.5; update dependencies or run the appropriate RGA probe scene to confirm.
