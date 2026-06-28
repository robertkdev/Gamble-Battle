extends Node

const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: UnitSelect = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame

	var failures: Array[String] = []
	var roster_plate: Panel = view.get_node_or_null("GothicRosterPlate") as Panel
	_expect(roster_plate != null, "Roster gothic plate missing", failures)
	if roster_plate != null:
		_expect(roster_plate.size.y > 300.0, "Roster gothic plate collapsed", failures)
	var preview_plate: Panel = view.get_node_or_null("GothicPreviewPlate") as Panel
	_expect(preview_plate != null, "Preview gothic plate missing", failures)
	if preview_plate != null:
		_expect(preview_plate.size.y > 300.0, "Preview gothic plate collapsed", failures)
	var heading: Label = view.get_node_or_null("Center/HBox/Left/Label") as Label
	_expect(heading != null, "Heading missing", failures)
	if heading != null:
		_expect(heading.get_theme_font_size("font_size") >= 36, "Heading is not visually prioritized", failures)
	var start_button: Button = view.get_node_or_null("Center/HBox/Right/StartButton") as Button
	_expect(start_button != null, "StartButton missing", failures)
	if start_button != null:
		_expect(start_button.disabled, "StartButton should begin disabled", failures)
		_expect(start_button.custom_minimum_size.x >= 500.0, "StartButton width is not visually prioritized", failures)
	var selected_label: Label = view.get_node_or_null("Center/HBox/Right/Preview/SelectedLabel") as Label
	_expect(selected_label != null and selected_label.text == "No champion chosen", "Unit Select should begin with no inspected champion", failures)
	var details_label: Label = view.get_node_or_null("Center/HBox/Right/Preview/Details") as Label
	_expect(details_label != null and details_label.text == "Hover a unit to preview", "Unit Select should begin with neutral preview help", failures)
	var initial_art: TextureRect = view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap/Art") as TextureRect
	_expect(initial_art != null and initial_art.texture == null, "Unit Select should begin without default preview art", failures)
	_verify_rendered_starter_surface(view, failures)
	var sari_button: Button = _button_for_unit(view, "sari")
	_expect(sari_button != null, "Sari starter button missing", failures)
	if sari_button != null:
		sari_button.emit_signal("mouse_entered")
		await get_tree().process_frame
		await get_tree().process_frame
		var role_badge: Label = view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel/RoleBadge") as Label
		_expect(role_badge != null and role_badge.visible, "Sari preview role badge missing", failures)
		if role_badge != null:
			_expect(role_badge.size.x <= 220.0, "Sari role badge should not stretch across the preview panel", failures)
		_expect(details_label != null and String(details_label.text).find("Identity summary above") < 0, "Sari preview should not show identity placeholder copy", failures)
		_expect(details_label != null and String(details_label.text).find("Traits:") >= 0, "Sari preview should show readable traits/identity tags", failures)
		_expect(details_label != null and String(details_label.text).find("Attack:") >= 0, "Starter preview should show attack details", failures)
		_expect(details_label != null and String(details_label.text).find("Ability:") >= 0, "Starter preview should show ability details", failures)
		sari_button.emit_signal("mouse_exited")
		await get_tree().process_frame
	var first_button: Button = view.find_child("UnitButton_*", true, false) as Button
	_expect(first_button != null, "No generated unit buttons found", failures)
	if first_button != null:
		_expect(first_button.custom_minimum_size.x >= 150.0, "Unit card button width too small", failures)
		first_button.emit_signal("pressed")
		await get_tree().process_frame
		_expect(not start_button.disabled, "StartButton did not enable after unit selection", failures)
		_expect(selected_label != null and selected_label.text != "No champion chosen", "Selection label did not update", failures)
		var art: TextureRect = view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap/Art") as TextureRect
		_expect(art != null and art.texture != null, "Preview art did not load", failures)
		view.reset_selection()
		await get_tree().process_frame
		_expect(start_button.disabled, "StartButton did not disable after reset_selection", failures)
		_expect(view.selected_id == "", "selected_id did not clear after reset_selection", failures)
		_expect(selected_label != null and selected_label.text == "No champion chosen", "Selection label did not reset", failures)
		_expect(art != null and art.texture == null, "Preview art did not clear after reset_selection", failures)
		var unit_id: String = String(first_button.get_meta("unit_id")) if first_button.has_meta("unit_id") else ""
		if unit_id != "":
			first_button.emit_signal("mouse_entered")
			await get_tree().process_frame
			_expect(selected_label != null and selected_label.text.begins_with("Inspecting "), "Hover preview did not show inspecting state", failures)
			var scroll: ScrollContainer = view.get_node_or_null("Center/HBox/Left/Scroll") as ScrollContainer
			var scroll_bar: VScrollBar = scroll.get_v_scroll_bar() if scroll != null else null
			if scroll_bar != null and scroll_bar.max_value > scroll_bar.min_value:
				var start_value: float = float(scroll.scroll_vertical)
				var target_value: float = float(scroll_bar.max_value)
				if absf(target_value - start_value) < 0.5:
					target_value = float(scroll_bar.min_value)
				scroll.scroll_vertical = int(roundf(target_value))
				await get_tree().process_frame
				var moved_value: float = float(scroll.scroll_vertical)
				if absf(moved_value - start_value) >= 0.5:
					await get_tree().process_frame
					await get_tree().process_frame
					_expect(view.selected_id == "", "Scroll should not select a unit", failures)
					_expect(selected_label != null and selected_label.text == "No champion chosen", "Scroll did not clear stale hover preview", failures)

	if failures.size() > 0:
		for failure: String in failures:
			push_error("UnitSelectSmoke: " + failure)
		get_tree().quit(1)
		return

	print("UnitSelectSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _verify_rendered_starter_surface(view: UnitSelect, failures: Array[String]) -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var expected_ids: Array[String] = _sorted_string_copy(catalog.list_starter_ids(ShopConfig.STARTING_LEVEL))
	var rendered_ids: Array[String] = _rendered_unit_button_ids(view)
	_expect_lists_equal("rendered starter ids", expected_ids, rendered_ids, failures)
	_expect(not rendered_ids.has("hexeon"), "Hexeon should remain hidden from the level-1 starter picker", failures)
	for unit_id: String in rendered_ids:
		var meta: Dictionary = catalog.get_unit_meta(unit_id)
		var cost: int = int(meta.get("cost", 0))
		_expect(cost == 1, "starter %s should be cost 1, got %d" % [unit_id, cost], failures)

func _rendered_unit_button_ids(view: UnitSelect) -> Array[String]:
	var ids: Array[String] = []
	var buttons: Array[Node] = view.find_children("UnitButton_*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button == null or not button.has_meta("unit_id"):
			continue
		ids.append(String(button.get_meta("unit_id")))
	ids.sort()
	return ids

func _button_for_unit(view: UnitSelect, unit_id: String) -> Button:
	var buttons: Array[Node] = view.find_children("UnitButton_*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and button.has_meta("unit_id") and String(button.get_meta("unit_id")) == unit_id:
			return button
	return null

func _sorted_string_copy(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(String(value))
	out.sort()
	return out

func _expect_lists_equal(label: String, expected: Array[String], actual: Array[String], failures: Array[String]) -> void:
	var expected_text: String = ",".join(PackedStringArray(expected))
	var actual_text: String = ",".join(PackedStringArray(actual))
	if expected_text != actual_text:
		failures.append("%s expected [%s] got [%s]" % [label, expected_text, actual_text])
