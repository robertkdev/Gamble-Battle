extends Object
class_name TraitCompiler

static var _cache: Dictionary = {} # Dictionary[String, TraitDef]

static func _trait_path(id: String) -> String:
	return "res://data/traits/%s.tres" % id

static func _load_trait(id: String) -> TraitDef:
	var path := _trait_path(id)
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var td: TraitDef = load(path)
		_cache[path] = td
		return td
	return null

static func _coerced_thresholds(def: TraitDef) -> Array[int]:
	var defaults: Array[int] = [2, 4, 6, 8]
	if def == null:
		return defaults
	var out: Array[int] = []
	if "thresholds" in def and def.thresholds != null:
		for v in def.thresholds:
			out.append(int(v))
		if out.size() > 0:
			return out
	return defaults

# Returns { counts: {trait->count}, tiers: {trait->tierIndex}, thresholds: {trait->thresholds(Array[int])} }
static func compile(units: Array[Unit]) -> Dictionary:
	var counts: Dictionary = {}                # Dictionary[String, int]
	for u in units:
		if u == null:
			continue
		for t in u.traits:
			var key := String(t)
			counts[key] = int(counts.get(key, 0)) + 1

	var tiers: Dictionary = {}                 # Dictionary[String, int]
	var thresholds_out: Dictionary = {}        # Dictionary[String, Array[int]]

	for trait_id in counts.keys():
		var def := _load_trait(trait_id)
		var thresholds: Array[int] = _coerced_thresholds(def)
		thresholds_out[trait_id] = thresholds

		var c := int(counts[trait_id])
		var tier := -1
		for i in range(thresholds.size()):
			if c >= thresholds[i]:
				tier = i
		tiers[trait_id] = tier

	return {
		"counts": counts,
		"tiers": tiers,
		"thresholds": thresholds_out,
	}
