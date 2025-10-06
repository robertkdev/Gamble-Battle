extends Object
class_name RosterCatalog

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const RosterUtils := preload("res://scripts/game/progression/roster_utils.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")

# Single source of truth for enemy compositions per (stage, round_in_stage).
# Minimal Stage 1 entries: five NORMAL and one BOSS at round=6.
#
# You can specify unit levels inline using dictionaries in the ids list:
#   ids: [ { id: "bonko", level: 2 }, "creep" ]
# This will set bonko to level 2 for that round. You can mix strings and
# dictionaries; unspecified levels use each unit's default.

static var _entries: Dictionary = {
	1: {
		1: { StageTypes.KEY_IDS: [ {"id": "bonko", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		2: { StageTypes.KEY_IDS: [ {"id": "bonko", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		3: { StageTypes.KEY_IDS: [ {"id": "bonko", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		4: { StageTypes.KEY_IDS: [ {"id": "bo", "level": 3}, {"id": "bonko", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		5: { StageTypes.KEY_IDS: [ {"id": "bonko", "level": 3}, {"id": "creep", "level": 1}, {"id": "grint", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		6: { StageTypes.KEY_IDS: [ {"id": "morrak", "level": 4} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {} },
	},
	# Chapter 2: examples with item loadouts applied via rules.items
	2: {
		# Round 1: basic components mapped by index
		1: { StageTypes.KEY_IDS: [ {"id": "bo", "level": 2}, {"id": "creep", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["hammer"], 1: ["plate"] } }
		}},
		# Round 2: item mapping by unit id
		2: { StageTypes.KEY_IDS: [ {"id": "bonko", "level": 3}, {"id": "grint", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {
			"items": { "id": { "bonko": ["dagger"], "grint": ["plate"] } }
		}},
		# Round 3: single bruiser with a completed defensive item
		3: { StageTypes.KEY_IDS: [ {"id": "brute", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {
			"items": [ ["chestplate"] ]
		}},
		# Round 4: mage + support with thematic components
		4: { StageTypes.KEY_IDS: [ {"id": "axiom", "level": 3}, {"id": "nyxa", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["wand"], 1: ["veil"] } }
		}},
		# Round 5: trio with mixed components
		5: { StageTypes.KEY_IDS: [ {"id": "teller", "level": 3}, {"id": "sari", "level": 2}, {"id": "creep", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["crystal"], 1: ["orb"], 2: ["spike"] } }
		}},
		# Round 6: boss with a single powerful completed item
		6: { StageTypes.KEY_IDS: [ {"id": "morrak", "level": 5} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {
			"items": [ ["hyperstone"] ]
		}},
	},
}

static func get_spec(ch: int, sic: int) -> Dictionary:
	var c: int = max(1, int(ch))
	var s: int = max(1, int(sic))
	var stage_map: Dictionary = _entries.get(c, {})
	if stage_map.has(s):
		var raw: Dictionary = stage_map[s]
		var raw_ids = (raw.get(StageTypes.KEY_IDS, []) if raw.has(StageTypes.KEY_IDS) else [])
		var ids: Array[String] = []
		var levels_from_inline: Dictionary = {}
		var idx: int = 0
		# Build ids and capture inline level overrides if present
		for v in raw_ids:
			if typeof(v) == TYPE_DICTIONARY:
				var vid: String = String(v.get("id", "")).strip_edges()
				if vid != "":
					ids.append(vid)
					var level_val: int = int(v.get("level", 0))
					if level_val > 0:
						# Support both index and id keys for robustness
						levels_from_inline[idx] = level_val
						levels_from_inline[vid] = level_val
						idx += 1
					else:
						idx += 1
			else:
				var sid: String = String(v).strip_edges()
				if sid != "":
					ids.append(sid)
					idx += 1

		ids = RosterUtils.sanitize_ids(ids)

		var kind: String = String(raw.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
		var rules = raw.get(StageTypes.KEY_RULES, {})
		var rules_dict: Dictionary = (rules.duplicate(true) if typeof(rules) == TYPE_DICTIONARY else {})
		# Merge/attach level overrides into rules.levels
		if not levels_from_inline.is_empty():
			if rules_dict.has("levels") and typeof(rules_dict["levels"]) == TYPE_DICTIONARY:
				var existing: Dictionary = rules_dict["levels"]
				for k in levels_from_inline.keys():
					existing[k] = levels_from_inline[k]
				rules_dict["levels"] = existing
			else:
				rules_dict["levels"] = levels_from_inline
		return StageTypes.make_spec(ids, kind, rules_dict)

	# Fallback when chapter/stage not explicitly defined
	var def_kind := _default_kind_for(c, s)
	var def_ids: Array[String] = RosterUtils.sanitize_ids(_default_ids_for(c, s, def_kind))
	return StageTypes.make_spec(def_ids, def_kind, {})

static func _default_kind_for(ch: int, sic: int) -> String:
	var per_ch: int = int(ChapterCatalog.stages_in(ch))
	return (StageTypes.KIND_BOSS if int(sic) >= per_ch else StageTypes.KIND_NORMAL)

static func _default_ids_for(_ch: int, _sic: int, kind: String) -> Array:
	if String(kind) == StageTypes.KIND_BOSS:
		return ["morrak"]
	return ["creep"]
