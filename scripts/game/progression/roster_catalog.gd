extends Object
class_name RosterCatalog

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const RosterUtils := preload("res://scripts/game/progression/roster_utils.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")

# Single source of truth for enemy compositions per (stage/chapter, round_in_stage).
# Chapters 1-5 are authored for the initial campaign pass. Each chapter uses
# six rounds: creep reward rounds, normal pressure rounds, one occasional
# special/elite round, and a boss round at round 6.
#
# You can specify unit levels inline using dictionaries in the ids list:
#   ids: [ { id: "bonko", level: 2 }, "creep" ]
# This will set bonko to level 2 for that round. You can mix strings and
# dictionaries; unspecified levels use each unit's default.

static var _entries: Dictionary = {
	1: {
		1: { StageTypes.KEY_IDS: [ {"id": "beegle", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		2: { StageTypes.KEY_IDS: [ {"id": "berebell", "level": 1}, {"id": "axiom", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		3: { StageTypes.KEY_IDS: [ "drubble", "drueling", "beegle", "faeling" ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		4: { StageTypes.KEY_IDS: [ {"id": "bo", "level": 1}, {"id": "bonko", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_ELITE, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["plate"], 1: ["hammer"] } }
		} },
		5: { StageTypes.KEY_IDS: [ {"id": "veyra", "level": 2}, {"id": "luna", "level": 1}, {"id": "teller", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		6: { StageTypes.KEY_IDS: [ {"id": "morrak", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {} },
	},
	2: {
		1: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 2}, {"id": "drueling", "level": 1}, {"id": "beegle", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		2: { StageTypes.KEY_IDS: [ {"id": "grint", "level": 2}, {"id": "nyxa", "level": 1}, {"id": "totem", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		3: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 2}, {"id": "drueling", "level": 2}, {"id": "beegle", "level": 2}, {"id": "faeling", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		4: { StageTypes.KEY_IDS: [ {"id": "brute", "level": 2}, {"id": "cashmere", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_ELITE, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["plate"], 1: ["wand"] } }
		} },
		5: { StageTypes.KEY_IDS: [ {"id": "bo", "level": 2}, {"id": "sari", "level": 2}, {"id": "paisley", "level": 1} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		6: { StageTypes.KEY_IDS: [ {"id": "korath", "level": 4} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {
			"items": [ ["guard"] ]
		} },
	},
	3: {
		1: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 2}, {"id": "drueling", "level": 2}, {"id": "beegle", "level": 2}, {"id": "faeling", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		2: { StageTypes.KEY_IDS: [ {"id": "vykos", "level": 2}, {"id": "volt", "level": 2}, {"id": "repo", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		3: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 3}, {"id": "drueling", "level": 2}, {"id": "beegle", "level": 2}, {"id": "faeling", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		4: { StageTypes.KEY_IDS: [ {"id": "mortem", "level": 2}, {"id": "berebell", "level": 2}, {"id": "veyra", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_ELITE, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["spike"], 1: ["hammer"], 2: ["plate"] } }
		} },
		5: { StageTypes.KEY_IDS: [ {"id": "teller", "level": 3}, {"id": "axiom", "level": 2}, {"id": "luna", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		6: { StageTypes.KEY_IDS: [ {"id": "hexeon", "level": 3}, {"id": "totem", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["spellblade"], 1: ["veil"] } }
		} },
	},
	4: {
		1: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 3}, {"id": "drueling", "level": 3}, {"id": "beegle", "level": 3}, {"id": "faeling", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		2: { StageTypes.KEY_IDS: [ {"id": "brute", "level": 3}, {"id": "cashmere", "level": 3}, {"id": "nyxa", "level": 2} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		3: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 3}, {"id": "drueling", "level": 3}, {"id": "beegle", "level": 3}, {"id": "faeling", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		4: { StageTypes.KEY_IDS: [ {"id": "kythera", "level": 3}, {"id": "paisley", "level": 3}, {"id": "sari", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_ELITE, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["wardheart"], 1: ["codex"], 2: ["shiv"] } }
		} },
		5: { StageTypes.KEY_IDS: [ {"id": "bo", "level": 3}, {"id": "korath", "level": 3}, {"id": "volt", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		6: { StageTypes.KEY_IDS: [ {"id": "morrak", "level": 4}, {"id": "repo", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["hyperstone"], 1: ["anchor"] } }
		} },
	},
	5: {
		1: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 4}, {"id": "drueling", "level": 3}, {"id": "beegle", "level": 3}, {"id": "faeling", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		2: { StageTypes.KEY_IDS: [ {"id": "veyra", "level": 4}, {"id": "vykos", "level": 3}, {"id": "teller", "level": 3}, {"id": "axiom", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		3: { StageTypes.KEY_IDS: [ {"id": "drubble", "level": 4}, {"id": "drueling", "level": 4}, {"id": "beegle", "level": 4}, {"id": "faeling", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {} },
		4: { StageTypes.KEY_IDS: [ {"id": "hexeon", "level": 4}, {"id": "nyxa", "level": 4}, {"id": "totem", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_ELITE, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["lifetaker"], 1: ["arc_dice"], 2: ["serenity"] } }
		} },
		5: { StageTypes.KEY_IDS: [ {"id": "brute", "level": 4}, {"id": "cashmere", "level": 4}, {"id": "mortem", "level": 4}, {"id": "luna", "level": 3} ], StageTypes.KEY_KIND: StageTypes.KIND_NORMAL, StageTypes.KEY_RULES: {} },
		6: { StageTypes.KEY_IDS: [ {"id": "morrak", "level": 5}, {"id": "korath", "level": 4}, {"id": "paisley", "level": 4} ], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {
			"items": { "index": { 0: ["blood_engine"], 1: ["sanctum"], 2: ["mageheart"] } }
		} },
	},
}

const DEFAULT_CREEP_REWARDS: Dictionary = {
	"pool_path": "res://data/creeps/reward_pools/default.tres",
	"rolls_per_kill": 1,
	"only_creeps": true,
	"source_team": "player",
}

static func get_spec(ch: int, sic: int) -> Dictionary:
	var c: int = max(1, int(ch))
	var s: int = max(1, int(sic))
	var stage_map: Dictionary = _entries.get(c, {})
	if stage_map.has(s):
		var raw: Dictionary = stage_map[s]
		var raw_ids_value: Variant = raw.get(StageTypes.KEY_IDS, []) if raw.has(StageTypes.KEY_IDS) else []
		var raw_ids: Array = raw_ids_value if raw_ids_value is Array else []
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
		var rules: Variant = raw.get(StageTypes.KEY_RULES, {})
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
		_attach_default_creep_rewards(rules_dict, kind)
		return StageTypes.make_spec(ids, kind, rules_dict)

	# Fallback when chapter/stage not explicitly defined
	var def_kind: String = _default_kind_for(c, s)
	var def_ids: Array[String] = RosterUtils.sanitize_ids(_default_ids_for(c, s, def_kind))
	var def_rules: Dictionary = {}
	_attach_default_creep_rewards(def_rules, def_kind)
	return StageTypes.make_spec(def_ids, def_kind, def_rules)

static func _attach_default_creep_rewards(rules: Dictionary, kind: String) -> void:
	if String(kind).strip_edges().to_upper() != StageTypes.KIND_CREEPS:
		return
	if rules.has("rewards"):
		return
	rules["rewards"] = DEFAULT_CREEP_REWARDS.duplicate(true)

static func _default_kind_for(ch: int, sic: int) -> String:
	var per_ch: int = int(ChapterCatalog.stages_in(ch))
	return (StageTypes.KIND_BOSS if int(sic) >= per_ch else StageTypes.KIND_NORMAL)

static func _default_ids_for(_ch: int, _sic: int, kind: String) -> Array:
	if String(kind) == StageTypes.KIND_BOSS:
		return ["morrak"]
	return ["creep"]
