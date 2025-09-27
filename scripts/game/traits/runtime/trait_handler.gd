extends RefCounted
class_name TraitHandler

# Tiny interface for trait handlers (SLAP + no UI side effects).
#
# Rules:
# - Each method performs exactly one concern and returns quickly.
# - No UI emissions or logging from handlers (do not call any engine emitters).
# - Restrict side effects to BuffSystem stacks/buffs and unit stat adjustments.
# - Be deterministic; avoid reading mutable global state outside ctx/state.

func on_battle_start(ctx):
	# Apply start-of-combat effects only.
	pass

func on_ability_cast(ctx, team: String, index: int, ability_id: String):
	# Respond to a successful cast (e.g., add stacks).
	pass

func on_hit_applied(ctx, event: Dictionary):
	# Pure reaction to a resolved hit.
	# event: { team, source_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd }
	pass

func on_unit_killed(ctx, source_team: String, source_index: int, target_team: String, target_index: int):
	# Fired when any unit is killed by a source (attack or ability).
	pass

func on_tick(ctx, delta: float):
	# Lightweight periodic timers.
	pass

func on_battle_end(ctx):
	# Cleanup if needed (should be minimal).
	pass
