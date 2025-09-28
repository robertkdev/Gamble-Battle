extends RefCounted
class_name ScoreboardModel

# Builds normalized, sorted scoreboard rows from a StatsTracker.
# Normalization modes:
#  - TEAM_SHARE: row share = value / team_total
#  - CROSS_TEAM_MAX: row share = value / max(value across both teams)

enum NormMode { TEAM_SHARE, CROSS_TEAM_MAX }

var tracker: StatsTracker = null

func configure(_tracker: StatsTracker) -> void:
    tracker = _tracker

func build(metric: String, window: String, norm_mode: int = NormMode.TEAM_SHARE) -> Dictionary:
    var out := {
        "player_rows": [],
        "enemy_rows": [],
        "player_total": 0.0,
        "enemy_total": 0.0,
        "norm_mode": norm_mode,
        "norm_max": 0.0,
    }
    if tracker == null:
        return out

    var p_rows: Array = tracker.get_rows("player", metric, window)
    var e_rows: Array = tracker.get_rows("enemy", metric, window)
    var p_total: float = tracker.get_team_total("player", metric, window)
    var e_total: float = tracker.get_team_total("enemy", metric, window)

    var cross_max: float = 0.0
    if norm_mode == NormMode.CROSS_TEAM_MAX:
        for r in p_rows:
            cross_max = max(cross_max, float(r.get("value", 0.0)))
        for r2 in e_rows:
            cross_max = max(cross_max, float(r2.get("value", 0.0)))
    out.norm_max = cross_max

    # Compute shares and decorate rows
    out.player_rows = _decorate_and_sort_rows(p_rows, p_total, cross_max, norm_mode)
    out.enemy_rows = _decorate_and_sort_rows(e_rows, e_total, cross_max, norm_mode)
    out.player_total = p_total
    out.enemy_total = e_total
    return out

func _decorate_and_sort_rows(rows: Array, team_total: float, cross_max: float, norm_mode: int) -> Array:
    var out: Array = []
    var denom_team: float = max(0.0, float(team_total))
    var denom_cross: float = max(0.0, float(cross_max))
    for r in rows:
        var v: float = max(0.0, float(r.get("value", 0.0)))
        var share: float = 0.0
        if norm_mode == NormMode.TEAM_SHARE:
            share = (v / denom_team) if denom_team > 0.0 else 0.0
        else:
            share = (v / denom_cross) if denom_cross > 0.0 else 0.0
        var row := {
            "team": r.get("team"),
            "index": int(r.get("index", -1)),
            "unit": r.get("unit"),
            "value": v,
            "share": share,                 # 0..1 for bar fill
            "share_pct": int(round(share * 100.0)),
        }
        out.append(row)
    # Sort descending by value; stable by index
    out.sort_custom(func(a, b):
        var av: float = float(a.value)
        var bv: float = float(b.value)
        return (av > bv) if av != bv else int(a.index) < int(b.index)
    )
    return out

