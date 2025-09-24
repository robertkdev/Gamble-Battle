extends RefCounted
class_name BuffSystem

# Lightweight timed buff manager.
# - Applies additive stat deltas and reverts them on expiry
# - Supports simple shields and stuns (data tracked here; integration is separate)

const SUPPORTED_FIELDS := [
	"armor", "magic_resist", "damage_reduction",
	"attack_damage", "spell_power", "attack_speed",
	"max_hp", "move_speed", "lifesteal",
	"true_damage", "armor_pen_flat", "armor_pen_pct",
	"mr_pen_flat", "mr_pen_pct"
]

# Map[Unit -> Array[Dictionary]]
var _buffs: Dictionary = {}
var _stacks: Dictionary = {} # Map[Unit -> Dictionary[String, int]]

func clear() -> void:
	_buffs.clear()
	_stacks.clear()

func tick(state: BattleState, delta: float) -> void:
	if delta <= 0.0:
		return
	var to_remove: Array = []
	for u in _buffs.keys():
		var arr: Array = _buffs[u]
		for b in arr:
			b.remaining = float(b.remaining) - delta
			if b.remaining <= 0.0:
				_expire_buff(u, b)
				to_remove.append([u, b])
	for pair in to_remove:
		var uu = pair[0]
		var bb = pair[1]
		if _buffs.has(uu):
			_buffs[uu].erase(bb)
			if _buffs[uu].is_empty():
				_buffs.erase(uu)

# === Public API ===

func apply_stats_buff(state: BattleState, team: String, index: int, fields: Dictionary, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or duration_s <= 0.0:
		return {"processed": false}
	var f := _filter_fields(fields)
	if f.is_empty():
		return {"processed": false}
	_apply_fields(u, f, +1)
	var buff := {"kind": "stats", "fields": f, "remaining": duration_s}
	_add_buff(u, buff)
	return {"processed": true, "applied": f, "duration": duration_s}

func apply_shield(state: BattleState, team: String, index: int, amount: int, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or amount <= 0 or duration_s <= 0.0:
		return {"processed": false}
	var buff := {"kind": "shield", "shield": int(amount), "remaining": duration_s}
	_add_buff(u, buff)
	return {"processed": true, "shield": int(amount), "duration": duration_s}

func apply_stun(state: BattleState, team: String, index: int, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or duration_s <= 0.0:
		return {"processed": false}
	var buff := {"kind": "stun", "remaining": duration_s}
	_add_buff(u, buff)
	return {"processed": true, "duration": duration_s}

# Generic tagged timed buff helper (no stat deltas by default)
# Stores a buff as { kind: "tag", tag: String, remaining: float, data: Dictionary }
func apply_tag(state: BattleState, team: String, index: int, tag: String, duration_s: float, data: Dictionary = {}) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or tag.strip_edges() == "" or duration_s <= 0.0:
		return {"processed": false}
	# If tag already present, refresh remaining and merge data
	if _buffs.has(u):
		for b in _buffs[u]:
			if String(b.get("kind", "")) == "tag" and String(b.get("tag", "")) == tag:
				b["remaining"] = max(float(b.get("remaining", 0.0)), duration_s)
				var cur: Dictionary = b.get("data", {})
				var merged: Dictionary = cur.duplicate()
				for k in data.keys():
					merged[k] = data[k]
				b["data"] = merged
				return {"processed": true, "updated": true, "remaining": float(b["remaining"]), "data": merged}
	var buff := {"kind": "tag", "tag": tag, "remaining": duration_s, "data": (data if data != null else {})}
	_add_buff(u, buff)
	return {"processed": true, "created": true, "remaining": duration_s, "data": buff["data"]}

func has_tag(state: BattleState, team: String, index: int, tag: String) -> bool:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if String(b.get("kind", "")) == "tag" and String(b.get("tag", "")) == tag and float(b.get("remaining", 0.0)) > 0.0:
			return true
	return false

func get_tag(state: BattleState, team: String, index: int, tag: String) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return {}
	for b in _buffs[u]:
		if String(b.get("kind", "")) == "tag" and String(b.get("tag", "")) == tag and float(b.get("remaining", 0.0)) > 0.0:
			return b
	return {}

func get_tag_data(state: BattleState, team: String, index: int, tag: String) -> Dictionary:
	var b := get_tag(state, team, index, tag)
	if b.is_empty():
		return {}
	var d: Dictionary = b.get("data", {})
	return d if d != null else {}

# Returns true if any active tag on the unit sets data.block_mana_gain == true
func is_mana_gain_blocked(state: BattleState, team: String, index: int) -> bool:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if String(b.get("kind", "")) != "tag":
			continue
		if float(b.get("remaining", 0.0)) <= 0.0:
			continue
		var d: Dictionary = b.get("data", {})
		if d != null and bool(d.get("block_mana_gain", false)):
			return true
	return false

# Attempts to absorb incoming damage using active shields on this unit.
# Returns leftover damage after shields (non-negative) and the amount absorbed.
func absorb_with_shields(u: Unit, incoming_damage: int) -> Dictionary:
	var result := {"leftover": max(0, incoming_damage), "absorbed": 0}
	if u == null or incoming_damage <= 0 or not _buffs.has(u):
		return result
	var arr: Array = _buffs[u]
	var dmg: int = max(0, incoming_damage)
	for b in arr:
		if dmg <= 0:
			break
		if String(b.get("kind", "")) != "shield":
			continue
		var s: int = int(b.get("shield", 0))
		if s <= 0:
			continue
		var used: int = min(s, dmg)
		b["shield"] = s - used
		dmg -= used
		result["absorbed"] = int(result["absorbed"]) + used
	result["leftover"] = dmg
	return result

# Instantly removes all active shield values on the unit.
# Returns the total shield amount removed.
func break_shields(u: Unit) -> int:
	var removed: int = 0
	if u == null or not _buffs.has(u):
		return removed
	var arr: Array = _buffs[u]
	for b in arr:
		if String(b.get("kind", "")) != "shield":
			continue
		var s: int = int(b.get("shield", 0))
		if s > 0:
			removed += s
			b["shield"] = 0
	return removed

func break_shields_on(state: BattleState, team: String, index: int) -> int:
	var u: Unit = _unit_at(state, team, index)
	return break_shields(u)

func is_stunned(u: Unit) -> bool:
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if String(b.get("kind", "")) == "stun" and float(b.get("remaining", 0.0)) > 0.0:
			return true
	return false

# === Stacks API ===

func add_stack(state: BattleState, team: String, index: int, key: String, delta: int, per_stack_fields: Dictionary = {}) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or key.strip_edges() == "" or delta == 0:
		return {"processed": false}
	if not _stacks.has(u):
		_stacks[u] = {}
	var smap: Dictionary = _stacks[u]
	var current: int = int(smap.get(key, 0))
	var new_count: int = max(0, current + delta)
	var applied_delta: int = new_count - current
	smap[key] = new_count
	# Apply permanent per-stack field deltas (scaled by applied_delta)
	if applied_delta != 0 and per_stack_fields != null and not per_stack_fields.is_empty():
		var scaled: Dictionary = {}
		for k in per_stack_fields.keys():
			scaled[k] = float(per_stack_fields[k]) * float(applied_delta)
		_apply_fields(u, scaled, +1)
	return {"processed": true, "key": key, "count": new_count, "delta": applied_delta}

func get_stack(state: BattleState, team: String, index: int, key: String) -> int:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _stacks.has(u):
		return 0
	var smap: Dictionary = _stacks[u]
	return int(smap.get(key, 0))

# === Internals ===

func _add_buff(u: Unit, buff: Dictionary) -> void:
	if u == null:
		return
	if not _buffs.has(u):
		_buffs[u] = []
	_buffs[u].append(buff)

func _expire_buff(u: Unit, buff: Dictionary) -> void:
	if u == null:
		return
	var kind: String = String(buff.get("kind", ""))
	if kind == "stats":
		var f: Dictionary = buff.get("fields", {})
		if f and not f.is_empty():
			_apply_fields(u, f, -1)
	# shield and stun expire passively
	# tag kind also expires passively

func _apply_fields(u: Unit, fields: Dictionary, sign: int) -> void:
	for k in fields.keys():
		var v = fields[k]
		var delta: float = float(v) * float(sign)
		match String(k):
			"damage_reduction":
				u.damage_reduction = clamp(u.damage_reduction + delta, 0.0, 0.9)
			"attack_speed":
				u.attack_speed = max(0.01, u.attack_speed + delta)
			"lifesteal":
				u.lifesteal = clamp(u.lifesteal + delta, 0.0, 0.9)
			"max_hp":
				var new_max: int = max(1, int(round(float(u.max_hp) + delta)))
				u.max_hp = new_max
				if u.hp > new_max:
					u.hp = new_max
			_:
				# Fallback for numeric fields; clamp to >= 0 for defenses
				var cur = u.get(k)
				if typeof(cur) == TYPE_FLOAT or typeof(cur) == TYPE_INT:
					var nv = float(cur) + delta
					if k in ["armor", "magic_resist", "armor_pen_flat", "mr_pen_flat"]:
						nv = max(0.0, nv)
					u.set(k, nv)

func _filter_fields(fields: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if fields == null:
		return out
	for k in SUPPORTED_FIELDS:
		if fields.has(k):
			out[k] = fields[k]
	return out

func _unit_at(state: BattleState, team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]
