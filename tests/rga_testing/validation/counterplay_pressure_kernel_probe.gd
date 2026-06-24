extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const CounterplayPressureKernel := preload("res://tests/rga_testing/aggregators/kernels/counterplay_pressure_kernel.gd")
const LockdownApproachTest := preload("res://tests/rga_testing/metrics/approach/lockdown_approach_test.gd")
const DebuffApproachTest := preload("res://tests/rga_testing/metrics/approach/debuff_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = CounterplayPressureKernel.new()
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
					"unit_id": "totem"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	engine.emit_signal("debuff_applied", "player", 0, "enemy", 0, "stun", {"duration": 2.0}, 2.0, 4.0)
	engine._resolver_emit_cc_taxed("player", 0, "enemy", 0, "stun", 2.0, 1.0, 0.5, false)
	engine.emit_signal("cleanse_applied", "enemy", 0, "enemy", 0, 1)

	kernel.call("finalize", 2.0)
	var kernel_result: Dictionary = kernel.call("result")
	var pressure: Dictionary = kernel_result.get("counterplay_pressure", {}) if (kernel_result is Dictionary) else {}
	var per_unit: Dictionary = pressure.get("per_unit", {}) if (pressure is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("repo", {}) if (side_a is Dictionary) else {}
	var lockdown_result: Dictionary = _run_lockdown_metric(kernel_result)
	var debuff_result: Dictionary = _run_debuff_metric(kernel_result)
	var scenario_payload: Dictionary = _scenario_delta_payload()
	var scenario_lockdown_result: Dictionary = _run_lockdown_metric_payload(scenario_payload)
	var scenario_debuff_result: Dictionary = _run_debuff_metric_payload(scenario_payload)

	var supported: bool = bool(pressure.get("supported", false))
	var cleanse_events: int = int(rec.get("cleanse_pressure_events", 0))
	var cleanse_removed: int = int(rec.get("cleanse_pressure_removed", 0))
	var bait_rate: float = float(rec.get("cleanse_bait_rate", 0.0))
	var tenacity_events: int = int(rec.get("tenacity_tax_events", 0))
	var tenacity_tax_s: float = float(rec.get("tenacity_tax_s", 0.0))
	var lockdown_pass: bool = bool(lockdown_result.get("pass", false))
	var debuff_pass: bool = bool(debuff_result.get("pass", false))
	var lockdown_span_present: bool = _has_span_label(lockdown_result, "subject_lockdown_cleanse_pressure") and _has_span_label(lockdown_result, "subject_lockdown_tenacity_tax_s")
	var debuff_span_present: bool = _has_span_label(debuff_result, "subject_debuff_cleanse_pressure") and _has_span_label(debuff_result, "subject_debuff_cleanse_bait_rate")
	var scenario_lockdown_pass: bool = bool(scenario_lockdown_result.get("pass", false))
	var scenario_debuff_pass: bool = bool(scenario_debuff_result.get("pass", false))
	var scenario_lockdown_span_present: bool = _has_span_label(scenario_lockdown_result, "subject_lockdown_cleanse_scenario_delta") and _has_span_label(scenario_lockdown_result, "subject_lockdown_high_tenacity_tax_delta_s") and _has_span_label(scenario_lockdown_result, "subject_lockdown_high_tenacity_effective_drop_s")
	var scenario_debuff_span_present: bool = _has_span_label(scenario_debuff_result, "subject_debuff_cleanse_scenario_delta")

	print("CounterplayPressureKernelProbe: supported=", supported,
		" cleanse_events=", cleanse_events,
		" cleanse_removed=", cleanse_removed,
		" bait_rate=", bait_rate,
		" tenacity_events=", tenacity_events,
		" tenacity_tax_s=", tenacity_tax_s,
		" lockdown_pass=", lockdown_pass,
		" debuff_pass=", debuff_pass,
		" scenario_lockdown_pass=", scenario_lockdown_pass,
		" scenario_debuff_pass=", scenario_debuff_pass)

	var failed: bool = false
	if not supported:
		printerr("CounterplayPressureKernelProbe: FAIL signals were not connected")
		failed = true
	if cleanse_events != 1 or cleanse_removed != 1 or not is_equal_approx(bait_rate, 1.0):
		printerr("CounterplayPressureKernelProbe: FAIL cleanse pressure was not attributed")
		failed = true
	if tenacity_events != 1 or not is_equal_approx(tenacity_tax_s, 1.0):
		printerr("CounterplayPressureKernelProbe: FAIL tenacity tax was not captured")
		failed = true
	if not lockdown_pass or not lockdown_span_present:
		printerr("CounterplayPressureKernelProbe: FAIL approach_lockdown did not expose direct counterplay spans")
		failed = true
	if not debuff_pass or not debuff_span_present:
		printerr("CounterplayPressureKernelProbe: FAIL approach_debuff did not expose direct cleanse spans")
		failed = true
	if not scenario_lockdown_pass or not scenario_lockdown_span_present:
		printerr("CounterplayPressureKernelProbe: FAIL approach_lockdown did not expose scenario counterplay delta spans")
		failed = true
	if not scenario_debuff_pass or not scenario_debuff_span_present:
		printerr("CounterplayPressureKernelProbe: FAIL approach_debuff did not expose scenario cleanse delta span")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("CounterplayPressureKernelProbe: PASS")
	_quit(0)

func _run_lockdown_metric(kernel_result: Dictionary) -> Dictionary:
	return _run_lockdown_metric_payload(_metric_payload(kernel_result))

func _run_lockdown_metric_payload(payload: Dictionary) -> Dictionary:
	var metric: Variant = LockdownApproachTest.new()
	return metric.call("run_metric", payload)

func _run_debuff_metric(kernel_result: Dictionary) -> Dictionary:
	return _run_debuff_metric_payload(_metric_payload(kernel_result))

func _run_debuff_metric_payload(payload: Dictionary) -> Dictionary:
	var metric: Variant = DebuffApproachTest.new()
	return metric.call("run_metric", payload)

func _metric_payload(kernel_result: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["repo"],
						"team_b_ids": ["totem"]
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
			"scenario": "mixed_counterplay",
			"sims": {
				"neutral": _scenario_delta_entry("neutral", {
					"debuffs_applied_for_counterplay": 1,
					"cleanse_pressure_events": 0,
					"cleanse_bait_rate": 0.0,
					"tenacity_tax_s": 0.0,
					"tenacity_tax_events": 0,
					"cc_raw_duration_s": 2.0,
					"cc_effective_duration_s": 2.0
				}),
				"high_tenacity_cleanse": _scenario_delta_entry("high_tenacity_cleanse", {
					"debuffs_applied_for_counterplay": 1,
					"cleanse_pressure_events": 2,
					"cleanse_bait_rate": 1.0,
					"tenacity_tax_s": 1.25,
					"tenacity_tax_events": 1,
					"cc_raw_duration_s": 2.0,
					"cc_effective_duration_s": 0.5
				})
			}
		},
		"subject_unit_ids": ["repo"]
	}

func _scenario_delta_entry(label: String, counterplay_rec: Dictionary) -> Dictionary:
	return {
		"context": {
			"team_a_ids": ["repo"],
			"team_b_ids": ["totem"],
			"scenario_label": String(label)
		},
		"kernels": {
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

func _has_span_label(metric_result: Dictionary, expected_label: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var label: String = String((span_value as Dictionary).get("label", ""))
		if label == expected_label:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
