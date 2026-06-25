extends Node

# Synthetic guard for the current accepted-miss counterplay bucket.
# It proves the affected unit semantics pass once a cleanse/high-tenacity
# scenario supplies the missing response pressure.

const LockdownApproachTest := preload("res://tests/rga_testing/metrics/approach/lockdown_approach_test.gd")
const DebuffApproachTest := preload("res://tests/rga_testing/metrics/approach/debuff_approach_test.gd")

const DEBUFF_COUNTERPLAY_UNITS: Array[String] = ["grint", "kythera", "sari"]
const LOCKDOWN_COUNTERPLAY_UNITS: Array[String] = ["brute", "volt"]

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var checked_units: Dictionary = {}
	var required_passing_spans: int = 0
	for unit_id in DEBUFF_COUNTERPLAY_UNITS:
		var subject_id: String = String(unit_id)
		checked_units[subject_id] = true
		var debuff_result: Dictionary = _run_debuff_metric(_counterplay_payload(subject_id, _debuff_neutral_rec(), _debuff_counter_rec()))
		_require_result(debuff_result, subject_id, "approach_debuff", PackedStringArray([
			"subject_debuff_cleanse_pressure",
			"subject_debuff_cleanse_bait_rate",
			"subject_debuff_cleanse_scenario_delta"
		]), failures)
		required_passing_spans += 3
	for unit_id in LOCKDOWN_COUNTERPLAY_UNITS:
		var subject_id: String = String(unit_id)
		checked_units[subject_id] = true
		var lockdown_result: Dictionary = _run_lockdown_metric(_counterplay_payload(subject_id, _lockdown_neutral_rec(), _lockdown_counter_rec()))
		_require_result(lockdown_result, subject_id, "approach_lockdown", PackedStringArray([
			"subject_lockdown_cleanse_pressure",
			"subject_lockdown_tenacity_tax_s",
			"subject_lockdown_cleanse_scenario_delta",
			"subject_lockdown_high_tenacity_tax_delta_s",
			"subject_lockdown_high_tenacity_effective_drop_s"
		]), failures)
		required_passing_spans += 5

	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		_quit(1)
		return
	print("CounterplayContextTriageSmoke: PASS units=", checked_units.size(), " required_passing_spans=", required_passing_spans)
	_quit(0)

func _run_debuff_metric(payload: Dictionary) -> Dictionary:
	var metric: Variant = DebuffApproachTest.new()
	return metric.call("run_metric", payload)

func _run_lockdown_metric(payload: Dictionary) -> Dictionary:
	var metric: Variant = LockdownApproachTest.new()
	return metric.call("run_metric", payload)

func _counterplay_payload(subject_id: String, neutral_rec: Dictionary, counter_rec: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "mixed_counterplay",
			"sims": {
				"neutral": _entry(subject_id, "neutral", neutral_rec),
				"high_tenacity_cleanse": _entry(subject_id, "high_tenacity_cleanse", counter_rec)
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _entry(subject_id: String, scenario_label: String, counterplay_rec: Dictionary) -> Dictionary:
	return {
		"context": {
			"team_a_ids": [subject_id],
			"team_b_ids": ["totem"],
			"scenario_label": scenario_label
		},
		"kernels": {
			"counterplay_pressure": {
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
		}
	}

func _debuff_neutral_rec() -> Dictionary:
	return {
		"debuffs_applied_for_counterplay": 2,
		"cleanse_pressure_events": 0,
		"cleanse_pressure_removed": 0,
		"cleanse_bait_events": 0,
		"cleanse_bait_rate": 0.0
	}

func _debuff_counter_rec() -> Dictionary:
	return {
		"debuffs_applied_for_counterplay": 2,
		"cleanse_pressure_events": 3,
		"cleanse_pressure_removed": 3,
		"cleanse_bait_events": 2,
		"cleanse_bait_rate": 1.0
	}

func _lockdown_neutral_rec() -> Dictionary:
	return {
		"cleanse_pressure_events": 0,
		"tenacity_tax_s": 0.0,
		"tenacity_tax_events": 0,
		"cc_raw_duration_s": 2.0,
		"cc_effective_duration_s": 2.0,
		"cc_prevented_by_immunity": 0
	}

func _lockdown_counter_rec() -> Dictionary:
	return {
		"cleanse_pressure_events": 3,
		"tenacity_tax_s": 1.5,
		"tenacity_tax_events": 1,
		"cc_raw_duration_s": 2.0,
		"cc_effective_duration_s": 0.5,
		"cc_prevented_by_immunity": 0
	}

func _require_result(metric_result: Dictionary, subject_id: String, metric_id: String, required_labels: PackedStringArray, failures: Array[String]) -> void:
	if not bool(metric_result.get("pass", false)):
		failures.append("%s: FAIL %s did not pass for %s; message=%s" % [
			"CounterplayContextTriageSmoke",
			metric_id,
			subject_id,
			String(metric_result.get("message", ""))
		])
	for label in required_labels:
		if not _has_passing_span(metric_result, String(label)):
			failures.append("%s: FAIL %s missing passing span %s for %s" % [
				"CounterplayContextTriageSmoke",
				metric_id,
				String(label),
				subject_id
			])

func _has_passing_span(metric_result: Dictionary, expected_label: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value
		var label: String = String(span.get("label", ""))
		if label == expected_label and bool(span.get("ok", false)):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
