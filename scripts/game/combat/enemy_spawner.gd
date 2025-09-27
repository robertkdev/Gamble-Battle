extends RefCounted
class_name EnemySpawner
const Trace := preload("res://scripts/util/trace.gd")

# Produces enemy Units for a given stage. No UI concerns.

# --- Edit here for quick testing ---
# Put unit IDs you want to spawn for the enemy team.
# Example: ["axiom", "axiom", "paisley"]
var ENEMY_TEAM: Array[String] = [
	"axiom", "axiom", "axiom", "axiom", "axiom", "axiom", "axiom"
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
	# Basic scaling hooks (optional; modify stats lightly by stage)
	for e in out:
		if e:
			var hp_scale := pow(1.15, max(0, stage - 1))
			var atk_scale := pow(1.10, max(0, stage - 1))
			e.max_hp = int(round(float(e.max_hp) * hp_scale))
			e.hp = e.max_hp
			e.attack_damage = int(round(float(e.attack_damage) * atk_scale))
	Trace.step("EnemySpawner.build_for_stage: end; count=" + str(out.size()))
	return out
