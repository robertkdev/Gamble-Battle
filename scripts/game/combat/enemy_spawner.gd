extends RefCounted
class_name EnemySpawner

# Produces enemy Units for a given stage. No UI concerns.

func build_for_stage(stage: int) -> Array[Unit]:
	var out: Array[Unit] = []
	var uf = load("res://scripts/unit_factory.gd")
	var e1: Unit = uf.spawn("nyxa")
	var e2: Unit = uf.spawn("volt")
	if e1: out.append(e1)
	if e2: out.append(e2)
	# Basic scaling hooks (optional; modify stats lightly by stage)
	for e in out:
		if e:
			var hp_scale := pow(1.15, max(0, stage - 1))
			var atk_scale := pow(1.10, max(0, stage - 1))
			e.max_hp = int(round(float(e.max_hp) * hp_scale))
			e.hp = e.max_hp
			e.attack_damage = int(round(float(e.attack_damage) * atk_scale))
	return out
