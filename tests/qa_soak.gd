extends SceneTree

## QA soak / leak driver (NOT a test_*.gd suite: long, run by hand; see docs/qa-release-report.md section 2).
## Loops real scenes and prints node / object / orphan / resource / memory counters so drift shows:
##   story level starts, restarts (reload), wins (slime put on the chalice), dry-ups, hub trips, hard mode;
##   randomizer mazes at several MORE SLIME levels (new maze, restart, win); map-table visits; skin / hat
##   screen visits (with the hat page); level select / upgrades / settings visits.
## Throwaway save, in-memory state (Progress.enable_story_complete + coins for upgrades).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 3000000 -s res://tests/qa_soak.gd
##      [-- --soak-levels=300 --soak-random=100 --soak-maps=100 --soak-skins=100 --soak-every=25]
## Prints one line per `every` iterations per phase and a drift verdict (last quarter vs second quarter).

var progress: Node
var L := 300
var R := 100
var M := 100
var S := 100
var every := 25
var rng := RandomNumberGenerator.new()
var verdicts: Array[String] = []
var errors := 0


class ErrLog extends Logger:
	var count := 0
	var lines: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _e: bool, error_type: int, _b: Array) -> void:
		if error_type == 1:
			return
		count += 1
		if lines.size() < 10:
			lines.append("%s:%d %s %s" % [file, line, code, rationale])


var errlog := ErrLog.new()


func _initialize() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak-levels="): L = int(arg.get_slice("=", 1))
		elif arg.begins_with("--soak-random="): R = int(arg.get_slice("=", 1))
		elif arg.begins_with("--soak-maps="): M = int(arg.get_slice("=", 1))
		elif arg.begins_with("--soak-skins="): S = int(arg.get_slice("=", 1))
		elif arg.begins_with("--soak-every="): every = int(arg.get_slice("=", 1))
	OS.add_logger(errlog)
	rng.seed = 777
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.saving_enabled = false
	var t0 := Time.get_ticks_msec()
	await _phase_story()
	await _phase_random()
	await _phase_menu("res://scenes/maps.tscn", M, "map table")
	await _phase_menu("res://scenes/skins.tscn", S, "skins+hats")
	await _phase_menu("res://scenes/hub.tscn", 60, "hub")
	await _phase_menu("res://scenes/upgrades.tscn", 60, "upgrades")
	await _phase_menu("res://scenes/level_select.tscn", 60, "level select")
	await _phase_menu("res://scenes/controls.tscn", 60, "settings")
	print("SOAK elapsed %.1f s, engine errors %d %s" % [(Time.get_ticks_msec() - t0) / 1000.0, errlog.count, errlog.lines])
	for v in verdicts:
		print(v)
	print("RESULT: %s" % ("PASS" if errlog.count == 0 else "FAIL"))
	quit(1 if errlog.count else 0)


func _snap() -> Dictionary:
	return {
		nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		objects = int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		static_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		rss_mb = _rss_mb(),
	}


func _rss_mb() -> float:
	var out := []
	OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out)
	return float(str(out[0]).strip_edges()) / 1024.0 if out.size() > 0 else 0.0


func _report(tag: String, series: Array) -> void:
	# series: snapshots taken every `every` iterations; compare the 2nd quarter with the last quarter
	var n := series.size()
	if n < 4:
		return
	var q2: Dictionary = series[n / 4]
	var last: Dictionary = series[n - 1]
	var line := "DRIFT %-14s" % tag
	var leak := false
	for key in ["nodes", "objects", "orphans", "resources"]:
		var d: int = last[key] - q2[key]
		line += " %s %+d" % [key, d]
		if (key == "nodes" or key == "orphans") and d > 10 or (key == "objects" and d > 400) or (key == "resources" and d > 25):
			leak = true
	line += " static_mb %+.1f rss_mb %+.1f" % [last.static_mb - q2.static_mb, last.rss_mb - q2.rss_mb]
	if last.rss_mb - q2.rss_mb > 60.0:
		leak = true
	verdicts.append(line + ("   <-- DRIFT" if leak else "   (flat)"))
	print(verdicts[-1])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits for the new game scene (its _ready ran and no goo wipe is running).
func _wait_game() -> Node2D:
	for i in 600:
		await process_frame
		var s := current_scene
		if s != null and s.is_inside_tree() and s.get("slime") != null and s.get("hud") != null:
			return s
	print("  !! no game scene appeared")
	errors += 1
	return null


func _start(level: int, hard: bool) -> Node2D:
	progress.hard_mode = hard
	progress.start_story(level)
	progress.mode = progress.MODE_STORY
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	return await _wait_game()


func _phase_story() -> void:
	var series := []
	var wins := 0
	var dries := 0
	var t0 := Time.get_ticks_msec()
	for i in L:
		var level := 1 + (i % 10)
		var hard := (i / 10) % 2 == 1
		var game := await _start(level, hard)
		if game == null:
			continue
		await _frames(3)
		match i % 5:
			0, 1:  # win: put the slime on the chalice
				game.slime.position = game.goal.position
				await _frames(6)
				if game.won:
					wins += 1
			2:  # dry up
				game.slime_remaining = 0.0
				game.slime.position += Vector2(2, 0)
				await _frames(6)
				if game.finished and not game.won:
					dries += 1
			3:  # restart (reload) a few times
				for k in 3:
					game.retry("soak")
					await process_frame
					game = await _wait_game()
			4:  # quit to hub and straight back in
				get_root().get_node("Transition")  # (exists)
				change_scene_to_file("res://scenes/hub.tscn")
				await _frames(4)
		if i % every == 0:
			var s := _snap()
			series.append(s)
			print("  story #%d L%d%s nodes %d objects %d orphans %d res %d static %.1fMB rss %.0fMB" % [i, level, "H" if hard else "", s.nodes, s.objects, s.orphans, s.resources, s.static_mb, s.rss_mb])
	print("story phase: %d starts, %d wins, %d dry-ups in %.1f s" % [L, wins, dries, (Time.get_ticks_msec() - t0) / 1000.0])
	_report("story levels", series)


func _phase_random() -> void:
	var series := []
	var wins := 0
	var t0 := Time.get_ticks_msec()
	for i in R:
		progress.upgrades = {"slime": i % 8}
		progress.start_random()
		progress.hard_mode = i % 7 == 6
		change_scene_to_file("res://scenes/main.tscn")
		await process_frame
		var game := await _wait_game()
		if game == null:
			continue
		await _frames(2)
		if i % 3 == 0:
			game.retry("soak")
			await process_frame
			game = await _wait_game()
		if i % 2 == 0 and game != null:
			game.slime.position = game.goal.position
			await _frames(6)
			if game.won:
				wins += 1
		if i % every == 0:
			var s := _snap()
			series.append(s)
			print("  random #%d slime=%d nodes %d objects %d orphans %d res %d static %.1fMB rss %.0fMB" % [i, i % 8, s.nodes, s.objects, s.orphans, s.resources, s.static_mb, s.rss_mb])
	progress.hard_mode = false
	progress.upgrades = {}
	print("random phase: %d mazes, %d wins in %.1f s" % [R, wins, (Time.get_ticks_msec() - t0) / 1000.0])
	_report("randomizer", series)


func _phase_menu(path: String, count: int, tag: String) -> void:
	var series := []
	var t0 := Time.get_ticks_msec()
	var step := maxi(count / 8, 1)
	for i in count:
		change_scene_to_file(path)
		await _frames(3)
		var scene := current_scene
		if scene != null and path.ends_with("skins.tscn") and scene.has_method("_open_hats"):
			scene.call("_open_hats")
			await process_frame
		if i % step == 0:
			series.append(_snap())
	print("%s: %d visits in %.1f s" % [tag, count, (Time.get_ticks_msec() - t0) / 1000.0])
	_report(tag, series)
