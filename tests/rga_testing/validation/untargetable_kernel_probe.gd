extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const TargetabilityKernel := preload("res://tests/rga_testing/aggregators/kernels/targetability_kernel.gd")
const UntargetableApproachTest := preload("res://tests/rga_testing/metrics/approach/untargetable_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = TargetabilityKernel.new()
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
	kernel.call("tick", 1.0)
	engine._resolver_emit_targetability_window("player", 0, false, 2.0, "blink_phase")
	engine._resolver_emit_targetability_threat_interaction("enemy", 0, "player", 0, "burst_ult", 5.5, true, true)
	engine._resolver_emit_targetability_threat_interaction("enemy", 0, "player", 0, "followup_cc", 4.0, true, false)
	kernel.call("finalize", 10.0)

	var result: Dictionary = kernel.call("result")
	var targetability: Dictionary = result.get("targetability", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = targetability.get("per_unit", {}) if (targetability is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("hexeon", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)

	var supported: bool = bool(targetability.get("supported", false))
	var window_supported: bool = bool(targetability.get("window_supported", false))
	var threat_supported: bool = bool(targetability.get("threat_interaction_supported", false))
	var windows: int = int(rec.get("untargetable_windows", 0))
	var time_s: float = float(rec.get("untargetable_time_s", 0.0))
	var frames_pct: float = float(rec.get("untargetable_frames_pct", 0.0))
	var key_faced: int = int(rec.get("key_threats_faced", 0))
	var key_dodged: int = int(rec.get("key_threats_dodged", 0))
	var key_rate: float = float(rec.get("key_threat_dodge_rate", 0.0))
	var cooldown_trade: float = float(rec.get("cooldown_trade_s", 0.0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_uses_proxy: bool = _has_span_prefix(metric_result, "subject_untargetable_incoming_share_proxy")

	print("UntargetableKernelProbe: supported=", supported,
		" window_supported=", window_supported,
		" threat_supported=", threat_supported,
		" windows=", windows,
		" time_s=", time_s,
		" frames_pct=", frames_pct,
		" key_faced=", key_faced,
		" key_dodged=", key_dodged,
		" key_rate=", key_rate,
		" cooldown_trade=", cooldown_trade,
		" metric_pass=", metric_pass)

	var failed: bool = false
	if not supported or not window_supported or not threat_supported:
		printerr("UntargetableKernelProbe: FAIL targetability signals were not connected")
		failed = true
	if windows != 1 or not is_equal_approx(time_s, 2.0):
		printerr("UntargetableKernelProbe: FAIL untargetable window duration was not recorded")
		failed = true
	if not is_equal_approx(frames_pct, 0.2):
		printerr("UntargetableKernelProbe: FAIL untargetable frame share was not recorded")
		failed = true
	if key_faced != 2 or key_dodged != 1 or not is_equal_approx(key_rate, 0.5):
		printerr("UntargetableKernelProbe: FAIL key threat dodge rate was not recorded")
		failed = true
	if not is_equal_approx(cooldown_trade, 5.5):
		printerr("UntargetableKernelProbe: FAIL cooldown trade was not recorded")
		failed = true
	if not metric_pass:
		printerr("UntargetableKernelProbe: FAIL approach_untargetable did not pass on direct targetability telemetry")
		failed = true
	if metric_uses_proxy:
		printerr("UntargetableKernelProbe: FAIL approach_untargetable used proxy spans when direct targetability telemetry was available")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("UntargetableKernelProbe: PASS")
	_quit(0)

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = UntargetableApproachTest.new()
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
