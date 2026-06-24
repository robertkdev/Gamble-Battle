extends DragAndDroppable
class_name ItemCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")
const ItemTooltipScene := preload("res://scenes/ui/items/ItemTooltip.tscn")

const HOVER_DELAY: float = 0.10

var icon: TextureRect
var count_label: Label
var background: Panel
var patina: ColorRect

var slot_index: int = -1
var item_id: String = ""
var count: int = 0
var _hovered: bool = false
var _hover_token: int = 0
var _tooltip: Control = null
var _hover_tween: Tween = null

func _ready() -> void:
	super._ready()
	_ensure_children()
	_refresh()
	# Drag base config
	content_root_path = NodePath(".")
	drag_size = Vector2(48, 48)
	# Ensure the card occupies space in containers (e.g., GridContainer)
	custom_minimum_size = Vector2(48, 48)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	pivot_offset = custom_minimum_size * 0.5
	allowed_phases = [GameState.GamePhase.PREVIEW, GameState.GamePhase.COMBAT, GameState.GamePhase.POST_COMBAT]
	tooltip_text = ""
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)
	if not is_connected("gui_input", Callable(self, "_on_hover_gui_input")):
		gui_input.connect(_on_hover_gui_input)
	if not is_connected("began_drag", Callable(self, "_on_began_drag")):
		began_drag.connect(_on_began_drag)
	if not is_connected("ended_drag", Callable(self, "_on_ended_drag")):
		ended_drag.connect(_on_ended_drag)
	if not is_connected("resized", Callable(self, "_sync_pivot")):
		resized.connect(_sync_pivot)
	_sync_pivot()

func _can_drag_extra() -> bool:
	# Do not allow dragging when this is an empty placeholder slot
	return String(item_id) != ""

func _ensure_children() -> void:
	if background == null:
		background = Panel.new()
		background.name = "Background"
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 0.0
		background.offset_top = 0.0
		background.offset_right = 0.0
		background.offset_bottom = 0.0
		background.z_index = -1
		add_child(background)
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 1
		add_child(icon)
		icon.anchor_left = 0.0
		icon.anchor_top = 0.0
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = -4.0
		icon.offset_bottom = -4.0
	if patina == null:
		patina = ColorRect.new()
		patina.name = "Patina"
		patina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patina.set_anchors_preset(Control.PRESET_FULL_RECT)
		patina.offset_left = 2.0
		patina.offset_top = 2.0
		patina.offset_right = -2.0
		patina.offset_bottom = -2.0
		patina.z_index = 2
		patina.visible = false
		patina.color = Color(0.060, 0.026, 0.018, 0.30)
		add_child(patina)
	if count_label == null:
		count_label = Label.new()
		count_label.name = "Count"
		add_child(count_label)
		count_label.z_index = 3
		count_label.anchor_left = 1.0
		count_label.anchor_top = 1.0
		count_label.anchor_right = 1.0
		count_label.anchor_bottom = 1.0
		count_label.offset_left = -18
		count_label.offset_top = -18
		count_label.offset_right = 0
		count_label.offset_bottom = 0
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.modulate = Color(0.96, 0.74, 0.38, 0.98)
		count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		count_label.add_theme_constant_override("outline_size", 1)

func set_item_id(id: String) -> void:
	item_id = String(id)
	_refresh()

func set_slot_index(idx: int) -> void:
	slot_index = int(idx)

func get_slot_index() -> int:
	return slot_index

func set_count(n: int) -> void:
	count = int(n)
	_refresh()

func _refresh() -> void:
	_ensure_children()
	count_label.text = (str(count) if count > 1 else "")
	var def: ItemDef = ItemCatalog.get_def(item_id)
	if String(item_id) == "":
		# Empty placeholder slot: no icon, subtle tooltip
		icon.texture = null
		icon.visible = false
		tooltip_text = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_apply_card_style(false)
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if def != null:
		var tex: Texture2D = null
		if String(def.icon_path) != "":
			tex = load(def.icon_path)
		if tex == null:
			tex = TextureUtils.make_circle_texture(Color(0.6, 0.7, 0.9), 48)
		icon.texture = tex
		icon.visible = true
	else:
		icon.texture = TextureUtils.make_circle_texture(Color(0.5, 0.5, 0.5), 48)
		icon.visible = true
	_apply_card_style(true)
	tooltip_text = ""

func _apply_card_style(filled: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var hover_filled: bool = _hovered and filled
	var hover_empty: bool = _hovered and not filled
	style.bg_color = Color(0.082, 0.052, 0.058, 0.99) if hover_filled else Color(0.044, 0.036, 0.044, 0.93) if filled else Color(0.032, 0.026, 0.034, 0.88) if hover_empty else Color(0.022, 0.019, 0.026, 0.78)
	style.border_color = Color(1.0, 0.76, 0.36, 1.0) if hover_filled else Color(0.50, 0.42, 0.38, 0.95) if hover_empty else Color(0.68, 0.47, 0.28, 0.92) if filled else Color(0.27, 0.24, 0.27, 0.78)
	var border_width: int = 2 if _hovered else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 12 if _hovered else 5
	style.shadow_color = Color(0.62, 0.19, 0.060, 0.36) if _hovered else Color(0.0, 0.0, 0.0, 0.40)
	if background != null:
		background.add_theme_stylebox_override("panel", style)
	if icon != null:
		icon.modulate = Color(1.0, 0.88, 0.66, 1.0) if hover_filled else Color(0.90, 0.78, 0.62, 0.98) if filled else Color(1.0, 1.0, 1.0, 0.0)
	if patina != null:
		patina.visible = filled
		patina.color = Color(0.12, 0.04, 0.024, 0.20) if hover_filled else Color(0.060, 0.026, 0.018, 0.30)
	if count_label != null:
		count_label.modulate = Color(1.0, 0.84, 0.42, 1.0) if _hovered else Color(0.96, 0.74, 0.38, 0.98)

func _on_mouse_entered() -> void:
	_hovered = true
	_hover_token += 1
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(true, item_id.strip_edges() != "")
	var token: int = _hover_token
	await get_tree().create_timer(HOVER_DELAY).timeout
	if not _hovered or token != _hover_token:
		return
	_show_tooltip()

func _on_mouse_exited() -> void:
	_hovered = false
	_hover_token += 1
	_clear_tooltip()
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(false, item_id.strip_edges() != "")

func _on_hover_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _tooltip != null and is_instance_valid(_tooltip):
		var viewport: Viewport = get_viewport()
		if viewport != null and _tooltip.has_method("move_to"):
			_tooltip.call("move_to", viewport.get_mouse_position())

func _on_began_drag() -> void:
	_hovered = false
	_hover_token += 1
	_clear_tooltip()
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(false, item_id.strip_edges() != "")

func _on_ended_drag() -> void:
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(_hovered, item_id.strip_edges() != "")

func _show_tooltip() -> void:
	_clear_tooltip()
	var tooltip: Control = ItemTooltipScene.instantiate() as Control
	if tooltip == null:
		return
	tooltip.top_level = true
	get_tree().root.add_child(tooltip)
	if tooltip.has_method("set_item_id"):
		tooltip.call("set_item_id", item_id)
	var viewport: Viewport = get_viewport()
	var viewport_position: Vector2 = viewport.get_mouse_position() if viewport != null else get_global_rect().end
	if tooltip.has_method("show_at"):
		tooltip.call("show_at", viewport_position)
	_tooltip = tooltip

func _clear_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null

func _apply_hover_motion(active: bool, filled: bool) -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	var target_scale: Vector2 = Vector2.ONE
	if active:
		target_scale = Vector2(1.075, 1.075) if filled else Vector2(1.025, 1.025)
		z_index = 60
	else:
		z_index = 0
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, 0.09)

func _sync_pivot() -> void:
	pivot_offset = size * 0.5 if size != Vector2.ZERO else custom_minimum_size * 0.5
