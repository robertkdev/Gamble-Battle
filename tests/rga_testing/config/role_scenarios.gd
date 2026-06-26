extends RefCounted
class_name RGARoleScenarios

# Curated, high-signal scenario packs per role (diagnostic, not exhaustive).
# Each scenario entry:
# {
#   id: String,                 # stable identifier (role.slug)
#   label: String,              # scenario label used by relaxations: neutral|burst|peel|kite|counter|sustained
#   subject_lane: String,       # front|back (runner may use for placement hints)
#   map_params: Dictionary,     # OpenFieldScenario map params (openness, artillery_range, etc.)
#   intents: PackedStringArray  # coarse tactical intents (e.g., ["peel"], ["kite","poke"]) for shell/opponent selection
# }

static func list_roles() -> PackedStringArray:
	var out: PackedStringArray = []
	for r in ["tank", "brawler", "marksman", "assassin", "mage", "support"]:
		out.append(r)
	return out

static func get_packs_for_role(role_id: String) -> Array[Dictionary]:
	var r: String = String(role_id).strip_edges().to_lower()
	match r:
		"tank":
			return _tank_packs()
		"brawler":
			return _brawler_packs()
		"marksman":
			return _marksman_packs()
		"assassin":
			return _assassin_packs()
		"mage":
			return _mage_packs()
		"support":
			return _support_packs()
		_:
			return []

static func all_packs() -> Dictionary:
	return {
		"tank": _tank_packs(),
		"brawler": _brawler_packs(),
		"marksman": _marksman_packs(),
		"assassin": _assassin_packs(),
		"mage": _mage_packs(),
		"support": _support_packs()
	}

# --- Packs ---------------------------------------------------------------

static func _tank_packs() -> Array[Dictionary]:
	return [
		_scen("tank.neutral", "neutral", "front", _open_field(0.7, 8.0), ["open_field"]),
		_scen("tank.engage_window", "engage", "front", _engage_window(), ["engage", "initiate"]),
		_scen("tank.fortification_window", "fortify", "front", _fortification_window(), ["fortify", "buffs"]),
		_scen("tank.burst", "burst", "front", _burst_lane(), ["burst", "antiheal"]),
		_scen("tank.peel", "peel", "front", _peel_map(), ["peel"])
	]

static func _brawler_packs() -> Array[Dictionary]:
	return [
		_scen("brawler.neutral", "neutral", "front", _open_field(0.7, 7.5), ["open_field"]),
		_scen("brawler.dive_window", "counter", "front", _dive_window(), ["dive", "backline"]),
		_scen("brawler.burst", "burst", "front", _burst_lane(), ["burst"]),
		_scen("brawler.peel", "peel", "front", _peel_map(), ["peel"]),
		_scen("brawler.clustered_targets", "clustered", "front", _clustered_targets("clustered_targets_brawler"), ["aoe", "line"]),
		_scen("brawler.clustered_crossfire", "clustered_alt", "front", _clustered_crossfire("clustered_crossfire_brawler"), ["aoe", "line"])
	]

static func _marksman_packs() -> Array[Dictionary]:
	return [
		_scen("marksman.kite_poke", "kite", "back", _kite_field(), ["kite", "poke"]),
		_scen("marksman.sustained_pressure", "sustained", "back", _marksman_sustained_pressure(), ["sustained", "focus_fire"]),
		_scen("marksman.open_field", "neutral", "back", _open_field(0.8, 10.0), ["open_field"]),
		_scen("marksman.backline_start", "neutral", "back", _backline_bias(), ["backline"]),
		_scen("marksman.clustered_targets", "clustered", "back", _clustered_targets("clustered_targets_marksman"), ["aoe", "line"]),
		_scen("marksman.clustered_crossfire", "clustered_alt", "back", _clustered_crossfire("clustered_crossfire_marksman"), ["aoe", "line"])
	]

static func _assassin_packs() -> Array[Dictionary]:
	return [
		_scen("assassin.dive", "counter", "front", _dive_window(), ["dive"]),
		_scen("assassin.counter", "counter", "front", _counter_lane(), ["counter"])
	]

static func _mage_packs() -> Array[Dictionary]:
	return [
		_scen("mage.periodic_friendly", "neutral", "back", _periodicity_friendly(), ["periodic"]),
		_scen("mage.mixed", "neutral", "back", _mixed_field(), ["mixed"]),
		_scen("mage.burst_window", "burst", "back", _pick_burst_window(), ["burst", "pick"]),
		_scen("mage.clustered_targets", "clustered", "back", _clustered_targets("clustered_targets_mage"), ["aoe", "wombo"]),
		_scen("mage.clustered_crossfire", "clustered_alt", "back", _clustered_crossfire("clustered_crossfire_mage"), ["aoe", "wombo"])
	]

static func _support_packs() -> Array[Dictionary]:
	return [
		_scen("support.peel_present", "peel", "back", _peel_map(), ["peel"]),
		_scen("support.carry_threat_window", "threat", "back", _carry_threat_window(), ["peel", "carry_threat", "interrupt"]),
		_scen("support.buff_window", "neutral", "back", _open_field(0.7, 8.0), ["buffs"])
	]

# --- Helpers -------------------------------------------------------------

static func _scen(id: String, label: String, subject_lane: String, map_params: Dictionary, intents: PackedStringArray) -> Dictionary:
	return {
		"id": String(id),
		"label": String(label),
		"subject_lane": String(subject_lane),
		"map_params": (map_params.duplicate(true) if map_params is Dictionary else {}),
		"intents": intents
	}

# Map param presets tuned for kernels and relaxations

static func _open_field(openness: float, artillery_range: float) -> Dictionary:
	return {
		"openness": float(openness),
		"artillery_range": float(artillery_range),
		"tile_size": 96.0,
		"map_id": "open_field_variable"
	}

static func _burst_lane() -> Dictionary:
	# Narrower field and modest separation to emphasize burst windows
	return {
		"openness": 0.55,
		"choke_count": 1,
		"obstacle_density": 0.35,
		"artillery_range": 7.0,
		"tile_size": 96.0,
		"map_id": "burst_lane"
	}

static func _peel_map() -> Dictionary:
	# Slightly tighter bounds, standard separation; defender peel context assumed
	return {
		"openness": 0.6,
		"choke_count": 0,
		"obstacle_density": 0.2,
		"artillery_range": 8.0,
		"tile_size": 96.0,
		"map_id": "peel_context"
	}

static func _kite_field() -> Dictionary:
	# Wide, open field with longer artillery range to favor kiting/poking
	return {
		"openness": 0.9,
		"choke_count": 0,
		"obstacle_density": 0.1,
		"artillery_range": 11.0,
		"tile_size": 96.0,
		"map_id": "kite_open"
	}

static func _marksman_sustained_pressure() -> Dictionary:
	# Wide back-lane pressure context for sustained marksman output checks.
	return {
		"openness": 0.82,
		"choke_count": 0,
		"obstacle_density": 0.08,
		"artillery_range": 10.5,
		"tile_size": 96.0,
		"half_width_tiles": 6.0,
		"half_height_tiles": 4.0,
		"spawn_x_tiles": 3.1,
		"row_spacing_tiles": 0.42,
		"depth_gap": 0.7,
		"map_id": "marksman_sustained_pressure"
	}

static func _backline_bias() -> Dictionary:
	# Normal field; runner can ensure subject starts backline via placement hints
	return _open_field(0.75, 9.0)

static func _dive_window() -> Dictionary:
	# Shorter separation to reach backline quickly; emphasizes 0-4s windows
	return {
		"openness": 0.65,
		"choke_count": 0,
		"obstacle_density": 0.2,
		"artillery_range": 6.5,
		"tile_size": 96.0,
		"map_id": "dive_window"
	}

static func _engage_window() -> Dictionary:
	# Compact front-lane context for multi-target initiate-fight checks.
	return {
		"openness": 0.58,
		"choke_count": 0,
		"obstacle_density": 0.18,
		"artillery_range": 6.5,
		"tile_size": 96.0,
		"half_width_tiles": 5.0,
		"half_height_tiles": 3.4,
		"spawn_x_tiles": 2.7,
		"row_spacing_tiles": 0.3,
		"depth_gap": 0.35,
		"map_id": "engage_window"
	}

static func _counter_lane() -> Dictionary:
	# Slightly constrained field; opponent selection expected to be counters
	return {
		"openness": 0.6,
		"choke_count": 1,
		"obstacle_density": 0.3,
		"artillery_range": 7.5,
		"tile_size": 96.0,
		"map_id": "counter_lane"
	}

static func _fortification_window() -> Dictionary:
	# Standard spacing, explicit map id for team-fortification audit rows.
	return {
		"openness": 0.65,
		"choke_count": 0,
		"obstacle_density": 0.2,
		"artillery_range": 8.0,
		"tile_size": 96.0,
		"map_id": "fortification_window"
	}

static func _carry_threat_window() -> Dictionary:
	# Compact carry-threat context for peel-carry interrupt and save attribution.
	return {
		"openness": 0.58,
		"choke_count": 0,
		"obstacle_density": 0.18,
		"artillery_range": 7.0,
		"tile_size": 96.0,
		"half_width_tiles": 5.0,
		"half_height_tiles": 3.5,
		"spawn_x_tiles": 2.8,
		"row_spacing_tiles": 0.35,
		"depth_gap": 0.45,
		"map_id": "carry_threat_window"
	}

static func _pick_burst_window() -> Dictionary:
	# Compact burst context so pick-burst identities do not fall back to generic mage maps.
	return {
		"openness": 0.55,
		"choke_count": 0,
		"obstacle_density": 0.18,
		"artillery_range": 6.0,
		"tile_size": 96.0,
		"half_width_tiles": 4.8,
		"half_height_tiles": 3.2,
		"spawn_x_tiles": 2.6,
		"row_spacing_tiles": 0.28,
		"depth_gap": 0.35,
		"map_id": "pick_burst_window"
	}

static func _periodicity_friendly() -> Dictionary:
	# Moderately open; enough space for periodicity kernel to observe cycles
	return {
		"openness": 0.7,
		"choke_count": 0,
		"obstacle_density": 0.2,
		"artillery_range": 8.5,
		"tile_size": 96.0,
		"map_id": "periodic_friendly"
	}

static func _mixed_field() -> Dictionary:
	# Balanced default; neither extreme burst nor kite
	return _open_field(0.7, 8.0)

static func _clustered_targets(map_id: String) -> Dictionary:
	# Intentionally tight target spacing for AoE and line-skill proof contexts.
	return {
		"openness": 0.6,
		"choke_count": 0,
		"obstacle_density": 0.1,
		"artillery_range": 5.0,
		"tile_size": 96.0,
		"half_width_tiles": 4.5,
		"half_height_tiles": 3.0,
		"spawn_x_tiles": 2.4,
		"row_spacing_tiles": 0.18,
		"depth_gap": 0.18,
		"map_id": String(map_id)
	}

static func _clustered_crossfire(map_id: String) -> Dictionary:
	var params: Dictionary = _clustered_targets(map_id)
	params["spawn_x_tiles"] = 2.1
	params["row_spacing_tiles"] = 0.24
	params["depth_gap"] = 0.12
	return params
