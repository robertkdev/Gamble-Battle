extends RefCounted
class_name EconomyUI

var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var _root: Node = null
var _bet_row: Control = null

func configure(_gold_label: Label, _bet_slider: HSlider, _bet_value: Label, root: Node = null) -> void:
	gold_label = _gold_label
	bet_slider = _bet_slider
	bet_value = _bet_value
	_root = root
	# Cache the row container so we can hide/show parts of it
	if bet_slider:
		_bet_row = bet_slider.get_parent()
	refresh()
	if _has_economy():
		Economy.gold_changed.connect(func(_g): refresh())
		Economy.bet_changed.connect(func(_b): refresh())
	# React to phase changes so we can hide/show slider exactly when combat starts/ends
	var gs = _get_gamestate()
	if gs and not gs.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gs.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(_prev: int, _next: int) -> void:
	refresh()

func _has_economy() -> bool:
	if Engine.has_singleton("Economy"):
		return true
	if _root and _root.get_tree():
		var econ = _root.get_tree().root.get_node_or_null("Economy")
		return econ != null
	return false

func _get_gamestate():
	# Resolve GameState autoload via globals or the scene tree
	if Engine.has_singleton("GameState"):
		return GameState
	if _root and _root.get_tree():
		return _root.get_tree().root.get_node_or_null("GameState")
	return null

func refresh() -> void:
	if not _has_economy():
		return
	if gold_label:
		gold_label.text = "Gold: " + str(Economy.gold)

	var in_combat: bool = false
	var gs = _get_gamestate()
	if gs != null:
		in_combat = (int(gs.phase) == int(gs.GamePhase.COMBAT))

	if bet_slider:
		bet_slider.min_value = 1 if Economy.gold > 0 else 0
		bet_slider.max_value = max(1, Economy.gold)
		# Choose a remembered value out of combat; show current bet during combat
		var target: int = 1
		if in_combat:
			target = max(0, int(Economy.current_bet))
		else:
			if Engine.has_singleton("Economy"):
				var _pref = Economy.get("preferred_bet")
				if _pref != null:
					target = int(_pref)
			elif int(Economy.current_bet) > 0:
				target = int(Economy.current_bet)
			target = int(clamp(target, bet_slider.min_value, bet_slider.max_value))
		bet_slider.value = target
		# Toggle visibility based on phase
		bet_slider.visible = not in_combat

	# Hide any static label siblings (e.g., left-side "Bet:") in combat
	if _bet_row:
		for ch in _bet_row.get_children():
			if ch is Label and ch != bet_value:
				ch.visible = not in_combat

	if bet_value:
		if in_combat:
			var locked_bet: int = int(Economy.current_bet)
			bet_value.text = "Bet: %d (locked)" % max(0, locked_bet)
			bet_value.visible = true
		else:
			if bet_slider:
				bet_value.text = str(int(bet_slider.value))
			else:
				bet_value.text = str(max(1, int(Economy.current_bet)))
			bet_value.visible = true

func on_bet_changed(val: float) -> void:
	if not _has_economy():
		return
	# Ignore programmatic slider updates while bet is locked (during combat)
	if bet_slider and not bet_slider.editable:
		return
	Economy.set_bet(int(val))
	if bet_value:
		bet_value.text = str(int(val))

func set_bet_editable(editable: bool) -> void:
	if bet_slider:
		bet_slider.editable = editable
