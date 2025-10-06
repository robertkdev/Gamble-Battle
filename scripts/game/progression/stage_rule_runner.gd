extends Object
class_name StageRuleRunner

const RulesRegistry := preload("res://scripts/game/progression/rules/rules_registry.gd")
const RuleProvider := preload("res://scripts/game/progression/rules/rule_provider.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")
const MAX_ITEMS_PER_UNIT := 3

static var _item_warning_logged: bool = false

# Stateless hook orchestrator. Selects a provider based on spec.rules.rule_id,
# chapter default, or spec.kind, in that priority order.

static func pre_spawn(spec: Dictionary, ch: int, sic: int) -> void:
	var p = _provider_for(spec, ch)
	if p and p.has_method("on_pre_spawn"):
		p.on_pre_spawn(spec, int(ch), int(sic))

static func post_spawn(units: Array, spec: Dictionary, ch: int, sic: int) -> void:
	var p = _provider_for(spec, ch)
	if p and p.has_method("on_post_spawn"):
		p.on_post_spawn(units, spec, int(ch), int(sic))
	# Common rule: per-unit level overrides via spec.rules.levels
	_apply_level_overrides(units, spec)
	_apply_item_overrides(units, spec)

static func pre_engine_config(state, engine, spec: Dictionary, ch: int, sic: int) -> void:
	var p = _provider_for(spec, ch)
	if p and p.has_method("on_pre_engine_config"):
		p.on_pre_engine_config(state, engine, spec, int(ch), int(sic))

static func on_battle_start(state, engine, spec: Dictionary, ch: int, sic: int) -> void:
	var p = _provider_for(spec, ch)
	if p and p.has_method("on_battle_start"):
		p.on_battle_start(state, engine, spec, int(ch), int(sic))

static func _provider_for(spec: Dictionary, ch: int):
	RulesRegistry.ensure_builtins()
	var rid: String = ""
	if typeof(spec) == TYPE_DICTIONARY and spec.has(StageTypes.KEY_RULES):
		var rules = spec[StageTypes.KEY_RULES]
		if typeof(rules) == TYPE_DICTIONARY and rules.has("rule_id"):
			rid = String(rules["rule_id"]).strip_edges().to_upper()
	if rid == "":
		var meta := ChapterCatalog.get_meta_for(int(ch))
		if meta.has("default_rule_id"):
			rid = String(meta["default_rule_id"]).strip_edges().to_upper()
	if rid == "":
		var k: String = ""
		if typeof(spec) == TYPE_DICTIONARY and spec.has(StageTypes.KEY_KIND):
			k = String(spec[StageTypes.KEY_KIND])
		rid = (k if k.strip_edges() != "" else StageTypes.KIND_NORMAL)
		rid = rid.strip_edges().to_upper()
	var provider = RulesRegistry.resolve(rid)
	if provider == null:
		provider = RuleProvider.new()
	return provider

static func _apply_level_overrides(units: Array, spec: Dictionary) -> void:
	if typeof(spec) != TYPE_DICTIONARY or not spec.has(StageTypes.KEY_RULES):
		return
	var rules: Dictionary = spec[StageTypes.KEY_RULES]
	if typeof(rules) != TYPE_DICTIONARY or not rules.has("levels"):
		return
	var lv: Variant = rules["levels"]
	if typeof(lv) == TYPE_ARRAY:
		var arr: Array = lv
		var n: int = min(units.size(), arr.size())
		for i in range(n):
			var u: Unit = units[i]
			if u == null:
				continue
			var L: int = int(arr[i])
			if L <= 0:
				continue
			u.level = L
			UnitScaler.apply_cost_level_scaling(u, {})
			u.hp = u.max_hp
		return
	if typeof(lv) == TYPE_DICTIONARY:
		# Support mapping by index (0-based) or by unit id string
		var ids: Array = []
		if spec.has(StageTypes.KEY_IDS):
			ids = spec[StageTypes.KEY_IDS]
		for i in range(units.size()):
			var u: Unit = units[i]
			if u == null:
				continue
			var chosen_level: int = 0
			# index key support
			if lv.has(i):
				chosen_level = int(lv[i])
			elif lv.has(str(i)):
				chosen_level = int(lv[str(i)])
			# id key support
			elif i < ids.size():
				var sid: String = String(ids[i])
				if lv.has(sid):
					chosen_level = int(lv[sid])
			if chosen_level > 0:
				u.level = chosen_level
				UnitScaler.apply_cost_level_scaling(u, {})
				u.hp = u.max_hp

static func _apply_item_overrides(units: Array, spec: Dictionary) -> void:
	if typeof(spec) != TYPE_DICTIONARY or not spec.has(StageTypes.KEY_RULES):
		return
	var rules: Dictionary = spec[StageTypes.KEY_RULES]
	if typeof(rules) != TYPE_DICTIONARY or not rules.has("items"):
		return
	var normalized: Dictionary = _normalize_item_rules(rules["items"])
	var by_index: Dictionary = normalized.get("by_index", {})
	var by_id: Dictionary = normalized.get("by_id", {})
	if by_index.is_empty() and by_id.is_empty():
		return
	var ids: Array = []
	if spec.has(StageTypes.KEY_IDS):
		ids = spec[StageTypes.KEY_IDS]
	var items_singleton = _resolve_items_singleton()
	if items_singleton == null or not items_singleton.has_method("force_set_equipped"):
		if not _item_warning_logged:
			push_warning("StageRuleRunner: Items singleton missing force_set_equipped; skipping item overrides.")
			_item_warning_logged = true
		return
	for i in range(units.size()):
		var unit: Unit = units[i]
		if unit == null:
			continue
		var loadout: Array[String] = _items_for_unit(i, unit, ids, normalized)
		if loadout.is_empty():
			continue
		items_singleton.force_set_equipped(unit, loadout)

static func _normalize_item_rules(value) -> Dictionary:
	var by_index: Dictionary = {}
	var by_id: Dictionary = {}
	if value == null:
		return {"by_index": by_index, "by_id": by_id}
	match typeof(value):
		TYPE_DICTIONARY:
			var dict_value: Dictionary = value
			if dict_value.has("index") and typeof(dict_value["index"]) == TYPE_DICTIONARY:
				var dict_index: Dictionary = dict_value["index"]
				for k in dict_index.keys():
					var idx = _coerce_index_key(k)
					if idx == null:
						continue
					var arr = _sanitize_item_list(dict_index[k])
					if arr.is_empty():
						continue
					by_index[idx] = arr
			if dict_value.has("id") and typeof(dict_value["id"]) == TYPE_DICTIONARY:
				var dict_id: Dictionary = dict_value["id"]
				for k in dict_id.keys():
					var key = _coerce_id_key(k)
					if key == "":
						continue
					var arr2 = _sanitize_item_list(dict_id[k])
					if arr2.is_empty():
						continue
					by_id[key] = arr2
			for k in dict_value.keys():
				if k == "index" or k == "id":
					continue
				var arr3 = _sanitize_item_list(dict_value[k])
				if arr3.is_empty():
					continue
				var idx2 = _coerce_index_key(k)
				if idx2 != null:
					by_index[idx2] = arr3
				else:
					var key2 = _coerce_id_key(k)
					if key2 != "":
						by_id[key2] = arr3
		TYPE_ARRAY:
			var arr_value: Array = value
			for i in range(arr_value.size()):
				var arr4 = _sanitize_item_list(arr_value[i])
				if arr4.is_empty():
					continue
				by_index[i] = arr4
		TYPE_STRING:
			var arr5 = _sanitize_item_list(value)
			if not arr5.is_empty():
				by_index[0] = arr5
	return {"by_index": by_index, "by_id": by_id}

static func _items_for_unit(index: int, unit: Unit, spec_ids, mapping: Dictionary) -> Array[String]:
	var by_index: Dictionary = mapping.get("by_index", {})
	if by_index.has(index):
		return (by_index[index] as Array).duplicate()
	var by_id: Dictionary = mapping.get("by_id", {})
	if spec_ids is Array and index < spec_ids.size():
		var sid := String(spec_ids[index]).strip_edges().to_lower()
		if sid != "" and by_id.has(sid):
			return (by_id[sid] as Array).duplicate()
	if unit != null:
		var uid := String(unit.id).strip_edges().to_lower()
		if uid != "" and by_id.has(uid):
			return (by_id[uid] as Array).duplicate()
	return []

static func _sanitize_item_list(value) -> Array[String]:
	var collected: Array[String] = []
	_collect_item_ids(value, collected)
	return _dedupe_item_ids(collected)

static func _collect_item_ids(value, output: Array[String]) -> void:
	if value == null:
		return
	if value is Array:
		for entry in value:
			_collect_item_ids(entry, output)
		return
	if typeof(value) == TYPE_DICTIONARY:
		var dict_value: Dictionary = value
		if dict_value.has("items"):
			_collect_item_ids(dict_value["items"], output)
		if dict_value.has("item"):
			_collect_item_ids(dict_value["item"], output)
		if dict_value.has("id"):
			_collect_item_ids(dict_value["id"], output)
		if not (dict_value.has("items") or dict_value.has("item") or dict_value.has("id")):
			for v in dict_value.values():
				_collect_item_ids(v, output)
		return
	var s := String(value).strip_edges()
	if s != "":
		output.append(s)

static func _dedupe_item_ids(values: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for raw in values:
		var key := String(raw).strip_edges()
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		out.append(key)
		if out.size() >= MAX_ITEMS_PER_UNIT:
			break
	return out

static func _coerce_index_key(value) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_STRING:
			var s := String(value).strip_edges()
			if s == "":
				return null
			if s.is_valid_int():
				return int(s)
	return null

static func _coerce_id_key(value) -> String:
	var s := String(value).strip_edges()
	return s.to_lower()

static func _resolve_items_singleton():
	if Engine.has_singleton("Items"):
		return Items
	var loop = Engine.get_main_loop()
	if loop == null:
		return null
	if loop.has_method("get_root"):
		var root = loop.get_root()
		if root != null and root.has_node("/root/Items"):
			return root.get_node("/root/Items")
	return null
