extends Node

const MentorLink := preload("res://scripts/game/traits/runtime/mentor_link.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_no_candidate_when_shared_traits_only(failures)
	_check_prefers_nearest_non_shared(failures)
	_check_missing_position_safeguard(failures)
	_check_equal_position_guardrail(failures)

	if failures.is_empty():
		print("MentorLinkNoSharedTraitProbe: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			printerr("MentorLinkNoSharedTraitProbe: ", failure)
		get_tree().quit(1)

func _check_no_candidate_when_shared_traits_only(failures: Array[String]) -> void:
	var team: Array[Unit] = []
	team.append(_spawn("axiom", failures))
	team.append(_spawn("sari", failures))
	team.append(_spawn("juno_vale", failures))
	var map: Array[int] = MentorLink.compute_for_team(team, [
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(2.0, 1.0),
	])
	_assert_eq(map.size(), 3, "shared-trait probe team 1 map size", failures)
	if map.size() >= 1:
		_assert_eq(map[0], -1, "Axiom should stay unpaired when all allies share traits", failures)

func _check_prefers_nearest_non_shared(failures: Array[String]) -> void:
	var team: Array[Unit] = []
	team.append(_spawn("axiom", failures))
	team.append(_spawn("bo", failures))
	team.append(_spawn("volt", failures))
	var map: Array[int] = MentorLink.compute_for_team(team, [
		Vector2(0.0, 0.0),
		Vector2(3.0, 0.0),
		Vector2(4.0, 0.0),
	])
	_assert_eq(map.size(), 3, "distance probe team 2 map size", failures)
	if map.size() >= 1:
		_assert_eq(map[0], 1, "Axiom should prefer nearest non-shared ally (bo=1), map=%s" % str(map), failures)
	# miri and bo are not mentors in this board
	_assert_eq(map[1], -1, "non-mentor index 1 must be -1", failures)
	_assert_eq(map[2], -1, "non-mentor index 2 must be -1", failures)

func _check_missing_position_safeguard(failures: Array[String]) -> void:
	var team: Array[Unit] = []
	team.append(_spawn("axiom", failures))
	team.append(_spawn("miri", failures))
	var map: Array[int] = MentorLink.compute_for_team(team, [
		Vector2(0.0, 0.0),
	])
	_assert_eq(map.size(), 2, "missing-position probe map size", failures)
	_assert_eq(map[0], -1, "mentor with missing teammate position should not invent a pupil", failures)

func _check_equal_position_guardrail(failures: Array[String]) -> void:
	var team: Array[Unit] = []
	team.append(_spawn("axiom", failures))
	team.append(_spawn("bo", failures))
	team.append(_spawn("miri", failures))
	var map: Array[int] = MentorLink.compute_for_team(team, [
		Vector2.ZERO,
		Vector2.ZERO,
		Vector2.ZERO,
	])
	_assert_eq(map.size(), 3, "equal-position guardrail map size", failures)
	_assert_eq(map[0], -1, "mentor should not invent a pupil when all ally positions are identical", failures)
	_assert_eq(map[1], -1, "non-mentor index 1 must stay -1 with identical positions", failures)
	_assert_eq(map[2], -1, "non-mentor index 2 must stay -1 with identical positions", failures)

func _spawn(unit_id: String, failures: Array[String]) -> Unit:
	var unit: Unit = UnitFactory.spawn(unit_id)
	if unit == null:
		failures.append("failed to spawn %s" % unit_id)
		return null
	return unit

func _assert_eq(actual: int, expected: int, message: String, failures: Array[String]) -> void:
	if int(actual) != int(expected):
		failures.append("%s (got %d expected %d)" % [message, int(actual), int(expected)])
