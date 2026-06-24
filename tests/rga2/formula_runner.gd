extends Node

# RGA2 Formula Runner
# Deterministic, formula-first validation of role baselines and derived targets.
# - Reads constants and role targets fixtures (JSON)
# - Computes EHP over horizon and sustained DPS from autos+abilities
# - Compares against fixture targets with tolerances

@export var constants_path: String = "res://tests/rga2/fixtures/constants.json"
@export var targets_path: String = "res://tests/rga2/fixtures/role_targets.json"
@export var roles_to_check: PackedStringArray = PackedStringArray([]) # empty = all
@export var cost: int = 1
@export var tolerance_dps: float = 2.0
@export var tolerance_ehp: float = 1.0
@export var verbose: bool = true
@export var quit_on_finish: bool = true

var _constants: Dictionary = {}
var _targets: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok_load: bool = _load_fixtures()
	if not ok_load:
		_log_err("RGA2: failed to load fixtures")
		_quit(1)
		return
	var selected: Array[String] = _resolve_roles()
	if selected.is_empty():
		_log_info("RGA2: no roles selected (fixtures empty?)")
		_quit(1)
		return
	var failures: int = 0
	for role in selected:
		var res: Dictionary = _eval_role(role)
		if not bool(res.get("pass", false)):
			failures += 1
			_log_err("RGA2 FAIL %s: %s" % [String(role), String(res.get("message", ""))])
		else:
			_log_info("RGA2 PASS %s: %s" % [String(role), String(res.get("message", ""))])
	if quit_on_finish:
		_quit(0 if failures == 0 else 1)

func _load_fixtures() -> bool:
	_constants = _read_json(constants_path)
	_targets = _read_json(targets_path)
	return (not _constants.is_empty()) and (not _targets.is_empty())

func _resolve_roles() -> Array[String]:
	var out: Array[String] = []
	var filter: Dictionary = {}
	for r in roles_to_check:
		filter[String(r).to_lower()] = true
	var roles: Dictionary = {}
	if _targets is Dictionary:
		roles = _targets.get("roles", {})
	if not (roles is Dictionary):
		return out
	for k in roles.keys():
		var id: String = String(k).strip_edges().to_lower()
		if filter.is_empty() or filter.has(id):
			out.append(id)
	out.sort()
	return out

func _eval_role(role_id: String) -> Dictionary:
	var roles: Dictionary = _targets.get("roles", {})
	var rt: Dictionary = roles.get(role_id, {})
	if rt.is_empty():
		return {"pass": false, "message": "missing_role_targets"}
	# Baselines from targets fixture (cost-1)
	var hp: float = float(rt.get("hp", 0.0))
	var armor: float = float(rt.get("armor", 0.0))
	var mr: float = float(rt.get("mr", 0.0))
	var ad: float = float(rt.get("ad", 0.0))
	var as_val: float = float(rt.get("as", 0.0))
	var crit: float = float(rt.get("crit_chance", 0.0))
	var crit_mult: float = float(rt.get("crit_mult", 1.5))
	var shield_per_cast: float = float(rt.get("shield_per_cast", 0.0))
	var shield_cd_s: float = float(rt.get("shield_cd_s", 9999.0))
	var heals_24: float = float(rt.get("heals_24", 0.0))
	var ab_arr: Variant = rt.get("abilities", [])
	var abilities: Array[Dictionary] = []
	if ab_arr is Array:
		for e in ab_arr:
			if e is Dictionary:
				abilities.append((e as Dictionary).duplicate(true))
	# Constants
	var T: float = float(_constants.get("time_horizon_s", 24.0))
	var mix: Dictionary = _constants.get("damage_mix", {"physical": 0.5, "magic": 0.5})
	var mix_phys: float = float(mix.get("physical", 0.5))
	var mix_magic: float = float(mix.get("magic", 0.5))
	var k_phys: float = float(_constants.get("dr_k_phys", 100.0))
	var k_magic: float = float(_constants.get("dr_k_magic", 100.0))
	# Derived computations
	var phys_dr: float = _dr(armor, k_phys)
	var magic_dr: float = _dr(mr, k_magic)
	var mixed_dr: float = mix_phys * phys_dr + mix_magic * magic_dr
	var shields_T: float = 0.0
	if shield_per_cast > 0.0 and shield_cd_s > 0.0:
		var casts: float = floor(T / max(0.0001, shield_cd_s))
		shields_T = casts * shield_per_cast
	var ehp_T: float = _ehp(hp, shields_T, heals_24, mixed_dr)
	var autos_dps: float = _autos_dps(ad, as_val, crit, crit_mult)
	var abil_dps: float = _abilities_dps(abilities)
	var sustained_dps: float = autos_dps + abil_dps
	# Targets & tolerances
	var want_dps: float = float(rt.get("sustained_dps_target", 0.0))
	var want_ehp: float = float(rt.get("ehp_24_target", 0.0))
	var pass_dps: bool = _within_abs(sustained_dps, want_dps, tolerance_dps)
	var pass_ehp: bool = _within_abs(ehp_T, want_ehp, tolerance_ehp)
	var ok: bool = pass_dps and pass_ehp
	var msg: String = "dps=%.2f want=%.2f tol=%.2f; ehp=%.2f want=%.2f tol=%.2f" % [sustained_dps, want_dps, tolerance_dps, ehp_T, want_ehp, tolerance_ehp]
	return {"pass": ok, "message": msg}

func _dr(stat: float, k: float) -> float:
	if stat <= 0.0:
		return 0.0
	return stat / (stat + k)

func _ehp(hp: float, shields_T: float, heals_T: float, mixed_dr: float) -> float:
	var numer: float = max(0.0, hp) + max(0.0, shields_T) + max(0.0, heals_T)
	var denom: float = max(0.000001, 1.0 - clamp(mixed_dr, 0.0, 0.99))
	return numer / denom

func _autos_dps(ad: float, as_val: float, crit_chance: float, crit_mult: float) -> float:
	var cc: float = clamp(crit_chance, 0.0, 0.95)
	var cm: float = max(1.0, crit_mult)
	return max(0.0, ad) * max(0.0, as_val) * (1.0 + cc * (cm - 1.0))

func _abilities_dps(abilities: Array) -> float:
	var s: float = 0.0
	for entry in abilities:
		if not (entry is Dictionary):
			continue
		var dpc: float = float((entry as Dictionary).get("damage_per_cast", 0.0))
		var cd: float = float((entry as Dictionary).get("cooldown_s", 999999.0))
		if dpc > 0.0 and cd > 0.0:
			s += (dpc / cd)
	return s

func _within_abs(v: float, want: float, tol: float) -> bool:
	return abs(v - want) <= max(0.0, tol)

func _read_json(path: String) -> Dictionary:
	var p: String = String(path).strip_edges()
	if p == "":
		return {}
	var fa: FileAccess = FileAccess.open(p, FileAccess.READ)
	if fa == null:
		_log_err("RGA2: cannot open %s" % p)
		return {}
	var txt: String = fa.get_as_text()
	fa.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	_log_err("RGA2: invalid JSON at %s" % p)
	return {}

func _log_info(msg: String) -> void:
	if verbose:
		print_rich("[color=light_green]" + String(msg) + "[/color]")

func _log_err(msg: String) -> void:
	printerr(String(msg))

func _quit(code: int) -> void:
	if get_tree():
		get_tree().quit(code)
