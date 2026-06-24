extends RefCounted
class_name RGATeamShells

const RGAUnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const RGASettings := preload("res://tests/rga_testing/settings.gd")

# Team shells help produce realistic, low-noise team contexts for the subject.
# All functions return Array[String] of unit_ids, with the subject included.
# Team sizes supported: 1, 2, 3 (1v1/2v2/3v3 on the subject side).

static func subject_plus_peel_tank(subject_id: String, team_size: int) -> Array[String]:
	var team: Array[String] = []
	var exclude: Dictionary = { String(subject_id): true }
	team.append(String(subject_id))
	# Prefer tank with peel approach; fallback to any tank
	var tank_ids: Array[String] = _list_by_filters(PackedStringArray(["tank"]), PackedStringArray(["peel"]), exclude)
	if tank_ids.is_empty():
		tank_ids = _list_by_filters(PackedStringArray(["tank"]), PackedStringArray([]), exclude)
	if not tank_ids.is_empty() and team.size() < max(1, team_size):
		var t := String(tank_ids[0])
		exclude[t] = true
		team.append(t)
	return _fill_neutral(team, team_size, exclude)

static func subject_plus_healer(subject_id: String, team_size: int) -> Array[String]:
	var team: Array[String] = []
	var exclude: Dictionary = { String(subject_id): true }
	team.append(String(subject_id))
	# Prefer support with sustain/amp; fallback to any support
	var sup_ids: Array[String] = _list_by_filters(PackedStringArray(["support"]), PackedStringArray(["sustain", "amp"]), exclude)
	if sup_ids.is_empty():
		sup_ids = _list_by_filters(PackedStringArray(["support"]), PackedStringArray([]), exclude)
	if not sup_ids.is_empty() and team.size() < max(1, team_size):
		var s := String(sup_ids[0])
		exclude[s] = true
		team.append(s)
	return _fill_neutral(team, team_size, exclude)

static func subject_plus_diver(subject_id: String, team_size: int) -> Array[String]:
	var team: Array[String] = []
	var exclude: Dictionary = { String(subject_id): true }
	team.append(String(subject_id))
	# Prefer assassin/brawler with engage/access_backline; fallbacks to role-only
	var roles: PackedStringArray = PackedStringArray(["assassin", "brawler"])
	var diver_ids: Array[String] = _list_by_any_roles(roles, PackedStringArray(["engage", "access_backline"]), exclude)
	if diver_ids.is_empty():
		diver_ids = _list_by_any_roles(roles, PackedStringArray([]), exclude)
	if not diver_ids.is_empty() and team.size() < max(1, team_size):
		var d := String(diver_ids[0])
		exclude[d] = true
		team.append(d)
	return _fill_neutral(team, team_size, exclude)

static func subject_plus_neutral(subject_id: String, team_size: int) -> Array[String]:
	var team: Array[String] = [String(subject_id)]
	var exclude: Dictionary = { String(subject_id): true }
	return _fill_neutral(team, team_size, exclude)

# Returns an all-neutral filler combo with no subject (useful for opponent teams).
static func neutral_filler_combo(team_size: int, exclude_ids: Array[String] = []) -> Array[String]:
	var exclude: Dictionary = {}
	for e in exclude_ids:
		exclude[String(e)] = true
	var pool: Array[String] = _list_by_filters(PackedStringArray([]), PackedStringArray([]), exclude)
	return _pick_n(pool, max(0, team_size), exclude)

# --- Internals -----------------------------------------------------------

static func _list_by_filters(role_filter: PackedStringArray, approach_filter: PackedStringArray, exclude: Dictionary) -> Array[String]:
	var s: RGASettings = RGASettings.new()
	s.role_filter = role_filter
	s.approach_filter = approach_filter
	var cat: RGAUnitCatalog = RGAUnitCatalog.new()
	var entries: Array[Dictionary] = cat.list(s)
	var out: Array[String] = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var uid := String(e.get("id", ""))
		if uid == "":
			continue
		if exclude.has(uid):
			continue
		out.append(uid)
	return out

static func _list_by_any_roles(roles: PackedStringArray, approach_filter: PackedStringArray, exclude: Dictionary) -> Array[String]:
	var all: Array[String] = []
	for r in roles:
		var ids: Array[String] = _list_by_filters(PackedStringArray([String(r)]), approach_filter, exclude)
		for id in ids:
			all.append(id)
	# Deduplicate while preserving order
	var seen: Dictionary = {}
	var out: Array[String] = []
	for v in all:
		var k := String(v)
		if seen.has(k):
			continue
		seen[k] = true
		out.append(k)
	return out

static func _fill_neutral(seed_team: Array[String], team_size: int, exclude: Dictionary) -> Array[String]:
	var team: Array[String] = []
	for t in seed_team:
		team.append(String(t))
	var want: int = max(1, team_size)
	if team.size() >= want:
		return team
	var pool: Array[String] = _list_by_filters(PackedStringArray([]), PackedStringArray([]), exclude)
	var need: int = want - team.size()
	var picked: Array[String] = _pick_n(pool, need, exclude)
	for p in picked:
		exclude[String(p)] = true
		team.append(String(p))
	return team

static func _pick_n(candidates: Array[String], n: int, exclude: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if n <= 0:
		return out
	for c in candidates:
		var id := String(c)
		if exclude.has(id):
			continue
		out.append(id)
		if out.size() >= n:
			break
	return out
