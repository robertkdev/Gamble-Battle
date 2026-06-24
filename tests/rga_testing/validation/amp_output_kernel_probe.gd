extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const BuffPresenceKernel := preload("res://tests/rga_testing/aggregators/kernels/buff_presence_kernel.gd")
const AmpApproachTest := preload("res://tests/rga_testing/metrics/approach/amp_approach_test.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.configure(state, state.player_team[0], 1)
	engine.start()
	engine.attack_resolver.emit_auto_attack_logs = false

	var kernel: Variant = BuffPresenceKernel.new()
	var team_sizes: Dictionary = {"a": 2, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "axiom"
				},
				{
					"unit_index": 1,
					"unit_id": "nyxa"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "brute"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	var hit_response: Dictionary = _apply_real_amp_hit(engine, state)
	kernel.call("finalize", 0.25)

	var result: Dictionary = kernel.call("result")
	var buff_presence: Dictionary = result.get("buff_presence", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = buff_presence.get("per_unit", {}) if (buff_presence is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("axiom", {}) if (side_a is Dictionary) else {}
	var approach_result: Dictionary = _run_approach_result(result)
	var goal_result: Dictionary = _run_goal_result(result)

	var supported: bool = bool(buff_presence.get("supported", false))
	var ally_buffs: int = int(rec.get("ally_buffs_to_others", 0))
	var output_events: int = int(rec.get("amp_output_events", 0))
	var output_delta: float = float(rec.get("amp_output_delta", 0.0))
	var beneficiaries: int = int(rec.get("amp_output_beneficiaries", 0))
	var hit_processed: bool = bool(hit_response.get("processed", false))
	var approach_pass: bool = bool(approach_result.get("pass", false))
	var approach_direct_span: bool = _has_span_prefix(approach_result, "subject_amp_output_delta")
	var goal_pass: bool = bool(goal_result.get("pass", false))
	var goal_direct_span: bool = _has_span_prefix(goal_result, "goal_team_amplification_amp_output_delta")

	print("AmpOutputKernelProbe: supported=", supported,
		" ally_buffs=", ally_buffs,
		" output_events=", output_events,
		" output_delta=", output_delta,
		" beneficiaries=", beneficiaries,
		" hit_processed=", hit_processed,
		" approach_pass=", approach_pass,
		" goal_pass=", goal_pass)

	var failed: bool = false
	if not supported:
		printerr("AmpOutputKernelProbe: FAIL buff_presence signal support was not connected")
		failed = true
	if ally_buffs != 1:
		printerr("AmpOutputKernelProbe: FAIL ally buff source count was not recorded")
		failed = true
	if not hit_processed:
		printerr("AmpOutputKernelProbe: FAIL real buffed projectile hit was not processed")
		failed = true
	if output_events != 1 or output_delta <= 0.0:
		printerr("AmpOutputKernelProbe: FAIL real amp output event/delta was not recorded")
		failed = true
	if beneficiaries != 1:
		printerr("AmpOutputKernelProbe: FAIL amp output beneficiary was not recorded")
		failed = true
	if not approach_pass or not approach_direct_span:
		printerr("AmpOutputKernelProbe: FAIL approach_amp did not pass on direct output telemetry")
		failed = true
	if not goal_pass or not goal_direct_span:
		printerr("AmpOutputKernelProbe: FAIL goal_primary did not expose direct team-amplification output telemetry")
		failed = true

	kernel.call("detach")
	engine.stop()
	engine.teardown()
	if failed:
		_quit(1)
		return
	print("AmpOutputKernelProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var support: Unit = Unit.new()
	support.id = "axiom"
	support.max_hp = 1000
	support.hp = 1000
	var carry: Unit = Unit.new()
	carry.id = "nyxa"
	carry.max_hp = 1000
	carry.hp = 1000
	carry.attack_damage = 100.0
	var target: Unit = Unit.new()
	target.id = "brute"
	target.max_hp = 1000
	target.hp = 1000
	target.armor = 0.0
	var player_team: Array[Unit] = [support, carry]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _apply_real_amp_hit(engine: CombatEngine, state: BattleState) -> Dictionary:
	if engine.buff_system == null:
		return {"processed": false}
	engine.buff_system.push_source("player", 0, "ability")
	var buff_result: Dictionary = engine.buff_system.apply_tag(state, "player", 1, BuffTags.TAG_DAMAGE_AMP, 5.0, {"damage_amp_pct": 0.25})
	engine.buff_system.pop_source()
	if not bool(buff_result.get("processed", false)):
		return {"processed": false}
	return engine.attack_resolver.apply_projectile_hit("player", 1, 0, 100, false, false)

func _run_approach_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = AmpApproachTest.new()
	var payload: Dictionary = _metric_payload(kernel_result)
	return metric.call("run_metric", payload)

func _run_goal_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	var payload: Dictionary = _metric_payload(kernel_result)
	return metric.call("run_metric", payload)

func _metric_payload(kernel_result: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["axiom", "nyxa"],
						"team_b_ids": ["brute"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["axiom"]
	}

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
