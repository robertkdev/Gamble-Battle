extends AbilityImplBase

# Bonko - Bonk
# Cast: empower Bonko's next basic attacks with extra AD-based damage,
# missing-HP healing, mana-gain block, and ramp-state telemetry.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const EMPOWER_HITS: int = 3
const EMPOWER_EXTRA_AD_RATIO: float = 1.0
const EMPOWER_HEAL_MISSING_PCT: float = 0.20
const BATTLE_LONG: float = 9999.0

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.state == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var meta: Dictionary = {
		"hits_left": EMPOWER_HITS,
		"extra_ad_ratio": EMPOWER_EXTRA_AD_RATIO,
		"heal_missing_pct": EMPOWER_HEAL_MISSING_PCT,
		"block_mana_gain": true
	}
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_BONKO_EMPOWER, BATTLE_LONG, meta)
	ctx.emit_ramp_state("timed_window", EMPOWER_HITS, EMPOWER_EXTRA_AD_RATIO, EMPOWER_HITS, float(EMPOWER_HITS), "bonko_empowered_hits")
	ctx.log("Bonk: empowered next %d attacks (+%d%% AD, heal %d%% missing, no mana)" % [
		EMPOWER_HITS,
		int(round(EMPOWER_EXTRA_AD_RATIO * 100.0)),
		int(round(EMPOWER_HEAL_MISSING_PCT * 100.0))
	])
	return true
