extends Object
class_name UnitIdentityFactory

const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")
const IdentityRegistry := preload("res://scripts/game/identity/identity_registry.gd")

static func from_dict(data: Dictionary) -> UnitIdentity:
    var identity := UnitIdentity.new()
    if data == null:
        return identity
    identity.primary_role = String(data.get("primary_role", ""))
    identity.primary_goal = String(data.get("primary_goal", ""))
    identity.approaches = _to_string_array(data.get("approaches", []))
    identity.alt_goals = _to_string_array(data.get("alt_goals", []))
    return identity

static func to_dict(identity: UnitIdentity) -> Dictionary:
    if identity == null:
        return {}
    return {
        "primary_role": String(identity.primary_role),
        "primary_goal": String(identity.primary_goal),
        "approaches": identity.approaches.duplicate(),
        "alt_goals": identity.alt_goals.duplicate(),
    }

static func validate(identity: UnitIdentity) -> Array[String]:
    if identity == null:
        return ["Identity resource is null"]
    return IdentityRegistry.validate_identity(identity.primary_role, identity.primary_goal, identity.approaches)

static func _to_string_array(value) -> Array[String]:
    var out: Array[String] = []
    if value == null:
        return out
    if value is Array:
        for v in value:
            out.append(String(v))
    elif value is PackedStringArray:
        for v in value:
            out.append(String(v))
    elif typeof(value) == TYPE_STRING:
        out.append(String(value))
    return out