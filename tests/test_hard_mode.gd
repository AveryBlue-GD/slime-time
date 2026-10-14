extends SceneTree

## Hard mode + one-time skin notice checks: hard mode has its own mazes, a 75-92% budget, no
## upgrades, no coins and its own records; explored areas that have fully dimmed turn back into
## unexplored fog (and relight when you return); the level select checkbox toggles and saves it;
## a new level's skin is equipped (with a notice) only the first time it loads.
## Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_hard_mode.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.levels_cleared = 0
	progress.selected_skin = Skins.DEFAULT
	progress.skin_notices_seen.clear()
	progress.hard_mode = false

	# --- A new level's skin is equipped (with a notice) once, not on every restart.
	progress.levels_cleared = 1
	progress.selected_skin = Skins.DEFAULT
	var game := await _spawn(2)
	_check(game.hud.message.visible and "EQUIPPED" in game.hud.message.text, "first load of a new level equips its skin, with a notice")
	game.free()
	game = await _spawn(2)
	_check(not game.hud.message.visible, "restarting the level doesn't show it again")
	game.free()
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(2 in reloaded.skin_notices_seen, "seen notices are saved")
	reloaded.free()
	progress.levels_cleared = 0

	# --- Hard mode: its own mazes, a tight budget, no upgrades, no coins, its own records.
	var normal := await _spawn(4)
	var normal_walls: PackedByteArray = normal.maze.walls
	normal.free()
	progress.set_hard_mode(true)
	progress.upgrades = {"slime": 7, "speed": 4, "brightness": 3}
	var hard := await _spawn(4)
	_check(hard.maze.walls != normal_walls, "hard mode plays a different maze")
	_check(hard.perfect_usage >= 0.75 and hard.perfect_usage <= 0.92, "the hard maze is budgeted tight: a perfect run needs %.0f%% of the slime" % (hard.perfect_usage * 100.0))
	_check(is_equal_approx(hard.slime_cost_per_tile, 100.0 / Levels.hard_meter_tiles(4))
		and hard.light_reach == 0.0 and absf(hard.slime.max_speed - 72.0) < 0.01,
		"upgrades are switched off in hard mode (the meter is exactly Levels.hard_meter_tiles)")
	_check(hard.coins.is_empty() and not hard.hud._coins_left_pod.visible, "no coins in hard mode")
	hard.free()
	progress.upgrades = {}
	progress.best_times = {}
	progress.record_time(4, 30.0)
	progress.set_hard_mode(false)
	_check(progress.best_time(4) < 0.0, "hard-mode records are kept apart from normal ones")
	progress.set_hard_mode(true)
	_check(progress.best_time(4) == 30.0, "...and come back on hard mode")
	progress.set_hard_mode(false)

	# --- Hard mode: fully dimmed areas are swallowed by fog again.
	progress.set_hard_mode(true)
	game = await _spawn()
	_check("HARD" in game.hud.level_label.text, "the HUD shows HARD next to the level")
	_check((game.fog_sprite.material as ShaderMaterial).get_shader_parameter("hard_mode") == true, "the fog shader is in hard mode")
	var start: Vector2 = game.slime.position
	var path := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	var far := MazeGenerator.cell_center(path[path.size() / 2], 16)
	game.slime.position = far
	game.last_slime_pos = far
	await _wait(4.0)
	var mid: float = game.fog_alpha_at(start)
	await _wait(6.0)
	var late: float = game.fog_alpha_at(start)
	_check(mid > 0.0 and mid < 1.0, "it dims in steps like normal at first (%.2f after 4 s)" % mid)
	_check(late == 1.0, "once fully dimmed, the fog takes it back completely (%.2f after 10 s)" % late)
	game.slime.position = start
	game.last_slime_pos = start
	await _wait(0.1)
	_check(game.fog_alpha_at(start) == 0.0, "coming back clears it again")
	game.free()

	progress.set_hard_mode(false)
	game = await _spawn()
	start = game.slime.position  # normal level 1 has its own maze and start
	path = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	far = MazeGenerator.cell_center(path[path.size() / 2], 16)
	game.slime.position = far
	game.last_slime_pos = far
	await _wait(10.0)
	_check(game.fog_alpha_at(start) < 1.0, "normal mode keeps the faint memory of the path")
	game.free()

	# --- Level select checkbox
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(not screen.hard_mode_box.button_pressed, "level select shows hard mode off")
	screen.hard_mode_box.button_pressed = true
	_check(progress.hard_mode, "ticking the box turns hard mode on")
	reloaded = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.hard_mode, "hard mode is saved")
	reloaded.free()
	screen.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _spawn(level := 1) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	return game


func _wait(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
