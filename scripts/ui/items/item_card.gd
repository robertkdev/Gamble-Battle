extends DragAndDroppable
class_name ItemCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")
const PhaseRules := preload("res://scripts/game/items/phase_rules.gd")

var icon: TextureRect
var count_label: Label

var slot_index: int = -1
var item_id: String = ""
var count: int = 0

func _ready() -> void:
	super._ready()
	_ensure_children()
	# Drag base config
	content_root_path = NodePath(".")
	drag_size = Vector2(48, 48)
	# Ensure the card occupies space in containers (e.g., GridContainer)
	custom_minimum_size = Vector2(48, 48)
	allowed_phases = [GameState.GamePhase.PREVIEW, GameState.GamePhase.COMBAT, GameState.GamePhase.POST_COMBAT]

func _can_drag_extra() -> bool:
	# Do not allow dragging when this is an empty placeholder slot
	return String(item_id) != ""

func _ensure_children() -> void:
	if icon == null:
		icon = TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		icon.anchor_left = 0.0
		icon.anchor_top = 0.0
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 0.0
		icon.offset_top = 0.0
		icon.offset_right = 0.0
		icon.offset_bottom = 0.0
	if count_label == null:
		count_label = Label.new()
		add_child(count_label)
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
		count_label.modulate = Color(1, 1, 1, 0.95)

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
	var tooltip := item_id
	if String(item_id) == "":
		# Empty placeholder slot: no icon, subtle tooltip
		icon.texture = null
		icon.visible = false
		self.tooltip_text = "Empty slot"
		return
	if def != null:
		tooltip = _format_tooltip(def)
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
	self.tooltip_text = tooltip

func _format_tooltip(def: ItemDef) -> String:
	var parts: Array[String] = []
	var title := (String(def.name) if String(def.name) != "" else String(def.id))
	parts.append(title)
	var mods: Dictionary = def.stat_mods if def.stat_mods != null else {}
	if not mods.is_empty():
		var mod_lines: Array[String] = []
		for k in mods.keys():
			var v = mods[k]
			var s := String(k) + ": " + ("%+d%%" % int(round(float(v) * 100.0)) if String(k).begins_with("pct_") else "%+d" % int(round(float(v))))
			mod_lines.append(s)
		mod_lines.sort()
		parts.append("\n" + "\n".join(mod_lines))
	# Phase gating hint for remover
	if String(def.id) == "remover" and not PhaseRules.can_remove():
		parts.append("\nCannot remove items during combat")
	return "\n".join(parts)
