extends AbilityImplBase

# Paisley — Bubbles
# Shields the two allies closest to death (lowest HP/MaxHP ratio), once per unique ally, for 1.5s.
# Then throws bubbles that deal split magic damage to the two nearest enemies (full damage if only one enemy).
# Trait-ready: scales with Kaleidoscope and Arcanist stacks (fallback 0 until traits are wired).

const SHIELD_BASE := [80, 100, 135]
const SHIELD_SP_MULT := 0.60
const SHIELD_KALEI_PER_STACK := 10.0
const SHIELD_ARCA_PER_STACK := 8.0
const SHIELD_DURATION := 1.5

const DMG_BASE := [110, 165, 260]
const DMG_SP_MULT := 0.70
const DMG_KALEI_PER_STACK := 12.0
const DMG_ARCA_PER_STACK := 8.0

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const KEY_KALEIDOSCOPE := "kaleidoscope_stacks" # Legacy fallback; TODO remove after validation
const KEY_ARCANIST := "arcanist_stacks"         # Legacy fallback; TODO remove after validation

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _get_stack(bs, state: BattleState, team: String, index: int, key: String) -> int:
	if bs == null:
		return 0
	var trait_key: String = key
	if key == KEY_ARCANIST:
		trait_key = TraitKeys.ARCANIST
	elif key == KEY_KALEIDOSCOPE:
		trait_key = TraitKeys.KALEIDOSCOPE
	var v: int = int(bs.get_stack(state, team, index, trait_key))
	if v > 0:
		return v
	return int(bs.get_stack(state, team, index, key))

func _ally_indices_by_lowest_ratio(ctx: AbilityContext, team: String) -> Array[int]:
	var arr: Array[Unit] = ctx.ally_team_array(team)
	var pairs: Array = []
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null or not u.is_alive():
			continue
		var ratio: float = float(u.hp) / max(1.0, float(u.max_hp))
		pairs.append({"i": i, "r": ratio})
	pairs.sort_custom(func(a, b): return float(a.r) < float(b.r))
	var out: Array[int] = []
	for p in pairs:
		if out.size() >= 2:
			break
		out.append(int(p.i))
	return out

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var bs = ctx.buff_system
	if bs == null:
		ctx.log("[Bubbles] BuffSystem not available; cast aborted")
		return false

	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var li: int = _level_index(caster)
	var kalei: int = _get_stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, KEY_KALEIDOSCOPE)
	var arca: int = _get_stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, KEY_ARCANIST)

	# Compute shield value (per ally)
	var shield_f: float = float(SHIELD_BASE[li])
	shield_f += SHIELD_SP_MULT * float(caster.spell_power)
	shield_f += SHIELD_KALEI_PER_STACK * float(max(0, kalei))
	shield_f += SHIELD_ARCA_PER_STACK * float(max(0, arca))
	var shield_val: int = int(max(0.0, round(shield_f)))

	# Pick two unique allies closest to death (include self as candidate via ally array)
	var targets: Array[int] = _ally_indices_by_lowest_ratio(ctx, ctx.caster_team)
	var applied: int = 0
	for i in targets:
		var res := bs.apply_shield(ctx.state, ctx.caster_team, i, shield_val, SHIELD_DURATION)
		if bool(res.get("processed", false)):
			applied += 1

	# Damage bubbles: split between two nearest enemies (full to one if only one target)
	var total_dmg_f: float = float(DMG_BASE[li])
	total_dmg_f += DMG_SP_MULT * float(caster.spell_power)
	total_dmg_f += DMG_KALEI_PER_STACK * float(max(0, kalei))
	total_dmg_f += DMG_ARCA_PER_STACK * float(max(0, arca))
	var total_dmg: int = int(max(0.0, round(total_dmg_f)))

	var enemy_idxs: Array[int] = ctx.two_nearest_enemies(ctx.caster_team)
	if enemy_idxs.size() == 0:
		ctx.log("Bubbles: shielded %d allies for %d; no enemies in range" % [applied, shield_val])
		return true
	elif enemy_idxs.size() == 1:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, enemy_idxs[0], float(total_dmg), "magic")
		ctx.log("Bubbles: shield %d for %d; dealt %d to one enemy" % [applied, shield_val, total_dmg])
		return true
	else:
		var a: int = int(floor(float(total_dmg) * 0.5))
		var b: int = total_dmg - a
		ctx.damage_single(ctx.caster_team, ctx.caster_index, enemy_idxs[0], float(a), "magic")
		ctx.damage_single(ctx.caster_team, ctx.caster_index, enemy_idxs[1], float(b), "magic")
		ctx.log("Bubbles: shield %d for %d; split %d/%d dmg" % [applied, shield_val, a, b])
		return true
