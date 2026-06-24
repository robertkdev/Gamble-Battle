extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BuffPresenceKernel := preload("res://tests/rga_testing/aggregators/kernels/buff_presence_kernel.gd")
const DotApproachTest := preload("res://tests/rga_testing/metrics/approach/dot_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = BuffPresenceKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "repo"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "korath"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	engine.emit_signal("debuff_applied", "player", 0, "enemy", 0, "executioner_bleed", {"tag": "executioner_bleed"}, 2.0, 3.0)
	kernel.call("tick", 1.25)
	engine._resolver_emit_dot_tick_applied("player", 0, "enemy", 0, 7, "executioner_bleed")
	engine._resolver_emit_dot_tick_applied("player", 0, "enemy", 0, 8, "executioner_bleed")

	var result: Dictionary = kernel.call("result")
	var buff_presence: Dictionary = result.get("buff_presence", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = buff_presence.get("per_unit", {}) if (buff_presence is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var source_rec: Dictionary = side_a.get("repo", {}) if (side_a is Dictionary) else {}
	var target_unit: Dictionary = buff_presence.get("target_unit", {}) if (buff_presence is Dictionary) else {}
	var side_b: Dictionary = target_unit.get("b", {}) if (target_unit is Dictionary) else {}
	var target_rec: Dictionary = side_b.get("korath", {}) if (side_b is Dictionary) else {}

	var supported: bool = bool(buff_presence.get("dot_tick_supported", false))
	var source_events: int = int(source_rec.get("dot_tick_events", 0))
	var source_damage: int = int(source_rec.get("dot_tick_damage", 0))
	var source_targets: int = int(source_rec.get("dot_tick_targets", 0))
	var source_duration: float = float(source_rec.get("dot_duration_applied_s", 0.0))
	var source_uptime: float = float(source_rec.get("dot_uptime_s", 0.0))
	var target_events: int = int(target_rec.get("dot_ticks_received", 0))
	var target_damage: int = int(target_rec.get("dot_damage_received", 0))
	var target_uptime: float = float(target_rec.get("dot_uptime_received_s", 0.0))
	var metric_result: Dictionary = _run_metric_result(result)
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_uses_proxy: bool = _has_span_prefix(metric_result, "subject_dot_debuff_events_proxy")
	var metric_uptime_span: bool = _has_span_prefix(metric_result, "subject_dot_uptime_s")
	var scenario_metric_result: Dictionary = _run_metric_payload(_scenario_delta_payload())
	var scenario_metric_pass: bool = bool(scenario_metric_result.get("pass", false))
	var scenario_delta_spans: bool = _has_span_prefix(scenario_metric_result, "subject_dot_anti_dot_tick_damage_drop") and _has_span_prefix(scenario_metric_result, "subject_dot_anti_dot_tick_event_drop") and _has_span_prefix(scenario_metric_result, "subject_dot_anti_dot_uptime_drop_s") and _has_span_prefix(scenario_metric_result, "subject_dot_anti_dot_cleanse_pressure_delta")

	print("DotTickKernelProbe: supported=", supported,
		" source_events=", source_events,
		" source_damage=", source_damage,
		" source_targets=", source_targets,
		" source_duration=", source_duration,
		" source_uptime=", source_uptime,
		" target_events=", target_events,
		" target_damage=", target_damage,
		" target_uptime=", target_uptime,
		" metric_pass=", metric_pass,
		" scenario_metric_pass=", scenario_metric_pass)

	var failed: bool = false
	if not supported:
		printerr("DotTickKernelProbe: FAIL dot_tick_applied signal was not connected")
		failed = true
	if source_events != 2 or source_damage != 15 or source_targets != 1:
		printerr("DotTickKernelProbe: FAIL source DoT tick ownership was not recorded")
		failed = true
	if not is_equal_approx(source_duration, 3.0) or not is_equal_approx(source_uptime, 1.25):
		printerr("DotTickKernelProbe: FAIL source DoT duration/uptime was not recorded")
		failed = true
	if target_events != 2 or target_damage != 15 or not is_equal_approx(target_uptime, 1.25):
		printerr("DotTickKernelProbe: FAIL target DoT tick receipt was not recorded")
		failed = true
	if not metric_pass:
		printerr("DotTickKernelProbe: FAIL approach_dot did not pass on direct tick telemetry")
		failed = true
	if not metric_uptime_span:
		printerr("DotTickKernelProbe: FAIL approach_dot did not emit direct uptime span")
		failed = true
	if metric_uses_proxy:
		printerr("DotTickKernelProbe: FAIL approach_dot used proxy spans when direct tick telemetry was available")
		failed = true
	if not scenario_metric_pass or not scenario_delta_spans:
		printerr("DotTickKernelProbe: FAIL approach_dot did not expose anti-DoT scenario delta spans")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("DotTickKernelProbe: PASS")
	_quit(0)

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	return _run_metric_payload(_metric_payload(kernel_result))

func _run_metric_payload(payload: Dictionary) -> Dictionary:
	var metric: Variant = DotApproachTest.new()
	return metric.call("run_metric", payload)

func _metric_payload(kernel_result: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["repo"],
						"team_b_ids": ["korath"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["repo"]
	}

func _scenario_delta_payload() -> Dictionary:
	return {
		"context": {
			"scenario": "mixed_anti_dot",
			"sims": {
				"neutral": _scenario_delta_entry("neutral", {
					"dot_tick_supported": true,
					"dot_tick_events": 4,
					"dot_tick_damage": 40.0,
					"dot_tick_targets": 1,
					"dot_uptime_s": 4.0,
					"dot_duration_applied_s": 4.0
				}, {
					"cleanse_pressure_events": 0
				}),
				"anti_dot_cleanse": _scenario_delta_entry("anti_dot_cleanse", {
					"dot_tick_supported": true,
					"dot_tick_events": 1,
					"dot_tick_damage": 5.0,
					"dot_tick_targets": 1,
					"dot_uptime_s": 0.5,
					"dot_duration_applied_s": 1.0
				}, {
					"cleanse_pressure_events": 1
				})
			}
		},
		"subject_unit_ids": ["repo"]
	}

func _scenario_delta_entry(label: String, dot_rec: Dictionary, counterplay_rec: Dictionary) -> Dictionary:
	return {
		"context": {
			"team_a_ids": ["repo"],
			"team_b_ids": ["korath"],
			"scenario_label": String(label)
		},
		"kernels": {
			"buff_presence": {
				"dot_tick_supported": bool(dot_rec.get("dot_tick_supported", true)),
				"per_unit": {
					"a": {
						"repo": dot_rec
					},
					"b": {}
				},
				"target_unit": {
					"a": {},
					"b": {
						"korath": {
							"dot_ticks_received": int(dot_rec.get("dot_tick_events", 0)),
							"dot_damage_received": float(dot_rec.get("dot_tick_damage", 0.0)),
							"dot_uptime_received_s": float(dot_rec.get("dot_uptime_s", 0.0))
						}
					}
				}
			},
			"counterplay_pressure": {
				"supported": true,
				"per_unit": {
					"a": {
						"repo": counterplay_rec
					},
					"b": {}
				},
				"target_unit": {
					"a": {},
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
