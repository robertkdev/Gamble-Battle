extends Control
class_name LossScreen

const Scoreboard := preload("res://scenes/ui/stats/Scoreboard.tscn")
const HighScore := preload("res://scripts/util/high_score.gd")

@onready var title_label: Label = $Panel/Center/VBox/Title
@onready var stage_label: Label = $Panel/Center/VBox/StageLabel
@onready var high_label: Label = $Panel/Center/VBox/HighLabel
@onready var stats_label: Label = $Panel/Center/VBox/Stats
@onready var scoreboard_holder: Control = $Panel/Center/VBox/ScoreboardHolder
@onready var new_game_button: Button = $Panel/Center/VBox/NewGameButton

var _tracker: StatsTracker = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if new_game_button and not new_game_button.is_connected("pressed", Callable(self, "_on_new_game")):
		new_game_button.pressed.connect(_on_new_game)

func configure(tracker: StatsTracker) -> void:
	_tracker = tracker
	_populate()

func _populate() -> void:
	# Title
	if title_label:
		title_label.text = "Defeat"
	# Stage reached and high score
	var stage_reached: int = 1
	if Engine.has_singleton("GameState"):
		stage_reached = int(GameState.stage)
	if stage_label:
		stage_label.text = "Stage Reached: %d" % stage_reached
	var best: int = HighScore.submit_stage(stage_reached)
	if high_label:
		high_label.text = "High Score (Stage): %d" % max(best, stage_reached)

	# Interesting run stats (from last battle tracker)
	var lines: Array[String] = []
	if _tracker != null:
		var dmg_total: float = _tracker.get_team_total("player", "damage", "ALL")
		var heal_total: float = _tracker.get_team_total("player", "healing", "ALL")
		var kills_total: float = _tracker.get_team_total("player", "kills", "ALL")
		var rows := _tracker.get_rows("player", "damage", "ALL")
		var top_name := ""
		var top_val: float = -1.0
		for r in rows:
			var v: float = float(r.get("value", 0.0))
			if v > top_val:
				top_val = v
				var u: Unit = r.get("unit")
				top_name = (u.name if u != null else "?")
		lines.append("Team Damage: %d" % int(dmg_total))
		lines.append("Team Healing: %d" % int(heal_total))
		lines.append("Total Kills: %d" % int(kills_total))
		if top_val >= 0.0:
			lines.append("Top Damage: %s (%d)" % [top_name, int(top_val)])
	if stats_label:
		stats_label.text = "\n".join(lines)

	# Scoreboard (player damage, expanded shows enemy in overlay sidebar)
	if scoreboard_holder and scoreboard_holder.get_child_count() == 0:
		var sb = Scoreboard.instantiate()
		scoreboard_holder.add_child(sb)
		if _tracker != null and sb.has_method("configure"):
			sb.configure(_tracker)
		if sb.has_method("set_metric"):
			sb.set_metric("damage")
		if sb.has_method("set_window"):
			sb.set_window("ALL")
		if sb.has_method("set_expanded"):
			sb.set_expanded(true)

func _on_new_game() -> void:
	# Reset run-related singletons and return to unit select flow
	if Engine.has_singleton("Economy"):
		Economy.reset_run()
	if Engine.has_singleton("Shop"):
		Shop.reset_run()
	if Engine.has_singleton("Roster") and Roster.has_method("reset"):
		Roster.reset()
	var main = get_tree().root.get_node_or_null("/root/Main")
	if main and main.has_method("_on_start"):
		main.call("_on_start")
	# Close this screen
	queue_free()
