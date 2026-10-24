extends "res://tests/suite_base.gd"

## BM-03 BOARDS & GHOSTS (Economy.BOARDS_TEST): top-5 insert / sort, day and week rollover, the weekly's seed and fixed loadout
## (MORE SLIME 3, no abilities, no pay), ghost record / replay / length cap / file round trip, the split text, RELAXED posts
## nothing, the platform events, the BOARDS page, hidden in the demo, and flag off = the old daily sign.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_boards.gd

const MAIN := preload("res://scenes/main.tscn")
const BOARDS_SCENE := preload("res://scenes/boards.tscn")
var progress: Node
var events: Array = []


func _spawn(weekly: bool) -> Node2D:
	if weekly:
		progress.start_weekly()
	else:
		progress.start_daily()
	var game: Node2D = MAIN.instantiate()
	game.random_seed = progress.random_seed
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _spawn_story(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _drop(game: Node2D) -> void:
	current_scene = null
	game.free()
	await physics_frame


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	_check(Economy.BOARDS_TEST == true, "BOARDS_TEST is on in this test build")
	Economy.boards_force = 1
	_check(Economy.boards_on(), "boards on")

	# ---- the pure parts
	var board: Array[int] = []
	for ms in [40000, 30000, 50000, 35000, 45000, 20000, 60000]:
		board = Boards.inserted(board, ms, 20000)
	_check(board.size() == 5, "a board keeps 5 times")
	var times := board.map(func(e: int) -> int: return Boards.entry_ms(e))
	_check(times == [20000, 30000, 35000, 40000, 45000], "sorted fastest first, the slowest fell off (%s)" % [times])
	_check(Boards.rank_of(board, 20000, 20000) == 1 and Boards.rank_of(board, 60000, 20000) == 0, "rank 1 for the best, 0 for off the board")
	board = Boards.inserted(board, 30000, 20001)
	_check(Boards.entry_ms(board[1]) == 30000 and Boards.entry_ms(board[2]) == 30000, "a tie goes after the older time")
	# 2026-10-26 is a Monday (UTC day 20752), the 25th a Sunday
	var monday := 20752
	_check(Boards.weekday(monday) == 0 and Boards.weekday(monday - 1) == 6, "weekday: Monday = 0, Sunday = 6")
	_check(Boards.week_of(monday) == Boards.week_of(monday + 6) and Boards.week_of(monday + 7) == Boards.week_of(monday) + 1, "a week runs Monday to Sunday")
	_check(Boards.week_of(monday - 1) == Boards.week_of(monday) - 1, "Sunday night rolls into the next week on Monday")
	_check(Boards.week_start(Boards.week_of(monday)) == monday, "the week starts on its Monday")
	_check(Boards.weekly_seed(Boards.week_of(monday)) == Boards.weekly_seed(Boards.week_of(monday + 6)), "the weekly seed is the same all week")
	_check(Boards.weekly_seed(Boards.week_of(monday)) != Boards.weekly_seed(Boards.week_of(monday + 7)), "the weekly seed changes with the week")
	_check(Boards.weekly_seed(Boards.week_of(monday)) != progress.daily_seed(monday), "a weekly seed is not a daily's")
	_check(Boards.weekly_number(Boards.week_of(Economy.DAILY_EPOCH_DAY)) == 1 and Boards.weekly_number(Boards.week_of(monday)) >= 1, "WEEKLY #1 is the week of DAILY #1")
	_check(Boards.split_text(1234) == "+1.2s" and Boards.split_text(-800) == "-0.8s" and Boards.split_text(20) == "0.0s", "split text +1.2s / -0.8s / 0.0s")
	var pos := Vector2i(-24, 1500)
	_check(Boards.unpack(Boards.pack(Vector2(pos))) == pos, "a position packs and unpacks")

	# ---- posting: daily, weekly, the day rolling over, the platform events
	progress.saving_enabled = true
	progress.demo_guard = false
	progress.save_path = throwaway_save()
	_temp_files.append(progress.ghosts_path())
	var plat: Node = root.get_node("PlatformEvents")
	plat.progress_event.connect(func(id: String, value: int) -> void: events.append([id, value]))
	progress.day_override = monday
	var post: Dictionary = progress.post_board("daily", 42000, monday)
	_check(post.rank == 1 and post.best_daily and progress.board_best_daily_ms == 42000, "first daily time: rank 1 and the all-time best")
	post = progress.post_board("daily", 50000, monday)
	_check(post.rank == 2 and not post.best_daily and progress.board_best_daily_ms == 42000, "a slower time ranks 2nd, the best stays")
	post = progress.post_board("daily", 40000, monday + 1)
	_check(post.rank == 1 and progress.board_for("daily", monday).size() == 2 and progress.board_for("daily", monday + 1).size() == 1, "the next day has its own board")
	post = progress.post_board("weekly", 90000, monday + 2)
	_check(post.rank == 1 and progress.board_for("weekly", Boards.week_of(monday)).size() == 1, "a weekly board per week")
	progress.post_board("weekly", 80000, monday + 9)
	_check(progress.board_for("weekly", Boards.week_of(monday)).size() == 1 and progress.board_for("weekly", Boards.week_of(monday) + 1).size() == 1, "the next week has its own board")
	var ids := events.map(func(e: Array) -> String: return e[0])
	_check(ids.has("board_daily") and ids.has("board_weekly") and events[0][1] == 42000, "each post goes out as board_daily / board_weekly with the ms")
	for i in 40:  # pruning keeps the last KEEP_DAYS days
		progress.post_board("daily", 50000 + i, monday + 10 + i)
	_check(progress.board_daily.size() == Boards.KEEP_DAYS and not progress.board_daily.has(monday), "old days are pruned")

	# ---- the save round trip
	progress.board_daily = {}
	progress.board_weekly = {}
	progress.post_board("daily", 33000, monday)
	progress.post_board("weekly", 77000, monday)
	progress.ghost_on = false
	progress.save_progress()
	progress.board_daily = {}
	progress.board_best_daily_ms = 0
	progress.ghost_on = true
	progress.load_progress()
	_check(progress.board_for("daily", monday).size() == 1 and Boards.entry_ms(progress.board_for("daily", monday)[0]) == 33000, "boards survive a save and load")
	_check(progress.board_for("weekly", Boards.week_of(monday)).size() == 1 and not progress.ghost_on, "the weekly board and the GHOST toggle too")
	progress.ghost_on = true
	progress.load_code(progress.save_code())
	_check(progress.board_for("daily", monday).size() == 1 and progress.board_for("weekly", Boards.week_of(monday)).size() == 1 and progress.board_best_daily_ms == 33000,
		"importing a save code keeps this device's boards")

	# ---- ghosts: record, cap, file round trip
	var pts: Array[int] = []
	for i in 60:
		pts.append(Boards.pack(Vector2(10 + i * 2, 20)))
	_check(progress.record_ghost("daily", monday, 6000, pts), "a first ghost is kept")
	_check(not progress.record_ghost("daily", monday, 7000, pts), "a slower run does not replace it")
	_check(progress.record_ghost("daily", monday, 5500, pts), "a faster run replaces it")
	_check(progress.ghost_for("daily", monday + 1).is_empty(), "another day has no ghost")
	var too_long: Array[int] = []
	too_long.resize(Economy.GHOST_MAX + 1)
	_check(not progress.record_ghost("weekly", Boards.week_of(monday), 1000, too_long), "a ghost over the cap is refused")
	progress._ghosts = {}
	progress._ghosts_loaded = false
	var back: Dictionary = progress.ghost_for("daily", monday)
	_check(not back.is_empty() and back.ms == 5500 and back.pts.size() == 60 and back.pts == pts, "the ghost file round trips")
	_check(not FileAccess.file_exists(progress.ghosts_path() + ".tmp"), "the ghosts file is written atomically (no .tmp left)")
	_check(FileAccess.get_file_as_bytes(progress.ghosts_path()).size() < 1500, "60 samples are a small file (%d bytes)" % FileAccess.get_file_as_bytes(progress.ghosts_path()).size())
	_check(Boards.ghost_pos(pts, 0.0) == Vector2i(10, 20) and Boards.ghost_pos(pts, 0.05) == Vector2i(11, 20) and Boards.ghost_pos(pts, 99.0) == Vector2i(128, 20),
		"replay positions are whole pixels, the last one after the end")
	# BUG4-01: 20 story ghosts of 1,200 samples (a slow player's whole story) survive a write / read round trip, small
	progress.saving_enabled = true
	var long_pts: Array[int] = []
	for i in 1200:
		long_pts.append(Boards.pack(Vector2(40 + (i * 7) % 600 + (300 if i == 600 else 0), 30 + (i * 3) % 400)))
	var all_ok := true
	for lv in range(1, 11):
		all_ok = progress.record_ghost(Boards.story_kind(lv, false), 1, 90000 + lv, long_pts) and all_ok
		all_ok = progress.record_ghost(Boards.story_kind(lv, true), 1, 90000 + lv, long_pts) and all_ok
	_check(all_ok, "all 20 story ghosts are kept")
	var big_size := FileAccess.get_file_as_bytes(progress.ghosts_path()).size()
	_check(big_size < 120 * 1024, "20 ghosts of 1,200 samples are well under the cap (%d bytes)" % big_size)
	progress._ghosts = {}
	progress._ghosts_loaded = false
	var survived := 0
	for lv in range(1, 11):
		for h in [false, true]:
			if progress.ghost_for(Boards.story_kind(lv, h), 1).get("pts", []) == long_pts:
				survived += 1
	_check(survived == 20, "20 ghosts of 1,200 samples survive the round trip (%d)" % survived)
	# over the cap: the oldest-touched kind goes, the one just recorded stays
	var fat := {}
	for k in ["story_1", "story_2", "story_3"]:
		fat[k] = {key = 1, ms = 1000, pts = long_pts}
	var tiny := Boards.write_ghosts(progress.ghosts_path(), fat, "story_3")
	_check(tiny and fat.size() == 3, "a file under the cap drops nothing")
	progress.saving_enabled = false

	progress.saving_enabled = false

	# ---- the weekly maze: seed, fixed loadout, no abilities, no pay
	progress.day_override = monday
	Economy.abilities_force = 1
	progress.upgrades["slime"] = 6
	progress.upgrades["speed"] = 5
	progress.upgrades["brightness"] = 5
	progress.hard_mode = true
	var game: Node2D = await _spawn(true)
	_check(game.is_weekly() and progress.random_weekly and not progress.random_daily, "the weekly run is flagged")
	_check(not game.hard_mode, "the weekly forces normal rules even with hard mode on")
	progress.hard_mode = false
	_check(game.random_seed == Boards.weekly_seed(Boards.week_of(monday)), "its seed is the week's")
	_check(game.seed_level == Economy.WEEKLY_SLIME, "its maze is MORE SLIME 3 sized")
	_check(is_equal_approx(game._applied_slime_factor(), Upgrades.slime_factor(Economy.WEEKLY_SLIME)), "its meter is the fixed loadout, not the player's MORE SLIME 6")
	_check(is_equal_approx(game.light_reach, Upgrades.light_reach(Economy.WEEKLY_BRIGHTNESS)) and game.light_reach != Upgrades.light_reach(5),
		"its light is the fixed BRIGHTNESS %d, not the player's 5" % Economy.WEEKLY_BRIGHTNESS)
	_check(is_equal_approx(game.slime.max_speed, 72.0 * Upgrades.speed_factor(Economy.WEEKLY_SPEED)),
		"its speed is the fixed SPEED %d, not the player's 5" % Economy.WEEKLY_SPEED)
	_check(game.abilities == null, "no abilities in the weekly")
	_check(game.payout().tickets == 0 and game.no_credit(), "it pays nothing")
	_check(game.ghost != null and game.ghost.kind == "weekly", "a weekly run records")
	_check(game.hud.level_label.text.begins_with("WEEKLY #"), "the HUD names it (%s)" % game.hud.level_label.text)
	# record a short run, then win it
	var wins_before: int = progress.randoms_won
	game.slime.position += Vector2(24, 0)
	await _wait_seconds(0.5)
	_check(game.ghost.rec.size() >= 4, "samples are recorded at 10 per second (%d in 0.5 s)" % game.ghost.rec.size())
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(progress.board_for("weekly", Boards.week_of(monday)).size() == 2, "the weekly win posted a board time")
	_check(progress.randoms_won == wins_before, "a weekly win counts toward nothing")
	_check(game.daily_share.begins_with("Dry Trying WEEKLY #"), "the weekly result has a share line (%s)" % game.daily_share)
	_check(not progress.ghost_for("weekly", Boards.week_of(monday)).is_empty(), "the winning run became the weekly ghost")
	_check(game.daily_share.contains(" BOARD #"), "the weekly share line carries the local place (%s)" % game.daily_share)
	game.copy_daily_share()
	_check("Dry Trying WEEKLY" in game.hud.message.text, "COPY shows the share line on the result (%s)" % game.hud.message.text)
	await _wait_seconds(4.0)
	_check("CHALICE" in game.hud.message.text, "the result text comes back after the share line")
	var labels: Array = game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)
	_check(labels == ["COPY", "REPLAY", "BOARDS", "HUB"], "the weekly result row carries COPY / REPLAY / BOARDS / HUB (%s)" % [labels])
	await _drop(game)

	# ---- a daily race against that kind of ghost; the split; RELAXED posts nothing
	progress.random_weekly = false
	progress.upgrades.erase("slime")
	progress.record_ghost("daily", monday, 20000, pts)
	game = await _spawn(false)
	_check(not game.is_weekly() and game.ghost != null and game.ghost.kind == "daily" and game.ghost.sprite != null, "a daily with a ghost shows it")
	_check(is_equal_approx(game.ghost.sprite.modulate.a, 0.5) and game.ghost.sprite.get_parent() == game.slime.get_parent(), "one translucent sprite beside the slime")
	await _wait_seconds(0.3)
	_check(game.ghost.sprite.position == Vector2(game.ghost.sprite.position.round()), "the ghost sits on whole pixels")
	var before: int = progress.board_for("daily", monday).size()
	game.relaxed_run = true
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(progress.board_for("daily", monday).size() == before, "a RELAXED daily posts no board time")
	await _drop(game)
	progress.relaxed = false
	game = await _spawn(false)
	game.run_time = 24.0  # slower than the 20.000 s ghost
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(game.finished, "the daily win ran")
	_check(game.daily_share.contains("vs ghost +"), "the daily share line carries the split (%s)" % game.daily_share)
	_check(progress.board_for("daily", monday).size() == min(before + 1, 5), "a normal daily posts")
	await _drop(game)
	progress.ghost_on = false
	game = await _spawn(false)
	_check(game.ghost != null and game.ghost.sprite == null, "GHOST off: it records but shows no ghost")
	await _drop(game)
	progress.ghost_on = true

	# ---- IMP3-06: a story level's best clear is a ghost per level and mode (a throwaway file, never the real one)
	progress.start_story(1)
	progress.random_daily = false
	progress.random_weekly = false
	progress.saving_enabled = true
	progress.demo_guard = false
	progress._ghosts = {}
	progress._ghosts_loaded = true
	_check(not progress.ghosts_path().begins_with("user://ghosts.cfg"), "the story ghost test writes a throwaway file")
	var story_kind := Boards.story_kind(1, false)
	_check(story_kind == "story_1" and Boards.story_kind(10, true) == "hard_10" and Boards.valid_kind("hard_10") and not Boards.valid_kind("story_11") and not Boards.valid_kind("story_01"),
		"story ghost kinds are story_N / hard_N for the 10 levels")
	game = await _spawn_story(1)
	_check(game.ghost != null and game.ghost.kind == story_kind and game.ghost.key == 1 and game.ghost.sprite == null, "a story level records (no ghost yet)")
	game.slime.position += Vector2(24, 0)
	await _wait_seconds(0.5)
	game.run_time = 30.0
	game._on_goal_body_entered(game.slime)
	await physics_frame
	var story_ghost: Dictionary = progress.ghost_for(story_kind, 1)
	_check(not story_ghost.is_empty() and story_ghost.ms == 30000, "the first clear becomes the level's ghost")
	_check(progress.ghost_for(Boards.story_kind(1, true), 1).is_empty(), "the hard ghost of that level is separate")
	await _drop(game)
	game = await _spawn_story(1)
	_check(game.ghost.sprite != null and game.ghost.best.ms == 30000, "the next attempt races the ghost")
	game.run_time = 35.0
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(progress.ghost_for(story_kind, 1).ms == 30000, "a slower clear keeps the ghost")
	_check("+5.0s" in game.hud.message.text and "VS GHOST" in game.hud.message.text, "the story result shows the split VS GHOST +5.0s (%s)" % game.hud.message.text)
	await _drop(game)
	game = await _spawn_story(1)
	game.relaxed_run = true
	game.run_time = 10.0
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(progress.ghost_for(story_kind, 1).ms == 30000, "a RELAXED clear records nothing")
	await _drop(game)
	game = await _spawn_story(1)
	game.assisted = true
	game.run_time = 10.0
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(progress.ghost_for(story_kind, 1).ms == 30000, "an assisted clear records nothing")
	await _drop(game)
	game = await _spawn_story(1)
	game.run_time = 25.0
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check(progress.ghost_for(story_kind, 1).ms == 25000, "a faster clear replaces the ghost")
	await _drop(game)
	progress._ghosts = {}
	progress._ghosts_loaded = false
	_check(progress.ghost_for(story_kind, 1).ms == 25000, "the story ghost round trips through the file")
	var big := {}
	var pts_big: Array[int] = []
	for i in 3000:
		pts_big.append(Boards.pack(Vector2(i * 7 % 900, i * 13 % 900)))
	for l in range(1, 11):
		big[Boards.story_kind(l, false)] = {key = l, ms = 1000, pts = pts_big.duplicate()}
		big[Boards.story_kind(l, true)] = {key = l, ms = 1000, pts = pts_big.duplicate()}
	big["daily"] = {key = 5, ms = 1000, pts = pts_big.duplicate()}
	Boards.write_ghosts(progress.ghosts_path(), big)
	_check(FileAccess.get_file_as_bytes(progress.ghosts_path()).size() <= Boards.MAX_FILE_BYTES + 64 and big.has("daily") and Boards.read_ghosts(progress.ghosts_path()).has("daily"),
		"20 maximal story ghosts are trimmed to fit the readable size (%d bytes)" % FileAccess.get_file_as_bytes(progress.ghosts_path()).size())
	progress._ghosts = {}
	progress._ghosts_loaded = true
	progress.saving_enabled = false

	# ---- the BOARDS page
	var page: Control = BOARDS_SCENE.instantiate()
	root.add_child(page)
	await process_frame
	_check(page.rows.size() == 2 * Economy.BOARD_TOP, "the page lists 5 + 5 places")
	_check(page.daily_button != null and page.weekly_button != null and page.ghost_button != null and page.back_button != null, "PLAY DAILY / PLAY WEEKLY / GHOST / BACK are buttons (touch + pad)")
	_check(page.ghost_button.text == "GHOST ON", "GHOST ON")
	page.ghost_button.pressed.emit()
	_check(not progress.ghost_on and page.ghost_button.text == "GHOST OFF", "the toggle turns the ghost off")
	progress.ghost_on = true
	_check(page.rows[0].text.begins_with("1  "), "the first place shows (%s)" % page.rows[0].text)
	for b: Button in [page.daily_button, page.weekly_button, page.ghost_button, page.back_button]:
		_check(b.position.x >= 0 and b.position.x + b.size.x <= 320 and b.position.y + b.size.y <= 180, "%s fits the screen" % b.text)
	page.free()
	await process_frame
	# IMP3-03: nothing kept yet: a hint line, only the first empty place of each column, the weekly's days left in its header
	var saved_daily: Dictionary = progress.board_daily
	var saved_weekly: Dictionary = progress.board_weekly
	progress.board_daily = {}
	progress.board_weekly = {}
	var empty: Control = BOARDS_SCENE.instantiate()
	root.add_child(empty)
	await process_frame
	var shown := 0
	for r: Label in empty.rows:
		shown += 1 if r.visible else 0
	_check(empty.empty_note != null and shown == 2, "the empty page shows a hint and one place per column (%d)" % shown)
	empty.free()
	progress.board_daily = saved_daily
	progress.board_weekly = saved_weekly
	var full: Control = BOARDS_SCENE.instantiate()
	root.add_child(full)
	await process_frame
	_check(full.empty_note == null, "no hint once a time is kept")
	full.free()
	await process_frame

	# ---- demo and flag off
	Economy.boards_force = 0
	_check(not Economy.boards_on() and GhostRacer.create(null) == null, "flag off: no boards")
	Economy.boards_force = 1
	Platform.demo_override = 1
	_check(not Economy.boards_on(), "hidden in the demo")
	Platform.demo_override = 0
	_result()
	quit(0 if failures == 0 else 1)
