extends RefCounted
class_name RGATime

# Integer-only time helpers for deterministic math.
# Prefer microseconds (us) and integer ticks; avoid floats in outputs.

const US_PER_MS: int = 1000
const US_PER_SEC: int = 1_000_000
const DEFAULT_TICK_US: int = 50_000   # 20 Hz (delta = 0.05s)

static func now_us() -> int:
    # Monotonic-ish time in microseconds (best effort, engine-dependent).
    if Engine.has_singleton("Time") and Time.has_method("get_ticks_usec"):
        return int(Time.get_ticks_usec())
    if OS.has_method("get_ticks_msec"):
        return int(OS.get_ticks_msec()) * US_PER_MS
    return 0

static func sec_to_us(seconds: float) -> int:
    # Convert seconds (float) to microseconds (int), rounded to nearest us.
    return int(round(seconds * US_PER_SEC))

static func ms_to_us(ms: int) -> int:
    return int(ms) * US_PER_MS

static func us_to_ms(us: int) -> int:
    # Truncates toward zero.
    return int(us) / US_PER_MS

static func us_from_ticks(ticks: int, tick_us: int = DEFAULT_TICK_US) -> int:
    return int(ticks) * int(max(1, tick_us))

static func ticks_from_us(us: int, tick_us: int = DEFAULT_TICK_US) -> int:
    # Floor division to keep windows conservative.
    return int(us) / int(max(1, tick_us))

static func ticks_from_seconds(seconds: float, tick_us: int = DEFAULT_TICK_US, mode: String = "round") -> int:
    # Convert seconds (float) to integer ticks using the chosen rounding mode.
    var us := sec_to_us(seconds)
    var denom := int(max(1, tick_us))
    match String(mode).to_lower():
        "floor":
            return us / denom
        "ceil":
            return (us + denom - 1) / denom
        _:
            # round to nearest
            return (us + denom / 2) / denom

static func clamp_nonneg(v: int) -> int:
    return (v if v >= 0 else 0)

