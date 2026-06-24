extends Node

const AgentBattleLabScene: PackedScene = preload("res://scenes/tools/AgentBattleLab.tscn")

var lab: Control = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	lab = AgentBattleLabScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	lab.call("_preset_items")
	lab.call("_speed_8x")
	lab.call("_start_battle")
	await get_tree().create_timer(12.0).timeout
	var hits: int = int(lab.get("hit_count"))
	var abilities: int = int(lab.get("ability_count"))
	var player_damage: int = int(lab.get("player_damage"))
	var enemy_damage: int = int(lab.get("enemy_damage"))
	var battle_running: bool = bool(lab.get("battle_running"))
	var target_map: Dictionary[String, String] = lab.get("target_map")
	var manager: CombatManager = lab.get("manager")
	var engine: Variant = manager.get_engine() if manager != null else null
	var elapsed: float = 0.0
	var active: bool = false
	var player_cds: String = "[]"
	var enemy_cds: String = "[]"
	var player_positions: String = "[]"
	var enemy_positions: String = "[]"
	if engine != null and engine.state != null:
		elapsed = float(engine.state.elapsed_time)
		active = bool(engine.state.battle_active)
		player_cds = str(engine.state.player_cds)
		enemy_cds = str(engine.state.enemy_cds)
		player_positions = str(engine.get_player_positions_copy())
		enemy_positions = str(engine.get_enemy_positions_copy())
	Engine.time_scale = 1.0
	if hits <= 0:
		push_error("AgentBattleLabSmoke: expected at least one hit event; running=%s active=%s elapsed=%.2f targets=%s pcd=%s ecd=%s ppos=%s epos=%s" % [str(battle_running), str(active), elapsed, str(target_map), player_cds, enemy_cds, player_positions, enemy_positions])
		get_tree().quit(1)
		return
	if player_damage <= 0 and enemy_damage <= 0:
		push_error("AgentBattleLabSmoke: expected combat damage")
		get_tree().quit(1)
		return
	print("AgentBattleLabSmoke: item battle OK hits=%d abilities=%d player_damage=%d enemy_damage=%d" % [hits, abilities, player_damage, enemy_damage])
	lab.call("_reset_battle")
	await get_tree().process_frame
	lab.call("_preset_movement")
	lab.call("_speed_8x")
	lab.call("_start_battle")
	await get_tree().process_frame
	manager = lab.get("manager")
	engine = manager.get_engine() if manager != null else null
	var start_positions: Array[Vector2] = _positions_from_engine(engine, true)
	await get_tree().create_timer(4.0).timeout
	var end_positions: Array[Vector2] = _positions_from_engine(engine, true)
	Engine.time_scale = 1.0
	var moved_distance: float = _movement_delta(start_positions, end_positions)
	if moved_distance <= 1.0:
		push_error("AgentBattleLabSmoke: expected movement position updates; start=%s end=%s" % [str(start_positions), str(end_positions)])
		get_tree().quit(1)
		return
	lab.call("_reset_battle")
	await get_tree().process_frame
	print("AgentBattleLabSmoke: OK hits=%d abilities=%d player_damage=%d enemy_damage=%d movement_delta=%.2f" % [hits, abilities, player_damage, enemy_damage, moved_distance])
	get_tree().quit(0)

func _positions_from_engine(engine: Variant, player_team: bool) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if engine == null:
		return positions
	var raw_value: Variant = engine.get_player_positions_copy() if player_team else engine.get_enemy_positions_copy()
	if raw_value is Array:
		for raw_position in raw_value:
			if raw_position is Vector2:
				positions.append(raw_position)
	return positions

func _movement_delta(start_positions: Array[Vector2], end_positions: Array[Vector2]) -> float:
	var total: float = 0.0
	var count: int = min(start_positions.size(), end_positions.size())
	for i in range(count):
		var index: int = int(i)
		total += start_positions[index].distance_to(end_positions[index])
	return total
