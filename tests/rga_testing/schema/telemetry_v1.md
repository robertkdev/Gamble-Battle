# Telemetry Schema v1 (NDJSON)

Each line in the NDJSON file is a single simulation row with the following top-level fields:

```
{
  "schema_version": "telemetry_v1",
  "context": { ... },
  "engine_outcome": { ... },
  "aggregates": { ... },
  "events": [ ... ] | null
}
```

Notes
- Rows are independent and self-describing. Consumers can stream them line by line.
- All strings are lowercase where they are identifiers; display names are out of scope.
- Events may be omitted (null) to reduce file size; presence is indicated by `context.capabilities`.

## Context

Provenance, scenario, rosters, and map snapshot used to interpret aggregates/events.

```
context: {
  run_id: string,
  sim_index: int,             // sequential index within a run
  sim_seed: int,              // PRNG seed for deterministic replay
  engine_version: string,     // optional; can be empty
  asset_hash: string,         // optional; content hash of assets/units

  scenario_id: string,        // e.g., "open_field"
  map_id: string,             // e.g., "open_field_basic"
  map_params: { ... },        // freeform scalar map of scenario parameters

  team_a_ids: string[],       // unit ids, order = spawn order
  team_b_ids: string[],
  team_size: int,

  tile_size: number,
  arena_bounds: { x: number, y: number, w: number, h: number },
  spawn_a: number[][],        // [[x,y], ...] world coords
  spawn_b: number[][],

  capabilities: string[]      // telemetry families present (see Capabilities)
}
```

## Engine Outcome

Summary of the combat resolution.

```
engine_outcome: {
  result: string,     // "team_a" | "team_b" | "draw" | "timeout"
  reason: string,     // optional, implementation-specific
  time_s: number,     // simulated seconds (float)
  frames: int,        // processed frames (int)
  team_a_alive: int,  // survivors
  team_b_alive: int
}
```

## Aggregates (Base)

Produced by the base combat stats collector. Per-team totals plus per-unit breakdowns.

```
aggregates: {
  teams: {
    a: TeamTotals,
    b: TeamTotals
  },
  units: {
    a: UnitTotals[],
    b: UnitTotals[]
  }
}

TeamTotals: {
  damage: int,
  healing: int,
  shield: int,
  mitigated: int,
  overkill: int,
  kills: int,
  deaths: int,
  casts: int,
  first_hit_s: number,   // -1.0 if none
  first_cast_s: number   // -1.0 if none
}

UnitTotals: {
  damage: int,
  healing: int,
  shield: int,
  mitigated: int,
  overkill: int,
  kills: int,
  deaths: int,
  casts: int,
  time_alive_s: number,  // seconds until death or match end
  first_hit_s: number,   // -1.0 if none
  first_cast_s: number   // -1.0 if none
}
```

Derived metrics (RGA-specific) will be added as additional namespaced fields in `aggregates` by separate plugins in later phases.

## Events (Optional)

Events are included when enabled by the run configuration and supported by `context.capabilities`. Each event entry:

```
{
  t_s: number,        // event time in seconds (float)
  kind: string,       // event family
  data: { ... }       // event-specific payload
}
```

Base families and payloads (v1):
- hit_applied: { team, sidx, tidx, rolled, dealt, crit, before_hp, after_hp }
- heal_applied: { st, si, tt, ti, healed, overheal, before_hp, after_hp }
- shield_absorbed: { tt, ti, absorbed }
- hit_mitigated: { st, si, tt, ti, pre_mit, post_pre_shield }
- hit_overkill: { st, si, tt, ti, overkill }
- hit_components: { st, si, tt, ti, phys, mag, tru }
- cc_applied: { st, si, tt, ti, kind, dur }

Event presence is not guaranteed; always branch on `context.capabilities` and `events != null`.

## Capabilities

Indicates which telemetry families are present in the row. Known flags:
- base        - base aggregates and outcome
- cc          - crowd-control events (cc_applied/refresh/expired)
- mobility    - movement/mobility events and periodic positions
- zones       - zone create/update/expire events and occupancy
- targets     - target acquisition/loss events

Consumers should treat unknown flags as ignorable (forward-compatible).

## Time & Ordering

- Time fields ending with `_s` are seconds (float). Frame counts are integers.
- `events` are recorded in processing order; consumers may sort by `t_s` if needed.
- For deterministic runs, `context.sim_seed` plus the telemetry is sufficient to replay the outcome.

## Versioning & Compatibility

- `schema_version` is a string. Breaking changes create a new version (e.g., `telemetry_v2`).
- New optional fields may be added without a version bump; consumers should ignore unknown fields.


