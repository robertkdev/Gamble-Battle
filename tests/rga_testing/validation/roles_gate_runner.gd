extends SceneTree

# Thin runner to execute roles_gate.gd via `-s` CLI. Required because
# Godot 4 expects `-s` scripts to extend SceneTree or MainLoop.

func _initialize() -> void:
    var gate_script := load("res://tests/rga_testing/validation/roles_gate.gd")
    if gate_script == null:
        push_error("roles_gate_runner: failed to load roles_gate.gd")
        quit(1)
        return
    var gate = gate_script.new()
    if gate == null:
        push_error("roles_gate_runner: failed to instantiate roles_gate.gd")
        quit(1)
        return
    get_root().add_child(gate)
    # roles_gate.gd calls get_tree().quit() when done
