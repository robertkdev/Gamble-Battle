extends AbilityImplBase

# Kythera — Siphon
# Mana cost: 80 (set in AbilityDef)
# For 3 seconds: each second siphons X Magic Resist (X = 1 + floor(Aegis stacks/3), cap 3) from the current target,
# and deals damage per tick. Kythera permanently gains the total actually siphoned when Siphon ends.

const DURATION_S := 3.0
const SP_DMG_MULT := 0.35
const KEY_AEGIS_STACKS := "aegis_stacks"              # Legacy fallback; TODO remove after validation
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

func _read_aegis_stacks(ctx: AbilityContext) -> int:
	if ctx == null or ctx.buff_system == null:
		return 0
	# Prefer unified TraitKeys; fall back to legacy aegis_stacks for compatibility.
	var v: int = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.AEGIS))
	if v > 0:
		return v
	return int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_AEGIS_STACKS))

func cast(ctx: AbilityContext) -> bool:
	if ctx == null:
		return false
	var bs = ctx.buff_system
	if bs == null:
		ctx.log("[Siphon] BuffSystem not available; cast aborted")
		return false

	var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_idx < 0:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_team: String = ("enemy" if ctx.caster_team == "player" else "player")
	var tgt: Unit = ctx.unit_at(target_team, target_idx)
	if caster == null or tgt == null or not tgt.is_alive():
		return false

	# Prevent re-cast while active to avoid double schedules
	if bs.has_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_KYTHERA):
		ctx.log("Siphon is already active; cast skipped.")
		return false

	var stacks: int = max(0, _read_aegis_stacks(ctx))
	var siphon_per_sec: int = min(3, 1 + int(floor(float(stacks) / 3.0)))

	# Build and store meta on caster so ticks/end can reference and accumulate drained_total
	var meta := {
		"target_index": target_idx,
		"per_sec": siphon_per_sec,
		"drained_total": 0.0
	}
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_KYTHERA, DURATION_S, meta)

	# Schedule ticks (once per second) and end handler
	var per_tick_dmg: int = int(max(0.0, round(50.0 + float(caster.spell_power) * SP_DMG_MULT)))
	if ctx.engine != null and ctx.engine.ability_system != null:
		for i in range(int(DURATION_S)):
			ctx.engine.ability_system.schedule_event("kythera_siphon_tick", ctx.caster_team, ctx.caster_index, float(i + 1), {
				"target_index": target_idx,
				"damage": per_tick_dmg,
				"remain": max(0.0, DURATION_S - float(i + 1))
			})
		ctx.engine.ability_system.schedule_event("kythera_siphon_end", ctx.caster_team, ctx.caster_index, DURATION_S, {})

	ctx.log("Siphon: drain %d MR/sec for %.1fs; %d magic dmg/sec." % [int(siphon_per_sec), DURATION_S, per_tick_dmg])
	return true
