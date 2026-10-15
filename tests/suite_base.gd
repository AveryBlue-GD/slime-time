extends SceneTree

## Shared base for the tests/test_*.gd suites (`extends "res://tests/suite_base.gd"`). It holds what every
## suite used to copy: the `failures` counter and `_check`, `_result` (prints the `RESULT:` line that
## tools/test_all.sh looks for and removes the suite's throwaway files), `throwaway_save` (a save file name
## that is unique per process, so suites can run in parallel), and the small spawn / wait / key helpers.
## Named suite_base.gd (not test_*.gd) so tools/test_all.sh does not run it as a suite.

const BASE_MAIN := preload("res://scenes/main.tscn")

var failures := 0
## Throwaway files this run made through throwaway_save(); _result() deletes them.
var _temp_files: Array[String] = []


## Prints "  ok   label" or "  FAIL label" and counts failures.
func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1


## Prints the RESULT line, deletes the throwaway files. The suite then calls quit(...) itself.
func _result() -> void:
	for path in _temp_files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
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


## A wall-clock budget check that survives a busy machine. `measure` does the work and returns its milliseconds;
## up to `tries` times it is run right after _busy_work(), and a run passes when its time, divided by how much slower
## than idle the machine just was (never below 1), is within `budget_ms`. A real slowdown of the code under test on an
## idle machine still fails; load from other test jobs (a parallel test_all.sh, even two of them) does not.
func _check_budget(label: String, budget_ms: float, measure: Callable, tries := 5) -> void:
	var best := INF
	for i in tries:
		var slowdown := maxf(1.0, _busy_work() / IDLE_BUSY_MS)
		best = minf(best, float(measure.call()) / slowdown)
		if best <= budget_ms:
			break
	_check(best <= budget_ms, "%s (best of up to %d runs, load-adjusted: %.1f ms, budget %.0f ms)" % [label, tries, best, budget_ms])


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
