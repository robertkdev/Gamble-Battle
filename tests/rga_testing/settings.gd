extends RefCounted
class_name RGASettings

# Single-responsibility: hold filters/settings and parse CLI args.

var ids: Array = []                               # [{a: String, b: String}, ...]
var role_filter: PackedStringArray = []           # ["tank","brawler",...]
var goal_filter: PackedStringArray = []           # ["tank.frontline_absorb",...]
var approach_filter: PackedStringArray = []       # ["burst","aoe",...]
var cost_filter: PackedInt32Array = []            # [1,2,3]
var run_id: String = ""
var sim_seed_start: int = 0                       # base seed for runs; per-sim seeds derive from this
var deterministic: bool = true
var team_sizes: PackedInt32Array = PackedInt32Array([1])
var repeats: int = 10
var timeout_s: float = 120.0
var abilities: bool = false
var ability_metrics: bool = false
var out_path: String = "user://rga_out.jsonl"
var aggregates_only: bool = false                # if true, write one aggregated row per pair (BalanceRunner-style)
var include_swapped: bool = true                 # if true, run both orientations per repeat (A→B and B→A)

static func parse_cli(argv: PackedStringArray) -> RGASettings:
	var s := RGASettings.new()
	var args := _parse_kv(argv)
	s.run_id = String(args.get("run_id", s.run_id))
	if String(args.get("sim_seed_start", "")).strip_edges() != "":
		s.sim_seed_start = int(args.get("sim_seed_start", s.sim_seed_start))
	s.deterministic = _parse_bool(String(args.get("deterministic", str(s.deterministic))))
	var ts := _csv_to_ints(String(args.get("team_sizes", "")))
	if ts.size() > 0:
		s.team_sizes = ts
	s.repeats = int(args.get("repeats", s.repeats))
	s.timeout_s = float(args.get("timeout", s.timeout_s))
	s.abilities = _parse_bool(String(args.get("abilities", str(s.abilities))))
	s.ability_metrics = _parse_bool(String(args.get("ability_metrics", str(s.ability_metrics))))
	s.out_path = String(args.get("out", s.out_path))
	s.role_filter = _split_csv(String(args.get("role", "")))
	s.goal_filter = _split_csv(String(args.get("goal", "")))
	s.approach_filter = _split_csv(String(args.get("approach", "")))
	s.cost_filter = _csv_to_ints(String(args.get("cost", "")))
	s.ids = _parse_id_pairs(String(args.get("ids", "")))
	return s

func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"sim_seed_start": sim_seed_start,
		"deterministic": deterministic,
		"team_sizes": team_sizes,
		"repeats": repeats,
		"timeout_s": timeout_s,
		"abilities": abilities,
		"ability_metrics": ability_metrics,
		"out_path": out_path,
		"aggregates_only": aggregates_only,
		"include_swapped": include_swapped,
		"role_filter": role_filter,
		"goal_filter": goal_filter,
		"approach_filter": approach_filter,
		"cost_filter": cost_filter,
		"ids": ids,
	}

# Layering helper: apply values from a Dictionary onto this instance.
func from_dict(d: Dictionary) -> void:
	if d == null:
		return
	if d.has("run_id"):
		run_id = str(d.get("run_id", run_id))
	if d.has("sim_seed_start"):
		var v = d.get("sim_seed_start")
		if typeof(v) == TYPE_INT or (typeof(v) == TYPE_STRING and str(v).is_valid_int()):
			sim_seed_start = int(v)
	if d.has("deterministic"):
		var db = d.get("deterministic")
		deterministic = (bool(db) if typeof(db) == TYPE_BOOL else _parse_bool(str(db)))
	if d.has("team_sizes"):
		var tv = d.get("team_sizes")
		if tv is PackedInt32Array:
			team_sizes = tv
		elif tv is Array:
			var acc: PackedInt32Array = []
			for x in tv:
				if typeof(x) == TYPE_INT or (typeof(x) == TYPE_STRING and str(x).is_valid_int()):
					acc.append(int(x))
			if acc.size() > 0:
				team_sizes = acc
		elif typeof(tv) == TYPE_STRING:
			var parsed := _csv_to_ints(str(tv))
			if parsed.size() > 0:
				team_sizes = parsed
	if d.has("repeats"):
		repeats = int(d.get("repeats", repeats))
	if d.has("timeout_s"):
		timeout_s = float(d.get("timeout_s", timeout_s))
	if d.has("abilities"):
		var ab = d.get("abilities")
		abilities = (bool(ab) if typeof(ab) == TYPE_BOOL else _parse_bool(str(ab)))
	if d.has("ability_metrics"):
		var am = d.get("ability_metrics")
		ability_metrics = (bool(am) if typeof(am) == TYPE_BOOL else _parse_bool(str(am)))
	if d.has("out_path"):
		# Use str() to coerce to a path string (avoids constructor call errors)
		out_path = str(d.get("out_path", out_path))
	if d.has("aggregates_only"):
		var ao = d.get("aggregates_only")
		aggregates_only = (bool(ao) if typeof(ao) == TYPE_BOOL else _parse_bool(str(ao)))
	if d.has("include_swapped"):
		var isw = d.get("include_swapped")
		include_swapped = (bool(isw) if typeof(isw) == TYPE_BOOL else _parse_bool(str(isw)))
	if d.has("role_filter"):
		var rf = d.get("role_filter")
		if rf is PackedStringArray:
			role_filter = rf
		elif rf is Array:
			var acc_rf: PackedStringArray = []
			for v in rf:
				var s := str(v).strip_edges().to_lower()
				if s != "": acc_rf.append(s)
			role_filter = acc_rf
		else:
			role_filter = _split_csv(str(rf))
	if d.has("goal_filter"):
		var gf = d.get("goal_filter")
		if gf is PackedStringArray:
			goal_filter = gf
		elif gf is Array:
			var acc_gf: PackedStringArray = []
			for v2 in gf:
				var s2 := str(v2).strip_edges().to_lower()
				if s2 != "": acc_gf.append(s2)
			goal_filter = acc_gf
		else:
			goal_filter = _split_csv(str(gf))
	if d.has("approach_filter"):
		var af = d.get("approach_filter")
		if af is PackedStringArray:
			approach_filter = af
		elif af is Array:
			var acc_af: PackedStringArray = []
			for v3 in af:
				var s3 := str(v3).strip_edges().to_lower()
				if s3 != "": acc_af.append(s3)
			approach_filter = acc_af
		else:
			approach_filter = _split_csv(str(af))
	if d.has("cost_filter"):
		var cf = d.get("cost_filter")
		if cf is PackedInt32Array:
			cost_filter = cf
		elif typeof(cf) == TYPE_STRING:
			cost_filter = _csv_to_ints(str(cf))
		elif cf is Array:
			var acc2: PackedInt32Array = []
			for y in cf:
				if typeof(y) == TYPE_INT or (typeof(y) == TYPE_STRING and str(y).is_valid_int()):
					acc2.append(int(y))
			cost_filter = acc2
	if d.has("ids"):
		var iv = d.get("ids")
		if iv is Array:
			ids = iv
		elif typeof(iv) == TYPE_STRING:
			ids = _parse_id_pairs(str(iv))

# --- Helpers (private, simple, DRY) ---

static func _parse_kv(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var seen_sep := false
	for a in argv:
		if a == "--":
			seen_sep = true
			continue
		var s := String(a)
		if (not seen_sep) and (not s.contains("=")):
			continue
		var parts := s.split("=", false, 2)
		if parts.size() == 2:
			out[parts[0].lstrip("-")] = parts[1]
	return out

static func _split_csv(s: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if s.strip_edges() == "":
		return out
	for p in s.split(","):
		var v := String(p).strip_edges().to_lower()
		if v != "": out.append(v)
	return out

static func _csv_to_ints(s: String) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if s.strip_edges() == "":
		return out
	for p in s.split(","):
		var v := String(p).strip_edges()
		if v.is_valid_int(): out.append(int(v))
	return out

static func _parse_bool(s: String) -> bool:
	var v := s.strip_edges().to_lower()
	return v in ["1","true","yes","y","on"]

static func _parse_id_pairs(s: String) -> Array:
	# Format: "a:b,c:d"
	var out: Array = []
	var src := String(s).strip_edges()
	if src == "":
		return out
	for tok in src.split(","):
		var t := String(tok).strip_edges()
		if t == "": continue
		var parts := t.split(":", false, 2)
		if parts.size() != 2: continue
		var a := String(parts[0]).strip_edges().to_lower()
		var b := String(parts[1]).strip_edges().to_lower()
		if a == "" or b == "": continue
		out.append({"a": a, "b": b})
	return out
