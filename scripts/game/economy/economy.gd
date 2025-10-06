extends Node

signal gold_changed(gold: int)
signal bet_changed(bet: int)

var gold: int = 2
var current_bet: int = 1
var preferred_bet: int = 1   # Remember last chosen bet outside combat

# Combat credit tracking
var combat_active: bool = false
var combat_credit_base: int = 0   # 2*bet - 1 at combat start
var combat_spent: int = 0         # Sum of spends during this combat
var last_gold_start: int = 0      # Gold at the moment combat started (before escrow)
var last_bet_start: int = 0       # Bet amount at the moment combat started

func _ready() -> void:
	gold = 2
	current_bet = 1
	preferred_bet = current_bet

func reset_run() -> void:
	gold = 2
	current_bet = min(1, gold)
	preferred_bet = current_bet
	combat_active = false
	combat_credit_base = 0
	combat_spent = 0
	last_gold_start = 0
	last_bet_start = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)

func set_bet(amount: int) -> bool:
	# Ignore bet changes during combat to preserve the wager placed at start
	if combat_active:
		return current_bet > 0
	var a: int = int(clamp(amount, 0, max(0, gold)))
	if a != current_bet:
		current_bet = a
		preferred_bet = a
		bet_changed.emit(current_bet)
	return current_bet > 0

func start_combat() -> void:
	# Escrow the bet at combat start
	var b: int = max(0, current_bet)
	# Mark combat active before emitting signals so reactive UI cannot change the bet mid-combat
	combat_active = true
	# Capture snapshot of gold and bet at the start for next-round heuristics
	last_gold_start = gold
	last_bet_start = b
	if b > 0:
		gold = max(0, gold - b)
		gold_changed.emit(gold)
	combat_credit_base = max(0, 2 * b - 1)
	combat_spent = 0

func adjust_combat_spent(delta: int) -> void:
	if not combat_active:
		return
	combat_spent = max(0, combat_spent + int(delta))

func get_available_combat_credit() -> int:
	return int(gold + combat_credit_base - combat_spent)

func resolve(win: bool) -> void:
	var b: int = max(0, current_bet)
	if combat_active:
		var payout: int = (2 * b) if win else 0
		gold = max(0, gold + payout - combat_spent)
		combat_active = false
		combat_credit_base = 0
		combat_spent = 0
		# Intelligent next-bet default:
		# If player went all-in last round (bet >= gold at start), assume same for next
		# and default slider to full (preferred_bet = new gold).
		if last_gold_start > 0 and last_bet_start >= last_gold_start:
			preferred_bet = gold
		else:
			# Otherwise, keep previous preferred bet but clamp to current gold
			preferred_bet = int(clamp(preferred_bet, (1 if gold > 0 else 0), gold))
	else:
		# Legacy fallback
		if win:
			gold += b
		else:
			gold -= b
	current_bet = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)

func is_broke() -> bool:
	return gold <= 0

func add_gold(amount: int) -> void:
	var delta: int = int(amount)
	if delta == 0:
		return
	gold = max(0, gold + delta)
	gold_changed.emit(gold)
