extends Resource
class_name CreepRewardEntry

# One entry in a creep reward pool.

@export var id: String = ""
@export_enum("action", "pool", "nothing") var kind: String = "action"
@export var weight: float = 1.0

# For kind == "action": identifier understood by the runtime (e.g., grant_gold, drop_component)
# Creep rewards intentionally drop item components, not completed items.
@export var action_id: String = ""
@export var action_params: Dictionary = {}

# For kind == "pool": nested pool to roll
# Use Resource to avoid circular preload; validated at runtime
@export var sub_pool: Resource = null
