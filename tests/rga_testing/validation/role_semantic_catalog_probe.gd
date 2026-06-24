extends Node

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const ROLE_IDS: Array[String] = [
	"tank",
	"brawler",
	"assassin",
	"marksman",
	"mage",
	"support"
]

const ROLE_METRIC_PATHS: Dictionary = {
	"tank": "res://tests/rga_testing/metrics/tank/tank_role_identity_test.gd",
	"brawler": "res://tests/rga_testing/metrics/brawler/brawler_role_identity_test.gd",
	"assassin": "res://tests/rga_testing/metrics/assassin/assassin_role_identity_test.gd",
	"marksman": "res://tests/rga_testing/metrics/marksman/marksman_role_identity_test.gd",
	"mage": "res://tests/rga_testing/metrics/mage/mage_role_identity_test.gd",
	"support": "res://tests/rga_testing/metrics/support/support_role_identity_test.gd"
}

const EXPECTED_SPAN_PREFIXES: Dictionary = {
	"tank": "unit_pass",
	"brawler": "unit_pass",
	"assassin": "subject_first_backline_frac",
	"marksman": "subject_sustained_",
	"mage": "magic_",
	"support": "subject_support_"
}

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var failed: bool = false
	for role_id in ROLE_IDS:
		var subject_id: String = _subject_id(role_id)
		_install_probe_identity(subject_id, role_id)
		var positive_result: Dictionary = _run_role(role_id, _positive_payload(role_id, subject_id))
		var negative_result: Dictionary = _run_role(role_id, _negative_payload(role_id, subject_id))
		var positive_pass: bool = bool(positive_result.get("pass", false))
		var negative_pass: bool = bool(negative_result.get("pass", false))
		var span_ok: bool = _has_span_prefix(positive_result, String(EXPECTED_SPAN_PREFIXES.get(role_id, "")))
		print("RoleSemanticCatalogProbe: role=", role_id,
			" positive=", positive_pass,
			" negative=", negative_pass,
			" span=", span_ok)
		if not positive_pass:
			printerr("RoleSemanticCatalogProbe: FAIL positive payload did not pass for ", role_id, " message=", String(positive_result.get("message", "")))
			failed = true
		if negative_pass:
			printerr("RoleSemanticCatalogProbe: FAIL negative control passed for ", role_id, " message=", String(negative_result.get("message", "")))
			failed = true
		if not span_ok:
			printerr("RoleSemanticCatalogProbe: FAIL expected role span prefix missing for ", role_id)
			failed = true
	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("RoleSemanticCatalogProbe: PASS roles=", ROLE_IDS.size())
	_quit(0)

func _install_probe_identity(subject_id: String, role_id: String) -> void:
	RoleCommon._identity_cache[subject_id] = {
		"unit_id": subject_id,
		"primary_role": role_id,
		"primary_goal": "",
		"approaches": [],
		"cost": 3,
		"level": 1
	}

func _run_role(role_id: String, payload: Dictionary) -> Dictionary:
	var metric_path: String = String(ROLE_METRIC_PATHS.get(role_id, ""))
	var metric_script: Script = load(metric_path) as Script
	if metric_script == null:
		return RoleCommon.fail_result([], ["missing_metric_script:%s" % metric_path])
	var metric: Variant = metric_script.new()
	var result: Dictionary = metric.call("run_metric", payload)
	metric = null
	metric_script = null
	return result

func _positive_payload(role_id: String, subject_id: String) -> Dictionary:
	var subject_fields: Dictionary = _subject_fields({"time_alive_s": 10.0})
	var kernels: Dictionary = {}
	var derived: Dictionary = {}
	var team_a_damage: float = 100.0
	var team_b_damage: float = 0.0
	var extra_allies: Array[Dictionary] = []
	var extra_enemies: Array[Dictionary] = []

	match role_id:
		"tank":
			subject_fields = _subject_fields({
				"incoming": 100.0,
				"mitigated": 60.0,
				"shield": 10.0,
				"time_alive_s": 12.0
			})
			team_b_damage = 100.0
		"brawler":
			subject_fields = _subject_fields({
				"damage": 90.0,
				"incoming": 90.0,
				"mitigated": 25.0,
				"time_alive_s": 12.0
			})
			extra_allies = [_unit("probe_brawler_ally", 20.0, 20.0, 10.0)]
			extra_enemies = [
				_unit("probe_enemy_0", 12.0, 0.0, 10.0),
				_unit("probe_enemy_1", 14.0, 0.0, 10.0)
			]
			team_a_damage = 110.0
			team_b_damage = 26.0
			_add_throughput_kernel(kernels, 40.0, 10.0, 12.0, 14.0)
		"assassin":
			subject_fields = _subject_fields({
				"first_cast_s": 0.8,
				"time_alive_s": 10.0
			})
			_add_backline_kernel(kernels, subject_id, 1.2, 8.0)
		"marksman":
			subject_fields = _subject_fields({
				"damage": 80.0,
				"time_alive_s": 10.0
			})
			extra_allies = [_unit("probe_marksman_ally", 20.0, 0.0, 10.0)]
			extra_enemies = [
				_unit("probe_enemy_0", 12.0, 0.0, 10.0),
				_unit("probe_enemy_1", 14.0, 0.0, 10.0)
			]
			team_a_damage = 100.0
			_add_throughput_kernel(kernels, 40.0, 10.0, 12.0, 14.0)
			_add_flat_side_kernel(kernels, "per_unit_kpis", subject_id, {
				"attacks_over_2_tiles_pct": 0.80,
				"time_on_target_pct": 0.80,
				"attack_distance_median_tiles": 3.0
			})
		"mage":
			_add_periodicity_kernel(kernels, 0.50, 2.0, 0.0, 1.0)
		"support":
			subject_fields = _subject_fields({
				"incoming": 100.0,
				"time_alive_s": 10.0
			})
			team_b_damage = 100.0
			_add_support_kernel(kernels, subject_id, 30.0, 20.0)
			_add_buff_presence_kernel(kernels, subject_id, 1.0, {
				"ally_buffs_to_others": 1,
				"ally_buff_magnitude_to_others": 30.0,
				"cc_immunity": 1,
				"cleanse_applied": 1
			})
		_:
			pass

	return _base_payload(subject_id, subject_fields, kernels, derived, team_a_damage, team_b_damage, extra_allies, extra_enemies)

func _negative_payload(role_id: String, subject_id: String) -> Dictionary:
	var subject_fields: Dictionary = _subject_fields({
		"incoming": 100.0,
		"pre_mit_incoming": 100.0,
		"post_mit_incoming": 100.0,
		"time_alive_s": 0.0
	})
	var kernels: Dictionary = {}
	var extra_allies: Array[Dictionary] = []
	var extra_enemies: Array[Dictionary] = []

	match role_id:
		"brawler", "marksman":
			extra_allies = [_unit("probe_low_ally", 50.0, 0.0, 10.0)]
			extra_enemies = [
				_unit("probe_enemy_0", 50.0, 0.0, 10.0),
				_unit("probe_enemy_1", 50.0, 0.0, 10.0)
			]
			_add_throughput_kernel(kernels, 5.0, 20.0, 22.0, 24.0)
			if role_id == "marksman":
				_add_flat_side_kernel(kernels, "per_unit_kpis", subject_id, {
					"attacks_over_2_tiles_pct": 0.05,
					"time_on_target_pct": 0.05,
					"attack_distance_median_tiles": 1.0
				})
		"assassin":
			subject_fields["first_cast_s"] = 0.8
			_add_backline_kernel(kernels, subject_id, 9.0, 1.0)
		"mage":
			_add_periodicity_kernel(kernels, 0.0, 1.0, 0.0, 1.0)
		"support":
			_add_buff_presence_kernel(kernels, subject_id, 0.0, {})
		_:
			pass

	return _base_payload(subject_id, subject_fields, kernels, {}, 100.0, 100.0, extra_allies, extra_enemies)

func _base_payload(subject_id: String, subject_fields: Dictionary, kernels: Dictionary, derived: Dictionary, team_a_damage: float, team_b_damage: float, extra_allies: Array[Dictionary], extra_enemies: Array[Dictionary]) -> Dictionary:
	var subject_unit: Dictionary = _subject_fields(subject_fields)
	subject_unit["unit_id"] = subject_id
	var team_a_ids: Array[String] = [subject_id]
	var team_a_units: Array[Dictionary] = [subject_unit]
	for ally in extra_allies:
		team_a_units.append(ally)
		team_a_ids.append(String(ally.get("unit_id", "")))
	var team_b_ids: Array[String] = []
	var team_b_units: Array[Dictionary] = []
	if extra_enemies.is_empty():
		var default_enemy: Dictionary = _unit("probe_enemy", team_b_damage, 0.0, 10.0)
		team_b_units.append(default_enemy)
		team_b_ids.append("probe_enemy")
	else:
		for enemy in extra_enemies:
			team_b_units.append(enemy)
			team_b_ids.append(String(enemy.get("unit_id", "")))
	var sim: Dictionary = {
		"context": {
			"team_a_ids": team_a_ids,
			"team_b_ids": team_b_ids
		},
		"teams": {
			"a": {
				"damage": team_a_damage,
				"healing": 0.0,
				"shield": 0.0
			},
			"b": {
				"damage": team_b_damage,
				"healing": 0.0,
				"shield": 0.0
			}
		},
		"units": {
			"a": team_a_units,
			"b": team_b_units
		},
		"outcome": {
			"time_s": 10.0,
			"winner_side": "a"
		},
		"kernels": kernels
	}
	if not derived.is_empty():
		sim["derived"] = derived
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": sim
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _subject_fields(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"damage": 0.0,
		"incoming": 0.0,
		"mitigated": 0.0,
		"pre_mit_incoming": 0.0,
		"post_mit_incoming": 0.0,
		"healing": 0.0,
		"shield": 0.0,
		"time_alive_s": 0.0
	}
	for key in overrides.keys():
		out[key] = overrides.get(key)
	return out

func _unit(unit_id: String, damage: float, incoming: float, time_alive_s: float) -> Dictionary:
	return {
		"unit_id": unit_id,
		"damage": damage,
		"incoming": incoming,
		"mitigated": 0.0,
		"shield": 0.0,
		"time_alive_s": time_alive_s
	}

func _add_throughput_kernel(kernels: Dictionary, subject_rate: float, ally_rate: float, enemy_rate_a: float, enemy_rate_b: float) -> void:
	kernels["throughput"] = {
		"peers": {
			"all": [subject_rate, ally_rate, enemy_rate_a, enemy_rate_b],
			"a": [subject_rate, ally_rate],
			"b": [enemy_rate_a, enemy_rate_b]
		},
		"peers_by_index": {
			"a": {
				"0": subject_rate,
				"1": ally_rate
			},
			"b": {
				"0": enemy_rate_a,
				"1": enemy_rate_b
			}
		}
	}

func _add_flat_side_kernel(kernels: Dictionary, kernel_key: String, subject_id: String, rec: Dictionary) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = rec
	kernels[kernel_key] = {
		"a": side_map,
		"b": {}
	}

func _add_backline_kernel(kernels: Dictionary, subject_id: String, subject_contact_s: float, enemy_contact_s: float) -> void:
	kernels["backline_access"] = {
		"supported": true,
		"a": {
			"first_backline_contact_s": subject_contact_s,
			"entered_by_unit": {
				subject_id: subject_contact_s
			}
		},
		"b": {
			"first_backline_contact_s": enemy_contact_s
		}
	}

func _add_periodicity_kernel(kernels: Dictionary, subject_share: float, subject_peak: float, enemy_share: float, enemy_peak: float) -> void:
	kernels["periodicity"] = {
		"a": {
			"top_2s_magic_damage_share": subject_share,
			"magic_peak_over_mean": subject_peak
		},
		"b": {
			"top_2s_magic_damage_share": enemy_share,
			"magic_peak_over_mean": enemy_peak
		}
	}

func _add_support_kernel(kernels: Dictionary, subject_id: String, healed: float, absorbed: float) -> void:
	var heal_side: Dictionary = {}
	var shield_side: Dictionary = {}
	heal_side[subject_id] = {
		"healed": healed,
		"overheal": 0.0
	}
	shield_side[subject_id] = {
		"absorbed": absorbed
	}
	kernels["support"] = {
		"healing_per_unit": {
			"a": heal_side,
			"b": {}
		},
		"shield_absorbed_per_unit": {
			"a": shield_side,
			"b": {}
		}
	}

func _add_buff_presence_kernel(kernels: Dictionary, subject_id: String, events_per_ally: float, rec: Dictionary) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = rec
	kernels["buff_presence"] = {
		"supported": true,
		"a": {
			"events_per_ally": events_per_ally
		},
		"b": {
			"events_per_ally": 0.0
		},
		"per_unit": {
			"a": side_map,
			"b": {}
		}
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

func _subject_id(role_id: String) -> String:
	return "probe_role_%s" % role_id

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
