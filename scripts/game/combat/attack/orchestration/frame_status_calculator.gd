extends RefCounted
class_name FrameStatusCalculator

const TeamUtils := preload("res://scripts/game/combat/attack/support/team_utils.gd")

# FrameStatusCalculator
# Computes per-frame outcome flags based on latest hit and cooldown timing.
# Mirrors the legacy AttackResolver double-KO timing semantics.
func update_after_hit(state: BattleState, cd_service: CDService, source_team: String) -> Dictionary:
    var flags := {
        "player_team_defeated": false,
        "enemy_team_defeated": false,
    }
    if state == null or cd_service == null:
        return flags
    var target_team: String = TeamUtils.other_team(source_team)
    if not BattleState.all_dead(TeamUtils.unit_array(state, target_team)):
        return flags
    var min_cd: float = cd_service.min_cd(cd_service.other_cds(source_team))
    if min_cd <= 0.0001:
        flags.player_team_defeated = true
        flags.enemy_team_defeated = true
    elif source_team == "player":
        flags.enemy_team_defeated = true
    else:
        flags.player_team_defeated = true
    return flags
