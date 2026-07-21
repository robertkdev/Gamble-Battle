extends Node

const SMOKE_NAME: String = "BattlefieldAtmospherePresentationSmoke"
const BattlefieldAtmosphere: GDScript = preload("res://scripts/ui/combat/battlefield_atmosphere.gd")

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var host: Control = Control.new()
	host.name = "AtmosphereHost"
	host.custom_minimum_size = Vector2(1280.0, 620.0)
	host.size = Vector2(1280.0, 620.0)
	add_child(host)
	var atmosphere: BattlefieldAtmosphere = BattlefieldAtmosphere.new() as BattlefieldAtmosphere
	_expect(atmosphere != null, "atmosphere should construct")
	if atmosphere == null:
		_finish()
		return
	atmosphere.configure(host, BattlefieldAtmosphere.STATE_PLANNING)
	await _settle(0.06)

	var planning: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	_expect(bool(planning.get("configured", false)), "atmosphere should report configured")
	_expect(String(planning.get("state", "")) == "planning", "initial state should be planning")
	_expect(int(planning.get("z_index", 0)) == -6, "atmosphere should sit between battlefield art and units")
	_expect(atmosphere.mouse_filter == Control.MOUSE_FILTER_IGNORE, "atmosphere must never consume input")
	_expect(int(planning.get("mote_count", 0)) == 14, "planning should use the restrained mote budget")

	var planning_time: float = float(planning.get("motion_time", 0.0))
	await _settle(0.12)
	var advanced: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	_expect(float(advanced.get("motion_time", 0.0)) > planning_time, "ambient motion should advance over time")

	atmosphere.set_state(BattlefieldAtmosphere.STATE_COMBAT, false)
	await _settle(0.14)
	var combat: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	_expect(String(combat.get("state", "")) == "combat", "combat state should be applied")
	_expect(int(combat.get("mote_count", 0)) == 22, "combat may use the expanded but bounded mote budget")
	_expect((combat.get("target_top", Color.TRANSPARENT) as Color).a > (planning.get("target_top", Color.TRANSPARENT) as Color).a, "combat should intensify enemy-side authored light")
	_expect(float(combat.get("flash_strength", 0.0)) < 0.72, "combat transition flash should decay")

	atmosphere.pulse_escalation(3)
	var escalation_onset: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	var onset_strength: float = float(escalation_onset.get("flash_strength", 0.0))
	_expect(onset_strength >= 0.01 and onset_strength < 0.08, "escalation should begin with a restrained onset")
	_expect(bool(escalation_onset.get("localized_flash", false)), "escalation should localize its pulse to the enemy half")
	await _settle(0.08)
	var escalation_crest: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	var crest_strength: float = float(escalation_crest.get("flash_strength", 0.0))
	_expect(crest_strength > onset_strength, "escalation should rise to a visible crest")
	await _settle(0.42)
	var escalation_decay: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	_expect(float(escalation_decay.get("flash_strength", 1.0)) < crest_strength, "escalation should decay after its crest")

	atmosphere.set_state(BattlefieldAtmosphere.STATE_VICTORY, true)
	var victory: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	_expect(String(victory.get("state", "")) == "victory", "victory state should be distinct")
	_expect((victory.get("target_bottom", Color.TRANSPARENT) as Color).g > (victory.get("target_bottom", Color.TRANSPARENT) as Color).r, "victory should cool the player-side field toward green")

	atmosphere.set_state(BattlefieldAtmosphere.STATE_DEFEAT, true)
	var defeat: Dictionary[String, Variant] = atmosphere.presentation_snapshot()
	_expect(String(defeat.get("state", "")) == "defeat", "defeat state should be distinct")
	_expect((defeat.get("target_top", Color.TRANSPARENT) as Color).r > (defeat.get("target_top", Color.TRANSPARENT) as Color).g * 4.0, "defeat should author a blood-red field")

	atmosphere.set_motion_enabled(false)
	var frozen_time: float = float(atmosphere.presentation_snapshot().get("motion_time", 0.0))
	await _settle(0.10)
	_expect(is_equal_approx(float(atmosphere.presentation_snapshot().get("motion_time", 0.0)), frozen_time), "motion-disable should freeze ambient drift")
	_finish()

func _settle(seconds: float) -> void:
	for _frame_index: int in range(2):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
