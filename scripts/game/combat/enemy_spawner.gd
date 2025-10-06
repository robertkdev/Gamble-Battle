extends RefCounted
class_name EnemySpawner
const Trace := preload("res://scripts/util/trace.gd")
const EnemyScaling := preload("res://scripts/game/combat/enemy_scaling.gd")
const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")

# Produces enemy Units for a given stage. No UI concerns.

# --- Edit here for quick testing ---
# Put unit IDs you want to spawn for the enemy team.
# Example: ["axiom", "axiom", "paisley"]
# Empty by default so catalog drives normal runs.
var ENEMY_TEAM: Array[String] = []

# Optional: change at runtime from tests/tools
func set_enemy_team(ids: Array) -> void:
	ENEMY_TEAM.clear()
	for v in ids:
		var s := String(v)
		if s.strip_edges() != "":
			ENEMY_TEAM.append(s)

func build_for_stage(stage: int) -> Array[Unit]:
	Trace.step("EnemySpawner.build_for_stage: begin stage=" + str(stage))
	var mapping := ProgressionService.from_global_stage(int(stage))
	var ch: int = int(mapping.get("chapter", 1))
	var sic: int = int(mapping.get("stage_in_chapter", 1))
	var units: Array[Unit] = build_for(ch, sic)
	# Centralized stage scaling (disabled by default; see EnemyScaling.ENABLED)
	EnemyScaling.apply_for_stage(units, stage)
	Trace.step("EnemySpawner.build_for_stage: end; count=" + str(units.size()))
	return units

func build_for(ch: int, sic: int) -> Array[Unit]:
	Trace.step("EnemySpawner.build_for: begin ch=" + str(ch) + " sic=" + str(sic))
	var spec: Dictionary = RosterCatalog.get_spec(int(ch), int(sic))
	var out: Array[Unit] = build_for_spec(spec, int(ch), int(sic))
	Trace.step("EnemySpawner.build_for: end; count=" + str(out.size()))
	return out

func build_for_spec(spec: Dictionary, _ch: int, _sic: int) -> Array[Unit]:
	# Build units from provided spec; apply override if present. No rule hooks here.
	var ids: Array = []
	if not ENEMY_TEAM.is_empty():
		ids = ENEMY_TEAM.duplicate(true)
	elif typeof(spec) == TYPE_DICTIONARY:
		ids = (spec.get(StageTypes.KEY_IDS, []) if spec.has(StageTypes.KEY_IDS) else [])
	var uf = load("res://scripts/unit_factory.gd")
	var out: Array[Unit] = []
	if ids.is_empty():
		Trace.step("EnemySpawner: no ids to spawn (spec empty). Applying default fallback.")
		# Fallback to chapter/kind defaults so stages never start empty
		var kind_fallback: String = String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
		var def_ids: Array = RosterCatalog._default_ids_for(int(_ch), int(_sic), kind_fallback)
		ids = def_ids.duplicate(true)
		if ids.is_empty():
			Trace.step("EnemySpawner: fallback also empty; returning no enemies")
			return out
	var label_parts: Array[String] = []
	for id in ids:
		var sid := String(id)
		label_parts.append(sid)
		var e: Unit = uf.spawn(sid)
		if e:
			out.append(e)
		else:
			Trace.step("EnemySpawner: failed to spawn '" + sid + "'")
	# If all spawns failed (e.g., missing resources), attempt a final minimal fallback
	if out.is_empty():
		Trace.step("EnemySpawner: spawn list empty after attempts; using [creep] as emergency fallback")
		var e2: Unit = uf.spawn("creep")
		if e2:
			out.append(e2)
	Trace.step("EnemySpawner: spawned [" + ", ".join(label_parts) + "]")
	return out
