extends Node

const ProbeReportCompiler := preload("res://tests/rga_testing/validation/probe_report_compiler.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SOFT_SUBJECT_ID: String = "probe_soft_peel_support"
const HARD_SUBJECT_ID: String = "probe_hard_peel_support"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var ok: bool = true
	ok = _assert_soft_peel_skips_hard_peel_diagnostics() and ok
	ok = _assert_hard_peel_keeps_hard_peel_diagnostics() and ok
	RoleCommon.clear_identity_cache()
	if ok:
		print("ProbeReportCompilerHardPeelApplicabilitySmoke: PASS")
		get_tree().quit(0)
	else:
		printerr("ProbeReportCompilerHardPeelApplicabilitySmoke: FAIL")
		get_tree().quit(1)

func _assert_soft_peel_skips_hard_peel_diagnostics() -> bool:
	_install_identity(SOFT_SUBJECT_ID, "support", "support.team_amplification", ["amp", "peel", "sustain"])
	var report: Dictionary[String, Variant] = _typed_dictionary(ProbeReportCompiler.compile(
		SOFT_SUBJECT_ID,
		{},
		{"metrics": _metrics_for_subject(SOFT_SUBJECT_ID)},
		{"run_id": "soft_peel_applicability"}
	))
	var labels: Array[String] = _labels(_diagnostic_spans(report))
	if labels.has("subject_support_cc_immunity") or labels.has("subject_support_cleanse_applied"):
		printerr("Smoke: soft support identity kept role hard-peel diagnostics: ", labels)
		return false
	if labels.has("subject_peel_cc_immunity_grants") or labels.has("subject_peel_cleanse_applied"):
		printerr("Smoke: soft peel identity kept approach hard-peel diagnostics: ", labels)
		return false
	if not labels.has("team_peel_saves_total"):
		printerr("Smoke: soft peel identity lost team peel-save scenario diagnostic: ", labels)
		return false
	if int((_typed_dictionary(report.get("diagnostics", {}))).get("lower_level_fail_span_count", -1)) != 1:
		printerr("Smoke: soft peel expected exactly one remaining diagnostic, got ", report.get("diagnostics", {}))
		return false
	return true

func _assert_hard_peel_keeps_hard_peel_diagnostics() -> bool:
	_install_identity(HARD_SUBJECT_ID, "support", "support.peel_carry", ["peel", "cc_immunity", "amp"])
	var report: Dictionary[String, Variant] = _typed_dictionary(ProbeReportCompiler.compile(
		HARD_SUBJECT_ID,
		{},
		{"metrics": _metrics_for_subject(HARD_SUBJECT_ID)},
		{"run_id": "hard_peel_applicability"}
	))
	var labels: Array[String] = _labels(_diagnostic_spans(report))
	for expected_label: String in [
		"subject_support_cc_immunity",
		"subject_support_cleanse_applied",
		"subject_peel_cc_immunity_grants",
		"subject_peel_cleanse_applied",
		"team_peel_saves_total"
	]:
		if not labels.has(expected_label):
			printerr("Smoke: hard peel identity lost expected diagnostic ", expected_label, " labels=", labels)
			return false
	if int((_typed_dictionary(report.get("diagnostics", {}))).get("lower_level_fail_span_count", -1)) != 5:
		printerr("Smoke: hard peel expected five diagnostics, got ", report.get("diagnostics", {}))
		return false
	return true

func _install_identity(subject_id: String, primary_role: String, primary_goal: String, approaches: Array[String]) -> void:
	RoleCommon.clear_identity_cache()
	RoleCommon._identity_cache[subject_id] = {
		"unit_id": subject_id,
		"primary_role": primary_role,
		"primary_goal": primary_goal,
		"approaches": approaches.duplicate(),
		"cost": 1,
		"level": 1
	}

func _metrics_for_subject(subject_id: String) -> Array[Dictionary]:
	return [
		{
			"id": "role_support_identity",
			"status": "pass",
			"message": "synthetic support pass with optional hard-peel misses",
			"spans": [
				_span("subject_support_events", 2.0, 1.0, true, subject_id),
				_span("subject_support_cc_immunity", 0.0, 1.0, false, subject_id),
				_span("subject_support_cleanse_applied", 0.0, 1.0, false, subject_id)
			]
		},
		{
			"id": "approach_peel",
			"status": "pass",
			"message": "synthetic peel pass with ally protection",
			"spans": [
				_span("subject_peel_ally_protection_magnitude", 50.0, 25.0, true, subject_id),
				_span("subject_peel_cc_immunity_grants", 0.0, 1.0, false, subject_id),
				_span("subject_peel_cleanse_applied", 0.0, 1.0, false, subject_id),
				_span("team_peel_saves_total", 0.0, 1.0, false, subject_id)
			]
		}
	]

func _span(label: String, value: float, want: float, ok: bool, subject_id: String) -> Dictionary[String, Variant]:
	return {
		"label": label,
		"value": value,
		"want": want,
		"ok": ok,
		"unit_id": subject_id,
		"subject_side": "a",
		"subject_role": "support"
	}

func _diagnostic_spans(report: Dictionary[String, Variant]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var diagnostics: Dictionary[String, Variant] = _typed_dictionary(report.get("diagnostics", {}))
	var raw_spans_value: Variant = diagnostics.get("lower_level_fail_spans", [])
	if not (raw_spans_value is Array):
		return out
	for raw_span: Variant in raw_spans_value:
		if raw_span is Dictionary:
			var typed_span: Dictionary = raw_span
			out.append(typed_span)
	return out

func _typed_dictionary(raw_value: Variant) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if not (raw_value is Dictionary):
		return out
	var source: Dictionary = raw_value
	for key: Variant in source.keys():
		out[String(key)] = source[key]
	return out

func _labels(spans: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for span: Dictionary in spans:
		out.append(String(span.get("label", "")))
	return out
