extends RefCounted
class_name ShopPanel

const UI := preload("res://scripts/constants/ui_constants.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopCardScene := preload("res://scenes/ui/shop/ShopCard.tscn")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")
const EmptySigilTexture: Texture2D = preload("res://assets/ui/gold icon.png")

var _grid: GridContainer = null
var _slot_count: int = ShopConfig.SLOT_COUNT
var _host_container: Container = null
var _cards: Array = []
var _empty_label_text: String = "LEDGER"
var _empty_hint_text: String = "Reroll to reveal"
var _single_empty_state: bool = false

func configure(grid: GridContainer, slot_count: int = ShopConfig.SLOT_COUNT) -> void:
    _grid = grid
    _host_container = (_grid.get_parent() as Container) if _grid else null
    _slot_count = max(1, int(slot_count))
    if _grid and _grid.has_method("set"):
        _grid.columns = _slot_count
        _grid.custom_minimum_size = Vector2(max(_grid.custom_minimum_size.x, 790.0), 138.0)

func get_host_container() -> Container:
    return _host_container

func clear() -> void:
    if _grid != null and is_instance_valid(_grid):
        for c in _grid.get_children():
            if c is Node:
                _grid.remove_child(c)
                c.free()
    _cards.clear()
    _grid = null
    _host_container = null

func set_empty_state(label_text: String, hint_text: String = "", single_panel: bool = false) -> void:
    _empty_label_text = String(label_text).strip_edges()
    _empty_hint_text = String(hint_text).strip_edges()
    _single_empty_state = bool(single_panel)
    if _empty_label_text == "":
        _empty_label_text = "LEDGER"

func set_offers(offers: Array) -> void:
    if _grid == null:
        return
    for c in _grid.get_children():
        if c is Node:
            c.queue_free()
    _cards.clear()
    _grid.columns = 1 if _single_empty_state and offers.is_empty() else _slot_count

    var shown: int = 0
    var idx: int = 0
    for o in offers:
        var card: Control = _make_card(o, idx)
        _grid.add_child(card)
        _cards.append(card)
        if card is ShopCard:
            var props: Dictionary = {}
            if o is ShopOffer and String(o.id) != "":
                var off: ShopOffer = o
                var roles: Array = _duplicate_strings(off.roles)
                var traits: Array = _duplicate_strings(off.traits)
                var approaches: Array = _duplicate_strings(off.approaches)
                var alt_goals: Array = _duplicate_strings(off.alt_goals)
                var primary_role: String = String(off.primary_role)
                props = {
                    "id": String(off.id),
                    "name": String(off.name),
                    "price": int(off.cost),
                    "image_path": String(off.sprite_path),
                    "role": _role_text(roles, primary_role),
                    "roles": roles,
                    "traits": traits,
                    "primary_role": primary_role,
                    "primary_goal": String(off.primary_goal),
                    "approaches": approaches,
                    "alt_goals": alt_goals,
                    "identity_path": String(off.identity_path),
                }
            else:
                props = {
                    "id": "",
                    "name": "?",
                    "price": 0,
                    "image_path": "",
                    "role": "",
                    "roles": [],
                    "traits": [],
                    "primary_role": "",
                    "primary_goal": "",
                    "approaches": [],
                    "alt_goals": [],
                    "identity_path": "",
                }
            (card as ShopCard).call_deferred("set_data", props)
        shown += 1
        idx += 1

    if _single_empty_state and offers.is_empty():
        _grid.add_child(_make_empty())
        return

    while shown < _slot_count:
        _grid.add_child(_make_empty())
        shown += 1

func _make_card(offer, index: int) -> Control:
    if ShopCardScene:
        if offer is ShopOffer and String(offer.id) == "":
            return _make_sold()
        var card: Control = ShopCardScene.instantiate() as Control
        if card and card.has_method("set_slot_index"):
            card.set_slot_index(index)
        return card
    var placeholder: ColorRect = ColorRect.new()
    placeholder.custom_minimum_size = Vector2(UI.TILE_SIZE * 2, UI.TILE_SIZE + 24)
    placeholder.color = Color(0.1, 0.1, 0.12, 0.4)
    return placeholder

func _make_empty() -> Control:
    return _make_placeholder(false)

func get_cards() -> Array:
    return _cards.duplicate()

func _make_sold() -> Control:
    return _make_placeholder(true)

func _make_placeholder(sold: bool) -> Control:
    var first_fight_placeholder: bool = _single_empty_state and not sold
    var wrap: PanelContainer = PanelContainer.new()
    wrap.custom_minimum_size = Vector2(790.0, 138.0) if first_fight_placeholder else Vector2(150.0, 138.0)
    wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_theme_stylebox_override("panel", _make_placeholder_style(sold))

    var stack: VBoxContainer = VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 8 if first_fight_placeholder else 5)
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(stack)

    var icon: TextureRect = TextureRect.new()
    icon.texture = EmptySigilTexture
    icon.custom_minimum_size = Vector2(62.0, 62.0) if first_fight_placeholder else Vector2(50.0, 50.0)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.modulate = Color(0.95, 0.68, 0.36, 0.52) if first_fight_placeholder else (Color(0.82, 0.58, 0.34, 0.30) if not sold else Color(0.82, 0.14, 0.14, 0.34))
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(icon)

    var label: Label = Label.new()
    label.text = "SEALED" if sold else _empty_label_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16 if first_fight_placeholder else 11)
    label.add_theme_color_override("font_color", Color(0.95, 0.73, 0.40, 0.98) if first_fight_placeholder else (Color(0.66, 0.58, 0.48, 0.88) if not sold else Color(0.74, 0.48, 0.44, 0.88)))
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
    label.add_theme_constant_override("outline_size", 2 if first_fight_placeholder else 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(label)

    var hint_text: String = "Purchased" if sold else _empty_hint_text
    if hint_text != "":
        var hint: Label = Label.new()
        hint.text = hint_text
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hint.custom_minimum_size = Vector2(360.0, 0.0) if first_fight_placeholder else Vector2(126.0, 0.0)
        hint.add_theme_font_size_override("font_size", 13 if first_fight_placeholder else 10)
        hint.add_theme_color_override("font_color", Color(0.84, 0.76, 0.62, 0.96) if first_fight_placeholder else (Color(0.52, 0.47, 0.42, 0.88) if not sold else Color(0.58, 0.38, 0.36, 0.86)))
        hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
        hint.add_theme_constant_override("outline_size", 2 if first_fight_placeholder else 1)
        hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(hint)
    return wrap

func _make_placeholder_style(sold: bool) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    var first_fight_placeholder: bool = _single_empty_state and not sold
    style.bg_color = Color(0.030, 0.026, 0.034, 0.88)
    style.border_color = Color(0.34, 0.29, 0.28, 0.86)
    if first_fight_placeholder:
        style.bg_color = Color(0.060, 0.041, 0.036, 0.94)
        style.border_color = Color(0.76, 0.45, 0.20, 0.92)
    if sold:
        style.bg_color = Color(0.062, 0.026, 0.034, 0.90)
        style.border_color = Color(0.48, 0.090, 0.090, 0.86)
    style.border_width_left = 2 if first_fight_placeholder else 1
    style.border_width_top = 2 if first_fight_placeholder else 1
    style.border_width_right = 2 if first_fight_placeholder else 1
    style.border_width_bottom = 2 if first_fight_placeholder else 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_right = 5
    style.corner_radius_bottom_left = 5
    style.shadow_size = 12 if first_fight_placeholder else 8
    style.shadow_color = Color(0.66, 0.24, 0.08, 0.24) if first_fight_placeholder else Color(0.0, 0.0, 0.0, 0.44)
    return style

func _duplicate_strings(values) -> Array:
    var out: Array = []
    if values == null:
        return out
    if values is Array:
        for v in values:
            out.append(String(v))
    elif values is PackedStringArray:
        for v in values:
            out.append(String(v))
    elif typeof(values) == TYPE_STRING:
        out.append(String(values))
    return out

func _role_text(roles: Array, primary_role: String = "") -> String:
    var source: String = String(primary_role).strip_edges()
    if source == "" and roles != null and roles.size() > 0:
        source = String(roles[0])
    source = source.strip_edges()
    if source == "":
        return ""
    var cleaned: String = source.replace("_", " ").strip_edges()
    if cleaned == "":
        return ""
    var parts: PackedStringArray = cleaned.split(" ", false)
    var pretty: PackedStringArray = PackedStringArray()
    for part in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    if pretty.size() == 0:
        return cleaned.capitalize()
    return " ".join(pretty)
