# Balance Runner CSV Schema

## identity_v2 (Current)

- A `schema_version` column prefixes every row (current value: `identity_v2`).
- Primary identity columns were added: `attacker_primary_role`, `defender_primary_role`, `attacker_primary_goal`, `defender_primary_goal`, `attacker_approaches`, `defender_approaches`.
- Legacy `attacker_roles` / `defender_roles` columns were removed; approach lists continue to use `|` separators.
  

### Column Order

```
schema_version,attacker_id,defender_id,attacker_primary_role,defender_primary_role,
attacker_primary_goal,defender_primary_goal,attacker_approaches,defender_approaches,
attacker_cost,defender_cost,attacker_level,defender_level,attacker_win_pct,defender_win_pct,
draw_pct,attacker_avg_time_to_win_s,defender_avg_time_to_win_s,attacker_avg_remaining_hp,
defender_avg_remaining_hp,matches_total,hit_events_total,attacker_hit_events,defender_hit_events,
attacker_avg_damage_dealt_per_match,defender_avg_damage_dealt_per_match,attacker_healing_total,
defender_healing_total,attacker_shield_absorbed_total,defender_shield_absorbed_total,
attacker_damage_mitigated_total,defender_damage_mitigated_total,attacker_overkill_total,
defender_overkill_total,attacker_damage_physical_total,defender_damage_physical_total,
attacker_damage_magic_total,defender_damage_magic_total,attacker_damage_true_total,
defender_damage_true_total,attacker_time_to_first_hit_s,defender_time_to_first_hit_s
```

Optional ability-metric columns (`attacker_avg_casts_per_match`, `defender_avg_casts_per_match`, `attacker_first_cast_time_s`, `defender_first_cast_time_s`) remain unchanged and are appended when recorded.

## Usage

BalanceRunner writes a single results CSV in the identity_v2 format.

Example:
```
godot --headless -s tests/balance_runner/balance_runner.gd -- \
  --out=user://balance_matrix.csv \
  --repeats=10 --timeout=120 \
  --role=marksman,mage --goal=brawler.frontline_disruption --cost=1,2,3 \
  --ids=bonko:grint \
  --abilities=true --ability_metrics=true
```
