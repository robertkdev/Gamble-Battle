extends AbilityImplBase

# Bonko — Bonk (with Bonk Buddy)
# Cast: Smash current target for 140/210/320 + 0.85×AD + 11×StrikerStacks physical.
# If target already stunned: +20% damage instead of applying stun.
# Else: stun for 1.0/1.25/1.5s.
# Then: lunge past the target, gain a shield for 5.0s, Bonk Buddy grants +30% attack speed, +armor/+MR, 18% lifesteal, and a clone shot is emitted on each attack for 35% damage.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

const BASE_BY_LEVEL := [110, 170, 260]
const STUN_BY_LEVEL := [1.0, 1.25, 1.5]
const STRIKER_KEY := "striker_stacks" # Legacy fallback; TODO: remove after validation
const DURATION_S := 2.0
const ATTACK_SPEED_BONUS := 0.35
const CLONE_PCT := 0.30
const BONUS_ON_STUNNED := 0.20
const AD_RATIO := 0.55
const STRIKER_SCALING := 10.0
const ARMOR_BUFF_BY_LEVEL := [18.0, 26.0, 34.0]
const MR_BUFF_BY_LEVEL := [16.0, 24.0, 32.0]
const LIFESTEAL_BUFF := 0.15
const DAMAGE_REDUCTION_BUFF := 0.12
const SHIELD_BY_LEVEL := [180, 260, 340]
const SHIELD_PER_STACK := 8.0
const HEAL_PER_LEVEL := [110.0, 160.0, 210.0]
const HEAL_PER_STACK := 6.0
const DASH_MAX_TILES := 2.0
const DASH_OVERSHOOT_TILES := 0.6
const FORCED_MOVE_DURATION := 0.22

# New empower parameters
const EMPOWER_HITS: int = 3
const EMPOWER_EXTRA_AD_RATIO: float = 1.0     # +100% AD as extra physical base
const EMPOWER_HEAL_MISSING_PCT: float = 0.20  # 20% of missing HP per empowered hit
const BATTLE_LONG: float = 9999.0

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _stacks(bs, state: BattleState, team: String, index: int, key: String) -> int:
	if bs == null:
		return 0
	# Prefer unified TraitKeys; fall back to legacy key for back-compat
	var trait_key: String = TraitKeys.STRIKER
	var v: int = int(bs.get_stack(state, team, index, trait_key))
	if v > 0:
		return v
	return int(bs.get_stack(state, team, index, key))


func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.state == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	# Apply empower tag on self; empowered hits are handled in impact/post-hit stages
	var meta: Dictionary = {
		"hits_left": EMPOWER_HITS,
		"extra_ad_ratio": EMPOWER_EXTRA_AD_RATIO,
		"heal_missing_pct": EMPOWER_HEAL_MISSING_PCT,
		"block_mana_gain": true
	}
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_BONKO_EMPOWER, BATTLE_LONG, meta)
	ctx.emit_ramp_state("timed_window", EMPOWER_HITS, EMPOWER_EXTRA_AD_RATIO, EMPOWER_HITS, float(EMPOWER_HITS), "bonko_empowered_hits")
	ctx.log("Bonk: empowered next %d attacks (+%d%% AD, heal %d%% missing, no mana)" % [
		EMPOWER_HITS,
		int(round(EMPOWER_EXTRA_AD_RATIO * 100.0)),
		int(round(EMPOWER_HEAL_MISSING_PCT * 100.0))
	])
	return true

func _dash_past_target(ctx: AbilityContext, ts: float, origin: Vector2, target_pos: Vector2) -> void:
	if ctx.engine == null or ctx.engine.arena_state == null or not ctx.engine.arena_state.has_method("notify_forced_movement"):
		return
	var dir: Vector2 = (target_pos - origin)
	if dir.length() <= 0.0:
		return
	var forward: Vector2 = dir.normalized()
	var desired_tiles: float = min(DASH_MAX_TILES, (dir.length() / max(ts, 0.001)) + DASH_OVERSHOOT_TILES)
	if desired_tiles <= 0.0:
		return
	var dash_vec: Vector2 = forward * desired_tiles * ts
	ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, dash_vec, FORCED_MOVE_DURATION)
