extends Object
class_name CombineRules

# Single source of truth for item combination results.
# Orderless pairs of component ids map to a completed item id.

static func _key(a: String, b: String) -> String:
    var a1 := String(a).strip_edges()
    var b1 := String(b).strip_edges()
    if a1 == "" or b1 == "":
        return ""
    if a1 <= b1:
        return a1 + "+" + b1
    return b1 + "+" + a1

static func completed_for(a: String, b: String) -> String:
    var k := _key(a, b)
    if k == "":
        return ""
    return String(RULES.get(k, ""))

static func has_combo(a: String, b: String) -> bool:
    return completed_for(a, b) != ""

const RULES := {
    # Doubles
    "core+core": "heavyheart",
    "crystal+crystal": "hyperstone",
    "hammer+hammer": "doubleblade",
    "orb+orb": "conductor",
    "plate+plate": "chestplate",
    "spike+spike": "gamblers_eye",
    "veil+veil": "sanctum",
    "wand+wand": "largewand",

    # hammer + X
    "crystal+hammer": "dagger",
    "hammer+spike": "shiv",
    "core+hammer": "blood_engine",
    "hammer+plate": "rendsaw",
    "hammer+veil": "mindbreaker",
    "hammer+orb": "mind_siphon",
    "hammer+wand": "spellblade",

    # crystal + X
    "crystal+wand": "mindstone",
    "crystal+spike": "bandana",
    "core+crystal": "turbine",
    "crystal+plate": "thunderplate",
    "crystal+veil": "piercing_gear",
    "crystal+orb": "clockwork",

    # wand + X
    "spike+wand": "arc_dice",
    "core+wand": "mageheart",
    "plate+wand": "codex",
    "veil+wand": "windwall",
    "orb+wand": "orb_on_a_stick",

    # spike + X
    "core+spike": "hemothorn",
    "plate+spike": "armageddon",
    "spike+veil": "vengeance",
    "orb+spike": "relay",

    # core + X
    "core+plate": "guard",
    "core+veil": "wardheart",
    "core+orb": "vital_battery",

    # plate + X
    "plate+veil": "stone",
    "orb+plate": "anchor",

    # veil + X
    "orb+veil": "serenity",
}

