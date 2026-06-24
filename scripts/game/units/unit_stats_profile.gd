extends Resource
class_name UnitStatsProfile

# Data-only resource to provide explicit base stats for non-playable units (e.g., creeps).
# When present at the conventional path for a creep id, UnitFactory will use these stats
# instead of inheriting from the primary role profile.

@export var base_stats: Dictionary = {}
