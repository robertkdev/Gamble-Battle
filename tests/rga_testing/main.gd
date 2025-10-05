extends Node
# RGA Testing - Main scene script
# Purpose: parse settings, run the headless pipeline, and exit.

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const ProfileSettings := preload("res://tests/rga_testing/config/profile_settings.gd")

@export var use_editor_params: bool = true
@export var profile_settings: ProfileSettings

var settings: RGASettings = RGASettings.new()

func _ready() -> void:
	# Defer to ensure OS args are available and scene is fully loaded
	call_deferred("_run")

func _run() -> void:
	# Use only user-provided args (after "--") so editor defaults apply when running via tools
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var extras: Dictionary
	var uses_editor_defaults := (args.size() == 0 and bool(use_editor_params))
	if uses_editor_defaults:
		extras = _build_editor_extras()
	else:
		extras = _parse_kv(args)

	var profile_name := String(extras.get("profile", "")).strip_edges().to_lower()
	var base_path := String(extras.get("config", "")).strip_edges()
	var cli_cfg := _cli_to_settings_dict(extras)
	var profile_path := _resolve_profile_path(profile_name)

	var merged := RGAConfigLoader.merge_all(
		RGAConfigLoader.load_config(base_path),
		RGAConfigLoader.load_config(profile_path),
		cli_cfg
	)
	settings.from_dict(merged)
	print("RGATesting: starting pipeline with settings:", settings.to_dict())

	var pipeline := HeadlessSimPipeline.new()
	var rows := pipeline.run_all(settings)
	print("RGATesting: completed. rows=", rows, " out=", settings.out_path)
	if get_tree():
		get_tree().quit()

func _build_editor_extras() -> Dictionary:
	var out := {}
	if profile_settings:
		if profile_settings.profile != "":
			out["profile"] = profile_settings.profile
		if profile_settings.base_config_path.strip_edges() != "":
			out["config"] = profile_settings.base_config_path
		var overrides := profile_settings.to_cli_dict()
		for k in overrides.keys():
			out[k] = overrides[k]
	return out

func _resolve_profile_path(name: String) -> String:
	var n := String(name).strip_edges().to_lower()
	if n == "" or n == "none":
		return ""
	if n.ends_with(".json") or n.ends_with(".tres") or n.find("//") >= 0 or n.find("/") >= 0 or n.find("\\") >= 0:
		return n
	match n:
		"designer_quick":
			return "res://tests/rga_testing/config/profiles/designer_quick.json"
		"ci_full":
			return "res://tests/rga_testing/config/profiles/ci_full.json"
		_:
			return ""

func _cli_to_settings_dict(kv: Dictionary) -> Dictionary:
	var d := {}
	for key in ["run_id", "sim_seed_start", "deterministic", "team_sizes", "repeats", "timeout", "abilities", "ability_metrics", "out", "aggregates_only", "include_swapped"]:
		if kv.has(key):
			d[_map_key(key)] = kv[key]
	if kv.has("role"):
		d["role_filter"] = kv["role"]
	if kv.has("goal"):
		d["goal_filter"] = kv["goal"]
	if kv.has("approach"):
		d["approach_filter"] = kv["approach"]
	if kv.has("cost"):
		d["cost_filter"] = kv["cost"]
	if kv.has("ids"):
		d["ids"] = kv["ids"]
	return d

func _map_key(k: String) -> String:
	match k:
		"timeout":
			return "timeout_s"
		"out":
			return "out_path"
		_:
			return k

func _parse_kv(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var seen_sep := false
	for a in argv:
		if a == "--":
			seen_sep = true
			continue
		var s := String(a)
		if (not seen_sep) and (not s.contains("=")):
			continue
		var parts := s.split("=", false, 2)
		if parts.size() == 2:
			out[parts[0].lstrip("-")] = parts[1]
	return out
