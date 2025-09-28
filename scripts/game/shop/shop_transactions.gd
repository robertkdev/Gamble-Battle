extends RefCounted
class_name ShopTransactions

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const PlayerProgress := preload("res://scripts/game/shop/player_progress.gd")
const CombineService := preload("res://scripts/game/shop/combine_service.gd")

var _roller: ShopRoller
var _roster
var _combiner: CombineService

func configure(roller: ShopRoller, roster = null) -> void:
    _roller = roller
    _roster = roster
    _combiner = CombineService.new()
    _combiner.configure(_roster if _roster != null else (Roster if Engine.has_singleton("Roster") else null))

func toggle_lock(state: ShopState) -> ShopState:
    # Returns a new state with lock flipped. Offers and free_rerolls preserved.
    var locked := (not bool(state.locked))
    return ShopState.new(state.offers, locked, state.free_rerolls)

func reroll(state: ShopState, level: int, available_gold: int) -> Dictionary:
    # Fail fast; no side-effects outside the returned payload.
    # Returns { ok: bool, error?: String, state?: ShopState, gold_spent?: int }
    if _roller == null:
        return { "ok": false, "error": ShopErrors.UNKNOWN }

    # Lock handling
    var locked_now: bool = bool(state.locked)
    if locked_now and not ShopConfig.CLEAR_LOCK_ON_REROLL:
        return { "ok": false, "error": ShopErrors.SHOP_LOCKED }

    # Cost computation (free reroll consumes a charge)
    var cost: int = int(ShopConfig.REROLL_COST)
    var new_free: int = int(state.free_rerolls)
    if new_free > 0:
        cost = 0
        new_free = max(0, new_free - 1)

    # Affordability check (phase-aware)
    var in_combat: bool = false
    if Engine.has_singleton("GameState"):
        in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
    var bet: int = (int(Economy.current_bet) if Engine.has_singleton("Economy") else 0)
    var spent: int = ((int(Economy.combat_spent) if Engine.has_singleton("Economy") else 0) if in_combat else 0)
    var aff := ShopAffordability.can_afford(int(available_gold), bet, cost, in_combat, spent)
    if not bool(aff.get("ok", false)):
        return { "ok": false, "error": ShopErrors.WOULD_KILL_YOU, "need_more": int(aff.get("need_more", 0)) }

    # Generate new offers
    var offers: Array[ShopOffer] = _roller.roll(int(level), int(ShopConfig.SLOT_COUNT))
    if offers.is_empty():
        return { "ok": false, "error": ShopErrors.NO_OFFERS }

    # Clear lock if configured; otherwise preserve (should not reach here if locked and not clearing)
    var next_locked: bool = false if ShopConfig.CLEAR_LOCK_ON_REROLL else bool(state.locked)
    var new_state := ShopState.new(offers, next_locked, new_free)
    return { "ok": true, "state": new_state, "gold_spent": cost }

func buy_xp(progress: PlayerProgress, available_gold: int) -> Dictionary:
    # Returns { ok: bool, error?: String, gold_spent?: int, level?: int, xp?: int, xp_to_next?: int }
    var cost: int = int(ShopConfig.BUY_XP_COST)
    var in_combat: bool = false
    if Engine.has_singleton("GameState"):
        in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
    var bet: int = (int(Economy.current_bet) if Engine.has_singleton("Economy") else 0)
    var spent: int = (int(Economy.combat_spent) if in_combat and Engine.has_singleton("Economy") else 0)
    var aff := ShopAffordability.can_afford(int(available_gold), bet, cost, in_combat, spent)
    if not bool(aff.get("ok", false)):
        return { "ok": false, "error": ShopErrors.WOULD_KILL_YOU, "need_more": int(aff.get("need_more", 0)) }
    if progress == null:
        return { "ok": false, "error": ShopErrors.UNKNOWN }
    progress.buy_xp()
    return {
        "ok": true,
        "gold_spent": cost,
        "level": int(progress.level),
        "xp": int(progress.xp),
        "xp_to_next": int(progress.xp_to_next()),
    }

func buy_unit(state: ShopState, slot_index: int, available_gold: int, level: int) -> Dictionary:
    # Returns { ok, state?, gold_spent?, bench_slot?, unit_id?, error? }
    if _roller == null:
        return { "ok": false, "error": ShopErrors.UNKNOWN }
    if state == null or state.offers == null or state.offers.is_empty():
        return { "ok": false, "error": ShopErrors.NO_OFFERS }
    var idx := int(slot_index)
    if idx < 0 or idx >= state.offers.size():
        return { "ok": false, "error": ShopErrors.INVALID_SLOT }
    var offer: ShopOffer = state.offers[idx]
    if offer == null:
        return { "ok": false, "error": ShopErrors.INVALID_SLOT }
    var cost := int(offer.cost)
    # Affordability (phase-aware)
    var in_combat: bool = false
    if Engine.has_singleton("GameState"):
        in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
    var bet: int = (int(Economy.current_bet) if Engine.has_singleton("Economy") else 0)
    var spent: int = (int(Economy.combat_spent) if in_combat and Engine.has_singleton("Economy") else 0)
    var aff := ShopAffordability.can_afford(int(available_gold), bet, cost, in_combat, spent)
    if not bool(aff.get("ok", false)):
        return { "ok": false, "error": ShopErrors.WOULD_KILL_YOU, "need_more": int(aff.get("need_more", 0)) }
    # Roster capacity
    var bench_slot: int = -1
    if _roster != null and _roster.has_method("first_empty_slot"):
        bench_slot = int(_roster.first_empty_slot())
    elif Engine.has_singleton("Roster"):
        bench_slot = int(Roster.first_empty_slot())
    if bench_slot == -1:
        return { "ok": false, "error": ShopErrors.BENCH_FULL }
    # Spawn unit
    var u: Unit = UnitFactory.spawn(String(offer.id))
    if u == null:
        return { "ok": false, "error": ShopErrors.UNKNOWN }
    # Place in bench
    var placed := false
    if _roster != null and _roster.has_method("set_slot"):
        placed = bool(_roster.set_slot(bench_slot, u))
    elif Engine.has_singleton("Roster"):
        placed = bool(Roster.set_slot(bench_slot, u))
    if not placed:
        return { "ok": false, "error": ShopErrors.BENCH_FULL }
    # Leave the purchased slot as a blank placeholder to preserve layout and indicate sold/empty
    var new_offers: Array[ShopOffer] = state.offers.duplicate()
    new_offers[idx] = ShopOffer.new("", "", 0, "")
    var new_state := ShopState.new(new_offers, state.locked, state.free_rerolls)
    # Attempt bench combines (chained)
    if _combiner != null:
        _combiner.combine()
    return { "ok": true, "state": new_state, "gold_spent": cost, "bench_slot": bench_slot, "unit_id": String(offer.id) }

func sell_unit(u: Unit) -> Dictionary:
    # Remove unit from bench and credit its base cost.
    if u == null:
        return { "ok": false, "error": ShopErrors.UNKNOWN }
    # Find in roster bench
    var slot: int = -1
    if _roster != null and _roster.has_method("slot_count"):
        var n := int(_roster.slot_count())
        for i in range(n):
            var cur: Unit = _roster.get_slot(i)
            if cur == u:
                slot = i
                break
    elif Engine.has_singleton("Roster"):
        var n2 := int(Roster.slot_count())
        for j in range(n2):
            var cur2: Unit = Roster.get_slot(j)
            if cur2 == u:
                slot = j
                break
    if slot == -1:
        return { "ok": false, "error": ShopErrors.UNKNOWN }
    # Remove from bench
    var ok := false
    if _roster != null and _roster.has_method("set_slot"):
        ok = bool(_roster.set_slot(slot, null))
    elif Engine.has_singleton("Roster"):
        ok = bool(Roster.set_slot(slot, null))
    if not ok:
        return { "ok": false, "error": ShopErrors.UNKNOWN }
    var value: int = int(u.cost)
    return { "ok": true, "gold_gained": value }
