extends RefCounted
class_name RGAProvenance

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")

# Build a provenance dictionary for a simulation context. Consumers may append overrides
# (e.g., engine version computed at runtime) without mutating the underlying context object.
static func build(ctx: DataModels.MatchContext, overrides: Dictionary = {}) -> Dictionary:
    if ctx == null:
        return {}
    var prov := {
        "run_id": String(ctx.run_id),
        "sim_index": int(ctx.sim_index),
        "sim_seed": int(ctx.sim_seed),
        "engine_version": String(ctx.engine_version),
        "asset_hash": String(ctx.asset_hash),
        "scenario_id": String(ctx.scenario_id),
        "map_id": String(ctx.map_id),
        "capabilities": _capabilities_to_array(ctx.capabilities),
    }
    if overrides != null:
        for k in overrides.keys():
            prov[k] = overrides[k]
    return prov

# Convenience helper: attach provenance to a telemetry row's aggregates block.
static func attach(row: DataModels.TelemetryRow, overrides: Dictionary = {}) -> Dictionary:
    if row == null:
        return {}
    var prov := build(row.context, overrides)
    if row.aggregates == null:
        row.aggregates = {}
    row.aggregates["provenance"] = prov
    return prov

static func _capabilities_to_array(raw) -> Array[String]:
    var out: Array[String] = []
    if raw == null:
        return out
    if raw is PackedStringArray:
        for v in raw:
            var s := String(v).strip_edges()
            if s != "":
                out.append(s)
        return out
    if raw is Array:
        for v2 in raw:
            var s2 := String(v2).strip_edges()
            if s2 != "":
                out.append(s2)
        return out
    var single := String(raw).strip_edges()
    if single != "":
        out.append(single)
    return out
