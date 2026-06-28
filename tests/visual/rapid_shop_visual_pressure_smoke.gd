extends "res://tests/visual/production_rapid_shop_pressure_smoke.gd"

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const VISUAL_SMOKE_NAME: String = "RapidShopVisualPressureSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/rapid_shop_pressure_pass"

var _saved_captures: int = 0

func _smoke_name() -> String:
	return VISUAL_SMOKE_NAME

func _after_rapid_purchase_checkpoint(expected_ids: Array[String]) -> void:
	await _settle_frames(4)
	_expect(expected_ids.size() == int(ShopConfig.SLOT_COUNT), "visual rapid shop should purchase every shop slot")
	_expect(_label_count_in_shop_grid("SOLD") == expected_ids.size(), "visual rapid shop should show SOLD on every purchased slot")
	_expect(_label_count_in_shop_grid("On bench") == expected_ids.size(), "visual rapid shop should show On bench on every purchased slot")
	_normalize_capture_timer()
	_save_capture("01_after_rapid_purchases.png")

func _after_rapid_deploy_checkpoint(expected_ids: Array[String]) -> void:
	await _settle_frames(4)
	_expect(_bench_ids().is_empty(), "visual rapid shop should have empty bench after deploy")
	_expect(_board_ids().size() >= expected_ids.size() + 1, "visual rapid shop should show starter plus deployed purchases on board")
	_normalize_capture_timer()
	_save_capture("02_after_rapid_deploy.png")

func _normalize_capture_timer() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 60.0)
	combat.set("planning_time_left", 60.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.text = "Planning: 1:00"

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [VISUAL_SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [VISUAL_SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: failed to save %s error=%s" % [VISUAL_SMOKE_NAME, ProjectSettings.globalize_path(path), str(int(error))])
		return
	_saved_captures += 1
	print("%s: saved %s" % [VISUAL_SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _save_vision_capture(filename: String) -> void:
	var root_node: Node = _main if _main != null else self
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(root_node, filename.get_basename(), OUTPUT_DIR)
	if not bool(result.get("ok", false)):
		push_error("%s: vision fallback failed for %s reason=%s" % [VISUAL_SMOKE_NAME, filename, str(result.get("reason", ""))])
		return
	_saved_captures += 1
	print("%s: saved %s via %s" % [VISUAL_SMOKE_NAME, ProjectSettings.globalize_path(str(result.get("path", ""))), str(result.get("kind", ""))])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _finish() -> void:
	print("%s: captures=%d output=%s" % [VISUAL_SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	super._finish()
