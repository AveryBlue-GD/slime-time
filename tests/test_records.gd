extends SceneTree

## Timer + record checks: the run timer counts (and stops while paused), a first clear only sets
## the record (no celebration), a slower repeat shows the best time, a faster repeat shows the gold
## NEW RECORD! banner and saves the new time, and level select shows record times.
## Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_records.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.levels_cleared = 0
	progress.highest_unlocked = 1
	progress.best_times = {}
	progress.skin_notices_seen.assign([1, 2])

	_check(UIKit.format_time(62.34) == "1:02.3" and UIKit.format_time(5.0) == "0:05.0", "times read m:ss.s (62.34 s -> 1:02.3)")

	# --- Timer counts, and stops while paused.
	var game := await _spawn_running()
	await _frames(60)
	_check(absf(game.run_time - 1.0) < 0.05 and game.hud.time_label.text == "0:01.0", "the HUD timer counts up (%s)" % game.hud.time_label.text)
	game.pause_menu.open()
	var paused_at: float = game.run_time
	await _frames(30)
	_check(game.run_time == paused_at, "the timer stops while paused")
	game.pause_menu.resume()

	# --- First clear: sets the record quietly.
	await _win(game)
	_check(not game.hud.record_banner.visible, "first clear: no NEW RECORD banner")
	_check("TIME" in game.hud.message.text and not "BEST" in game.hud.message.text, "first clear shows the time only")
	_check(progress.best_time(1) > 0.0, "first clear saves the record (%s)" % UIKit.format_time(progress.best_time(1)))
	await _stop_running(game)

	# --- Slower repeat: shows the best, no banner, record unchanged.
	progress.best_times[1] = 0.05
	game = await _spawn_running()
	await _frames(30)
	await _win(game)
	_check(not game.hud.record_banner.visible and "BEST 0:00.0" in game.hud.message.text, "a slower clear shows your best, no banner")
	_check(progress.best_time(1) == 0.05, "a slower clear keeps the old record")
	await _stop_running(game)

	# --- Faster repeat: gold NEW RECORD! with chalices, record saved.
	progress.best_times[1] = 999.0
	game = await _spawn_running()
	await _frames(30)
	await _win(game)
	var banner: CenterContainer = game.hud.record_banner
	_check(banner.visible, "beating your record shows the NEW RECORD! banner")
	_check(game.hud._chalices.size() == 2 and game.hud.record_time_label.text == UIKit.format_time(game.run_time),
		"the banner has a chalice on each side and the new time")
	var title: Label = banner.get_child(0).get_child(1).get_child(0)
	_check(title.text == "NEW RECORD!" and title.get_theme_color("font_color") == game.hud.GOLD, "NEW RECORD! is gold")
	_check(progress.best_time(1) < 999.0, "the new record is saved (%s)" % UIKit.format_time(progress.best_time(1)))
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(absf(reloaded.best_time(1) - progress.best_time(1)) < 0.001, "records survive a restart")
	reloaded.free()
	await _stop_running(game)

	# --- Level select shows the record time.
	progress.levels_cleared = 1
	progress.highest_unlocked = 2
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var tile_text := " ".join(screen.level_buttons[0].find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	_check(UIKit.format_time(progress.best_time(1)) in tile_text, "level select shows the record (%s)" % tile_text)
	screen.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## Level 1 as the current scene, so its real end-of-level flow (saving records) runs.
func _spawn_running() -> Node2D:
	progress.start_story(1)
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _win(game: Node2D) -> void:
	game.slime.position = game.chalice.position
	await _frames(3)


## Detaches the game before its end-of-level timer reloads the scene, then frees it.
func _stop_running(game: Node2D) -> void:
	current_scene = null
	await _frames(int(game.END_DELAY * 60) + 10)
	game.free()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
