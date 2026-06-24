extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const ResetMechanicApproachTest := preload("res://tests/rga_testing/metrics/approach/reset_mechanic_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 2}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "hexeon"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "korath"
				},
				{
					"unit_index": 1,
					"unit_id": "berebell"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	kernel.call("tick", 0.50)
	engine._resolver_emit_reset_triggered("player", 0, "enemy", 0, "hexeon_execute_recast", 1, 0.0, 0.70)
	kernel.call("tick", 0.10)
	engine.emit_signal("hit_applied", "player", 0, 0, 90, 90, false, 90, 0, 0.0, 0.0)
	kernel.call("tick", 1.15)
	engine._resolver_emit_reset_triggered("player", 0, "enemy", 1, "hexeon_execute_recast", 2, 1.25, 0.70)
	kernel.call("tick", 0.15)
	engine.emit_signal("hit_applied", "player", 0, 1, 60, 60, false, 60, 0, 0.0, 0.0)
	kernel.call("finalize", 2.00)

	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("hexeon", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)

	var supported: bool = bool(combat_patterns.get("reset_supported", false))
	var reset_events: int = int(rec.get("reset_events", 0))
	var reset_chain_length: int = int(rec.get("reset_chain_length", 0))
	var reset_time_between: float = float(rec.get("reset_time_between_min_s", 0.0))
	var reset_targets: int = int(rec.get("reset_targets", 0))
	var post_damage: float = float(rec.get("reset_post_first_damage", 0.0))
	var post_kills: int = int(rec.get("reset_post_first_kills", 0))
	var followup_s: float = float(rec.get("reset_first_followup_s", -1.0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_uses_proxy: bool = _has_span_prefix(metric_result, "subject_reset_kill_count_proxy")
	var metric_post_spans: bool = _has_span_prefix(metric_result, "subject_reset_post_first_damage") and _has_span_prefix(metric_result, "subject_reset_post_first_kills") and _has_span_prefix(metric_result, "subject_reset_win_rate_after_reset")
	var scenario_metric_result: Dictionary = _run_metric_payload(_scenario_delta_payload())
	var scenario_metric_pass: bool = bool(scenario_metric_result.get("pass", false))
	var scenario_delta_spans: bool = _has_span_prefix(scenario_metric_result, "subject_reset_counter_event_drop") and _has_span_prefix(scenario_metric_result, "subject_reset_counter_chain_drop") and _has_span_prefix(scenario_metric_result, "subject_reset_counter_post_damage_drop") and _has_span_prefix(scenario_metric_result, "subject_reset_counter_win_rate_drop")

	print("ResetMechanicKernelProbe: supported=", supported,
		" events=", reset_events,
		" chain=", reset_chain_length,
		" time_between=", reset_time_between,
		" targets=", reset_targets,
		" post_damage=", post_damage,
		" post_kills=", post_kills,
		" followup_s=", followup_s,
		" metric_pass=", metric_pass,
		" scenario_metric_pass=", scenario_metric_pass)

	var failed: bool = false
	if not supported:
		printerr("ResetMechanicKernelProbe: FAIL reset_triggered signal was not connected")
		failed = true
	if reset_events != 2 or reset_chain_length != 3:
		printerr("ResetMechanicKernelProbe: FAIL reset event chain was not recorded")
		failed = true
	if not is_equal_approx(reset_time_between, 1.25):
		printerr("ResetMechanicKernelProbe: FAIL reset time-between was not recorded")
		failed = true
	if reset_targets != 2:
		printerr("ResetMechanicKernelProbe: FAIL reset target count was not recorded")
		failed = true
	if post_damage != 150.0 or post_kills != 2:
		printerr("ResetMechanicKernelProbe: FAIL post-first-reset impact was not recorded")
		failed = true
	if not is_equal_approx(followup_s, 0.10):
		printerr("ResetMechanicKernelProbe: FAIL first reset follow-up timing was not recorded")
		failed = true
	if not metric_pass:
		printerr("ResetMechanicKernelProbe: FAIL approach_reset_mechanic did not pass on direct reset telemetry")
		failed = true
	if not metric_post_spans:
		printerr("ResetMechanicKernelProbe: FAIL approach_reset_mechanic did not expose post-reset spans")
		failed = true
	if metric_uses_proxy:
		printerr("ResetMechanicKernelProbe: FAIL approach_reset_mechanic used proxy spans when direct reset telemetry was available")
		failed = true
	if not scenario_metric_pass or not scenario_delta_spans:
		printerr("ResetMechanicKernelProbe: FAIL approach_reset_mechanic did not expose reset counter-scenario delta spans")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("ResetMechanicKernelProbe: PASS")
	_quit(0)

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	return _run_metric_payload(_metric_payload(kernel_result))

func _run_metric_payload(payload: Dictionary) -> Dictionary:
	var metric: Variant = ResetMechanicApproachTest.new()
	return metric.call("run_metric", payload)

func _metric_payload(kernel_result: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["hexeon"],
						"team_b_ids": ["korath", "berebell"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["hexeon"]
	}

func _scenario_delta_payload() -> Dictionary:
	return {
		"context": {
			"scenario": "mixed_reset_counter",
			"sims": {
				"neutral": _scenario_delta_entry("neutral", {
					"reset_events": 2,
					"reset_chain_length": 3,
					"reset_time_between_min_s": 1.0,
					"reset_targets": 2,
					"reset_post_first_damage": 120.0,
					"reset_post_first_damage_share": 0.80,
					"reset_post_first_kills": 2,
					"reset_post_first_targets": 2,
					"reset_first_followup_s": 0.20
				}, "a"),
				"sustain_counter": _scenario_delta_entry("sustain_counter", {
					"reset_events": 0,
					"reset_chain_length": 0,
					"reset_time_between_min_s": 0.0,
					"reset_targets": 0,
					"reset_post_first_damage": 0.0,
					"reset_post_first_damage_share": 0.0,
					"reset_post_first_kills": 0,
					"reset_post_first_targets": 0,
					"reset_first_followup_s": -1.0
				}, "b")
			}
		},
		"subject_unit_ids": ["hexeon"]
	}

func _scenario_delta_entry(label: String, pattern_rec: Dictionary, winner_side: String) -> Dictionary:
	return {
		"context": {
			"scenario": label,
			"team_a_ids": ["hexeon"],
			"team_b_ids": ["korath", "berebell"]
		},
		"outcome": {
			"winner_side": winner_side
		},
		"kernels": {
			"combat_patterns": {
				"supported": true,
				"reset_supported": true,
				"per_unit": {
					"a": {
						"hexeon": pattern_rec
					},
					"b": {}
				}
			}
		}
	}

func _has_span_prefix(metric_result: Dictionary, prefix: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var label: String = String((span_value as Dictionary).get("label", ""))
		if label.begins_with(prefix):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
