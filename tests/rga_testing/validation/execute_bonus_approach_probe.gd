extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const ExecuteApproachTest := preload("res://tests/rga_testing/metrics/approach/execute_approach_test.gd")

const HEXEON_ID: String = "hexeon"
const MORRAK_ID: String = "morrak"
const TARGET_ID: String = "target_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hexeon_full_result: Dictionary = _run_case("hexeon_full", HEXEON_ID, 80, 40, 120, 20, 0.30, 0.20)
	var morrak_full_result: Dictionary = _run_case("morrak_full", MORRAK_ID, 80, 40, 120, 20, 0.30, 0.20)
	var hexeon_zero_bonus_result: Dictionary = _run_case("hexeon_zero_bonus", HEXEON_ID, 120, 0, 120, 20, 0.30, 0.20)
	var morrak_zero_bonus_result: Dictionary = _run_case("morrak_zero_bonus", MORRAK_ID, 120, 0, 120, 20, 0.30, 0.20)
	var weak_result: Dictionary = _run_case("weak_execute", HEXEON_ID, 120, 0, 200, 80, 0.30, 0.40)

	var hexeon_full_rec: Dictionary = hexeon_full_result.get("rec", {})
	var morrak_full_rec: Dictionary = morrak_full_result.get("rec", {})
	var hexeon_full_metric: Dictionary = hexeon_full_result.get("metric", {})
	var morrak_full_metric: Dictionary = morrak_full_result.get("metric", {})
	var hexeon_zero_metric: Dictionary = hexeon_zero_bonus_result.get("metric", {})
	var morrak_zero_metric: Dictionary = morrak_zero_bonus_result.get("metric", {})
	var weak_metric: Dictionary = weak_result.get("metric", {})

	var hexeon_full_pass: bool = bool(hexeon_full_metric.get("pass", false))
	var morrak_full_pass: bool = bool(morrak_full_metric.get("pass", false))
	var hexeon_zero_pass: bool = bool(hexeon_zero_metric.get("pass", false))
	var morrak_zero_pass: bool = bool(morrak_zero_metric.get("pass", false))
	var weak_pass: bool = bool(weak_metric.get("pass", false))
	var hexeon_bonus_share: float = float(hexeon_full_rec.get("execute_bonus_damage_share", 0.0))
	var morrak_bonus_share: float = float(morrak_full_rec.get("execute_bonus_damage_share", 0.0))
	var hexeon_full_bonus_span: bool = _has_span(hexeon_full_metric, "subject_execute_bonus_damage_share", true)
	var morrak_full_bonus_span: bool = _has_span(morrak_full_metric, "subject_execute_bonus_damage_share", true)
	var hexeon_zero_bonus_span: bool = _has_span(hexeon_zero_metric, "subject_execute_bonus_damage_share", false)
	var morrak_zero_bonus_span: bool = _has_span(morrak_zero_metric, "subject_execute_bonus_damage_share", false)
	var weak_low_hp_kill_span: bool = _has_span(weak_metric, "subject_low_hp_kills", true)

	print("ExecuteBonusApproachProbe: hexeon_full_pass=", hexeon_full_pass,
		" hexeon_bonus_share=", hexeon_bonus_share,
		" morrak_full_pass=", morrak_full_pass,
		" morrak_bonus_share=", morrak_bonus_share,
		" hexeon_zero_pass=", hexeon_zero_pass,
		" hexeon_zero_bonus_fail_span=", hexeon_zero_bonus_span,
		" morrak_zero_pass=", morrak_zero_pass,
		" morrak_zero_bonus_fail_span=", morrak_zero_bonus_span,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not hexeon_full_pass or not hexeon_full_bonus_span:
		printerr("ExecuteBonusApproachProbe: FAIL Hexeon direct execute-bonus proof did not pass")
		failed = true
	if not morrak_full_pass or not morrak_full_bonus_span:
		printerr("ExecuteBonusApproachProbe: FAIL Morrak direct execute-bonus proof did not pass")
		failed = true
	if hexeon_bonus_share < 0.30 or morrak_bonus_share < 0.30:
		printerr("ExecuteBonusApproachProbe: FAIL direct execute bonus share was below target")
		failed = true
	if not hexeon_zero_pass or not hexeon_zero_bonus_span:
		printerr("ExecuteBonusApproachProbe: FAIL Hexeon zero-bonus aggregate path did not preserve the failed bonus-share span")
		failed = true
	if not morrak_zero_pass or not morrak_zero_bonus_span:
		printerr("ExecuteBonusApproachProbe: FAIL Morrak zero-bonus aggregate path did not preserve the failed bonus-share span")
		failed = true
	if weak_pass or weak_low_hp_kill_span:
		printerr("ExecuteBonusApproachProbe: FAIL weak above-threshold control passed execute")
		failed = true

	if failed:
		_quit(1)
		return
	print("ExecuteBonusApproachProbe: PASS")
	_quit(0)

func _run_case(case_id: String, subject_id: String, base_damage: int, bonus_damage: int, target_max_hp: int, target_hp_before: int, threshold_pct: float, target_hp_pct: float) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(subject_id, target_max_hp, target_hp_before)
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
	kernel.call("tick", 0.25)
	engine._resolver_emit_execute_bonus_applied("player", 0, "enemy", 0, base_damage, bonus_damage, threshold_pct, target_hp_pct, "%s_execute" % case_id)
	engine.emit_signal("hit_applied", "player", 0, 0, base_damage + bonus_damage, base_damage + bonus_damage, false, target_hp_before, 0, 0.0, 0.0)
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

func _make_state(subject_id: String, target_max_hp: int, target_hp: int) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = subject_id
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target: Unit = Unit.new()
	target.id = TARGET_ID
	target.max_hp = target_max_hp
	target.hp = target_hp
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_metric(case_id: String, subject_id: String, kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = ExecuteApproachTest.new()
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
		if label.begins_with(label_prefix) and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
