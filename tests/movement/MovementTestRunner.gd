extends SceneTree

func _initialize() -> void:
    # Create and run the MovementTest scene in headless mode.
    var test_node := preload("res://tests/movement/MovementTest.gd").new()
    root.add_child(test_node)

