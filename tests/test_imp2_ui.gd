extends "res://tests/suite_base.gd"

## IMP2-02 / IMP2-06: the achievements page (counts, band, page arrows), the settings route to it, merged and held
## notices, no SEED line on a daily result; the one-press portal, the DAILY MAZE sign, the station names and "!" badges,
## and a tap's glide to a station.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_imp2_ui.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.levels_cleared = Levels.COUNT  # the portal is open
	await _achievements_page()
	await _settings_route()
	await _notices()
	await _hub()
	_result()
	quit(1 if failures > 0 else 0)


func _achievements_page() -> void:
	progress.randoms_won = 23
	var pair: Vector2i = Achievements.progress(progress, "rand_50")
	_check(pair == Vector2i(23, 50), "rand_50 reads 23/50 (%s)" % str(pair))
	_check(Achievements.progress(progress, "rand_10") == Vector2i(10, 10), "...a met goal caps at its goal")
	_check(Achievements.progress(progress, "clear_1") == Vector2i.ZERO, "...a goal without a number has none")
	var page: Control = load("res://scenes/achievements.tscn").instantiate()
	root.add_child(page)
	await process_frame
	var counts: Array[String] = []
	for turn_i in page.page_count():  # (the paging changed with IMP2-03: look on every page)
		for row in page.rows:
			for label in row.find_children("*", "Label", true, false):
				if "/" in label.text:
					counts.append(label.text)
		page._turn(1)
	_check("23/50" in counts, "the page shows 23/50 on the 50-maze goal (%s)" % str(counts))
	_check(page.prev_arrow != null and page.next_arrow != null and page.next_arrow.visible, "the page has < > arrows")
	var first_goal: String = page.rows[0].get_meta("id")
	page.next_arrow.pressed.emit()
	_check(page.page == 1 and page.rows[0].get_meta("id") != first_goal, "the > arrow turns the page")
	page.prev_arrow.pressed.emit()
	_check(page.page == 0, "the < arrow turns it back")
	var band := false
	for child in page.get_children():
		band = band or (child is ColorRect and child.color.a > 0.3 and child.color.v < 0.1)
	_check(band, "a dark band sits behind the list")
	page.free()


func _settings_route() -> void:
	var page: Control = load("res://scenes/controls.tscn").instantiate()
	root.add_child(page)
	await process_frame
	var safe := UIKit.safe_rect()
	_check(page.achievements_button != null and safe.encloses(Rect2(page.achievements_button.position, page.achievements_button.size)),
		"SETTINGS has an ACHIEVEMENTS button inside the safe area (a touch route)")
	page.free()
	# BACK returns to where the page was opened from (SETTINGS), once; the hub otherwise.
	var shot_script: GDScript = load("res://scripts/ui/achievements_screen.gd")
	shot_script.back_scene = "res://scenes/controls.tscn"
	var ach: Control = load("res://scenes/achievements.tscn").instantiate()
	root.add_child(ach)
	await process_frame
	_check(ach._back_to == "res://scenes/controls.tscn" and shot_script.back_scene == "", "the achievements page goes back to SETTINGS when opened from it")
	ach.free()
	ach = load("res://scenes/achievements.tscn").instantiate()
	root.add_child(ach)
	await process_frame
	_check(ach._back_to == UIKit.HUB_SCENE, "...and to the hub when opened from the hub menu")
	ach.free()


func _notices() -> void:
	var transition: Node = root.get_node("Transition")
	progress.notices.clear()
	progress.notice_groups.clear()
	progress.notify_once("t1", "ACHIEVEMENT: A", "ach")
	progress.notify_once("t2", "ACHIEVEMENT: B", "ach")
	progress.notify_once("t3", "ACHIEVEMENT: C", "ach")
	transition._pump_notice(0.0)
	var box: Control = transition._notice
	_check(box != null and progress.notices.is_empty(), "three queued achievements become one notice")
	var label: Label = box.find_children("*", "Label", true, false)[0]
	_check(label.text == "+3 ACHIEVEMENTS", "...worded +3 ACHIEVEMENTS (%s)" % label.text)
	var safe := UIKit.safe_rect()
	_check(box.position.y <= safe.position.y + 8.0 and absf(box.position.x + box.size.x / 2.0 - (safe.position.x + safe.size.x / 2.0)) <= 1.0,
		"...at the top centre of the safe area")
	transition._pump_notice(2.6)
	_check(transition._notice == null, "...gone after 2.5 s")
	# Held while a run is in progress, errors not.
	progress.start_random()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.finished = false
	progress.notify_once("t4", "ACHIEVEMENT: D", "ach")
	progress.notify_once("t5", "SAVE FAILED", "")
	transition._pump_notice(0.0)
	var shown: Label = transition._notice.find_children("*", "Label", true, false)[0]
	_check(shown.text == "SAVE FAILED" and progress.notices == ["ACHIEVEMENT: D"], "an error shows during a run, a new achievement waits (%s)" % shown.text)
	transition._pump_notice(3.0)
	transition._pump_notice(0.0)
	_check(transition._notice == null and progress.notices.size() == 1, "...and keeps waiting")
	game.finished = true
	transition._pump_notice(0.0)
	_check(transition._notice != null and progress.notices.is_empty(), "...shown once the run is over")
	transition._pump_notice(3.0)
	current_scene = null
	game.free()


func _hub() -> void:
	progress.tickets = 0
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(3)
	_check(hub.extras.size() == 1 and hub.extras[0].id == "daily" and hub.stations.size() == 9, "the DAILY MAZE sign stands beside the ring (9 stations + 1 sign)")
	var sign: Dictionary = hub.extras[0]
	var portal: Dictionary = hub._station("random")
	var gap: float = sign.sprite.position.distance_to(portal.sprite.position)
	_check(gap > 18.0 and gap < 40.0, "...next to the portal (%.0f px)" % gap)
	_check(hub.badges.has("daily") and hub.badges["daily"].visible and hub.badges["daily"].text == "!", "a gold ! on the sign until today's daily is won")
	# IMP3-03: a live streak shows its deadline; the weekly alternates in while unplayed; the press starts what the prompt names.
	progress.daily_day = progress.utc_day() - 1
	progress.daily_best_ms = 40000
	progress.daily_streak = 4
	hub.near = sign
	hub.sign_weekly = false
	hub._show_prompt()
	_check(hub.prompt_key.text.begins_with("STREAK 4  ENDS IN ") and (hub.prompt_key.text.ends_with("H") or hub.prompt_key.text.ends_with("M")), "the sign prompt reads the streak and its deadline (%s)" % hub.prompt_key.text)
	Economy.boards_force = 1
	_check(hub.weekly_unplayed(), "the weekly is unplayed")
	hub._sign_t = hub.SIGN_ALT_TIME
	hub._process(0.0)
	_check(hub.sign_weekly and hub.prompt_name.text == "WEEKLY MAZE" and hub.prompt_key.text.ends_with("NEW"), "...after a few seconds the prompt offers WEEKLY MAZE (%s %s)" % [hub.prompt_name.text, hub.prompt_key.text])
	hub._sign_t = hub.SIGN_ALT_TIME
	hub._process(0.0)
	_check(not hub.sign_weekly and hub.prompt_name.text == "DAILY MAZE", "...and back to the daily")
	Economy.boards_force = 0
	progress.daily_day = 0
	progress.daily_best_ms = 0
	progress.daily_streak = 0
	progress.record_daily(41000, progress.utc_day())
	hub._refresh_badges()
	_check(hub.badges["daily"].text.begins_with("NEW IN ") and hub.badges["daily"].text.ends_with("H"), "...NEW IN <h>H after (%s)" % hub.badges["daily"].text)
	# Names on arrival.
	_check(hub.name_layer.visible and hub.name_labels.size() == 10, "every station name shows on arrival (%d)" % hub.name_labels.size())
	var badge_seen := false
	for i in int(hub.NAMES_TIME * 60) + 30:
		await physics_frame
		for id: String in hub.badge_art:
			badge_seen = badge_seen or (hub.name_layer.visible and hub.badge_art[id].node.visible)
	_check(not badge_seen, "no ! badge shows while the names show (they come after, see test_hub_badges)")
	_check(not hub.name_layer.visible, "...and is gone after 3 s")

	# Badges: the wheel's first spin is free; the signpost has news with a new achievement.
	progress.spins = 0
	progress.hats_owned.clear()
	hub._refresh_badges()
	_check(hub.has_news("wheel"), "the wheel shows ! while a spin can be paid")
	progress.ach_known.assign(["clear_1"])
	progress.ach_seen = 0
	_check(hub.has_news("settings"), "the signpost shows ! for a new achievement")
	progress.mark_achievements_seen()
	_check(not hub.has_news("settings"), "...until the page has been opened")
	# One press at the portal.
	hub.near = portal
	hub._use(portal)
	_check(not hub.portal_menu.visible and progress.mode == progress.MODE_RANDOM and not progress.random_daily, "walking into the portal starts a random maze at once")
	hub.free()
	# (the portal's scene change is under way: let it finish and drop the maze it loads, or it frees the next hub)
	for i in 400:
		await physics_frame
		if not root.get_node("Transition").busy and current_scene != null and current_scene.name != "Hub":
			break
	if current_scene != null:
		current_scene.free()
		current_scene = null
	# A tap glides to a station.
	progress.mode = progress.MODE_STORY
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(3)
	var target: Dictionary = hub._station("coins")
	var path: Array[Vector2] = hub.path_to_prop(hub.slime.position, target)
	_check(path.size() >= 1 and path[path.size() - 1].distance_to(hub.use_spot(target)) < 1.0, "the glide path ends on the spot in front of the station")
	hub._on_tap(target.sprite.position + Vector2(0, -8))
	_check(not hub.glide_path.is_empty(), "a tap on a station starts the glide")
	var arrived := false
	for i in 600:
		await physics_frame
		if not hub.near.is_empty() and hub.near.id == "coins":
			arrived = true
			break
	_check(arrived, "...the slime glides up to the coin bag")
	# IMP2-06 fix: the glide to the DAILY sign ends inside its use gap at several room turns.
	progress.mode = progress.MODE_STORY
	var all_ok := true
	var bad := []
	for k in [0, 2, 4, 6, 8]:
		hub.turn = -k * hub.step
		hub._place_all()
		hub.turning = false
		hub.slime.position = hub.START
		await physics_frame
		hub.glide_to(hub.extras[0])
		var reached := false
		for i in 600:
			await physics_frame
			if hub.glide_path.is_empty():
				await physics_frame  # (near updates each frame)
				reached = hub.near.has("id") and hub.near.id == "daily"
				break
		if not reached:
			all_ok = false
			bad.append(k)
	_check(all_ok, "the glide to the DAILY sign ends within its use gap at every turn (failed: %s)" % [bad])
	# A tap while the slime is busy (frozen / not gliding) does nothing.
	hub.slime.frozen = true
	hub._on_tap(hub.extras[0].sprite.position + Vector2(0, -8))
	_check(hub.glide_path.is_empty(), "a tap while the slime is frozen starts nothing")
	hub.slime.frozen = false
	hub.glide_to(hub._station("wheel"))
	_check(not hub.glide_path.is_empty(), "a new glide starts")
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	hub._input(key)
	_check(hub.glide_path.is_empty(), "any key interrupts the glide")
	hub.free()
