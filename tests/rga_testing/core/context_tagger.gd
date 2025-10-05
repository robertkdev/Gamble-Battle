extends RefCounted
class_name ContextTagger

const BattleState := preload("res://scripts/game/combat/battle_state.gd")

const TAG_CARRY := "carry"
const TAG_FRONTLINE := "frontline"
const TAG_PRIORITY := "priority_target"
const TIMELINE_SOURCE := "pre_sim"
const OPEN_ENDED_US := -1

class ContextTags:
    extends RefCounted
    var unit_timelines: Dictionary = {}
    var zones: Dictionary = {}
    var metadata: Dictionary = {}

    func to_dict() -> Dictionary:
        return {
            "unit_timelines": _deep_clone(unit_timelines),
            "zones": _deep_clone(zones),
            "metadata": _deep_clone(metadata)
        }

    func _deep_clone(value):
        if value is Dictionary:
            return (value as Dictionary).duplicate(true)
        if value is Array:
            return (value as Array).duplicate(true)
        return value

static func make_context(state: BattleState, player_positions: Array, enemy_positions: Array, map_bounds: Rect2 = Rect2()) -> ContextTags:
    var tags := ContextTags.new()
    if state == null:
        tags.unit_timelines = {"a": [], "b": []}
        tags.zones = {"a": {}, "b": {}}
        return tags
    var player_team := state.player_team if state.player_team is Array else []
    var enemy_team := state.enemy_team if state.enemy_team is Array else []
    tags.unit_timelines = {
        "a": _build_unit_timelines(player_team),
        "b": _build_unit_timelines(enemy_team)
    }
    tags.zones = {
        "a": _build_zones(player_team, player_positions, enemy_team, enemy_positions),
        "b": _build_zones(enemy_team, enemy_positions, player_team, player_positions)
    }
    tags.metadata = {
        "map_bounds": _serialize_rect(map_bounds)
    }
    return tags

static func _build_unit_timelines(team: Array) -> Array:
    var out: Array = []
    if not (team is Array):
        return out
    for idx in range(team.size()):
        var unit = team[idx]
        if unit == null:
            out.append({"unit_index": idx, "entries": []})
            continue
        var entries: Array = []
        if _is_carry(unit):
            entries.append(_static_timeline(TAG_CARRY))
        if _is_frontline(unit):
            entries.append(_static_timeline(TAG_FRONTLINE))
        if _is_priority_target(unit):
            entries.append(_static_timeline(TAG_PRIORITY))
        out.append({
            "unit_index": idx,
            "unit_id": String(unit.id),
            "entries": entries
        })
    return out

static func _static_timeline(tag: String) -> Dictionary:
    return {
        "tag": String(tag),
        "source": TIMELINE_SOURCE,
        "segments": [{
            "start_us": 0,
            "end_us": OPEN_ENDED_US,
            "confidence": 100
        }]
    }

static func _is_carry(unit) -> bool:
    if unit == null:
        return false
    var role := String(unit.primary_role).strip_edges().to_lower()
    if role in ["marksman", "assassin", "mage", "carry"]:
        return true
    var goal := String(unit.primary_goal).strip_edges().to_lower()
    return goal.find("carry") >= 0 or goal.find("sustained_dps") >= 0 or goal.find("burst") >= 0 or goal.find("backline") >= 0

static func _is_frontline(unit) -> bool:
    if unit == null:
        return false
    var role := String(unit.primary_role).strip_edges().to_lower()
    if role in ["tank", "brawler", "vanguard"]:
        return true
    var goal := String(unit.primary_goal).strip_edges().to_lower()
    return goal.find("frontline") >= 0 or goal.find("lockdown") >= 0 or goal.find("fortification") >= 0

static func _is_priority_target(unit) -> bool:
    if unit == null:
        return false
    if _is_carry(unit):
        return true
    var goal := String(unit.primary_goal).strip_edges().to_lower()
    if goal.find("support") >= 0 and goal.find("carry") >= 0:
        return true
    var approaches := unit.approaches if unit.approaches is Array else []
    for app in approaches:
        var s := String(app).strip_edges().to_lower()
        if s in ["backline", "amplify", "pick", "execute"]:
            return true
    return false

static func _build_zones(team: Array, team_positions: Array, enemy_team: Array, enemy_positions: Array) -> Dictionary:
    var centroid_self := _hp_weighted_centroid(team, team_positions)
    var centroid_enemy := _hp_weighted_centroid(enemy_team, enemy_positions)
    var forward := (centroid_enemy - centroid_self)
    if forward.length_squared() <= 0.0001:
        forward = Vector2.RIGHT if centroid_self.x <= centroid_enemy.x else Vector2.LEFT
    if forward.length_squared() <= 0.0001:
        forward = Vector2.RIGHT
    forward = forward.normalized()
    var front_offset := 0.0
    var back_offset := 0.0
    var half_width := 0.0
    if team_positions is Array and team_positions.size() > 0:
        var perp := Vector2(-forward.y, forward.x)
        var front_weight := 0.0
        var front_total := 0.0
        var front_max := 0.0
        var back_weight := 0.0
        var back_total := 0.0
        var back_max := 0.0
        var lateral_weight := 0.0
        var lateral_total := 0.0
        for idx in range(team_positions.size()):
            var pos = team_positions[idx]
            if not (pos is Vector2):
                continue
            var unit = null
            if idx < team.size():
                unit = team[idx]
            if unit == null:
                continue
            var hp_weight := max(1.0, float(unit.max_hp))
            var offset := pos - centroid_self
            var proj := offset.dot(forward)
            if proj >= 0.0:
                front_weight += hp_weight
                front_total += proj * hp_weight
                if proj > front_max:
                    front_max = proj
            else:
                var back_proj := -proj
                back_weight += hp_weight
                back_total += back_proj * hp_weight
                if back_proj > back_max:
                    back_max = back_proj
            var lateral := abs(offset.dot(perp))
            lateral_weight += hp_weight
            lateral_total += lateral * hp_weight
        if front_weight > 0.0:
            front_offset = front_total / front_weight
        else:
            front_offset = front_max
        if back_weight > 0.0:
            back_offset = back_total / back_weight
        else:
            back_offset = back_max
        if lateral_weight > 0.0:
            half_width = lateral_total / lateral_weight
    var front_center := centroid_self + forward * front_offset
    var back_center := centroid_self - forward * back_offset
    return {
        "centroid": _serialize_vec2(centroid_self),
        "forward": _serialize_vec2(forward),
        "frontline": {
            "center": _serialize_vec2(front_center),
            "half_length": front_offset,
            "half_width": half_width
        },
        "backline": {
            "center": _serialize_vec2(back_center),
            "half_length": back_offset,
            "half_width": half_width
        }
    }

static func _hp_weighted_centroid(team: Array, positions: Array) -> Vector2:
    if not (team is Array) or not (positions is Array):
        return Vector2.ZERO
    var accum := Vector2.ZERO
    var total := 0.0
    for idx in range(positions.size()):
        var pos = positions[idx]
        if not (pos is Vector2):
            continue
        var unit = null
        if idx < team.size():
            unit = team[idx]
        if unit == null:
            continue
        var hp_weight := max(1.0, float(unit.max_hp))
        accum += pos * hp_weight
        total += hp_weight
    if total <= 0.0:
        return _average_vecs(positions)
    return accum / total

static func _average_vecs(arr: Array) -> Vector2:
    if not (arr is Array) or arr.is_empty():
        return Vector2.ZERO
    var accum := Vector2.ZERO
    var count := 0
    for v in arr:
        if v is Vector2:
            accum += v
            count += 1
    if count == 0:
        return Vector2.ZERO
    return accum / float(count)

static func _serialize_vec2(v: Vector2) -> Dictionary:
    return {"x": v.x, "y": v.y}

static func _serialize_rect(r: Rect2) -> Dictionary:
    return {
        "position": _serialize_vec2(r.position),
        "size": _serialize_vec2(r.size)
    }
