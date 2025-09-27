extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")
const LinkUtils := preload("res://scripts/game/traits/runtime/link_utils.gd")

const TRAIT_ID := "Liaison"

const PCT_PER_LINK := [0.05, 0.10, 0.15] # tiers (1,3,5) -> indices 0..2
const TICK_SECONDS := 2.0
const BATTLE_LONG := 9999.0

var _accum_player
var _accum_enemy
var _tris_player: Array = []
var _tris_enemy: Array = []

func on_battle_start(ctx):
	assert(ctx != null and ctx.state != null)
	assert(ctx.buff_system != null)
	_accum_player = LinkUtils.make_accumulator(TICK_SECONDS)
	_accum_enemy = LinkUtils.make_accumulator(TICK_SECONDS)
	_tris_player = []
	_tris_enemy = []
	_apply_for_team(ctx, "player")
	_apply_for_team(ctx, "enemy")

func on_tick(ctx, delta: float):
	if delta <= 0.0 or ctx == null or ctx.engine == null:
		return
	if _accum_player != null and _tris_player.size() > 0:
		_accum_player.accumulate(delta)
		var n: int = _accum_player.consume_pulses()
		if n > 0:
			_grant_triangle_mana(ctx, "player", _tris_player, n)
	if _accum_enemy != null and _tris_enemy.size() > 0:
		_accum_enemy.accumulate(delta)
		var m: int = _accum_enemy.consume_pulses()
		if m > 0:
			_grant_triangle_mana(ctx, "enemy", _tris_enemy, m)

func _apply_for_team(ctx, team: String) -> void:
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 0:
		return
	var pct: float = StackUtils.value_by_tier(t, PCT_PER_LINK)
	if pct <= 0.0 and t < 1:
		return
	var engine = ctx.engine
	if engine == null or engine.arena_state == null:
		return
	# Gather planning-phase positions
	var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
	var positions: Array[Vector2] = []
	for i in range(arr.size()):
		var p: Vector2 = (engine.arena_state.get_player_position(i) if team == "player" else engine.arena_state.get_enemy_position(i))
		positions.append(p)
	var ts: float = engine.arena_state.tile_size()
	var eps: float = (engine.arena_state.tuning.range_epsilon if engine.arena_state != null and engine.arena_state.has_method("tile_size") else 0.1)
	var res: Dictionary = LinkUtils.compute(arr, positions, ts, float(eps))
	var degrees = res.get("degrees", [])
	var triangles: Array = res.get("triangles", [])
	# Persist triangles for periodic mana
	if team == "player":
		_tris_player = triangles
	else:
		_tris_enemy = triangles
	# Apply per-link buffs per unit (damage modeled as AD/SP increase)
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null:
			continue
		var k: int = 0
		if i < degrees.size():
			k = int(degrees[i])
		if k <= 0:
			continue
		var fields: Dictionary = {}
		var dmg_pct_total: float = pct * float(k)
		# +% damage modeled as +% AD and +% SP
		var ad_delta: float = float(u.attack_damage) * dmg_pct_total
		var sp_delta: float = float(u.spell_power) * dmg_pct_total
		if ad_delta != 0.0:
			fields["attack_damage"] = ad_delta
		if sp_delta != 0.0:
			fields["spell_power"] = sp_delta
		fields["damage_reduction"] = dmg_pct_total
		ctx.buff_system.apply_stats_buff(ctx.state, team, i, fields, BATTLE_LONG)

func _grant_triangle_mana(ctx, team: String, tris: Array, pulses: int) -> void:
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 1:
		return
	var per_pulse: int = (1 if t == 1 else (2 if t >= 2 else 0))
	if per_pulse <= 0:
		return
	var grant: int = per_pulse * max(1, pulses)
	var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
	for tri in tris:
		if typeof(tri) != TYPE_ARRAY:
			continue
		for vi in tri:
			var idx: int = int(vi)
			if idx < 0 or idx >= arr.size():
				continue
			var u: Unit = arr[idx]
			if u == null or not u.is_alive():
				continue
			if int(u.mana_max) <= 0:
				continue
			u.mana = min(int(u.mana_max), int(u.mana) + grant)
			if ctx.engine != null and ctx.engine.has_method("_resolver_emit_unit_stat"):
				ctx.engine._resolver_emit_unit_stat(team, idx, {"mana": u.mana})
