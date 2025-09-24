Attack Resolver Split (Modules)

- orchestration/resolver_services.gd — wires and exposes all sub-services.
- orchestration/ordered_attack_processor.gd — per-event processing; rolls + fires projectiles.
- orchestration/target_assigner.gd — assigns/refreshes targets via TargetController.
- orchestration/post_hit_coordinator.gd — totals/frame increments, mana gain, emits analytics.
- orchestration/frame_status_calculator.gd — computes per-frame defeat flags.
- orchestration/cd_service.gd — read-only cooldown helpers and snapshots.
- projectile/projectile_policy.gd — base retarget + extra shots (MultishotSelector + ProjectileEmitter).
- support/team_utils.gd — unit/team helpers (single source of truth for lookups).
- support/combat_stats.gd — tracks totals + frame damage.
- legacy/pair_resolver.gd — deprecated pair path, stubbed for compatibility.
- abilities/ability_utils.gd — convenience helper for ability names via AbilityCatalog.

Single sources of truth respected:
- Damage/mitigation in DamageMath + AttackImpact pipeline.
- Shields/CC/tags in BuffSystem; do not read tags directly from modules.
- CD scheduling in CooldownScheduler; cd_service is read-only.
- Range checks in MovementMath; epsilon from MovementService.tuning.
- Signal emissions via CombatEvents only.

Overrides
- You can override modules at wiring time by passing an `overrides` Dictionary to `ResolverServices.configure(...)`.
- Keys (see `ResolverServices.KEYS`): `events`, `roller`, `impact`, `shield_service`, `hooks`, `projectile_emitter`, `multishot`, `mana_service`, `cd_service`, `stats`, `frame_calc`, `post_hit`, `projectile_policy`, `target_assigner`, `ordered_processor`.
- Example:
  - var services := ResolverServices.new()
  - var custom_policy := preload("res://scripts/game/combat/attack/variants/example_projectile_policy.gd").new()
  - services.configure(state, target_controller, rng, player_ref, emitters, ability_system, buff_system, deterministic, { ResolverServices.KEYS.projectile_policy: custom_policy })
