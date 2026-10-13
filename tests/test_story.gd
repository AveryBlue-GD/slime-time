extends SceneTree

## The story: the intro shows only on a fresh save (any key advances, Esc skips, seen is saved and
## reset by RESET PROGRESS), old saves count as seen, every line fits the 320 px screen in the
## pixel font, level banners carry their line, and starting a level directly is never blocked.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_story.gd

const MAIN := preload("res://scenes/main.tscn")
var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = true
	progress.save_path = "user://test_save_story.cfg"
	progress.dev_tools = false

	# --- Text: ten level lines, everything uppercase and narrow enough
	_check(Story.LEVEL_LINES.size() == Levels.COUNT, "a story line for each of the %d levels" % Levels.COUNT)
	_check(Story.widest_line() <= Story.MAX_WIDTH and Story.MAX_WIDTH < 320.0, "every line fits 320 px (widest %d px)" % int(Story.widest_line()))
	var upper := true
	for line in Story.LEVEL_LINES:
		upper = upper and line == line.to_upper()
	_check(upper and Story.level_line(0) == "" and Story.level_line(11) == "", "lines are uppercase; no line outside levels 1-10")

	# --- Fresh save: due; seen flag persists; old saves are seen; RESET clears
	progress.reset_progress()
	_check(not progress.has_seen_story(progress.STORY_INTRO) and Story.intro_due(progress), "fresh save: the intro is due")
	progress.dev_tools = true
	_check(not Story.intro_due(progress), "dev mode: never due")
	progress.dev_tools = false
	var screen := await _open("intro")
	_check(screen.cards.size() >= 3 and screen.cards.size() <= 5, "intro has 3-5 cards (%d)" % screen.cards.size())
	await _frames(20)
	screen._unhandled_input(_key(KEY_SPACE))
	_check(screen.index == 1, "any key goes to the next card")
	screen._unhandled_input(_key(KEY_SPACE))  # too soon after the last one: ignored
	_check(screen.index == 1, "...but not within the grace period")
	await _frames(20)
	screen._unhandled_input(_key(KEY_ESCAPE))
	_check(screen.finished and progress.has_seen_story(progress.STORY_INTRO), "Esc skips the whole intro and marks it seen")
	screen.free()
	_check(not Story.intro_due(progress), "...so it isn't due again")
	progress.story_seen = 0
	screen = await _open("intro")
	for i in screen.cards.size():
		await _frames(20)
		screen._unhandled_input(_key(KEY_A))
	_check(screen.finished and progress.has_seen_story(progress.STORY_INTRO), "clicking through every card finishes it")
	screen.free()
	progress.save_progress()
	progress.story_seen = 0
	progress.load_progress()
	_check(progress.has_seen_story(progress.STORY_INTRO), "the seen flag persists through a save/load")
	var file := ConfigFile.new()
	file.set_value("progress", "levels_cleared", 4)
	progress._read(file)
	_check(progress.has_seen_story(progress.STORY_INTRO) and not progress.has_seen_story(progress.STORY_FINALE), "an old save without the key counts as past the intro")
	file.set_value("progress", "levels_cleared", Levels.COUNT)
	progress._read(file)
	_check(progress.has_seen_story(progress.STORY_FINALE), "...and a beaten old save as past the finale")
	var fresh := ConfigFile.new()
	fresh.set_value("progress", "levels_cleared", 0)
	progress._read(fresh)
	_check(Story.intro_due(progress), "an old save with no progress still gets the intro")
	progress.reset_progress()
	_check(progress.story_seen == 0, "RESET PROGRESS clears the flag")

	# --- Reduce Motion: cards still show, as stills
	progress.reduce_motion = true
	screen = await _open("finale")
	_check(screen.calm and screen.cards.size() == Story.FINALE.size() and screen.slime != null, "Reduce Motion: finale shows stills")
	screen.free()
	progress.reduce_motion = false

	# --- Starting levels directly: no intro, the banner carries the story line
	progress.story_seen = 0
	progress.levels_cleared = 2
	progress.hard_mode = false
	for level in [1, 3, 10]:
		var game: Node2D = MAIN.instantiate()
		game.level = level
		root.add_child(game)
		await _frames(3)
		_check(game.hud.story_label.visible and game.hud.story_label.text == Story.level_line(level) and game.hud.area_label.visible,
			"level %d's banner shows its story line (%s)" % [level, game.hud.story_label.text])
		game.free()
	var maze: Node2D = MAIN.instantiate()
	maze.random_seed = 777
	root.add_child(maze)
	await _frames(3)
	_check(not maze.hud.story_label.visible, "randomizer mazes have no story line")
	maze.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_story.cfg"))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _open(which: String) -> Control:
	Story.mode = which
	Story.next_scene = ""
	var screen: Control = load("res://scenes/story.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	return screen


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["ok" if ok else "FAIL", what])
