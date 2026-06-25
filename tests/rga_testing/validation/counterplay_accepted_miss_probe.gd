extends Node

const DebuffApproachTest := preload("res://tests/rga_testing/metrics/approach/debuff_approach_test.gd")
const LockdownApproachTest := preload("res://tests/rga_testing/metrics/approach/lockdown_approach_test.gd")

const DEBUFF_IDS: Array[String] = ["kythera", "sari"]
const LOCKDOWN_IDS: Array[String] = ["brute", "volt"]
const RESPONSE_ID: String = "totem"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var debuff_full_passes: int = 0
	var debuff_low_passes: int = 0
	var lockdown_full_passes: int = 0
	var lockdown_low_passes: int = 0
	var weak_debuff_pass: bool = false
	var weak_lockdown_pass: bool = false
	var failed: bool = false

	for subject_id in DEBUFF_IDS:
		var full_debuff: Dictionary = _run_debuff(_debuff_payload(String(subject_id), true, true))
		var low_debuff: Dictionary = _run_debuff(_debuff_payload(String(subject_id), true, false))
		var weak_debuff: Dictionary = _run_debuff(_debuff_payload(String(subject_id), false, false))
		if bool(full_debuff.get("pass", false)) and _has_span(full_debuff, "subject_debuff_cleanse_pressure", true) and _has_span(full_debuff, "subject_debuff_cleanse_bait_rate", true) and _has_span(full_debuff, "subject_debuff_cleanse_scenario_delta", true):
			debuff_full_passes += 1
		else:
			printerr("CounterplayAcceptedMissProbe: FAIL full debuff counterplay proof for ", String(subject_id))
			failed = true
		if bool(low_debuff.get("pass", false)) and _has_span(low_debuff, "subject_debuff_enemy_events", true) and _has_span(low_debuff, "subject_debuff_cleanse_pressure", false) and _has_span(low_debuff, "subject_debuff_cleanse_bait_rate", false) and _has_span(low_debuff, "subject_debuff_cleanse_scenario_delta", false):
			debuff_low_passes += 1
		else:
			printerr("CounterplayAcceptedMissProbe: FAIL low-response debuff aggregate control for ", String(subject_id))
			failed = true
		weak_debuff_pass = weak_debuff_pass or bool(weak_debuff.get("pass", false))

	for subject_id in LOCKDOWN_IDS:
		var full_lockdown: Dictionary = _run_lockdown(_lockdown_payload(String(subject_id), true, true))
		var low_lockdown: Dictionary = _run_lockdown(_lockdown_payload(String(subject_id), true, false))
		var weak_lockdown: Dictionary = _run_lockdown(_lockdown_payload(String(subject_id), false, false))
		if bool(full_lockdown.get("pass", false)) and _has_span(full_lockdown, "subject_lockdown_cleanse_scenario_delta", true) and _has_span(full_lockdown, "subject_lockdown_high_tenacity_tax_delta_s", true) and _has_span(full_lockdown, "subject_lockdown_high_tenacity_effective_drop_s", true):
			lockdown_full_passes += 1
		else:
			printerr("CounterplayAcceptedMissProbe: FAIL full lockdown counterplay proof for ", String(subject_id))
			failed = true
		if bool(low_lockdown.get("pass", false)) and _has_span(low_lockdown, "subject_lockdown_seconds_on_priority", true) and _has_span(low_lockdown, "subject_lockdown_cleanse_scenario_delta", false) and _has_span(low_lockdown, "subject_lockdown_high_tenacity_effective_drop_s", false):
			lockdown_low_passes += 1
		else:
			printerr("CounterplayAcceptedMissProbe: FAIL low-response lockdown aggregate control for ", String(subject_id))
			failed = true
		weak_lockdown_pass = weak_lockdown_pass or bool(weak_lockdown.get("pass", false))

	print("CounterplayAcceptedMissProbe: debuff_full_passes=", debuff_full_passes,
		" debuff_low_passes=", debuff_low_passes,
		" lockdown_full_passes=", lockdown_full_passes,
		" lockdown_low_passes=", lockdown_low_passes,
		" weak_debuff_pass=", weak_debuff_pass,
		" weak_lockdown_pass=", weak_lockdown_pass)

	if weak_debuff_pass:
		printerr("CounterplayAcceptedMissProbe: FAIL weak debuff control passed")
		failed = true
	if weak_lockdown_pass:
		printerr("CounterplayAcceptedMissProbe: FAIL weak lockdown control passed")
		failed = true
	if debuff_full_passes != DEBUFF_IDS.size() or debuff_low_passes != DEBUFF_IDS.size():
		failed = true
	if lockdown_full_passes != LOCKDOWN_IDS.size() or lockdown_low_passes != LOCKDOWN_IDS.size():
		failed = true

	if failed:
		_quit(1)
		return
	print("CounterplayAcceptedMissProbe: PASS")
	_quit(0)

func _run_debuff(payload: Dictionary) -> Dictionary:
	var metric: Variant = DebuffApproachTest.new()
	return metric.call("run_metric", payload)

func _run_lockdown(payload: Dictionary) -> Dictionary:
	var metric: Variant = LockdownApproachTest.new()
	return metric.call("run_metric", payload)

func _debuff_payload(subject_id: String, direct_debuff: bool, response_pressure: bool) -> Dictionary:
	return {
		"context": {
			"scenario": "mixed_counterplay",
			"sims": {
				"neutral": _debuff_entry(subject_id, "neutral", direct_debuff, false),
				"high_tenacity_cleanse": _debuff_entry(subject_id, "high_tenacity_cleanse", direct_debuff, response_pressure)
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _lockdown_payload(subject_id: String, direct_lockdown: bool, response_pressure: bool) -> Dictionary:
	return {
		"context": {
			"scenario": "mixed_counterplay",
			"sims": {
				"neutral": _lockdown_entry(subject_id, "neutral", direct_lockdown, false),
				"high_tenacity_cleanse": _lockdown_entry(subject_id, "high_tenacity_cleanse", direct_lockdown, response_pressure)
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _debuff_entry(subject_id: String, scenario_label: String, direct_debuff: bool, response_pressure: bool) -> Dictionary:
	var buff_rec: Dictionary = {
		"enemy_debuffs": 2 if direct_debuff else 0,
		"debuff_magnitude": 2.0 if direct_debuff else 0.0
	}
	var counterplay_rec: Dictionary = {
		"debuffs_applied_for_counterplay": 2 if direct_debuff else 0,
		"cleanse_pressure_events": 3 if response_pressure else 0,
		"cleanse_pressure_removed": 3 if response_pressure else 0,
		"cleanse_bait_events": 2 if response_pressure else 0,
		"cleanse_bait_rate": 1.0 if response_pressure else 0.0
	}
	return {
		"context": {
			"team_a_ids": [subject_id],
			"team_b_ids": [RESPONSE_ID],
			"scenario_label": scenario_label
		},
		"kernels": {
			"buff_presence": {
				"supported": true,
				"per_unit": {
					"a": {
						subject_id: buff_rec
					}
				}
			},
			"counterplay_pressure": _counterplay_block(subject_id, counterplay_rec)
		}
	}

func _lockdown_entry(subject_id: String, scenario_label: String, direct_lockdown: bool, response_pressure: bool) -> Dictionary:
	var lockdown_rec: Dictionary = {
		"seconds_on_priority": 2.0 if direct_lockdown else 0.0,
		"events": 1 if direct_lockdown else 0
	}
	var counterplay_rec: Dictionary = {
		"cleanse_pressure_events": 3 if response_pressure else 0,
		"tenacity_tax_s": 1.5 if response_pressure else 0.0,
		"tenacity_tax_events": 1 if response_pressure else 0,
		"cc_raw_duration_s": 2.0 if response_pressure else 2.0,
		"cc_effective_duration_s": 0.5 if response_pressure else 2.0,
		"cc_prevented_by_immunity": 0
	}
	return {
		"context": {
			"team_a_ids": [subject_id],
			"team_b_ids": [RESPONSE_ID],
			"scenario_label": scenario_label
		},
		"kernels": {
			"lockdown": {
				"a": {
					"per_unit": {
						subject_id: lockdown_rec
					}
				}
			},
			"counterplay_pressure": _counterplay_block(subject_id, counterplay_rec)
		}
	}

func _counterplay_block(subject_id: String, counterplay_rec: Dictionary) -> Dictionary:
	return {
		"supported": true,
		"per_unit": {
			"a": {
				subject_id: counterplay_rec
			},
			"b": {}
		},
		"target_unit": {
			"a": {},
			"b": {}
		}
	}

func _has_span(metric_result: Dictionary, expected_label: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label == expected_label and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
