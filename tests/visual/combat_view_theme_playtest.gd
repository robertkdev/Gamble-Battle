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
		_finish(view, 1)
		return
	if engine.state == null or not bool(engine.state.battle_active):
		push_error("CombatViewThemePlaytest: battle is not active")
		_finish(view, 1)
		return
	print("CombatViewThemePlaytest: OK elapsed=%.2f" % float(engine.state.elapsed_time))
	_finish(view, 0)

func _finish(view: Control, code: int) -> void:
	if view != null and is_instance_valid(view):
		if view.has_method("_teardown"):
			view.call("_teardown")
		var parent_node: Node = view.get_parent()
		if parent_node != null:
			parent_node.remove_child(view)
		view.free()
	if get_tree() != null:
		get_tree().quit(code)
