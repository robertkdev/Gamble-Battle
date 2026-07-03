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

	forced.add("player", 3, Vector2(96.0, 0.0), 60.0)
	var active_hits: int = 0
	var active_step_signature: int = 0
	var active_gate: bool = forced.has_any()
	var started_active_usec: int = Time.get_ticks_usec()
	for active_index in range(max(0, active_iterations)):
		if active_gate and forced.has_active("player", 3):
			active_hits += 1
			var step: Vector2 = forced.consume_step("player", 3, 0.0)
			active_step_signature = _mix(active_step_signature, int(round(step.x * 100.0)))
	var active_ms: int = int((Time.get_ticks_usec() - started_active_usec) / 1000)

	var signature: int = 23
	signature = _mix(signature, empty_hits)
	signature = _mix(signature, active_hits)
	signature = _mix(signature, active_step_signature)
	print("PerfForcedMovement: empty_iterations=", empty_iterations,
		" empty_ms=", empty_ms,
		" empty_hits=", empty_hits,
		" active_iterations=", active_iterations,
		" active_ms=", active_ms,
		" active_hits=", active_hits,
		" signature=", signature)
	get_tree().quit(0)

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
