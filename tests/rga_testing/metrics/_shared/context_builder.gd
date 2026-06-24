extends RefCounted
class_name RoleMetricsContextBuilder

const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")

# Build a slim, reusable metrics context for role tests.
# - Loads NDJSON from a file or directory path
# - Validates required capabilities
# - Indexes aggregates/derived per simulation (by sim_index)
# - Tags scenario label (neutral/counter) using a hint or simple heuristics
# Returns Dictionary:
# {
#   ok: bool,
#   missing_caps: string[],
#   scenario: string,               # neutral | counter | unknown
#   caps_present: string[],
#   sims: { sim_index: { context, outcome, teams, units, derived, kernels } },
#   files: string[]                 # consumed file paths (for provenance)
# }

static func build(path: String, required_caps: PackedStringArray = PackedStringArray(), scenario_hint: String = "") -> Dictionary:
    var files := _collect_files(String(path))
    var rows := _load_rows(files)
    var caps_union := _union_caps(rows)
    var missing := _missing_caps(caps_union, TelemetryCapabilities.normalize(required_caps))
    var sims := _index_by_sim(rows)
    var scen := _derive_scenario(rows, _infer_scenario(scenario_hint, String(path)))
    return {
        "ok": missing.is_empty(),
        "missing_caps": missing,
        "scenario": scen,
        "caps_present": caps_union,
        "sims": sims,
        "files": files
    }

# --- File collection & loading ------------------------------------------

static func _collect_files(path: String) -> Array[String]:
    var out: Array[String] = []
    var p := String(path).strip_edges()
    if p == "":
        return out
    # If explicit file (supports res:// and user:// schemes)
    if FileAccess.file_exists(p):
        if p.ends_with(".jsonl") or p.ends_with(".ndjson"):
            out.append(p)
        return out
    # Try directory (support virtual paths like user:// as well as absolute)
    var dir := DirAccess.open(p)
    if dir == null:
        return out
    dir.list_dir_begin()
    while true:
        var name := dir.get_next()
        if name == "":
            break
        if dir.current_is_dir():
            continue
        if name.ends_with(".jsonl") or name.ends_with(".ndjson"):
            out.append(p.rstrip("/\\") + "/" + name)
    dir.list_dir_end()
    return out

static func _load_rows(files: Array[String]) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    for f in files:
        var fa := FileAccess.open(f, FileAccess.READ)
        if fa == null:
            continue
        while not fa.eof_reached():
            var line := fa.get_line()
            if String(line).strip_edges() == "":
                continue
            var parsed = JSON.parse_string(line)
            if parsed is Dictionary:
                rows.append(parsed)
        fa.close()
    return rows

# --- Caps ----------------------------------------------------------------

static func _union_caps(rows: Array[Dictionary]) -> PackedStringArray:
    var seen: Dictionary = {}
    for r in rows:
        var ctx = r.get("context", {})
        if ctx is Dictionary:
            var caps = ctx.get("capabilities", [])
            var arr := []
            if caps is Array:
                arr = caps
            elif caps is PackedStringArray:
                for v in (caps as PackedStringArray):
                    arr.append(v)
            for v2 in arr:
                var s := String(v2).strip_edges().to_lower()
                if s != "": seen[s] = true
    var out: PackedStringArray = []
    for k in seen.keys(): out.append(String(k))
    out.sort()
    return out

static func _missing_caps(present: PackedStringArray, required: PackedStringArray) -> Array[String]:
    var cap_set: Dictionary = {}
    for c in present:
        cap_set[String(c)] = true
    var missing: Array[String] = []
    for r in required:
        var s := String(r)
        if not cap_set.has(s):
            missing.append(s)
    return missing

# --- Indexing ------------------------------------------------------------

static func _index_by_sim(rows: Array[Dictionary]) -> Dictionary:
    var by_sim: Dictionary = {}
    for r in rows:
        var ctx: Dictionary = r.get("context", {})
        if not (ctx is Dictionary):
            continue
        var sim_idx := int(ctx.get("sim_index", -1))
        if sim_idx < 0:
            continue
        var agg: Dictionary = r.get("aggregates", {})
        var out := {
            "context": {
                "team_a_ids": ctx.get("team_a_ids", []),
                "team_b_ids": ctx.get("team_b_ids", []),
                "team_size": ctx.get("team_size", 0),
                "capabilities": ctx.get("capabilities", []),
                "scenario_label": _scenario_from_map_params(ctx.get("map_params", {}))
            },
            "outcome": r.get("engine_outcome", {}),
            "teams": (agg.get("teams", {}) if agg is Dictionary else {}),
            "units": (agg.get("units", {}) if agg is Dictionary else {}),
            "derived": (agg.get("derived", {}) if agg is Dictionary else {}),
            "kernels": (agg.get("kernels", {}) if agg is Dictionary else {})
        }
        by_sim[str(sim_idx)] = out
    return by_sim

# --- Scenario label ------------------------------------------------------

static func _infer_scenario(hint: String, provenance_path: String) -> String:
    var s := String(hint).strip_edges().to_lower()
    if s in ["neutral", "counter"]:
        return s
    var p := String(provenance_path).strip_edges().to_lower()
    if p.find("neutral") >= 0:
        return "neutral"
    if p.find("counter") >= 0:
        return "counter"
    return "unknown"

static func _scenario_from_map_params(mp) -> String:
    if not (mp is Dictionary):
        return ""
    var label = String((mp as Dictionary).get("scenario_label", "")).strip_edges().to_lower()
    return label

static func _derive_scenario(rows: Array[Dictionary], fallback: String) -> String:
    # Majority vote across rows using context.map_params.scenario_label; fallback when absent.
    var counts: Dictionary = {}
    for r in rows:
        var ctx: Dictionary = r.get("context", {})
        if not (ctx is Dictionary):
            continue
        var mp: Dictionary = ctx.get("map_params", {})
        var label := _scenario_from_map_params(mp)
        if label == "":
            continue
        counts[label] = int(counts.get(label, 0)) + 1
    var best := ""
    var best_n := 0
    for k in counts.keys():
        var n := int(counts.get(k, 0))
        if n > best_n:
            best_n = n
            best = String(k)
    if best != "":
        return best
    return fallback
