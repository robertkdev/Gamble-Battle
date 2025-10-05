extends RefCounted
class_name RGAScenarioBuilder

const RGASettings = preload("res://tests/rga_testing/settings.gd")
const RGADataModels = preload("res://tests/rga_testing/core/data_models.gd")
const RGAArchetypeCatalog = preload("res://tests/rga_testing/teams/archetype_catalog.gd")
const RGARandom = preload("res://tests/rga_testing/util/random.gd")

# Generates SimJobs for multi-unit matchups by pairing archetypes according to
# declarative "intent" dictionaries. Supports tag-based selection, symmetry
# reduction, and deterministic stratified sampling of archetype pairings.
func build(settings: RGASettings, intents: Array = []) -> Array:
    if settings == null:
        push_warning("ScenarioBuilder: settings required")
        return []
    var catalog := RGAArchetypeCatalog.new()
    var archetype_entries := catalog.list_all()
    if archetype_entries.is_empty():
        push_warning("ScenarioBuilder: archetype catalog empty")
        return []
    var archetypes_by_id := _index_by_id(archetype_entries)
    var tag_index := _build_tag_index(archetype_entries)
    var normalized_intents := _normalize_intents(intents, settings)
    if normalized_intents.is_empty():
        normalized_intents = [
            {
                "id": "all_vs_all",
                "team_size": _default_team_size(settings),
                "team_a": {},
                "team_b": {},
                "scenario_id": "open_field",
                "map_params": {},
                "capabilities": ["base"],
                "metadata": {},
                "max_pairs": 0,
                "allow_mirror": false,
            }
        ]
    var jobs: Array = []
    var seen_pairs: Dictionary = {}
    var sim_index := 0
    for intent in normalized_intents:
        var intent_id := String(intent.get("id", "intent_%d" % sim_index))
        var team_size := int(intent.get("team_size", _default_team_size(settings)))
        if team_size <= 0:
            team_size = _default_team_size(settings)
        var side_a_spec: Dictionary = intent.get("team_a", {})
        var side_b_spec: Dictionary = intent.get("team_b", {})
        var candidates_a := _select_archetypes(side_a_spec, archetypes_by_id, tag_index)
        var candidates_b := _select_archetypes(side_b_spec, archetypes_by_id, tag_index)
        if candidates_a.is_empty() or candidates_b.is_empty():
            push_warning("ScenarioBuilder: intent %s skipped (no archetypes for A or B)" % intent_id)
            continue
        var allow_mirror := bool(intent.get("allow_mirror", false))
        var allow_duplicates := bool(intent.get("allow_duplicate_pairs", false))
        var raw_pairs := _cartesian_pairs(candidates_a, candidates_b, allow_mirror)
        if raw_pairs.is_empty():
            continue
        var max_pairs := int(intent.get("max_pairs", 0))
        if max_pairs <= 0:
            max_pairs = int(intent.get("samples", raw_pairs.size()))
        max_pairs = clamp(max_pairs, 0, raw_pairs.size())
        var filtered_pairs: Array = []
        for pair in raw_pairs:
            var key := _pair_key(String(pair["a"].get("id")), String(pair["b"].get("id")))
            if not allow_duplicates and seen_pairs.has(key):
                continue
            filtered_pairs.append(pair)
        if filtered_pairs.is_empty():
            continue
        if max_pairs > 0 and max_pairs < filtered_pairs.size():
            filtered_pairs = _stratified_sample(intent_id, filtered_pairs, max_pairs)
        for pair_dict in filtered_pairs:
            var arch_a: Dictionary = pair_dict.get("a", {})
            var arch_b: Dictionary = pair_dict.get("b", {})
            var key2 := _pair_key(String(arch_a.get("id")), String(arch_b.get("id")))
            if not allow_duplicates and seen_pairs.has(key2):
                continue
            var team_a_ids := _select_units(arch_a, team_size)
            var team_b_ids := _select_units(arch_b, team_size)
            if team_a_ids.is_empty() or team_b_ids.is_empty():
                continue
            var resolved_size := min(team_a_ids.size(), team_b_ids.size())
            if resolved_size <= 0:
                continue
            var job := RGADataModels.SimJob.new()
            job.run_id = String(settings.run_id)
            job.sim_index = sim_index
            job.seed = int(settings.sim_seed_start) + sim_index
            job.team_a_ids = team_a_ids
            job.team_b_ids = team_b_ids
            job.team_size = resolved_size
            job.scenario_id = String(intent.get("scenario_id", "open_field"))
            job.map_params = _duplicate_dict(intent.get("map_params", {}))
            job.deterministic = bool(settings.deterministic)
            job.delta_s = 0.05
            job.timeout_s = float(settings.timeout_s)
            job.abilities = bool(settings.abilities)
            job.ability_metrics = bool(settings.ability_metrics)
            job.alternate_order = bool(intent.get("alternate_order", false))
            job.bridge_projectile_to_hit = bool(intent.get("bridge_projectile_to_hit", true))
            job.capabilities = _resolve_capabilities(intent.get("capabilities", []))
            job.metadata = _compose_metadata(intent, arch_a, arch_b, side_a_spec, side_b_spec)
            jobs.append(job)
            seen_pairs[key2] = true
            sim_index += 1
    return jobs

func _index_by_id(entries: Array) -> Dictionary:
    var out: Dictionary = {}
    for entry in entries:
        if entry is Dictionary:
            var dup = entry.duplicate(true)
            var id := String(dup.get("id", "")).strip_edges()
            if id == "":
                continue
            dup["tags"] = _normalize_string_array(dup.get("tags", []))
            dup["unit_ids"] = _normalize_string_array(dup.get("unit_ids", []))
            out[id] = dup
    return out

func _build_tag_index(entries: Array) -> Dictionary:
    var out: Dictionary = {}
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var tags: Array = entry.get("tags", [])
        var id := String(entry.get("id", ""))
        for tag in tags:
            var lower := String(tag).strip_edges().to_lower()
            if lower == "":
                continue
            if not out.has(lower):
                out[lower] = []
            var arr: Array = out[lower]
            arr.append(id)
            out[lower] = arr
    return out

func _normalize_intents(intents: Array, settings: RGASettings) -> Array:
    var result: Array = []
    if intents == null:
        return result
    var counter := 0
    for raw in intents:
        if not (raw is Dictionary):
            continue
        var intent: Dictionary = raw.duplicate(true)
        if String(intent.get("id", "")).strip_edges() == "":
            intent["id"] = "intent_%d" % counter
        counter += 1
        intent["team_a"] = _normalize_team_spec(intent, "team_a")
        intent["team_b"] = _normalize_team_spec(intent, "team_b")
        if not intent.has("team_size"):
            intent["team_size"] = _default_team_size(settings)
        result.append(intent)
    return result

func _normalize_team_spec(intent: Dictionary, prefix: String) -> Dictionary:
    var spec: Dictionary = {}
    if intent.has(prefix) and intent[prefix] is Dictionary:
        spec = (intent[prefix] as Dictionary).duplicate(true)
    var tags_key := prefix + "_tags"
    if intent.has(tags_key):
        spec["tags"] = _normalize_string_array(intent.get(tags_key))
    elif spec.has("tags"):
        spec["tags"] = _normalize_string_array(spec.get("tags"))
    var ids_key := prefix + "_archetypes"
    if intent.has(ids_key):
        spec["archetypes"] = _normalize_string_array(intent.get(ids_key))
    elif spec.has("archetypes"):
        spec["archetypes"] = _normalize_string_array(spec.get("archetypes"))
    var include_key := prefix + "_include"
    if intent.has(include_key):
        spec["include"] = _normalize_string_array(intent.get(include_key))
    elif spec.has("include"):
        spec["include"] = _normalize_string_array(spec.get("include"))
    var exclude_key := prefix + "_exclude"
    if intent.has(exclude_key):
        spec["exclude"] = _normalize_string_array(intent.get(exclude_key))
    elif spec.has("exclude"):
        spec["exclude"] = _normalize_string_array(spec.get("exclude"))
    spec["require_all_tags"] = bool(spec.get("require_all_tags", false))
    spec["allow_mirror"] = bool(spec.get("allow_mirror", false))
    return spec

func _select_archetypes(spec: Dictionary, by_id: Dictionary, tag_index: Dictionary) -> Array:
    var include_ids := _normalize_string_array(spec.get("archetypes", spec.get("include", [])))
    var tags_any := _normalize_string_array(spec.get("tags", []))
    var exclude_ids := _normalize_string_array(spec.get("exclude", []))
    var require_all := bool(spec.get("require_all_tags", false))
    var candidate_ids: Array = []
    if include_ids.is_empty():
        for id in by_id.keys():
            candidate_ids.append(String(id))
        candidate_ids.sort()
    else:
        for inc in include_ids:
            if by_id.has(inc):
                candidate_ids.append(inc)
        candidate_ids.sort()
    if not tags_any.is_empty():
        var tag_matches: Array = []
        for tag in tags_any:
            var lower := String(tag).strip_edges().to_lower()
            if lower == "":
                continue
            if tag_index.has(lower):
                for id2 in tag_index[lower]:
                    tag_matches.append(String(id2))
            else:
                push_warning("ScenarioBuilder: no archetypes tagged '%s'" % tag)
        if require_all:
            var filtered: Array = []
            for id3 in candidate_ids:
                var arch: Dictionary = by_id.get(id3, {})
                if arch.is_empty():
                    continue
                var arch_tags: Array = arch.get("tags", [])
                var lower_map: Dictionary = {}
                for at in arch_tags:
                    var lowered := String(at).strip_edges().to_lower()
                    if lowered != "":
                        lower_map[lowered] = true
                var has_all := true
                for wanted in tags_any:
                    var wanted_lower := String(wanted).strip_edges().to_lower()
                    if wanted_lower == "":
                        continue
                    if not lower_map.has(wanted_lower):
                        has_all = false
                        break
                if has_all:
                    filtered.append(id3)
            candidate_ids = filtered
        else:
            var tag_set := _to_string_set(tag_matches)
            var filtered2: Array = []
            for id4 in candidate_ids:
                if tag_set.has(id4):
                    filtered2.append(id4)
            candidate_ids = filtered2
    if not exclude_ids.is_empty():
        var exclude_set := _to_string_set(exclude_ids)
        var kept: Array = []
        for id5 in candidate_ids:
            if not exclude_set.has(id5):
                kept.append(id5)
        candidate_ids = kept
    var out: Array = []
    for cid in candidate_ids:
        var entry: Dictionary = by_id.get(cid, {})
        if entry.is_empty():
            continue
        out.append(entry)
    return out

func _cartesian_pairs(left: Array, right: Array, allow_mirror: bool) -> Array:
    var out: Array = []
    for a in left:
        if not (a is Dictionary):
            continue
        var a_id := String(a.get("id", ""))
        for b in right:
            if not (b is Dictionary):
                continue
            var b_id := String(b.get("id", ""))
            if not allow_mirror and a_id == b_id:
                continue
            out.append({"a": a, "b": b})
    return out

func _stratified_sample(intent_id: String, combos: Array, limit: int) -> Array:
    var pool: Array = []
    for c in combos:
        var dup: Dictionary = c.duplicate(true)
        dup["_hash"] = _combo_hash(intent_id, String(dup.get("a").get("id")), String(dup.get("b").get("id")))
        pool.append(dup)
    var usage_a: Dictionary = {}
    var usage_b: Dictionary = {}
    var selected: Array = []
    var remaining := pool.duplicate()
    while selected.size() < limit and not remaining.is_empty():
        var best_index := 0
        var best_score := null
        for i in range(remaining.size()):
            var item: Dictionary = remaining[i]
            var a_id := String(item.get("a").get("id"))
            var b_id := String(item.get("b").get("id"))
            var a_used := int(usage_a.get(a_id, 0))
            var b_used := int(usage_b.get(b_id, 0))
            var score_primary := max(a_used, b_used)
            var score_secondary := min(a_used, b_used)
            var tie := int(item.get("_hash"))
            var score = [score_primary, score_secondary, tie]
            if best_score == null or _score_less(score, best_score):
                best_score = score
                best_index = i
        var chosen: Dictionary = remaining.pop_at(best_index)
        selected.append({"a": chosen.get("a"), "b": chosen.get("b")})
        var a_key := String(chosen.get("a").get("id"))
        var b_key := String(chosen.get("b").get("id"))
        usage_a[a_key] = int(usage_a.get(a_key, 0)) + 1
        usage_b[b_key] = int(usage_b.get(b_key, 0)) + 1
    return selected

func _score_less(a_score: Array, b_score: Array) -> bool:
    if a_score[0] != b_score[0]:
        return a_score[0] < b_score[0]
    if a_score[1] != b_score[1]:
        return a_score[1] < b_score[1]
    return a_score[2] < b_score[2]

func _combo_hash(intent_id: String, a_id: String, b_id: String) -> int:
    var seed := RGARandom.hash_string64(String(intent_id))
    seed = RGARandom.combine64(seed, RGARandom.hash_string64(String(a_id)))
    seed = RGARandom.combine64(seed, RGARandom.hash_string64(String(b_id)))
    return seed

func _select_units(archetype: Dictionary, team_size: int) -> Array:
    var ids: Array = archetype.get("unit_ids", [])
    if ids == null or ids.is_empty():
        push_warning("ScenarioBuilder: archetype %s has no unit_ids" % String(archetype.get("id", "")))
        return []
    if team_size <= 0:
        team_size = ids.size()
    if ids.size() < team_size:
        push_warning("ScenarioBuilder: archetype %s lacks units for team size %d" % [String(archetype.get("id", "")), team_size])
        return []
    var out: Array = []
    for i in range(team_size):
        out.append(String(ids[i]))
    return out

func _compose_metadata(intent: Dictionary, arch_a: Dictionary, arch_b: Dictionary, spec_a: Dictionary, spec_b: Dictionary) -> Dictionary:
    var meta := _duplicate_dict(intent.get("metadata", {}))
    meta["intent_id"] = String(intent.get("id", ""))
    meta["intent_tags_a"] = _normalize_string_array(spec_a.get("tags", []))
    meta["intent_tags_b"] = _normalize_string_array(spec_b.get("tags", []))
    meta["team_a_archetype"] = String(arch_a.get("id", ""))
    meta["team_b_archetype"] = String(arch_b.get("id", ""))
    return meta

func _resolve_capabilities(raw) -> PackedStringArray:
    var list := _normalize_string_array(raw)
    if list.is_empty():
        list = ["base"]
    elif not list.has("base"):
        list.append("base")
    list.sort()
    var out: PackedStringArray = []
    for item in list:
        out.append(String(item))
    return out

func _default_team_size(settings: RGASettings) -> int:
    if settings == null or settings.team_sizes == null or settings.team_sizes.size() == 0:
        return 5
    return int(settings.team_sizes[0])

func _normalize_string_array(value) -> Array:
    var out: Array = []
    if value == null:
        return out
    if value is PackedStringArray:
        for v in (value as PackedStringArray):
            var s := String(v).strip_edges()
            if s != "":
                out.append(s)
        return out
    if value is Array:
        for v2 in value:
            var s2 := String(v2).strip_edges()
            if s2 != "":
                out.append(s2)
        return out
    var single := String(value).strip_edges()
    if single != "":
        out.append(single)
    return out

func _duplicate_dict(value) -> Dictionary:
    if value == null:
        return {}
    if value is Dictionary:
        return (value as Dictionary).duplicate(true)
    return {}

func _to_string_set(arr: Array) -> Dictionary:
    var out: Dictionary = {}
    for v in arr:
        out[String(v)] = true
    return out

func _pair_key(a_id: String, b_id: String) -> String:
    var la := String(a_id)
    var lb := String(b_id)
    if la <= lb:
        return la + "|" + lb
    return lb + "|" + la
