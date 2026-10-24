extends "res://tests/suite_base.gd"

## BM-08 GOO ORCHESTRA (Economy.ORCHESTRA_TEST): the three level-music layers (BASE always, PULSE while moving,
## TENSION on a low meter / the chalice first seen within 12 tiles) follow the game and glide, the music ducks under
## splat / coin / win sounds and recovers, the coin chain climbs a semitone per coin within 2 s (cap +6) and resets,
## the theme sets the layers' pitch, LEVEL MUSIC off silences all of it, and the flag off is the IMP-05 bed.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_orchestra.gd


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	var music: Node = root.get_node("Music")
	var sfx: Node = root.get_node("Sfx")
	progress.saving_enabled = false
	_check(Economy.ORCHESTRA_TEST == true, "ORCHESTRA_TEST is on in this test build")
	Economy.orchestra_force = 1
	_check(Economy.orchestra_on(), "orchestra_force = 1 turns it on")

	# --- the coin chain
	var step := pow(2.0, 1.0 / 12.0)
	_check(is_equal_approx(sfx.coin_chain_pitch(1000), 1.0), "the first coin plays at the plain pitch")
	_check(is_equal_approx(sfx.coin_chain_pitch(2500), step), "a coin within 2 s plays a semitone higher")
	_check(is_equal_approx(sfx.coin_chain_pitch(4000), step * step), "and the next one another")
	var last := 0.0
	for i in 8:
		last = sfx.coin_chain_pitch(5000 + i * 500)
	_check(is_equal_approx(last, pow(2.0, 6.0 / 12.0)), "the chain is capped at +6 semitones")
	_check(is_equal_approx(sfx.coin_chain_pitch(9000 + 2100), 1.0), "after a 2 s gap it starts again at the plain pitch")

	# --- layers follow the game
	music.follow_scene(music.LEVEL_SCENE)
	_check(music.orch_active and music.current == music.ORCH_TRACKS[0], "a level starts the orchestra")
	var layers: Array = music._orch
	_check(layers.size() == 3 and layers.all(func(p: AudioStreamPlayer) -> bool: return p.playing), "all three layers play")
	var lengths: Array = music.ORCH_TRACKS.map(func(p: String) -> float: return (load(p) as AudioStream).get_length())
	_check(absf(lengths[0] - lengths[1]) < 0.02 and absf(lengths[0] - lengths[2]) < 0.02, "the layers are the same length (%s)" % str(lengths))
	var game: Node2D = await _spawn_game({level = 1})
	game.slime.velocity = Vector2.ZERO
	game.slime_remaining = 100.0
	game.slime.position = game.goal.position + Vector2(400, 0)
	game._orch_seen = false
	game._orchestra_frame(0.0)
	_check(music.orch_target == [1.0, 0.0, 0.0], "still, meter full, chalice far: BASE only")
	game.slime.velocity = Vector2(60, 0)
	game._orchestra_frame(0.0)
	_check(music.orch_target == [1.0, 1.0, 0.0], "moving: PULSE comes in")
	game.slime.velocity = Vector2.ZERO
	game.slime_remaining = 10.0
	game._orchestra_frame(0.0)
	_check(music.orch_target == [1.0, 0.0, 1.0], "low meter: TENSION comes in")
	game.slime_remaining = 100.0
	game._orchestra_frame(0.0)
	_check(music.orch_target == [1.0, 0.0, 0.0], "meter back up: TENSION goes")
	game.slime.position = game.goal.position + Vector2(150, 0)
	game._orchestra_frame(0.0)
	_check(not game._orch_seen and music.orch_target == [1.0, 0.0, 0.0], "the chalice near but still in the fog: no sighting (no hint)")
	game.reveal_tile(Vector2i(game.goal.position / game.TILE), false)
	game._orchestra_frame(0.0)
	_check(game._orch_seen and music.orch_target == [1.0, 0.0, 1.0], "the chalice revealed within 12 tiles: TENSION (and once)")
	game._orchestra_frame(game.ORCH_TENSE_TIME + 1.0)
	_check(music.orch_target == [1.0, 0.0, 0.0] and game._orch_seen, "the tension from the sighting lasts a while only")

	# --- smoothing and the layer volumes (the game is frozen so it stops setting the targets)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	music.orchestra_state(true, true)
	await _wait_seconds(3.0)  # (the bed's own fade-in is 2.5 s)
	_check(is_equal_approx(music.orch_level[1], 1.0) and is_equal_approx(music.orch_level[2], 1.0), "layers glide up to full")
	var full: float = layers[0].volume_db
	_check(full > -12.0 and full <= music.LEVEL_DB + 0.2 and layers[1].volume_db > -12.0 and layers[2].volume_db > -12.0, "all three are audible (%.1f dB)" % full)
	music.orchestra_state(false, false)
	await _wait_seconds(0.25)
	_check(music.orch_level[1] > 0.0 and music.orch_level[1] < 1.0, "a layer glides, no jump (%.2f after 0.25 s)" % music.orch_level[1])
	await _wait_seconds(0.5)
	_check(music.orch_level[1] == 0.0 and layers[1].volume_db <= -79.0, "and is silent after 0.5 s")

	# --- ducking
	await _wait_seconds(0.2)
	var before: float = layers[0].volume_db
	sfx.play("splat", -20.0)
	_check(music._duck_hold <= 0.0, "a very quiet splat does not duck")
	sfx.play("coin", -4.0)
	_check(music._duck_hold > 0.0, "a coin ducks the music")
	await _wait_seconds(0.15)
	var ducked: float = layers[0].volume_db
	_check(ducked <= before - 4.0 and ducked >= before - 6.0, "ducked by 4-6 dB (%.1f -> %.1f)" % [before, ducked])
	await _wait_seconds(0.9)
	_check(music.duck_db == 0.0 and absf(layers[0].volume_db - before) < 0.2, "and the music is back after")
	sfx.play("splat", -3.0)
	_check(music._duck_hold > 0.0, "a splat ducks it")
	sfx.play("chalice", -3.0)
	await _wait_seconds(0.9)

	# --- theme pitch, stings
	music.set_orchestra_theme("catacombs")
	_check(is_equal_approx(layers[0].pitch_scale, 0.89) and is_equal_approx(layers[2].pitch_scale, 0.89), "a theme sets all three layers' pitch")
	for theme in Themes.BY_LEVEL:
		_check(music.ORCH_THEME_PITCH.has(theme), "theme %s has a pitch" % theme)
	music.play_orchestra_sting("chalice")
	_check(music._sting_player.playing, "the chalice sting plays")
	music._sting_player.stop()
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.queue_free()
	await physics_frame

	# --- LEVEL MUSIC off silences everything
	progress.level_music = false
	music.follow_scene(music.LEVEL_SCENE)
	await _wait_seconds(1.0)
	_check(music.current == "" and not layers.any(func(p: AudioStreamPlayer) -> bool: return p.playing), "LEVEL MUSIC off: no layer plays")
	music.play_orchestra_sting("win")
	_check(not music._sting_player.playing, "LEVEL MUSIC off: no sting either")
	progress.level_music = true

	# --- the flag off is the IMP-05 bed
	Economy.orchestra_force = 0
	music.follow_scene(music.LEVEL_SCENE)
	_check(music.current == music.LEVEL_TRACK and not music.orch_active, "flag off: the single IMP-05 bed")
	sfx.play("coin", -4.0)
	_check(music._duck_hold <= 0.0, "flag off: no ducking")
	_check(is_equal_approx(sfx.coin_chain_pitch(0) * 0.0 + 1.0, 1.0), "flag off: Sfx.play leaves the coin pitch alone")
	music.play_orchestra_sting("win")
	_check(not music._sting_player.playing, "flag off: no sting")
	music.stop(0.0)
	Economy.orchestra_force = -1
	_result()
	quit(0 if failures == 0 else 1)
