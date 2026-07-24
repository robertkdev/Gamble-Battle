extends Node

const RoleMatrixProbe = preload("res://tests/rga_testing/validation/RoleMatrixProbe.gd")
const RoleMetricsContextBuilder = preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const TelemetryCapabilities = preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const AoeApproachTest = preload("res://tests/rga_testing/metrics/approach/aoe_approach_test.gd")

const SUBJECT_IDS: Array[String] = ["luna", "morrak", "nyxa", "paisley", "omenry"]
const CLUSTER_LABELS: Array[String] = ["clustered", "clustered_alt"]

@export var do_quit_on_finish: bool = true

var _finished_for: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var passing_subjects: int = 0
	for subject_id in SUBJECT_IDS:
		var result: Dictionary = await _run_subject(String(subject_id))
		if bool(result.get("passed", false)):
			passing_subjects += 1
		else:
			failures.append(String(result.get("message", "AoeClusteredScenarioProbe: unknown failure for %s" % subject_id)))

	print("AoeClusteredScenarioProbe: passing_subjects=", passing_subjects, " total=", SUBJECT_IDS.size())
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		_quit(1)
		return
	print("AoeClusteredScenarioProbe: PASS")
	_quit(0)

func _run_subject(subject_id: String) -> Dictionary:
	_finished_for.erase(subject_id)
	var probe: Node = RoleMatrixProbe.new()
	probe.set("subject_unit_id", subject_id)
	probe.set("quick_balance_mode", true)
	probe.set("quick_balance_seed_count", 1)
	probe.set("quick_balance_labels", _cluster_labels())
	probe.set("scenario_packs_to_run", _cluster_labels())
	probe.set("profile", "full_probe_6v6")
	probe.set("scenario_labels_6v6", _cluster_labels())
	probe.set("max_seeds_per_label", 1)
	probe.set("max_sims", CLUSTER_LABELS.size())
	probe.set("metric_ids", PackedStringArray(["approach_aoe"]))
	probe.set("out_root", "user://rga_probe/aoe_clustered/%s" % subject_id)
	probe.set("write_reports", false)
	probe.set("resume_if_exists", false)
	probe.set("do_quit_on_finish", false)
	probe.connect("finished", Callable(self, "_on_probe_finished"), CONNECT_ONE_SHOT)
	add_child(probe)

	var start_ms: int = Time.get_ticks_msec()
	while not _finished_for.has(subject_id) and (Time.get_ticks_msec() - start_ms) < 240000:
		await get_tree().process_frame

	if probe.get_parent() != null:
		remove_child(probe)
	probe.queue_free()

	if not _finished_for.has(subject_id):
		return {
			"passed": false,
			"message": "AoeClusteredScenarioProbe: %s timed out waiting for RoleMatrixProbe" % subject_id
		}

	var rows_path: String = "user://rga_probe/aoe_clustered/%s/run_role_matrix6v6_%s" % [subject_id, subject_id]
	var ctx: Dictionary = RoleMetricsContextBuilder.build(rows_path, TelemetryCapabilities.all_caps(), "")
	var sims: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	if sims.size() != CLUSTER_LABELS.size():
		return {
			"passed": false,
			"message": "AoeClusteredScenarioProbe: %s expected %d sims, found %d at %s" % [subject_id, CLUSTER_LABELS.size(), sims.size(), rows_path]
		}

	var metric: Variant = AoeApproachTest.new()
	var metric_result: Dictionary = metric.call("run_metric", {
		"context": ctx,
		"subject_unit_ids": [subject_id]
	})
	var median_span: Dictionary = _span(metric_result, "subject_targets_hit_median")
	var max_span: Dictionary = _span(metric_result, "subject_max_targets_hit")
	var dps_span: Dictionary = _span(metric_result, "subject_aoe_dps_med")
	var median_value: float = float(median_span.get("value", 0.0))
	var median_diagnostic: bool = not median_span.has("ok") and String(median_span.get("reason", "")) == "alternate_aoe_evidence_satisfied"
	var max_value: float = float(max_span.get("value", 0.0))
	var max_ok: bool = bool(max_span.get("ok", false))
	var dps_value: float = float(dps_span.get("value", 0.0))
	var dps_ok: bool = bool(dps_span.get("ok", false))
	var metric_ok: bool = bool(metric_result.get("pass", false))
	print("AoeClusteredScenarioProbe: unit=", subject_id,
		" median=", median_value,
		" median_diagnostic=", median_diagnostic,
		" max_targets=", max_value,
		" max_ok=", max_ok,
		" aoe_dps=", dps_value,
		" dps_ok=", dps_ok,
		" metric_ok=", metric_ok)
	if not metric_ok or not (max_ok or dps_ok) or not median_diagnostic:
		return {
			"passed": false,
			"message": "AoeClusteredScenarioProbe: %s clustered AoE proof failed metric_ok=%s median=%.2f median_diagnostic=%s max=%.2f dps=%.2f" % [subject_id, str(metric_ok), median_value, str(median_diagnostic), max_value, dps_value]
		}
	return {"passed": true}

func _on_probe_finished(unit_id: String, _report_path: String) -> void:
	_finished_for[String(unit_id)] = true

func _span(metric_result: Dictionary, label: String) -> Dictionary:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		if String(span.get("label", "")) == label:
			return span
	return {}

func _cluster_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for label in CLUSTER_LABELS:
		labels.append(String(label))
	return labels

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
