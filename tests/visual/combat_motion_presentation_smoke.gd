extends Node

const SMOKE_NAME: String = "CombatMotionPresentationSmoke"
const UnitActorScript: GDScript = preload("res://scripts/ui/combat/unit_actor.gd")

var _actor: UnitActor = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_actor = UnitActorScript.new() as UnitActor
	if _actor == null:
		_fail("UnitActor construction failed")
		_finish()
		return
	add_child(_actor)
	_actor.set_size_px(Vector2(96.0, 96.0))
	_actor.set_screen_position(Vector2(320.0, 260.0))
	_actor.set_team_tint(Color(0.12, 0.30, 0.46, 0.72))
	await _settle(0.06)

	var initial: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(bool(initial.get("has_motion_root", false)), "portrait motion root should exist")
	_expect(bool(initial.get("has_contact_shadow", false)), "contact shadow should exist")
	_expect(bool(initial.get("sprite_parent_is_motion_root", false)), "sprite should be parented to portrait motion root")
	_expect(String(initial.get("state", "")) == "idle", "actor should begin idle")
	var initial_position: Vector2 = initial.get("portrait_position", Vector2.ZERO) as Vector2
	await _settle(0.18)
	var idle_snapshot: Dictionary[String, Variant] = _actor.presentation_snapshot()
	var idle_position: Vector2 = idle_snapshot.get("portrait_position", Vector2.ZERO) as Vector2
	_expect(initial_position.distance_to(idle_position) > 0.01, "idle should visibly advance over time")
	_expect(idle_position.length() <= 2.0, "idle displacement should remain bounded")

	_actor.play_attack_motion(Vector2(430.0, 240.0), {"shape": "hammer"})
	var anticipation: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(String(anticipation.get("state", "")) == "anticipation", "attack should enter anticipation")
	await _settle(0.12)
	var attack_active: Dictionary[String, Variant] = _actor.presentation_snapshot()
	var active_state: String = String(attack_active.get("state", ""))
	_expect(["strike", "recovery"].has(active_state), "attack should advance through strike/recovery, got %s" % active_state)
	var attack_offset: Vector2 = attack_active.get("offset", Vector2.ZERO) as Vector2
	_expect(attack_offset.length() <= 22.01, "attack displacement should respect the 22px presentation cap")
	await _settle(0.40)
	var recovered: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(String(recovered.get("state", "")) == "idle", "attack should recover to idle")
	_expect((recovered.get("offset", Vector2.ONE) as Vector2).is_equal_approx(Vector2.ZERO), "attack offset should reset")
	_expect((recovered.get("scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ONE), "attack scale should reset")

	_actor.play_hit_reaction(Vector2(320.0, 120.0), {"crit": true})
	var hit_snapshot: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(String(hit_snapshot.get("state", "")) == "hit", "hit should enter hit state")
	await _settle(0.30)
	var hit_recovered: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(String(hit_recovered.get("state", "")) == "idle", "hit should recover to idle")

	_actor.play_death_reaction(Vector2(320.0, 120.0), {"duration_scale": 0.35})
	var death_started: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(bool(death_started.get("death_in_progress", false)), "death should hold an in-progress state")
	_expect(bool(death_started.get("visible", false)), "actor should remain visible while death plays")
	_actor.sync_alive_visibility(false)
	_expect(_actor.visible, "dead visibility sync should not hide an active death reaction")
	await _settle(0.28)
	var death_complete: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(String(death_complete.get("state", "")) == "dead", "death should finish in dead state")
	_expect(bool(death_complete.get("hidden_by_death", false)), "death should record presentation-owned hiding")
	_expect(not _actor.visible, "actor should hide after death finishes")

	_actor.sync_alive_visibility(true)
	var revived: Dictionary[String, Variant] = _actor.presentation_snapshot()
	_expect(_actor.visible, "alive sync should restore visibility")
	_expect(String(revived.get("state", "")) == "idle", "alive sync should restore idle state")
	_expect((revived.get("offset", Vector2.ONE) as Vector2).is_equal_approx(Vector2.ZERO), "alive sync should restore base offset")
	_finish()

func _settle(seconds: float) -> void:
	for _frame_index: int in range(2):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
