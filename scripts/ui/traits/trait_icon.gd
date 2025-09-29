extends Control
class_name TraitIcon

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitTooltipScene := preload("res://scenes/ui/traits/TraitTooltip.tscn")

const ICON_OVERRIDES := {
	"Catalyst": "res://assets/traits/catylist_symbol.png",
	"Executioner": "res://assets/traits/exocutioner_symbol.png",
	"Liaison": "res://assets/traits/liason_symbol.png",
}
const ICON_TEMPLATE := "res://assets/traits/%s_symbol.png"

@onready var _icon: TextureRect = $Texture

var trait_id: String = ""
var _tooltip: Control = null
var _active: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)
	_update_visuals()

func _exit_tree() -> void:
	_clear_tooltip()

func set_trait(id: String) -> void:
	trait_id = String(id)
	_update_visuals()

func clear_trait() -> void:
	trait_id = ""
	_update_visuals()

func _update_visuals() -> void:
	var path := _resolve_icon_path(trait_id)
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(Color(0.4, 0.4, 0.4, 0.4), 32)
	if _icon:
		_icon.texture = tex
	var has_trait := trait_id.strip_edges() != ""
	visible = has_trait
	if not has_trait:
		_clear_tooltip()
	_apply_active_bg()

func _resolve_icon_path(id: String) -> String:
	var key := String(id).strip_edges()
	if key == "":
		return ""
	if ICON_OVERRIDES.has(key):
		return ICON_OVERRIDES[key]
	var normalized := key.to_lower()
	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace("-", "_")
	normalized = normalized.replace("'", "")
	return ICON_TEMPLATE % normalized

func _on_mouse_entered() -> void:
	if trait_id.strip_edges() == "":
		return
	if not TraitTooltipScene:
		return
	_clear_tooltip()
	var tooltip := TraitTooltipScene.instantiate()
	if tooltip == null:
		return
	if tooltip is Control:
		(tooltip as Control).top_level = true
	var root := get_tree().root
	if root:
		root.add_child(tooltip)
	if tooltip.has_method("set_trait"):
		tooltip.call("set_trait", trait_id)
	var pos := get_viewport().get_mouse_position()
	if tooltip.has_method("show_at"):
		tooltip.call("show_at", pos)
	_tooltip = tooltip

func _on_mouse_exited() -> void:
	_clear_tooltip()

func _clear_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null

func set_active(v: bool) -> void:
	_active = bool(v)
	_apply_active_bg()

func _apply_active_bg() -> void:
	# Toggle the background ColorRect to indicate active trait
	var bg: ColorRect = get_node_or_null("ColorRect")
	if bg == null:
		return
	if _active:
		bg.color = Color(0.2, 0.45, 0.95, 0.85)
	else:
		# Neutral default similar to scene setup
		bg.color = Color(0.734726, 0.757418, 0.822632, 1)
