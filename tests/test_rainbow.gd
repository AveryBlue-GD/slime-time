extends SceneTree

## Rainbow skin + randomizer shuffle checks: the rainbow unlocks by finding every coin (its solid
## version by beating it on hard mode), drying up in the randomizer shuffles to a new maze, and
## the rainbow skin colors the slime, trail and meter. Uses a throwaway save file.
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

	# --- Unlocking: the rainbow comes with finding every coin in the story; its solid version
	# (like the custom color's) with level 10 beaten on hard mode.
	progress.hard_cleared.clear()
	progress.coins_found = {}
	progress.dev_tools = false
	progress.set_hard_mode(false)
	progress.select_skin(Skins.RAINBOW)
	_check(progress.selected_skin == Skins.DEFAULT, "rainbow is locked at first")
	progress.levels_cleared = Levels.COUNT - 1
	var game := await _spawn_story_running(Levels.COUNT)
	game.slime.position = game.goal.position
	await _frames(5)
	_check(progress.is_skin_unlocked(Skins.CUSTOM) and not progress.is_skin_unlocked(Skins.RAINBOW),
		"beating level 10 unlocks the color wheel, not the rainbow")
	await _stop_running(game)
	game = await _spawn_story_running(3)
	var last: Coin = game.coins[0]
	for level in range(1, Levels.COUNT + 1):  # every other coin already found
		progress.coins_found[level] = []
		for i in Levels.COINS[level - 1]:
			progress.coins_found[level].append("found%d" % i)
	progress.coins_found[3].pop_back()
	_check(not progress.is_skin_unlocked(Skins.RAINBOW), "one coin short: still locked")
	game.slime.position = last.position
	await _frames(3)
	_check(progress.is_skin_unlocked(Skins.RAINBOW), "the very last coin unlocks the rainbow skin")
	_check("RAINBOW" in game.hud.message.text, "...and says so (%s)" % game.hud.message.text.replace("\n", " / "))
	_check(not progress.is_skin_unlocked(Skins.RAINBOW, false), "its solid version still needs level 10 on hard mode")
	progress.hard_cleared.assign([Levels.COUNT])
	_check(progress.is_skin_unlocked(Skins.RAINBOW, false) and progress.is_skin_unlocked(Skins.CUSTOM, false),
		"...which unlocks it, like the solid color wheel")
	progress.hard_cleared.clear()
	await _stop_running(game)

	# --- Drying up in the randomizer retries the same maze.
	game = await _spawn_running(777)
	game.slime_remaining = 0.2
	var open_dir: Vector2i = MazeGenerator.open_neighbors(game.maze, game.maze.start)[0] - game.maze.start  # (the start is random)
	var action: String = {Vector2i.RIGHT: "move_right", Vector2i.LEFT: "move_left", Vector2i.DOWN: "move_down", Vector2i.UP: "move_up"}[open_dir]
	Input.action_press(action)
	await _frames(30)
	Input.action_release(action)
	_check(game.finished and progress.random_seed == 777, "drying up in the randomizer keeps the same maze")
	_check("SHUFFLE" not in game.hud.message.text, "the dry-up message no longer promises a shuffle")
	_check(progress.randoms_won == 0, "a dry-up doesn't count as a win")
	await _stop_running(game)

	# --- Rainbow look
	progress.levels_cleared = Levels.COUNT  # the rainbow comes with level 10; no first-run skin either
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
	_check(screen.tiles.has(Skins.RAINBOW) and screen.tiles.size() == 13, "skins screen has a rainbow tile")
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


## A story level set as the current scene, so its real end-of-level flow runs.
func _spawn_story_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
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
