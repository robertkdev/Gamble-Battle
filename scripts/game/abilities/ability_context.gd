extends RefCounted
class_name AbilityContext

const AbilityEffects = preload("res://scripts/game/abilities/effects.gd")
const TraitCompiler = preload("res://scripts/game/traits/trait_compiler.gd")
const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

var engine: CombatEngine
var state: BattleState
var rng: RandomNumberGenerator
var caster_team: String = ""
var caster_index: int = -1
var buff_system: BuffSystem = null

func _init(_engine: CombatEngine, _state: BattleState, _rng: RandomNumberGenerator, _caster_team: String, _caster_index: int) -> void:
	engine = _engine
	state = _state
	rng = _rng
	caster_team = _caster_team
	caster_index = _caster_index

# --- Read-only accessors ---
func unit_at(team: String, idx: int) -> Unit:
	if team == "player":
		if idx >= 0 and idx < state.player_team.size():
			return state.player_team[idx]
	else:
		if idx >= 0 and idx < state.enemy_team.size():
			return state.enemy_team[idx]
	return null

func ally_team_array(team: String) -> Array[Unit]:
	return state.player_team if team == "player" else state.enemy_team

func enemy_team_array(team: String) -> Array[Unit]:
	return state.enemy_team if team == "player" else state.player_team

func is_alive(team: String, idx: int) -> bool:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	return BattleState.is_target_alive(arr, idx)

# --- Selectors ---
func current_target(team: String, idx: int) -> int:
	if engine == null:
		return -1
	return engine.target_controller.current_target(team, idx)

func lowest_hp_ally(team: String) -> int:
	var arr: Array[Unit] = ally_team_array(team)
	var best_idx: int = -1
	var best_hp: int = 1 << 30
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u and u.is_alive():
			if u.hp < best_hp:
				best_hp = int(u.hp)
				best_idx = i
	return best_idx

func lowest_hp_enemy(team: String) -> int:
	var arr: Array[Unit] = enemy_team_array(team)
	var best_idx: int = -1
	var best_hp: int = 1 << 30
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u and u.is_alive():
			if u.hp < best_hp:
				best_hp = int(u.hp)
				best_idx = i
	return best_idx

# Position helpers
func tile_size() -> float:
	if engine != null and engine.arena_state != null:
		return float(engine.arena_state.tile_size())
	return 1.0

func position_of(team: String, idx: int) -> Vector2:
	if engine == null:
		return Vector2.ZERO
	return engine.get_player_position(idx) if team == "player" else engine.get_enemy_position(idx)

func _enemy_indices_alive(team: String) -> Array[int]:
	var arr: Array[int] = []
	var enemies: Array[Unit] = enemy_team_array(team)
	for i in range(enemies.size()):
		var u: Unit = enemies[i]
		if u and u.is_alive():
			arr.append(i)
	return arr

# Geometric selectors (tile-aware; use MovementMath and MovementService tuning
# epsilon so range checks behave consistently with movement/attacks.)
func enemies_in_radius(team: String, center_index: int, radius_tiles: float) -> Array[int]:
	var out: Array[int] = []
	var center: Vector2 = position_of(team, center_index)
	var ts: float = tile_size()
	var epsilon: float = _range_epsilon()
	var band_mult: float = _band_max_for(team, center_index)
	for i in _enemy_indices_alive(team):
		var p: Vector2 = position_of(_other_team(team), i)
		if MovementMath.within_radius_tiles(center, p, radius_tiles * band_mult, ts, epsilon):
			out.append(i)
	return out

func enemies_in_radius_at(team: String, center_world: Vector2, radius_tiles: float) -> Array[int]:
	var out: Array[int] = []
	var ts: float = tile_size()
	var epsilon: float = _range_epsilon()
	for i in _enemy_indices_alive(team):
		var p: Vector2 = position_of(_other_team(team), i)
		if MovementMath.within_radius_tiles(center_world, p, radius_tiles, ts, epsilon):
			out.append(i)
	return out

func enemies_in_line(team: String, shooter_index: int, target_index: int, length_tiles: float, width_tiles: float = 0.5) -> Array[int]:
	var out: Array[int] = []
	var start: Vector2 = position_of(team, shooter_index)
	var end: Vector2 = position_of(_other_team(team), target_index)
	var dir: Vector2 = (end - start)
	if dir.length() == 0.0:
		return out
	var len_w: float = max(0.0, length_tiles) * tile_size()
	# Expand half-width by epsilon to keep edge behavior consistent
	var half_w: float = max(0.0, width_tiles) * tile_size() * 0.5 + _range_epsilon()
	var fwd: Vector2 = dir.normalized()
	for i in _enemy_indices_alive(team):
		var p: Vector2 = position_of(_other_team(team), i)
		var rel: Vector2 = p - start
		var proj: float = rel.dot(fwd)
		if proj < 0.0 or proj > len_w:
			continue
		var perp: float = abs(rel.cross(fwd)) # area of parallelogram per unit length = distance
		if perp <= half_w:
			out.append(i)
	return out

func two_nearest_enemies(team: String) -> Array[int]:
	var out: Array[int] = []
	var src: Vector2 = position_of(team, caster_index)
	var pairs: Array = []
	for i in _enemy_indices_alive(team):
		var p: Vector2 = position_of(_other_team(team), i)
		pairs.append({"i": i, "d": src.distance_to(p)})
	pairs.sort_custom(func(a, b): return float(a.d) < float(b.d))
	for k in range(min(2, pairs.size())):
		out.append(int(pairs[k].i))
	return out

func two_furthest_enemies(team: String) -> Array[int]:
	var out: Array[int] = []
	var src: Vector2 = position_of(team, caster_index)
	var pairs: Array = []
	for i in _enemy_indices_alive(team):
		var p: Vector2 = position_of(_other_team(team), i)
		pairs.append({"i": i, "d": src.distance_to(p)})
	pairs.sort_custom(func(a, b): return float(a.d) > float(b.d))
	for k in range(min(2, pairs.size())):
		out.append(int(pairs[k].i))
	return out

# Traits (lazy compile)
var _traits_cache_player: Dictionary = {}
var _traits_cache_enemy: Dictionary = {}

func traits(team: String) -> Dictionary:
	if team == "player":
		if _traits_cache_player.is_empty():
			_traits_cache_player = TraitCompiler.compile(state.player_team)
		return _traits_cache_player
	else:
		if _traits_cache_enemy.is_empty():
			_traits_cache_enemy = TraitCompiler.compile(state.enemy_team)
		return _traits_cache_enemy

func trait_tier(team: String, trait_id: String) -> int:
	var t: Dictionary = traits(team)
	var tiers: Dictionary = t.get("tiers", {})
	return int(tiers.get(trait_id, -1))

func trait_count(team: String, trait_id: String) -> int:
	var t: Dictionary = traits(team)
	var counts: Dictionary = t.get("counts", {})
	return int(counts.get(trait_id, 0))

# Exile upgrade helper for abilities: returns 0 if none, or 1..3 when active.
func exile_upgrade_level(team: String, index: int) -> int:
	if buff_system == null:
		return 0
	if not buff_system.has_tag(state, team, index, BuffTags.TAG_EXILE_UPGRADE):
		return 0
	var data: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_EXILE_UPGRADE)
	return int(data.get("level", 0))

func _other_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

# --- Mentor–Pupil pairing ---
func pupil_for(team: String, mentor_index: int) -> int:
	if state == null or mentor_index < 0:
		return -1
	if team == "player":
		if mentor_index < state.player_pupil_map.size():
			return int(state.player_pupil_map[mentor_index])
	else:
		if mentor_index < state.enemy_pupil_map.size():
			return int(state.enemy_pupil_map[mentor_index])
	return -1

# --- Effects ---
# Deals physical/magic/true damage in-place using shared mitigation.
# type: "physical" | "magic" | "true" | "hybrid"
func damage_single(source_team: String, source_index: int, target_index: int, amount: float, type: String = "physical") -> Dictionary:
	return AbilityEffects.damage_single(engine, state, source_team, source_index, target_index, amount, type)

func heal_single(target_team: String, target_index: int, amount: float) -> Dictionary:
	return AbilityEffects.heal_single(engine, state, target_team, target_index, amount)

func log(text: String) -> void:
	if text == "" or engine == null:
		return
	engine._resolver_emit_log(text)
# Shared epsilon sourced from movement tuning to keep range consistent
func _range_epsilon() -> float:
	if engine != null and engine.arena_state != null:
		return float(engine.arena_state.tuning.range_epsilon)
	return 0.5

# Movement profile band (hysteresis) helper for abilities that use unit-centered
# ranges. This keeps ability radii consistent with approach/attack bands.
func _band_max_for(team: String, idx: int) -> float:
	if engine != null and engine.arena_state != null and engine.arena_state.has_method("get_profile"):
		var prof = engine.arena_state.get_profile(team, idx)
		if prof != null and typeof(prof.band_max) in [TYPE_FLOAT, TYPE_INT]:
			return float(prof.band_max)
	return 1.0
