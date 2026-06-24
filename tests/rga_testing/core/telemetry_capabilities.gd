extends RefCounted
class_name TelemetryCapabilities

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")

# Capability flags indicate which telemetry families are present in a row.
# Keep identifiers short, lowercase, and stable for schema consumers.

const CAP_BASE := "base"        # always present: damage/heal/shield/mitigated, basic outcomes
const CAP_CC := "cc"            # cc_applied/refresh/expired events
const CAP_MOBILITY := "mobility" # mobility start/end; position_updated cadence
const CAP_ZONES := "zones"      # zone exposure/create/update/expire; occupancy
const CAP_TARGETS := "targets"  # target_start/target_end events
const CAP_BUFFS := "buffs"      # buff/debuff/cleanse/cc-immunity events
const CAP_TARGETABILITY := "targetability" # targetability windows and threat-dodge interactions
const CAP_COOLDOWN_PRESSURE := "cooldown_pressure" # committed ability responses and cooldowns forced
const CAP_COUNTERPLAY_PRESSURE := "counterplay_pressure" # cleanse pressure, tenacity tax, and CC immunity tax
const CAP_RAMP_STATE := "ramp_state" # direct stack/window state changes for ramp approaches

static func all_caps() -> PackedStringArray:
    return PackedStringArray([CAP_BASE, CAP_CC, CAP_MOBILITY, CAP_ZONES, CAP_TARGETS, CAP_BUFFS, CAP_TARGETABILITY, CAP_COOLDOWN_PRESSURE, CAP_COUNTERPLAY_PRESSURE, CAP_RAMP_STATE])

static func normalize(caps) -> PackedStringArray:
    var out: PackedStringArray = []
    var seen: Dictionary = {}
    if caps == null:
        return out
    var arr: Array = []
    if caps is Array:
        arr = caps
    elif caps is PackedStringArray:
        for v in caps:
            arr.append(v)
    elif typeof(caps) == TYPE_STRING:
        arr = [caps]
    for v in arr:
        var s := String(v).strip_edges().to_lower()
        if s == "":
            continue
        if not seen.has(s):
            seen[s] = true
            out.append(s)
    out.sort()
    return out

static func has(caps, cap: String) -> bool:
    var norm := normalize(caps)
    return norm.has(String(cap).strip_edges().to_lower())

static func attach_to_row(row: DataModels.TelemetryRow, caps) -> void:
    if row == null or row.context == null:
        return
    var norm := normalize(caps)
    # Ensure base present at minimum
    if not norm.has(CAP_BASE):
        norm.append(CAP_BASE)
        norm.sort()
    row.context.capabilities = norm
