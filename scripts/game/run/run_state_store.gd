extends RefCounted
class_name RunStateStore

const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://active_run_v1.json"
const MAX_EXACT_JSON_INT: int = 9007199254740991
const INT64_PREFIX: String = "i64:"

static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)

static func save_snapshot(snapshot: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	var validation: Dictionary = _validate_snapshot(snapshot)
	if not bool(validation.get("ok", false)):
		return validation
	if String(snapshot.get("phase", "preview")).to_lower() == "combat":
		return {"ok": false, "error": "MIDCOMBAT_SAVE_REJECTED"}
	var payload: Dictionary = snapshot.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	payload["saved_unix_time"] = int(Time.get_unix_time_from_system())
	var encoded_payload: Variant = _encode_large_ints(payload)
	var json_text: String = JSON.stringify(encoded_payload, "\t")
	var temp_path: String = "%s.tmp" % path
	var backup_path: String = "%s.bak" % path
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "OPEN_FAILED", "path": path}
	file.store_string(json_text)
	file.flush()
	file.close()
	var global_temp: String = ProjectSettings.globalize_path(temp_path)
	var global_target: String = ProjectSettings.globalize_path(path)
	var global_backup: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(global_backup)
	if FileAccess.file_exists(path):
		var backup_error: Error = DirAccess.rename_absolute(global_target, global_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(global_temp)
			return {"ok": false, "error": "BACKUP_FAILED", "code": int(backup_error), "path": path}
	var rename_error: Error = DirAccess.rename_absolute(global_temp, global_target)
	if rename_error != OK:
		DirAccess.remove_absolute(global_temp)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(global_backup, global_target)
		return {"ok": false, "error": "RENAME_FAILED", "code": int(rename_error), "path": path}
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(global_backup)
	return {"ok": true, "path": path, "schema_version": SCHEMA_VERSION}

static func load_snapshot(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "NOT_FOUND", "path": path}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "OPEN_FAILED", "path": path}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "CORRUPT", "path": path}
	var decoded: Variant = _decode_large_ints(parsed)
	if not decoded is Dictionary:
		return {"ok": false, "error": "CORRUPT", "path": path}
	var payload: Dictionary = decoded as Dictionary
	if int(payload.get("schema_version", -1)) != SCHEMA_VERSION:
		return {
			"ok": false,
			"error": "UNSUPPORTED_SCHEMA",
			"found": int(payload.get("schema_version", -1)),
			"expected": SCHEMA_VERSION,
			"path": path,
		}
	var validation: Dictionary = _validate_snapshot(payload)
	if not bool(validation.get("ok", false)):
		validation["path"] = path
		return validation
	if String(payload.get("phase", "preview")).to_lower() == "combat":
		return {"ok": false, "error": "MIDCOMBAT_SAVE_REJECTED", "path": path}
	return {"ok": true, "snapshot": payload, "path": path}

static func clear(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

static func _validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot == null or snapshot.is_empty():
		return {"ok": false, "error": "INVALID_SNAPSHOT"}
	var phase: String = String(snapshot.get("phase", "")).strip_edges().to_lower()
	if phase == "":
		return {"ok": false, "error": "MISSING_PHASE"}
	if phase != "preview" and phase != "menu" and phase != "post_combat" and phase != "combat":
		return {"ok": false, "error": "INVALID_PHASE"}
	if String(snapshot.get("snapshot_kind", "")) == "active_run":
		var required_sections: Array[String] = ["game_state", "economy", "shop", "board", "bench", "inventory"]
		for section: String in required_sections:
			if not snapshot.has(section):
				return {"ok": false, "error": "MISSING_SECTION", "section": section}
	return {"ok": true}

static func _encode_large_ints(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		var integer: int = int(value)
		if integer > MAX_EXACT_JSON_INT or integer < -MAX_EXACT_JSON_INT:
			return "%s%d" % [INT64_PREFIX, integer]
		return integer
	if value is Dictionary:
		var encoded_dictionary: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			encoded_dictionary[key] = _encode_large_ints((value as Dictionary)[key])
		return encoded_dictionary
	if value is Array:
		var encoded_array: Array = []
		for entry: Variant in value:
			encoded_array.append(_encode_large_ints(entry))
		return encoded_array
	return value

static func _decode_large_ints(value: Variant) -> Variant:
	if typeof(value) == TYPE_STRING:
		var text: String = String(value)
		if text.begins_with(INT64_PREFIX):
			var digits: String = text.trim_prefix(INT64_PREFIX)
			if digits.is_valid_int():
				return int(digits)
		return value
	if value is Dictionary:
		var decoded_dictionary: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			decoded_dictionary[key] = _decode_large_ints((value as Dictionary)[key])
		return decoded_dictionary
	if value is Array:
		var decoded_array: Array = []
		for entry: Variant in value:
			decoded_array.append(_decode_large_ints(entry))
		return decoded_array
	return value
