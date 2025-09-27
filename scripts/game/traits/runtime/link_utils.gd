extends Object
class_name LinkUtils

const TickAccumulator := preload("res://scripts/game/traits/runtime/tick_accumulator.gd")

# Computes Liaison links (max 2 per unit) between adjacent allies with no shared traits,
# and detects triangles formed by these links.
# Positions are world-space; adjacency threshold is <= 1 tile (with epsilon).

static func compute(units: Array[Unit], positions: Array, tile_size: float, epsilon: float = 0.01) -> Dictionary:
	var n: int = units.size() if units != null else 0
	var deg: Array[int] = []
	for _i in range(n): deg.append(0)
	var candidates: Array = [] # Array[Dictionary{a:int,b:int,d2:float}]
	# Build candidate edges: adjacent and no shared traits
	for i in range(n):
		var u: Unit = units[i]
		if u == null:
			continue
		for j in range(i + 1, n):
			var v: Unit = units[j]
			if v == null:
				continue
			if _shares_any_trait(u, v):
				continue
			if _adjacent(positions, i, j, tile_size, epsilon):
				var d2: float = _dist2(positions, i, j)
				candidates.append({"a": i, "b": j, "d2": d2})
	# Greedy selection: shortest first, cap degree<=2
	candidates.sort_custom(func(a, b): return float(a.d2) < float(b.d2))
	var links: Array = [] # Array[Vector2i]
	var link_set: Dictionary = {} # key "a|b"
	for c in candidates:
		var a: int = int(c.a)
		var b: int = int(c.b)
		if deg[a] >= 2 or deg[b] >= 2:
			continue
		var key := _edge_key(a, b)
		if link_set.has(key):
			continue
		links.append(Vector2i(min(a, b), max(a, b)))
		link_set[key] = true
		deg[a] += 1
		deg[b] += 1
	# Detect triangles from links
	var triangles: Array = _triangles_from_links(n, links)
	return {"links": links, "triangles": triangles, "degrees": deg}

static func make_accumulator(period_s: float = 2.0) -> TickAccumulator:
	var acc: TickAccumulator = TickAccumulator.new()
	acc.configure(max(0.001, float(period_s)))
	return acc

# --- Internals ---
static func _adjacent(positions: Array, i: int, j: int, tile_size: float, epsilon: float) -> bool:
	var p: Vector2 = _pos_of(positions, i)
	var q: Vector2 = _pos_of(positions, j)
	var th: float = max(0.0, tile_size) + max(0.0, epsilon)
	return p.distance_to(q) <= th

static func _pos_of(positions: Array, idx: int) -> Vector2:
	if positions != null and idx >= 0 and idx < positions.size() and typeof(positions[idx]) == TYPE_VECTOR2:
		return positions[idx]
	return Vector2.ZERO

static func _dist2(positions: Array, i: int, j: int) -> float:
	var a: Vector2 = _pos_of(positions, i)
	var b: Vector2 = _pos_of(positions, j)
	return a.distance_squared_to(b)

static func _shares_any_trait(a: Unit, b: Unit) -> bool:
	if a == null or b == null:
		return true
	var set_a: Dictionary = {}
	for t in a.traits:
		set_a[String(t)] = true
	for t2 in b.traits:
		if set_a.has(String(t2)):
			return true
	return false

static func _edge_key(a: int, b: int) -> String:
	var x: int = min(a, b)
	var y: int = max(a, b)
	return str(x) + "|" + str(y)

static func _triangles_from_links(n: int, links: Array) -> Array:
	# Use untyped Arrays to avoid nested typed collection limitations in GDScript.
	var adj: Array = [] # each row is an Array of ints
	for _i in range(n):
		var row: Array = []
		adj.append(row)
	var has_edge: Dictionary = {}
	for e in links:
		var a: int = int(e.x)
		var b: int = int(e.y)
		adj[a].append(b)
		adj[b].append(a)
		has_edge[_edge_key(a, b)] = true
	# Unique triangles: enforce a < b < c ordering
	var tris: Array = []
	for a in range(n):
		var neigh_a: Array = adj[a]
		neigh_a.sort()
		for bi in range(neigh_a.size()):
			var b: int = int(neigh_a[bi])
			if b <= a:
				continue
			for ci in range(bi + 1, neigh_a.size()):
				var c: int = int(neigh_a[ci])
				if c <= b:
					continue
				if has_edge.has(_edge_key(b, c)):
					tris.append([a, b, c])
	return tris
