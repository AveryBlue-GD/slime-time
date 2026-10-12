extends SceneTree

## Seed codes for randomizer mazes: the pause menu shows a maze's seed (not in story levels), a
## seed typed in rebuilds exactly that maze (the same one for anyone), bad input is ignored, and the
## win text names the seed. Throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_seed.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.saving_enabled = false
	progress.hard_mode = false
	progress.dev_tools = false

	var pause_script: GDScript = load("res://scripts/ui/pause_menu.gd")
	_check(pause_script.parse_seed("12345") == 12345 and pause_script.parse_seed(" 7 ") == 7 and pause_script.parse_seed("2000000000") == 2000000000,
		"seeds are plain numbers (spaces ignored)")
	_check(pause_script.parse_seed("") == 0 and pause_script.parse_seed("abc") == 0 and pause_script.parse_seed("0") == 0 and pause_script.parse_seed("-4") == 0
		and pause_script.parse_seed("2000000001") == 0 and pause_script.parse_seed("1.5") == 0, "empty, letters, zero, negative and too-big seeds are refused")

	# --- A story level shows no seed
	progress.mode = progress.MODE_STORY
	progress.current_level = 1
	var story: Node2D = MAIN.instantiate()
	story.level = 1
	root.add_child(story)
	await physics_frame
	story.pause_menu.open()
	_check(not story.pause_menu.seed_button.visible and story.pause_menu.buttons.size() == 4, "story levels: the pause menu has no seed")
	story.pause_menu.resume()
	story.free()

	# --- A random maze shows its seed; typing another rebuilds that maze
	progress.start_random()
	progress.random_seed = 424242
	var game: Node2D = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	var walls_a: Dictionary = game.maze.duplicate(true)
	game.pause_menu.open()
	_check(game.pause_menu.seed_button.visible and game.pause_menu.seed_button.text == "SEED 424242", "a random maze's pause menu shows SEED 424242")
	game.pause_menu._edit_seed()
	_check(game.pause_menu.seed_edit.visible and game.pause_menu.seed_edit.text == "424242", "pressing it opens the box with the seed in it (to copy or type over)")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = game.pause_menu.seed_edit.get_global_rect().get_center()
	game.pause_menu._input(tap)
	_check(game.pause_menu.seed_edit.visible, "tapping inside the box keeps it open")
	tap.position = Vector2(2, 2)
	game.pause_menu._input(tap)
	_check(not game.pause_menu.seed_edit.visible and game.pause_menu.seed_button.visible and paused and progress.random_seed == 424242,
		"tapping outside the box closes it without changing the seed")
	game.pause_menu._edit_seed()
	game.pause_menu._submit_seed("nonsense")
	_check(not game.pause_menu.seed_edit.visible and paused and progress.random_seed == 424242, "a bad entry just closes the box")
	game.pause_menu._edit_seed()
	game.pause_menu._submit_seed("9001")
	await _frames(4)
	var next: Node2D = current_scene
	_check(next != game and next.is_random() and next.random_seed == 9001 and progress.random_seed == 9001 and not paused, "typing 9001 reloads the randomizer on seed 9001")
	var again := MAIN.instantiate()
	progress.random_seed = 9001
	root.add_child(again)
	await physics_frame
	_check(_same_maze(next.maze, again.maze), "the same seed builds the same maze")
	var other := MAIN.instantiate()
	progress.random_seed = 424242
	root.add_child(other)
	await physics_frame
	_check(_same_maze(other.maze, walls_a) and not _same_maze(other.maze, again.maze), "...and the first maze comes back with its own seed")
	other.free()
	again.free()

	# --- The win text names it
	progress.random_seed = 5150
	current_scene = null
	var win: Node2D = MAIN.instantiate()
	root.add_child(win)
	current_scene = win
	await physics_frame
	win.slime.position = win.chalice.position
	await _frames(10)
	_check("SEED 5150" in win.hud.message.text, "winning a randomizer maze shows its seed (%s)" % win.hud.message.text.replace("\n", " / "))
	current_scene = null
	await _frames(150)
	win.free()
	next.free()
	progress.mode = progress.MODE_STORY
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _same_maze(a: Dictionary, b: Dictionary) -> bool:
	return a.cells == b.cells and a.start == b.start and a.goal == b.goal and a.goal_steps == b.goal_steps and str(a) == str(b)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
