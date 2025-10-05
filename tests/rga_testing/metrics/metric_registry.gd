extends RefCounted
class_name MetricRegistry

const METRIC_ROOT := "res://tests/rga_testing/metrics"
const TEST_SUFFIX := "_test.gd"

static func run_all(available_caps: PackedStringArray = PackedStringArray(), context: Dictionary = {}, filters: Array = []) -> Dictionary:
    var descriptors := _discover(filters)
    var norm_caps := _normalize_caps(available_caps)
    var cap_set := {}
    for cap in norm_caps:
        cap_set[cap] = true
    var results: Array = []
    var passed_all := true
    var failed := 0
    var skipped := 0
    var errors := 0
    for desc in descriptors:
        var required_caps: PackedStringArray = desc.get("required_capabilities", PackedStringArray())
        var missing := _missing_caps(required_caps, cap_set)
        if missing.size() > 0:
            skipped += 1
            results.append({
                "id": desc.get("id"),
                "version": desc.get("version"),
                "status": "skipped",
                "reason": "missing_capabilities",
                "missing_capabilities": missing,
                "path": desc.get("path"),
                "spans": [],
                "required_capabilities": required_caps
            })
            continue
        var run_result := _run_metric(desc, norm_caps, context)
        var status := String(run_result.get("status", "error"))
        match status:
            "pass":
                pass
            "fail":
                failed += 1
                passed_all = false
            "error":
                errors += 1
                passed_all = false
            _:
                failed += 1
                passed_all = false
        results.append(run_result)
    return {
        "passed": passed_all,
        "metrics": results,
        "failed_count": failed,
        "skipped_count": skipped,
        "error_count": errors
    }

static func list_metrics(filters: Array = []) -> Array:
    var descriptors := _discover(filters)
    var out: Array = []
    for desc in descriptors:
        out.append({
            "id": desc.get("id"),
            "version": desc.get("version"),
            "path": desc.get("path"),
            "required_capabilities": desc.get("required_capabilities", PackedStringArray()),
            "description": desc.get("description", "")
        })
    return out

# --- discovery -----------------------------------------------------------

static func _discover(filters: Array = []) -> Array:
    var files := _collect_metric_files()
    files.sort()
    var filter_set := {}
    for f in filters:
        filter_set[String(f)] = true
    var descriptors: Array = []
    for path in files:
        var script := load(path)
        if script == null:
            push_warning("MetricRegistry: failed to load metric script at " + path)
            continue
        var instance = null
        if script is Script:
            instance = script.new()
        if instance == null:
            push_warning("MetricRegistry: unable to instantiate metric " + path)
            continue
        var meta := {}
        if instance.has_method("get_metadata"):
            meta = instance.get_metadata()
        if instance is RefCounted:
            instance = null
        var desc := _normalize_descriptor(meta, path)
        if filter_set.size() > 0 and not filter_set.has(desc.get("id")):
            continue
        descriptors.append(desc)
    descriptors.sort_custom(_DescriptorSorter.new(), "compare")
    return descriptors

class _DescriptorSorter:
    func compare(a, b) -> bool:
        var id_a := String(a.get("id", ""))
        var id_b := String(b.get("id", ""))
        if id_a == id_b:
            return String(a.get("path", "")) < String(b.get("path", ""))
        return id_a < id_b

static func _normalize_descriptor(meta: Dictionary, path: String) -> Dictionary:
    var id := String(meta.get("id", _id_from_path(path))).strip_edges()
    if id == "":
        id = _id_from_path(path)
    var version := String(meta.get("version", "1.0.0")).strip_edges()
    var required_caps := _normalize_caps(meta.get("required_capabilities", []))
    var description := String(meta.get("description", ""))
    return {
        "id": id,
        "version": version,
        "required_capabilities": required_caps,
        "description": description,
        "path": path
    }

static func _collect_metric_files() -> Array:
    var out: Array = []
    _collect_recursive(METRIC_ROOT, out)
    return out

static func _collect_recursive(dir_path: String, out: Array) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    while true:
        var name := dir.get_next()
        if name == "":
            break
        if name.begins_with('.'):
            continue
        if dir.current_is_dir():
            _collect_recursive(dir_path + "/" + name, out)
        else:
            if name.ends_with(TEST_SUFFIX):
                out.append(dir_path + "/" + name)
    dir.list_dir_end()

# --- execution -----------------------------------------------------------

static func _run_metric(desc: Dictionary, norm_caps: PackedStringArray, context: Dictionary) -> Dictionary:
    var path := String(desc.get("path", ""))
    var script := load(path)
    if script == null:
        push_warning("MetricRegistry: failed to load metric script at " + path)
        return {
            "id": desc.get("id"),
            "version": desc.get("version"),
            "status": "error",
            "path": path,
            "message": "load_failed",
            "spans": [],
            "required_capabilities": desc.get("required_capabilities", PackedStringArray())
        }
    var instance = null
    if script is Script:
        instance = script.new()
    if instance == null:
        return {
            "id": desc.get("id"),
            "version": desc.get("version"),
            "status": "error",
            "path": path,
            "message": "instantiate_failed",
            "spans": [],
            "required_capabilities": desc.get("required_capabilities", PackedStringArray())
        }
    var payload := {
        "context": context,
        "available_capabilities": norm_caps,
        "id": desc.get("id"),
        "version": desc.get("version")
    }
    var run_callable := Callable()
    if instance.has_method("run_metric"):
        run_callable = Callable(instance, "run_metric")
    elif instance.has_method("run"):
        run_callable = Callable(instance, "run")
    else:
        if instance.has_method("cleanup"):
            instance.cleanup()
        if instance is RefCounted:
            instance = null
        return {
            "id": desc.get("id"),
            "version": desc.get("version"),
            "status": "error",
            "path": path,
            "message": "missing_run_method",
            "spans": [],
            "required_capabilities": desc.get("required_capabilities", PackedStringArray())
        }
    var run_result := {}
    var spans: Array = []
    var message := ""
    var status := "error"
    var passed := false
    var argc := _resolve_method_argc(instance, String(run_callable.get_method()))
    var call_result
    if argc <= 0:
        call_result = run_callable.call()
    else:
        call_result = run_callable.call(payload)
    if call_result is Dictionary:
        run_result = call_result
    else:
        run_result = {"pass": bool(call_result)}
    passed = bool(run_result.get("pass", false))
    spans = run_result.get("spans", []) if run_result.has("spans") else []
    if not (spans is Array):
        spans = []
    message = String(run_result.get("message", ""))
    status = "pass" if passed else "fail"
    var details := {}
    if run_result is Dictionary:
        details = run_result.duplicate(true)
    if instance.has_method("cleanup"):
        instance.cleanup()
    if instance is RefCounted:
        instance = null
    return {
        "id": desc.get("id"),
        "version": desc.get("version"),
        "status": status,
        "path": path,
        "spans": spans,
        "message": message,
        "required_capabilities": desc.get("required_capabilities", PackedStringArray()),
        "details": details
    }

# --- helpers -------------------------------------------------------------

static func _normalize_caps(caps) -> PackedStringArray:
    var out: PackedStringArray = []
    var seen := {}
    if caps == null:
        return out
    var arr: Array = []
    if caps is PackedStringArray:
        for v in caps:
            arr.append(v)
    elif caps is Array:
        arr = caps
    else:
        arr = [caps]
    for v in arr:
        var s := String(v).strip_edges().to_lower()
        if s == "":
            continue
        if seen.has(s):
            continue
        seen[s] = true
        out.append(s)
    out.sort()
    return out

static func _missing_caps(required: PackedStringArray, available_set: Dictionary) -> Array:
    var missing: Array = []
    for cap in required:
        if not available_set.has(cap):
            missing.append(cap)
    return missing

static func _id_from_path(path: String) -> String:
    var file := path.get_file()
    if file.ends_with(TEST_SUFFIX):
        file = file.substr(0, file.length() - TEST_SUFFIX.length())
    return file.to_lower()

static func _resolve_method_argc(obj, method_name: String) -> int:
    if obj == null:
        return 0
    if not obj.has_method(method_name):
        return 0
    for meta in obj.get_method_list():
        if String(meta.get("name", "")) == method_name:
            var args = meta.get("args", [])
            return args.size() if args is Array else 0
    return 0
