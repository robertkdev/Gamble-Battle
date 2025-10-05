extends RefCounted
class_name TeamBuilder

const RGASettings = preload("res://tests/rga_testing/settings.gd")
const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const RGACatalogScript = preload("res://tests/rga_testing/io/unit_catalog.gd")

# Build 1v1 SimJobs from explicit ids or filtered unit catalog.
# Symmetry reduction: each unordered pair appears at most once.
func build_1v1(settings: RGASettings) -> Array:
    var pairs: Array = []
    var catalog = RGACatalogScript.new()
    var units_info: Array = catalog.list(settings)
    var available_ids := _ids_from(units_info)

    if settings.ids != null and settings.ids.size() > 0:
        pairs = _canonicalize_explicit_pairs(settings.ids, available_ids)
    else:
        pairs = _enumerate_pairs(available_ids)

    var jobs: Array = []
    var idx := 0
    for p in pairs:
        var a: String = String(p.get("a", "")).strip_edges()
        var b: String = String(p.get("b", "")).strip_edges()
        if a == "" or b == "":
            continue
        var job := DataModels.SimJob.new()
        job.run_id = String(settings.run_id)
        job.sim_index = idx
        job.seed = int(settings.sim_seed_start) + idx
        job.team_a_ids = [a]
        job.team_b_ids = [b]
        job.team_size = 1
        job.scenario_id = "open_field"
        job.map_params = {}
        job.deterministic = bool(settings.deterministic)
        job.delta_s = 0.05
        job.timeout_s = float(settings.timeout_s)
        job.abilities = bool(settings.abilities)
        job.ability_metrics = bool(settings.ability_metrics)
        job.alternate_order = false
        job.bridge_projectile_to_hit = true
        job.capabilities = ["base"]
        jobs.append(job)
        idx += 1
    return jobs

func _ids_from(infos: Array) -> Array:
    var out: Array = []
    for d in infos:
        if d is Dictionary:
            var v := String(d.get("id", "")).strip_edges()
            if v != "":
                out.append(v)
    out.sort() # deterministic order
    return out

func _enumerate_pairs(ids: Array) -> Array:
    var out: Array = []
    for i in range(ids.size()):
        for j in range(i + 1, ids.size()):
            out.append({"a": ids[i], "b": ids[j]})
    return out

func _canonicalize_explicit_pairs(explicit: Array, available_ids: Array) -> Array:
    var have: Dictionary = {}
    var set_ids: Dictionary = {}
    for id in available_ids:
        set_ids[String(id)] = true
    var out: Array = []
    for p in explicit:
        if not (p is Dictionary):
            continue
        var a := String(p.get("a", "")).strip_edges()
        var b := String(p.get("b", "")).strip_edges()
        if a == "" or b == "":
            continue
        if not set_ids.has(a) or not set_ids.has(b):
            push_warning("TeamBuilder: unknown id in pair %s:%s (skipped)" % [a, b])
            continue
        var ca := a
        var cb := b
        if cb < ca:
            var tmp := ca
            ca = cb
            cb = tmp
        var key := ca + "|" + cb
        if have.has(key):
            continue
        have[key] = true
        out.append({"a": ca, "b": cb})
    out.sort_custom(func(x, y): return _pair_key(x) < _pair_key(y))
    return out

func _pair_key(pair: Dictionary) -> String:
    return String(pair.get("a", "")) + "|" + String(pair.get("b", ""))

