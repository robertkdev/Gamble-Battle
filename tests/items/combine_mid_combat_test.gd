extends Node

const ItemsLib := preload("res://scripts/game/items/items.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    print("CombineMidCombatTest: start")
    ItemCatalog.reload()
    var items := ItemsLib.new()
    add_child(items)

    # Enter combat phase
    if Engine.has_singleton("GameState"):
        GameState.set_phase(GameState.GamePhase.COMBAT)

    var u := load("res://scripts/unit.gd").new()
    u.attack_damage = 100.0
    u.attack_speed = 1.0
    u.max_hp = 1000
    u.hp = 1000

    # Equip first component
    items.add_to_inventory("hammer", 1)
    var r1 := items.equip(u, "hammer")
    assert_true(r1.ok, "Equip first component ok")
    # Equip second component -> should auto-combine to spellblade
    items.add_to_inventory("wand", 1)
    var r2 := items.equip(u, "wand")
    assert_true(r2.ok, "Equip second component ok")
    assert_true(String(r2.get("combined_id", "")) == "spellblade", "Auto-combined to spellblade")

    var eq := items.get_equipped(u)
    assert_true(eq.size() == 1 and String(eq[0]) == "spellblade", "Equipped set contains only completed item")

    print("CombineMidCombatTest: ok")
    if get_tree():
        get_tree().quit()

func assert_true(cond: bool, msg: String) -> void:
    if not cond:
        push_error("ASSERT FAILED: " + msg)
        printerr("ASSERT FAILED: " + msg)
        if get_tree():
            get_tree().quit()

