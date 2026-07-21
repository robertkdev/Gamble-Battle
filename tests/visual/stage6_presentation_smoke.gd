extends Node

const BattlePhaseStinger: GDScript = preload("res://scripts/ui/combat/battle_phase_stinger.gd")
const ArenaControllerClass: GDScript = preload("res://scripts/ui/combat/arena_controller.gd")
const UnitActorClass: GDScript = preload("res://scripts/ui/combat/unit_actor.gd")
const UNIT_IDS: Array[String] = ["axiom", "berebell", "bo", "bonko", "brute", "cashmere"]

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_phase_stinger()
	await _test_health_bar_collision_layout()
	if _failures.is_empty():
		print("Stage6PresentationSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("Stage6PresentationSmoke: " + failure)
	get_tree().quit(1)

func _test_phase_stinger() -> void:
	var host: Control = Control.new()
	host.size = Vector2(1280.0, 720.0)
	add_child(host)
	var stinger: BattlePhaseStinger = BattlePhaseStinger.new() as BattlePhaseStinger
	host.add_child(stinger)
	await get_tree().process_frame
	stinger.set_motion_enabled(false)
	stinger.play_round(4, 1, 3, true)
	await get_tree().process_frame
	var snapshot: Dictionary[String, Variant] = stinger.presentation_snapshot()
	_expect(bool(stinger.visible), "boss stinger should be visible during hold")
	_expect(String(snapshot.get("cue", "")) == "hold", "disabled-motion stinger should settle at hold")
	_expect(String(snapshot.get("title", "")) == "BOSS CONTRACT", "boss stinger title missing")
	_expect(String(snapshot.get("detail", "")).contains("WAGER 3G LOCKED"), "boss stinger wager consequence missing")
	_expect(bool(snapshot.get("boss", false)), "boss stinger mode missing")
	_expect(int(snapshot.get("mouse_filter", -1)) == Control.MOUSE_FILTER_IGNORE, "stinger must remain input-transparent")
	_expect(int(snapshot.get("z_index", 0)) < 158, "stinger must stay below result ceremony")
	stinger.cancel()
	_expect(not stinger.visible, "cancel should hide stinger")
	host.queue_free()
	await get_tree().process_frame

func _test_health_bar_collision_layout() -> void:
	var arena_units: Control = Control.new()
	arena_units.position = Vector2(100.0, 80.0)
	arena_units.size = Vector2(760.0, 500.0)
	add_child(arena_units)
	var arena: ArenaController = ArenaControllerClass.new() as ArenaController
	arena.arena_units = arena_units
	for index: int in range(UNIT_IDS.size()):
		var actor: UnitActor = UnitActorClass.new() as UnitActor
		actor.set_unit(UnitFactory.spawn(UNIT_IDS[index]))
		actor.set_team_tint(Color(0.12, 0.30, 0.46, 0.72) if index < 3 else Color(0.54, 0.06, 0.09, 0.76))
		arena_units.add_child(actor)
		actor.set_size_px(Vector2(72.0, 72.0))
		var cluster_position: Vector2 = arena_units.global_position + Vector2(350.0 + float(index % 3) * 10.0, 260.0 + float(index / 3) * 12.0)
		actor.set_screen_position(cluster_position)
		if index < 3:
			arena.player_actors.append(actor)
		else:
			arena.enemy_actors.append(actor)
	await get_tree().process_frame
	arena.refresh_bar_layout()
	await get_tree().process_frame
	var snapshot: Array[Dictionary] = arena.bar_layout_snapshot()
	_expect(snapshot.size() == UNIT_IDS.size(), "bar layout snapshot should include every visible actor")
	var shifted_count: int = 0
	var rects: Array[Rect2] = []
	var bounds: Rect2 = arena_units.get_global_rect()
	for entry: Dictionary in snapshot:
		var offset_value: Variant = entry.get("offset", Vector2.ZERO)
		var rect_value: Variant = entry.get("rect", Rect2())
		if offset_value is Vector2 and not (offset_value as Vector2).is_zero_approx():
			shifted_count += 1
		if rect_value is Rect2:
			var rect: Rect2 = rect_value as Rect2
			_expect(bounds.encloses(rect), "resolved health bar left arena bounds: %s" % str(rect))
			for placed: Rect2 in rects:
				_expect(not rect.intersects(placed.grow(1.0)), "resolved health bars still overlap: %s vs %s" % [str(rect), str(placed)])
			rects.append(rect)
	_expect(shifted_count >= 2, "dense cluster should move multiple health bars")
	arena_units.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
