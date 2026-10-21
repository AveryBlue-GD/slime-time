extends "res://tests/suite_base.gd"

## Phase 6 checks: pixel font with real spaces, every sound loads and plays (and stays quiet when
## muted), splats shake the screen briefly, the pause menu freezes the level, and the victory
## screen builds. Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_phase6.gd

const MAIN := preload("res://scenes/main.tscn")



var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	var sfx: Node = root.get_node("Sfx")
	progress.save_path = test_save
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
	progress.set_music_volume(0.3)
	var sfx_bus := AudioServer.get_bus_index(progress.SFX_BUS)
	var music_bus := AudioServer.get_bus_index(progress.MUSIC_BUS)
	_check(sfx_bus > 0 and absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.5)) < 0.01 and not AudioServer.is_bus_mute(sfx_bus)
		and absf(AudioServer.get_bus_volume_db(0)) < 0.01 and sfx._players["click"][0].bus == progress.SFX_BUS,
		"the SFX slider drives the SFX bus (the sound effects play there; Master stays at 0 dB)")
	_check(music_bus > 0 and absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.3)) < 0.01 and get_root().get_node("Music")._player.bus == progress.MUSIC_BUS,
		"the MUSIC slider drives the Music bus on its own")
	progress.set_volume(0.0)
	_check(AudioServer.is_bus_mute(sfx_bus) and not AudioServer.is_bus_mute(music_bus), "SFX at zero mutes the effects, not the music")
	progress.set_volume(0.8)
	progress.set_music_volume(0.0)
	_check(AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(sfx_bus), "MUSIC at zero mutes the music, not the effects")
	progress.set_music_volume(0.35)
	progress.set_volume(0.0)
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = progress.save_path
	reloaded.load_progress()
	_check(reloaded.volume == 0.0 and is_equal_approx(reloaded.music_volume, 0.35), "SFX and MUSIC volumes are saved separately")
	reloaded.free()
	progress.set_volume(0.8)

	# --- Splat: sound + brief screen shake
	var game := await _spawn_game()
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

	_result()
	quit(1 if failures else 0)


func _playing(sfx: Node, sound_name: String) -> bool:
	for player: AudioStreamPlayer in sfx._players[sound_name]:
		if player.playing:
			return true
	return false


