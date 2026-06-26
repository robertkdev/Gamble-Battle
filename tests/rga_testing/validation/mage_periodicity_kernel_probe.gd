extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const PeriodicityKernel := preload("res://tests/rga_testing/aggregators/kernels/periodicity_kernel.gd")
const MageRoleTest := preload("res://tests/rga_testing/metrics/mage/mage_role_identity_test.gd")

const SUBJECT_ID: String = "luna"
const TARGET_ID: String = "target_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var positive_result: Dictionary = _run_case(true)
	var alternate_result: Dictionary = _run_low_share_peak_case()
	var negative_result: Dictionary = _run_case(false)
	var positive_rec: Dictionary = positive_result.get("rec", {})
	var positive_metric: Dictionary = positive_result.get("metric", {})
	var alternate_rec: Dictionary = alternate_result.get("rec", {})
	var alternate_metric: Dictionary = alternate_result.get("metric", {})
	var negative_metric: Dictionary = negative_result.get("metric", {})
	var magic_share: float = float(positive_rec.get("top_2s_magic_damage_share", 0.0))
	var magic_peak: float = float(positive_rec.get("magic_peak_over_mean", 0.0))
	var alternate_magic_share: float = float(alternate_rec.get("top_2s_magic_damage_share", 0.0))
	var alternate_magic_peak: float = float(alternate_rec.get("magic_peak_over_mean", 0.0))
	var magic_supported: bool = bool(positive_rec.get("magic_supported", false))
	var positive_pass: bool = bool(positive_metric.get("pass", false))
	var alternate_pass: bool = bool(alternate_metric.get("pass", false))
	var negative_pass: bool = bool(negative_metric.get("pass", false))
	var share_span: bool = _has_passing_span(positive_metric, "magic_share_med_a")
	var peak_span: bool = _has_passing_span(positive_metric, "magic_peak_over_mean_med_a")
	var alternate_share_diag: bool = _has_diagnostic_span(alternate_metric, "magic_share_med_a", "alternate_magic_periodicity_evidence_satisfied")
	var alternate_peak_span: bool = _has_passing_span(alternate_metric, "magic_peak_over_mean_med_a")

	print("MagePeriodicityKernelProbe: magic_share=", magic_share,
		" magic_peak=", magic_peak,
		" alternate_magic_share=", alternate_magic_share,
		" alternate_magic_peak=", alternate_magic_peak,
		" alternate_pass=", alternate_pass,
		" alternate_share_diag=", alternate_share_diag,
		" magic_supported=", magic_supported,
		" positive_pass=", positive_pass,
		" negative_pass=", negative_pass)

	var failed: bool = false
	if not magic_supported:
		printerr("MagePeriodicityKernelProbe: FAIL magic periodicity was not supported")
		failed = true
	if magic_share < 0.90 or magic_peak < 1.70:
		printerr("MagePeriodicityKernelProbe: FAIL direct magic periodicity evidence was below proof threshold")
		failed = true
	if not positive_pass:
		printerr("MagePeriodicityKernelProbe: FAIL role_mage_identity did not pass on magic periodicity telemetry")
		failed = true
	if not share_span or not peak_span:
		printerr("MagePeriodicityKernelProbe: FAIL role_mage_identity did not emit passing magic periodicity spans")
		failed = true
	if alternate_magic_share >= 0.35 or alternate_magic_peak < 1.70 or not alternate_pass or not alternate_share_diag or not alternate_peak_span:
		printerr("MagePeriodicityKernelProbe: FAIL alternate peak-over-mean magic evidence did not keep low share diagnostic")
		failed = true
	if negative_pass:
		printerr("MagePeriodicityKernelProbe: FAIL diffuse negative magic case passed role_mage_identity")
		failed = true

	if failed:
		_quit(1)
		return
	print("MagePeriodicityKernelProbe: PASS")
	_quit(0)

func _run_case(concentrated: bool) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = PeriodicityKernel.new()
	kernel.call("attach", engine, true)
	if concentrated:
		_emit_magic_hit(engine, kernel, 0.20, 80)
		_emit_magic_hit(engine, kernel, 0.40, 20)
		kernel.call("finalize", 6.0)
	else:
		_emit_magic_hit(engine, kernel, 0.20, 20)
		_emit_magic_hit(engine, kernel, 2.50, 20)
		_emit_magic_hit(engine, kernel, 2.50, 20)
		_emit_magic_hit(engine, kernel, 2.50, 20)
		_emit_magic_hit(engine, kernel, 2.50, 20)
		kernel.call("finalize", 12.0)
	var result: Dictionary = kernel.call("result")
	var periodicity: Dictionary = result.get("periodicity", {}) if (result is Dictionary) else {}
	var rec: Dictionary = periodicity.get("a", {}) if (periodicity is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)
	kernel.call("detach")
	return {
		"rec": rec,
		"metric": metric_result
	}

func _run_low_share_peak_case() -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = PeriodicityKernel.new()
	kernel.call("attach", engine, true)
	_emit_magic_hit(engine, kernel, 0.20, 80)
	_emit_magic_hit(engine, kernel, 0.20, 20)
	var repeat_index: int = 0
	while repeat_index < 10:
		_emit_magic_hit(engine, kernel, 3.00, 80)
		repeat_index += 1
	kernel.call("finalize", 45.0)
	var result: Dictionary = kernel.call("result")
	var periodicity: Dictionary = result.get("periodicity", {}) if (result is Dictionary) else {}
	var rec: Dictionary = periodicity.get("a", {}) if (periodicity is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)
	kernel.call("detach")
	return {
		"rec": rec,
		"metric": metric_result
	}

func _emit_magic_hit(engine: CombatEngine, kernel: Variant, delta_s: float, magic_damage: int) -> void:
	kernel.call("tick", delta_s)
	engine.emit_signal("hit_components", "player", 0, "enemy", 0, 0, magic_damage, 0)

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = MageRoleTest.new()
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
