extends Panel
class_name TraitTooltip

@onready var _name_label: Label = $VBox/Name
@onready var _threshold_label: Label = $VBox/Thresholds
@onready var _description_label: Label = $VBox/Description
@onready var _vbox: VBoxContainer = $VBox

const PADDING := 8

var trait_id: String = ""

func _ready() -> void:
	top_level = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_labels()

func set_trait(id: String) -> void:
	trait_id = String(id)
	_update_labels()

func show_at(viewport_pos: Vector2) -> void:
	await get_tree().process_frame
	var measured_size := _compute_desired_size()
	size = measured_size
	var offset := -Vector2(0, measured_size.y)
	global_position = viewport_pos + offset
	_clamp_to_viewport()

func _update_labels() -> void:
	var def: TraitDef = _load_trait_def(trait_id)
	var title := trait_id
	if def and String(def.name).strip_edges() != "":
		title = String(def.name)
	if _name_label:
		_name_label.text = title
	var thresholds_text := _format_thresholds(def)
	if _threshold_label:
		_threshold_label.text = thresholds_text
		_threshold_label.visible = thresholds_text != ""
	var description := ""
	if def and def.description != null:
		description = String(def.description)
	if _description_label:
		_description_label.text = description
		_description_label.visible = description.strip_edges() != ""
	size = _compute_desired_size()
	queue_redraw()

func _compute_desired_size() -> Vector2:
	var content_size := Vector2.ZERO
	if _vbox:
		# Combined minimum includes children and container rules
		content_size = _vbox.get_combined_minimum_size()
	# Add padding on all sides and respect custom_minimum_size.x
	var desired := content_size + Vector2(PADDING * 2, PADDING * 2)
	desired.x = max(desired.x, custom_minimum_size.x)
	return desired

func _format_thresholds(def: TraitDef) -> String:
	# Godot 4 does not have Object.has_property(); TraitDef always defines
	# an exported Array[int] `thresholds`, so access it directly and guard nulls.
	var values: Array = []
	if def != null:
		var arr = def.thresholds
		if arr != null and arr.size() > 0:
			for v in arr:
				values.append(int(v))
	var parts := PackedStringArray()
	for v in values:
		parts.append(str(v))
	if parts.size() == 0:
		return ""
	return "Thresholds: %s" % ", ".join(parts)

func _load_trait_def(id: String) -> TraitDef:
	var key := String(id).strip_edges()
	if key == "":
		return null
	var path := "res://data/traits/%s.tres" % key
	if ResourceLoader.exists(path):
		return load(path) as TraitDef
	return null

func _clamp_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var measured_size := size
	if measured_size == Vector2.ZERO:
		measured_size = get_minimum_size()
	var rect := Rect2(global_position, measured_size)
	var viewport_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	var new_pos := rect.position
	if rect.end.x > viewport_rect.size.x:
		new_pos.x = viewport_rect.size.x - rect.size.x
	if new_pos.x < 0:
		new_pos.x = 0
	if rect.position.y < 0:
		new_pos.y = 0
	elif rect.end.y > viewport_rect.size.y:
		new_pos.y = viewport_rect.size.y - rect.size.y
	global_position = new_pos
