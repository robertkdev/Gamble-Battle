extends RefCounted
class_name ShopButtons

signal reroll_pressed()
signal lock_pressed()
signal buy_xp_pressed()

var _host: Container = null
var _bar: HBoxContainer = null
var _reroll: Button = null
var _lock: Button = null
var _buy_xp: Button = null
var _progress_label: Label = null

func configure(host_container: Container) -> HBoxContainer:
	_host = host_container
	_ensure_bar()
	return _bar

func _ensure_bar() -> void:
	if _host == null:
		return
	if _bar and is_instance_valid(_bar):
		return
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	_host.add_child(_bar)
	# Prefer top placement
	_host.move_child(_bar, 0)
	_reroll = Button.new()
	_reroll.text = "Reroll"
	_reroll.pressed.connect(func(): emit_signal("reroll_pressed"))
	_lock = Button.new()
	_lock.text = "Lock"
	_lock.toggle_mode = true
	_lock.pressed.connect(func(): emit_signal("lock_pressed"))
	_buy_xp = Button.new()
	_buy_xp.text = "Buy XP"
	_buy_xp.pressed.connect(func(): emit_signal("buy_xp_pressed"))
	_progress_label = Label.new()
	_progress_label.text = "Lvl 1 (0/0)"
	_progress_label.modulate = Color(1,1,1,0.9)
	_bar.add_child(_reroll)
	_bar.add_child(_lock)
	_bar.add_child(_buy_xp)
	_bar.add_child(_progress_label)

func get_bar() -> HBoxContainer:
	return _bar

func set_locked(locked: bool) -> void:
	if _lock:
		_lock.button_pressed = bool(locked)

func set_enabled(enabled: bool) -> void:
	var en := bool(enabled)
	if _reroll:
		_reroll.disabled = not en
	if _lock:
		_lock.disabled = not en
	if _buy_xp:
		_buy_xp.disabled = not en

func set_progress(level: int, xp: int, xp_to_next: int) -> void:
	if _progress_label == null:
		return
	var need: int = max(0, int(xp_to_next))
	var cur: int = max(0, int(xp))
	if need <= 0:
		_progress_label.text = "Lvl %d (MAX)" % int(level)
	else:
		_progress_label.text = "Lvl %d (%d/%d)" % [int(level), cur, need]

func set_reroll_tooltip(text: String) -> void:
	if _reroll:
		_reroll.tooltip_text = String(text)

func set_buy_xp_tooltip(text: String) -> void:
	if _buy_xp:
		_buy_xp.tooltip_text = String(text)
