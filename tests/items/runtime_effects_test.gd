extends Node

const BuffSystem := preload("res://scripts/game/abilities/buff_system.gd")
const BattleState := preload("res://scripts/game/combat/battle_state.gd")

func _ready() -> void:
    call_deferred("_run")

class_name DummyManager
var player_team: Array
var enemy_team: Array

class DummyEngine:
    var state
    var buff_system
    func _resolver_emit_hit(_a,_b,_c,_d,_e,_f,_g,_h,_i,_j) -> void: pass
    func _resolver_emit_unit_stat(_team,_idx,_fields) -> void: pass
    func _resolver_emit_stats(_p,_e) -> void: pass

func _run() -> void:
    print("RuntimeEffectsTest: start")
    var bs := BuffSystem.new()
    var st := BattleState.new()
    var u := load("res://scripts/unit.gd").new()
    u.attack_damage = 100.0
    u.spell_power = 100.0
    u.crit_chance = 0.0
    var e := load("res://scripts/unit.gd").new()
    e.max_hp = 1000
    e.hp = 1000
    e.armor = 0.0
    e.magic_resist = 0.0
    st.player_team = [u]
    st.enemy_team = [e]

    var mgr := DummyManager.new()
    mgr.player_team = st.player_team
    mgr.enemy_team = st.enemy_team
    var eng := DummyEngine.new()
    eng.state = st
    eng.buff_system = bs

    # Doubleblade: on hit -> +2% AD stack
    var dbl = preload("res://scripts/game/items/effects/doubleblade.gd").new()
    dbl.configure(mgr, eng, bs)
    var before_ad: float = u.attack_damage
    dbl.on_event(u, "hit_dealt", {})
    var stacks: int = bs.get_stack(st, "player", 0, "doubleblade_ad")
    assert_true(stacks >= 1, "Doubleblade increments stacks on hit")
    assert_true(u.attack_damage > before_ad, "Doubleblade increased AD")

    # Spellblade: on cast -> next attack deals +20% SP as magic
    var spb = preload("res://scripts/game/items/effects/spellblade.gd").new()
    spb.configure(mgr, eng, bs)
    spb.on_event(u, "ability_cast", {})
    var enemy_before_hp: int = int(e.hp)
    spb.on_event(u, "hit_dealt", {"target_index": 0})
    var dealt: int = enemy_before_hp - int(e.hp)
    assert_true(dealt >= 20, "Spellblade dealt expected bonus magic damage (>=20)")

    # Shiv: on crit -> armor shred (5% current Armor)
    var shiv = preload("res://scripts/game/items/effects/shiv.gd").new()
    shiv.configure(mgr, eng, bs)
    e.armor = 100.0
    shiv.on_event(u, "hit_dealt", {"crit": true, "target_index": 0})
    assert_approx(e.armor, 95.0, 0.25, "Shiv applied ~5% armor shred")

    print("RuntimeEffectsTest: ok")
    if get_tree():
        get_tree().quit()

func assert_true(cond: bool, msg: String) -> void:
    if not cond:
        push_error("ASSERT FAILED: " + msg)
        printerr("ASSERT FAILED: " + msg)
        if get_tree():
            get_tree().quit()

func assert_approx(actual: float, expected: float, eps: float, msg: String) -> void:
    if abs(float(actual) - float(expected)) > float(eps):
        assert_true(false, msg + " (actual=" + str(actual) + ", expected=" + str(expected) + ")")

