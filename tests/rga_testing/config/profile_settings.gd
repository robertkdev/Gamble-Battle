extends Resource
class_name ProfileSettings

# Exported knobs used by the RGATesting main scene.
@export_enum("designer_quick", "ci_full", "none") var profile: String = "designer_quick"
@export var base_config_path: String = ""
@export var ids_csv: String = ""
@export var repeats_override: int = -1
@export var timeout_override: float = -1.0
@export var abilities_override: bool = false
@export var ability_metrics_override: bool = false
@export var override_flags: bool = false

func to_cli_dict() -> Dictionary:
	var d := {}
	if ids_csv.strip_edges() != "":
		d["ids"] = ids_csv
	if repeats_override >= 0:
		d["repeats"] = str(repeats_override)
	if timeout_override >= 0.0:
		d["timeout"] = str(timeout_override)
	if override_flags:
		d["abilities"] = str(abilities_override)
		d["ability_metrics"] = str(ability_metrics_override)
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
	"override_flags": "Turn this ON to make the two ability switches above matter. OFF keeps the profile defaults."
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
}

func _get(property: StringName):
	var n := String(property)
	if _help_values.has(n):
		return _help_values[n]
	return null

func _set(property: StringName, _value) -> bool:
	# Help entries are read-only.
	if _help_values.has(String(property)):
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
	return props
