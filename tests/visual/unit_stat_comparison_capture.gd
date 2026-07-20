extends Node

const UnitPanelScene: PackedScene = preload("res://scenes/ui/stats/UnitPanel.tscn")
const UnitFactory: GDScript = preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/unit_stat_comparison_pass"

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport_size: Vector2i = Vector2i(1280, 720)
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.010, 0.009, 0.013, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	backdrop.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	var player: Unit = UnitFactory.spawn_at_level("axiom", 1)
	var enemy: Unit = UnitFactory.spawn_at_level("berebell", 1)
	if player == null or enemy == null:
		_failures.append("comparison fixture units failed to spawn")
		_finish()
		return
	player.max_hp += 90
	player.hp = player.max_hp
	player.attack_damage += 18.0
	enemy.max_hp += 120
	enemy.hp = enemy.max_hp
	enemy.armor += 14.0

	var player_panel: Control = _add_panel(row, "FRIENDLY — MODIFIED", "player", player)
	var enemy_panel: Control = _add_panel(row, "ENEMY — MODIFIED", "enemy", enemy)
	await _settle_frames(8)
	_assert_comparison_panel(player_panel, "friendly")
	_assert_comparison_panel(enemy_panel, "enemy")
	_save_capture("01_friendly_enemy_base_current.png")
	_finish()

func _add_panel(parent: HBoxContainer, heading_text: String, team: String, unit: Unit) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var heading: Label = Label.new()
	heading.text = heading_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.94, 0.72, 0.38, 1.0))
	column.add_child(heading)
	var panel: Control = UnitPanelScene.instantiate() as Control
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	if panel.has_method("set_target"):
		panel.call("set_target", team, 0, unit)
	return panel

func _assert_comparison_panel(panel: Control, context: String) -> void:
	if panel == null:
		_failures.append("%s panel missing" % context)
		return
	var legend: Label = panel.find_child("StatComparisonLegend", true, false) as Label
	if legend == null or legend.text != "BASE > CURRENT  (DELTA)":
		_failures.append("%s comparison legend missing" % context)
	var comparison_value_found: bool = false
	var changed_delta_found: bool = false
	for node: Node in panel.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label == null:
			continue
		var text: String = String(label.text)
		if label.name != "StatComparisonLegend" and text.contains(">"):
			comparison_value_found = true
		if label.name == "Delta" and text != "(0)" and text != "(0.00)":
			changed_delta_found = true
	if not comparison_value_found:
		_failures.append("%s base/current values missing" % context)
	if not changed_delta_found:
		_failures.append("%s changed delta missing" % context)

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport texture unavailable")
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("viewport image unavailable")
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("capture failed error=%d" % int(error))
		return
	print("UnitStatComparisonCapture: saved %s" % ProjectSettings.globalize_path(path))

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("UnitStatComparisonCapture: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("UnitStatComparisonCapture: " + failure)
	get_tree().quit(1)
