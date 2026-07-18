extends Node

func _ready() -> void:
	var ids: PackedStringArray = Sound.list_ids()
	if ids.is_empty():
		push_error("AudioCatalogPackageProbe: no packaged audio streams discovered")
		get_tree().quit.call_deferred(1)
		return
	for id: String in ids:
		if not Sound.has(id):
			push_error("AudioCatalogPackageProbe: stream missing for %s" % id)
			get_tree().quit.call_deferred(1)
			return
	print("AudioCatalogPackageProbe: PASS streams=%d" % ids.size())
	get_tree().quit.call_deferred(0)
