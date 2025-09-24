extends Object
class_name Trace
const Debug := preload("res://scripts/util/debug.gd")

static var _n: int = 1
static var _enabled: bool = false

static func reset(n: int = 1) -> void:
    _n = n

static func set_enabled(v: bool) -> void:
    _enabled = v

static func step(label: String) -> void:
    if not _enabled:
        return
    if Debug.enabled:
        print("[STEP ", _n, "] ", label)
    _n += 1
