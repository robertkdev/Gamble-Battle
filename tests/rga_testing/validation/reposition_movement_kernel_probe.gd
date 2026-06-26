extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const ControlMobilityKernel := preload("res://tests/rga_testing/aggregators/kernels/control_mobility_kernel.gd")
const RepositionApproachTest := preload("res://tests/rga_testing/metrics/approach/reposition_approach_test.gd")

const SUBJECT_ID: String = "berebell"
const TARGET_ID: String = "target_dummy"
const TILE_SIZE: float = 64.0

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var positive_result: Dictionary = _run_case(true)
	var alternate_result: Dictionary = _run_path_only_case()
	var negative_result: Dictionary = _run_case(false)
	var positive_rec: Dictionary = positive_result.get("rec", {})
	var positive_metric: Dictionary = positive_result.get("metric", {})
	var alternate_rec: Dictionary = alternate_result.get("rec", {})
	var alternate_metric: Dictionary = alternate_result.get("metric", {})
	var negative_metric: Dictionary = negative_result.get("metric", {})
	var max_step: float = float(positive_rec.get("max_step_tiles", 0.0))
	var post_cast: float = float(positive_rec.get("post_cast_displacement_tiles", 0.0))
	var total_path: float = float(positive_rec.get("total_path_tiles", 0.0))
	var alternate_max_step: float = float(alternate_rec.get("max_step_tiles", 0.0))
	var alternate_post_cast: float = float(alternate_rec.get("post_cast_displacement_tiles", 0.0))
	var alternate_total_path: float = float(alternate_rec.get("total_path_tiles", 0.0))
	var reposition_steps: int = int(positive_rec.get("reposition_steps", 0))
	var positive_pass: bool = bool(positive_metric.get("pass", false))
	var alternate_pass: bool = bool(alternate_metric.get("pass", false))
	var negative_pass: bool = bool(negative_metric.get("pass", false))
	var max_step_span: bool = _has_passing_span(positive_metric, "subject_max_step_tiles")
	var post_cast_span: bool = _has_passing_span(positive_metric, "subject_post_cast_displacement_tiles")
	var path_span: bool = _has_passing_span(positive_metric, "subject_total_path_tiles")
	var alternate_max_step_diag: bool = _has_diagnostic_span(alternate_metric, "subject_max_step_tiles", "alternate_reposition_evidence_satisfied")
	var alternate_post_cast_diag: bool = _has_diagnostic_span(alternate_metric, "subject_post_cast_displacement_tiles", "alternate_reposition_evidence_satisfied")
	var alternate_path_span: bool = _has_passing_span(alternate_metric, "subject_total_path_tiles")

	print("RepositionMovementKernelProbe: max_step=", max_step,
		" post_cast=", post_cast,
		" total_path=", total_path,
		" alternate_max_step=", alternate_max_step,
		" alternate_post_cast=", alternate_post_cast,
		" alternate_total_path=", alternate_total_path,
		" alternate_pass=", alternate_pass,
		" alternate_max_step_diag=", alternate_max_step_diag,
		" alternate_post_cast_diag=", alternate_post_cast_diag,
		" reposition_steps=", reposition_steps,
		" positive_pass=", positive_pass,
		" negative_pass=", negative_pass)

	var failed: bool = false
	if not positive_pass:
		printerr("RepositionMovementKernelProbe: FAIL approach_reposition did not pass on direct movement telemetry")
		failed = true
	if max_step < 1.5 or post_cast < 1.5 or total_path < 3.0:
		printerr("RepositionMovementKernelProbe: FAIL direct movement evidence was below proof thresholds")
		failed = true
	if reposition_steps < 2:
		printerr("RepositionMovementKernelProbe: FAIL reposition step count was not recorded")
		failed = true
	if not max_step_span or not post_cast_span or not path_span:
		printerr("RepositionMovementKernelProbe: FAIL approach_reposition did not emit passing direct movement spans")
		failed = true
	if alternate_max_step >= 0.75 or alternate_post_cast >= 1.0 or alternate_total_path < 3.0 or not alternate_pass or not alternate_max_step_diag or not alternate_post_cast_diag or not alternate_path_span:
		printerr("RepositionMovementKernelProbe: FAIL alternate path-distance reposition evidence did not keep lower movement spans diagnostic")
		failed = true
	if negative_pass:
		printerr("RepositionMovementKernelProbe: FAIL weak movement negative case passed approach_reposition")
		failed = true

	if failed:
		_quit(1)
		return
	print("RepositionMovementKernelProbe: PASS")
	_quit(0)

func _run_case(strong: bool) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = ControlMobilityKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"metadata": {
			"tile_size": TILE_SIZE
		},
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": TARGET_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	engine.emit_signal("position_updated", "player", 0, 0.0, 0.0)
	if strong:
		_move(engine, kernel, 0.20, Vector2(96.0, 0.0))
		engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2(96.0, 0.0))
		_move(engine, kernel, 0.50, Vector2(192.0, 0.0))
		_move(engine, kernel, 0.50, Vector2(256.0, 0.0))
	else:
		_move(engine, kernel, 0.20, Vector2(12.0, 0.0))
		engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2(12.0, 0.0))
		_move(engine, kernel, 0.50, Vector2(24.0, 0.0))
		_move(engine, kernel, 0.50, Vector2(32.0, 0.0))
	kernel.call("finalize", 2.0)
	var result: Dictionary = kernel.call("result")
	var control: Dictionary = result.get("control_mobility", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = control.get("per_unit", {}) if (control is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)
	kernel.call("detach")
	return {
		"rec": rec,
		"metric": metric_result
	}

func _run_path_only_case() -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = ControlMobilityKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"metadata": {
			"tile_size": TILE_SIZE
		},
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": TARGET_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	engine.emit_signal("position_updated", "player", 0, 0.0, 0.0)
	var position_x: float = 0.0
	var move_index: int = 0
	while move_index < 7:
		position_x += 32.0
		_move(engine, kernel, 0.20, Vector2(position_x, 0.0))
		move_index += 1
	engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2(position_x, 0.0))
	kernel.call("finalize", 2.0)
	var result: Dictionary = kernel.call("result")
	var control: Dictionary = result.get("control_mobility", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = control.get("per_unit", {}) if (control is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)
	kernel.call("detach")
	return {
		"rec": rec,
		"metric": metric_result
	}

func _move(engine: CombatEngine, kernel: Variant, delta_s: float, position: Vector2) -> void:
	kernel.call("tick", delta_s)
	engine.emit_signal("position_updated", "player", 0, position.x, position.y)

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = RepositionApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUBJECT_ID],
						"team_b_ids": [TARGET_ID]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}
	return metric.call("run_metric", payload)

func _has_passing_span(metric_result: Dictionary, label_prefix: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and bool(span.get("ok", false)):
			return true
	return false

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and String(span.get("reason", "")) == reason:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
