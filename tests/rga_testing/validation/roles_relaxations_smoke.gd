extends Node

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RoleMetricsContextBuilder := preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var ok := true
    ok = _assert_assassin_peel_relaxation() and ok
    ok = _assert_tank_burst_relaxation() and ok
    ok = _assert_frontline_window_kernel() and ok
    if ok:
        print("RolesRelaxationsSmoke: PASS")
        get_tree().quit(0)
    else:
        printerr("RolesRelaxationsSmoke: FAIL")
        get_tree().quit(1)

func _base_settings(profile_path: String) -> RGASettings:
    var merged := RGAConfigLoader.load_config(profile_path)
    var s := RGASettings.new()
    s.from_dict(merged)
    return s

func _write_dir(base: String, run_id: String) -> String:
    var root := String(base)
    if root.strip_edges() == "":
        root = "user://out"
    var dir := "%s/run_%s" % [root.rstrip("/\\"), String(run_id)]
    return dir

func _assert_assassin_peel_relaxation() -> bool:
    # Run a peel scenario using assassin intent; verify time bound is relaxed to 4.0 and scenario label is peel.
    var settings := _base_settings("res://tests/rga_testing/config/profiles/rga_roles_derived.json")
    settings.run_id = "relax_peel"
    settings.metadata = {"scenario_intents": "res://tests/rga_testing/config/intents/roles/assassin_counter.json"}
    var rows := HeadlessSimPipeline.new().run_all(settings)
    if rows <= 0:
        printerr("Smoke: assassin peel run produced no rows")
        return false
    var dir := _write_dir(settings.out_path, settings.run_id)
    var ctx := RoleMetricsContextBuilder.build(dir, [], "")
    var caps := PackedStringArray(ctx.get("caps_present", []))
    var result := MetricRegistry.run_all(caps, ctx, ["role_assassin_identity"])
    var metrics: Array = result.get("metrics", [])
    if metrics.is_empty():
        printerr("Smoke: assassin metric not produced")
        return false
    var m: Dictionary = metrics[0]
    var msg := String(m.get("message", ""))
    if msg.find("scenario=peel") < 0:
        printerr("Smoke: assassin metric missing scenario=peel in message: ", msg)
        return false
    var spans: Array = m.get("spans", [])
    var saw_bound := false
    for s in spans:
        if not (s is Dictionary):
            continue
        var span: Dictionary = s
        var label: String = String(span.get("label", ""))
        if label.begins_with("a_first_frac") or label.begins_with("b_first_frac"):
            var tb: Variant = span.get("time_bound_s", null)
            if typeof(tb) == TYPE_FLOAT or typeof(tb) == TYPE_INT:
                if float(tb) <= 4.0 + 1e-6:
                    saw_bound = true
                    break
    if not saw_bound:
        printerr("Smoke: assassin relaxed time_bound_s not observed in spans")
        return false
    return true

func _assert_tank_burst_relaxation() -> bool:
    # Run a burst-like scenario (anti-heal) using tank intent; verify scenario=burst and threshold resolves to floor 2.0
    var settings := _base_settings("res://tests/rga_testing/config/profiles/rga_roles_derived.json")
    settings.run_id = "relax_burst"
    settings.metadata = {"scenario_intents": "res://tests/rga_testing/config/intents/roles/tank_counter.json"}
    var rows := HeadlessSimPipeline.new().run_all(settings)
    if rows <= 0:
        printerr("Smoke: tank burst run produced no rows")
        return false
    var dir := _write_dir(settings.out_path, settings.run_id)
    var ctx := RoleMetricsContextBuilder.build(dir, [], "")
    var caps := PackedStringArray(ctx.get("caps_present", []))
    var result := MetricRegistry.run_all(caps, ctx, ["role_tank_identity"])
    var metrics: Array = result.get("metrics", [])
    if metrics.is_empty():
        printerr("Smoke: tank metric not produced")
        return false
    var m: Dictionary = metrics[0]
    var msg := String(m.get("message", ""))
    if msg.find("scenario=burst") < 0:
        printerr("Smoke: tank metric missing scenario=burst in message: ", msg)
        return false
    var thresholds := RoleCommon.load_thresholds()
    var tank_cfg: Dictionary = RoleCommon.role_threshold(thresholds, "tank")
    var metrics_cfg: Dictionary = tank_cfg.get("metrics", {})
    var focus_cfg: Dictionary = metrics_cfg.get("focus_survival_s", {})
    var resolved := RoleCommon.resolve_min_threshold(focus_cfg, 3, "burst")
    if abs(float(resolved) - 2.0) > 1e-6:
        printerr("Smoke: tank burst relaxed focus threshold mismatch; got=", resolved, " want=2.0")
        return false
    return true

func _assert_frontline_window_kernel() -> bool:
    # Run a kite/poke scenario; verify frontline_window kernel emits supported=true and >0 observed_s
    var settings := _base_settings("res://tests/rga_testing/config/profiles/rga_roles_derived.json")
    settings.run_id = "relax_frontline"
    settings.metadata = {"scenario_intents": "res://tests/rga_testing/config/intents/roles/kite_poke.json"}
    var rows := HeadlessSimPipeline.new().run_all(settings)
    if rows <= 0:
        printerr("Smoke: frontline window run produced no rows")
        return false
    var dir := _write_dir(settings.out_path, settings.run_id)
    var ctx := RoleMetricsContextBuilder.build(dir, [], "")
    var sims: Dictionary = ctx.get("sims", {})
    var ok := false
    for k in sims.keys():
        var e: Dictionary = sims.get(k, {})
        var kernels: Dictionary = e.get("kernels", {})
        var flw: Dictionary = kernels.get("frontline_window", {})
        if flw is Dictionary and bool(flw.get("supported", false)):
            var a: Dictionary = flw.get("a", {})
            var b: Dictionary = flw.get("b", {})
            if a is Dictionary and b is Dictionary:
                var obs_a := float(a.get("observed_s", 0.0))
                var obs_b := float(b.get("observed_s", 0.0))
                if obs_a > 0.0 or obs_b > 0.0:
                    ok = true
                    break
    if not ok:
        printerr("Smoke: frontline_window supported or observed_s not present")
    return ok
