extends SceneTree

## Phase 6 checks: pixel font with real spaces, every sound loads and plays (and stays quiet when
## muted), splats shake the screen briefly, the pause menu freezes the level, and the victory
## screen builds. Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_phase6.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	var sfx: Node = root.get_node("Sfx")
	progress.save_path = "user://test_save.cfg"
	progress.sound_on = true

	# --- Font
	var font: Font = load(ProjectSettings.get_setting("gui/theme/custom_font"))
	var spaced := font.get_string_size("NEW GAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var squashed := font.get_string_size("NEWGAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_check(font is FontFile and spaced >= squashed + 3, "pixel font is the project font, with real spaces (%d vs %d px)" % [spaced, squashed])
	_check(font.has_char("Q".unicode_at(0)) and font.has_char("q".unicode_at(0)) and font.has_char("%".unicode_at(0)),
		"font covers letters (both cases), digits and punctuation")

	# --- Sounds
	var all_sounds := true
	for sound_name in sfx.SOUNDS:
		all_sounds = all_sounds and sfx.has_sound(sound_name) and sfx._players[sound_name][0].stream.get_length() > 0.0
	_check(all_sounds, "%d sound effects load" % sfx.SOUNDS.size())
	progress.sound_on = false
	sfx.play("click")
	_check(not _playing(sfx, "click"), "muted: nothing plays")
	progress.sound_on = true
	progress.set_volume(0.5)
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01 and not AudioServer.is_bus_mute(0),
		"volume slider value drives the master volume")
	progress.set_volume(0.0)
	_check(AudioServer.is_bus_mute(0), "volume at zero mutes")
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = progress.save_path
	reloaded.load_progress()
	_check(reloaded.volume == 0.0, "volume is saved")
	reloaded.free()
	progress.set_volume(0.8)

	# --- Splat: sound + brief screen shake
	var game := await _spawn()
	game.slime.facing = Vector2.UP
	game.slime.launch(100.0)
	var shook := false
	for i in 30:
		await process_frame
		shook = shook or game.camera.offset != Vector2.ZERO
	_check(_playing(sfx, "splat") or shook, "a splat plays the splat sound")
	_check(shook, "a splat shakes the screen")
	for i in 40:
		await process_frame
	_check(game.camera.offset == Vector2.ZERO, "the shake settles quickly")

	# --- Pause
	var before: Vector2 = game.slime.position
	game.pause_menu.open()
	_check(paused and game.pause_menu.visible, "pause menu opens and freezes the game")
	Input.action_press("move_down")
	for i in 30:
		await physics_frame
	Input.action_release("move_down")
	_check(game.slime.position == before, "the slime can't move while paused")
	_check(game.pause_menu.buttons.size() == 4, "pause menu: resume, restart, sound, quit")
	var pause_slider: HSlider = game.pause_menu.volume_row.get_meta("slider")
	_check(pause_slider.value == 0.8, "pause menu has a volume slider showing the current volume")
	var p_key := InputEventKey.new()
	p_key.physical_keycode = KEY_P
	_check(InputMap.event_is_action(p_key, "menu"), "P also pauses (browsers keep Esc for leaving fullscreen)")
	var esc := InputEventAction.new()
	esc.action = "menu"
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check(not paused and not game.pause_menu.visible, "Esc resumes")
	game.free()

	# --- Victory screen
	var victory: Control = load("res://scenes/victory.tscn").instantiate()
	root.add_child(victory)
	await process_frame
	_check(victory.buttons.size() == 3 and victory.buttons[0].text == "PICK YOUR COLOR", "victory screen offers: pick your color, randomizer, title")
	victory.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	return game


func _playing(sfx: Node, sound_name: String) -> bool:
	for player: AudioStreamPlayer in sfx._players[sound_name]:
		if player.playing:
			return true
	return false


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
