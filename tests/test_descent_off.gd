extends "res://tests/suite_base.gd"

## DESCENT is cut from the randomizer for now (decision D11): ONE flag, Economy.DESCENT_ENABLED = false. With it off the
## hub's randomizer portal opens RANDOM MAZE / DAILY MAZE only (IMP-06; no DESCENT button), a saved [descent_run] never prompts and is neither
## resumed, banked nor dropped (the save file is byte-identical through a load + save), no run can start, the ABYSS trail
## is hidden from the wardrobe unless owned (owners keep and can wear it), and flipping the flag back on (Economy.descent_force)
## restores all of it. The Descent suites force the flag on; abilities still work in randomizer mazes.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_descent_off.gd

var progress: Node
var save_file := ""


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	save_file = throwaway_save()
	_check(Economy.descent_force == -1 and not Economy.DESCENT_ENABLED and not Economy.descent_on(), "shipped with Descent off")
	_save_survives()
	await _hub()
	await _abyss()
	progress.reset_progress()
	_result()
	quit(1 if failures else 0)


func _text() -> String:
	return FileAccess.get_file_as_bytes(save_file).get_string_from_utf8()


func _relaunch() -> void:
	progress.descent_run = {}
	progress.mode = progress.MODE_STORY
	progress.descent_resume = {}
	progress.load_progress(save_file)


func _state_with_saved_run() -> void:
	Economy.descent_force = 1
	progress.save_path = save_file
	progress.saving_enabled = true
	progress.reset_progress()
	progress.dev_tools = false
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.day_override = 20000
	progress.tutorial_seen = 3
	progress.start_descent(4242)
	progress.clear_descent_floor(60.0, 30.0)
	progress.descend(progress.descent_offers()[0])
	progress.descent_best_floor = 7
	progress.save_progress()
	progress.descent_run = {}
	progress.mode = progress.MODE_STORY
	Economy.descent_force = -1


func _save_survives() -> void:
	_state_with_saved_run()
	var before := _text()
	_check(before.contains("[descent_run]") and before.contains("[descent]"), "setup: the save holds a Descent run and stats")
	_relaunch()
	_check(not progress.descent_resume.is_empty() and not progress.descent_resume_pending(), "off: the run is held but never pending")
	_check(not progress.resume_descent() and progress.quit_saved_descent().is_empty(), "off: it can't be resumed or banked")
	progress.start_descent(99)
	_check(progress.mode == progress.MODE_STORY and not progress.descent_active(), "off: no run can start")
	_check(not progress.descent_resume.is_empty() and progress.descent_best_floor == 7, "off: run and stats untouched in memory")
	_check(progress.save_progress() and _text() == before, "off: load + save leaves the file byte-identical")
	Economy.descent_force = 1
	_check(progress.descent_resume_pending() and progress.resume_descent(), "back on: the saved run resumes")
	Economy.descent_force = -1


func _hub() -> void:
	_state_with_saved_run()
	var before := _text()
	_relaunch()
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 3:
		await process_frame
	_check(not hub.resume_menu.visible and not hub.slime.frozen, "hub: no resume prompt on arrival")
	hub._update_near()
	hub._use(hub._station("random"))
	# IMP2-06: with Descent off the portal has no menu: one press starts a RANDOM MAZE at once; DAILY MAZE has its own sign
	_check(not hub.portal_menu.visible and progress.mode == progress.MODE_RANDOM and not progress.random_daily,
		"the portal starts a random maze at once, no menu (Descent off)")
	await _wait_scene()
	var first_scene := current_scene
	current_scene = null
	if is_instance_valid(first_scene):
		first_scene.free()
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 3:
		await process_frame
	var sign: Dictionary = hub.extras[0] if not hub.extras.is_empty() else {}
	_check(not sign.is_empty() and sign.id == "daily", "the hub has the DAILY MAZE sign beside the portal")
	hub._use(sign)
	_check(progress.random_daily and progress.mode == progress.MODE_RANDOM, "DAILY MAZE is reachable with Descent off")
	await _wait_scene()
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn" and progress.random_daily, "...and starts today's daily")
	var daily_scene := current_scene
	current_scene = null
	if is_instance_valid(daily_scene):
		daily_scene.free()
	var hub1: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub1)
	current_scene = hub1
	for i in 3:
		await process_frame
	hub1._update_near()
	hub1._use(hub1._station("random"))
	_check(not hub1.portal_menu.visible and progress.mode == progress.MODE_RANDOM and not progress.random_daily, "the portal starts a random maze")
	hub = hub1
	await _wait_scene()
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn" and current_scene.is_random() and not current_scene.descent, "...and it is a random maze")
	var cs := current_scene
	_check(Abilities.allowed_in(cs), "abilities are still allowed in it")
	current_scene = null
	if is_instance_valid(cs):
		cs.free()
	progress.save_progress()
	_check(_text().contains("[descent_run]") and _text().contains("best_floor=7"), "the saved run and stats are still in the file after a maze")
	# With the flag on, the portal asks again.
	Economy.descent_force = 1
	_relaunch()
	var hub2: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub2)
	current_scene = hub2
	for i in 3:
		await process_frame
	_check(hub2.resume_menu.visible, "on: the resume prompt returns")
	current_scene = null
	hub2.free()
	Economy.descent_force = -1


func _wait_scene() -> void:
	for i in 120:
		await process_frame
		if not root.get_node("Transition").busy:
			break


func _abyss() -> void:
	progress.reset_progress()
	progress.saving_enabled = false
	progress.cosmetics_owned.erase("abyss")
	_check(not progress.cosmetic_visible("abyss") and progress.cosmetic_visible("ink"), "ABYSS hidden when not owned, others shown")
	var screen: Node = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(not screen.trail_tiles.has("abyss") and screen.trail_tiles.has("starry"), "wardrobe: no ABYSS tile unless owned")
	screen.free()
	progress.cosmetics_owned.append("abyss")
	screen = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(progress.cosmetic_visible("abyss") and screen.trail_tiles.has("abyss"), "an owner keeps the tile")
	progress.trail_style = "abyss"
	_check(progress.trail_style == "abyss" and progress.owns_cosmetic("abyss"), "...and can wear it")
	screen.free()
	progress.cosmetics_owned.erase("abyss")
	progress.trail_style = Cosmetics.DEFAULT_TRAIL
	Economy.descent_force = 1
	_check(progress.cosmetic_visible("abyss"), "flag on: ABYSS shown again")
	Economy.descent_force = -1
