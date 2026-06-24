extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BuffPresenceKernel := preload("res://tests/rga_testing/aggregators/kernels/buff_presence_kernel.gd")
const CooldownPressureKernel := preload("res://tests/rga_testing/aggregators/kernels/cooldown_pressure_kernel.gd")
const CcImmunityApproachTest := preload("res://tests/rga_testing/metrics/approach/cc_immunity_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var buff_kernel: Variant = BuffPresenceKernel.new()
	var pressure_kernel: Variant = CooldownPressureKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 2}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "totem"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "repo"
				},
				{
					"unit_index": 1,
					"unit_id": "hexeon"
				}
			]
		}
	}
	buff_kernel.call("attach", engine, team_sizes, context_tags, true)
	pressure_kernel.call("attach", engine, team_sizes, context_tags, true)

	engine.emit_signal("buff_applied", "player", 0, "player", 0, "cc_immunity", {}, 1.0, 2.0)
	engine._resolver_emit_ability_committed("player", 0, "sentinel_vow", "player", 0, Vector2.ZERO, 0.5, "ability")
	engine._resolver_emit_ability_committed("enemy", 0, "writ_of_severance", "player", 0, Vector2.ZERO, 1.5, "ability")
	engine._resolver_emit_ability_committed("enemy", 1, "finisher_mark", "player", 0, Vector2.ZERO, 2.0, "execute")

	buff_kernel.call("finalize", 2.0)
	pressure_kernel.call("finalize", 2.0)

	var kernel_result: Dictionary = _merge_kernel_results(buff_kernel.call("result"), pressure_kernel.call("result"))
	var pressure: Dictionary = kernel_result.get("cooldown_pressure", {}) if (kernel_result is Dictionary) else {}
	var per_unit: Dictionary = pressure.get("per_unit", {}) if (pressure is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("totem", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(kernel_result)

	var supported: bool = bool(pressure.get("supported", false))
	var forced: int = int(rec.get("cooldowns_forced", 0))
	var forced_s: float = float(rec.get("cooldowns_forced_s", 0.0))
	var key_forced: int = int(rec.get("key_cooldowns_forced", 0))
	var threat_events: int = int(rec.get("cooldown_threat_draw_events", 0))
	var threat_casters: int = int(rec.get("cooldown_threat_draw_casters", 0))
	var threat_abilities: int = int(rec.get("cooldown_threat_draw_abilities", 0))
	var key_threat_share: float = float(rec.get("cooldown_key_threat_share", 0.0))
	var trade_efficiency: float = float(rec.get("cooldown_trade_efficiency", 0.0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var direct_span_present: bool = _has_span_label(metric_result, "subject_cc_immunity_counter_cooldown_trade_s")
	var efficiency_span_present: bool = _has_span_label(metric_result, "subject_cc_immunity_cooldown_trade_efficiency")
	var casters_span_present: bool = _has_span_label(metric_result, "subject_cc_immunity_threat_draw_casters")
	var key_share_span_present: bool = _has_span_label(metric_result, "subject_cc_immunity_key_threat_share")

	print("CooldownPressureKernelProbe: supported=", supported,
		" forced=", forced,
		" forced_s=", forced_s,
		" key_forced=", key_forced,
		" threat_events=", threat_events,
		" threat_casters=", threat_casters,
		" threat_abilities=", threat_abilities,
		" key_threat_share=", key_threat_share,
		" trade_efficiency=", trade_efficiency,
		" metric_pass=", metric_pass)

	var failed: bool = false
	if not supported:
		printerr("CooldownPressureKernelProbe: FAIL cooldown pressure signal was not connected")
		failed = true
	if forced != 2 or not is_equal_approx(forced_s, 3.5) or key_forced != 2:
		printerr("CooldownPressureKernelProbe: FAIL forced cooldown record was not captured")
		failed = true
	if threat_events != 2 or threat_casters != 2 or threat_abilities != 2:
		printerr("CooldownPressureKernelProbe: FAIL threat-draw diversity fields were not captured")
		failed = true
	if not is_equal_approx(key_threat_share, 1.0) or not is_equal_approx(trade_efficiency, 7.0):
		printerr("CooldownPressureKernelProbe: FAIL cooldown quality fields were not computed")
		failed = true
	if not metric_pass:
		printerr("CooldownPressureKernelProbe: FAIL approach_cc_immunity did not pass on direct counter-cooldown evidence")
		failed = true
	if not direct_span_present:
		printerr("CooldownPressureKernelProbe: FAIL metric did not emit direct counter-cooldown span")
		failed = true
	if not efficiency_span_present or not casters_span_present or not key_share_span_present:
		printerr("CooldownPressureKernelProbe: FAIL metric did not emit cooldown quality spans")
		failed = true

	buff_kernel.call("detach")
	pressure_kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("CooldownPressureKernelProbe: PASS")
	_quit(0)

func _merge_kernel_results(buff_result: Dictionary, pressure_result: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if buff_result is Dictionary:
		for key_value in buff_result.keys():
			out[String(key_value)] = buff_result.get(key_value)
	if pressure_result is Dictionary:
		for key_value in pressure_result.keys():
			out[String(key_value)] = pressure_result.get(key_value)
	return out

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = CcImmunityApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["totem"],
						"team_b_ids": ["repo", "hexeon"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["totem"]
	}
	return metric.call("run_metric", payload)

func _has_span_label(metric_result: Dictionary, expected_label: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var label: String = String((span_value as Dictionary).get("label", ""))
		if label == expected_label:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
