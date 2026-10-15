extends "res://tests/suite_base.gd"

## Phase 1B feel + light checks: jump input buffer, camera kick / hit-stop (and Reduce Motion),
## SFX pitch variation, the low-slime warning, the new optional settings (saved, defaulted,
## kept on RESET PROGRESS), the lantern above the fog, and a fog shader with no arrays.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_phase1b.gd

const MAIN := preload("res://scenes/main.tscn")
const GameScript := preload("res://scripts/game.gd")



var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.save_path = test_save
	progress.reduce_motion = false
	progress.fog_brightness = progress.FOG_NORMAL
	var spot := {}

	# --- Jump buffer: a press made while stunned starts the charge when the stun ends.
	var game := await _spawn_game()
	spot = _dead_end(game, 3)
	await _splat(game, spot, 100.0)
	_check(game.slime.state == Slime.State.STUNNED, "a hard splat stuns the slime")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	_check(game.slime.state == Slime.State.STUNNED, "pressing jump while stunned does nothing yet")
	for i in 40:
		await physics_frame
		if game.slime.state == Slime.State.CHARGING:
			break
	_check(game.slime.state == Slime.State.CHARGING, "...but the buffered press starts charging as soon as it can")
	Input.action_release("jump")
	for i in 5:
		await physics_frame
	game.free()

	# A tap that was let go before the slime recovered must not start (or fire) anything.
	game = await _spawn_game()
	await _splat(game, spot, 100.0)
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for i in 60:
		await physics_frame
	_check(game.slime.state == Slime.State.GLIDE, "a tap during the stun does not auto-leap or charge")
	# ...and a press made long before it can charge again expires.
	game.free()

	# --- Hit-stop and kick: the picture holds, the run clock does not.
	game = await _spawn_game()
	var clock_before: float = game.run_time
	var frames := 0
	var splat_pos := await _splat(game, spot, 100.0, true)
	_check(splat_pos.kick_dot > 0.5, "the camera is kicked toward the wall that was hit")
	_check(splat_pos.hit_stop > 0.0, "a hard splat holds the slime's picture for a moment")
	_check(Slime.HIT_STOP_MAX <= 0.08, "hit-stop is very short")
	var clock_mid: float = game.run_time
	for i in 30:
		await physics_frame
	_check(absf((game.run_time - clock_mid) - 0.5) < 0.03, "the run timer keeps counting through hit-stop (%.3f s over 30 frames)" % (game.run_time - clock_mid))
	game.free()

	# --- Reduce motion: no shake, kick or hit-stop.
	progress.reduce_motion = true
	game = await _spawn_game()
	var calm := await _splat(game, spot, 100.0, true)
	_check(calm.hit_stop == 0.0 and not calm.shook, "REDUCE MOTION skips the hit-stop and the shake/kick")
	game.free()
	progress.reduce_motion = false

	# --- SFX variation
	var sfx: Node = root.get_node("Sfx")
	var pitches := {}
	for i in 12:
		sfx.play("land", 0.0, 1.0)
		pitches[snappedf((sfx._players["land"][0] as AudioStreamPlayer).pitch_scale, 0.001)] = true
		await process_frame
		sfx.stop("land")
	_check(pitches.size() > 3, "repeated sounds vary in pitch (%d distinct)" % pitches.size())
	_check(pitches.keys().all(func(p: float) -> bool: return p > 0.94 and p < 1.06), "...by only a few percent")
	_check(sfx.has_sound("heartbeat") and sfx.has_sound("lowwarn"), "the low-slime warning sounds exist")

	# --- Low-slime warning
	game = await _spawn_game()
	game.slime_remaining = 50.0
	await physics_frame
	_check(not game._was_low, "no warning above the red mark")
	game.slime_remaining = 15.0
	for i in 90:
		await physics_frame
	_check(game._was_low, "dropping under the red mark triggers the warning cue")
	var beat := false
	for player: AudioStreamPlayer in sfx._players["heartbeat"]:
		beat = beat or player.playing
	game.slime_remaining = 60.0
	for i in 5:
		await physics_frame
	_check(not game._was_low, "...and it stops when the meter recovers")
	var slow: float = game.HEARTBEAT_SLOW
	_check(lerpf(float(game.HEARTBEAT_FAST), slow, 0.1) < slow, "the heartbeat speeds up as the slime runs out")
	_check(game.slime_light.z_index > game.fog_sprite.z_index, "the lantern is drawn above the fog")
	game.free()

	# --- Settings are optional keys with defaults, saved, and read back.
	var file := ConfigFile.new()
	var fresh: Node = preload("res://scripts/progress.gd").new()
	fresh._read(file)
	_check(not fresh.reduce_motion and fresh.fog_brightness == fresh.FOG_NORMAL, "an old save without the new keys loads with the defaults")
	fresh.reduce_motion = true
	fresh.fog_brightness = fresh.FOG_BRIGHT
	var written: ConfigFile = fresh._write()
	var other: Node = preload("res://scripts/progress.gd").new()
	other._read(written)
	_check(other.reduce_motion and other.fog_brightness == other.FOG_BRIGHT, "reduce motion and fog brightness round-trip")
	written.set_value("settings", "fog_brightness", 99)
	other._read(written)
	_check(other.fog_brightness == other.FOG_BRIGHT, "a bad fog value is clamped")
	fresh.free()
	other.free()

	# --- Fog looks: shader and fog_alpha_at agree for every brightness, Normal is the standard look.
	for setting in 3:
		progress.fog_brightness = setting
		game = await _spawn_game()
		var look: Dictionary = game.fog_look()
		var material: ShaderMaterial = game.fog_sprite.material
		var fa: Vector4 = material.get_shader_parameter("fade_alpha")
		_check(is_equal_approx(fa.y, look.fade[1]) and is_equal_approx(material.get_shader_parameter("fade_alpha_last"), look.fade[4])
			and is_equal_approx(material.get_shader_parameter("wall_shade"), look.wall), "fog setting %d: the shader gets the table fog_alpha_at uses" % setting)
		var outer: ShaderMaterial = game.outer_fog.material
		_check(is_equal_approx(outer.get_shader_parameter("mist_gain"), look.mist_gain), "fog setting %d: the outer fog matches" % setting)
		var start: Vector2 = game.slime.position
		await physics_frame
		_check(game.fog_alpha_at(start) == 0.0, "fog setting %d: lit ground under the slime is clear" % setting)
		game.free()
	progress.fog_brightness = progress.FOG_NORMAL
	_check(GameScript.FOG_LOOKS[1].fade == GameScript.FADE_ALPHA and GameScript.FOG_LOOKS[1].wall == GameScript.WALL_FOG_ALPHA, "Normal is the standard fade table")
	_check(GameScript.FOG_LOOKS[2].fade[4] < GameScript.FOG_LOOKS[1].fade[4] and GameScript.FOG_LOOKS[0].fade[4] > GameScript.FOG_LOOKS[1].fade[4], "Bright is lighter and Dark heavier than Normal")
	_check(GameScript.FOG_LOOKS[2].mist_gain >= GameScript.FOG_LOOKS[1].mist_gain and GameScript.FOG_LOOKS[2].deep_gain >= GameScript.FOG_LOOKS[1].deep_gain, "Bright never gets darker than Normal")

	# --- The fog shader has no arrays (Android WebGL).
	var source := FileAccess.get_file_as_string("res://assets/shaders/fog.gdshader")
	var code := "\n".join(Array(source.split("\n")).filter(func(l: String) -> bool: return not l.strip_edges().begins_with("//")))
	_check(not code.contains("["), "the fog shader indexes no arrays")
	_check(not code.contains("for ("), "...and has no loops over uniforms")

	_result()
	quit(1 if failures else 0)


## Puts the slime at a dead end and leaps into the wall; with `watch`, reports the frame the splat
## lands (kick direction, hit-stop, shake).
func _splat(game: Node2D, spot: Dictionary, charge: float, watch := false) -> Dictionary:
	var start := MazeGenerator.cell_center(spot.cell, 16)
	game.slime.position = start
	game.last_slime_pos = start
	game.slime.facing = Vector2(spot.dir)
	game.slime.launch(charge)
	var frames := 0
	var shook := false
	for i in 120:
		await physics_frame
		frames += 1
		if game.slime.state == Slime.State.STUNNED:
			break
	await process_frame
	var info := {frames = frames, kick_dot = game.kick.normalized().dot(Vector2(spot.dir)), hit_stop = game.slime._hit_stop_left,
		shook = game.camera.offset != Vector2.ZERO or game.kick != Vector2.ZERO}
	return info


func _dead_end(game: Node2D, behind: int) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell):
					continue
				var back := cell
				var ok := true
				for i in behind:
					ok = ok and (back - dir) in MazeGenerator.open_neighbors(game.maze, back)
					back -= dir
				if ok:
					return {cell = cell, dir = dir}
	return {}


