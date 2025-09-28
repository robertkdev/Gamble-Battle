extends RefCounted
class_name CombineService

const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")

var _roster

func configure(roster) -> void:
    _roster = roster

func combine() -> Array:
    # Scan bench slots for three-of-a-kind (same id and same level).
    # Promote one copy by +1 level (max 3), remove two others. Repeat while possible.
    var results: Array = []
    var bench_count: int = _bench_size()
    if bench_count <= 0:
        return results
    # Build initial groups
    var groups := _build_groups()
    var changed := true
    while changed:
        changed = false
        var match_key := _find_group_with_at_least(groups, 3)
        if match_key == "":
            break
        var arr: Array = groups[match_key]
        arr.sort()
        var keep_idx: int = int(arr[0])
        var eat1: int = int(arr[1])
        var eat2: int = int(arr[2])
        # Extract id and level
        var parts := match_key.split("#")
        var id: String = String(parts[0])
        var level: int = int(parts[1])
        if level >= 3:
            # No promotion beyond 3-star; drop this group to avoid infinite loop
            groups.erase(match_key)
            continue
        # Promote kept unit in place
        var u: Unit = _roster.get_slot(keep_idx)
        if u == null or String(u.id) != id or int(u.level) != level:
            # Rebuild groups and continue if stale
            groups = _build_groups()
            continue
        _promote_one_level(u)
        _roster.set_slot(keep_idx, u)
        # Remove the two others
        _roster.set_slot(eat1, null)
        _roster.set_slot(eat2, null)
        results.append({
            "id": id,
            "from_level": level,
            "to_level": int(u.level),
            "kept_slot": keep_idx,
            "consumed": [eat1, eat2],
        })
        # Rebuild groups after mutation and loop again (chained promotions allowed)
        groups = _build_groups()
        changed = true
    return results

func _bench_size() -> int:
    if _roster != null and _roster.has_method("slot_count"):
        return int(_roster.slot_count())
    elif Engine.has_singleton("Roster"):
        return int(Roster.slot_count())
    return 0

func _build_groups() -> Dictionary:
    var groups: Dictionary = {}
    var n := _bench_size()
    for i in range(n):
        var u: Unit = _roster.get_slot(i) if _roster != null else (Roster.get_slot(i) if Engine.has_singleton("Roster") else null)
        if u == null:
            continue
        var id := String(u.id)
        var lv := int(u.level)
        if id == "":
            continue
        var key := id + "#" + str(lv)
        if not groups.has(key):
            groups[key] = []
        groups[key].append(i)
    return groups

func _find_group_with_at_least(groups: Dictionary, n: int) -> String:
    for k in groups.keys():
        var arr: Array = groups[k]
        if arr.size() >= int(n):
            return String(k)
    return ""

func _promote_one_level(u: Unit) -> void:
    # Increase unit.level by 1 (max 3) and apply multiplicative step to scaled stats.
    if u == null:
        return
    var steps := 1
    var keys := [
        "max_hp",
        "hp_regen",
        "attack_damage",
        "spell_power",
        "lifesteal",
        "armor",
        "magic_resist",
        "true_damage",
    ]
    for _i in range(steps):
        for k in keys:
            var curv: float = float(u.get(k))
            curv *= 1.5
            match k:
                "max_hp":
                    u.max_hp = max(1, int(curv))
                "hp_regen":
                    u.hp_regen = max(0.0, curv)
                "attack_damage":
                    u.attack_damage = max(0.0, curv)
                "spell_power":
                    u.spell_power = max(0.0, curv)
                "lifesteal":
                    u.lifesteal = clampf(curv, 0.0, 0.9)
                "armor":
                    u.armor = max(0.0, curv)
                "magic_resist":
                    u.magic_resist = max(0.0, curv)
                "true_damage":
                    u.true_damage = max(0.0, curv)
    u.level = min(3, int(u.level) + 1)
    # Heal to full after promotion
    u.hp = u.max_hp

