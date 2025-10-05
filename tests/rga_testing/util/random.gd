extends RefCounted
class_name RGARandom

# Pure deterministic helpers for seeds and sub-seeds.
# Uses SplitMix64-style mixing; all functions are pure (no global state).

const MASK64: int = 0xFFFFFFFFFFFFFFFF
const GOLDEN_GAMMA: int = 0x9E3779B97F4A7C15 # 2^64 / phi

static func _u64(x: int) -> int:
    return int(x) & MASK64

static func mix64(x: int) -> int:
    # SplitMix64 finalizer
    var z := _u64(x)
    z = _u64(z ^ (z >> 30))
    z = _u64(z * 0xBF58476D1CE4E5B9)
    z = _u64(z ^ (z >> 27))
    z = _u64(z * 0x94D049BB133111EB)
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
    var hash: int = 0xcbf29ce484222325
    var prime: int = 0x100000001b3
    for i in s.length():
        hash = _u64(hash ^ int(s.unicode_at(i)))
        hash = _u64(hash * prime)
    return _u64(hash)

static func combine64(a: int, b: int) -> int:
    # Symmetric-ish combiner then mix
    var x := _u64(a) ^ _u64(b)
    x = _u64(x + (_u64(a) * 0x9E3779B185EBCA87))
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

