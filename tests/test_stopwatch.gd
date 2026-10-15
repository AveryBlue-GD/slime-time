extends "res://tests/suite_base.gd"

## The STOPWATCH skin: unlock rule (all 30 normal-mode medals gold; dev mode unlocks it), selection
## saved/loaded (and a locked saved one falls back to Lime), save codes, clock gearing from one value
## (second:minute 60:1, minute:hour 12:1), speed ramp per mode, Reduce Motion, the unlock notice.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_stopwatch.gd

var progress: Node


var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.hard_mode = false
	progress.reset_progress()

	# --- Unlock rule
	_check(not progress.is_skin_unlocked(Skins.STOPWATCH) and not progress.is_skin_unlocked(Skins.STOPWATCH, false), "locked on a fresh save")
	for level in range(1, 10):
		progress.medals[level] = 3
	_check(not progress.is_skin_unlocked(Skins.STOPWATCH), "9 of 10 golds: still locked")
	progress.medals[10] = 2
	_check(not progress.is_skin_unlocked(Skins.STOPWATCH), "a silver on the last level: locked")
	progress.medals[110] = 3
	_check(not progress.is_skin_unlocked(Skins.STOPWATCH), "hard-mode gold doesn't count")
	progress.medals[10] = 3
	_check(progress.is_skin_unlocked(Skins.STOPWATCH) and progress.is_skin_unlocked(Skins.STOPWATCH, false), "all 30 medals: unlocked")
	_check(Skins.display_name(Skins.STOPWATCH) == "STOPWATCH" and Skins.get_preset(Skins.STOPWATCH).is_empty(), "named, not a preset")

	# --- Select, save, load
	progress.select_skin(Skins.STOPWATCH)
	_check(progress.selected_skin == Skins.STOPWATCH and progress.is_stopwatch() and progress.skin_color() == Skins.STOPWATCH_BASE, "selectable once unlocked")
	var code: String = progress.save_code()
	progress.selected_skin = Skins.DEFAULT
	progress.load_progress()
	_check(progress.selected_skin == Skins.STOPWATCH, "the selected skin survives save and load")
	progress.selected_skin = Skins.DEFAULT
	_check(progress.load_code(code) and progress.selected_skin == Skins.STOPWATCH and code.length() < 4000, "...and a save code (%d chars)" % code.length())
	progress.medals.erase(3)  # a save whose medals no longer add up
	progress.save_progress()
	progress.load_progress()
	_check(progress.selected_skin == Skins.DEFAULT, "a saved stopwatch that is locked falls back to Lime")
	progress.medals[3] = 3
	progress.select_skin(Skins.STOPWATCH)
	progress.reset_progress()
	_check(progress.selected_skin == Skins.DEFAULT and not progress.is_skin_unlocked(Skins.STOPWATCH), "reset clears it")
	progress.dev_tools = true
	_check(progress.is_skin_unlocked(Skins.STOPWATCH), "dev mode unlocks it")
	progress.dev_tools = false

	# --- Gearing: one clock value drives all hands
	for clock: float in [0.0, 1.0, 59.0, 1234.5, 36600.0, 43199.0]:
		var a := Stopwatch.angles(clock)
		_check(is_equal_approx(a.z, a.y * 60.0), "second = 60 x minute at %.1f s" % clock)
		_check(is_equal_approx(a.y, a.x * 12.0), "minute = 12 x hour at %.1f s" % clock)
	var one_rev := Stopwatch.angles(60.0)
	_check(is_equal_approx(one_rev.z, TAU) and is_equal_approx(one_rev.y, TAU / 60.0) and is_equal_approx(one_rev.x, TAU / 720.0), "60 s: second 1 turn, minute 1/60, hour 1/720")
	var hour_rev := Stopwatch.angles(3600.0)
	_check(is_equal_approx(hour_rev.y, TAU) and is_equal_approx(hour_rev.x, TAU / 12.0), "3600 s: minute 1 turn, hour 1/12")
	# ...also while speeding up: after any amount of stepping the angles still agree
	Stopwatch.reset()
	for i in 600:
		Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.LEAP if i < 300 else Stopwatch.Mode.IDLE)
	var b := Stopwatch.angles(Stopwatch.time)
	_check(is_equal_approx(fposmod(b.z, TAU), fposmod(b.y * 60.0, TAU)) and is_equal_approx(b.y, b.x * 12.0), "gearing holds after a whirl and a slowdown")
	_check(Stopwatch.shown_time(100.7, 1.0) == 100.0 and is_equal_approx(Stopwatch.shown_time(100.7, 600.0), 100.7), "ticks in whole seconds when slow, sweeps when fast")

	# --- Speed ramp: idle / move / charge
	Stopwatch.reset()
	_check(Stopwatch.rate == Stopwatch.RATE_IDLE, "starts idle")
	var last := Stopwatch.rate
	var smooth := true
	for i in 120:
		Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.MOVE)
		smooth = smooth and Stopwatch.rate >= last
		last = Stopwatch.rate
	_check(smooth and absf(Stopwatch.rate - Stopwatch.RATE_MOVE) < 0.1, "moving eases up to the move rate (%.2f)" % Stopwatch.rate)
	Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.LEAP)
	_check(Stopwatch.rate < 100.0 and Stopwatch.rate > Stopwatch.RATE_MOVE, "a leap ramps, it doesn't snap (%.1f after one frame)" % Stopwatch.rate)
	for i in 90:
		Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.LEAP)
	_check(Stopwatch.rate > 0.95 * Stopwatch.RATE_LEAP, "the whirl reaches full speed (%.0f)" % Stopwatch.rate)
	Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.IDLE)
	_check(Stopwatch.rate > 0.9 * Stopwatch.RATE_LEAP, "easing back down after landing is gradual")
	for i in 600:
		Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.IDLE)
	_check(Stopwatch.rate < 1.1, "...and settles to idle (%.2f)" % Stopwatch.rate)
	_check(Stopwatch.mode_for(Slime.State.CHARGING, 0.0) == Stopwatch.Mode.LEAP and Stopwatch.mode_for(Slime.State.AIRBORNE, 50.0) == Stopwatch.Mode.LEAP
			and Stopwatch.mode_for(Slime.State.GLIDE, 50.0) == Stopwatch.Mode.MOVE and Stopwatch.mode_for(Slime.State.GLIDE, 0.0) == Stopwatch.Mode.IDLE, "slime states map to idle / move / leap")

	# --- Reduce Motion: a calm tick, no whirl
	_check(Stopwatch.target_rate(Stopwatch.Mode.LEAP, true) <= 2.0 and Stopwatch.target_rate(Stopwatch.Mode.MOVE, true) <= 2.0, "reduce motion: leap and move only tick calmly")
	Stopwatch.reset()
	for i in 300:
		Stopwatch.step(1.0 / 60.0, Stopwatch.Mode.LEAP, true)
	_check(Stopwatch.rate < 2.1, "reduce motion: never whirls (%.2f)" % Stopwatch.rate)
	Stopwatch.reset()

	# --- The skin on a slime: clock on, hands fed to the shader, face follows the frame
	var slime: Slime = preload("res://scenes/slime.tscn").instantiate()
	root.add_child(slime)
	slime.apply_skin(Skins.STOPWATCH_BASE, false, true)
	await process_frame
	await process_frame
	var mat := slime.sprite.material as ShaderMaterial
	_check(mat.get_shader_parameter("clock_on") > 0.5 and slime.sprite.has_node("StopwatchFace"), "the slime runs the clock")
	var face: Vector4 = mat.get_shader_parameter("clock_face")
	_check(face.z >= 4.0 and face.z <= 7.0, "face fits the 14 px body (radius %.1f)" % face.z)
	slime.apply_skin(Skins.get_preset("lime").color)
	_check(mat.get_shader_parameter("clock_on") < 0.5 and not slime.sprite.has_node("StopwatchFace"), "another skin turns it off")
	slime.free()

	# --- The notice on the result screen when the last gold is earned (once)
	progress.reset_progress()
	for level in range(1, 10):
		progress.medals[level] = 3
	var game := await _spawn_running(10)
	game.add_child(preload("res://tests/autopilot.gd").new())
	await _until_finished(game, 120.0)
	_check(game.won and progress.all_medals() and progress.is_skin_unlocked(Skins.STOPWATCH), "the last gold unlocks it")
	_check("NEW SKIN: STOPWATCH" in game.hud.message.text, "...and the result screen says so")
	_check(Progress.STOPWATCH_NOTICE in progress.skin_notices_seen, "...once (saved in skin_notices_seen)")
	await _stop(game)
	progress.reset_progress()

	_result()
	quit(1 if failures else 0)


func _spawn_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = preload("res://scenes/main.tscn").instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _until_finished(game: Node2D, max_seconds: float) -> void:
	for i in int(max_seconds * 60.0):
		await physics_frame
		if game.finished:
			return


func _stop(game: Node2D) -> void:
	current_scene = null
	for i in int(game.CHOICE_DELAY * 60) + 10:
		await physics_frame
	game.free()
