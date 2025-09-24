extends RefCounted
class_name MovementTuning

# MovementTuning
# Centralized movement tuning knobs. Kept as a simple data object so callers
# can read/update values without engine coupling or singletons.
#
# Fields:
# - speed_scale: global multiplier applied to every unit's move_speed
#   when computing per-frame step lengths. Defaults to 1.0.
# - range_epsilon: small forgiveness margin (in world pixels) used by
#   MovementMath.within_range for range checks. Engine gating uses the
#   same helper to avoid drift. Defaults to 0.5.
# - unit_radius_factor: radius (in tiles) = tile_size * factor, used by
#   CollisionResolver to compute separation circles. Defaults to 0.35.

var speed_scale: float = 1.0
var range_epsilon: float = 0.5
var unit_radius_factor: float = 0.35

# Slot-based movement + local avoidance knobs
var separation_radius_factor: float = 3.0  # neighbors within (radius * factor) contribute to separation
var separation_weight: float = 1.5         # base weight of separation steering
var seek_weight: float = 1.0               # base weight of seek steering
var collision_iterations: int = 2          # position-based relaxation passes per frame
var friendly_soft_separation: bool = true  # friend–friend pairs ignore step cap during relaxation

# Legacy knobs for avoidance/grid A* removed in favor of slot-based movement.

# Arrival behavior (speed scales down near destination slot)
# Units begin slowing within (arrival_slow_radius_factor * radius), and treat
# themselves as "arrived" (0 speed) within (arrival_stop_radius_factor * radius).
var arrival_slow_radius_factor: float = 1.8
var arrival_stop_radius_factor: float = 0.5
var arrival_min_speed_factor: float = 0.2  # floor speed fraction outside stop radius

# Clamp how much separation can steer away from the desired seek direction.
# If the final blended direction points too far away from seek, we soften sep.
var min_forward_dot: float = 0.2
