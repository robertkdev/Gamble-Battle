extends Node

func _ready() -> void:
	var scr = load("res://scripts/combat_manager.gd")
	if scr == null:
		print("Failed to load CombatManager")
	else:
		print("Loaded CombatManager: %s" % [scr])
	get_tree().quit()
