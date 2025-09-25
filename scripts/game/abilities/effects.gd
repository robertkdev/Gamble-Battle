extends Object
class_name AbilityEffects

const DamageMath = preload("res://scripts/game/combat/damage_math.gd")
const Health := preload("res://scripts/game/stats/health.gd")

# Deals damage to a single target with mitigation.
# type: "physical" | "magic" | "true" | "hybrid"
static func damage_single(engine: CombatEngine, state: BattleState, source_team: String, source_index: int, target_index: int, amount: float, type: String = "physical") -> Dictionary:
	var result: Dictionary = {"processed": false}
	if engine == null or state == null:
		return result
	var src: Unit = _unit_at(state, source_team, source_index)
	var tgt_team: String = _other_team(source_team)
	var tgt: Unit = _unit_at(state, tgt_team, target_index)
	if src == null or tgt == null or not tgt.is_alive():
		return result
	result["processed"] = true
	var before_hp: int = int(tgt.hp)
	var dealt_f: float = 0.0
	match type:
		"physical":
			dealt_f = DamageMath.apply_reduction(DamageMath.physical_after_armor(max(0.0, amount), src, tgt), tgt)
		"magic":
			dealt_f = DamageMath.apply_reduction(DamageMath.magic_after_resist(max(0.0, amount), src, tgt), tgt)
		"true":
			dealt_f = max(0.0, amount)
		"hybrid":
			var half: float = max(0.0, amount) * 0.5
			var phys := DamageMath.physical_after_armor(half, src, tgt)
			var mag := DamageMath.magic_after_resist(half, src, tgt)
			dealt_f = DamageMath.apply_reduction(phys + mag, tgt)
		_:
			dealt_f = max(0.0, amount)
	# Apply global flat damage reduction after %DR, before health apply
	if tgt != null:
		var flat_dr: float = 0.0
		if tgt.has_method("get"):
			flat_dr = max(0.0, float(tgt.get("damage_reduction_flat")))
		else:
			flat_dr = max(0.0, float(tgt.damage_reduction_flat))
		dealt_f = max(0.0, dealt_f - flat_dr)
	var dealt: int = int(max(0.0, round(dealt_f)))
	var _hres := Health.apply_damage(tgt, dealt)
	dealt = int(_hres.dealt)
	result["dealt"] = dealt
	result["before_hp"] = before_hp
	result["after_hp"] = int(tgt.hp)
	# Emit for UI/analytics
	if source_team == "player":
		engine._resolver_emit_log("Your ability hits %s for %d." % [tgt.name, dealt])
	else:
		engine._resolver_emit_log("%s hits you with an ability for %d." % [src.name, dealt])
	engine._resolver_emit_unit_stat(tgt_team, target_index, {"hp": tgt.hp})
	engine._resolver_emit_stats(src, BattleState.first_alive(state.enemy_team))
	return result

# Heals a single target (clamped to Max HP)
static func heal_single(engine: CombatEngine, state: BattleState, target_team: String, target_index: int, amount: float) -> Dictionary:
	var result := {"processed": false}
	var tgt: Unit = _unit_at(state, target_team, target_index)
	if tgt == null or not tgt.is_alive():
		return result
	var before_hp: int = int(tgt.hp)
	var heal_amt: int = int(max(0.0, round(amount)))
	var hres := Health.heal(tgt, heal_amt)
	result["processed"] = true
	result["healed"] = int(hres.get("healed", int(tgt.hp) - before_hp))
	result["before_hp"] = before_hp
	result["after_hp"] = int(tgt.hp)
	engine._resolver_emit_unit_stat(target_team, target_index, {"hp": tgt.hp})
	engine._resolver_emit_stats(BattleState.first_alive(state.player_team), BattleState.first_alive(state.enemy_team))
	return result

# Applies a shield via BuffSystem; no-op if buff_system is null.
static func shield(buff_system, engine: CombatEngine, state: BattleState, target_team: String, target_index: int, amount: float, duration_s: float) -> Dictionary:
	if buff_system == null:
		engine._resolver_emit_log("[Ability] Shield requested but BuffSystem not available")
		return {"processed": false}
	return buff_system.apply_shield(state, target_team, target_index, int(max(0.0, round(amount))), max(0.0, duration_s))

# Applies temporary stat buffs via BuffSystem; fields e.g., {armor:+20, magic_resist:+20, damage_reduction:0.2}
static func buff_stats(buff_system, engine: CombatEngine, state: BattleState, target_team: String, target_index: int, fields: Dictionary, duration_s: float) -> Dictionary:
	if buff_system == null:
		engine._resolver_emit_log("[Ability] Buff requested but BuffSystem not available")
		return {"processed": false}
	return buff_system.apply_stats_buff(state, target_team, target_index, fields, max(0.0, duration_s))

# Applies a stun via BuffSystem; no-op if buff_system is null.
static func stun(buff_system, engine: CombatEngine, state: BattleState, target_team: String, target_index: int, duration_s: float) -> Dictionary:
	if buff_system == null:
		engine._resolver_emit_log("[Ability] Stun requested but BuffSystem not available")
		return {"processed": false}
	return buff_system.apply_stun(state, target_team, target_index, max(0.0, duration_s))

# --- Internal helpers ---
static func _unit_at(state: BattleState, team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]

static func _other_team(team: String) -> String:
	return "enemy" if team == "player" else "player"
