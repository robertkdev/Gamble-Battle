extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	print("MinimalQuit: PASS")
	get_tree().quit(0)
