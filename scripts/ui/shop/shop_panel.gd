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

func configure(grid: GridContainer, slot_count: int = ShopConfig.SLOT_COUNT) -> void:
    _grid = grid
    _host_container = (_grid.get_parent() as Container) if _grid else null
    _slot_count = max(1, int(slot_count))
    if _grid and _grid.has_method("set"):
        _grid.columns = _slot_count
        _grid.custom_minimum_size = Vector2(max(_grid.custom_minimum_size.x, 790.0), 138.0)

func get_host_container() -> Container:
    return _host_container

func set_empty_state(label_text: String, hint_text: String = "") -> void:
    _empty_label_text = String(label_text).strip_edges()
    _empty_hint_text = String(hint_text).strip_edges()
    if _empty_label_text == "":
        _empty_label_text = "LEDGER"

func set_offers(offers: Array) -> void:
    if _grid == null:
        return
    for c in _grid.get_children():
        if c is Node:
            c.queue_free()
    _cards.clear()

    var shown: int = 0
    var idx: int = 0
    for o in offers:
        var card := _make_card(o, idx)
        _grid.add_child(card)
        _cards.append(card)
        if card is ShopCard:
            var props: Dictionary = {}
            if o is ShopOffer and String(o.id) != "":
                var off: ShopOffer = o
                var roles := _duplicate_strings(off.roles)
                var traits := _duplicate_strings(off.traits)
                var approaches := _duplicate_strings(off.approaches)
                var alt_goals := _duplicate_strings(off.alt_goals)
                var primary_role := String(off.primary_role)
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

    while shown < _slot_count:
        _grid.add_child(_make_empty())
        shown += 1

func _make_card(offer, index: int) -> Control:
    if ShopCardScene:
        if offer is ShopOffer and String(offer.id) == "":
            return _make_sold()
        var card = ShopCardScene.instantiate()
        if card and card.has_method("set_slot_index"):
            card.set_slot_index(index)
        return card
    var placeholder := ColorRect.new()
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
    var wrap: PanelContainer = PanelContainer.new()
    wrap.custom_minimum_size = Vector2(150.0, 138.0)
    wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_theme_stylebox_override("panel", _make_placeholder_style(sold))

    var stack: VBoxContainer = VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 5)
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(stack)

    var icon: TextureRect = TextureRect.new()
    icon.texture = EmptySigilTexture
    icon.custom_minimum_size = Vector2(50.0, 50.0)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.modulate = Color(0.82, 0.58, 0.34, 0.30) if not sold else Color(0.82, 0.14, 0.14, 0.34)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(icon)

    var label: Label = Label.new()
    label.text = "SEALED" if sold else _empty_label_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color(0.66, 0.58, 0.48, 0.88) if not sold else Color(0.74, 0.48, 0.44, 0.88))
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
    label.add_theme_constant_override("outline_size", 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(label)

    var hint_text: String = "Purchased" if sold else _empty_hint_text
    if hint_text != "":
        var hint: Label = Label.new()
        hint.text = hint_text
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hint.custom_minimum_size = Vector2(126.0, 0.0)
        hint.add_theme_font_size_override("font_size", 10)
        hint.add_theme_color_override("font_color", Color(0.52, 0.47, 0.42, 0.88) if not sold else Color(0.58, 0.38, 0.36, 0.86))
        hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
        hint.add_theme_constant_override("outline_size", 1)
        hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(hint)
    return wrap

func _make_placeholder_style(sold: bool) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.030, 0.026, 0.034, 0.88)
    style.border_color = Color(0.34, 0.29, 0.28, 0.86)
    if sold:
        style.bg_color = Color(0.062, 0.026, 0.034, 0.90)
        style.border_color = Color(0.48, 0.090, 0.090, 0.86)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_right = 5
    style.corner_radius_bottom_left = 5
    style.shadow_size = 8
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
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
    var source := String(primary_role).strip_edges()
    if source == "" and roles != null and roles.size() > 0:
        source = String(roles[0])
    source = source.strip_edges()
    if source == "":
        return ""
    var cleaned := source.replace("_", " ").strip_edges()
    if cleaned == "":
        return ""
    var parts := cleaned.split(" ", false)
    var pretty := PackedStringArray()
    for part in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    if pretty.size() == 0:
        return cleaned.capitalize()
    return " ".join(pretty)
