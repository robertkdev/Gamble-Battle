# Blood Will Pay agent instructions

Scope: this repository. Preserve the user's requested outcome and existing authored work. Resolve the actual selected checkout before using any example path.

## Canonical Obsidian Brain
Use the global conditional brain-retrieval workflow for project history, decisions, and continuity. The live router currently resolves this project to `Projects/Gamble Battle.md`; use the route it actually returns rather than inventing a renamed page. Record durable state changes and reusable conclusions, not every read-only task. Canonical writes belong to the root through the revision/hash-checked write helper. Run read-only `Tools\Test-Vault.cmd` after vault edits; use `-CreateProbeCapture` only when testing capture integration itself. Keep secrets and large/raw artifacts out of the vault.

## Game Design Source Of Truth
- The canonical gameplay/design reference is the private Google Doc `Blood Will Pay`: https://docs.google.com/document/d/1OCS4jfjMIiw-2-VQbLPaeDxsmzZMKEAFKb6BHvkMa7I/edit?tab=t.0
- For game terminology, units, roles, stats, traits, items, tests, goals, and design-framework decisions, consult the live Google Doc before inventing new behavior or changing game content.
- The doc requires the user's signed-in Chrome/Google session; anonymous fetch/export may fail with `401 Unauthorized`.
- If the live doc conflicts with repo code or local docs, surface the conflict and treat the Google Doc as the product/design authority unless the user says otherwise.
- The brain source note for this document is `Sources/Blood Will Pay Google Design Doc.md`.

## Current Unit Naming Contract
- Mara is the only current unit identity. Cashmere is a retired legacy name and must never be presented as a current unit, alias, display label, or approved image.
- Lowercase `cashmere` may remain only in explicitly labeled legacy input compatibility, historical filenames, generated-output provenance, or preserved dated evidence.
- Canonical active identifiers are `mara`, `mara_arcane_ledger`, `data/units/mara.tres`, and `data/identity/unit_identities/mara_identity.tres`.
- The pale ledger-clad artwork stored under the retired filename is an unapproved placeholder/provenance asset, not confirmed Mara art. Do not silently relabel or promote it.

## Project Overview
- Engine: Godot 4.5
- Main scene (gameplay): `scenes/Main.tscn`
- Autoloads: `GameState`, `Economy`, `Roster`, `Shop`, `Items` (see `project.godot`)
- Languages: Typed GDScript, Godot `.tscn`/`.tres`
- Base combat stats live in `data/identity/primary_role_profiles/*.tres`; unit defs under `data/units/` carry identity/kit/economy only and must stay stat-free.

Top-level layout
- `scripts/` � gameplay code (combat, shop, items, UI helpers, utilities)
- `scenes/` � scenes and UI
- `data/` � content resources (units, items)
- `assets/` � textures/art
- `tests/` � headless runners, test scenes
- `docs/` � design notes and developer docs

## GDScript Style (Typed)
- Indentation: match nearby files; gameplay code uses tabs.
- Naming: functions/vars `snake_case`; classes `class_name PascalCase`; constants `UPPER_SNAKE_CASE`; preloads `const Pascal := preload("...")`.
- Types: always annotate vars/params/returns; use `Array[T]`, `Packed*Array`, and `Dictionary[K, V]`.
  - Typed examples
    - Good: `var number: int = 0`
    - Bad: `var number := 0` (missing explicit type)
- Hard rule: no ambiguous variables
  - Every `var` must declare an explicit type. Do NOT use inferred declarations like `var x := ...` or bare `var x = ...`.
  - Always use typed containers: `Array[T]`, `Dictionary[K, V]`, `Packed*Array`.
  - Exported vars must be typed (e.g., `@export var health: int = 100`).
- Signals: type parameters when known (e.g., `signal error(code: String, context: Dictionary)`).
- Imports: prefer `preload()`; use `load()` only for dynamic cases.
- Scene scripts: keep `_ready()` light; prefer explicit `configure(...)` methods.
- Logging: `print` for routine logs; `push_warning` for non-fatal; `push_error` only for hard failures.

## Godot/Resource Practices
- Prefer editing `.tscn`/`.tres` via Godot; if patching text, keep formatting stable and minimal.
- Do not edit `.uid`/`.import` by hand.
- When UIDs break, re-open/save scenes in the editor or batch-resave; MCP `update_project_uids` is available.
- Autoload checks: follow `_has_autoload(...)` before calling singletons in tools/headless.

## Making Changes Safely
- Do not edit `project.godot` unless required.
- For combat/shop/items behavior changes, use an existing appropriate regression scene or add focused coverage when it would catch a meaningful failure. Keep behavior deterministic where possible; do not create a test that merely repeats the implementation.
- Keep changes focused; do not reformat unrelated files.

## Git Hygiene / Publishing
- Start and finish meaningful work with `git status -sb`; inspect `git diff --stat` before deciding what belongs in the handoff.
- Treat a dirty tree as a maintenance risk. Do not leave agent-owned source, test, docs, or config changes uncommitted unless blocked or the user explicitly asks for an uncommitted handoff.
- When the tree is already dirty, separate pre-existing user work from agent-made work. Never revert user changes just to make status clean.
- For broad accumulated work, classify changes into intentional commit groups before staging: tooling/docs, gameplay/content, RGA/tests, UI/visuals, and cleanup are common groups in this repo.
- Stage explicit paths or reviewed groups. Avoid `git add -A` until ignored runtime artifacts, generated outputs, local Godot binaries, and temporary files have been ruled out.
- Before committing, run `git diff --check` and the affected checks described below. Gameplay, script, resource, and runtime-affecting changes require appropriate MCP validation and `get_debug_output()` inspection; instruction-only or documentation-only changes require content, reference, and scope review rather than a game launch. Line-ending warnings alone are not blockers; script errors, assertions, or unexpected engine errors are.
- Before pushing, run `git fetch --prune --tags`, verify the branch and upstream, inspect `git diff --cached --stat`, commit with a clear message, then push.
- If GitHub tooling such as `gh` is unavailable, direct-push the branch when that is the user's requested publishing path, and state that no PR was opened.
- If any dirty files remain at handoff, document exactly why they remain, who owns them if known, and what command or decision is needed next.

## Validation and completion

Choose checks for the affected behavior. Reuse current evidence only when its source and scope still match. After those checks pass, repeat or broaden them only for new changes, failures, or unresolved concerns. An explicit `/playtest` still means broad player-facing coverage under the playtest skill. A narrow implementation check must not be reported as a broad playtest. Preserve active editors, games, serving roots, dirty primaries, and user saves.

## Task-specific references

- Before launching or validating runtime changes; includes mandatory hydration and meaningful debug gates: [docs/agent-workflows/runtime.md](docs/agent-workflows/runtime.md).
- Before discussing selected unit art or editing generated UI assets; shared selection is not production approval: [docs/agent-workflows/art.md](docs/agent-workflows/art.md).
- When placing content or locating the existing game systems and tests: [docs/agent-workflows/content.md](docs/agent-workflows/content.md).

When selected-art context is requested, read the exact image selected in `C:\Users\Flipm\Documents\Blood-Will-Pay-shared\tools\art\unit-art-review-state.json` before considering alternatives.
