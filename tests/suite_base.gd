extends SceneTree

## Shared base for the tests/test_*.gd suites (`extends "res://tests/suite_base.gd"`). It holds what every
## suite used to copy: the `failures` counter and `_check`, `_result` (prints the `RESULT:` line that
## tools/test_all.sh looks for and removes the suite's throwaway files), `throwaway_save` (a save file name
## that is unique per process, so suites can run in parallel), and the small spawn / wait / key helpers.
## Named suite_base.gd (not test_*.gd) so tools/test_all.sh does not run it as a suite.

const BASE_MAIN := preload("res://scenes/main.tscn")
const I18nMode := preload("res://tests/i18n_mode.gd")

var failures := 0


func _init() -> void:
	Economy.idle_drain_force = 0  # (the suites' meter maths predate the idle drain; test_phase1 turns it on)
	# (the suites' ticket maths predate IMP-02: pay on touch, the plain attempt table, every maze starts at attempt 1;
	# test_economy_integrity turns the three on)
	Economy.pickups_on_win_force = 0
	Economy.pay_by_length_force = 0
	Economy.abandon_counts_force = 0
	Economy.orchestra_force = 0  # (BM-08 layered level music is off for the older suites; test_orchestra turns it on)
	Economy.lurkers_force = 0  # (BM-01 lurkers are off for the older suites; test_lurkers turns them on)
	Economy.lightlife_force = 0  # (BM-09 lighting is off for the older suites; test_light_life turns it on)
	Economy.boards_force = 0  # (BM-03 boards and ghosts are off for the older suites; test_boards turns them on)
## Throwaway files this run made through throwaway_save(); _result() deletes them.
var _temp_files: Array[String] = []


## Non-English findings reported but not failed in English-only mode (tests/i18n_mode.gd).
var reported := 0


## Prints "  ok   label" or "  FAIL label" and counts failures. In English-only mode (tests/i18n_mode.gd) a suite that
## declares `const I18N_PER_LOCALE := true` has a check that runs while a non-English locale is set (Language gate on,
## locale not "en") REPORTED instead of failed ("  note  (english-only, de) label"); English checks stay strict.
func _check(ok: bool, label: String) -> void:
	var scope := _report_only_scope()
	if not ok and scope != "":
		print("  note  (english-only, %s) %s" % [scope, label])
		reported += 1
		return
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1


## Like _check, but for a finding about non-English content that is not tied to the locale set at that moment (a
## catalog, a report after the locale loop): reported only while English-only mode is on. `locale` is for the message.
func _check_locale(ok: bool, label: String, locale := "") -> void:
	if not ok and I18nMode.ENGLISH_ONLY:
		print("  note  (english-only%s) %s" % [(", " + locale) if locale != "" else "", label])
		reported += 1
		return
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1


## The non-English locale currently set when the running suite is per-locale and English-only mode is on, else "".
func _report_only_scope() -> String:
	if not I18nMode.ENGLISH_ONLY or not (get_script() as Script).get_script_constant_map().get("I18N_PER_LOCALE", false):
		return ""
	var language := root.get_node_or_null("Language")
	if language == null or not language.get("active"):
		return ""
	var locale: String = language.get("locale")
	return "" if locale == "en" else locale


## Prints the RESULT line, deletes the throwaway files. The suite then calls quit(...) itself.
func _result() -> void:
	for path in _temp_files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# DevLog's per-process log (dev_attempts_<pid>.log) - only this process's own, never the owner's dev_attempts.log.
	# A crash or a kill never gets here: tools/test_all.sh removes those files per job and sweeps dead pids at the start.
	if DevLog.path_override == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dev_attempts_%d.log" % OS.get_process_id()))
	if reported > 0:
		print("english-only mode (tests/i18n_mode.gd): %d non-English findings reported, not failed" % reported)
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))


## A save file path unique to this process and suite (user://test_<suite>_<pid><tag>.cfg). A fixed name
## like user://test_save.cfg is shared by every suite and every parallel test_all run: one run's
## cleanup or write then lands in another run's save. Several tags give several files.
func throwaway_save(tag := "") -> String:
	var suite: String = (get_script() as Script).resource_path.get_file().get_basename()
	var path := "user://%s_%d%s.cfg" % [suite, OS.get_process_id(), tag]
	if path not in _temp_files:
		_temp_files.append(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return path


## A game scene (scenes/main.tscn) with `settings` assigned (level = N, random_seed = N, ...), added to the
## root and let run one physics frame. The caller frees it. Default: story level 1.
func _spawn_game(settings: Dictionary = {level = 1}) -> Node2D:
	var game: Node2D = BASE_MAIN.instantiate()
	for key: String in settings:
		game.set(key, settings[key])
	root.add_child(game)
	await physics_frame
	return game


## Waits `count` physics frames.
func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Waits `seconds` of game time (physics frames at 60 per second).
func _wait_seconds(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame


## A key press and release through the real input pipeline.
func _tap_key(code: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()


## Milliseconds a fixed GDScript workload (_busy_work) takes on an idle dev machine (Apple M3): the yardstick that
## tells how busy the machine is right now.
const IDLE_BUSY_MS := 4.75


## A fixed CPU workload of the kind the game code does (integer maths, dictionary and array writes).
func _busy_work() -> float:
	var t := Time.get_ticks_usec()
	var acc := 0
	var d := {}
	var arr := PackedInt32Array()
	arr.resize(512)
	for i in 60000:
		acc += (i * 7919) % 1013
		d[i % 512] = acc
		arr[i % 512] = acc & 255
	return (Time.get_ticks_usec() - t) / 1000.0


## The most the busy-machine correction of _check_budget may divide by. Every caller's budget is the idle time x ~1.6, so a
## code slowdown of 2x is caught whenever the probes see the machine less than 1.25x slower than idle (2 / 1.25 = 1.6) - a
## quiet machine, `test_all.sh -j 1`, a suite run alone. Under heavy parallel load (probe 1.25x and up) only a slowdown beyond
## 1.6 x the probe (capped at 2.0, so about 3.2x idle) fails, because there the probe cannot tell code from load.
const BUDGET_LOAD_CAP := 2.0


## A wall-clock budget check that survives a busy machine but still catches a real 2x slowdown. `measure` does the work
## and returns its milliseconds. Each try runs _busy_work() BEFORE and AFTER it and takes the smaller (the less preempted)
## of the two as how much slower than idle the machine is (clamped to 1 .. BUDGET_LOAD_CAP); the try's time is divided by
## that. Passes when the best of up to `tries` tries is within `budget_ms`.
func _check_budget(label: String, budget_ms: float, measure: Callable, tries := 5) -> void:
	var best := INF
	var factor := 1.0
	for i in tries:
		var before := _busy_work()
		var took := float(measure.call())
		var after := _busy_work()
		factor = clampf(minf(before, after) / IDLE_BUSY_MS, 1.0, BUDGET_LOAD_CAP)
		best = minf(best, took / factor)
		if best <= budget_ms:
			break
	_check(best <= budget_ms, "%s (best of up to %d runs, load-adjusted by <= %.1fx: %.1f ms, budget %.0f ms)" % [label, tries, BUDGET_LOAD_CAP, best, budget_ms])


## Touch events arrive in window pixels; convert from the game's 320x180 view.
func _to_window(view_pos: Vector2) -> Vector2:
	return root.get_final_transform() * view_pos


## A finger `index` goes down / up at `view_pos` (game view pixels).
func _send_touch(index: int, view_pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _to_window(view_pos)
	event.pressed = pressed
	Input.parse_input_event(event)


## Finger `index` drags to `view_pos`.
func _send_drag(index: int, view_pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _to_window(view_pos)
	Input.parse_input_event(event)
