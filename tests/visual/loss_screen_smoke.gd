extends Node

const LossScreenScene: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/loss_screen_pass"

func _ready() -> void:
	var failures: Array[String] = []
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_prepare_dirty_run_state()

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "LossOverlayLayer"
	layer.layer = 100
	add_child(layer)

	var screen: LossScreen = LossScreenScene.instantiate() as LossScreen
	screen.z_index = 100
	screen.z_as_relative = false
	screen.configure(null)
	layer.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var stage_label: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/StageLabel") as Label
	_expect(stage_label != null, "StageLabel missing after deferred configure", failures)
	if stage_label != null:
		_expect(stage_label.text == "Stage Reached: 3", "StageLabel did not use live GameState", failures)
	var scoreboard: Node = screen.get_node_or_null("Panel/Center/Frame/VBox/ScoreboardHolder/Scoreboard")
	_expect(scoreboard != null, "Loss scoreboard missing", failures)
	if scoreboard != null:
		var expand_button: Button = scoreboard.find_child("ExpandButton", true, false) as Button
		_expect(expand_button != null, "Loss scoreboard expand button missing", failures)
		if expand_button != null:
			_expect(not expand_button.visible, "Loss scoreboard expand button should be hidden", failures)
			_expect(expand_button.disabled, "Loss scoreboard expand button should be disabled", failures)
		if scoreboard.has_method("set_expanded"):
			scoreboard.call("set_expanded", true)
		var overlay: Control = scoreboard.get("overlay") as Control
		_expect(overlay == null or not overlay.visible, "Loss scoreboard overlay escaped modal", failures)
	_save_capture("loss_overlay_modal_fixed.png")

	screen.call("_on_new_game")
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(int(GameState.stage) == 1, "New Game did not reset GameState.stage", failures)
	_expect(int(Economy.gold) == 2, "New Game did not reset Economy.gold", failures)
	_expect(int(Roster.first_empty_slot()) == 0, "New Game did not clear Roster bench", failures)
	_expect(not is_instance_valid(layer), "New Game did not clear the overlay CanvasLayer", failures)

	if failures.is_empty():
		print("LossScreenSmoke: OK")
	else:
		for failure: String in failures:
			push_error("LossScreenSmoke: " + failure)
	get_tree().quit()

func _prepare_dirty_run_state() -> void:
	if GameState.has_method("set_stage"):
		GameState.set_stage(3)
	if Economy.has_method("add_gold"):
		Economy.add_gold(8)
	var unit: Unit = UnitFactory.spawn("mortem")
	if unit != null:
		Roster.set_slot(0, unit)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy":
		print("LossScreenSmoke: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("LossScreenSmoke: skipped %s because viewport texture is unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("LossScreenSmoke: skipped %s because viewport image is unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		print("LossScreenSmoke: failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(err)])
		return
	print("LossScreenSmoke: saved %s" % ProjectSettings.globalize_path(path))
