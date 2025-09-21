extends Node

func _ready() -> void:
	var runs: int = 2300
	var tick: float = 0.1
	var role_a: String = "none"
	var role_b: String = "none"
	var unit_a: String = "sari"
	var unit_b: String = "nyxa"
	var max_frames: int = 200
	var placeholder: bool = false
	var A_cost: int = 1
	var A_level: int = 1
	var B_cost: int = 1
	var B_level: int = 1

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--runs="):
			runs = int(arg.substr(7))
		elif arg.begins_with("--tick="):
			tick = float(arg.substr(7))
		elif arg.begins_with("--roleA="):
			role_a = arg.substr(8)
		elif arg.begins_with("--roleB="):
			role_b = arg.substr(8)
		elif arg.begins_with("--unitA="):
			unit_a = arg.substr(8)
		elif arg.begins_with("--unitB="):
			unit_b = arg.substr(8)
		elif arg.begins_with("--maxframes="):
			max_frames = int(arg.substr(12))
		elif arg == "--placeholder":
			placeholder = true
		elif arg.begins_with("--A_cost="):
			A_cost = int(arg.substr(9))
		elif arg.begins_with("--A_level="):
			A_level = int(arg.substr(10))
		elif arg.begins_with("--B_cost="):
			B_cost = int(arg.substr(9))
		elif arg.begins_with("--B_level="):
			B_level = int(arg.substr(10))

	var sim: Object = load("res://tests/unit_sim.gd").new()
	var result: Dictionary
	if placeholder:
		result = sim.run_1v1_placeholders(A_cost, A_level, B_cost, B_level, runs, tick, max_frames, 6.0, 3.0)
	else:
		result = sim.run_1v1(role_a, role_b, runs, tick, unit_a, unit_b, 1, 1, max_frames, 6.0, 3.0)
	var a_pct: float = float(result.get("A_pct", 0.0))
	var b_pct: float = float(result.get("B_pct", 0.0))
	var d_pct: float = float(result.get("D_pct", 0.0))
	var ran: int = int(result.get("runs", runs))
	var who := ("placeholder A(cost="+str(A_cost)+",lvl="+str(A_level)+") vs B(cost="+str(B_cost)+",lvl="+str(B_level)+")" if placeholder else unit_a+"["+role_a+"] vs "+unit_b+"["+role_b+"]")
	var summary := "UnitSim 1v1 (" + who + " runs=" + str(ran) + " tick=" + str(tick) + (" maxf=" + str(max_frames) if max_frames > 0 else "") + "): A=" + str(snapped(a_pct, 0.1)) + "% B=" + str(snapped(b_pct, 0.1)) + "% D=" + str(snapped(d_pct, 0.1)) + "%"
	prints(summary)
	var out := FileAccess.open("res://tests/unit_sim_results.txt", FileAccess.WRITE)
	if out:
		out.store_line(summary)
		out.close()
	get_tree().quit(0)
