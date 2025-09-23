extends AbilityImplBase

# Example ability implementation scaffold.
# File path: res://scripts/game/abilities/impls/<ability_id>.gd
# AbilityCatalog will auto-resolve by ability_id using this convention.

func cast(ctx: AbilityContext) -> bool:
	# Select targets via ctx helpers, then apply effects via AbilityEffects (indirectly through ctx.damage_single/heal_single).
	# Example:
	# var target_idx := ctx.current_target(ctx.caster_team, ctx.caster_index)
	# if target_idx < 0: return false
	# ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, 100.0, "physical")
	# ctx.log("Example cast executed")
	return false
