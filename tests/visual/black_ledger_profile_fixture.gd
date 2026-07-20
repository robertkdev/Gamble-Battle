extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")

const BACKUP_PATH: String = "user://black_ledger_capture_profile_backup.bin"
const MARKER_PATH: String = "user://black_ledger_capture_profile_backup.marker"
const REQUEST_PATH: String = "user://black_ledger_capture_request.json"

@export_enum("fresh", "veteran", "restore") var mode: String = "fresh"

func _ready() -> void:
	var result: Dictionary = {}
	match mode:
		"fresh":
			result = _seed(false)
		"veteran":
			result = _seed(true)
		"restore":
			result = _restore()
		_:
			result = {"ok": false, "error": "UNKNOWN_MODE"}
	if bool(result.get("ok", false)):
		print("BLACK_LEDGER_PROFILE_FIXTURE:PASS mode=%s" % mode)
		get_tree().quit(0)
	else:
		push_error("BLACK_LEDGER_PROFILE_FIXTURE:FAIL mode=%s error=%s" % [mode, String(result.get("error", "UNKNOWN"))])
		get_tree().quit(1)

func _seed(veteran: bool) -> Dictionary:
	var backup_result: Dictionary = _backup_once()
	if not bool(backup_result.get("ok", false)):
		return backup_result
	var seeded: Dictionary = AccountProfileStoreScript.default_profile()
	var output_name: String = "01_main_fresh.png"
	if veteran:
		seeded["omens_balance"] = 24
		seeded["lifetime_omens"] = 52
		seeded["unlocked_starter_ids"] = ["axiom", "bonko", "brute", "cashmere", "pilfer", "sari", "berebell", "grint", "knoll"]
		seeded["completed_bounty_ids"] = [
			"axiom_ascendant", "calculated_desperation", "unbought_crown", "made_not_bought", "last_one_standing", "woven_company",
			"five_disciplines", "empty_chair", "chosen_champion", "stable_foundation", "new_formation", "shared_spotlight",
		]
		output_name = "02_main_veteran.png"
	var saved: Dictionary = AccountProfileStoreScript.save_profile(seeded)
	if not bool(saved.get("ok", false)):
		return saved
	return _write_text(REQUEST_PATH, JSON.stringify({
		"output_path": "res://outputs/visual_debug/black_ledger/main_source/%s" % output_name,
		"quit_after_capture": true,
	}, "\t"))

func _backup_once() -> Dictionary:
	if FileAccess.file_exists(MARKER_PATH):
		return {"ok": true, "existing": true}
	var target_path: String = AccountProfileStoreScript.DEFAULT_PATH
	var marker: String = "absent"
	if FileAccess.file_exists(target_path):
		var source: FileAccess = FileAccess.open(target_path, FileAccess.READ)
		if source == null:
			return {"ok": false, "error": "BACKUP_READ_FAILED"}
		var raw: PackedByteArray = source.get_buffer(source.get_length())
		source.close()
		var backup: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup == null:
			return {"ok": false, "error": "BACKUP_WRITE_FAILED"}
		backup.store_buffer(raw)
		backup.flush()
		backup.close()
		marker = "present"
	return _write_text(MARKER_PATH, marker)

func _restore() -> Dictionary:
	if not FileAccess.file_exists(MARKER_PATH):
		return {"ok": false, "error": "BACKUP_MARKER_NOT_FOUND"}
	var marker_file: FileAccess = FileAccess.open(MARKER_PATH, FileAccess.READ)
	if marker_file == null:
		return {"ok": false, "error": "MARKER_READ_FAILED"}
	var marker: String = marker_file.get_as_text().strip_edges()
	marker_file.close()
	var target_path: String = AccountProfileStoreScript.DEFAULT_PATH
	if marker == "present":
		var backup: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if backup == null:
			return {"ok": false, "error": "BACKUP_READ_FAILED"}
		var raw: PackedByteArray = backup.get_buffer(backup.get_length())
		backup.close()
		var target: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
		if target == null:
			return {"ok": false, "error": "RESTORE_WRITE_FAILED"}
		target.store_buffer(raw)
		target.flush()
		target.close()
	else:
		AccountProfileStoreScript.clear(target_path)
	var cleanup_paths: Array[String] = [BACKUP_PATH, MARKER_PATH, REQUEST_PATH, "%s.bak" % target_path, "%s.tmp" % target_path]
	for cleanup_path: String in cleanup_paths:
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	return {"ok": true}

func _write_text(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "WRITE_FAILED", "path": path}
	file.store_string(text)
	file.flush()
	file.close()
	return {"ok": true, "path": path}
