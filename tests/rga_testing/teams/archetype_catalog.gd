extends RefCounted
class_name RGAArchetypeCatalog

const TAG_DIVE := "Dive"
const TAG_POKE := "Poke"
const TAG_SUSTAIN := "Sustain"
const TAG_TENACITY := "Tenacity"
const TAG_PEEL := "Peel"
const TAG_ANTI_HEAL := "AntiHeal"

# Each entry is pure data describing a roster archetype used by higher-level builders.
const _ARCHETYPES := [
    {
        "id": "dive_collapse_alpha",
        "name": "Collapse Alpha Dive",
        "description": "Double-tank engage with layered burst to collapse on priority targets.",
        "unit_ids": ["grint", "bo", "hexeon", "creep", "mortem"],
        "tags": [TAG_DIVE],
    },
    {
        "id": "poke_siege_pressure",
        "name": "Siege Pressure Poke",
        "description": "Long-range zoning core that chips opponents before committing.",
        "unit_ids": ["paisley", "volt", "luna", "nyxa", "teller"],
        "tags": [TAG_POKE],
    },
    {
        "id": "sustain_eternal_watch",
        "name": "Eternal Watch Sustain",
        "description": "Attrition frontline with layered heals and self-sustain loops.",
        "unit_ids": ["axiom", "bonko", "morrak", "berebell", "kythera"],
        "tags": [TAG_SUSTAIN, TAG_TENACITY],
    },
    {
        "id": "tenacity_bastion_wall",
        "name": "Bastion Wall Tenacity",
        "description": "High-durability wall that shrugs burst and locks threats in place.",
        "unit_ids": ["korath", "brute", "kythera", "repo", "axiom"],
        "tags": [TAG_TENACITY, TAG_PEEL],
    },
    {
        "id": "peel_carry_screen",
        "name": "Carry Screen Peel",
        "description": "Carry-centric backline with layered peel and emergency cleanses.",
        "unit_ids": ["totem", "axiom", "paisley", "repo", "sari"],
        "tags": [TAG_PEEL, TAG_SUSTAIN],
    },
    {
        "id": "antiheal_suppression_lance",
        "name": "Suppression Lance AntiHeal",
        "description": "Debuff-heavy core focused on cutting sustain and forcing short fights.",
        "unit_ids": ["volt", "teller", "kythera", "mortem", "paisley"],
        "tags": [TAG_ANTI_HEAL, TAG_POKE],
    },
]

func list_all() -> Array:
    var out: Array = []
    for entry in _ARCHETYPES:
        out.append(entry.duplicate(true))
    return out

func list_ids() -> PackedStringArray:
    var ids: PackedStringArray = []
    for entry in _ARCHETYPES:
        var raw := String(entry.get("id", "")).strip_edges()
        if raw != "":
            ids.append(raw)
    return ids

func get(id: String) -> Dictionary:
    var want := String(id).strip_edges()
    if want == "":
        return {}
    for entry in _ARCHETYPES:
        if String(entry.get("id", "")) == want:
            return entry.duplicate(true)
    return {}

func with_tag(tag: String) -> Array:
    var want := String(tag).strip_edges()
    if want == "":
        return []
    var want_lower := want.to_lower()
    var out: Array = []
    for entry in _ARCHETYPES:
        var tags: Array = entry.get("tags", [])
        for raw_tag in tags:
            if String(raw_tag).to_lower() == want_lower:
                out.append(entry.duplicate(true))
                break
    return out

func tags() -> PackedStringArray:
    return PackedStringArray([TAG_DIVE, TAG_POKE, TAG_SUSTAIN, TAG_TENACITY, TAG_PEEL, TAG_ANTI_HEAL])

func has(id: String) -> bool:
    return not get(id).is_empty()
