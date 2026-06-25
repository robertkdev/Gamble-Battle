extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const AoeApproachTest := preload("res://tests/rga_testing/metrics/approach/aoe_approach_test.gd")

const SUBJECT_IDS: Array[String] = ["luna", "morrak", "nyxa", "paisley", "teller"]
const TARGET_IDS: Array[String] = ["target_alpha", "target_beta", "target_gamma"]

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var full_passes: int = 0
	var low_median_passes: int = 0
	for subject_id in SUBJECT_IDS:
		var full_result: Dictionary = _run_case("%s_full_aoe" % subject_id, subject_id, "full")
		var low_result: Dictionary = _run_case("%s_low_median_aoe" % subject_id, subject_id, "low_median")
		var full_metric: Dictionary = full_result.get("metric", {})
		var full_rec: Dictionary = full_result.get("rec", {})
		var low_metric: Dictionary = low_result.get("metric", {})
		var low_rec: Dictionary = low_result.get("rec", {})
		var full_pass: bool = bool(full_metric.get("pass", false))
		var full_targets_median: float = float(full_rec.get("targets_hit_median", 0.0))
		var full_median_span: bool = _has_span(full_metric, "subject_targets_hit_median", true)
		var low_pass: bool = bool(low_metric.get("pass", false))
		var low_targets_median: float = float(low_rec.get("targets_hit_median", 0.0))
		var low_max_targets: int = int(low_rec.get("max_targets_hit", 0))
		var low_median_fail_span: bool = _has_span(low_metric, "subject_targets_hit_median", false)
		if full_pass and full_median_span and full_targets_median >= 2.0:
			full_passes += 1
		else:
			failures.append("AoeMultiTargetApproachProbe: FAIL %s full AoE proof pass=%s median=%.2f median_span=%s" % [subject_id, str(full_pass), full_targets_median, str(full_median_span)])
		if low_pass and low_median_fail_span and low_targets_median < 1.5 and low_max_targets >= 2:
			low_median_passes += 1
		else:
			failures.append("AoeMultiTargetApproachProbe: FAIL %s low-median aggregate path pass=%s median=%.2f max=%d fail_span=%s" % [subject_id, str(low_pass), low_targets_median, low_max_targets, str(low_median_fail_span)])

	var weak_result: Dictionary = _run_case("weak_single_target_aoe", SUBJECT_IDS[0], "weak")
	var weak_metric: Dictionary = weak_result.get("metric", {})
	var weak_pass: bool = bool(weak_metric.get("pass", false))
	var weak_median_span: bool = _has_span(weak_metric, "subject_targets_hit_median", true)
	if weak_pass or weak_median_span:
		failures.append("AoeMultiTargetApproachProbe: FAIL weak single-target control passed")

	print("AoeMultiTargetApproachProbe: full_passes=", full_passes,
		" low_median_passes=", low_median_passes,
		" weak_pass=", weak_pass)

	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		_quit(1)
		return
	print("AoeMultiTargetApproachProbe: PASS")
	_quit(0)

func _run_case(case_id: String, subject_id: String, mode: String) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(subject_id)
	engine.state = state
	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": TARGET_IDS.size()}
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
					"unit_id": TARGET_IDS[0]
				},
				{
					"unit_index": 1,
					"unit_id": TARGET_IDS[1]
				},
				{
					"unit_index": 2,
					"unit_id": TARGET_IDS[2]
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	if mode == "full":
		_emit_group(engine, kernel, 0.20, PackedInt32Array([0, 1]), 35)
		_emit_group(engine, kernel, 0.20, PackedInt32Array([0, 1, 2]), 35)
	elif mode == "low_median":
		_emit_group(engine, kernel, 0.20, PackedInt32Array([0]), 15)
		_emit_group(engine, kernel, 0.20, PackedInt32Array([1]), 15)
		_emit_group(engine, kernel, 0.20, PackedInt32Array([0, 2]), 45)
	else:
		_emit_group(engine, kernel, 0.20, PackedInt32Array([0]), 25)
		_emit_group(engine, kernel, 0.20, PackedInt32Array([1]), 25)
	kernel.call("finalize", 1.0)
	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(subject_id, {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric(case_id, subject_id, result)
	kernel.call("detach")
	return {
		"rec": rec,
		"metric": metric_result
	}

func _emit_group(engine: CombatEngine, kernel: Variant, delta_s: float, target_indices: PackedInt32Array, damage: int) -> void:
	kernel.call("tick", delta_s)
	for target_index in target_indices:
		engine.emit_signal("hit_applied", "player", 0, int(target_index), damage, damage, false, 1000, 1000 - damage, 0.0, 0.0)

func _make_state(subject_id: String) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = subject_id
	attacker.max_hp = 1000
	attacker.hp = 1000
	var targets: Array[Unit] = []
	for target_id in TARGET_IDS:
		var target: Unit = Unit.new()
		target.id = String(target_id)
		target.max_hp = 1000
		target.hp = 1000
		targets.append(target)
	var player_team: Array[Unit] = [attacker]
	state.player_team = player_team
	state.enemy_team = targets
	return state

func _run_metric(case_id: String, subject_id: String, kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = AoeApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [subject_id],
						"team_b_ids": TARGET_IDS
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
		if label.begins_with(label_prefix) and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
