extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const ControlMobilityKernel := preload("res://tests/rga_testing/aggregators/kernels/control_mobility_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const LUNA_ID: String = "luna"
const PAISLEY_ID: String = "paisley"
const TARGET_A_ID: String = "wombo_target_a"
const TARGET_B_ID: String = "wombo_target_b"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var full_result: Dictionary = _run_case("luna_full_wombo", LUNA_ID, _full_burst_groups(), true)
	var no_cc_result: Dictionary = _run_case("luna_no_cc", LUNA_ID, _full_burst_groups(), false)
	var paisley_full_result: Dictionary = _run_case("paisley_full_wombo", PAISLEY_ID, _full_burst_groups(), true)
	var paisley_diffuse_result: Dictionary = _run_case("paisley_diffuse_wombo", PAISLEY_ID, _diffuse_multitarget_groups(), true)
	var weak_result: Dictionary = _run_case("weak_wombo", LUNA_ID, _weak_single_target_groups(), false)

	var full_rec: Dictionary = full_result.get("rec", {})
	var full_control: Dictionary = full_result.get("control", {})
	var full_goal: Dictionary = full_result.get("goal", {})
	var no_cc_goal: Dictionary = no_cc_result.get("goal", {})
	var paisley_full_goal: Dictionary = paisley_full_result.get("goal", {})
	var paisley_diffuse_rec: Dictionary = paisley_diffuse_result.get("rec", {})
	var paisley_diffuse_goal: Dictionary = paisley_diffuse_result.get("goal", {})
	var weak_goal: Dictionary = weak_result.get("goal", {})

	var full_pass: bool = bool(full_goal.get("pass", false))
	var no_cc_pass: bool = bool(no_cc_goal.get("pass", false))
	var paisley_full_pass: bool = bool(paisley_full_goal.get("pass", false))
	var paisley_diffuse_pass: bool = bool(paisley_diffuse_goal.get("pass", false))
	var weak_pass: bool = bool(weak_goal.get("pass", false))
	var full_peak_share: float = float(full_rec.get("peak_1s_damage_share", 0.0))
	var full_targets: int = int(full_rec.get("max_targets_hit", 0))
	var full_cc_events: int = int(full_control.get("cc_events", 0))
	var full_peak_span: bool = _has_span(full_goal, "goal_wombo_combo_burst_peak_1s_share", true)
	var full_targets_span: bool = _has_span(full_goal, "goal_wombo_combo_burst_targets_hit", true)
	var full_sync_span: bool = _has_span(full_goal, "goal_wombo_combo_burst_cc_sync_proxy", true)
	var no_cc_sync_fail_span: bool = _has_span(no_cc_goal, "goal_wombo_combo_burst_cc_sync_proxy", false)
	var paisley_full_peak_span: bool = _has_span(paisley_full_goal, "goal_wombo_combo_burst_peak_1s_share", true)
	var paisley_diffuse_peak_share: float = float(paisley_diffuse_rec.get("peak_1s_damage_share", 0.0))
	var paisley_diffuse_peak_fail_span: bool = _has_span(paisley_diffuse_goal, "goal_wombo_combo_burst_peak_1s_share", false)
	var weak_peak_span: bool = _has_span(weak_goal, "goal_wombo_combo_burst_peak_1s_share", true)
	var weak_targets_span: bool = _has_span(weak_goal, "goal_wombo_combo_burst_targets_hit", true)
	var weak_sync_span: bool = _has_span(weak_goal, "goal_wombo_combo_burst_cc_sync_proxy", true)

	print("WomboComboGoalProbe: full_pass=", full_pass,
		" full_peak_share=", full_peak_share,
		" full_targets=", full_targets,
		" full_cc_events=", full_cc_events,
		" no_cc_pass=", no_cc_pass,
		" no_cc_sync_fail_span=", no_cc_sync_fail_span,
		" paisley_full_pass=", paisley_full_pass,
		" paisley_full_peak_span=", paisley_full_peak_span,
		" paisley_diffuse_pass=", paisley_diffuse_pass,
		" paisley_diffuse_peak_share=", paisley_diffuse_peak_share,
		" paisley_diffuse_peak_fail_span=", paisley_diffuse_peak_fail_span,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not full_pass or not full_peak_span or not full_targets_span or not full_sync_span:
		printerr("WomboComboGoalProbe: FAIL full Wombo telemetry did not pass all goal spans")
		failed = true
	if full_peak_share < 0.99 or full_targets < 2 or full_cc_events < 1:
		printerr("WomboComboGoalProbe: FAIL full Wombo kernel telemetry did not record peak, target, and CC evidence")
		failed = true
	if not no_cc_pass or not no_cc_sync_fail_span:
		printerr("WomboComboGoalProbe: FAIL no-CC aggregate path did not preserve a failed CC-sync span")
		failed = true
	if not paisley_full_pass or not paisley_full_peak_span:
		printerr("WomboComboGoalProbe: FAIL Paisley full case did not prove direct peak-share support")
		failed = true
	if not paisley_diffuse_pass or not paisley_diffuse_peak_fail_span or paisley_diffuse_peak_share >= 0.25:
		printerr("WomboComboGoalProbe: FAIL Paisley diffuse aggregate path did not preserve a failed peak-share span")
		failed = true
	if weak_pass or weak_peak_span or weak_targets_span or weak_sync_span:
		printerr("WomboComboGoalProbe: FAIL weak control passed or emitted a passing Wombo span")
		failed = true

	if failed:
		_quit(1)
		return
	print("WomboComboGoalProbe: PASS")
	_quit(0)

func _run_case(case_id: String, subject_id: String, groups: Array[Dictionary], include_cc: bool) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(subject_id)
	engine.state = state
	var combat_kernel: Variant = CombatPatternKernel.new()
	var control_kernel: Variant = ControlMobilityKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 2}
	var context_tags: Dictionary = _context_tags(subject_id)
	combat_kernel.call("attach", engine, team_sizes, context_tags, true)
	control_kernel.call("attach", engine, team_sizes, context_tags, true)
	engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2.ZERO)
	if include_cc:
		control_kernel.call("tick", 0.1)
		combat_kernel.call("tick", 0.1)
		engine.emit_signal("cc_applied", "player", 0, "enemy", 0, "stun", 1.0)
	for group in groups:
		var delta_s: float = float(group.get("delta_s", 0.0))
		control_kernel.call("tick", delta_s)
		combat_kernel.call("tick", delta_s)
		var hits: Array = group.get("hits", [])
		for hit in hits:
			if not (hit is Dictionary):
				continue
			var hit_rec: Dictionary = hit
			var target_index: int = int(hit_rec.get("target_index", 0))
			var damage: int = int(hit_rec.get("damage", 0))
			engine.emit_signal("hit_applied", "player", 0, target_index, damage, damage, false, 1000, 1000 - damage, 0.0, 0.0)
	var total_time_s: float = _total_time(groups) + (0.1 if include_cc else 0.0)
	combat_kernel.call("finalize", total_time_s)
	control_kernel.call("finalize", total_time_s)

	var combat_result: Dictionary = combat_kernel.call("result")
	var control_result: Dictionary = control_kernel.call("result")
	var kernel_result: Dictionary = _combined_kernels(combat_result, control_result)
	var combat_patterns: Dictionary = combat_result.get("combat_patterns", {}) if (combat_result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(subject_id, {}) if (side_a is Dictionary) else {}
	var control_patterns: Dictionary = control_result.get("control_mobility", {}) if (control_result is Dictionary) else {}
	var control_per_unit: Dictionary = control_patterns.get("per_unit", {}) if (control_patterns is Dictionary) else {}
	var control_side_a: Dictionary = control_per_unit.get("a", {}) if (control_per_unit is Dictionary) else {}
	var control_rec: Dictionary = control_side_a.get(subject_id, {}) if (control_side_a is Dictionary) else {}
	var subject_damage: float = float(rec.get("total_damage", 0.0))
	var goal_result: Dictionary = _run_goal(case_id, subject_id, kernel_result, subject_damage, total_time_s)
	combat_kernel.call("detach")
	control_kernel.call("detach")
	return {
		"rec": rec,
		"control": control_rec,
		"goal": goal_result
	}

func _full_burst_groups() -> Array[Dictionary]:
	return [
		{
			"delta_s": 0.2,
			"hits": [
				{"target_index": 0, "damage": 80},
				{"target_index": 1, "damage": 40}
			]
		}
	]

func _diffuse_multitarget_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for i in range(5):
		groups.append({
			"delta_s": 0.2 if i == 0 else 1.2,
			"hits": [
				{"target_index": 0, "damage": 20},
				{"target_index": 1, "damage": 20}
			]
		})
	return groups

func _weak_single_target_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for i in range(5):
		groups.append({
			"delta_s": 0.2 if i == 0 else 1.2,
			"hits": [
				{"target_index": 0, "damage": 12}
			]
		})
	return groups

func _make_state(subject_id: String) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var subject: Unit = Unit.new()
	subject.id = subject_id
	subject.max_hp = 1000
	subject.hp = 1000
	var target_a: Unit = Unit.new()
	target_a.id = TARGET_A_ID
	target_a.max_hp = 1000
	target_a.hp = 1000
	var target_b: Unit = Unit.new()
	target_b.id = TARGET_B_ID
	target_b.max_hp = 1000
	target_b.hp = 1000
	var player_team: Array[Unit] = [subject]
	var enemy_team: Array[Unit] = [target_a, target_b]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _context_tags(subject_id: String) -> Dictionary:
	return {
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
					"unit_id": TARGET_A_ID
				},
				{
					"unit_index": 1,
					"unit_id": TARGET_B_ID
				}
			]
		}
	}

func _combined_kernels(combat_result: Dictionary, control_result: Dictionary) -> Dictionary:
	var combined: Dictionary = {}
	for key in combat_result.keys():
		combined[key] = combat_result.get(key)
	for key in control_result.keys():
		combined[key] = control_result.get(key)
	return combined

func _total_time(groups: Array[Dictionary]) -> float:
	var total: float = 0.0
	for group in groups:
		total += float(group.get("delta_s", 0.0))
	return total

func _run_goal(case_id: String, subject_id: String, kernel_result: Dictionary, subject_damage: float, total_time_s: float) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "burst",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [subject_id],
						"team_b_ids": [TARGET_A_ID, TARGET_B_ID]
					},
					"teams": {
						"a": {
							"damage": subject_damage
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": subject_id,
								"damage": subject_damage,
								"incoming": 0.0,
								"time_alive_s": total_time_s
							}
						],
						"b": [
							{
								"unit_id": TARGET_A_ID,
								"damage": 0.0
							},
							{
								"unit_id": TARGET_B_ID,
								"damage": 0.0
							}
						]
					},
					"outcome": {
						"time_s": total_time_s
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
