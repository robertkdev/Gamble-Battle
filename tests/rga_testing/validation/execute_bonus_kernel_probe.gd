extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const ExecuteApproachTest := preload("res://tests/rga_testing/metrics/approach/execute_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.state = state

	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "hexeon"
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

	kernel.call("tick", 0.25)
	engine.emit_signal("hit_applied", "player", 0, 0, 150, 150, false, 200, 50, 0.0, 0.0)
	engine._resolver_emit_execute_bonus_applied("player", 0, "enemy", 0, 150, 50, 0.30, 0.25, "probe_execute")
	engine.emit_signal("hit_applied", "player", 0, 0, 50, 50, false, 50, 0, 0.0, 0.0)
	kernel.call("finalize", 0.25)

	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("hexeon", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)

	var supported: bool = bool(combat_patterns.get("execute_bonus_supported", false))
	var bonus_events: int = int(rec.get("execute_bonus_events", 0))
	var bonus_damage: float = float(rec.get("execute_bonus_damage", 0.0))
	var bonus_share: float = float(rec.get("execute_bonus_damage_share", 0.0))
	var low_hp_kills: int = int(rec.get("low_hp_kill_count", 0))
	var outside_threshold: int = int(rec.get("execute_bonus_outside_threshold_events", 0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_bonus_span: bool = _has_span_prefix(metric_result, "subject_execute_bonus_damage_share")

	print("ExecuteBonusKernelProbe: supported=", supported,
		" events=", bonus_events,
		" bonus_damage=", bonus_damage,
		" bonus_share=", bonus_share,
		" low_hp_kills=", low_hp_kills,
		" outside_threshold=", outside_threshold,
		" metric_pass=", metric_pass)

	var failed: bool = false
	if not supported:
		printerr("ExecuteBonusKernelProbe: FAIL execute_bonus_applied signal was not connected")
		failed = true
	if bonus_events != 1 or not is_equal_approx(bonus_damage, 50.0):
		printerr("ExecuteBonusKernelProbe: FAIL execute bonus event/damage was not recorded")
		failed = true
	if not is_equal_approx(bonus_share, 0.25):
		printerr("ExecuteBonusKernelProbe: FAIL execute bonus share was not recorded")
		failed = true
	if low_hp_kills != 1:
		printerr("ExecuteBonusKernelProbe: FAIL low-HP execute kill was not recorded")
		failed = true
	if outside_threshold != 0:
		printerr("ExecuteBonusKernelProbe: FAIL execute bonus was treated as outside threshold")
		failed = true
	if not metric_pass:
		printerr("ExecuteBonusKernelProbe: FAIL approach_execute did not pass on direct execute telemetry")
		failed = true
	if not metric_bonus_span:
		printerr("ExecuteBonusKernelProbe: FAIL approach_execute did not emit direct bonus-share span")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("ExecuteBonusKernelProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = "hexeon"
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target: Unit = Unit.new()
	target.id = "korath"
	target.max_hp = 200
	target.hp = 200
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = ExecuteApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["hexeon"],
						"team_b_ids": ["korath"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["hexeon"]
	}
	return metric.call("run_metric", payload)

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
