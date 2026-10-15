extends "res://tests/suite_base.gd"

## The --autoplay launch end to end. A child Godot process plays the whole campaign headless at
## --speed=8 (`-- --autoplay --speed=8 --autoplay-hold=0.05 --autoplay-quit`, ~15 s) and prints a
## summary: every coin (165/165), all 10 levels cleared on normal and hard, medal tiers that follow
## from the real best times (tier_for(best, par)) and those times from real winning runs, every
## upgrade bought, no dry-ups, ends in the hub with time back at 1x, a throwaway save path with
## saving off, and the real save byte-identical. A launch without the flag runs no autoplay. Then
## in this process: the driver hands over control on F10 and when the player quits a level from the
## pause menu (keys released, time scale and tick rate restored).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_autoplay.gd

const REAL_SAVE := "user://save.cfg"
const PROGRESS := preload("res://scripts/progress.gd")



func _initialize() -> void:
	var real := ProjectSettings.globalize_path(REAL_SAVE)
	var real_exists := FileAccess.file_exists(real)
	var real_md5 := FileAccess.get_md5(real) if real_exists else ""
	var real_mtime := FileAccess.get_modified_time(real) if real_exists else 0

	# --- The whole campaign in a child process.
	var started := Time.get_ticks_msec()
	var output := _run_game(["--autoplay", "--speed=8", "--autoplay-hold=0.05", "--autoplay-quit"], 120000)  # the full campaign takes ~15k frames; a stuck bot is cut off at 120k
	var summary := {}
	for line in output.split("\n"):
		if line.begins_with("AUTOPLAY SUMMARY "):
			summary = JSON.parse_string(line.trim_prefix("AUTOPLAY SUMMARY "))
		elif line.begins_with("AUTOPLAY: ") and ("COMPLETE" in line or "NOTE" in line or "DRIED" in line):
			print("  | " + line)
	print("  (the campaign took %.1f s of real time)" % ((Time.get_ticks_msec() - started) / 1000.0))
	_check(not summary.is_empty(), "the autoplay finished and printed its summary")
	if summary.is_empty():
		print(output.right(3000))
		_finish()
		return
	_check(int(summary.coins) == Levels.total_coins(), "every coin found: %d/%d" % [summary.coins, Levels.total_coins()])
	_check(int(summary.levels_cleared) == Levels.COUNT, "all %d levels cleared on normal" % Levels.COUNT)
	var hard_cleared: Array = summary.hard_cleared
	_check(hard_cleared.size() == Levels.COUNT, "all %d levels cleared on hard (%s)" % [Levels.COUNT, str(hard_cleared)])
	var upgrades: Dictionary = summary.upgrades
	_check(int(upgrades.get("slime", 0)) == Upgrades.max_level("slime") and int(upgrades.get("speed", 0)) == Upgrades.max_level("speed") and int(upgrades.get("brightness", 0)) == Upgrades.max_level("brightness"),
		"every upgrade bought to the top with the coins (%s)" % str(upgrades))
	_check(int(summary.dry_ups) == 0 and (summary.notes as Array).is_empty(),
		"no dry-ups and no goals missed (%d, %s)" % [summary.dry_ups, str(summary.notes)])

	# Medals: each saved tier is what its saved best time earns against the level's par, and each
	# best time is the fastest real winning run the bot played there.
	var legit := true
	var why := ""
	for hard in [false, true]:
		for level in range(1, Levels.COUNT + 1):
			var key := level + (100 if hard else 0)
			var best: float = summary.best_times.get(str(key), -1.0)
			var tier := int(summary.medals.get(str(key), 0))
			var fastest := INF
			for run: Dictionary in summary.runs:
				if run.won and int(run.level) == level and (run.mode == "hard") == hard:
					fastest = minf(fastest, float(run.time))
			if tier != PROGRESS.tier_for(best, Levels.level_par(level, hard)) or absf(best - fastest) > 0.001:
				legit = false
				why += " %s L%d (tier %d, best %.2f, fastest run %.2f, par %.2f)" % ["hard" if hard else "normal",
					level, tier, best, fastest, Levels.level_par(level, hard)]
	_check(legit, "medal tiers follow from real run times vs par" + why)
	# Trail maps: the real runs recorded a survey of all 20 levels, each with its best clear's route.
	var maps: Dictionary = summary.get("maps", {})
	var maps_ok := maps.size() == 2 * Levels.COUNT
	for key: String in maps:
		var best: float = summary.best_times.get(key, -1.0)
		maps_ok = maps_ok and maps[key].clear and int(maps[key].moves) > 0 and absi(int(maps[key].best_ms) - roundi(best * 1000.0)) <= 1
	_check(maps_ok, "the runs recorded trail map surveys of all 20 levels, routes = the best clears (%d)" % maps.size())
	_check(int(summary.medals_normal) == 30 and int(summary.medals_hard) == 30,
		"medals: %d/30 normal, %d/30 hard (all gold)" % [summary.medals_normal, summary.medals_hard])
	var coin_runs := 0
	for run: Dictionary in summary.runs:
		coin_runs += 1 if run.kind == "coins" else 0
	print("  (%d runs, %d of them coin runs; game time %.0f s; %d frames = %.1f min at 60 fps and 8x)"
		% [(summary.runs as Array).size(), coin_runs, summary.game_time, summary.frames, summary.frames / 3600.0])
	_check(summary.scene == "res://scenes/hub.tscn" and float(summary.time_scale) == 1.0 and int(summary.ticks) == 60,
		"ends in the hub with time back at 1x and 60 ticks/s (%s, %.1f, %d)" % [summary.scene, summary.time_scale, summary.ticks])
	_check(int(summary.story_seen) == 3, "intro and finale count as seen (skipped)")
	_check(not bool(summary.saving) and String(summary.save_path).begins_with(PROGRESS.THROWAWAY_PREFIX),
		"played in memory: saving off, throwaway path %s" % summary.save_path)

	# --- Without the flag nothing autoplays.
	var plain := _run_game([], 90)
	_check(not "AUTOPLAY" in plain, "a launch without --autoplay runs no autoplay")

	if real_exists:
		_check(FileAccess.get_md5(real) == real_md5 and FileAccess.get_modified_time(real) == real_mtime,
			"the real save is byte-identical and untouched")
	else:
		_check(not FileAccess.file_exists(real), "no real save was created")

	await _stop_checks()
	_finish()


## In this process: start the driver on a fresh level 1 and take over with F10, then again by
## quitting the level from the pause menu.
func _stop_checks() -> void:
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false
	for route in ["F10", "PAUSE MENU"]:
		progress.levels_cleared = 0
		progress.highest_unlocked = 1
		progress.coins_found = {}
		progress.upgrades = {}
		progress.start_story(1)
		var before := current_scene
		change_scene_to_file(UIKit.GAME_SCENE)
		for i in 60:
			await process_frame
			if current_scene != before and current_scene != null:
				break
		var driver: Node = load("res://scripts/autoplay/autoplay.gd").new()
		driver.hold_scale = 0.05
		root.add_child(driver)
		var moving := false
		for i in 600:
			await process_frame
			var game := current_scene
			if game and game.has_node("AutoplayPilot") and game.slime.velocity.length() > 20.0:
				moving = true
				break
		_check(moving and Engine.time_scale == Autoplay.DEFAULT_SPEED and Engine.physics_ticks_per_second == 180,
			"%s: the driver plays level 1 at %.0fx (%d ticks/s)" % [route, Engine.time_scale, Engine.physics_ticks_per_second])
		if route == "F10":
			var key := InputEventKey.new()
			key.keycode = KEY_F10
			key.physical_keycode = KEY_F10
			key.pressed = true
			Input.parse_input_event(key)
		else:
			var esc := InputEventAction.new()
			esc.action = "menu"
			esc.pressed = true
			Input.parse_input_event(esc)
			await _frames(5)
			_check(paused and current_scene.pause_menu.visible, "the pause menu opened over the autoplay")
			current_scene.pause_menu._quit()  # QUIT TO HUB
		for i in 600:
			await process_frame
			if not is_instance_valid(driver) and current_scene and (route == "F10" or current_scene.scene_file_path == UIKit.HUB_SCENE):
				break
		var held := Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") \
			or Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")
		_check(not is_instance_valid(driver) and not held and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60,
			"%s: the autoplay stops and hands over (no keys held, 1x, 60 ticks/s)" % route)
		if route == "F10":
			var game := current_scene
			_check(game.scene_file_path == UIKit.GAME_SCENE and not game.has_node("AutoplayPilot") and not game.finished,
				"F10: the player is left in the level, still running")


## Runs the game (title scene) headless in a child process with `user_args` after `--`.
func _run_game(user_args: Array, frames: int) -> String:
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--headless",
		"--fixed-fps", "60", "--quit-after", str(frames), "--"])
	args.append_array(PackedStringArray(user_args))
	var out := []
	OS.execute(OS.get_executable_path(), args, out, true)
	return "\n".join(out)


func _finish() -> void:
	_result()
	quit(1 if failures else 0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


