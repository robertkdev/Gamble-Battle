extends RefCounted
class_name MovementProfile

# MovementProfile
# Minimal, per-unit configuration for the movement layer. This is intentionally
# short to leave room for future extensions (e.g., kiting/strafe flags).
#
# Fields:
# - intent: movement mode; currently only "approach" is supported.
# - band_min/band_max: hysteresis multipliers around desired range (in tiles).
#   If desired_range = attack_range * tile_size, band is [band_min..band_max] * desired_range.
#   Movement computes step=0 inside band to avoid thrashing at the threshold.

var intent: String = "approach"
var band_min: float = 0.95
var band_max: float = 1.05

func _init(_intent: String = "approach", _band_min: float = 0.95, _band_max: float = 1.05) -> void:
    intent = _intent
    band_min = _band_min
    band_max = _band_max
