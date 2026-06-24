extends Object
class_name AbilityEffects

const DamageMath = preload("res://scripts/game/combat/damage_math.gd")
const Health := preload("res://scripts/game/stats/health.gd")
const HealingService := preload("res://scripts/game/traits/runtime/healing_service.gd")
const TeamUtils := preload("res://scripts/game/combat/attack/support/team_utils.gd")

# Deals damage to a single target with mitigation.
# type: "physical" | "magic" | "true" | "hybrid"
static func damage_single(engine: CombatEngine, state: BattleState, source_team: String, source_index: int, target_index: int, amount: float, type: String = "physical") -> Dictionary:
	var result: Dictionary = {"processed": false}
	if engine == null or state == null:
		return result
	var src: Unit = TeamUtils.unit_at(state, source_team, source_index)
	var tgt_team: String = TeamUtils.other_team(source_team)
	var tgt: Unit = TeamUtils.unit_at(state, tgt_team, target_index)
	if src == null or tgt == null or not tgt.is_alive():
		return result
	# Global ability damage amplifier via tag
	var amt_f: float = max(0.0, amount)
	var amp_pct: float = 0.0
	var amp_output_delta: float = 0.0
	var amp_source_team: String = source_team
	var amp_source_index: int = source_index
	if engine != null and engine.buff_system != null:
		const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")
		var data: Dictionary = engine.buff_system.get_tag_data(state, source_team, source_index, BuffTags.TAG_ABILITY_AMP)
		if data != null and not data.is_empty():
			amp_pct = float(data.get("ability_damage_amp", 0.0))
			amp_source_team = String(data.get("source_team", source_team))
			amp_source_index = int(data.get("source_index", source_index))
			if amp_pct != 0.0:
				var before_amp_amount: float = amt_f
				amt_f = max(0.0, amt_f * (1.0 + amp_pct))
				amp_output_delta = max(0.0, amt_f - before_amp_amount)
	# Delegate to attack resolver's unified pipeline
	if engine.attack_resolver != null and engine.attack_resolver.has_method("apply_ability_damage"):
		var res: Dictionary = engine.attack_resolver.apply_ability_damage(source_team, source_index, target_index, amt_f, type)
		if bool(res.get("processed", false)):
			if amp_output_delta > 0.0 and engine.has_method("_resolver_emit_amp_output_applied"):
				engine._resolver_emit_amp_output_applied(amp_source_team, amp_source_index, source_team, source_index, tgt_team, target_index, amp_output_delta, amp_pct, "ability_amp")
			return res
	# Fallback (shouldn't trigger): no-op result
	return result

# Heals a single target (clamped to Max HP)
static func heal_single(engine: CombatEngine, state: BattleState, target_team: String, target_index: int, amount: float, source_team: String = "", source_index: int = -1) -> Dictionary:
	var result := {"processed": false}
	var tgt: Unit = TeamUtils.unit_at(state, target_team, target_index)
	if tgt == null or not tgt.is_alive():
		return result
	var heal_amt: float = max(0.0, float(amount))
	# Route through HealingService for amp/overheal conversion
	var bs = engine.buff_system if engine != null else null
	var hres: Dictionary = HealingService.apply_heal(state, bs, target_team, target_index, heal_amt)
	if not hres.get("processed", false):
		return result
	result["processed"] = true
	result["healed"] = int(hres.get("healed", 0))
	result["before_hp"] = int(hres.get("before_hp", 0))
	result["after_hp"] = int(hres.get("after_hp", 0))
	if engine != null:
		engine._resolver_emit_unit_stat(target_team, target_index, {"hp": tgt.hp})
		engine._resolver_emit_stats(BattleState.first_alive(state.player_team), BattleState.first_alive(state.enemy_team))
		var st := String(source_team)
		var si := int(source_index)
		if st == "" or si < 0:
			# Unknown source; still emit with placeholders
			st = ""
			si = -1
		engine._resolver_emit_heal_applied(st, si, target_team, target_index, int(hres.get("healed", 0)), int(hres.get("overheal", 0)), int(hres.get("before_hp", 0)), int(hres.get("after_hp", 0)))
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
static func stun(buff_system, engine: CombatEngine, state: BattleState, target_team: String, target_index: int, duration_s: float, source_team: String = "", source_index: int = -1) -> Dictionary:
	if buff_system == null:
		engine._resolver_emit_log("[Ability] Stun requested but BuffSystem not available")
		return {"processed": false}
	var pushed_source: bool = false
	if String(source_team) != "" and int(source_index) >= 0 and buff_system.has_method("push_source"):
		buff_system.push_source(String(source_team), int(source_index), "ability")
		pushed_source = true
	var res: Dictionary = buff_system.apply_stun(state, target_team, target_index, max(0.0, duration_s))
	if pushed_source and buff_system.has_method("pop_source"):
		buff_system.pop_source()
	# Emit CC applied for analytics if we know the effective time
	if engine != null and res != null and bool(res.get("processed", false)):
		var resolved_source_team: String = String(source_team)
		var resolved_source_index: int = int(source_index)
		if resolved_source_team == "" or resolved_source_index < 0:
			if buff_system != null and buff_system.has_method("current_source"):
				var source_info: Dictionary = buff_system.current_source(String(target_team), int(target_index))
				resolved_source_team = String(source_info.get("team", resolved_source_team))
				resolved_source_index = int(source_info.get("index", resolved_source_index))
		var eff: float = float(res.get("effective", res.get("duration", duration_s)))
		if eff > 0.0 and engine.has_method("_resolver_emit_log"):
			engine._resolver_emit_log("CC applied: stun %.2fs" % eff)
		if engine != null and engine.has_method("_resolver_emit_hit") and engine.has_method("_resolver_emit_log"):
			pass
		if engine != null and engine.has_method("_resolver_emit_stats"):
			pass
		if engine != null and engine.has_method("_resolver_emit_hit_mitigated"):
			pass
		if engine != null and engine.has_method("_resolver_emit_team_stats"):
			pass
		if engine != null and engine.has_method("_resolver_emit_log"):
			pass
		if engine != null and engine.has_method("_resolver_emit_hit_components"):
			pass
		if engine != null and engine.has_method("_resolver_emit_heal_applied"):
			pass
		# Dedicated event through CombatEvents if wired
		if engine != null and engine.has_method("_build_resolver_emitters"):
			# Use CombatManager re-emitted path via events: add cc_applied to bus
			if engine != null and engine.has_method("_resolver_emit_log"):
				pass
		if engine != null and engine.has_method("_resolver_emit_team_stats"):
			pass
		# Use the engine-owned signal emitter when available.
		if engine != null and engine.has_method("_resolver_emit_cc_applied"):
			engine._resolver_emit_cc_applied(resolved_source_team, resolved_source_index, String(target_team), int(target_index), "stun", float(eff))
		elif engine != null and engine.has_signal("cc_applied"):
			engine.emit_signal("cc_applied", resolved_source_team, resolved_source_index, String(target_team), int(target_index), "stun", float(eff))
	return res

# --- Internal helpers ---
