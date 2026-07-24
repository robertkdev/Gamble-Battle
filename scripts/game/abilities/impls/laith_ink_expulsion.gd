extends AbilityImplBase

# Provisional bridge kit for Laith during the economy conversion.
# The final role and ability design are intentionally deferred.
# Deals 170/255/380 + 0.8x SP + 20x ArcanistStacks magic damage.

const BASE_BY_LEVEL: Array[int] = [170, 255, 380]
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const ARCANIST_KEY: String = "arcanist_stacks" # Legacy fallback for old saved/test state.

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		return false

	var arcanist_stacks: int = 0
	if ctx.buff_system != null:
		arcanist_stacks = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.ARCANIST))
		if arcanist_stacks <= 0:
			arcanist_stacks = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, ARCANIST_KEY))
	var level_index: int = _level_index(caster)
	var damage: float = float(BASE_BY_LEVEL[level_index]) + 0.8 * float(caster.spell_power) + 20.0 * float(max(0, arcanist_stacks))
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, max(0.0, damage), "magic")
	ctx.log("Laith vents the spine ledger.")
	return true
