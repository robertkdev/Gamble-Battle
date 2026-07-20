extends Node

const SMOKE_NAME: String = "Sprint4VisualAcceptanceSmoke"
const PortraitPresentationScript: GDScript = preload("res://scripts/ui/portrait_presentation.gd")
const COMBAT_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_portrait_crop_contract()
	_validate_unit_asset_inventory()
	await _validate_runtime_depth_layers()
	_finish()

func _validate_portrait_crop_contract() -> void:
	var tall_image: Image = Image.create(100, 160, false, Image.FORMAT_RGBA8)
	tall_image.fill(Color.WHITE)
	var tall_texture: ImageTexture = ImageTexture.create_from_image(tall_image)
	var tall_portrait: Texture2D = PortraitPresentationScript.normalize(tall_texture)
	_expect(tall_portrait is AtlasTexture, "vertical art was not converted to a portrait atlas")
	if tall_portrait is AtlasTexture:
		var region: Rect2 = (tall_portrait as AtlasTexture).region
		_expect(is_equal_approx(region.size.x, region.size.y), "vertical portrait crop is not square: %s" % str(region))
		_expect(region.position.y < 12.0, "vertical portrait focus drifted below the upper-body target: %s" % str(region))
	var square_image: Image = Image.create(120, 120, false, Image.FORMAT_RGBA8)
	square_image.fill(Color.WHITE)
	var square_texture: ImageTexture = ImageTexture.create_from_image(square_image)
	var square_portrait: Texture2D = PortraitPresentationScript.normalize(square_texture)
	_expect(square_portrait == square_texture, "near-square art should remain lossless and uncropped")

func _validate_unit_asset_inventory() -> void:
	var directory: DirAccess = DirAccess.open("res://assets/units")
	_expect(directory != null, "unit asset directory missing")
	if directory == null:
		return
	var checked: int = 0
	var normalized: int = 0
	directory.list_dir_begin()
	var filename: String = directory.get_next()
	while filename != "":
		if not directory.current_is_dir() and filename.to_lower().ends_with(".png"):
			var texture: Texture2D = load("res://assets/units/" + filename) as Texture2D
			_expect(texture != null, "unit art failed to load: %s" % filename)
			if texture != null:
				var portrait: Texture2D = PortraitPresentationScript.normalize(texture)
				_expect(portrait != null, "unit art failed normalization: %s" % filename)
				if portrait is AtlasTexture:
					normalized += 1
			checked += 1
		filename = directory.get_next()
	directory.list_dir_end()
	_expect(checked >= 50, "unit asset audit covered only %d files" % checked)
	_expect(normalized >= 10, "vertical unit-art normalization path was not exercised: %d" % normalized)

func _validate_runtime_depth_layers() -> void:
	var combat: Control = COMBAT_SCENE.instantiate() as Control
	add_child(combat)
	await _settle_frames(8)
	var atmosphere: Control = combat.find_child("ArenaAtmosphere", true, false) as Control
	_expect(atmosphere != null, "arena atmosphere layer missing")
	if atmosphere != null:
		_expect(atmosphere.z_index == -6, "arena atmosphere is not behind actors")
	var actor: UnitActor = UnitActor.new()
	add_child(actor)
	actor.set_size_px(Vector2(72.0, 72.0))
	actor.set_unit(UnitFactory.spawn("axiom"))
	await _settle_frames(2)
	var shadow: Panel = actor.get_node_or_null("GroundShadow") as Panel
	_expect(shadow != null, "combat actor ground shadow missing")
	if shadow != null:
		_expect(shadow.z_index < 0, "ground shadow must render behind the actor")
	actor.queue_free()
	if combat.has_method("_teardown"):
		combat.call("_teardown")
	combat.queue_free()
	await _settle_frames(3)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("%s: OK" % SMOKE_NAME)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("%s: %s" % [SMOKE_NAME, failure])
	get_tree().quit(1)
