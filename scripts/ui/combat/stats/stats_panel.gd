extends Control

const Scoreboard := preload("res://scripts/ui/combat/stats/scoreboard.gd")
const UnitPanel := preload("res://scripts/ui/combat/stats/unit_panel.gd")
const MetricTabs := preload("res://scripts/ui/combat/stats/metric_tabs.gd")

enum Mode { TEAM, UNIT }

var mode: int = Mode.TEAM
var manager: CombatManager = null
var _tracker: StatsTracker = null

@onready var title_label: Label = $"VBox/Header/Title"
@onready var btn_all: Button = $"VBox/Header/WindowAll"
@onready var btn_3s: Button = $"VBox/Header/Window3s"
@onready var metric_tabs: MetricTabs = $"VBox/MetricTabs"
@onready var scoreboard: Scoreboard = $"VBox/Body/Scoreboard"
@onready var unit_panel: UnitPanel = $"VBox/Body/UnitPanel"

var _unit_team: String = "player"
var _unit_index: int = -1

func _ready() -> void:
    set_process(false)
    # Wire header window buttons
    if btn_all and not btn_all.is_connected("pressed", Callable(self, "_on_window_all")):
        btn_all.pressed.connect(_on_window_all)
    if btn_3s and not btn_3s.is_connected("pressed", Callable(self, "_on_window_3s")):
        btn_3s.pressed.connect(_on_window_3s)
    # Metric tabs: MVP metrics list
    if metric_tabs:
        metric_tabs.set_metrics_for_category("damage", [
            {"key": "damage", "label": "Damage"},
            {"key": "dps", "label": "DPS"},
            {"key": "casts", "label": "Casts"},
        ])
        metric_tabs.set_metrics_for_category("tanking", [
            {"key": "taken", "label": "Taken"},
            {"key": "absorbed", "label": "Shield"},
            {"key": "mitigated", "label": "Mitigated"},
        ])
        metric_tabs.set_metrics_for_category("sustain", [
            {"key": "healing", "label": "Healing"},
            {"key": "overheal", "label": "Overheal"},
            {"key": "hps", "label": "HPS"},
        ])
        metric_tabs.set_category("damage")
        if not metric_tabs.is_connected("metric_changed", Callable(self, "_on_metric_changed")):
            metric_tabs.metric_changed.connect(_on_metric_changed)
    # Defaults
    show_team_metrics()
    set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
    if mode != Mode.UNIT:
        return
    if not (event is InputEventMouseButton):
        return
    var mb := event as InputEventMouseButton
    if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
        return
    # If click is outside the unit panel rect, revert to team view
    if unit_panel and unit_panel.visible:
        var r := unit_panel.get_global_rect()
        var mp := get_viewport().get_mouse_position()
        if not r.has_point(mp):
            show_team_metrics()

func configure(_parent: Control, _manager: CombatManager) -> void:
    manager = _manager
    if manager != null:
        if not manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
            manager.stats_updated.connect(_on_stats_updated)
        if not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
            manager.team_stats_updated.connect(_on_team_stats_updated)

func set_tracker(t: StatsTracker) -> void:
    _tracker = t
    if scoreboard and _tracker:
        scoreboard.configure(_tracker)
    if unit_panel and _tracker:
        unit_panel.configure(_tracker)

func set_ability_system(_abilities) -> void:
    # Placeholder for future use
    pass

func show_team_metrics() -> void:
    mode = Mode.TEAM
    if title_label:
        title_label.text = "Team Metrics"
    if scoreboard:
        scoreboard.visible = true
    if unit_panel:
        unit_panel.visible = false

func show_unit_metrics_ctx(team: String, index: int, u: Unit) -> void:
    _unit_team = String(team)
    _unit_index = int(index)
    if unit_panel:
        unit_panel.set_target(_unit_team, _unit_index, u)
    show_unit_metrics(u)

func show_unit_metrics(u: Unit) -> void:
    mode = Mode.UNIT
    if title_label:
        title_label.text = "Unit Metrics"
    if unit_panel:
        unit_panel.set_unit(u)
        unit_panel.visible = true
    if scoreboard:
        scoreboard.visible = false

func _on_window_all() -> void:
    if btn_all: btn_all.button_pressed = true
    if btn_3s: btn_3s.button_pressed = false
    if scoreboard:
        scoreboard.set_window("ALL")

func _on_window_3s() -> void:
    if btn_all: btn_all.button_pressed = false
    if btn_3s: btn_3s.button_pressed = true
    if scoreboard:
        scoreboard.set_window("3S")

func _on_metric_changed(key: String) -> void:
    if scoreboard:
        scoreboard.set_metric(key)

func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
    # No-op for now; UI pulls from tracker periodically
    pass

func _on_team_stats_updated(_pteam, _eteam) -> void:
    # No-op for now
    pass
