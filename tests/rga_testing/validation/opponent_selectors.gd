extends RefCounted
class_name RGAOpponentSelectors

const RGAUnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const RGASettings := preload("res://tests/rga_testing/settings.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

# Deterministic opponent selectors to improve coverage and reduce bias.
# All selectors exclude the subject and return Array[String] unit_ids.

static func select_balanced(subject_id: String, n: int) -> Array[String]:
	# Round-robin across roles to build a varied set.
	var subj := String(subject_id)
	var out: Array[String] = []
	var exclude: Dictionary = { subj: true }
	var roles: PackedStringArray = PackedStringArray(["tank", "brawler", "marksman", "assassin", "mage", "support"])
	var i: int = 0
	while out.size() < max(0, n) and i < 24: # hard cap to avoid infinite loops
		for r in roles:
			if out.size() >= max(0, n):
				break
			var ids: Array[String] = _list_by_filters(PackedStringArray([String(r)]), PackedStringArray([]), exclude)
			if ids.is_empty():
				continue
			var pick: String = String(ids[0])
			if not exclude.has(pick):
				exclude[pick] = true
				out.append(pick)
		i += 1
	return out

static func select_counters(subject_id: String, n: int) -> Array[String]:
	# Select opponents likely to stress the subject given its primary role.
	var subj := String(subject_id)
	var ident: Dictionary = RoleCommon.get_identity(subj)
	var role: String = String(ident.get("primary_role", "")).strip_edges().to_lower()
	var counter_roles: PackedStringArray = _counter_roles_for(role)
	var out: Array[String] = []
	var exclude: Dictionary = { subj: true }
	for cr in counter_roles:
		if out.size() >= max(0, n):
			break
		var ids: Array[String] = _list_by_filters(PackedStringArray([String(cr)]), PackedStringArray([]), exclude)
		for id in ids:
			var k := String(id)
			if exclude.has(k):
				continue
			exclude[k] = true
			out.append(k)
			if out.size() >= max(0, n):
				break
	# If still short, fill with balanced mix
	if out.size() < max(0, n):
		var filler: Array[String] = select_balanced(subj, n - out.size())
		for f in filler:
			out.append(String(f))
	return out

static func select_light(subject_id: String, n: int) -> Array[String]:
	# Prefer lower-cost opponents (confidence check). Falls back to balanced.
	var subj := String(subject_id)
	var out: Array[String] = []
	var exclude: Dictionary = { subj: true }
	var s: RGASettings = RGASettings.new()
	s.cost_filter = PackedInt32Array([1, 2])
	var ids: Array[String] = _list_with_settings(s, exclude)
	for id in ids:
		var k := String(id)
		if exclude.has(k):
			continue
		exclude[k] = true
		out.append(k)
		if out.size() >= max(0, n):
			break
	if out.size() < max(0, n):
		# Relax cost band
		s.cost_filter = PackedInt32Array([1, 2, 3])
		ids = _list_with_settings(s, exclude)
		for id2 in ids:
			var kk := String(id2)
			if exclude.has(kk):
				continue
			exclude[kk] = true
			out.append(kk)
			if out.size() >= max(0, n):
				break
	if out.size() < max(0, n):
		var filler: Array[String] = select_balanced(subj, n - out.size())
		for f in filler:
			out.append(String(f))
	return out

# --- helpers -------------------------------------------------------------

static func _list_by_filters(role_filter: PackedStringArray, approach_filter: PackedStringArray, exclude: Dictionary) -> Array[String]:
	var s: RGASettings = RGASettings.new()
	s.role_filter = role_filter
	s.approach_filter = approach_filter
	return _list_with_settings(s, exclude)

static func _list_with_settings(s: RGASettings, exclude: Dictionary) -> Array[String]:
	var cat: RGAUnitCatalog = RGAUnitCatalog.new()
	var entries: Array[Dictionary] = cat.list(s)
	var out: Array[String] = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var uid: String = String(e.get("id", ""))
		if uid == "":
			continue
		if exclude.has(uid):
			continue
		out.append(uid)
	return out

static func _counter_roles_for(role_id: String) -> PackedStringArray:
	var r := String(role_id).strip_edges().to_lower()
	match r:
		"marksman":
			return PackedStringArray(["assassin", "brawler"]) # divers and assassins pressure backline
		"tank":
			return PackedStringArray(["marksman", "mage"]) # shredders and burst
		"brawler":
			return PackedStringArray(["marksman", "mage"]) # kite/poke and burst punish extended fights
		"assassin":
			return PackedStringArray(["support", "tank"]) # peel and hard control
		"mage":
			return PackedStringArray(["assassin", "brawler"]) # dive counters setup and channeling
		"support":
			return PackedStringArray(["assassin", "brawler"]) # pick pressure tests peel/positioning
		_:
			return PackedStringArray(["brawler", "marksman"]) # sensible default mix
