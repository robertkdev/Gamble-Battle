@tool
extends Node

const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")

const REQUIRED_GOAL_IDS: Array[String] = [
	"tank.frontline_absorb",
	"tank.team_fortification",
	"tank.initiate_fight",
	"tank.single_target_lockdown",
	"brawler.attrition_dps",
	"brawler.frontline_disruption",
	"brawler.skirmish_dive",
	"assassin.backline_elimination",
	"assassin.cleanup_execution",
	"assassin.disrupt_and_escape",
	"marksman.sustained_dps",
	"marksman.backline_siege",
	"marksman.tank_shredding",
	"mage.wombo_combo_burst",
	"mage.area_denial_zone",
	"mage.pick_burst",
	"mage.sustained_dps",
	"support.peel_carry",
	"support.team_amplification",
	"support.enemy_lockdown",
	"support.initiate_fight",
	"support.formation_breaking"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var descriptors: Array = MetricRegistry.list_metrics([])
	var metric_ids: Dictionary = {}
	for desc in descriptors:
		if not (desc is Dictionary):
			continue
		var metric_id: String = String((desc as Dictionary).get("id", "")).strip_edges()
		if metric_id != "":
			metric_ids[metric_id] = true

	var missing_approaches: Array[String] = []
	for raw_approach in IdentityKeys.APPROACHES:
		var approach_id: String = String(raw_approach).strip_edges()
		if approach_id == "":
			continue
		var expected_metric_id: String = "approach_%s" % approach_id
		if not metric_ids.has(expected_metric_id):
			missing_approaches.append("%s -> %s" % [approach_id, expected_metric_id])

	var missing_goal_resources: Array[String] = []
	for goal_id in REQUIRED_GOAL_IDS:
		var goal_path: String = "res://data/identity/goals/%s.tres" % String(goal_id).replace(".", "_")
		if not ResourceLoader.exists(goal_path):
			missing_goal_resources.append("%s -> %s" % [goal_id, goal_path])

	var failed: bool = false
	if not metric_ids.has("goal_primary"):
		printerr("ApproachCatalogCoverage: FAIL missing direct goal metric goal_primary")
		failed = true
	if not missing_approaches.is_empty():
		printerr("ApproachCatalogCoverage: FAIL missing approach metrics: ", missing_approaches)
		failed = true
	if not missing_goal_resources.is_empty():
		printerr("ApproachCatalogCoverage: FAIL missing goal resources: ", missing_goal_resources)
		failed = true

	if failed:
		get_tree().quit(1)
		return

	print("ApproachCatalogCoverage: PASS approaches=%d goals=%d metrics=%d" % [
		IdentityKeys.APPROACHES.size(),
		REQUIRED_GOAL_IDS.size(),
		metric_ids.size()
	])
	get_tree().quit(0)
