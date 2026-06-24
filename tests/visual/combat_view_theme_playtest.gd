extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = COMBAT_VIEW_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	if view.has_method("set_player_team_ids"):
		view.call("set_player_team_ids", ["bonko", "paisley"])
	await get_tree().process_frame
	if view.has_method("_on_continue_pressed"):
		view.call("_on_continue_pressed")
	await get_tree().create_timer(2.0).timeout
	var manager: CombatManager = view.get("manager")
	var engine: Variant = manager.get_engine() if manager != null else null
	if engine == null:
		push_error("CombatViewThemePlaytest: combat engine did not start")
		get_tree().quit(1)
		return
	if engine.state == null or not bool(engine.state.battle_active):
		push_error("CombatViewThemePlaytest: battle is not active")
		get_tree().quit(1)
		return
	print("CombatViewThemePlaytest: OK elapsed=%.2f" % float(engine.state.elapsed_time))
	get_tree().quit(0)
