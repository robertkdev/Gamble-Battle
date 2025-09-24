extends RefCounted
class_name TargetAssigner

# TargetAssigner
# Delegates target selection to TargetController and writes result into the event.

func assign_for_event(event: AttackEvent, target_controller: TargetController) -> void:
	if event == null or target_controller == null:
		return
	var idx: int = target_controller.current_target(event.team, event.shooter_index)
	event.target_index = idx
