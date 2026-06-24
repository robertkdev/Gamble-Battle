extends Resource
class_name ProfileSettings

# Exported knobs used by the RGATesting main scene.
@export_enum("designer_quick", "ci_full", "rga_roles_base", "rga_roles_derived", "none") var profile: String = "designer_quick"
@export_file("*.json", "*.tres") var base_config_path: String = ""
@export var ids_csv: String = ""
@export var repeats_override: int = -1
@export var timeout_override: float = -1.0
@export var abilities_override: bool = false
@export var ability_metrics_override: bool = false
@export var override_flags: bool = false

# Roles test wiring (optional):
# - When set, the main scene will forward this as scenario intents to the pipeline.
# - After the pipeline, it can also run role_* metrics (e.g., the Tank identity test).
@export_file("*.json", "*.ndjson") var scenario_intents_path: String = ""
@export var run_roles_metrics: bool = false
# Comma-separated list of metric IDs to run after the pipeline. If empty, runs all role_* metrics.
@export var role_metric_ids: String = ""

func to_cli_dict() -> Dictionary:
	var d := {}
	if String(base_config_path).strip_edges() != "":
		d["config"] = base_config_path
	if ids_csv.strip_edges() != "":
		d["ids"] = ids_csv
	if repeats_override >= 0:
		d["repeats"] = str(repeats_override)
	if timeout_override >= 0.0:
		d["timeout"] = str(timeout_override)
	if override_flags:
		d["abilities"] = str(abilities_override)
		d["ability_metrics"] = str(ability_metrics_override)
	if scenario_intents_path.strip_edges() != "":
		d["intents"] = scenario_intents_path
	return d

# Inspector help: add read-only helper strings so hovering shows meaningful text
# (Godot does not support per-property tooltips via annotations).
const _HELP := {
	"profile": "Pick a ready-made setup. 'designer_quick' is short, 'ci_full' is big. 'none' uses only the other boxes.",
	"base_config_path": "Optional file to read first (JSON or TRES). Think of it like stacking settings blocks.",
	"ids_csv": "Only test these pairs: write like a:b,c:d (left fights right). Leave empty to test everything.",
	"repeats_override": "How many times to repeat each fight. Leave -1 to keep the normal number.",
	"timeout_override": "How long each fight can last (seconds). Leave -1 to keep the normal time.",
	"abilities_override": "If 'override flags' is ON: allow fighters to use their special moves.",
	"ability_metrics_override": "If 'override flags' is ON: also record extra stats about those moves.",
	"override_flags": "Turn this ON to make the two ability switches above matter. OFF keeps the profile defaults.",
	"scenario_intents_path": "Optional: path to a Roles intents JSON (e.g., tank_neutral.json). If set, pipeline will use it.",
	"run_roles_metrics": "If ON, run role_* metrics (like Tank identity) after the pipeline and print PASS/FAIL.",
	"role_metric_ids": "Optional: comma-separated metric IDs to run (e.g., role_tank_identity). Leave empty to run all role_* metrics."
}

var _help_values := {
	"profile_help": _HELP.profile,
	"base_config_path_help": _HELP.base_config_path,
	"ids_csv_help": _HELP.ids_csv,
	"repeats_override_help": _HELP.repeats_override,
	"timeout_override_help": _HELP.timeout_override,
	"abilities_override_help": _HELP.abilities_override,
	"ability_metrics_override_help": _HELP.ability_metrics_override,
	"override_flags_help": _HELP.override_flags,
	"scenario_intents_path_help": _HELP.scenario_intents_path,
	"run_roles_metrics_help": _HELP.run_roles_metrics,
	"role_metric_ids_help": _HELP.role_metric_ids,
}

func _get(property: StringName):
	var n := String(property)
	if _help_values.has(n):
		return _help_values[n]
	# Dynamic, user-friendly dropdown mirrors
	if n == "scenario_intents_preset":
		return _current_intents_preset()
	if n == "role_metric_choice":
		return _current_role_metric_choice()
	return null

func _set(property: StringName, _value) -> bool:
	# Help entries are read-only.
	if _help_values.has(String(property)):
		return true
	var n := String(property)
	if n == "scenario_intents_preset":
		var label := String(_value)
		var path := _intents_path_from_label(label)
		scenario_intents_path = path
		return true
	if n == "role_metric_choice":
		var id := String(_value)
		# Selecting "All role_*" clears the filter; otherwise set single metric id
		if id == _all_roles_label():
			role_metric_ids = ""
		else:
			role_metric_ids = id
		return true
	return false

func _get_property_list() -> Array:
	var props: Array = []
	# Add a small "Help" category with friendly one-liners.
	props.append({
		"name": "Help",
		"usage": PROPERTY_USAGE_CATEGORY
	})
	for key in _help_values.keys():
		props.append({
			"name": String(key),
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
		})

	# Quick Presets category with dropdowns so users don't need to type
	props.append({
		"name": "Quick Presets",
		"usage": PROPERTY_USAGE_CATEGORY
	})
	props.append({
		"name": "scenario_intents_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(_intents_preset_labels()),
		"usage": PROPERTY_USAGE_EDITOR
	})
	props.append({
		"name": "role_metric_choice",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(_role_metric_choices()),
		"usage": PROPERTY_USAGE_EDITOR
	})
	return props

# --- Dropdown helpers ----------------------------------------------------

func _intents_dir() -> String:
	return "res://tests/rga_testing/config/intents/roles"

func _intents_preset_labels() -> Array[String]:
	var labels: Array[String] = ["None (leave empty)"]
	var p := _intents_dir()
	if DirAccess.dir_exists_absolute(p):
		var d := DirAccess.open(p)
		if d != null:
			d.list_dir_begin()
			while true:
				var name := d.get_next()
				if name == "": break
				if d.current_is_dir(): continue
				if name.ends_with(".json"):
					labels.append(name)
			d.list_dir_end()
	labels.sort()
	return labels

func _intents_path_from_label(label: String) -> String:
	var s := String(label)
	if s == "" or s.begins_with("None"):
		return ""
	return _intents_dir() + "/" + s

func _current_intents_preset() -> String:
	var p := String(scenario_intents_path).strip_edges()
	if p == "":
		return "None (leave empty)"
	return p.get_file()

func _role_metric_choices() -> Array[String]:
	var ids: Array[String] = []
	# Discover role_* metric ids by scanning tests/rga_testing/metrics
	var root := "res://tests/rga_testing/metrics"
	_introspect_role_metric_ids(root, ids)
	ids.sort()
	# Prepend an option to run all role metrics
	ids.insert(0, _all_roles_label())
	return ids

func _all_roles_label() -> String:
	return "All role_*"

func _introspect_role_metric_ids(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "": break
		var full := dir_path + "/" + name
		if d.current_is_dir():
			if not name.begins_with("."):
				_introspect_role_metric_ids(full, out)
		else:
			if name.ends_with("_test.gd"):
				var fa := FileAccess.open(full, FileAccess.READ)
				if fa != null:
					var txt := fa.get_as_text()
					fa.close()
					# Simple parse for METRIC_ID line to avoid Script instantiation in editor
					var idx := txt.find("METRIC_ID")
					if idx >= 0:
						# extract quoted id
						var q1 := txt.find("\"", idx)
						var q2 := txt.find("\"", q1 + 1)
						if q1 >= 0 and q2 > q1:
							var id := txt.substr(q1 + 1, q2 - q1 - 1)
							if id.begins_with("role_"):
								out.append(id)
	d.list_dir_end()

func _current_role_metric_choice() -> String:
	var s := String(role_metric_ids).strip_edges()
	if s == "":
		return _all_roles_label()
	# If multiple are set, show the first one.
	var parts := s.split(",", false)
	return String(parts[0])
