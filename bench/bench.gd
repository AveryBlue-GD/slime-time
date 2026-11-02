extends SceneTree

## Reproducible performance harness for the cleanup audit (AUDIT.md). Not a test suite: it prints one
## `BENCH {json}` line per scenario that bench/run.sh collects. Fixed seeds, fixed frame counts, `--fixed-fps 60`
## (the simulation advances exactly 1/60 s per frame, so every run plays the same frames) and vsync off (frames
## run uncapped, so the wall time per frame is the real cost).
##
##   godot --path . --fixed-fps 60 -s res://bench/bench.gd -- --scenario=level10 [--frames=600] [--warmup=120]
##
## Scenarios (one per process, so memory high-water marks don't mix):
##   startup     engine start -> title screen's first drawn frame (ms since the process started)
##   title       the title screen
##   hub         the hub with all 8 stations (bench/run.sh passes --unlock-all)
##   level1      story level 1, the slime driven back and forth along a fixed route (never reaching the chalice)
##   level10     story level 10, same
##   random      randomizer seed 5 at MORE SLIME max (the v2 tree: 7), the biggest maze sizes
##   story       the story intro (scenes/story.tscn)
##   skins       the skins screen (bench/run.sh passes --unlock-all)
##
## Per frame it records the wall time between frames and the time spent in node _process/_physics_process (between
## two stamp nodes at the extreme process priorities). At the end it reports avg / p50 / p95 / p99 / max frame ms,
## avg script ms, the static memory high-water mark (OS.get_static_memory_peak_usage), node / object counts, and the
## render counters (draw calls etc.; zero under --headless, real under a display such as xvfb-run).
## Saving is off for the whole run (tools and headless runs never write the real save anyway, see CLAUDE.md).

const SCENES := {
	title = "res://scenes/title.tscn",
	hub = "res://scenes/hub.tscn",
	story = "res://scenes/story.tscn",
	skins = "res://scenes/skins.tscn",
}
const GAME := preload("res://scenes/main.tscn")

var scenario := "level1"
var frames := 600
var warmup := 120

var _stamp_first: Node
var _stamp_last: Node
var _times: PackedFloat64Array = []
var _script: PackedFloat64Array = []
var _last_frame_us := 0
var _measuring := false
var _game: Node2D
var _traveled := 0.0  ## px the slime moved during the measurement (proves the pilot drove it)
var _last_pos := Vector2.INF


class Stamp:
	extends Node
	var at := 0
	var phys_at := 0
	var phys_sum := 0

	func _process(_d: float) -> void:
		at = Time.get_ticks_usec()

	func _physics_process(_d: float) -> void:
		phys_at = Time.get_ticks_usec()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.trim_prefix("--scenario=")
		elif a.begins_with("--frames="):
			frames = a.trim_prefix("--frames=").to_int()
		elif a.begins_with("--warmup="):
			warmup = a.trim_prefix("--warmup=").to_int()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	var progress := root.get_node("Progress")
	progress.saving_enabled = false
	if scenario == "startup":
		await _startup()
		return
	_stamp_first = Stamp.new()
	_stamp_first.process_priority = -1000000
	_stamp_first.process_physics_priority = -1000000
	_stamp_last = Stamp.new()
	_stamp_last.process_priority = 1000000
	_stamp_last.process_physics_priority = 1000000
	root.add_child(_stamp_first)
	root.add_child(_stamp_last)
	var load_start := Time.get_ticks_usec()
	match scenario:
		"level1":
			_spawn_level({level = 1})
		"level10":
			_spawn_level({level = 10})
		"random":
			_spawn_level({random_seed = 5})
		_:
			if not SCENES.has(scenario):
				printerr("unknown scenario " + scenario)
				quit(2)
				return
			change_scene_to_file(SCENES[scenario])
	await process_frame
	await process_frame
	var load_ms := (Time.get_ticks_usec() - load_start) / 1000.0
	for i in warmup:
		await process_frame
	_measuring = true
	_last_frame_us = Time.get_ticks_usec()
	for i in frames:
		await process_frame
	_measuring = false
	_report(load_ms)
	quit(0)


func _process(_delta: float) -> bool:
	if _measuring:
		var now := Time.get_ticks_usec()
		_times.append((now - _last_frame_us) / 1000.0)
		_last_frame_us = now
		# node _process span this frame (first stamp -> last stamp) plus physics span (first -> last), when they ran
		var span := maxi(_stamp_last.at - _stamp_first.at, 0)
		var phys := maxi(_stamp_last.phys_at - _stamp_first.phys_at, 0)
		_script.append((span + phys) / 1000.0)
		_stamp_first.phys_at = 0
		_stamp_last.phys_at = 0
		if _game != null and is_instance_valid(_game.slime):
			if _last_pos != Vector2.INF:
				_traveled += _game.slime.position.distance_to(_last_pos)
			_last_pos = _game.slime.position
	return false


## Story level or randomizer maze, the slime steered by RoutePilot along a fixed back-and-forth route that never
## touches the goal cell, with the meter frozen (game.dev_no_drain), so the level never ends during the measurement.
func _spawn_level(settings: Dictionary) -> void:
	if settings.has("random_seed"):
		var progress := root.get_node("Progress")
		progress.mode = progress.MODE_RANDOM
		var id: String = Upgrades.LIST[0].id  # MORE SLIME at its max: the biggest randomizer mazes
		progress.upgrades[id] = Upgrades.max_level(id)
	_game = GAME.instantiate()
	for key: String in settings:
		_game.set(key, settings[key])
	root.add_child(_game)
	await physics_frame
	_game.dev_no_drain = true
	var pilot := RoutePilot.new()
	pilot.cells = _tour(_game.maze)
	_game.add_child(pilot)


## start -> the farthest cell whose route avoids the goal -> start, repeated (deterministic for a given maze).
static func _tour(maze: Dictionary) -> Array[Vector2i]:
	var dist := MazeGenerator.distances_from(maze, maze.start)
	var best := maze.start as Vector2i
	var best_d := -1
	for cell: Vector2i in dist:
		if dist[cell] > best_d and cell != maze.goal:
			var path := MazeGenerator.shortest_path(maze, maze.start, cell)
			if maze.goal not in path:
				best = cell
				best_d = dist[cell]
	var out_path := MazeGenerator.shortest_path(maze, maze.start, best)
	var back := out_path.duplicate()
	back.reverse()
	var cells: Array[Vector2i] = []
	for i in 40:
		cells.append_array(out_path if i % 2 == 0 else back)
	return cells


func _startup() -> void:
	change_scene_to_file(SCENES.title)
	await process_frame
	await process_frame
	await process_frame
	var ms := Time.get_ticks_msec()
	print("BENCH " + JSON.stringify({scenario = "startup", startup_ms = ms,
		mem_peak_mb = snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.01)}))
	quit(0)


func _report(load_ms: float) -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for t in sorted:
		total += t
	var script_total := 0.0
	for t in _script:
		script_total += t
	var out := {
		scenario = scenario,
		frames = n,
		avg_ms = snappedf(total / n, 0.001),
		p50_ms = snappedf(sorted[n / 2], 0.001),
		p95_ms = snappedf(sorted[int(n * 0.95)], 0.001),
		p99_ms = snappedf(sorted[int(n * 0.99)], 0.001),
		max_ms = snappedf(sorted[-1], 0.001),
		script_ms = snappedf(script_total / n, 0.001),
		load_ms = snappedf(load_ms, 0.1),
		mem_peak_mb = snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.01),
		mem_now_mb = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		objects = int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		render_objects = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		finished = _game.finished if _game != null else false,
		traveled_px = int(_traveled),
	}
	print("BENCH " + JSON.stringify(out))
