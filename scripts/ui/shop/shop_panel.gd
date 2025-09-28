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
    # Clear existing children
    for c in _grid.get_children():
        if c is Node:
            c.queue_free()
    _cards.clear()
    # Populate placeholders for now (no interactions)
    var shown: int = 0
    var idx: int = 0
    for o in offers:
        var card := _make_card(o, idx)
        _grid.add_child(card)
        _cards.append(card)
        # IMPORTANT: now that the card is in the scene tree, set its data
        if card is ShopCard:
            var props: Dictionary = {}
            if o is ShopOffer and String(o.id) != "":
                var off: ShopOffer = o
                props = {
                    "id": String(off.id),
                    "name": String(off.name),
                    "price": int(off.cost),
                    "image_path": String(off.sprite_path),
                    "tags": [],
                }
            else:
                props = {"id":"","name":"?","price":0,"image_path":"","tags":[]}
            # Defer until after _ready so @onready children exist
            (card as ShopCard).call_deferred("set_data", props)
        shown += 1
        idx += 1
    # Fill remaining slots with empty placeholders to keep layout stable
    while shown < _slot_count:
        _grid.add_child(_make_empty())
        shown += 1

func _make_card(offer, index: int) -> Control:
    if ShopCardScene:
        # If this is a placeholder/empty offer, render a blank sold/empty tile
        if offer is ShopOffer and String(offer.id) == "":
            return _make_sold()
        var card = ShopCardScene.instantiate()
        if card and card.has_method("set_slot_index"):
            card.set_slot_index(index)
        return card
    # Fallback minimal if scene missing
    var placeholder := ColorRect.new()
    placeholder.custom_minimum_size = Vector2(UI.TILE_SIZE * 2, UI.TILE_SIZE + 24)
    placeholder.color = Color(0.1,0.1,0.12,0.4)
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
    lbl.modulate = Color(1,0.5,0.5,0.9)
    wrap.add_child(tile)
    wrap.add_child(lbl)
    return wrap
