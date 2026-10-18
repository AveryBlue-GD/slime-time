extends "res://tests/suite_base.gd"

## The first-session tutorial's flow and save rules (chunk A of docs/tutorial/design.md, gate
## Economy.TUTORIAL_TEST): with the gate OFF nothing changes (today's intro -> title PLAY -> level 1,
## the save bytes and the title's English layout identical, nothing due, no new bit written). With it
## ON a fresh save goes intro -> training (Esc on the intro too) -> hub tour, saves TUTORIAL_TRAINING
## (+ the MOVE / LEAP bits really used) and TUTORIAL_HUB, the title then says ENTER THE HUB; returning
## saves, save codes and dev mode never see it; RESET PROGRESS makes it due again; the SETTINGS replay
## writes nothing; `--tutorial[=maze|hub]` parses and sets up a clean in-memory state.
## While chunk B's maze isn't built (game.gd has no training_beat), the training hand-off is a stub
## that counts the training as skipped and opens the hub; the checks follow whichever is there.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_tutorial_flow.gd

var progress: Node
var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = true
	progress.save_path = test_save
	progress.dev_tools = false
	Story.launched = true

	await _gate_off()
	await _gate_on_rules()
	await _boot_flow()
	_flags()

	Economy.tutorial_force = -1
	progress.saving_enabled = true
	progress.save_path = test_save
	progress.reset_progress()
	_check(Economy.TUTORIAL_TEST and Economy.tutorial_on(), "the tutorial ships ON (owner, 2026-10-18)")
	_result()
	quit(1 if failures > 0 else 0)


# --- Gate off: today's flow, byte-identical saves, the same title
func _gate_off() -> void:
	Economy.tutorial_force = 0
	progress.reset_progress()
	var before := _save_bytes()
	_check(before.contains("tutorial_seen=0"), "gate off: a fresh save writes tutorial_seen=0 as today")
	_check(progress.is_fresh_save() and not progress.tutorial_due() and not progress.hub_tour_due(), "gate off: fresh save, nothing due")
	_check(Story.launch_next(progress) == UIKit.TITLE_SCENE and progress.mode == progress.MODE_STORY, "gate off: the launch intro still wipes into the title")
	progress.note_training_input(progress.TUTORIAL_MOVE)
	_check(progress.finish_training(false) == progress.TOUR_SCENE and progress.tutorial_seen == 0, "gate off: finish_training writes no bit")
	progress.finish_hub_tour()
	_check(progress.tutorial_seen == 0 and progress.is_fresh_save(), "gate off: finish_hub_tour writes no bit; still fresh")
	progress.save_progress()
	_check(_save_bytes() == before, "gate off: the save is byte-identical after every tutorial call")
	progress.tutorial_seen = progress.TUTORIAL_TRAINING  # (only a gate-on build writes this)
	_check(progress.is_fresh_save(), "gate off: a training bit doesn't end the fresh save")
	progress.tutorial_seen = 0

	# The title, gate off vs gate on (a save the tutorial isn't due for): the same English screen.
	var off_fresh := await _title_layout()
	var title := await _title()
	_check(title.enter_button.text == "PLAY" and Rect2(title.enter_button.position, title.enter_button.size) == Rect2(72, 84, 176, 25),
		"gate off, fresh save: PLAY at (72, 84) 176x25 as today")
	title._play()
	_check(progress.mode == progress.MODE_STORY and progress.current_level == 1, "gate off: PLAY starts level 1 in story mode")
	title.free()
	await _settle()
	progress.levels_cleared = 1
	var off_back := await _title_layout()
	Economy.tutorial_force = 1
	var on_back := await _title_layout()
	_check(off_back == on_back and off_back.size() > 3, "a returning save: the title is identical with the gate on (%d controls)" % off_back.size())
	progress.levels_cleared = 0
	progress.tutorial_seen = progress.TUTORIAL_MOVE  # moved in level 1: fresh but never due
	_check(not progress.tutorial_due(), "gate on: a fresh save that already moved in level 1 isn't due")
	var on_fresh := await _title_layout()
	_check(off_fresh == on_fresh, "...and its title is identical to the gate-off fresh title (PLAY)")
	progress.tutorial_seen = 0
	Economy.tutorial_force = 0


# --- Gate on: the save rules
func _gate_on_rules() -> void:
	Economy.tutorial_force = 1
	progress.reset_progress()
	_check(progress.tutorial_due() and not progress.hub_tour_due(), "gate on: a fresh save is due the training, not the tour")
	progress.dev_tools = true
	_check(not progress.tutorial_due() and not progress.hub_tour_due(), "dev mode: never due")
	progress.dev_tools = false

	# The full run: moved and leapt, reached the chalice.
	var next: String = progress.prepare_training(false)
	_check(next == progress.TRAINING_SCENE and progress.in_training(), "prepare_training: MODE_TRAINING, the training maze scene")
	progress.note_training_input(progress.TUTORIAL_MOVE)
	progress.note_training_input(progress.TUTORIAL_LEAP | 16)
	_check(progress.tutorial_seen == 0 and progress.training_used == 3, "...moves / leaps are remembered, not saved yet")
	next = progress.finish_training(false)
	_check(next == progress.TOUR_SCENE and progress.mode == progress.MODE_STORY, "finish_training: back to story mode, the hub next")
	_check(progress.tutorial_seen == 7 and _save_bytes().contains("tutorial_seen=7"), "...saves TRAINING + MOVE + LEAP (%d)" % progress.tutorial_seen)
	_check(not progress.is_fresh_save() and not progress.tutorial_due(), "...the save isn't fresh any more (the hub is open)")
	var title := await _title()
	_check(title.enter_button.text == "ENTER THE HUB", "...the title says ENTER THE HUB")
	title.free()
	_check(progress.hub_tour_due(), "...the hub tour is due")
	progress.finish_hub_tour()
	_check(progress.tutorial_seen == 15 and not progress.hub_tour_due() and _save_bytes().contains("tutorial_seen=15"), "finish_hub_tour saves TUTORIAL_HUB; never due again")
	progress.finish_training(false)
	_check(progress.tutorial_seen == 15 and not progress.hub_tour_due(), "finish_training twice is harmless")

	# Replay from SETTINGS: plays, writes nothing, the tour follows once.
	var saved := _save_bytes()
	progress.prepare_training(true)
	progress.note_training_input(progress.TUTORIAL_MOVE)
	if progress.in_training():
		progress.finish_training(false)
	_check(progress.hub_tour_due() and not progress.in_training(), "replay: the tour is due after it")
	progress.finish_hub_tour()
	_check(not progress.hub_tour_due() and progress.tutorial_seen == 15 and _save_bytes() == saved, "replay: nothing saved, the tour done")

	# Skipped before moving: only the training bit, the level 1-2 cues stay.
	progress.reset_progress()
	progress.prepare_training(false)
	if progress.in_training():
		progress.finish_training(true)
	_check(progress.tutorial_seen == progress.TUTORIAL_TRAINING and progress.training_skipped, "an early skip saves only TUTORIAL_TRAINING")
	_check(not progress.has_seen_tutorial(progress.TUTORIAL_MOVE) and not progress.has_seen_tutorial(progress.TUTORIAL_LEAP), "...so the level 1-2 move / leap cues still show")
	_check(progress.hub_tour_due() and not progress.tutorial_due(), "...and the tour is due, the training isn't")

	# Returning players and codes.
	progress.reset_progress()
	_check(progress.tutorial_due(), "RESET PROGRESS makes the training due again")
	var file := ConfigFile.new()
	file.set_value("progress", "levels_cleared", 2)
	progress._read(file)
	_check(not progress.tutorial_due() and not progress.hub_tour_due(), "an old save with progress (no key: bits 1|2) never sees it")
	file = ConfigFile.new()
	file.set_value("progress", "randoms_won", 1)
	progress._read(file)
	_check(not progress.tutorial_due(), "...nor one with a randomizer win")
	progress.reset_progress()
	progress.levels_cleared = 3
	var code: String = progress.save_code()
	progress.reset_progress()
	_check(progress.load_code(code) and not progress.tutorial_due() and not progress.hub_tour_due(), "a loaded save code with progress never sees it")
	progress.reset_progress()
	_check(not progress.training_replay and not progress.tour_replay and progress.training_used == 0, "RESET PROGRESS clears the session state too")
	Economy.tutorial_force = 0


# --- The boot: intro -> training (or the stub's hub), Esc too; PLAY on a due save; gate off unchanged
func _boot_flow() -> void:
	var packed: PackedScene = load("res://scenes/title.tscn")
	for gate in [1, 0]:
		Economy.tutorial_force = gate
		progress.reset_progress()
		Story.launched = false
		change_scene_to_packed(packed)
		await _frames(5)
		_check(current_scene != null and current_scene.scene_file_path == Story.SCENE, "gate %d: booting a fresh save opens the intro" % gate)
		var screen := current_scene
		var expect: String = UIKit.TITLE_SCENE
		if gate == 1:
			expect = progress.TRAINING_SCENE
		_check(screen.next_scene == expect, "gate %d: ...which leads to %s (%s)" % [gate, expect.get_file(), screen.next_scene.get_file()])
		await _frames(20)
		screen._unhandled_input(_key(KEY_ESCAPE))
		await _frames(90)
		_check(progress.has_seen_story(progress.STORY_INTRO) and current_scene != null and current_scene.scene_file_path == expect,
			"gate %d: Esc on the intro marks it seen and lands on %s" % [gate, expect.get_file()])
		if gate == 0:
			_check(current_scene.enter_button.text == "PLAY" and progress.tutorial_seen == 0, "gate off: ...the title, PLAY, no tutorial bit")
		await _settle()
	# Quit during the training (intro seen, no bit): the title's PLAY goes to the training.
	Economy.tutorial_force = 1
	progress.reset_progress()
	progress.story_seen = progress.STORY_INTRO
	var title := await _title()
	_check(title.enter_button.text == "PLAY", "gate on, intro seen, training not: the title says PLAY")
	title._play()
	await _frames(90)
	var landed: String = current_scene.scene_file_path if current_scene else ""
	_check(landed == (progress.TRAINING_SCENE), "...and PLAY opens the training (%s)" % landed.get_file())
	title.free()
	await _settle()
	Economy.tutorial_force = 0
	progress.reset_progress()


# --- `--tutorial[=maze|hub]`
func _flags() -> void:
	var P: GDScript = progress.get_script()
	_check(P.tutorial_flag(PackedStringArray()) == "" and P.tutorial_flag(PackedStringArray(["--story-complete"])) == "", "no --tutorial: no tutorial launch")
	_check(P.tutorial_flag(PackedStringArray(["--tutorial"])) == "intro" and P.tutorial_flag(PackedStringArray(["--tutorial=maze"])) == "maze"
		and P.tutorial_flag(PackedStringArray(["--tutorial=hub"])) == "hub" and P.tutorial_flag(PackedStringArray(["--tutorial=x"])) == "intro",
		"--tutorial / =maze / =hub parse (an unknown value plays it all)")
	_check(P.game_args(PackedStringArray(["--tutorial"]), false).is_empty(), "a release build ignores --tutorial")
	progress.levels_cleared = 4
	progress.enable_tutorial_test("intro")
	_check(not progress.saving_enabled and Economy.tutorial_on() and progress.levels_cleared == 0 and progress.story_seen == 0
		and progress.tutorial_due() and Story.intro_due(progress), "--tutorial: a clean fresh state, saving off, intro and training due")
	_check(progress.take_tutorial_launch() == "", "...the intro's own hand-off (the boot title starts the trailer)")
	progress.enable_tutorial_test("maze")
	_check(not Story.intro_due(progress) and progress.tutorial_due(), "--tutorial=maze: intro seen, training due")
	var maze: String = progress.take_tutorial_launch()
	_check(maze == (progress.TRAINING_SCENE) and progress.take_tutorial_launch() == "", "...the boot title opens it, once")
	progress.enable_tutorial_test("hub")
	_check(progress.hub_tour_due() and not progress.tutorial_due() and not progress.is_fresh_save(), "--tutorial=hub: training done, the tour due")
	_check(progress.take_tutorial_launch() == progress.TOUR_SCENE, "...the boot title opens the hub")
	var real: String = progress.REAL_SAVE_PATH
	_check(progress.save_path != real and not progress._is_real_save(progress.save_path), "...and never on the real save path")
	Economy.tutorial_force = 0
	progress.tutorial_launch = ""


func _save_bytes() -> String:
	progress.save_progress()
	return FileAccess.get_file_as_string(test_save)


func _title() -> Control:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)  # not the current scene: no boot hand-off
	await _frames(2)
	return title


## Every control on the title (class, text, rect, visibility), in tree order.
func _title_layout() -> Array[String]:
	var title := await _title()
	var out: Array[String] = []
	var stack: Array[Node] = [title]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node is Control:
			var c := node as Control
			out.append("%s|%s|%s|%s|%s" % [c.get_class(), c.get("text") if "text" in c else "", c.position, c.size, c.visible])
		stack.append_array(node.get_children())
	title.free()
	return out


## Lets scene changes and wipes started by a check land, then drops the current scene.
func _settle() -> void:
	await _frames(90)
	if current_scene:
		current_scene.free()
		current_scene = null


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _frames(n: int) -> void:
	for i in n:
		await process_frame
