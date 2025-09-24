extends RefCounted
class_name PostHitCoordinator

# PostHitCoordinator
# Centralizes post-impact effects: totals/frame increments, mana gain, stat emits, analytics payload, and frame flags.

const TeamUtils := preload("res://scripts/game/combat/attack/support/team_utils.gd")

var state: BattleState
var events: CombatEvents
var stats: CombatStats
var mana_service: ManaOnAttack
var cd_service: CDService
var frame_calc: FrameStatusCalculator
var player_ref: Unit

func configure(_state: BattleState, _events: CombatEvents, _stats: CombatStats, _mana: ManaOnAttack, _cd: CDService, _frame_calc: FrameStatusCalculator, _player_ref: Unit) -> void:
    state = _state
    events = _events
    stats = _stats
    mana_service = _mana
    cd_service = _cd
    frame_calc = _frame_calc
    player_ref = _player_ref

# Emits queued impact messages in order.
func emit_messages(messages) -> void:
    if events == null or messages == null:
        return
    if typeof(messages) != TYPE_ARRAY:
        return
    for msg in messages:
        events.log_line(String(msg))

# Applies post-hit side effects and emits analytics+stats.
# Returns frame flags: { player_team_defeated: bool, enemy_team_defeated: bool }
func apply(source_team: String, source_index: int, target_team: String, target_index: int, rolled_damage: int, dealt: int, crit: bool, before_hp: int, after_hp: int) -> Dictionary:
    if state == null or events == null or stats == null:
        return {"player_team_defeated": false, "enemy_team_defeated": false}

    # Totals/frame damage
    stats.add_dealt(source_team, dealt)

    # Mana gain on attack (handles tag-based blocking and optional autocast)
    var src: Unit = TeamUtils.unit_at(state, source_team, source_index)
    mana_service.gain(source_team, source_index, src)

    # Unit stat emits (HP/Mana for shooter; HP for target)
    var tgt: Unit = TeamUtils.unit_at(state, target_team, target_index)
    if src != null:
        events.unit_stat_changed(source_team, source_index, {"hp": src.hp, "mana": src.mana})
    if tgt != null:
        events.unit_stat_changed(target_team, target_index, {"hp": tgt.hp})

    # Stats snapshots (UI/analytics)
    events.stats_snapshot(player_ref, state)
    events.team_stats(state)

    # CD snapshots for analytics payload
    var player_cd_now: float = 0.0
    var enemy_cd_now: float = 0.0
    if source_team == "player":
        player_cd_now = cd_service.cd_safe("player", source_index)
        enemy_cd_now = cd_service.cd_safe("enemy", target_index)
        events.hit_applied("player", source_index, target_index, rolled_damage, dealt, crit, before_hp, after_hp, player_cd_now, enemy_cd_now)
    else:
        player_cd_now = cd_service.cd_safe("player", target_index)
        enemy_cd_now = cd_service.cd_safe("enemy", source_index)
        events.hit_applied("enemy", source_index, target_index, rolled_damage, dealt, crit, before_hp, after_hp, player_cd_now, enemy_cd_now)

    # Frame outcome flags
    var flags = frame_calc.update_after_hit(state, cd_service, source_team)
    return flags
