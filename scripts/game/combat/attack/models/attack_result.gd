extends RefCounted
class_name AttackResult

var processed: bool = false
var blocked: bool = false
var dealt: int = 0
var absorbed: int = 0
var heal: int = 0
var before_hp: int = 0
var after_hp: int = 0
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
        "messages": messages
    }
