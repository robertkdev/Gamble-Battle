extends RefCounted
class_name TickAccumulator

var period_s: float = 1.0
var _accum: float = 0.0
var _pulses: int = 0

func configure(period_seconds: float) -> void:
	set_period(max(0.001, float(period_seconds)))
	reset()

func set_period(period_seconds: float) -> void:
	period_s = max(0.001, float(period_seconds))

func reset() -> void:
	_accum = 0.0
	_pulses = 0

func accumulate(delta: float) -> void:
	var d: float = max(0.0, float(delta))
	if d <= 0.0:
		return
	_accum += d
	while _accum >= period_s:
		_pulses += 1
		_accum -= period_s

func consume_pulses() -> int:
	var n: int = _pulses
	_pulses = 0
	return n
