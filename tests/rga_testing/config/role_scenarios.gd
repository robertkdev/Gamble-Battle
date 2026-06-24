extends RefCounted
class_name RGARoleScenarios

# Curated, high-signal scenario packs per role (diagnostic, not exhaustive).
# Each scenario entry:
# {
#   id: String,                 # stable identifier (role.slug)
#   label: String,              # scenario label used by relaxations: neutral|burst|peel|kite|counter
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
	var r := String(role_id).strip_edges().to_lower()
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
		_scen("tank.burst", "burst", "front", _burst_lane(), ["burst", "antiheal"]),
		_scen("tank.peel", "peel", "front", _peel_map(), ["peel"])
	]

static func _brawler_packs() -> Array[Dictionary]:
	return [
		_scen("brawler.neutral", "neutral", "front", _open_field(0.7, 7.5), ["open_field"]),
		_scen("brawler.burst", "burst", "front", _burst_lane(), ["burst"]),
		_scen("brawler.peel", "peel", "front", _peel_map(), ["peel"])
	]

static func _marksman_packs() -> Array[Dictionary]:
	return [
		_scen("marksman.kite_poke", "kite", "back", _kite_field(), ["kite", "poke"]),
		_scen("marksman.open_field", "neutral", "back", _open_field(0.8, 10.0), ["open_field"]),
		_scen("marksman.backline_start", "neutral", "back", _backline_bias(), ["backline"])
	]

static func _assassin_packs() -> Array[Dictionary]:
	return [
		_scen("assassin.dive", "counter", "front", _dive_window(), ["dive"]),
		_scen("assassin.counter", "counter", "front", _counter_lane(), ["counter"])
	]

static func _mage_packs() -> Array[Dictionary]:
	return [
		_scen("mage.periodic_friendly", "neutral", "back", _periodicity_friendly(), ["periodic"]),
		_scen("mage.mixed", "neutral", "back", _mixed_field(), ["mixed"])
	]

static func _support_packs() -> Array[Dictionary]:
	return [
		_scen("support.peel_present", "peel", "back", _peel_map(), ["peel"]),
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
