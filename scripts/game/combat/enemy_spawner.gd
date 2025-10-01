extends RefCounted
class_name EnemySpawner
const Trace := preload("res://scripts/util/trace.gd")
const EnemyScaling := preload("res://scripts/game/combat/enemy_scaling.gd")

# Produces enemy Units for a given stage. No UI concerns.

# --- Edit here for quick testing ---
# Put unit IDs you want to spawn for the enemy team.
# Example: ["axiom", "axiom", "paisley"]
var ENEMY_TEAM: Array[String] = [
	"bonko"
]

# Optional: change at runtime from tests/tools
func set_enemy_team(ids: Array) -> void:
	ENEMY_TEAM.clear()
	for v in ids:
		var s := String(v)
		if s.strip_edges() != "":
			ENEMY_TEAM.append(s)

func build_for_stage(stage: int) -> Array[Unit]:
	Trace.step("EnemySpawner.build_for_stage: begin stage=" + str(stage))
	var out: Array[Unit] = []
	var uf = load("res://scripts/unit_factory.gd")
	var label := ", ".join(ENEMY_TEAM)
	Trace.step("EnemySpawner: spawning [" + label + "]")
	if ENEMY_TEAM.is_empty():
		Trace.step("EnemySpawner: ENEMY_TEAM empty; nothing to spawn")
	for id in ENEMY_TEAM:
		var e: Unit = uf.spawn(String(id))
		if e:
			out.append(e)
		else:
			Trace.step("EnemySpawner: failed to spawn '" + String(id) + "'")
	# Centralized stage scaling (disabled by default; see EnemyScaling.ENABLED)
	EnemyScaling.apply_for_stage(out, stage)
	Trace.step("EnemySpawner.build_for_stage: end; count=" + str(out.size()))
	return out
