extends Object
class_name AbilityUtils

const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")

static func ability_name_for(u: Unit) -> String:
    if u == null or String(u.ability_id) == "":
        return "Ability"
    var def = AbilityCatalog.get_def(String(u.ability_id))
    if def != null and String(def.name) != "":
        return String(def.name)
    return "Ability"

