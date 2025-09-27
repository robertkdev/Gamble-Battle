extends RefCounted
class_name BattleState

# Central battle data model (no Nodes, no UI)

var stage: int = 1

var player_team: Array[Unit] = []
var enemy_team: Array[Unit] = []

var player_cds: Array[float] = []
var enemy_cds: Array[float] = []
var player_targets: Array[int] = []
var enemy_targets: Array[int] = []

var battle_active: bool = false
var regen_tick_accum: float = 0.0

# Mentor–Pupil pairing (planning-time; frozen for the battle)
# Arrays map mentor index -> pupil index (or -1 if none)
var player_pupil_map: Array[int] = []
var enemy_pupil_map: Array[int] = []

# Per-unit damage dealt this round (resets each battle)
var player_damage_this_round: Array[int] = []
var enemy_damage_this_round: Array[int] = []

func reset() -> void:
	player_team.clear()
	enemy_team.clear()
	player_cds.clear()
	enemy_cds.clear()
	player_targets.clear()
	enemy_targets.clear()
	battle_active = false
	regen_tick_accum = 0.0
	player_pupil_map.clear()
	enemy_pupil_map.clear()
	player_damage_this_round.clear()
	enemy_damage_this_round.clear()

static func ensure_size(arr: Array, size: int, fill) -> Array:
	var out: Array = []
	for v in arr:
		out.append(v)
	while out.size() < size:
		out.append(fill)
	return out

static func fill_cds_for(team: Array[Unit]) -> Array[float]:
	var cds: Array[float] = []
	for u in team:
		cds.append(0.0 if u else 1.0)
	return cds

static func all_dead(team: Array[Unit]) -> bool:
	for u in team:
		if u and u.is_alive():
			return false
	return true

static func first_alive(team: Array[Unit]) -> Unit:
	for u in team:
		if u and u.is_alive():
			return u
	return null

static func unit_at(team: Array[Unit], idx: int) -> Unit:
	if idx < 0 or idx >= team.size():
		return null
	return team[idx]

static func is_target_alive(team: Array[Unit], idx: int) -> bool:
	var u := unit_at(team, idx)
	return u != null and u.is_alive()
