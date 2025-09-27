extends RefCounted
class_name HealingService

const Health := preload("res://scripts/game/stats/health.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const BATTLE_LONG := 9999.0

static func _unit_at(state: BattleState, team: String, idx: int) -> Unit:
    if state == null:
        return null
    var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
    if idx < 0 or idx >= arr.size():
        return null
    return arr[idx]

static func _mods(buff_system, state: BattleState, team: String, index: int) -> Dictionary:
    var mods := {
        "healing_received_pct": 0.0,
        "overheal_to_shield_pct": 0.0,
        "shield_strength_pct": 0.0,
    }
    if buff_system == null or state == null:
        return mods
    if buff_system.has_tag(state, team, index, BuffTags.TAG_HEALING_MODS):
        var data: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_HEALING_MODS)
        if data != null and not data.is_empty():
            mods.healing_received_pct = float(data.get("healing_received_pct", 0.0))
            mods.overheal_to_shield_pct = float(data.get("overheal_to_shield_pct", 0.0))
            mods.shield_strength_pct = float(data.get("shield_strength_pct", 0.0))
    return mods

# Applies a heal with trait-aware modifiers and converts overheal to shields if configured.
# Returns { processed: bool, healed: int, overheal: int, shield: int, before_hp: int, after_hp: int }
static func apply_heal(state: BattleState, buff_system, team: String, index: int, base_amount: float) -> Dictionary:
    var result := {"processed": false, "healed": 0, "overheal": 0, "shield": 0}
    var u: Unit = _unit_at(state, team, index)
    if u == null or base_amount <= 0.0:
        return result
    var mods: Dictionary = _mods(buff_system, state, team, index)
    var amp: float = 1.0 + float(mods.get("healing_received_pct", 0.0))
    var amount_f: float = max(0.0, float(base_amount) * max(0.0, amp))
    var before: int = int(u.hp)
    var h = Health.heal_and_overheal(u, int(round(amount_f)))
    var healed: int = int(h.get("healed", 0))
    var overheal: int = int(h.get("overheal", 0))
    result.processed = true
    result.healed = healed
    result.overheal = max(0, overheal)
    result.before_hp = before
    result.after_hp = int(u.hp)
    # Convert overheal to a shield based on configured pct
    if result.overheal > 0 and buff_system != null:
        var o2s_pct: float = float(mods.get("overheal_to_shield_pct", 0.0))
        if o2s_pct > 0.0:
            var to_shield: int = int(floor(float(result.overheal) * o2s_pct))
            if to_shield > 0:
                var sres: Dictionary = buff_system.apply_shield(state, team, index, to_shield, BATTLE_LONG)
                if bool(sres.get("processed", false)):
                    result.shield = int(sres.get("shield", to_shield))
    return result

