extends SceneTree

## Hard mode + one-time skin notice checks: in hard mode, explored areas that have fully dimmed
## turn back into unexplored fog (and relight when you return); the level select checkbox toggles
## and saves it; the "first run: playing as ..." notice shows only the first time a level loads.
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

	# --- The forced-skin notice shows once per level, not on every restart.
	var game := await _spawn()
	_check(game.hud.message.visible and "PLAYING AS" in game.hud.message.text, "first load of a new level shows the forced-skin notice")
	game.free()
	game = await _spawn()
	_check(not game.hud.message.visible, "restarting the level doesn't show it again")
	_check(game.skin_color == Skins.get_preset(Skins.DEFAULT).color, "...but the forced skin still applies")
	game.free()
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(1 in reloaded.skin_notices_seen, "seen notices are saved")
	reloaded.free()

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


func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
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
