extends Resource
class_name UnitDef

const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")

@export var id: String = ""
@export var name: String = ""
@export var sprite_path: String = ""

# Core stats (single source of truth)
# Health & regen
@export var max_hp: int = 500
@export var hp_regen: float = 0.0

# Offense
@export var attack_damage: float = 50.0   # AD
@export var spell_power: float = 0.0      # SP
@export var attack_speed: float = 1.0     # AS (attacks/sec)
@export var crit_chance: float = 0.00     # 0..1
@export var crit_damage: float = 1.5      # multiplier
@export var true_damage: float = 0.0      # flat true dmg per attack/instance
@export var lifesteal: float = 0.0        # 0..1 (omnivamp behavior decided by combat)
@export var attack_range: int = 1         # tiles

# Defense & penetration
@export var armor: float = 20.0
@export var magic_resist: float = 0.0
@export var armor_pen_flat: float = 0.0
@export var armor_pen_pct: float = 0.0    # 0..1
@export var mr_pen_flat: float = 0.0
@export var mr_pen_pct: float = 0.0       # 0..1

# Resource & casting
@export var mana: int = 0                 # mana/ability cost (required to cast)
@export var mana_regen: float = 0.0       # per second
@export var mana_start: float = 0.0       # initial mana at round start
@export var cast_speed: float = 1.0       # 1.0 = baseline; >1 faster cast

# Content/metadata
@export var ability_id: String = ""       # links to data/abilities/*.tres
@export var traits: Array[String] = []
@export var roles: Array[String] = []
@export var damage_type: String = "Attack" # Attack | Magic | Hybrid-Additive | Hybrid-Either
@export var power_level: int = 1

@export var primary_role: String = ""
@export var primary_goal: String = ""
@export var approaches: Array[String] = []
@export var alt_goals: Array[String] = []
@export var identity: UnitIdentity = null

# Economy/scaling
@export var cost: int = 1
@export var level: int = 1
