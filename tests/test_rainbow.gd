extends SceneTree

## Rainbow skin + randomizer shuffle checks: the rainbow unlocks after 5 randomizer wins (saved),
## the 5th win announces it, drying up in the randomizer shuffles to a new maze, and the rainbow
## skin colors the slime, trail and meter. Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_rainbow.gd

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
	progress.randoms_won = 0

	# --- Unlocking
	progress.select_skin(Skins.RAINBOW)
	_check(progress.selected_skin == Skins.DEFAULT, "rainbow is locked at first")
	progress.randoms_won = 4
	_check(not progress.is_skin_unlocked(Skins.RAINBOW), "still locked after 4 random wins")

	# 5th randomizer win, played as the running scene so the real win flow runs.
	var game := await _spawn_running(12345)
	game.slime.position = game.chalice.position
	await _frames(5)
	_check(progress.randoms_won == 5, "winning a random maze counts toward the rainbow (%d/5)" % progress.randoms_won)
	_check("NEW SKIN: RAINBOW" in game.hud.message.text, "the 5th random win announces the rainbow skin")
	_check(progress.random_seed != 12345, "a win lines up a brand-new maze")
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.randoms_won == 5, "random wins are saved")
	reloaded.free()
	await _stop_running(game)

	# --- Drying up in the randomizer shuffles the maze.
	game = await _spawn_running(777)
	game.slime_remaining = 0.2
	var open_right: bool = Vector2i.RIGHT in MazeGenerator.open_neighbors(game.maze, game.maze.start)
	var action := "move_right" if open_right else "move_down"
	Input.action_press(action)
	await _frames(30)
	Input.action_release(action)
	_check(game.finished and progress.random_seed != 777, "drying up in the randomizer shuffles to a new maze")
	_check("SHUFFLING" in game.hud.message.text, "the dry-up message says the maze is shuffling")
	_check(progress.randoms_won == 5, "a dry-up doesn't count as a win")
	await _stop_running(game)

	# --- Rainbow look
	progress.levels_cleared = 1  # level 1 already cleared, so its skin isn't forced
	progress.select_skin(Skins.RAINBOW)
	_check(progress.is_rainbow(), "rainbow can be selected once unlocked")
	game = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	var material := game.slime.sprite.material as ShaderMaterial
	_check(material.get_shader_parameter("rainbow") == true, "the slime uses the flowing rainbow shader")
	var first: Color = game._goo_color(false)
	var meter_first: Color = game.hud.fill.color
	await _frames(120)
	var later: Color = game._goo_color(false)
	_check(absf(first.h - later.h) > 0.05, "the trail color moves through the rainbow (hue %.2f -> %.2f)" % [first.h, later.h])
	_check(game.hud.fill.color != meter_first, "the slime meter cycles through the rainbow")
	game.free()

	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.tiles.has(Skins.RAINBOW) and screen.tiles.size() == 12, "skins screen has a rainbow tile")
	screen.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## A randomizer game set as the current scene, so its real end-of-maze flow runs.
func _spawn_running(seed_value: int) -> Node2D:
	progress.start_random()
	progress.random_seed = seed_value
	var game: Node2D = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


## Detaches the game before its end-of-maze timer fires (so it doesn't reload), then frees it.
func _stop_running(game: Node2D) -> void:
	current_scene = null
	await _frames(int(game.END_DELAY * 60) + 10)
	game.free()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
