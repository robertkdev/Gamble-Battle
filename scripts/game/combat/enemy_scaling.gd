extends Object
class_name EnemyScaling

# Centralized enemy stage-scaling configuration.
# Set ENABLED to true to re-enable difficulty scaling by stage.
# Default is false (disabled) as requested.

const ENABLED := false

# Multipliers applied per stage above 1 when ENABLED=true.
const HP_PER_STAGE := 1.15
const ATK_PER_STAGE := 1.10

static func apply_for_stage(units: Array, stage: int) -> void:
    # No-op unless explicitly enabled.
    if not ENABLED:
        return
    var s: int = max(0, int(stage) - 1)
    if s <= 0:
        return
    var hp_mult: float = pow(HP_PER_STAGE, s)
    var atk_mult: float = pow(ATK_PER_STAGE, s)
    for u in units:
        if u == null:
            continue
        u.max_hp = int(round(float(u.max_hp) * hp_mult))
        u.hp = u.max_hp
        u.attack_damage = int(round(float(u.attack_damage) * atk_mult))

