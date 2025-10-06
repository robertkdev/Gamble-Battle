extends Object
class_name StageTypes

# Stage kinds (canonical identifiers)
const KIND_NORMAL := "NORMAL"
const KIND_CREEPS := "CREEPS"
const KIND_ELITE := "ELITE"
const KIND_BOSS := "BOSS"
const KIND_EVENT := "EVENT"

const KNOWN_KINDS := [
    KIND_NORMAL,
    KIND_CREEPS,
    KIND_ELITE,
    KIND_BOSS,
    KIND_EVENT,
]

# StageSpec shape (Dictionary):
# {
#   ids: Array[String],
#   kind: String,           # one of KNOWN_KINDS
#   rules: Dictionary       # optional provider-specific config
# }

const KEY_IDS := "ids"
const KEY_KIND := "kind"
const KEY_RULES := "rules"

static func is_valid_kind(kind: String) -> bool:
    var k := String(kind).strip_edges().to_upper()
    return KNOWN_KINDS.has(k)

static func make_spec(ids: Array, kind: String = KIND_NORMAL, rules: Dictionary = {}) -> Dictionary:
    var k := String(kind).strip_edges().to_upper()
    if not is_valid_kind(k):
        k = KIND_NORMAL
    var spec: Dictionary = {}
    spec[KEY_IDS] = ids.duplicate(true)
    spec[KEY_KIND] = k
    spec[KEY_RULES] = rules.duplicate(true)
    return spec

static func validate_spec(spec: Dictionary) -> bool:
    if typeof(spec) != TYPE_DICTIONARY:
        return false
    if not spec.has(KEY_IDS) or not spec.has(KEY_KIND) or not spec.has(KEY_RULES):
        return false
    if typeof(spec[KEY_IDS]) != TYPE_ARRAY:
        return false
    if typeof(spec[KEY_KIND]) != TYPE_STRING:
        return false
    if typeof(spec[KEY_RULES]) != TYPE_DICTIONARY:
        return false
    return is_valid_kind(String(spec[KEY_KIND]))

