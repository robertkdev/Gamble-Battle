extends RefCounted
class_name RGADataModels

# Small, typed DTOs only. No logic.

class SimJob:
    extends RefCounted
    # Identity
    var run_id: String = ""
    var sim_index: int = 0
    var seed: int = 0

    # Rosters
    var team_a_ids: Array[String] = []
    var team_b_ids: Array[String] = []
    var team_size: int = 1

    # Scenario
    var scenario_id: String = "open_field"
    var map_params: Dictionary = {}

    # Engine config
    var deterministic: bool = true
    var delta_s: float = 0.05
    var timeout_s: float = 120.0
    var abilities: bool = false
    var ability_metrics: bool = false
    var alternate_order: bool = false
    var bridge_projectile_to_hit: bool = false

    # Requested telemetry capabilities (e.g., ["base","cc","targets","mobility","zones"]).
    var capabilities: PackedStringArray = PackedStringArray()

    # Free-form metadata for experiment/tagging.
    var metadata: Dictionary = {}


class MatchContext:
    extends RefCounted
    # Provenance
    var run_id: String = ""
    var sim_index: int = 0
    var sim_seed: int = 0
    var engine_version: String = ""
    var asset_hash: String = ""

    # Scenario
    var scenario_id: String = "open_field"
    var map_id: String = ""
    var map_params: Dictionary = {}

    # Rosters
    var team_a_ids: Array[String] = []
    var team_b_ids: Array[String] = []
    var team_size: int = 1

    # Arena snapshot (optional)
    var tile_size: float = 1.0
    var arena_bounds: Rect2 = Rect2()
    var spawn_a: Array[Vector2] = []
    var spawn_b: Array[Vector2] = []

    # Telemetry capability flags included in this row
    var capabilities: PackedStringArray = PackedStringArray()


class EngineOutcome:
    extends RefCounted
    # Result: "team_a" | "team_b" | "draw" | "timeout"
    var result: String = "draw"
    var reason: String = ""       # Optional engine-specific reason
    var time_s: float = 0.0
    var frames: int = 0
    var team_a_alive: int = 0
    var team_b_alive: int = 0


class TelemetryRow:
    extends RefCounted
    var schema_version: String = "telemetry_v1"
    var context: MatchContext
    var engine_outcome: EngineOutcome
    # Aggregates are produced by base/derived aggregators; shape is documented in schema.
    var aggregates: Dictionary = {}
    # Event stream is optional (heavy); present only when enabled.
    var events: Array = []

