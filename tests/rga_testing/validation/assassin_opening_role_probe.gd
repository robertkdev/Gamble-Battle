extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BacklineAccessKernel := preload("res://tests/rga_testing/aggregators/kernels/backline_access_kernel.gd")
const AssassinRoleTest := preload("res://tests/rga_testing/metrics/assassin/assassin_role_identity_test.gd")

const SUBJECT_ID: String = "hexeon"
const ENEMY_ID: String = "probe_enemy_assassin"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var opening_result: Dictionary = _run_case("opening_access", 1.2, 8.0, 0.8)
	var late_result: Dictionary = _run_case("late_access", 4.5, 1.0, 0.8)
	var opening_role: Dictionary = opening_result.get("role", {})
	var late_role: Dictionary = late_result.get("role", {})
	var opening_access: Dictionary = opening_result.get("access", {})
	var opening_side_span: Dictionary = _find_span(opening_role, "a_first_frac")
	var opening_subject_span: Dictionary = _find_span(opening_role, "subject_first_backline_frac")
	var late_side_span: Dictionary = _find_span(late_role, "a_first_frac")
	var late_subject_span: Dictionary = _find_span(late_role, "subject_first_backline_frac")
	var opening_pass: bool = bool(opening_role.get("pass", false))
	var late_pass: bool = bool(late_role.get("pass", false))
	var opening_contact_s: float = float(opening_access.get("first_backline_contact_s", -1.0))
	var opening_unit_id: String = String(opening_access.get("first_backline_unit_id", ""))
	var opening_side_ok: bool = bool(opening_side_span.get("ok", false))
	var opening_subject_ok: bool = bool(opening_subject_span.get("ok", false))
	var late_side_ok: bool = bool(late_side_span.get("ok", false))
	var late_subject_ok: bool = bool(late_subject_span.get("ok", false))
	var late_subject_contact_s: float = float(late_subject_span.get("subject_first_backline_contact_s", -1.0))

	print("AssassinOpeningRoleProbe: opening_pass=", opening_pass,
		" opening_contact_s=", opening_contact_s,
		" opening_unit_id=", opening_unit_id,
		" opening_side_ok=", opening_side_ok,
		" opening_subject_ok=", opening_subject_ok,
		" late_pass=", late_pass,
		" late_subject_contact_s=", late_subject_contact_s,
		" late_side_ok=", late_side_ok,
		" late_subject_ok=", late_subject_ok)

	var failed: bool = false
	if not opening_pass:
		printerr("AssassinOpeningRoleProbe: FAIL early backline-access telemetry did not pass Hexeon's assassin role")
		failed = true
	if opening_contact_s < 1.19 or opening_contact_s > 1.21 or opening_unit_id != SUBJECT_ID:
		printerr("AssassinOpeningRoleProbe: FAIL BacklineAccessKernel did not record Hexeon's first contact")
		failed = true
	if not opening_side_ok or not opening_subject_ok:
		printerr("AssassinOpeningRoleProbe: FAIL assassin role spans did not pass on early opening access")
		failed = true
	if late_pass or late_side_ok or late_subject_ok:
		printerr("AssassinOpeningRoleProbe: FAIL late/access-losing control passed")
		failed = true
	if late_subject_contact_s < 4.49 or late_subject_contact_s > 4.51:
		printerr("AssassinOpeningRoleProbe: FAIL late control did not preserve the delayed contact evidence")
		failed = true

	if failed:
		_quit(1)
		return
	print("AssassinOpeningRoleProbe: PASS")
	_quit(0)

func _run_case(case_id: String, subject_contact_s: float, enemy_contact_s: float, first_cast_s: float) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = BacklineAccessKernel.new()
	kernel.call("attach", engine, _context_tags(), true)
	var current_time_s: float = 0.0
	if subject_contact_s <= enemy_contact_s:
		current_time_s = _advance_to(kernel, current_time_s, subject_contact_s)
		engine.emit_signal("position_updated", "player", 0, 3.0, 0.0)
		current_time_s = _advance_to(kernel, current_time_s, enemy_contact_s)
		engine.emit_signal("position_updated", "enemy", 0, -3.0, 0.0)
	else:
		current_time_s = _advance_to(kernel, current_time_s, enemy_contact_s)
		engine.emit_signal("position_updated", "enemy", 0, -3.0, 0.0)
		current_time_s = _advance_to(kernel, current_time_s, subject_contact_s)
		engine.emit_signal("position_updated", "player", 0, 3.0, 0.0)
	kernel.call("finalize", max(subject_contact_s, enemy_contact_s))
	var kernel_result: Dictionary = kernel.call("result")
	var access_block: Dictionary = kernel_result.get("backline_access", {}) if (kernel_result is Dictionary) else {}
	var side_a_access: Dictionary = access_block.get("a", {}) if (access_block is Dictionary) else {}
	var role_result: Dictionary = _run_role(case_id, kernel_result, first_cast_s)
	kernel.call("detach")
	return {
		"access": side_a_access,
		"role": role_result
	}

func _advance_to(kernel: Variant, current_time_s: float, target_time_s: float) -> float:
	var delta_s: float = max(0.0, target_time_s - current_time_s)
	kernel.call("tick", delta_s)
	return current_time_s + delta_s

func _context_tags() -> Dictionary:
	return {
		"zones": {
			"a": {
				"backline": {
					"center": {
						"x": -3.0,
						"y": 0.0
					},
					"half_length": 0.5,
					"half_width": 2.0
				}
			},
			"b": {
				"backline": {
					"center": {
						"x": 3.0,
						"y": 0.0
					},
					"half_length": 0.5,
					"half_width": 2.0
				}
			}
		},
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": ENEMY_ID
				}
			]
		}
	}

func _run_role(case_id: String, kernel_result: Dictionary, first_cast_s: float) -> Dictionary:
	var metric: Variant = AssassinRoleTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 100.0
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"first_cast_s": first_cast_s,
								"damage": 100.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": 0.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						]
					},
					"outcome": {
						"time_s": 10.0,
						"winner_side": "a"
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}
	return metric.call("run_metric", payload)

func _find_span(metric_result: Dictionary, label_prefix: String) -> Dictionary:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return span
	return {}

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
