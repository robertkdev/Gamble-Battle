extends RefCounted
class_name EconomyUI

var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var _root: Node = null

func configure(_gold_label: Label, _bet_slider: HSlider, _bet_value: Label, root: Node = null) -> void:
	gold_label = _gold_label
	bet_slider = _bet_slider
	bet_value = _bet_value
	_root = root
	refresh()
	if _has_economy():
		Economy.gold_changed.connect(func(_g): refresh())
		Economy.bet_changed.connect(func(_b): refresh())

func _has_economy() -> bool:
	if Engine.has_singleton("Economy"):
		return true
	if _root and _root.get_tree():
		var econ = _root.get_tree().root.get_node_or_null("Economy")
		return econ != null
	return false

func refresh() -> void:
	if not _has_economy():
		return
	if gold_label:
		gold_label.text = "Gold: " + str(Economy.gold)
	if bet_slider:
		bet_slider.min_value = 1 if Economy.gold > 0 else 0
		bet_slider.max_value = max(1, Economy.gold)
		if Economy.current_bet > 0:
			bet_slider.value = clamp(Economy.current_bet, bet_slider.min_value, bet_slider.max_value)
		else:
			bet_slider.value = min(1, bet_slider.max_value)
	if bet_value and bet_slider:
		bet_value.text = str(int(bet_slider.value))

func on_bet_changed(val: float) -> void:
	if not _has_economy():
		return
	Economy.set_bet(int(val))
	if bet_value:
		bet_value.text = str(int(val))

func set_bet_editable(editable: bool) -> void:
	if bet_slider:
		bet_slider.editable = editable
