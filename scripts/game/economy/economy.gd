extends Node

signal gold_changed(gold: int)
signal bet_changed(bet: int)

var gold: int = 2
var current_bet: int = 1

func _ready() -> void:
	gold = 2
	current_bet = 1

func reset_run() -> void:
	gold = 2
	current_bet = min(1, gold)
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)

func set_bet(amount: int) -> bool:
	var a: int = int(clamp(amount, 0, max(0, gold)))
	if a != current_bet:
		current_bet = a
		bet_changed.emit(current_bet)
	return current_bet > 0

func resolve(win: bool) -> void:
	var b: int = max(0, current_bet)
	if b <= 0:
		return
	if win:
		gold += b
	else:
		gold -= b
	current_bet = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)

func is_broke() -> bool:
	return gold <= 0
