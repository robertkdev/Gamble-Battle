extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Control = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var failures: Array[String] = []
	var title_menu: Control = main.get_node_or_null("TitleMenu") as Control
	_expect(title_menu != null, "TitleMenu missing", failures)
	if title_menu != null:
		_expect(title_menu.visible, "TitleMenu is not visible on main start", failures)
		var title_label: Label = title_menu.get_node_or_null("Center/VBox/GameTitle") as Label
		_expect(title_label != null, "GameTitle missing", failures)
		if title_label != null:
			_expect(title_label.get_theme_font_size("font_size") >= 54, "GameTitle is not visually prioritized", failures)
		var hero: TextureRect = title_menu.get_node_or_null("TitleHero") as TextureRect
		_expect(hero != null, "TitleHero missing", failures)
		if hero != null:
			_expect(hero.texture != null, "TitleHero texture missing", failures)
		var content_panel: PanelContainer = title_menu.get_node_or_null("ContentPanel") as PanelContainer
		_expect(content_panel != null, "ContentPanel missing", failures)
		var search_field: LineEdit = title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/SearchField") as LineEdit
		_expect(search_field != null, "SearchField missing", failures)
		var how_to_play_button: Button = title_menu.get_node_or_null("Center/VBox/HowToPlayButton") as Button
		var units_button: Button = title_menu.get_node_or_null("Center/VBox/UnitsButton") as Button
		var rga_button: Button = title_menu.get_node_or_null("Center/VBox/RGAGlossaryButton") as Button
		var settings_button: Button = title_menu.get_node_or_null("Center/VBox/SettingsButton") as Button
		_expect(how_to_play_button != null, "HowToPlayButton missing", failures)
		_expect(units_button != null, "UnitsButton missing", failures)
		_expect(rga_button != null, "RGAGlossaryButton missing", failures)
		_expect(settings_button != null, "SettingsButton missing", failures)
		if units_button != null and search_field != null:
			units_button.emit_signal("pressed")
			await get_tree().process_frame
			search_field.text = "hexeon"
			search_field.emit_signal("text_changed", "hexeon")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "Hexeon") != null, "Unit search did not find Hexeon", failures)
			_expect(_find_label_containing_text(title_menu, "Prismatic Guillotine") != null, "Unit card did not show ability info", failures)
		if rga_button != null and search_field != null:
			rga_button.emit_signal("pressed")
			await get_tree().process_frame
			search_field.text = "PASS"
			search_field.emit_signal("text_changed", "PASS")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "PASS / LEAN / FAIL") != null, "RGA search did not expose verdict terminology", failures)
		if how_to_play_button != null and search_field != null:
			how_to_play_button.emit_signal("pressed")
			await get_tree().process_frame
			search_field.text = "combine"
			search_field.emit_signal("text_changed", "combine")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "combine into a stronger copy") != null, "Tutorial search did not expose combine guidance", failures)
		if settings_button != null:
			settings_button.emit_signal("pressed")
			await get_tree().process_frame
			var volume_slider: HSlider = title_menu.find_child("MasterVolumeSlider", true, false) as HSlider
			_expect(volume_slider != null, "Settings did not expose master volume slider", failures)
		var start_button: Button = title_menu.get_node_or_null("Center/VBox/StartButton") as Button
		_expect(start_button != null, "StartButton missing", failures)
		if start_button != null:
			_expect(start_button.custom_minimum_size.x >= 300.0, "StartButton is not visually prioritized", failures)
			start_button.emit_signal("pressed")
			await get_tree().process_frame
			var unit_select: Control = main.get_node_or_null("UnitSelect") as Control
			_expect(unit_select != null and unit_select.visible, "StartButton did not open UnitSelect", failures)

	if failures.size() > 0:
		for failure: String in failures:
			push_error("TitleMenuSmoke: " + failure)
		get_tree().quit(1)
		return

	print("TitleMenuSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _find_label_containing_text(root: Node, needle: String) -> Label:
	if root == null:
		return null
	var label: Label = root as Label
	if label != null and String(label.text).contains(needle):
		return label
	for child: Node in root.get_children():
		var found: Label = _find_label_containing_text(child, needle)
		if found != null:
			return found
	return null
