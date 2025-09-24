extends ProjectilePolicy

# Example variant demonstrating how to override a module.
# Identical behavior; place custom logic here and register via ResolverServices.configure(..., overrides={}).

func emit_shots(team: String, shooter_index: int, default_target: int, rolled_damage: int, crit: bool) -> int:
    # Defer to base implementation for parity
    return .emit_shots(team, shooter_index, default_target, rolled_damage, crit)

