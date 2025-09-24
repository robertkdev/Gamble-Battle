extends BuffHooks
class_name BuffHooksTagsImpl

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

var buff_system: BuffSystem = null

func configure(_buff_system: BuffSystem) -> void:
    buff_system = _buff_system

func nyxa_extra_shots(state: BattleState, team: String, index: int) -> int:
    if buff_system == null or state == null:
        return 0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_NYXA):
        return 0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_NYXA)
    return int(meta.get("extra", 0))

func nyxa_per_shot_bonus(state: BattleState, team: String, index: int) -> int:
    if buff_system == null or state == null:
        return 0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_NYXA):
        return 0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_NYXA)
    return int(meta.get("damage_bonus", 0))

func korath_absorb_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_KORATH)
    return float(meta.get("pct", 0.0))

func korath_accumulate_pool(state: BattleState, team: String, index: int, amount: int) -> void:
    if buff_system == null or state == null or amount <= 0:
        return
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
        return
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_KORATH)
    meta["pool"] = int(meta.get("pool", 0)) + max(0, amount)
