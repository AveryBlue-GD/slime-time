extends SceneTree

## Level medals: PAR (finish within the par time derived from the solution path and the slime's
## base speed), CLEAN (not one wall splat) and COINS (every coin of the level, story only); each
## pays 2 globs the first time, shows under the win text and as pips on the level select, and is
## saved as a small bitmask. Runs real wins (the game as the current scene). Throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_medals.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.dev_tools = false
	progress.hard_mode = false
	progress.reset_progress()

	# --- The conditions
	var mask: int = progress.medals_earned(10.0, 12.0, 0, true)
	_check(mask == progress.MEDAL_ALL, "fast, clean and every coin: all three medals")
	_check(progress.medals_earned(12.0, 12.0, 0, false) == (progress.MEDAL_PAR | progress.MEDAL_CLEAN), "exactly par counts; coins missing")
	_check(progress.medals_earned(12.1, 12.0, 0, true) == (progress.MEDAL_CLEAN | progress.MEDAL_COINS), "a hair over par loses PAR only")
	_check(progress.medals_earned(5.0, 12.0, 1, true) == (progress.MEDAL_PAR | progress.MEDAL_COINS), "one wall splat loses CLEAN")
	progress.hard_mode = true
	_check(progress.medals_earned(5.0, 12.0, 0, true) == (progress.MEDAL_PAR | progress.MEDAL_CLEAN), "hard mode has no COINS medal")
	progress.hard_mode = false
	_check(progress.medal_count(0) == 0 and progress.medal_count(5) == 2 and progress.medal_count(7) == 3, "medal counting")

	# --- Par comes from the solution path: longer levels get more time, upgrades don't move it
	var par1 := await _par(1)
	var par10 := await _par(10)
	_check(par1 > 5.0 and par10 > par1 * 3.0, "par grows with the path: level 1 %.1f s, level 10 %.1f s" % [par1, par10])
	progress.upgrades = {"speed": 3}
	var fast_par := await _par(1)
	progress.upgrades = {}
	_check(is_equal_approx(fast_par, par1), "speed upgrades don't change the par time")

	# --- A real clean, quick win with the autopilot's perfect glide: first clear + PAR + CLEAN
	for level in [1, 10]:
		progress.reset_progress()
		var game := await _spawn_running(level)
		game.add_child(preload("res://tests/autopilot.gd").new())
		await _until_finished(game, 120.0)
		_check(game.won and game.splats == 0 and game.run_time <= game.par_time, "level %d: a perfect glide (%.1f s) beats its par (%.1f s)" % [level, game.run_time, game.par_time])
		_check(game.reward.first and game.reward.medals == (progress.MEDAL_PAR | progress.MEDAL_CLEAN) and game.reward.globs == 4 + 4,
			"...first clear + PAR + CLEAN pay 8 globs (got %d)" % game.reward.globs)
		_check(progress.globs == 8 and progress.medals_for(level) == (progress.MEDAL_PAR | progress.MEDAL_CLEAN), "...saved: %d globs, medals %d" % [progress.globs, progress.medals_for(level)])
		_check("+8" in game.hud.rewards_texts and "PAR" in game.hud.rewards_texts and game.hud.rewards_row.visible, "...and the win screen shows +8 and the medals")
		await _stop(game)

	# --- A splat costs CLEAN; the coins medal needs every coin; hard mode stays separate
	progress.reset_progress()
	var game := await _spawn_running(1)
	var spot := _dead_end(game)
	game.slime.position = MazeGenerator.cell_center(spot.cell, 16)
	game.last_slime_pos = game.slime.position
	game.slime.facing = Vector2(spot.dir)
	await physics_frame
	game.slime.launch(100.0)
	for i in 120:
		await physics_frame
		if game.splats > 0:
			break
	_check(game.splats == 1, "a leap into a wall counts one splat")
	for cell in game.coin_cells(game.config_seed() if game.has_method("config_seed") else Levels.get_config(1).seed):
		progress.collect_coin(1, cell)
	game.slime.position = game.chalice.position
	await _until_finished(game, 5.0)
	_check(game.reward.medals & progress.MEDAL_CLEAN == 0 and game.reward.medals & progress.MEDAL_COINS != 0, "splatted but every coin found: COINS yes, CLEAN no")
	_check(game.reward.globs == 4 + 2 + 2 or game.reward.globs == 4 + 2, "...paid first clear + the medals won (%d)" % game.reward.globs)
	var kept: int = progress.medals_for(1)
	await _stop(game)

	game = await _spawn_running(1)
	game.add_child(preload("res://tests/autopilot.gd").new())
	await _until_finished(game, 60.0)
	_check(game.reward.first == false and progress.medals_for(1) == progress.MEDAL_ALL and game.reward.globs == 2 * (3 - progress.medal_count(kept)),
		"a better replay adds only the missing medals (%d globs)" % game.reward.globs)
	await _stop(game)

	progress.hard_mode = true
	game = await _spawn_running(2)
	game.add_child(preload("res://tests/autopilot.gd").new())
	await _until_finished(game, 120.0)
	_check(game.reward.first and progress.medals_for(2) != 0 and progress.medal_key(2) == 102 and progress.medals.get(2, 0) == 0,
		"hard clears keep their own medals (level_102), and pay the +8")
	_check(not game.hud.rewards_texts.has("COINS"), "...the hard win screen has no COINS medal")
	await _stop(game)
	progress.hard_mode = false

	# --- Saved small, and shown on the level select
	progress.reset_progress()
	progress.medals = {1: 7, 2: 3, 102: 1}
	var file: ConfigFile = progress._write()
	_check(file.get_value("medals", "level_1") == 7 and file.get_value("medals", "level_102") == 1 and file.get_section_keys("medals").size() == 3,
		"medals are small ints under [medals] level_N (hard under N+100)")
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	progress.highest_unlocked = 3
	root.add_child(screen)
	await process_frame
	var pips := 0
	for child in screen.level_buttons[0].get_children():
		if child is ColorRect and child.color == UIKit.GOLD:
			pips += 1
	_check(pips == 3, "level 1's tile shows its 3 medals as gold pips (%d)" % pips)
	screen.free()
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _par(level: int) -> float:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	var par: float = game.par_time
	game.free()
	return par


func _spawn_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _until_finished(game: Node2D, max_seconds: float) -> void:
	for i in int(max_seconds * 60.0):
		await physics_frame
		if game.finished:
			return


## Detaches the game before its end-of-level timer fires (so it doesn't reload), then frees it.
func _stop(game: Node2D) -> void:
	current_scene = null
	for i in int(game.END_DELAY * 60) + 10:
		await physics_frame
	game.free()


func _dead_end(game: Node2D) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell):
					continue
				var back := cell
				var ok := true
				for i in 3:
					ok = ok and (back - dir) in MazeGenerator.open_neighbors(game.maze, back)
					back -= dir
				if ok:
					return {cell = cell, dir = dir}
	return {}


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
