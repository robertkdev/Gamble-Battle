extends RefCounted
class_name ProjectileHandler

var resolver: AttackResolver

func configure(_resolver: AttackResolver) -> void:
    resolver = _resolver

func handle_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> Dictionary:
    if not resolver:
        return {"processed": false}
    return resolver.apply_projectile_hit(source_team, source_index, target_index, damage, crit, true)
