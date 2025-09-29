extends Node

const ItemsLib := preload("res://scripts/game/items/items.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    print("EquipOverlayTest: start")
    # Ensure catalog loaded
    ItemCatalog.reload()
    # Create Items autoload substitute
    var items := ItemsLib.new()
    add_child(items)

    # Fresh unit baseline
    var u := load("res://scripts/unit.gd").new()
    u.attack_damage = 100.0
    u.attack_speed = 1.0
    u.spell_power = 0.0
    u.armor = 0.0
    u.magic_resist = 0.0
    u.mana_regen = 10.0
    u.max_hp = 1000
    u.hp = 1000
    u.mana_max = 100
    u.mana_start = 0
    u.mana = 0

    # Plate: +30 armor (flat)
    items.add_to_inventory("plate", 1)
    var r1 := items.equip(u, "plate")
    assert_true(r1.ok, "Equip plate ok")
    assert_true(int(u.armor) == 30, "Armor +30 applied")

    # Crystal: +25% AS (pct)
    items.add_to_inventory("crystal", 1)
    var r2 := items.equip(u, "crystal")
    assert_true(r2.ok, "Equip crystal ok")
    assert_approx(u.attack_speed, 1.25, 0.001, "AS +25% applied")

    # Orb: +20 start mana and +15% mana regen; outside combat current mana bumps to start
    items.add_to_inventory("orb", 1)
    var r3 := items.equip(u, "orb")
    assert_true(r3.ok, "Equip orb ok")
    assert_true(int(u.mana_start) == 20, "Start mana set to 20")
    assert_true(int(u.mana) == 20, "Current mana bumped to start outside combat")
    assert_approx(u.mana_regen, 11.5, 0.01, "+15% mana regen applied to base 10")

    # Remove all -> revert to base values
    var rr := items.remove_all(u)
    assert_true(rr.ok, "remove_all ok")
    assert_true(int(u.armor) == 0, "Armor reverted")
    assert_approx(u.attack_speed, 1.0, 0.001, "AS reverted")
    assert_true(int(u.mana_start) == 0, "Start mana reverted")

    print("EquipOverlayTest: ok")
    if get_tree():
        get_tree().quit()

func assert_true(cond: bool, msg: String) -> void:
    if not cond:
        push_error("ASSERT FAILED: " + msg)
        printerr("ASSERT FAILED: " + msg)
        if get_tree():
            get_tree().quit()

func assert_approx(actual: float, expected: float, eps: float, msg: String) -> void:
    if abs(float(actual) - float(expected)) > float(eps):
        assert_true(false, msg + " (actual=" + str(actual) + ", expected=" + str(expected) + ")")

