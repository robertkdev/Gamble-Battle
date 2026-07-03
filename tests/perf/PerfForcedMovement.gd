extends Node

const ForcedMovementScript: Script = preload("res://scripts/game/combat/movement/forced_movement.gd")

@export var empty_iterations: int = 420000
@export var active_iterations: int = 120000

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var forced: ForcedMovement = ForcedMovementScript.new()
	var empty_hits: int = 0
	var empty_gate: bool = forced.has_any()
	var started_empty_usec: int = Time.get_ticks_usec()
	for index in range(max(0, empty_iterations)):
		if empty_gate and forced.has_active("player", index % 12):
			empty_hits += 1
	var empty_ms: int = int((Time.get_ticks_usec() - started_empty_usec) / 1000)

	var legacy_forced: ForcedMovement = ForcedMovementScript.new()
	var active_duration: float = float(max(1, active_iterations)) + 1.0
	legacy_forced.add("player", 3, Vector2(96.0, 0.0), active_duration)
	var legacy_active_hits: int = 0
	var legacy_active_step_signature: int = 0
	var legacy_active_gate: bool = legacy_forced.has_any()
	var started_legacy_active_usec: int = Time.get_ticks_usec()
	for active_index in range(max(0, active_iterations)):
		if legacy_active_gate and legacy_forced.has_active("player", 3):
			legacy_active_hits += 1
			var legacy_step: Vector2 = legacy_forced.consume_step("player", 3, 1.0)
			legacy_active_step_signature = _mix(legacy_active_step_signature, int(round(legacy_step.x * 100000.0)))
	var legacy_active_ms: int = int((Time.get_ticks_usec() - started_legacy_active_usec) / 1000)

	var direct_forced: ForcedMovement = ForcedMovementScript.new()
	direct_forced.add("player", 3, Vector2(96.0, 0.0), active_duration)
	var direct_active_hits: int = 0
	var direct_active_step_signature: int = 0
	var direct_active_gate: bool = direct_forced.has_any()
	var started_direct_active_usec: int = Time.get_ticks_usec()
	for direct_index in range(max(0, active_iterations)):
		if direct_active_gate:
			var direct_step: Vector2 = direct_forced.consume_step("player", 3, 1.0)
			if direct_step != Vector2.ZERO:
				direct_active_hits += 1
				direct_active_step_signature = _mix(direct_active_step_signature, int(round(direct_step.x * 100000.0)))
	var direct_active_ms: int = int((Time.get_ticks_usec() - started_direct_active_usec) / 1000)

	var signature: int = 23
	signature = _mix(signature, empty_hits)
	signature = _mix(signature, legacy_active_hits)
	signature = _mix(signature, direct_active_hits)
	signature = _mix(signature, legacy_active_step_signature)
	signature = _mix(signature, direct_active_step_signature)
	print("PerfForcedMovement: empty_iterations=", empty_iterations,
		" empty_ms=", empty_ms,
		" empty_hits=", empty_hits,
		" active_iterations=", active_iterations,
		" legacy_active_ms=", legacy_active_ms,
		" legacy_active_hits=", legacy_active_hits,
		" direct_active_ms=", direct_active_ms,
		" direct_active_hits=", direct_active_hits,
		" signature=", signature)
	get_tree().quit(0)

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
