extends RefCounted
class_name RollingWindow

# RollingWindow: fixed-size circular buffer with running sum.
# Constant-time push and sum of full window; sum_last(n) is O(min(n, count)).
# Intended sampling cadence: 5–10 Hz via caller (_process or timer).

var _cap: int = 1
var _buf: Array[float] = []
var _cursor: int = 0     # next write index
var _filled: int = 0     # number of valid samples stored (<= _cap)
var _sum: float = 0.0

func configure(size: int) -> void:
    _cap = max(1, int(size))
    _buf.resize(_cap)
    for i in range(_cap):
        _buf[i] = 0.0
    _cursor = 0
    _filled = 0
    _sum = 0.0

func clear() -> void:
    if _buf.is_empty():
        return
    for i in range(_buf.size()):
        _buf[i] = 0.0
    _cursor = 0
    _filled = 0
    _sum = 0.0

func push(value: float) -> void:
    var v: float = float(value)
    if _filled < _cap:
        _buf[_cursor] = v
        _sum += v
        _cursor = (_cursor + 1) % _cap
        _filled += 1
    else:
        # Overwrite oldest; adjust running sum
        var old: float = _buf[_cursor]
        _buf[_cursor] = v
        _sum += (v - old)
        _cursor = (_cursor + 1) % _cap

func sum() -> float:
    return _sum

func sum_last(n: int) -> float:
    var k: int = clamp(int(n), 0, _filled)
    if k <= 0:
        return 0.0
    var total: float = 0.0
    var idx: int = (_cursor - 1 + _cap) % _cap
    for _i in range(k):
        total += _buf[idx]
        idx = (idx - 1 + _cap) % _cap
    return total

func count() -> int:
    return _filled

func capacity() -> int:
    return _cap

func is_full() -> bool:
    return _filled >= _cap

