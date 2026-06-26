extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const RampApproachTest := preload("res://tests/rga_testing/metrics/approach/ramp_approach_test.gd")

const SARI_ID: String = "sari"
const VEYRA_ID: String = "veyra"
const TARGET_ID: String = "target_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var sari_full_result: Dictionary = _run_case("sari_full", SARI_ID, 4, 2, 3.0, 3.0, true)
	var veyra_full_result: Dictionary = _run_case("veyra_full", VEYRA_ID, 4, 2, 3.0, 3.0, true)
	var sari_low_stack_result: Dictionary = _run_case("sari_low_stack", SARI_ID, 1, 2, 3.0, 3.0, true)
	var veyra_low_stack_result: Dictionary = _run_case("veyra_low_stack", VEYRA_ID, 1, 2, 3.0, 3.0, true)
	var weak_result: Dictionary = _run_case("weak_ramp", SARI_ID, 1, 1, 0.0, 0.0, false)

	var sari_full_metric: Dictionary = sari_full_result.get("metric", {})
	var veyra_full_metric: Dictionary = veyra_full_result.get("metric", {})
	var sari_low_metric: Dictionary = sari_low_stack_result.get("metric", {})
	var veyra_low_metric: Dictionary = veyra_low_stack_result.get("metric", {})
	var weak_metric: Dictionary = weak_result.get("metric", {})
	var sari_full_pass: bool = bool(sari_full_metric.get("pass", false))
	var veyra_full_pass: bool = bool(veyra_full_metric.get("pass", false))
	var sari_low_pass: bool = bool(sari_low_metric.get("pass", false))
	var veyra_low_pass: bool = bool(veyra_low_metric.get("pass", false))
	var weak_pass: bool = bool(weak_metric.get("pass", false))
	var sari_stack: float = _span_value(sari_full_metric, "subject_ramp_stack_max")
	var veyra_stack: float = _span_value(veyra_full_metric, "subject_ramp_stack_max")
	var sari_full_stack_span: bool = _has_span(sari_full_metric, "subject_ramp_stack_max", true)
	var veyra_full_stack_span: bool = _has_span(veyra_full_metric, "subject_ramp_stack_max", true)
	var sari_low_stack: float = _span_value(sari_low_metric, "subject_ramp_stack_max")
	var veyra_low_stack: float = _span_value(veyra_low_metric, "subject_ramp_stack_max")
	var sari_low_stack_diagnostic: bool = _has_diagnostic_span(sari_low_metric, "subject_ramp_stack_max", "alternate_ramp_state_evidence_satisfied")
	var veyra_low_stack_diagnostic: bool = _has_diagnostic_span(veyra_low_metric, "subject_ramp_stack_max", "alternate_ramp_state_evidence_satisfied")
	var weak_stack_span: bool = _has_span(weak_metric, "subject_ramp_stack_max", true)

	print("RampApproachProbe: sari_full_pass=", sari_full_pass,
		" sari_stack=", sari_stack,
		" veyra_full_pass=", veyra_full_pass,
		" veyra_stack=", veyra_stack,
		" sari_low_pass=", sari_low_pass,
		" sari_low_stack=", sari_low_stack,
		" sari_low_stack_diagnostic=", sari_low_stack_diagnostic,
		" veyra_low_pass=", veyra_low_pass,
		" veyra_low_stack=", veyra_low_stack,
		" veyra_low_stack_diagnostic=", veyra_low_stack_diagnostic,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not sari_full_pass or not sari_full_stack_span:
		printerr("RampApproachProbe: FAIL Sari full ramp proof did not pass the stack span")
		failed = true
	if not veyra_full_pass or not veyra_full_stack_span:
		printerr("RampApproachProbe: FAIL Veyra full ramp proof did not pass the stack span")
		failed = true
	if sari_stack < 4.0 or veyra_stack < 4.0:
		printerr("RampApproachProbe: FAIL direct full-stack proof was below target")
		failed = true
	if not sari_low_pass or not sari_low_stack_diagnostic or sari_low_stack >= 2.0:
		printerr("RampApproachProbe: FAIL Sari low-stack aggregate path did not keep stack span diagnostic")
		failed = true
	if not veyra_low_pass or not veyra_low_stack_diagnostic or veyra_low_stack >= 2.0:
		printerr("RampApproachProbe: FAIL Veyra low-stack aggregate path did not keep stack span diagnostic")
		failed = true
	if weak_pass or weak_stack_span:
		printerr("RampApproachProbe: FAIL weak ramp control passed")
		failed = true

	if failed:
		_quit(1)
		return
	print("RampApproachProbe: PASS")
	_quit(0)

func _run_case(case_id: String, subject_id: String, stack_max: int, event_count: int, peak_duration_s: float, window_duration_s: float, use_peak_stacks: bool) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(subject_id)
	engine.state = state
	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": subject_id
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
	for i in range(event_count):
		var event_stack: int = 1 if i == 0 else stack_max
		var peak_stack: int = stack_max if use_peak_stacks else max(2, stack_max + 1)
		var duration_s: float = peak_duration_s if i == event_count - 1 else window_duration_s
		kernel.call("tick", float(i + 1))
		engine._resolver_emit_ramp_state_changed("player", 0, "stack_window", event_stack, float(event_stack), peak_stack, duration_s, "%s_ramp_%d" % [case_id, i])
	kernel.call("finalize", 6.0)
	var result: Dictionary = kernel.call("result")
	var metric_result: Dictionary = _run_metric(case_id, subject_id, result)
	kernel.call("detach")
	return {
		"metric": metric_result
	}

func _make_state(subject_id: String) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = subject_id
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target: Unit = Unit.new()
	target.id = TARGET_ID
	target.max_hp = 1000
	target.hp = 1000
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_metric(case_id: String, subject_id: String, kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = RampApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [subject_id],
						"team_b_ids": [TARGET_ID]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": [subject_id]
	}
	return metric.call("run_metric", payload)

func _has_span(metric_result: Dictionary, label_prefix: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and span.has("ok") and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, expected_reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		var reason: String = String(span.get("reason", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and reason == expected_reason:
			return true
	return false

func _span_value(metric_result: Dictionary, label_prefix: String) -> float:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return float(span.get("value", 0.0))
	return 0.0

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
