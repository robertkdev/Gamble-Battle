extends Object
class_name Debug

# Simple logging utility with tag gating
static var enabled: bool = false
static var tags: = {
	"Arena": false,
	"ArenaSync": false,
	"Plan": false,
}

static func set_enabled(v: bool) -> void:
	enabled = v

static func enable_tag(tag: String, v: bool = true) -> void:
	tags[tag] = v

static func log(tag: String, msg: String) -> void:
	if not enabled:
		return
	if tags.get(tag, false):
		print("[%s] %s" % [tag, msg])
