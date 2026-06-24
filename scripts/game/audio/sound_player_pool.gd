extends Object
class_name SoundPlayerPool

# Manages AudioStreamPlayer nodes and allows concurrent playback.

var _parent: Node = null
var _active: Dictionary = {} # Map[int, AudioStreamPlayer]
var _meta: Dictionary = {}   # Map[int, Dictionary]
var _next_id: int = 1
var _default_bus: String = "Master"

signal playback_finished(id: int)

func configure(parent: Node, default_bus: String = "Master") -> void:
	_parent = parent
	_default_bus = String(default_bus)

func set_default_bus(bus: String) -> void:
	_default_bus = String(bus)

func play(stream: AudioStream, options: Dictionary = {}) -> int:
	if _parent == null or stream == null:
		return -1
	var id: int = _next_id
	_next_id += 1
	var player := AudioStreamPlayer.new()
	_parent.add_child(player)
	player.bus = String(options.get("bus", _default_bus))
	player.volume_db = float(options.get("volume_db", 0.0))
	player.pitch_scale = float(options.get("pitch_scale", 1.0))
	var loop: bool = bool(options.get("loop", false))
	var from_pos: float = float(options.get("from_position", 0.0))
	# Set stream (duplicate when changing loop flag to avoid mutating shared resource)
	var use_stream: AudioStream = stream
	if loop:
		var dup = stream.duplicate()
		if dup != null:
			if dup.has_property("loop"):
				dup.set("loop", true)
			use_stream = dup
	player.stream = use_stream
	# Connect finished for cleanup / software loop fallback
	if not player.is_connected("finished", Callable(self, "_on_finished")):
		player.finished.connect(_on_finished.bind(id))
	_active[id] = player
	_meta[id] = {"loop": loop}
	if from_pos > 0.0:
		player.play(from_pos)
	else:
		player.play()
	return id

func stop(id: int) -> void:
	var p: AudioStreamPlayer = _active.get(int(id), null)
	if p != null:
		p.stop()
		_cleanup(id)

func stop_all() -> void:
	for k in _active.keys():
		var id: int = int(k)
		var p: AudioStreamPlayer = _active[id]
		if p != null:
			p.stop()
	_cleanup_all()

func set_volume(id: int, db: float) -> void:
	var p: AudioStreamPlayer = _active.get(int(id), null)
	if p != null:
		p.volume_db = float(db)

func busy_count() -> int:
	return _active.size()

func _on_finished(id: int) -> void:
	var p: AudioStreamPlayer = _active.get(int(id), null)
	if p == null:
		return
	var meta: Dictionary = _meta.get(int(id), {})
	var loop: bool = bool(meta.get("loop", false))
	if loop:
		p.play()
	else:
		playback_finished.emit(int(id))
		_cleanup(int(id))

func _cleanup(id: int) -> void:
	var p: AudioStreamPlayer = _active.get(int(id), null)
	_active.erase(int(id))
	_meta.erase(int(id))
	if p != null and is_instance_valid(p):
		p.queue_free()

func _cleanup_all() -> void:
	for k in _active.keys():
		var p: AudioStreamPlayer = _active[int(k)]
		if p != null and is_instance_valid(p):
			p.queue_free()
	_active.clear()
	_meta.clear()
