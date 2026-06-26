extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const ControlMobilityKernel := preload("res://tests/rga_testing/aggregators/kernels/control_mobility_kernel.gd")
const EngageApproachTest := preload("res://tests/rga_testing/metrics/approach/engage_approach_test.gd")

const SUBJECT_ID: String = "grint"
const TARGET_ID: String = "target_dummy"
const TILE_SIZE: float = 64.0

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var positive_result: Dictionary = _run_case(true)
	var alternate_result: Dictionary = _run_no_cc_case()
	var mixed_peak_metric: Dictionary = _run_mixed_peak_case()
	var negative_result: Dictionary = _run_case(false)
	var positive_rec: Dictionary = positive_result.get("rec", {})
	var positive_metric: Dictionary = positive_result.get("metric", {})
	var alternate_rec: Dictionary = alternate_result.get("rec", {})
	var alternate_metric: Dictionary = alternate_result.get("metric", {})
	var negative_metric: Dictionary = negative_result.get("metric", {})
	var displacement: float = float(positive_rec.get("early_max_displacement_tiles", 0.0))
	var first_action: float = float(positive_rec.get("first_action_s", -1.0))
	var first_cc: float = float(positive_rec.get("first_cc_s", -1.0))
	var alternate_displacement: float = float(alternate_rec.get("early_max_displacement_tiles", 0.0))
	var alternate_first_action: float = float(alternate_rec.get("first_action_s", -1.0))
	var alternate_first_cc: float = float(alternate_rec.get("first_cc_s", -1.0))
	var cc_seconds: float = float(positive_rec.get("cc_seconds", 0.0))
	var cc_events: int = int(positive_rec.get("cc_events", 0))
	var positive_pass: bool = bool(positive_metric.get("pass", false))
	var alternate_pass: bool = bool(alternate_metric.get("pass", false))
	var mixed_peak_pass: bool = bool(mixed_peak_metric.get("pass", false))
	var negative_pass: bool = bool(negative_metric.get("pass", false))
	var displacement_span: bool = _has_passing_span(positive_metric, "subject_early_engage_displacement_tiles")
	var peak_span: bool = _has_passing_span(mixed_peak_metric, "subject_early_engage_displacement_tiles_peak")
	var mixed_median_diag: bool = _has_diagnostic_span(mixed_peak_metric, "subject_early_engage_displacement_tiles_med", "alternate_engage_peak_distance_satisfied")
	var mixed_cc_diag: bool = _has_diagnostic_span(mixed_peak_metric, "subject_time_to_first_cc_s", "alternate_engage_peak_distance_satisfied")
	var action_span: bool = _has_passing_span(positive_metric, "subject_time_to_first_action_s")
	var cc_span: bool = _has_passing_span(positive_metric, "subject_time_to_first_cc_s")
	var alternate_displacement_span: bool = _has_passing_span(alternate_metric, "subject_early_engage_displacement_tiles")
	var alternate_action_span: bool = _has_passing_span(alternate_metric, "subject_time_to_first_action_s")
	var alternate_cc_diag: bool = _has_diagnostic_span(alternate_metric, "subject_time_to_first_cc_s", "alternate_engage_evidence_satisfied")

	print("EngageCcTimingKernelProbe: displacement=", displacement,
		" first_action=", first_action,
		" first_cc=", first_cc,
		" alternate_displacement=", alternate_displacement,
		" alternate_first_action=", alternate_first_action,
		" alternate_first_cc=", alternate_first_cc,
		" alternate_pass=", alternate_pass,
		" alternate_cc_diag=", alternate_cc_diag,
		" mixed_peak_pass=", mixed_peak_pass,
		" mixed_median_diag=", mixed_median_diag,
		" mixed_cc_diag=", mixed_cc_diag,
		" cc_seconds=", cc_seconds,
		" cc_events=", cc_events,
		" positive_pass=", positive_pass,
		" negative_pass=", negative_pass)

	var failed: bool = false
	if not positive_pass:
		printerr("EngageCcTimingKernelProbe: FAIL approach_engage did not pass on direct engage timing telemetry")
		failed = true
	if displacement < 1.5 or first_action < 0.0 or first_action > 5.0 or first_cc < 0.0 or first_cc > 6.0:
		printerr("EngageCcTimingKernelProbe: FAIL direct engage timing evidence was below proof thresholds")
		failed = true
	if cc_events < 1 or cc_seconds < 1.0:
		printerr("EngageCcTimingKernelProbe: FAIL CC event duration was not recorded")
		failed = true
	if not displacement_span or not action_span or not cc_span:
		printerr("EngageCcTimingKernelProbe: FAIL approach_engage did not emit passing engage timing spans")
		failed = true
	if alternate_displacement < 1.0 or alternate_first_action < 0.0 or alternate_first_action > 5.0 or alternate_first_cc >= 0.0 or not alternate_pass or not alternate_displacement_span or not alternate_action_span or not alternate_cc_diag:
		printerr("EngageCcTimingKernelProbe: FAIL alternate fast-action engage evidence did not keep missing CC diagnostic")
		failed = true
	if not mixed_peak_pass or not peak_span or not mixed_median_diag or not mixed_cc_diag:
		printerr("EngageCcTimingKernelProbe: FAIL mixed-context peak engage evidence did not keep median/CC diagnostics")
		failed = true
	if negative_pass:
		printerr("EngageCcTimingKernelProbe: FAIL weak no-engage negative case passed approach_engage")
		failed = true

	if failed:
		_quit(1)
		return
	print("EngageCcTimingKernelProbe: PASS")
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
		_move(engine, kernel, 0.40, Vector2(96.0, 0.0))
		engine.emit_signal("target_start", "player", 0, "enemy", 0)
		kernel.call("tick", 0.60)
		engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2(96.0, 0.0))
		engine.emit_signal("hit_applied", "player", 0, 0, 12, 12, false, 100, 88, 0.0, 0.0)
		kernel.call("tick", 1.50)
		engine.emit_signal("cc_applied", "player", 0, "enemy", 0, "stun", 1.25)
	else:
		_move(engine, kernel, 0.40, Vector2(8.0, 0.0))
		kernel.call("tick", 7.00)
		engine.emit_signal("target_start", "player", 0, "enemy", 0)
	kernel.call("finalize", 8.0)
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

func _run_no_cc_case() -> Dictionary:
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
	_move(engine, kernel, 0.40, Vector2(96.0, 0.0))
	engine.emit_signal("target_start", "player", 0, "enemy", 0)
	kernel.call("tick", 0.60)
	engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2(96.0, 0.0))
	engine.emit_signal("hit_applied", "player", 0, 0, 12, 12, false, 100, 88, 0.0, 0.0)
	kernel.call("finalize", 8.0)
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

func _run_mixed_peak_case() -> Dictionary:
	var metric: Variant = EngageApproachTest.new()
	var sims: Dictionary = {}
	sims["low_a"] = _mixed_peak_entry(0.20, 1.40)
	sims["low_b"] = _mixed_peak_entry(0.30, 1.60)
	sims["peak"] = _mixed_peak_entry(1.40, 2.00)
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": sims
		},
		"subject_unit_ids": [SUBJECT_ID]
	}
	return metric.call("run_metric", payload)

func _mixed_peak_entry(displacement_tiles: float, first_action_s: float) -> Dictionary:
	var rec: Dictionary = {
		"early_max_displacement_tiles": displacement_tiles,
		"first_action_s": first_action_s
	}
	var per_unit_a: Dictionary = {}
	per_unit_a[SUBJECT_ID] = rec
	return {
		"context": {
			"team_a_ids": [SUBJECT_ID],
			"team_b_ids": [TARGET_ID]
		},
		"kernels": {
			"control_mobility": {
				"per_unit": {
					"a": per_unit_a
				}
			}
		}
	}

func _move(engine: CombatEngine, kernel: Variant, delta_s: float, position: Vector2) -> void:
	kernel.call("tick", delta_s)
	engine.emit_signal("position_updated", "player", 0, position.x, position.y)

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = EngageApproachTest.new()
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
