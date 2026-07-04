extends Object
class_name TeamOddsEstimator

const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")

const MIN_PERCENT: int = 1
const MAX_PERCENT: int = 99
const EMPTY_TEAM_RATING: float = 1.0
const LEVEL_RATING_STEP: float = 0.18
const COST_RATING_STEP: float = 0.08
const TRAIT_TIER_STEP: float = 0.075
const TRAIT_COUNT_STEP: float = 0.012
const ODDS_EXPONENT: float = 1.12

static func estimate_win_percent(player_team: Array[Unit], enemy_team: Array[Unit]) -> int:
	var player_rating: float = team_rating(player_team)
	var enemy_rating: float = team_rating(enemy_team)
	return estimate_from_ratings(player_rating, enemy_rating)

static func estimate_from_ratings(player_rating: float, enemy_rating: float) -> int:
	var player_value: float = pow(max(EMPTY_TEAM_RATING, float(player_rating)), ODDS_EXPONENT)
	var enemy_value: float = pow(max(EMPTY_TEAM_RATING, float(enemy_rating)), ODDS_EXPONENT)
	var total: float = max(1.0, player_value + enemy_value)
	var percent: int = int(round((player_value / total) * 100.0))
	return clampi(percent, MIN_PERCENT, MAX_PERCENT)

static func team_rating(team: Array[Unit]) -> float:
	var total: float = 0.0
	var typed_team: Array[Unit] = []
	for unit: Unit in team:
		if unit == null:
			continue
		total += unit_rating(unit)
		typed_team.append(unit)
	if total <= 0.0:
		return EMPTY_TEAM_RATING
	return total * _trait_multiplier(typed_team)

static func unit_rating(unit: Unit) -> float:
	if unit == null:
		return 0.0
	var hp_rating: float = float(max(1, int(unit.max_hp))) * (1.0 + (float(unit.armor) + float(unit.magic_resist)) / 260.0)
	var attack_rating: float = float(unit.attack_damage) * max(0.1, float(unit.attack_speed)) * 12.0
	var spell_rating: float = float(unit.spell_power) * 5.0
	var sustain_rating: float = float(unit.hp_regen) * 18.0 + float(unit.lifesteal) * 95.0
	var mana_rating: float = float(unit.mana_regen) * 12.0 + float(unit.mana_start) * 0.18
	var range_rating: float = max(0.0, float(unit.attack_range - 1)) * 12.0
	var base_rating: float = hp_rating + attack_rating + spell_rating + sustain_rating + mana_rating + range_rating
	var level_multiplier: float = 1.0 + float(max(0, int(unit.level) - 1)) * LEVEL_RATING_STEP
	var cost_multiplier: float = 1.0 + float(max(0, int(unit.cost) - 1)) * COST_RATING_STEP
	return max(EMPTY_TEAM_RATING, base_rating * level_multiplier * cost_multiplier)

static func _trait_multiplier(team: Array[Unit]) -> float:
	if team.is_empty():
		return 1.0
	var compiled: Dictionary = TraitCompiler.compile(team)
	var tiers: Dictionary = compiled.get("tiers", {}) if typeof(compiled.get("tiers", {})) == TYPE_DICTIONARY else {}
	var counts: Dictionary = compiled.get("counts", {}) if typeof(compiled.get("counts", {})) == TYPE_DICTIONARY else {}
	var bonus: float = 0.0
	for trait_id: Variant in tiers.keys():
		var tier: int = int(tiers.get(trait_id, -1))
		if tier < 0:
			continue
		bonus += float(tier + 1) * TRAIT_TIER_STEP
		bonus += float(max(0, int(counts.get(trait_id, 0)))) * TRAIT_COUNT_STEP
	return 1.0 + bonus
