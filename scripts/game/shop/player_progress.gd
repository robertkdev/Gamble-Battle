extends RefCounted
class_name PlayerProgress

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")

signal level_changed(old_level: int, new_level: int)
signal xp_changed(old_xp: int, new_xp: int)
signal progress_reset(level: int, xp: int)

var level: int = ShopConfig.STARTING_LEVEL
var xp: int = 0

func reset() -> void:
	level = int(ShopConfig.STARTING_LEVEL)
	xp = 0
	progress_reset.emit(level, xp)

func set_level(new_level: int) -> void:
	var clamped: int = clamp(int(new_level), int(ShopConfig.MIN_LEVEL), int(ShopConfig.MAX_LEVEL))
	if clamped == level:
		return
	var old := level
	level = clamped
	xp = 0
	level_changed.emit(old, level)
	xp_changed.emit(0, xp)

func add_xp(amount: int) -> void:
	# Pure XP addition; no gold logic here. Levels up as thresholds are met.
	if is_at_max_level():
		return
	var inc: int = max(0, int(amount))
	if inc == 0:
		return
	var old_xp := xp
	xp += inc
	_resolve_level_ups()
	if xp != old_xp:
		xp_changed.emit(old_xp, xp)

func buy_xp() -> int:
	# Convenience: add configured XP per buy and return amount added.
	var amt: int = int(ShopConfig.XP_PER_BUY)
	add_xp(amt)
	return amt

func is_at_max_level() -> bool:
	return int(level) >= int(ShopConfig.MAX_LEVEL)

func xp_to_next() -> int:
	if is_at_max_level():
		return 0
	var target_level := int(level) + 1
	return int(ShopConfig.XP_TO_REACH_LEVEL.get(target_level, 0))

func progress_to_next() -> float:
	var need := xp_to_next()
	if need <= 0:
		return 1.0
	return clamp(float(xp) / float(need), 0.0, 1.0)

func _resolve_level_ups() -> void:
	# Loop to handle multiple level-ups if large XP arrives.
	while not is_at_max_level():
		var need := xp_to_next()
		if need <= 0:
			break
		if xp >= need:
			var old_level := level
			level = min(level + 1, int(ShopConfig.MAX_LEVEL))
			xp -= need
			level_changed.emit(old_level, level)
			# If we reached max level, normalize XP to 0 for clarity
			if is_at_max_level():
				if xp != 0:
					var old_xp := xp
					xp = 0
					xp_changed.emit(old_xp, xp)
		else:
			break
