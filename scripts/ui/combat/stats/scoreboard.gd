extends Control
class_name Scoreboard

const ScoreboardModelLib := preload("res://scripts/ui/combat/stats/scoreboard_model.gd")
const ScoreboardRow := preload("res://scripts/ui/combat/stats/scoreboard_row.gd")
const TooltipSvc := preload("res://scripts/ui/combat/stats/tooltip_service.gd")

@onready var expand_button: Button = $"Header/ExpandButton"
@onready var body_box: HBoxContainer = $"Body"
@onready var player_col: VBoxContainer = $"Body/PlayerColumn"
@onready var enemy_col: VBoxContainer = $"Body/EnemyColumn" # kept for non-overlay mode (currently unused)

# Floating overlay to show enemy column without reflowing the main layout
var overlay: Control
var overlay_enemy_col: VBoxContainer
var overlay_width: int = 320

var tracker: StatsTracker
var model: ScoreboardModel

var metric: String = "damage"
var window: String = "ALL"
var norm_mode: int = ScoreboardModel.NormMode.TEAM_SHARE
var expanded: bool = false

var refresh_interval: float = 0.3
var _accum: float = 0.0

func _ready() -> void:
	set_process(true)
	if expand_button and not expand_button.is_connected("pressed", Callable(self, "_on_toggle_expand")):
		expand_button.pressed.connect(_on_toggle_expand)
	_build_overlay()
	# Ensure in-panel enemy column never forces layout
	if enemy_col:
		enemy_col.visible = false

func configure(_tracker: StatsTracker) -> void:
	tracker = _tracker
	model = ScoreboardModelLib.new()
	model.configure(tracker)
	_rebuild_now()

func set_metric(m: String) -> void: metric = m
func set_window(w: String) -> void: window = w
func set_norm_mode(n: int) -> void: norm_mode = n
func set_expanded(flag: bool) -> void:
	expanded = flag
	if overlay:
		overlay.visible = expanded
		_layout_overlay()
	# Keep embedded enemy column hidden to avoid container expansion
	if enemy_col:
		enemy_col.visible = false
	if expand_button:
		expand_button.text = ("<<" if expanded else ">>")

func _on_toggle_expand() -> void:
	set_expanded(not expanded)

func _process(delta: float) -> void:
	_accum += max(0.0, float(delta))
	if _accum >= refresh_interval:
		_accum = 0.0
		_rebuild_now()
		if overlay and overlay.visible:
			_layout_overlay()

func _rebuild_now() -> void:
	if tracker == null:
		return
	var data: Dictionary = model.build(metric, window, norm_mode)
	_apply_rows(player_col, data.get("player_rows", []), float(data.get("player_total", 0.0)))
	var enemy_target: VBoxContainer = (overlay_enemy_col if expanded and overlay_enemy_col != null else enemy_col)
	_apply_rows(enemy_target, data.get("enemy_rows", []), float(data.get("enemy_total", 0.0)))

func _apply_rows(col: VBoxContainer, rows: Array, team_total: float) -> void:
	if col == null:
		return
	# Map existing by key
	var existing: Dictionary = {}
	for child in col.get_children():
		if child is ScoreboardRow:
			var key: String = _key(child.team, child.index)
			existing[key] = child
	# Build desired order; create missing
	var desired: Array[ScoreboardRow] = []
	for r in rows:
		var key2: String = _key(String(r.get("team")), int(r.get("index", -1)))
		var row_node: ScoreboardRow = existing.get(key2)
		if row_node == null:
			row_node = load("res://scenes/ui/stats/ScoreboardRow.tscn").instantiate()
			col.add_child(row_node)
		row_node.set_row_data(r)
		# Tooltip using window + team_total context
		var uname := ""
		var u: Unit = r.get("unit")
		if u != null:
			uname = String(u.name)
		var tip := TooltipSvc.row_tooltip(metric, window, float(r.get("value", 0.0)), float(r.get("share", 0.0)), uname, team_total)
		if metric == "damage" and tracker != null:
			var br := tracker.damage_breakdown(String(r.get("team")), int(r.get("index", -1)))
			if br != null and not br.is_empty():
				tip = TooltipSvc.row_tooltip(metric, window, float(r.get("value", 0.0)), float(r.get("share", 0.0)), uname, team_total, br)
		row_node.tooltip_text = tip
		desired.append(row_node)
	# Remove extras
	for child in col.get_children():
		if child is ScoreboardRow and not desired.has(child):
			child.queue_free()
	# Enforce order with a small tween hint
	for i in range(desired.size()):
		var node: Node = desired[i]
		if node.get_index() != i:
			node.owner = get_tree().edited_scene_root
			col.move_child(node, i)
			if node is ScoreboardRow:
				node.tween_reorder_hint()

func _key(team: String, index: int) -> String:
	return "%s#%d" % [String(team), int(index)]

# --- Overlay helpers ---

func _build_overlay() -> void:
	if overlay != null:
		return
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.top_level = true
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)
	# Container inside overlay
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.clip_contents = true
	overlay_enemy_col = VBoxContainer.new()
	overlay_enemy_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(overlay_enemy_col)

func _layout_overlay() -> void:
	if overlay == null:
		return
	# Desired rect: match Body rows area and extend left
	var area_rect := (body_box.get_global_rect() if body_box != null else get_global_rect())
	var pc_rect := (player_col.get_global_rect() if player_col != null else Rect2())
	var w: float = pc_rect.size.x
	if w <= 0.0:
		w = float(overlay_width)
	overlay.position = Vector2(area_rect.position.x - w, area_rect.position.y)
	overlay.size = Vector2(w, area_rect.size.y)
