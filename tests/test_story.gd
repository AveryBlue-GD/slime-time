extends SceneTree

## The story: the intro shows only on a fresh save (any key advances, Esc skips, seen is saved and
## reset by RESET PROGRESS), old saves count as seen, every level banner line fits the 320 px
## screen in the pixel font, the story itself is wordless (no text drawn by any shot, no labels on
## the screen), the animated shots play through by themselves in time (drawing every shot), Reduce
## Motion holds stills with no shake or zoom, level banners carry their line, and starting a level
## directly is never blocked.
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
	_check(Story.widest_line() <= Story.MAX_WIDTH and Story.MAX_WIDTH < 320.0, "every level line fits 320 px (widest %d px)" % int(Story.widest_line()))

	# --- Wordless: the cinematics carry no text at all, only pictures
	var no_words := true
	for card in Story.INTRO + Story.FINALE:
		for key in ["lines", "title", "subtitle", "text"]:
			no_words = no_words and not card.has(key)
	_check(no_words, "no intro / finale shot has lines, a title or a subtitle")
	var source := FileAccess.get_file_as_string("res://scripts/ui/story_screen.gd")
	var text_calls := []
	for call in ["draw_string", "draw_char", "draw_multiline_string", "draw_string_outline", "Font", ".fnt", "Label", "make_label", "RichText"]:
		if source.contains(call):
			text_calls.append(call)
	_check(source.length() > 1000 and text_calls.is_empty(), "the story screen's drawing makes no text calls and loads no font (%s)" % ", ".join(text_calls))
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
	_check(Story.length("intro") >= 18.0 and Story.length("intro") <= 25.0, "the intro plays in 18-25 s (%.1f s)" % Story.length("intro"))
	var stills_ok := true
	for card in Story.INTRO + Story.FINALE:
		stills_ok = stills_ok and card.has("time") and card.has("still") and card.still < card.time
	_check(stills_ok, "every shot has a play time and a Reduce Motion still inside it")
	await _frames(20)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	screen._unhandled_input(wheel)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	screen._unhandled_input(wheel)
	_check(screen.index == 0, "mouse wheel / trackpad scrolling doesn't advance the story")
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

	# --- Launch trailer: the boot title hands a fresh save to the intro, which wipes back into the title
	progress.reset_progress()
	Story.launched = false
	await _frames(60)  # let the wipes the checks above started land (they change scenes)
	if current_scene:
		current_scene.free()
		current_scene = null
	var packed: PackedScene = load("res://scenes/title.tscn")
	Story.launched = false
	var boot: Control = packed.instantiate()
	root.add_child(boot)  # not the current scene: a test instancing the title is never hijacked
	await _frames(2)
	_check(boot.enter_button != null and current_scene != boot and not Story.launched, "a title that isn't the booted scene doesn't start the trailer or use up the launch")
	boot.free()
	progress.dev_tools = true
	change_scene_to_packed(packed)  # like the real boot: the title is the current scene before it is ready
	await _frames(3)
	_check(current_scene != null and current_scene.scene_file_path == UIKit.TITLE_SCENE and Story.launched, "dev mode: the booted title just builds (never the trailer)")
	progress.dev_tools = false
	current_scene.free()
	current_scene = null
	Story.launched = false
	change_scene_to_packed(packed)
	await _frames(5)
	_check(current_scene != null and current_scene.scene_file_path == Story.SCENE and Story.launched, "booting a fresh save opens the intro first")
	var trailer := current_scene
	await _frames(20)
	trailer._unhandled_input(_key(KEY_ESCAPE))
	await _frames(90)
	_check(progress.has_seen_story(progress.STORY_INTRO), "skipping the trailer marks it seen")
	_check(current_scene != null and current_scene.scene_file_path == UIKit.TITLE_SCENE and current_scene.enter_button.text == "PLAY",
		"...and lands on the title (PLAY, fresh save)")
	Story.launched = false
	_check(not Story.launch_due(current_scene, progress), "second launch: straight to the title, no trailer")
	current_scene.free()
	current_scene = null
	Story.launched = true
	progress.reset_progress()

	# --- Left alone, every shot plays and moves on by itself (runs every shot's drawing)
	progress.story_seen = 0
	for which in ["intro", "finale"]:
		screen = await _open(which, false)
		var shots_seen := {}
		var frames := 0
		var shook := false
		var text_nodes := 0
		while not screen.finished and frames < 60 * 40:
			await process_frame
			frames += 1
			shots_seen[screen.art.shot] = true
			shook = shook or screen.art.shake > 0.0
			if frames % 30 == 0:
				text_nodes += _text_nodes(screen)
		_check(screen.finished and shots_seen.size() == screen.cards.size(), "%s: plays through all %d shots by itself (%d shown)" % [which, screen.cards.size(), shots_seen.size()])
		_check(text_nodes == 0, "%s: no label, button or rich text on screen in any shot" % which)
		_check(absf(frames / 60.0 - Story.length(which)) < 1.0, "%s: ...in about %.1f s (%.1f s)" % [which, Story.length(which), frames / 60.0])
		if which == "intro":
			_check(shook, "intro: the crack and the splat shake the screen")
		screen.free()
	_check(progress.has_seen_story(progress.STORY_INTRO) and progress.has_seen_story(progress.STORY_FINALE), "...and both count as seen")

	# --- Reduce Motion: stills, no shake or zoom, held long enough to read, then on by themselves
	progress.reduce_motion = true
	screen = await _open("finale")
	_check(screen.calm and screen.cards.size() == Story.FINALE.size() and screen.slime != null, "Reduce Motion: finale shows stills")
	# The search: the adventurers find only a puddle: puzzled ("?") first, then angry faces (the still).
	screen.show_card(1)
	_check(_reactions(screen.art) == ["angry", "angry", "angry"], "finale search still: an angry face over each adventurer (%s)" % [_reactions(screen.art)])
	screen.art.start("search")
	screen.art.simulate_to(1.6)
	_check(_reactions(screen.art) == ["huh", "huh", "huh"], "...after a puzzled \"?\" over each (%s)" % [_reactions(screen.art)])
	var icons: Dictionary = screen.art.ICONS
	_check(not icons.has("loot") and not icons.has("sparkle"), "...and no loot or sparkle pictograms any more")
	screen.free()
	screen = await _open("intro", false)
	screen.show_card(4)  # the splat: shakes, bounces and zooms with motion on
	var frozen_t: float = screen.art.t
	await _frames(30)
	_check(screen.art.t == frozen_t and screen.art.t == Story.INTRO[4].still, "Reduce Motion: the shot holds its still (t %.2f)" % screen.art.t)
	_check(screen.art.shake == 0.0 and screen.art.zoom == 1.0 and screen.art.bounce == 0.0, "Reduce Motion: no shake, bounce or zoom")
	screen.show_card(0)
	await _frames(int(60 * (screen.CALM_HOLD - 0.5)))
	_check(screen.index == 0, "Reduce Motion: a still stays up at least %.1f s" % screen.CALM_HOLD)
	await _frames(60)
	_check(screen.index == 1, "...then moves on by itself")
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
	# --- A huge first frame delta (web scene load) keeps the stage bounce bounded
	var big := await _open("intro", false)
	big.art.start("splat")
	big.art.step(0.0, 1.0, 1.0)
	_check(absf(big.art.bounce) < 20.0 and absf(big.art.bounce_v) < 400.0, "a 1 s first frame keeps the bounce bounded (%.1f)" % big.art.bounce)
	big.finish()
	big.free()
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _open(which: String, leave := true) -> Control:
	Story.mode = which
	Story.next_scene = ""
	var screen: Control = load("res://scenes/story.tscn").instantiate()
	screen.leave_on_finish = leave
	root.add_child(screen)
	await process_frame
	return screen


## The reaction pictograms showing over the adventurers right now, in hero order.
func _reactions(art: Node2D) -> Array:
	var shown := []
	for who in 3:
		for pop in art.pops:
			var age: float = art.t - pop.at
			if pop.who == who and pop.icon in ["huh", "angry"] and age >= 0.0 and age < pop.life:
				shown.append(pop.icon)
	return shown


## Text-showing nodes under `node` (the story must have none).
func _text_nodes(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is Label or child is Button or child is RichTextLabel or child is LineEdit or child is TextEdit:
			count += 1
		count += _text_nodes(child)
	return count


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
