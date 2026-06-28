extends Control
class_name ProjectileManager

# Lightweight projectile container managed and rendered by this node.
# Designed to scale by avoiding per-projectile nodes.

# Extended to carry team + indices for multi-unit scenarios.
signal projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)

const DEBUG_RECENT_LIMIT: int = 12

var _projectiles: Array[Dictionary] = []
var _to_remove: Array[int] = []
var _debug_fired: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_hits: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_culled: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_missing_target: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_recent: Array[Dictionary] = []

func configure() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100 # render on top of most UI
	# Cover the whole view and render above containers
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	clip_contents = false
	set_process(true)
	if has_method("set_as_top_level"):
		set_as_top_level(true)

func has_active() -> bool:
	return _projectiles.size() > 0

func debug_snapshot() -> Dictionary:
	return {
		"active_count": _projectiles.size(),
		"fired": _debug_fired.duplicate(),
		"hits": _debug_hits.duplicate(),
		"culled": _debug_culled.duplicate(),
		"missing_target_control": _debug_missing_target.duplicate(),
		"recent": _debug_recent.duplicate(true),
	}

func clear() -> void:
	_projectiles.clear()
	_reset_debug_counters()
	queue_redraw()

func fire_basic(
		source_team: String,
		source_index: int,
		start_pos: Vector2,
		end_pos: Vector2,
		damage: int,
		crit: bool,
		speed: float = 600.0,
		radius: float = 6.0,
		color: Color = Color(1,1,1,1),
		target_control: Control = null,
		target_index: int = -1,
		source_control: Control = null,
		arc_curve: float = 0.0,
		arc_freq: float = 6.0,
		emit_hit_on_arrival: bool = true
) -> void:
	var dir: Vector2 = (end_pos - start_pos)
	var dist: float = max(1.0, dir.length())
	dir /= dist
	var proj: Dictionary = {
		"pos": start_pos,
		"vel": dir * speed,
		"speed": float(speed),
		"radius": radius,
		"color": color,
		"source_team": source_team,
		"source_index": int(source_index),
		"damage": int(max(0, damage)),
		"crit": bool(crit),
		"target_index": int(target_index),
		"target_ref": weakref(target_control) if target_control != null else null,
		"target_pos": end_pos,
		"source_ref": weakref(source_control) if source_control != null else null,
		"arc_curve": max(0.0, float(arc_curve)),
		"arc_freq": max(0.0, float(arc_freq)),
		"arc_phase": randf() * (PI * 2.0),
		"elapsed": 0.0,
		"emit_hit_on_arrival": bool(emit_hit_on_arrival),
	}
	_increment_debug_counter(_debug_fired, source_team)
	if target_control == null:
		_increment_debug_counter(_debug_missing_target, source_team)
	_debug_remember({
		"event": "fire",
		"team": source_team,
		"source_index": int(source_index),
		"target_index": int(target_index),
		"start": _format_vector(start_pos),
		"end": _format_vector(end_pos),
		"target_control": target_control != null,
	})
	_projectiles.append(proj)
	queue_redraw()

func _process(delta: float) -> void:
	if _projectiles.is_empty():
		return
	_to_remove.clear()

	# Snapshot size to avoid issues if list changes mid-loop
	var count: int = _projectiles.size()
	for i in range(count):
		if i >= _projectiles.size():
			break
		var p: Dictionary = _projectiles[i]
		# Home towards current target position if available
		var speed: float = float(p.get("speed", 600.0))
		var previous_pos: Vector2 = p["pos"] as Vector2
		var tc: Control = _control_from_ref(p.get("target_ref", null))
		if tc != null:
			var control_rect: Rect2 = tc.get_global_rect()
			var target_center: Vector2 = control_rect.get_center()
			p["target_pos"] = target_center
			var cur_pos: Vector2 = p["pos"]
			var d: Vector2 = target_center - cur_pos
			if d.length() > 0.001:
				var base_dir: Vector2 = d.normalized()
				var curve: float = float(p.get("arc_curve", 0.0))
				if curve > 0.0:
					var freq: float = float(p.get("arc_freq", 6.0))
					var t: float = float(p.get("elapsed", 0.0))
					var phase: float = float(p.get("arc_phase", 0.0))
					var perp: Vector2 = Vector2(-base_dir.y, base_dir.x)
					var sway: float = sin(t * freq + phase) * curve
					var dir2: Vector2 = (base_dir + perp * sway).normalized()
					p["vel"] = dir2 * speed
				else:
					p["vel"] = base_dir * speed
		p["pos"] = previous_pos + (p["vel"] as Vector2) * delta
		p["elapsed"] = float(p.get("elapsed", 0.0)) + delta
		_projectiles[i] = p

		var target_rect: Rect2 = _get_target_rect_for(p)
		var did_hit: bool = false
		if _swept_intersects_rect(previous_pos, p["pos"] as Vector2, float(p["radius"]), target_rect):
			if bool(p.get("emit_hit_on_arrival", true)):
				emit_signal("projectile_hit", String(p.get("source_team", "player")), int(p.get("source_index", -1)), int(p.get("target_index", -1)), int(p["damage"]), bool(p["crit"]))
				_increment_debug_counter(_debug_hits, String(p.get("source_team", "player")))
			_debug_remember({
				"event": "hit",
				"team": String(p.get("source_team", "player")),
				"source_index": int(p.get("source_index", -1)),
				"target_index": int(p.get("target_index", -1)),
				"pos": _format_vector(p["pos"] as Vector2),
				"target_rect": _format_rect(target_rect),
			})
			did_hit = true
			_to_remove.append(i)

		# Cull offscreen far outside viewport as a fallback
		var vp: Rect2 = get_viewport_rect()
		if not did_hit and not vp.grow(64).has_point((p["pos"] as Vector2)):
			_increment_debug_counter(_debug_culled, String(p.get("source_team", "player")))
			_debug_remember({
				"event": "cull",
				"team": String(p.get("source_team", "player")),
				"source_index": int(p.get("source_index", -1)),
				"target_index": int(p.get("target_index", -1)),
				"pos": _format_vector(p["pos"] as Vector2),
				"target_rect": _format_rect(target_rect),
			})
			_to_remove.append(i)

	if not _to_remove.is_empty():
		_to_remove.sort()
		var last_index: int = -1
		for j in range(_to_remove.size() - 1, -1, -1):
			var idx: int = int(_to_remove[j])
			if idx == last_index:
				continue
			last_index = idx
			if idx >= 0 and idx < _projectiles.size():
				_projectiles.remove_at(idx)
	# Always redraw while projectiles are active to animate smoothly
	queue_redraw()

func _draw() -> void:
	# Render all projectiles as circles (can be swapped for textured quads later)
	for i in range(_projectiles.size()):
		var p: Dictionary = _projectiles[i]
		var lp: Vector2 = get_global_transform().affine_inverse() * (p["pos"] as Vector2)
		var c: Color = Color(0.2, 0.8, 1.0) if String(p.get("source_team", "player")) == "player" else Color(1.0, 0.4, 0.2)
		draw_circle(lp, float(p["radius"]), c)

func _get_target_rect_for(p: Dictionary) -> Rect2:
	var tc: Control = _control_from_ref(p.get("target_ref", null))
	if tc != null:
		return tc.get_global_rect()
	var target_pos_value: Variant = p.get("target_pos", null)
	if target_pos_value is Vector2:
		var target_pos: Vector2 = target_pos_value
		var half_size: float = max(24.0, float(p.get("radius", 6.0)) * 4.0)
		return Rect2(target_pos - Vector2(half_size, half_size), Vector2(half_size * 2.0, half_size * 2.0))
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func _control_from_ref(ref_value: Variant) -> Control:
	var ref: WeakRef = ref_value as WeakRef
	if ref == null:
		return null
	return ref.get_ref() as Control

func _intersects_rect(pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size == Vector2.ZERO:
		return false
	var closest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return (closest - pos).length_squared() <= radius * radius

func _swept_intersects_rect(from_pos: Vector2, to_pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size == Vector2.ZERO:
		return false
	if _intersects_rect(to_pos, radius, rect) or _intersects_rect(from_pos, radius, rect):
		return true
	var grown_rect: Rect2 = rect.grow(radius)
	if grown_rect.has_point(from_pos) or grown_rect.has_point(to_pos):
		return true
	return _segment_intersects_rect(from_pos, to_pos, grown_rect)

func _segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	var top_left: Vector2 = rect.position
	var top_right: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var bottom_right: Vector2 = rect.position + rect.size
	var bottom_left: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	return (
		_segments_intersect(from_pos, to_pos, top_left, top_right)
		or _segments_intersect(from_pos, to_pos, top_right, bottom_right)
		or _segments_intersect(from_pos, to_pos, bottom_right, bottom_left)
		or _segments_intersect(from_pos, to_pos, bottom_left, top_left)
	)

func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var r: Vector2 = b - a
	var s: Vector2 = d - c
	var denominator: float = _cross(r, s)
	var offset: Vector2 = c - a
	if abs(denominator) < 0.000001:
		if abs(_cross(offset, r)) >= 0.000001:
			return false
		return _point_on_segment(c, a, b) or _point_on_segment(d, a, b) or _point_on_segment(a, c, d) or _point_on_segment(b, c, d)
	var t: float = _cross(offset, s) / denominator
	var u: float = _cross(offset, r) / denominator
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func _point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	var min_x: float = min(a.x, b.x) - 0.000001
	var max_x: float = max(a.x, b.x) + 0.000001
	var min_y: float = min(a.y, b.y) - 0.000001
	var max_y: float = max(a.y, b.y) + 0.000001
	return point.x >= min_x and point.x <= max_x and point.y >= min_y and point.y <= max_y

func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

func _reset_debug_counters() -> void:
	_debug_fired = {"player": 0, "enemy": 0}
	_debug_hits = {"player": 0, "enemy": 0}
	_debug_culled = {"player": 0, "enemy": 0}
	_debug_missing_target = {"player": 0, "enemy": 0}
	_debug_recent.clear()

func _increment_debug_counter(counters: Dictionary[String, int], team: String) -> void:
	var key: String = "player" if team == "player" else "enemy"
	counters[key] = int(counters.get(key, 0)) + 1

func _debug_remember(event: Dictionary) -> void:
	_debug_recent.append(event)
	while _debug_recent.size() > DEBUG_RECENT_LIMIT:
		_debug_recent.remove_at(0)

func _format_vector(value: Vector2) -> String:
	return "(%.1f,%.1f)" % [value.x, value.y]

func _format_rect(value: Rect2) -> String:
	return "(%.1f,%.1f %.1fx%.1f)" % [value.position.x, value.position.y, value.size.x, value.size.y]
