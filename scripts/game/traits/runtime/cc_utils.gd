extends Object
class_name CCUtils

# Helpers for CC logic: duration scaling and first-CC triggers.

static func is_cc_tag(tag: String) -> bool:
    var lname: String = String(tag).to_lower()
    return lname == "root" or lname == "rooted" or lname == "stun"

static func scaled_duration(state: BattleState, team: String, index: int, base_duration: float) -> float:
    if state == null or base_duration <= 0.0:
        return max(0.0, base_duration)
    var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
    if index < 0 or index >= arr.size():
        return max(0.0, base_duration)
    var u: Unit = arr[index]
    if u == null:
        return max(0.0, base_duration)
    var ten: float = 0.0
    if u.has_method("get"):
        ten = max(0.0, min(0.95, float(u.get("tenacity"))))
    else:
        ten = max(0.0, min(0.95, float(u.tenacity)))
    return max(0.0, float(base_duration) * (1.0 - ten))

