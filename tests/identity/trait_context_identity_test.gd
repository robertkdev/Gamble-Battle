extends Node

const UnitFactory := preload("res://scripts/unit_factory.gd")
const TraitContext := preload("res://scripts/game/traits/runtime/trait_context.gd")
const BattleState := preload("res://scripts/game/combat/battle_state.gd")
const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")
const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")

func _ready() -> void:
	var tank := UnitFactory.spawn("korath")
	var mage := UnitFactory.spawn("luna")
	var brawler := UnitFactory.spawn("berebell")
	var state := BattleState.new()
	state.player_team = [tank, mage, brawler]
	state.enemy_team = []

	var ctx := TraitContext.new()
	ctx.configure(null, state, null, null)
	ctx.refresh()

	var tanks := ctx.members_with_primary_role("player", IdentityKeys.ROLE_TANK)
	assert(tanks.size() == 1 and tanks[0] == 0)

	var role_counts := ctx.primary_role_counts("player")
	assert(int(role_counts.get(IdentityKeys.ROLE_TANK, 0)) == 1)
	assert(int(role_counts.get(IdentityKeys.ROLE_BRAWLER, 0)) == 1)
	assert(int(role_counts.get(IdentityKeys.ROLE_MAGE, 0)) == 1)

	var mage_goal := ctx.members_with_primary_goal("player", IdentityKeys.GOAL_MAGE_WOMBO_COMBO_BURST)
	assert(mage_goal.size() == 1 and mage_goal[0] == 1)

	var disrupt_members := ctx.members_with_approach("player", IdentityKeys.APPROACH_DISRUPT)
	assert(disrupt_members.size() == 1 and disrupt_members[0] == 2)

	var state_brawlers := state.primary_role_members("player", IdentityKeys.ROLE_BRAWLER)
	assert(state_brawlers.size() == 1 and state_brawlers[0] == 2)

	assert(state.primary_goal_count("player", IdentityKeys.GOAL_BRAWLER_FRONTLINE_DISRUPTION) == 1)
	assert(state.members_with_approach_count("player", IdentityKeys.APPROACH_SUSTAIN) == 1)

	var stack_role_members := StackUtils.members_with_primary_role(ctx, "player", IdentityKeys.ROLE_TANK)
	assert(stack_role_members.size() == 1 and stack_role_members[0] == 0)

	queue_free()
