extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const LOSS_SCENE: PackedScene = preload("res://scenes/ui/LossScreen.tscn")

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	var main: Control = MAIN_SCENE.instantiate() as Control
	add_child(main)
	await _settle_frames(8)
	_expect(main.get_node_or_null("TitlePage/BrandFrame") is PanelContainer, "title brand frame missing")
	_expect(_label_text(main, "TitlePage/Center/Stack/GameTitle") == "GAMBLE BATTLE", "title-page wordmark missing")
	_expect(_label_text(main, "TitlePage/Center/Stack/BrandKicker") == "OPEN THE BLACK LEDGER", "title-page kicker missing")
	var enter_button: Button = main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	_expect(enter_button != null and enter_button.text == "ENTER THE LEDGER", "title entry action is not branded")
	if enter_button != null:
		enter_button.emit_signal("pressed")
	await _settle_frames(8)
	_expect(_label_text(main, "TitleMenu/Center/VBox/GameTitle") == "GAMBLE\nBATTLE", "menu brand lockup missing")
	_expect(_label_text(main, "TitleMenu/Center/VBox/BrandKicker") == "THE BLACK LEDGER", "menu brand kicker missing")
	var title_sigil: TextureRect = main.get_node_or_null("TitleMenu/TitleSigil") as TextureRect
	_expect(title_sigil != null and title_sigil.visible, "menu sigil should be visible")
	var compact_roster_card: Node = main.find_child("HomeRoster", true, false)
	_expect(compact_roster_card == null, "compact command menu should not expose a clipped roster card")

	var combat_view: Control = main.get_node_or_null("CombatView") as Control
	var title_menu: Control = main.get_node_or_null("TitleMenu") as Control
	if title_menu != null:
		title_menu.visible = false
	if combat_view != null:
		combat_view.visible = true
		combat_view.set_process(true)
	await _settle_frames(5)
	var controller: Variant = combat_view.get("controller") if combat_view != null else null
	_expect(controller != null, "combat controller missing")
	if controller != null:
		controller.call("_show_result_banner", "VICTORY", "Round secured. Preparing your next decision.", Color(0.58, 0.72, 0.38, 1.0), Color(0.86, 0.94, 0.74, 1.0))
	await _settle_frames(5)
	var result_card: PanelContainer = combat_view.get_node_or_null("BattleResultBanner/Center/BattleResultCard") as PanelContainer if combat_view != null else null
	var result_emblem: TextureRect = combat_view.get_node_or_null("BattleResultBanner/Center/BattleResultCard/CardMargin/Content/OutcomeEmblem") as TextureRect if combat_view != null else null
	_expect(result_card != null and result_card.custom_minimum_size.y >= 220.0, "victory card should have cinematic presentation space")
	_expect(result_emblem != null and result_emblem.texture != null, "victory emblem missing")
	_expect(_label_text(combat_view, "BattleResultBanner/Center/BattleResultCard/CardMargin/Content/KickerLabel") == "THE LEDGER FAVORS YOU", "victory kicker missing")

	var loss_screen: LossScreen = LOSS_SCENE.instantiate() as LossScreen
	add_child(loss_screen)
	loss_screen.configure(null)
	await _settle_frames(5)
	_expect(_label_text(loss_screen, "Panel/Center/Frame/VBox/Title") == "THE HOUSE COLLECTS", "defeat headline missing")
	_expect(loss_screen.get_node_or_null("Panel/Center/Frame/DefeatSigil") is TextureRect, "defeat sigil missing")
	loss_screen.teardown()
	loss_screen.queue_free()

	if main.has_method("_teardown"):
		main.call("_teardown")
	main.queue_free()
	await _settle_frames(3)
	if _failures.is_empty():
		print("Sprint3VisualPresentationSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("Sprint3VisualPresentationSmoke: " + failure)
	get_tree().quit(1)

func _label_text(root: Node, path: String) -> String:
	if root == null:
		return ""
	var label: Label = root.get_node_or_null(path) as Label
	return String(label.text) if label != null else ""

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame
