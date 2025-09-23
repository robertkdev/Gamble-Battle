extends Node

func _ready() -> void:
    var cm = load("res://scripts/combat_manager.gd")
    if cm:
        print("Loaded CombatManager script OK")
    else:
        push_error("Failed to load CombatManager script")
    get_tree().quit()

