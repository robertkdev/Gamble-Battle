extends Object
class_name IdentityUtils

# Normalization helpers for identity keys (roles/goals/approaches).

static func normalize_role_id(value: String) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s
