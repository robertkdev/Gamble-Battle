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

func bonko_clone_count(state: BattleState, team: String, index: int) -> int:
    if buff_system == null or state == null:
        return 0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_BONKO):
        return 0
    return 1

func bonko_clone_damage_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.5
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_BONKO):
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_BONKO)
    return float(meta.get("pct", 0.5))

func unstable_pre_phys_bonus(state: BattleState, team: String, index: int, tgt_team: String, target_index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_BEREBELL):
        return 0.0
    var src: Unit = (state.player_team[index] if team == "player" and index >= 0 and index < state.player_team.size() else (state.enemy_team[index] if index >= 0 and index < state.enemy_team.size() else null))
    var tgt: Unit = (state.enemy_team[target_index] if team == "player" and target_index >= 0 and target_index < state.enemy_team.size() else (state.player_team[target_index] if target_index >= 0 and target_index < state.player_team.size() else null))
    if src == null or tgt == null or not tgt.is_alive():
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_BEREBELL)
    var pct: float = float(meta.get("missing_pct", 0.0))
    if pct <= 0.0:
        return 0.0
    var missing: int = max(0, int(tgt.max_hp) - int(tgt.hp))
    # Return bonus physical base damage to be mitigated with armor
    return float(missing) * pct

func exec_ignore_shields_on_crit(state: BattleState, team: String, index: int) -> bool:
    if buff_system == null or state == null:
        return false
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_EXEC_T8):
        return false
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_EXEC_T8)
    return bool(meta.get("ignore_shields_on_crit", false))

func exec_true_bonus_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_EXEC_T8):
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_EXEC_T8)
    return float(meta.get("true_bonus_pct", 0.0))

func damage_amp_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    # Prefer explicit damage amp tag
    if buff_system.has_tag(state, team, index, BuffTags.TAG_DAMAGE_AMP):
        var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_DAMAGE_AMP)
        return float(meta.get("damage_amp_pct", 0.0))
    # Fallback: reuse ability amp for attacks if present
    if buff_system.has_tag(state, team, index, BuffTags.TAG_ABILITY_AMP):
        var meta2: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_ABILITY_AMP)
        return float(meta2.get("ability_damage_amp", 0.0))
    return 0.0
