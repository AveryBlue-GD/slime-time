extends SceneTree

## Smoke run of an EXPORTED demo pack (docs/demo-plan.md section 8; tools/build_demo.* run it).
## It runs with the editor binary against the exported pack, from outside it (tools/ is not exported):
##   godot --headless --fixed-fps 60 --quit-after 200000 --main-pack build/demo/windows/DryTryingDemo.exe \
##     -s C:/path/to/slime-time/tools/demo_smoke.gd -- --save-path=C:/path/to/build/demo/reports/demo_smoke_selftest.cfg
## The web pack: add `--platform=web` (a debug binary then answers Platform.is_web() true, so the web knobs
## and the web cut list apply) and `--expect=web` (the smoke fails unless it really runs as the web demo).
## The editor binary is a debug build, so `--save-path=` is honored: an absolute path outside the game's
## user folder, so not even a crashed run leaves a file next to the player's save. The run reads and writes
## only that throwaway file (deleted at the end; the build scripts delete it again), never the player's
## save.cfg (checked before anything else: the file must be named SAVE_NAME and not be the real save).
## Checks, all in the real stripped pack: the `demo` feature is baked in; the platform's knobs (levels,
## randomizer, hat wheel); every Demo.export_cut() path of the platform is absent; levels 1..Demo.levels()
## are played to the chalice by the route pilot, the last one leads to the end screen; the first demo maze
## is played to its ticket (or the randomizer stays shut where it is left out); every menu scene opens; a
## full-game level asked for anyway falls back. Prints `RESULT: PASS` / `RESULT: FAIL`; the build script
## also fails on any ERROR line in the log (a missing resource, a script error).

const MAIN := "res://scenes/main.tscn"
const SCREENS: Array[String] = [
	"res://scenes/title.tscn", "res://scenes/hub.tscn", "res://scenes/level_select.tscn",
	"res://scenes/skins.tscn", "res://scenes/maps.tscn", "res://scenes/upgrades.tscn",
	"res://scenes/controls.tscn", "res://scenes/key_controls.tscn", "res://scenes/demo_end.tscn",
]
const SAVE_NAME := "demo_smoke_selftest.cfg"

var failures := 0
var progress: Node


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	# Save safety first: this must be the throwaway file, never the real save.
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH).simplify_path()
	var save := ProjectSettings.globalize_path(progress.save_path).simplify_path()
	if save == real or save.get_file() != SAVE_NAME:
		print("  FAIL save path is %s (expected a file named %s): stopping before anything is written" % [progress.save_path, SAVE_NAME])
		print("RESULT: FAIL")
		quit(1)
		return
	var expect := "desktop"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expect="):
			expect = arg.trim_prefix("--expect=")
	var web := expect == "web"
	print("demo smoke: %s, %s demo, save %s" % [ProjectSettings.get_setting("application/config/name"), expect, progress.save_path])
	progress.reset_progress()
	_check(OS.has_feature("demo") and Platform.is_demo() and Platform.demo_override == -1,
		"the pack has the `demo` feature (Platform.is_demo from the export, not a flag)")
	_check(Platform.is_web() == web, "runs as the %s demo (Platform.is_web %s)" % [expect, Platform.is_web()])
	_check(Demo.levels() == (Demo.WEB_LEVELS if web else Demo.LEVELS) and Demo.levels() < Levels.COUNT,
		"Demo.levels() = %d of %d (the %s knob)" % [Demo.levels(), Levels.COUNT, expect])
	_check(Demo.randomizer_open() == (Demo.WEB_RANDOMIZER if web else Demo.RANDOMIZER), "randomizer open: %s (the %s knob)" % [Demo.randomizer_open(), expect])
	_check(Demo.hat_wheel_open() == (Demo.WEB_HAT_WHEEL if web else Demo.HAT_WHEEL), "hat wheel open: %s (the %s knob)" % [Demo.hat_wheel_open(), expect])
	_check_cut()
	await _play_story()
	await _play_first_maze()
	await _open_screens()
	await _forced_full_level()
	progress.saving_enabled = false
	DirAccess.remove_absolute(save)
	DirAccess.remove_absolute(save + progress.TEMP_SUFFIX)
	print("RESULT: " + ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check_cut() -> void:
	var cut := Demo.export_cut(Platform.is_web())
	var present: Array[String] = []
	for path in cut:
		if path.ends_with(".import"):
			continue
		if ResourceLoader.exists(path) or FileAccess.file_exists(path) or FileAccess.file_exists(path + ".remap"):
			present.append(path)
	_check(present.is_empty(), "none of the %d cut paths is in the pack (%s)" % [cut.size(), present])
	_check(not Levels.has_data(Demo.levels() + 1) and Levels.has_data(Demo.levels()), "Levels.has_data: only the demo's levels")
	_check(not Levels.has_data(Demo.hard_levels() + 1, true) and Levels.has_data(Demo.hard_levels(), true), "...and the demo's hard levels")
	_check(Story.level_line(Demo.levels() + 1) == "" and Story.level_line(1) != "", "no banner line past the demo")
	for id in Demo.themes():
		_check(ResourceLoader.exists(Themes.atlas_path(id, "walls")), "theme art kept: %s" % id)


func _play_story() -> void:
	progress.story_seen = progress.STORY_INTRO
	for level in range(1, Demo.levels() + 1):
		progress.start_story(level)
		var game: Node2D = load(MAIN).instantiate()
		game.level = level
		root.add_child(game)
		current_scene = game
		await physics_frame
		game.add_child(RoutePilot.new())
		for i in 150 * 60:
			await physics_frame
			if game.finished:
				break
		_check(game.won, "level %d (%s): the pilot reaches the chalice" % [level, game.theme])
		for i in int(game.CHOICE_DELAY * 60) + 10:
			await physics_frame
		if level < Demo.levels():
			current_scene = null
			game.free()
			continue
		game.play_next()
		var opened := false
		for i in 240:
			await process_frame
			if current_scene != null and current_scene.scene_file_path == DemoEnd.SCENE:
				opened = true
				break
		_check(opened, "...level %d's CONTINUE opens the demo end screen" % level)
		if current_scene:
			current_scene.free()
		current_scene = null


func _play_first_maze() -> void:
	if not Demo.randomizer_open():
		_check(not progress.is_randomizer_unlocked(), "the randomizer stays shut after the last demo level (left out here)")
		return
	_check(progress.is_randomizer_unlocked(), "the randomizer is open after the last demo level")
	progress.start_random()
	var maze: Node2D = load(MAIN).instantiate()
	root.add_child(maze)
	current_scene = maze
	await physics_frame
	_check(maze.is_random() and maze.theme in Demo.themes(), "demo maze %d in a demo theme (%s)" % [progress.random_seed, maze.theme])
	# Every maze is a new random seed: whatever theme one draws must be in this pack.
	var pool := {}
	for s in range(1, 400):
		pool[Themes.for_seed(s)] = true
	var packed := true
	for id: String in pool:
		packed = packed and id in Demo.themes() and ResourceLoader.exists(Themes.atlas_path(id, "walls"))
	_check(packed and pool.size() == Demo.themes().size(), "random mazes draw only packed demo themes (%s)" % [pool.keys()])
	maze.add_child(RoutePilot.new())
	for i in 150 * 60:
		await physics_frame
		if maze.finished:
			break
	_check(maze.won, "...the pilot reaches its ticket")
	current_scene = null
	maze.free()


func _open_screens() -> void:
	for path in SCREENS:
		var screen: Node = load(path).instantiate()
		root.add_child(screen)
		current_scene = screen
		for i in 5:
			await process_frame
		_check(is_instance_valid(screen), "opens: %s" % path.get_file())
		current_scene = null
		if is_instance_valid(screen):
			screen.free()


func _forced_full_level() -> void:
	var level := Demo.levels() + 1
	progress.current_level = level
	var game: Node2D = load(MAIN).instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	_check(game.level == Demo.levels(), "a full-game level (%d) falls back to the demo's last level" % level)
	game.free()
