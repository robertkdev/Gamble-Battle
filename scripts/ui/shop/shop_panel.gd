extends RefCounted
class_name ShopPanel

const UI := preload("res://scripts/constants/ui_constants.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopCardScene := preload("res://scenes/ui/shop/ShopCard.tscn")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")

var _grid: GridContainer = null
var _slot_count: int = ShopConfig.SLOT_COUNT
var _host_container: Container = null
var _cards: Array = []

func configure(grid: GridContainer, slot_count: int = ShopConfig.SLOT_COUNT) -> void:
    _grid = grid
    _host_container = (_grid.get_parent() as Container) if _grid else null
    _slot_count = max(1, int(slot_count))
    if _grid and _grid.has_method("set"):
        _grid.columns = _slot_count

func get_host_container() -> Container:
    return _host_container

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
    var placeholder := ColorRect.new()
    placeholder.custom_minimum_size = Vector2(UI.TILE_SIZE * 2, UI.TILE_SIZE + 24)
    placeholder.color = Color(0.1, 0.1, 0.12, 0.4)
    return placeholder

func get_cards() -> Array:
    return _cards.duplicate()

func _make_sold() -> Control:
    var wrap := VBoxContainer.new()
    wrap.custom_minimum_size = Vector2(UI.TILE_SIZE * 2, UI.TILE_SIZE + 24)
    var tile := ColorRect.new()
    tile.custom_minimum_size = Vector2(UI.TILE_SIZE, UI.TILE_SIZE)
    tile.color = Color(0.1, 0.1, 0.12, 0.6)
    var lbl := Label.new()
    lbl.text = "SOLD"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.modulate = Color(1, 0.5, 0.5, 0.9)
    wrap.add_child(tile)
    wrap.add_child(lbl)
    return wrap

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
