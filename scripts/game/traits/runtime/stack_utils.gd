extends Object
class_name StackUtils

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

static func tier(ctx, team: String, trait_id: String) -> int:
	if ctx == null:
		return -1
	return int(ctx.tier(team, trait_id))

static func is_active(ctx, team: String, trait_id: String) -> bool:
	return tier(ctx, team, trait_id) >= 0

static func members(ctx, team: String, trait_id: String) -> Array[int]:
	if ctx == null:
		return []
	return ctx.members(team, trait_id)

static func key_for(trait_id: String) -> String:
	return TraitKeys.stack_key(trait_id)

static func get_count(ctx, team: String, index: int, trait_id: String) -> int:
	if ctx == null or ctx.buff_system == null:
		return 0
	var k := key_for(trait_id)
	return int(ctx.buff_system.get_stack(ctx.state, team, index, k))

static func add_stacks(ctx, team: String, index: int, trait_id: String, delta: int, per_stack_fields: Dictionary = {}) -> int:
	if ctx == null or ctx.buff_system == null or delta == 0:
		return get_count(ctx, team, index, trait_id)
	var k := key_for(trait_id)
	var res: Dictionary = ctx.buff_system.add_stack(ctx.state, team, index, k, int(delta), per_stack_fields)
	return int(res.get("count", get_count(ctx, team, index, trait_id)))

static func value_by_tier(tier_index: int, values: Array) -> float:
	if values == null or values.size() == 0 or tier_index < 0:
		return 0.0
	var i: int = clamp(tier_index, 0, values.size() - 1)
	var v = values[i]
	return float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0.0

static func members_with_primary_role(ctx, team: String, role_id: String) -> Array[int]:
	if ctx == null:
		return []
	return ctx.members_with_primary_role(team, role_id)

static func primary_role_count(ctx, team: String, role_id: String) -> int:
	return members_with_primary_role(ctx, team, role_id).size()

static func members_with_primary_goal(ctx, team: String, goal_id: String) -> Array[int]:
	if ctx == null:
		return []
	return ctx.members_with_primary_goal(team, goal_id)

static func members_with_approach(ctx, team: String, approach_id: String) -> Array[int]:
	if ctx == null:
		return []
	return ctx.members_with_approach(team, approach_id)
