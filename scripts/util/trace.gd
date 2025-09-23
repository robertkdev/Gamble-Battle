extends Object
class_name Trace

static var _n: int = 1
static var _enabled: bool = false

static func reset(n: int = 1) -> void:
    _n = n

static func set_enabled(v: bool) -> void:
    _enabled = v

static func step(label: String) -> void:
    if not _enabled:
        return
    print("[STEP ", _n, "] ", label)
    _n += 1
