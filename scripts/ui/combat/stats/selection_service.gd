extends RefCounted
class_name SelectionService

signal unit_selected(unit)

var _unit: Unit = null
var _team: String = ""
var _index: int = -1

func select(team: String, index: int, u: Unit) -> void:
    _team = String(team)
    _index = int(index)
    _unit = u
    unit_selected.emit(_unit)

func clear() -> void:
    _team = ""
    _index = -1
    _unit = null
    unit_selected.emit(null)

func get_selected_unit() -> Unit:
    return _unit

func get_selected_team() -> String:
    return _team

func get_selected_index() -> int:
    return _index

# Attach selection to a UnitView (grid tile). Reuses UnitView's gui_input.
func attach_to_unit_view(view: Control, team: String, index: int, unit_provider: Callable = Callable()) -> void:
    if view == null:
        return
    if not view.is_connected("gui_input", Callable(self, "_on_view_gui_input")):
        view.gui_input.connect(_on_view_gui_input.bind(view, String(team), int(index), unit_provider))

# Attach selection to a UnitActor (arena). Adds a lightweight hitbox overlay so clicks don't interfere with actors.
func attach_to_unit_actor(actor: Control, team: String, index: int, unit_provider: Callable = Callable()) -> void:
    if actor == null:
        return
    var hit := actor.get_node_or_null("SelectHit")
    if hit == null:
        hit = ColorRect.new()
        hit.name = "SelectHit"
        actor.add_child(hit)
    elif not (hit is ColorRect):
        var replacement := ColorRect.new()
        replacement.name = "SelectHit"
        actor.add_child(replacement)
        hit.queue_free()
        hit = replacement
    var hit_control := hit as Control
    if hit_control == null:
        return
    hit_control.anchor_left = 0.0
    hit_control.anchor_top = 0.0
    hit_control.anchor_right = 1.0
    hit_control.anchor_bottom = 1.0
    hit_control.offset_left = 0.0
    hit_control.offset_top = 0.0
    hit_control.offset_right = 0.0
    hit_control.offset_bottom = 0.0
    hit_control.mouse_filter = Control.MOUSE_FILTER_STOP
    hit_control.z_index = 0
    if hit_control is ColorRect:
        var rect := hit_control as ColorRect
        rect.color = Color(1.0, 0.0, 0.0, 0.25)
        rect.show_behind_parent = false
    if not hit_control.is_connected("gui_input", Callable(self, "_on_view_gui_input")):
        hit_control.gui_input.connect(_on_view_gui_input.bind(actor, String(team), int(index), unit_provider))

# Clicking on this control clears the selection.
func attach_clear_on(control: Control) -> void:
    if control == null:
        return
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    if not control.is_connected("gui_input", Callable(self, "_on_clear_gui_input")):
        control.gui_input.connect(_on_clear_gui_input)

func _on_view_gui_input(event: InputEvent, _src: Control, team: String, index: int, unit_provider: Callable) -> void:
    if not (event is InputEventMouseButton):
        return
    var mb := event as InputEventMouseButton
    if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
        return
    var u: Unit = null
    if unit_provider.is_valid():
        u = unit_provider.call()
    # Fallback: try to discover from manager grids (caller may bind provider)
    select(team, index, u)

func _on_clear_gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var mb := event as InputEventMouseButton
    if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
        return
    clear()

