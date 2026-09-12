# Blood Will Pay: content

All code and resource paths are relative to the selected repository root. Verify live tool schemas and selected checkout paths before using examples.

## Where Things Go
- New systems: `scripts/game/<area>/...`
- Utilities: `scripts/util/`
- Scenes: `scenes/` (e.g., `scenes/ui`, `scenes/tools`)
- Items: `data/items/<id>.tres` (auto-discovered by catalog)
- Units: `data/units/<id>.tres` (playables; `UnitFactory` loads identity, kit knobs, cost/level; combat stats belong in role profiles)
- Non-playables: `data/other_units/creeps/...` and `data/other_units/other/...` (enemy waves, test dummies). Excluded from shop/audits; still spawnable by ID.
- Public constants/config: update docs under `docs/` (e.g., `docs/shop/README.md`).

## Adding Content
- Unit (playable): create `data/units/<id>.tres` as `UnitProfile`; fill identity/kit metadata and economy knobs only (no combat stats).
- Non-playable (enemy/test): create under `data/other_units/creeps/...` or `data/other_units/other/...` with `UnitProfile`; set flags (`enemy_only`, `hidden`) as appropriate.
- Item: create `data/items/<id>.tres` as `ItemDef`; set `type` and (for completed) `components`.

## Quick Links
- Shop docs: `docs/shop/README.md`
- Gothic UI asset workflow: `docs/art/ui_gothic_asset_workflow.md`
- Shop config: `scripts/game/shop/shop_config.gd`
- Unit factory: `scripts/unit_factory.gd`
- Unit stat audit: `tests/rga_testing/validation/UnitStatAudit.tscn`
- Balancing workflow: `docs/balancing_workflow.md`
- RGA testing overview: `tests/rga_testing/README.md`
- Role matrix probes: `tests/rga_testing/validation/RoleMatrixProbe.tscn`, `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn`
