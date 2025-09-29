extends RefCounted
class_name TraitsPresenter

const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")

var view: Control
var manager

var _overlay: Control = null
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null

const WIDTH := 56
const PADDING_X := 8
const SPACING := 6

func configure(_view: Control, _manager) -> void:
	view = _view
	manager = _manager

func initialize() -> void:
	_ensure_overlay()
	_connect_signals()
	rebuild()

func _connect_signals() -> void:
	if view and not view.is_connected("resized", Callable(self, "_on_view_resized")):
		view.resized.connect(_on_view_resized)
	if manager and not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
		manager.team_stats_updated.connect(_on_team_stats_updated)

func _on_team_stats_updated(_pteam, _eteam) -> void:
	rebuild()

func _on_view_resized() -> void:
	_update_layout()

func _ensure_overlay() -> void:
	# Find prebuilt panel in scene instead of constructing via code
	if _overlay and is_instance_valid(_overlay):
		return
	if view == null:
		return
	# Look for instance added to CombatView at: BattleArea/TraitsPanel
	var panel: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TraitsPanel")
	if panel == null:
		return
	_overlay = panel
	# Locate ScrollContainer and VBox inside the panel by name
	_scroll = panel.get_node_or_null("TraitsScroll")
	if _scroll == null:
		# fallback: first ScrollContainer child
		for c in panel.get_children():
			if c is ScrollContainer:
				_scroll = c
				break
	if _scroll:
		_vbox = _scroll.get_node_or_null("TraitsVBox")
		if _vbox == null:
			# fallback: first VBoxContainer inside the scroll
			for c2 in _scroll.get_children():
				if c2 is VBoxContainer:
					_vbox = c2
					break
	# Ensure spacing default if found
	if _vbox:
		_vbox.add_theme_constant_override("spacing", SPACING)

func rebuild() -> void:
	if _overlay == null:
		_ensure_overlay()
	if _overlay == null:
		return
	# Clear existing
	if _vbox:
		for c in _vbox.get_children():
			c.queue_free()

	var team: Array = []
	if manager and manager.has_method("get"): # loose guard; not used
		pass
	# Pull on-board team only
	var board_team: Array = (manager.player_team if manager else [])
	var compiled: Dictionary = {}
	if TraitCompiler and board_team is Array:
		compiled = TraitCompiler.compile(board_team)
	var counts: Dictionary = compiled.get("counts", {})
	var tiers: Dictionary = compiled.get("tiers", {})

	# Build visible list: traits on board only (count > 0)
	var ids: Array[String] = []
	for k in counts.keys():
		var c := int(counts[k])
		if c > 0:
			ids.append(String(k))

	# Partition active vs inactive
	var active: Array[String] = []
	var inactive: Array[String] = []
	for id in ids:
		var tier := int(tiers.get(id, -1))
		if tier >= 0:
			active.append(id)
		else:
			inactive.append(id)

	# Sort each block: count desc, then name A–Z
	var _by_count_then_name := func(a: String, b: String) -> bool:
		var ca := int(counts.get(a, 0))
		var cb := int(counts.get(b, 0))
		if ca == cb:
			return String(a) < String(b)
		return ca > cb
	active.sort_custom(_by_count_then_name)
	inactive.sort_custom(_by_count_then_name)

	var ordered: Array[String] = []
	for x in active: ordered.append(x)
	for y in inactive: ordered.append(y)

	# Create icons (icons only; highlight active)
	for id in ordered:
		var icon = TraitIconScene.instantiate()
		if icon == null:
			continue
		if icon.has_method("set_trait"):
			icon.call("set_trait", id)
		if icon.has_method("set_active"):
			icon.call("set_active", active.has(id))
		_vbox.add_child(icon)

	_update_layout()

func _item_grid() -> Control:
	if view == null:
		return null
	return view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")

func _update_layout() -> void:
	if _overlay == null or _scroll == null:
		return
	# With prebuilt panel, respect authored position/size; just ensure visibility
	_scroll.visible = true
	if _vbox:
		_vbox.custom_minimum_size.x = WIDTH
