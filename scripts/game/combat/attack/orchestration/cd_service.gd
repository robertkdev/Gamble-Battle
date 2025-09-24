extends RefCounted
class_name CDService

# CDService
# Read-only helpers to query per-unit cooldowns from BattleState and compute snapshots.

var state: BattleState = null

func configure(_state: BattleState) -> void:
    state = _state

func other_cds(team: String) -> Array[float]:
    if state == null:
        return []
    return state.enemy_cds if team == "player" else state.player_cds

func cd_safe(team: String, index: int) -> float:
    if state == null:
        return 0.0
    var cds: Array[float] = state.player_cds if team == "player" else state.enemy_cds
    if index < 0 or index >= cds.size():
        return 0.0
    return float(cds[index])

func min_cd(cds: Array) -> float:
    if cds == null or cds.is_empty():
        return 9999.0
    var min_val: float = 9999.0
    for v in cds:
        var f: float = float(v)
        if f < min_val:
            min_val = f
    return min_val
