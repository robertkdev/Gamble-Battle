extends RefCounted
class_name RGARandom

# Pure deterministic helpers for seeds and sub-seeds.
# Uses SplitMix64-style mixing; all functions are pure (no global state).

const MASK64: int = -1
const GOLDEN_GAMMA: int = -7046029254386353131 # 0x9E3779B97F4A7C15 (2^64/phi) as signed 64-bit

static func _u64(x: int) -> int:
    return int(x) & MASK64

static func mix64(x: int) -> int:
    # SplitMix64 finalizer (constants expressed as signed 64-bit to avoid hex literal overflow)
    var z := _u64(x)
    z = _u64(z ^ (z >> 30))
    z = _u64(z * int(-4658895280553007687)) # 0xBF58476D1CE4E5B9
    z = _u64(z ^ (z >> 27))
    z = _u64(z * int(-7723592293110705685)) # 0x94D049BB133111EB
    z = _u64(z ^ (z >> 31))
    return z

static func step_splitmix(x: int) -> int:
    # Advances a SplitMix64 state and returns the new state (not the output)
    return _u64(x + GOLDEN_GAMMA)

static func out_splitmix(x: int) -> int:
    # Outputs a mixed value from the given SplitMix64 state
    return mix64(x)

static func hash_string64(s: String) -> int:
    # FNV-1a 64-bit hash for strings (simple, deterministic)
    var hash: int = int(-3750763034362895579) # 0xcbf29ce484222325
    var prime: int = 1099511628211 # 0x100000001b3
    for i in s.length():
        hash = _u64(hash ^ int(s.unicode_at(i)))
        hash = _u64(hash * prime)
    return _u64(hash)

static func combine64(a: int, b: int) -> int:
    # Symmetric-ish combiner then mix (avoid oversized hex literals by composing 64-bit value)
    var x := _u64(a) ^ _u64(b)
    var mul_hi: int = 2654435761      # 0x9E3779B1
    var mul_lo: int = 2246822519      # 0x85EBCA87
    var mul64: int = _u64((mul_hi << 32) + mul_lo) # 0x9E3779B185EBCA87
    x = _u64(x + (_u64(a) * mul64))
    x = _u64(x + (_u64(b) << 1))
    return mix64(x)

static func seed_from(run_id: String, sim_index: int) -> int:
    # Derive a deterministic 64-bit seed from run_id and sim_index.
    var base := hash_string64(String(run_id))
    var idx := _u64(sim_index) * GOLDEN_GAMMA
    var s := combine64(base, idx)
    s = _u64(s | 1) # avoid zero/evens; keep non-zero
    return s

static func subseed(seed: int, label: String) -> int:
    # Derive a stable sub-seed for a component/entity from a base seed and label.
    var h := hash_string64(label)
    var x := combine64(seed, h)
    x = _u64(x | 1)
    return x

static func subseed_i(seed: int, index: int) -> int:
    var x := combine64(seed, _u64(index))
    x = _u64(x | 1)
    return x

static func next_seed(seed: int) -> int:
    # Advance a seed in SplitMix64 sequence; useful for deterministic streams.
    return step_splitmix(seed)
