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
    _configure_input_routing()
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

func _exit_tree() -> void:
    teardown()

func teardown() -> void:
    set_process(false)
    set_process_unhandled_input(false)
    if manager != null and is_instance_valid(manager):
        if manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
            manager.stats_updated.disconnect(_on_stats_updated)
        if manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
            manager.team_stats_updated.disconnect(_on_team_stats_updated)
    if btn_all != null and is_instance_valid(btn_all) and btn_all.is_connected("pressed", Callable(self, "_on_window_all")):
        btn_all.pressed.disconnect(_on_window_all)
    if btn_3s != null and is_instance_valid(btn_3s) and btn_3s.is_connected("pressed", Callable(self, "_on_window_3s")):
        btn_3s.pressed.disconnect(_on_window_3s)
    if metric_tabs != null and is_instance_valid(metric_tabs) and metric_tabs.is_connected("metric_changed", Callable(self, "_on_metric_changed")):
        metric_tabs.metric_changed.disconnect(_on_metric_changed)
    reset_runtime()
    manager = null

func reset_runtime() -> void:
    mode = Mode.TEAM
    _unit_team = "player"
    _unit_index = -1
    _tracker = null
    if scoreboard != null and is_instance_valid(scoreboard) and scoreboard.has_method("teardown"):
        scoreboard.teardown()
    if unit_panel != null and is_instance_valid(unit_panel) and unit_panel.has_method("teardown"):
        unit_panel.teardown()

func _unhandled_input(event: InputEvent) -> void:
    if mode != Mode.UNIT:
        return
    if not (event is InputEventMouseButton):
        return
    var mb: InputEventMouseButton = event as InputEventMouseButton
    if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
        return
    # If click is outside the unit panel rect, revert to team view
    if unit_panel and unit_panel.visible:
        var r: Rect2 = unit_panel.get_global_rect()
        var mp: Vector2 = get_viewport().get_mouse_position()
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
        title_label.add_theme_color_override("font_color", Color(0.92, 0.68, 0.34, 1.0))
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
        title_label.text = "Enemy Unit" if _unit_team == "enemy" else "Player Unit"
        title_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.36, 1.0) if _unit_team == "enemy" else Color(0.92, 0.68, 0.34, 1.0))
    if unit_panel:
        unit_panel.set_unit(u)
        unit_panel.visible = true
    if scoreboard:
        scoreboard.visible = false

func _on_window_all() -> void:
    if mode == Mode.UNIT:
        show_team_metrics()
    if btn_all: btn_all.button_pressed = true
    if btn_3s: btn_3s.button_pressed = false
    if scoreboard:
        scoreboard.set_window("ALL")

func _on_window_3s() -> void:
    if mode == Mode.UNIT:
        show_team_metrics()
    if btn_all: btn_all.button_pressed = false
    if btn_3s: btn_3s.button_pressed = true
    if scoreboard:
        scoreboard.set_window("3S")

func _on_metric_changed(key: String) -> void:
    if mode == Mode.UNIT:
        show_team_metrics()
    if scoreboard:
        scoreboard.set_metric(key)

func _configure_input_routing() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    var shell_nodes: Array[Control] = [
        $"VBox" as Control,
        $"VBox/Header" as Control,
        $"VBox/Header/Spacer" as Control,
        $"VBox/Body" as Control,
    ]
    for shell: Control in shell_nodes:
        if shell != null:
            shell.mouse_filter = Control.MOUSE_FILTER_PASS
    var clickable_nodes: Array[Button] = [btn_all, btn_3s]
    for button: Button in clickable_nodes:
        if button != null:
            button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
    # No-op for now; UI pulls from tracker periodically
    pass

func _on_team_stats_updated(_pteam, _eteam) -> void:
    # No-op for now
    pass
