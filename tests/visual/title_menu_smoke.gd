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
			_expect(title_label.get_theme_font_size("font_size") >= 80, "GameTitle is not visually prioritized", failures)
		var hero: TextureRect = title_menu.get_node_or_null("TitleHero") as TextureRect
		_expect(hero != null, "TitleHero missing", failures)
		if hero != null:
			_expect(hero.texture != null, "TitleHero texture missing", failures)
		var start_button: Button = title_menu.get_node_or_null("Center/VBox/StartButton") as Button
		_expect(start_button != null, "StartButton missing", failures)
		if start_button != null:
			_expect(start_button.custom_minimum_size.x >= 460.0, "StartButton is not visually prioritized", failures)
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
