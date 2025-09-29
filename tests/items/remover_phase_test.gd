extends Node

const ItemsLib := preload("res://scripts/game/items/items.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    print("RemoverPhaseTest: start")
    ItemCatalog.reload()
    var items := ItemsLib.new()
    add_child(items)

    var u := load("res://scripts/unit.gd").new()
    u.max_hp = 1000
    u.hp = 1000

    # Equip an item first (out of combat)
    if Engine.has_singleton("GameState"):
        GameState.set_phase(GameState.GamePhase.PREVIEW)
    items.add_to_inventory("plate", 1)
    var r1 := items.equip(u, "plate")
    assert_true(r1.ok, "Equip plate ok")
    assert_true(items.get_equipped(u).size() == 1, "One item equipped")

    # Attempt remover in COMBAT -> denied
    if Engine.has_singleton("GameState"):
        GameState.set_phase(GameState.GamePhase.COMBAT)
    items.add_to_inventory("remover", 1)
    var r2 := items.equip(u, "remover")
    assert_true(not r2.ok and String(r2.reason) == "cannot_remove_in_combat", "Remover denied in combat")

    # Post-combat -> allowed
    if Engine.has_singleton("GameState"):
        GameState.set_phase(GameState.GamePhase.POST_COMBAT)
    # Ensure remover in inventory
    items.add_to_inventory("remover", 1)
    var r3 := items.equip(u, "remover")
    assert_true(r3.ok and int(r3.get("removed", 0)) >= 1, "Remover succeeded after combat")
    assert_true(items.get_equipped(u).size() == 0, "No items remain equipped")

    print("RemoverPhaseTest: ok")
    if get_tree():
        get_tree().quit()

func assert_true(cond: bool, msg: String) -> void:
    if not cond:
        push_error("ASSERT FAILED: " + msg)
        printerr("ASSERT FAILED: " + msg)
        if get_tree():
            get_tree().quit()

