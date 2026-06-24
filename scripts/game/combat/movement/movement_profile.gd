extends RefCounted
class_name MovementProfile

# MovementProfile
# Minimal, per-unit configuration for the movement layer. This is intentionally
# short to leave room for future extensions (e.g., kiting/strafe flags).
#
# Fields:
# - intent: movement mode: approach, strafe, or kite.
# - band_min/band_max: hysteresis multipliers around desired range.
# - strafe_strength: fraction of move speed used for deterministic lateral drift
#   while in range.
# - kite_strength: fraction of move speed used to open distance when too close.
# - side_bias: -1 or 1. Keeps lateral movement deterministic per unit.
# - anchor_*: optional allied escort behavior, used by supports to stay near
#   a carry while still peeling threats.

var intent: String = "approach"
var band_min: float = 0.95
var band_max: float = 1.05
var strafe_strength: float = 0.0
var kite_strength: float = 0.0
var side_bias: float = 1.0
var anchor_index: int = -1
var anchor_min_tiles: float = 0.0
var anchor_max_tiles: float = 0.0
var anchor_strength: float = 0.0

func _init(_intent: String = "approach", _band_min: float = 0.95, _band_max: float = 1.05, _strafe_strength: float = 0.0, _kite_strength: float = 0.0, _side_bias: float = 1.0, _anchor_index: int = -1, _anchor_min_tiles: float = 0.0, _anchor_max_tiles: float = 0.0, _anchor_strength: float = 0.0) -> void:
	intent = _intent
	band_min = _band_min
	band_max = _band_max
	strafe_strength = _strafe_strength
	kite_strength = _kite_strength
	side_bias = -1.0 if _side_bias < 0.0 else 1.0
	anchor_index = _anchor_index
	anchor_min_tiles = max(0.0, _anchor_min_tiles)
	anchor_max_tiles = max(anchor_min_tiles, _anchor_max_tiles)
	anchor_strength = clampf(_anchor_strength, 0.0, 1.0)
