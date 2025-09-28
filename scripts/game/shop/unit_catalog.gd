extends RefCounted
class_name UnitCatalog

const Debug := preload("res://scripts/util/debug.gd")

# Read-only catalog of unit definitions indexed by cost.
# Scans `res://data/units` for UnitProfile/UnitDef resources and caches ID→meta.

var _scanned: bool = false
var _cost_to_ids: Dictionary = {}        # int cost -> Array[String] ids
var _meta_by_id: Dictionary = {}          # id -> { name, sprite_path, cost }

func refresh() -> void:
	_scanned = false
	_cost_to_ids.clear()
	_meta_by_id.clear()
	var dir := DirAccess.open("res://data/units")
	if dir == null:
		if Debug.enabled:
			print("[UnitCatalog] Missing directory: res://data/units")
		_scanned = true
		return
	dir.list_dir_begin()
	var seen: Dictionary = {}
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if f.begins_with("."):
			continue
		if dir.current_is_dir():
			continue
		if not f.ends_with(".tres"):
			continue
		var path := "res://data/units/%s" % f
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		var id := ""
		var name := ""
		var sprite_path := ""
		var cost := 0
		if res is UnitProfile:
			var p: UnitProfile = res
			id = String(p.id)
			name = String(p.name)
			sprite_path = String(p.sprite_path)
			cost = int(p.cost)
		elif res is UnitDef:
			var d: UnitDef = res
			id = String(d.id)
			name = String(d.name)
			sprite_path = String(d.sprite_path)
			cost = int(d.cost)
		if id == "" or cost <= 0:
			continue
		if seen.has(id):
			continue # de-duplicate by id
		seen[id] = true
		_meta_by_id[id] = {
			"name": name,
			"sprite_path": sprite_path,
			"cost": cost,
		}
		if not _cost_to_ids.has(cost):
			_cost_to_ids[cost] = []
		_cost_to_ids[cost].append(id)
	dir.list_dir_end()
	# Optional: stable sort ids alphabetically by name for deterministic order
	for c in _cost_to_ids.keys():
		var arr: Array = _cost_to_ids[c]
		arr.sort_custom(func(a, b):
			var na := String(_meta_by_id.get(String(a), {}).get("name", ""))
			var nb := String(_meta_by_id.get(String(b), {}).get("name", ""))
			return na.nocasecmp_to(nb) < 0
		)
		_cost_to_ids[c] = arr
	_scanned = true

func is_ready() -> bool:
	return _scanned

func ensure_ready() -> void:
	if not _scanned:
		refresh()

func get_all_costs() -> Array[int]:
	ensure_ready()
	var out: Array[int] = []
	for k in _cost_to_ids.keys():
		out.append(int(k))
	out.sort()
	return out

func get_ids_by_cost(cost: int) -> Array[String]:
	ensure_ready()
	var c := int(cost)
	var arr: Array = _cost_to_ids.get(c, [])
	var out: Array[String] = []
	for id in arr:
		out.append(String(id))
	return out

func count_by_cost(cost: int) -> int:
	return get_ids_by_cost(cost).size()

func has_id(id: String) -> bool:
	ensure_ready()
	return _meta_by_id.has(String(id))

func get_unit_meta(id: String) -> Dictionary:
	ensure_ready()
	return _meta_by_id.get(String(id), {})

func get_name(id: String) -> String:
	return String(get_unit_meta(id).get("name", ""))

func get_sprite_path(id: String) -> String:
	return String(get_unit_meta(id).get("sprite_path", ""))

func get_cost(id: String) -> int:
	return int(get_unit_meta(id).get("cost", 0))

func pick_id_by_cost(cost: int, rng = null) -> String:
	var ids := get_ids_by_cost(cost)
	if ids.is_empty():
		return ""
	var idx: int
	if rng and rng.has_method("randi_range"):
		idx = int(rng.randi_range(0, ids.size() - 1))
	else:
		var r := RandomNumberGenerator.new()
		r.randomize()
		idx = int(r.randi_range(0, ids.size() - 1))
	return String(ids[idx])
