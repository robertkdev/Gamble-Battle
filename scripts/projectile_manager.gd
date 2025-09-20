extends Control
class_name ProjectileManager

# Lightweight projectile container managed and rendered by this node.
# Designed to scale by avoiding per-projectile nodes.

# Extended to carry team + indices for multi-unit scenarios.
signal projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)

var _projectiles: Array[Dictionary] = []
var _to_remove: Array[int] = []

var player_sprite: TextureRect
var enemy_sprite: TextureRect

func configure(_player_sprite: TextureRect, _enemy_sprite: TextureRect) -> void:
	player_sprite = _player_sprite
	enemy_sprite = _enemy_sprite
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

func clear() -> void:
	_projectiles.clear()
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
		source_control: Control = null
	) -> void:
	var dir: Vector2 = (end_pos - start_pos)
	var dist: float = max(1.0, dir.length())
	dir /= dist
	var proj: Dictionary = {
		"pos": start_pos,
		"vel": dir * speed,
		"radius": radius,
		"color": color,
		"source_team": source_team,
		"source_index": int(source_index),
		"damage": int(max(0, damage)),
		"crit": bool(crit),
		"target_index": int(target_index),
		"target_control": target_control,
		"source_control": source_control,
	}
	_projectiles.append(proj)
	queue_redraw()

func _process(delta: float) -> void:
	if _projectiles.is_empty():
		return
	_to_remove.clear()

	# Snapshot size to avoid issues if list changes mid-loop
	var count := _projectiles.size()
	for i in range(count):
		if i >= _projectiles.size():
			break
		var p: Dictionary = _projectiles[i]
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		_projectiles[i] = p

		var target_rect: Rect2 = _get_target_rect_for(p)
		if _intersects_rect((p["pos"] as Vector2), float(p["radius"]), target_rect):
			# Notify hit, schedule removal
			emit_signal("projectile_hit", String(p.get("source_team", "player")), int(p.get("source_index", -1)), int(p.get("target_index", -1)), int(p["damage"]), bool(p["crit"]))
			_to_remove.append(i)

		# Cull offscreen far outside viewport as a fallback
		var vp: Rect2 = get_viewport_rect()
		if not vp.grow(64).has_point((p["pos"] as Vector2)):
			_to_remove.append(i)

	if not _to_remove.is_empty():
		_to_remove.sort()
		var last_index := -1
		for j in range(_to_remove.size() - 1, -1, -1):
			var idx := _to_remove[j]
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
	var tc = p.get("target_control", null)
	if tc and is_instance_valid(tc):
		return tc.get_global_rect()
	# Fallbacks for legacy single-target
	var is_player_target := String(p.get("source_team", "player")) == "enemy"
	var spr := player_sprite if is_player_target else enemy_sprite
	if spr and is_instance_valid(spr):
		return spr.get_global_rect()
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func _intersects_rect(pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size == Vector2.ZERO:
		return false
	var closest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return (closest - pos).length_squared() <= radius * radius
