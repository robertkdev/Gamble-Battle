extends RefCounted
class_name AttackResult

var processed: bool = false
var blocked: bool = false
var dealt: int = 0
var absorbed: int = 0
var heal: int = 0
var before_hp: int = 0
var after_hp: int = 0
var premit: int = 0                # Pre-mitigation total (approx)
var pre_shield: int = 0           # After mitigation, before shields
var before_cap: int = 0           # After shields, before HP cap
var comp_phys: int = 0            # Post-mitigation, pre-shield component breakdown
var comp_mag: int = 0
var comp_true: int = 0
var messages: Array[String] = []

func to_dictionary() -> Dictionary:
    return {
        "processed": processed,
        "blocked": blocked,
        "dealt": dealt,
        "absorbed": absorbed,
        "heal": heal,
        "before_hp": before_hp,
        "after_hp": after_hp,
        "premit": premit,
        "pre_shield": pre_shield,
        "before_cap": before_cap,
        "comp_phys": comp_phys,
        "comp_mag": comp_mag,
        "comp_true": comp_true,
        "messages": messages
    }
