extends Node
class_name UnitEffectPlayer

const EFFECT_LEVEL_UP := "unit_level_up"
const EFFECT_HIT := "unit_hit"
const LevelUpEffect := preload("res://scripts/ui/vfx/effects/unit_level_up_effect.gd")
const HitEffect := preload("res://scripts/ui/vfx/effects/unit_hit_effect.gd")

var host: Control
var sprite: Control
var default_ring_parent: Control
var default_flash_parent: Control

var _active_effects: Dictionary = {}

func configure(_host: Control, _sprite: Control = null) -> void:
	host = _host
	sprite = _sprite
	default_ring_parent = host
	default_flash_parent = host

func set_sprite(_sprite: Control) -> void:
	sprite = _sprite

func set_default_overlay_parents(ring_parent: Control, flash_parent: Control = null) -> void:
	default_ring_parent = ring_parent
	default_flash_parent = flash_parent if flash_parent != null else ring_parent

func play(effect_id: String, params: Dictionary = {}) -> void:
	if host == null:
		return
	var effect: Node = _instantiate_effect(effect_id)
	if effect == null:
		return
	var payload := params.duplicate(true)
	if not payload.has("host"):
		payload["host"] = host
	if sprite != null and not payload.has("sprite"):
		payload["sprite"] = sprite
	if default_ring_parent != null and not payload.has("ring_parent"):
		payload["ring_parent"] = default_ring_parent
	if default_flash_parent != null and not payload.has("flash_parent"):
		payload["flash_parent"] = default_flash_parent

	_replace_active(effect_id)
	add_child(effect)
	_active_effects[effect_id] = effect
	if effect.has_signal("finished"):
		effect.finished.connect(func():
			if _active_effects.get(effect_id) == effect:
				_active_effects.erase(effect_id)
			if is_instance_valid(effect) and effect.is_inside_tree():
				effect.queue_free()
		)
	if effect.has_method("configure"):
		effect.configure(payload)
	if effect.has_method("play"):
		effect.play()

func cancel(effect_id: String) -> void:
	var node: Node = _active_effects.get(effect_id, null)
	if node and is_instance_valid(node):
		node.queue_free()
	_active_effects.erase(effect_id)

func _replace_active(effect_id: String) -> void:
	var node: Node = _active_effects.get(effect_id, null)
	if node and is_instance_valid(node):
		node.queue_free()
	_active_effects.erase(effect_id)

func _instantiate_effect(effect_id: String) -> Node:
	match effect_id:
		EFFECT_LEVEL_UP:
			return LevelUpEffect.new()
		EFFECT_HIT:
			return HitEffect.new()
		_:
			push_warning("[UnitEffectPlayer] Unknown effect id: %s" % effect_id)
			return null
