extends SceneTree

## Micro-benchmarks for single functions the cleanup audit changed (AUDIT.md section 4 cites them). Each case
## times one call path many times in this process and prints `MICRO {json}` (microseconds per call, median of
## ROUNDS rounds). Cheaper and steadier than a whole-scene bench for a change to one function, and it can time
## the old and new path of a change in the same process (the A/B cases), so machine load hits both alike.
##
##   godot --path . --headless --fixed-fps 60 -s res://bench/micro.gd -- --case=hub_hints [--unlock-all]
##
## Cases:
##   hub_hints     Hub._place_hints() with the station names showing and after they hid (C-01: the solver now
##                 runs only while they show). Needs --unlock-all (all 8 stations).

const ROUNDS := 7

var case_name := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			case_name = a.trim_prefix("--case=")
	await process_frame
	root.get_node("Progress").saving_enabled = false
	match case_name:
		"hub_hints":
			await _hub_hints()
		_:
			push_error("micro.gd: unknown --case=%s" % case_name)
	quit(0)


## Median microseconds per call of `fn` over ROUNDS rounds of `calls` calls.
func _time(fn: Callable, calls: int) -> float:
	var rounds: Array[float] = []
	for r in ROUNDS:
		var t0 := Time.get_ticks_usec()
		for i in calls:
			fn.call()
		rounds.append(float(Time.get_ticks_usec() - t0) / calls)
	rounds.sort()
	return rounds[ROUNDS / 2]


func _report(data: Dictionary) -> void:
	data.case = case_name
	print("MICRO " + JSON.stringify(data))


func _hub_hints() -> void:
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 10:
		await process_frame
	hub.name_layer.visible = true
	var shown := _time(hub._place_hints, 500)
	hub.name_layer.visible = false
	var hidden := _time(hub._place_hints, 500)
	_report({stations = hub.stations.size(), names_shown_us = snappedf(shown, 0.01), names_hidden_us = snappedf(hidden, 0.01)})
