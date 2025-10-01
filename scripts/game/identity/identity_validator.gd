extends Object
class_name IdentityValidator

const PrimaryRole := preload("res://scripts/game/identity/primary_role.gd")
const GoalCatalog := preload("res://scripts/game/identity/goal_catalog.gd")
const ApproachCatalog := preload("res://scripts/game/identity/approach_catalog.gd")
const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")

static func validate(primary_role: String, primary_goal: String, approaches: Array[String]) -> Array[String]:
	var errors: Array[String] = []

	if not PrimaryRole.is_valid(primary_role):
		errors.append("Unknown primary role '%s'" % primary_role)
	if String(primary_goal).strip_edges() == "":
		errors.append("Primary goal id is required")
	elif not GoalCatalog.has(primary_goal):
		errors.append("Unknown primary goal '%s'" % primary_goal)
	elif PrimaryRole.is_valid(primary_role):
		var goal_def = GoalCatalog.get_def(primary_goal)
		if goal_def != null:
			var roles = goal_def.allowed_roles.duplicate()
			if roles.is_empty():
				roles = PrimaryRole.ALL
			if not roles.has(primary_role):
				errors.append("Goal '%s' is not allowed for role '%s'" % [primary_goal, primary_role])

	var seen: Dictionary = {}
	for approach_id in approaches:
		var aid := String(approach_id).strip_edges()
		if aid == "":
			errors.append("Approach id cannot be empty")
			continue
		if seen.has(aid):
			errors.append("Duplicate approach id '%s'" % aid)
			continue
		seen[aid] = true
		if not ApproachCatalog.has(aid):
			errors.append("Unknown approach id '%s'" % aid)
			continue
	if errors.is_empty():
		# conflict check only when ids valid
		for aid in seen.keys():
			var def := ApproachCatalog.get_def(aid)
			if def == null:
				continue
			for conflict in def.conflicts_with:
				if seen.has(String(conflict)):
					errors.append("Approach '%s' conflicts with '%s'" % [aid, String(conflict)])
	return errors

static func ensure_valid(primary_role: String, primary_goal: String, approaches: Array[String]) -> void:
	var issues := validate(primary_role, primary_goal, approaches)
	if not issues.is_empty():
		for e in issues:
			push_error("IdentityValidator: %s" % e)
		assert(false)
