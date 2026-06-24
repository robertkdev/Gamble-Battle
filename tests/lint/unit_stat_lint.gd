extends Node

const UnitDefaults := preload("res://scripts/game/units/unit_defaults.gd")

func _ready() -> void:
	var issues: Array[String] = scan()
	if issues.is_empty():
		print("UnitStatLint: OK")
	else:
		for issue in issues:
			push_error(issue)
	get_tree().quit(0 if issues.is_empty() else 1)

func scan() -> Array[String]:
	var issues: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/units")
	if dir == null:
		issues.append("UnitStatLint: unable to open res://data/units")
		return issues
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			continue
		if not entry.ends_with(".tres"):
			continue
		var resource_path: String = "res://data/units/%s" % entry
		var text: String = FileAccess.get_file_as_string(resource_path)
		if text == "":
			continue
		var padded: String = "\n" + text
		for key in UnitDefaults.banned_keys():
			var pattern_a: String = "\n%s =" % key
			var pattern_b: String = "\n%s=" % key
			if padded.find(pattern_a) != -1 or padded.find(pattern_b) != -1:
				issues.append("%s contains banned stat key '%s'" % [resource_path, key])
				break
	dir.list_dir_end()
	return issues
