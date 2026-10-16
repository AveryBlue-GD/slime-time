extends "res://tests/suite_base.gd"

## Trail maps (Survey; the hub's MAP TABLE). Checks:
## - capture: real story runs record the tiles they revealed (kept across restarts and a save/load
##   "session"), the route walked (a last attempt until a clear; the best clear replaced only by a
##   faster one), the goal once seen; assisted, dev-mode, dev-toggled and randomizer runs and loose
##   (non-running) game nodes record nothing; hard mode has its own surveys (level + 100);
## - save: [maps] round trip, an old save without it loads unchanged, hostile data is dropped or
##   clamped, the save code with all 20 levels fully surveyed stays far under the cap (sizes are
##   printed), RESET PROGRESS clears the maps and the first-time hint;
## - seeds: --story-complete and --maps=full (child process with --unlock-all) give 20 full surveys
##   (every tile seen, the shortest route as a clear, the goal seen); --unlock-all alone gives none;
## - drawing (MapView): wall lines between cells, drawn only next to a seen cell; nothing on unseen
##   cells at any size (also with a route, coins, start and goal over unseen cells); a hairpin (U-turn)
##   route keeps a wall line between its two legs; the route is a 1 px red line whatever the skin;
##   every story and hard maze (up to 36x20 cells) fits the view at whole pixels, themed too; a foreign
##   survey draws nothing; every level (normal + hard) has a theme palette, themed maps are on;
## - select previews (MapView.preview): made-up example mazes, deterministic and distinct per level and
##   mode, unrelated to the real layout, lit in proportion to the %, a route only with a recorded
##   route, all inside the tile's box, cached (no per-frame cost); two different surveys at the same %
##   give identical tiles;
## - the MAP TABLE screen: tiles locked until surveyed, just thumbnail/name/percent (no times or route
##   labels), opening a map (name + "NN% UNCOVERED"), BACK / Esc / ui_cancel at each depth (Esc on the
##   select returns to the hub), taps, the first-time hint.
## Uses a throwaway save; the real save's md5 is checked unchanged at the end.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_maps.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()
const CHILD_FLAG := "--maps-child"

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	if CHILD_FLAG in OS.get_cmdline_user_args():
		# Child process: report the surveys this launch's flags set up.
		var full := 0
		for key: int in progress.maps:
			var level: int = key % 100
			if Survey.completeness(progress.maps[key], Levels.story_maze(level, key > 100)) == 1.0 and progress.maps[key].clear:
				full += 1
		print("MAPS_CHILD count=%d full=%d dev=%s saving=%s" % [progress.maps.size(), full, progress.dev_tools, progress.saving_enabled])
		quit()
		return
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH)
	var real_md5 := FileAccess.get_md5(real) if FileAccess.file_exists(real) else ""
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.reset_progress()
	progress.levels_cleared = 2
	progress.highest_unlocked = 3
	progress.tutorial_seen = 3

	await _test_capture()
	_test_rules()
	_test_save()
	_test_seeds()
	_test_drawing()
	await _test_screen()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched (md5 %s)" % real_md5)
	_result()
	quit(1 if failures else 0)


# ---------------------------------------------------------------- capture in real runs

func _test_capture() -> void:
	progress.maps = {}
	# A first attempt: glide part of the way (the running scene), then restart.
	var game := await _spawn_running(1)
	var path: Array[Vector2i] = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	await _walk(game, path.slice(0, 5))
	var walked: int = game.survey_moves.size()
	_check(walked >= 4, "a run records the cells it walks as moves (%d)" % walked)
	await _stop(game)
	var survey: Dictionary = progress.survey_for(1, false)
	_check(not survey.is_empty() and not survey.clear and survey.moves.size() == walked, "leaving the run records it: a last attempt (%d moves)" % survey.get("moves", []).size())
	var first_seen := _seen_count(survey)
	_check(first_seen > 10 and Survey.is_seen(survey, game_start_tile(1)), "...with the tiles it revealed (%d), the start among them" % first_seen)
	_check(Survey.route_cells(survey, Levels.story_maze(1)) == path.slice(0, walked + 1), "...and its route follows the cells walked")

	# A second attempt down a different branch (a dry-up ends it): the tiles add up.
	var maze := Levels.story_maze(1)
	var other := _other_branch(maze, path)
	game = await _spawn_running(1)
	await _walk(game, other)
	game.slime_remaining = 0.0
	await _physics_frames(3)
	_check(game.finished and not game.won, "the second attempt dries up")
	await _physics_frames(30)  # past its retry buttons' delay
	await _stop(game)
	survey = progress.survey_for(1, false)
	_check(_seen_count(survey) > first_seen, "a later attempt adds to the tiles seen (%d -> %d)" % [first_seen, _seen_count(survey)])
	_check(Survey.route_cells(survey, maze) == other, "...and its walk replaces the last-attempt route")
	_check(not survey.goal, "the goal hasn't been seen yet")

	# Across sessions: the save holds it.
	var before := Survey.pack(survey)
	progress.save_progress()
	progress.maps = {}
	progress.load_progress()
	_check(Survey.pack(progress.survey_for(1, false)) == before, "the survey survives a save and a new session")

	# A win (autopilot, shortest route): the route becomes the best clear, with its time.
	game = await _spawn_running(1)
	game.add_child(preload("res://tests/autopilot.gd").new())
	await _until(func() -> bool: return game.finished, 1800)
	var clear_time: float = game.run_time
	_check(game.won, "the autopilot clears level 1 (%.1f s)" % clear_time)
	survey = progress.survey_for(1, false)
	_check(survey.clear and survey.goal and absi(survey.best_ms - roundi(clear_time * 1000.0)) <= 1,
		"a clear becomes the best route with its time (%d ms) and the goal is marked" % survey.best_ms)
	_check(Survey.route_cells(survey, maze) == path, "...its route is the path walked, start to chalice (%d cells)" % path.size())
	await _physics_frames(60)  # past its win buttons' delay
	await _stop(game)
	var clear_pack := Survey.pack(progress.survey_for(1, false))

	# A later attempt that doesn't clear keeps the best route (adds its tiles only).
	game = await _spawn_running(1)
	await _walk(game, other.slice(0, 3))
	await _stop(game)
	survey = progress.survey_for(1, false)
	_check(survey.clear and survey.best_ms == Survey.unpack(clear_pack).best_ms and Survey.route_cells(survey, maze) == path,
		"an attempt after a clear keeps the best route")

	# Assisted, dev mode, dev toggles, randomizer and loose game nodes record nothing.
	progress.maps = {}
	progress.dry_ups[1] = progress.ASSIST_AFTER
	_check(progress.accept_assist(1), "(the slime reserve is on offer after 3 dry-ups)")
	game = await _spawn_running(1)
	_check(game.assisted, "an assisted run...")
	await _walk(game, path.slice(0, 4))
	await _stop(game)
	_check(progress.maps.is_empty(), "...records no survey")
	progress.dry_ups.erase(1)

	progress.dev_tools = true
	game = await _spawn_running(1)
	await _walk(game, path.slice(0, 4))
	await _stop(game)
	progress.dev_tools = false
	_check(progress.maps.is_empty(), "a dev-mode run records no survey")

	game = await _spawn_running(1)
	game.dev_toggled = true  # what F1 FULL BRIGHT / F2 NO DRAIN set (they exist only in dev mode)
	await _walk(game, path.slice(0, 4))
	await _stop(game)
	_check(progress.maps.is_empty(), "a dev-toggled run records no survey")

	progress.start_random()
	progress.random_seed = 5
	game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await _physics_frames(3)
	_check(game.is_random(), "a randomizer maze...")
	game.slime.position += Vector2(16, 0)
	await _physics_frames(20)
	await _stop(game)
	_check(progress.maps.is_empty(), "...records nothing (it is fresh every time)")
	progress.start_story(1)

	game = MAIN.instantiate()
	game.level = 1
	root.add_child(game)  # not the running scene: a test's or demo's loose game node
	await _physics_frames(20)
	game.free()
	_check(progress.maps.is_empty(), "a game node that isn't the running scene records nothing")

	# Hard mode: its own survey under level + 100; seeing the goal marks it without a win.
	progress.hard_mode = true
	game = await _spawn_running(2)
	var hard_path: Array[Vector2i] = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	# Halfway between the last cell before the chalice and the chalice: in sight, not in reach.
	game.slime.position = (MazeGenerator.cell_center(hard_path[-2], game.TILE) + MazeGenerator.cell_center(hard_path[-1], game.TILE)) / 2.0
	await _physics_frames(3)
	await _stop(game)
	progress.hard_mode = false
	_check(progress.maps.has(102) and not progress.maps.has(2) and progress.maps[102].goal and not progress.maps[102].clear,
		"hard mode records its own survey (level + 100); coming near the goal marks it seen")


## The level's start tile.
func game_start_tile(level: int) -> Vector2i:
	return Levels.story_maze(level).start * 2 + Vector2i.ONE


## A route from the start into a branch off the shortest path (a different way).
func _other_branch(maze: Dictionary, path: Array[Vector2i]) -> Array[Vector2i]:
	for i in path.size():
		for next in MazeGenerator.open_neighbors(maze, path[i]):
			if not next in path:
				var route: Array[Vector2i] = path.slice(0, i + 1)
				route.append(next)
				var cell := next
				for step in 3:  # a few cells on down the branch
					var ahead := MazeGenerator.open_neighbors(maze, cell).filter(func(c: Vector2i) -> bool: return not c in route)
					if ahead.is_empty():
						break
					cell = ahead[0]
					route.append(cell)
				return route
	return path


func _seen_count(survey: Dictionary) -> int:
	var n := 0
	for i in survey.w * survey.h:
		if (survey.seen[i >> 3] >> (i & 7)) & 1:
			n += 1
	return n


# ---------------------------------------------------------------- record rules

func _test_rules() -> void:
	progress.maps = {}
	var maze := Levels.story_maze(3)
	var tiles := PackedByteArray()
	tiles.resize(maze.size.x * maze.size.y)
	tiles[maze.start.y * 2 * maze.size.x + maze.start.x * 2 + maze.size.x + 1] = 1
	var path := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	var slow := Survey.moves_along(path)
	var detour := Survey.moves_along(path.slice(0, 3))
	progress.record_survey(3, false, maze, tiles, slow, true, 40.0, true)
	progress.record_survey(3, false, maze, tiles, detour, true, 45.0, true)
	_check(progress.survey_for(3, false).best_ms == 40000 and progress.survey_for(3, false).moves == slow, "a slower clear doesn't replace the best route")
	progress.record_survey(3, false, maze, tiles, detour, false, 10.0, false)
	_check(progress.survey_for(3, false).moves == slow, "...nor does an attempt that didn't clear")
	progress.record_survey(3, false, maze, tiles, detour, true, 39.5, false)
	_check(progress.survey_for(3, false).best_ms == 39500 and progress.survey_for(3, false).moves == detour, "a faster clear does")

	# A stale survey: same size, but of another layout (an update re-laid the maze; here one wall
	# moved). It no longer fits, is dropped where it's used and never blocks a new route.
	var relaid := maze.duplicate(true)
	var relaid_walls: PackedByteArray = relaid.walls
	for i in relaid_walls.size():  # open one inner wall tile between two cells (a different layout)
		var t := Vector2i(i % maze.size.x, i / maze.size.x)
		if relaid_walls[i] == 1 and t.x > 0 and t.y > 0 and t.x < maze.size.x - 1 and t.y < maze.size.y - 1 and (t.x + t.y) & 1 == 1:
			relaid_walls[i] = 0
			break
	relaid.walls = relaid_walls
	_check(relaid.size == maze.size and Survey.fingerprint(relaid) != Survey.fingerprint(maze), "a re-laid maze of the same size has another fingerprint")
	var stale := Survey.full(relaid, 1.0)  # every tile seen, a 1 s clear on the old layout
	_check(not Survey.fits(stale, maze) and Survey.route_cells(stale, maze).is_empty() and Survey.completeness(stale, maze) == 0.0,
		"a survey of another layout of the same size doesn't fit: no route, no survey %")
	progress.maps[3] = stale
	_check(progress.survey_for(3, false).is_empty() and not progress.maps.has(3), "...and is dropped when it is asked for (the level has no survey)")
	progress.maps[3] = Survey.full(relaid, 1.0)
	progress.record_survey(3, false, maze, tiles, slow, true, 40.0, true)
	var fresh: Dictionary = progress.survey_for(3, false)
	_check(fresh.fp == Survey.fingerprint(maze) and fresh.clear and fresh.best_ms == 40000 and fresh.moves == slow and _seen_count(fresh) <= 2,
		"a run over a stale survey starts afresh: its slower clear (40 s vs the stale 1 s) sets the best route, with only its own tiles (%d seen)" % _seen_count(fresh))
	_check(Survey.route_cells(fresh, maze).size() == path.size() and Survey.route_cells(fresh, maze)[-1] == maze.goal, "...and that route reaches the goal")
	progress.maps = {}


# ---------------------------------------------------------------- save

func _test_save() -> void:
	progress.reset_progress()
	progress.levels_cleared = 4
	progress.highest_unlocked = 5
	var maze := Levels.story_maze(2)
	progress.maps[2] = Survey.full(maze, 21.5)
	progress.maps[103] = Survey.blank(Levels.story_maze(3, true))
	progress.maps_hint_seen = true
	var text: String = progress._write().encode_to_text()
	var file := ConfigFile.new()
	file.parse(text)
	progress.maps = {}
	progress.maps_hint_seen = false
	progress._read(file)
	_check(progress.maps.size() == 2 and Survey.pack(progress.maps[2]) == Survey.pack(Survey.full(maze, 21.5)) and progress.maps_hint_seen,
		"[maps] round-trips through the save (surveys and the hint flag)")

	# An old save (no [maps] section) loads exactly as before.
	file.erase_section("maps")
	progress._read(file)
	var again: ConfigFile = progress._write()
	if again.has_section("maps"):
		again.erase_section("maps")
	file.set_value("meta", "version", progress.SAVE_VERSION)
	_check(progress.maps.is_empty() and not progress.maps_hint_seen and again.encode_to_text() == file.encode_to_text(),
		"an old save without [maps] loads unchanged, with no maps")

	# Hostile values: wrong types, broken base64, wrong lengths, out-of-range sizes, long strings.
	var good := Survey.pack(Survey.full(maze, 21.5))
	var raw := Marshalls.base64_to_raw(good)
	var cut := raw.slice(0, raw.size() - 1)
	var big := raw.duplicate()
	big.encode_u16(10, 60000)
	var wide := raw.duplicate()
	wide[2] = 200
	var version := raw.duplicate()
	version[0] = 9
	var weird := raw.duplicate()
	weird[1] = 255
	weird.encode_u32(4, 0xFFFFFFFF)
	weird[8] = 250
	var bad: Array = [12, 3.5, [1, 2], "", "!!!not base64!!!", "A".repeat(Survey.MAX_TEXT + 4), Marshalls.raw_to_base64(cut),
		Marshalls.raw_to_base64(big), Marshalls.raw_to_base64(wide), Marshalls.raw_to_base64(version)]
	var dropped := true
	for value: Variant in bad:
		dropped = dropped and Survey.unpack(value).is_empty()
	_check(dropped, "hostile survey values are all dropped (%d kinds)" % bad.size())
	# An old version-1 survey (no fingerprint: can't be checked against the maze) is dropped.
	var v1 := raw.slice(0, 12) + raw.slice(Survey.HEADER)
	v1[0] = 1
	_check(Survey.unpack(Marshalls.raw_to_base64(v1)).is_empty(), "an old version-1 survey (no layout fingerprint) is dropped")
	var old_file := ConfigFile.new()
	old_file.set_value("progress", "levels_cleared", 2)
	old_file.set_value("maps", "level_2", Marshalls.raw_to_base64(v1))
	progress._read(old_file)
	_check(progress.maps.is_empty() and progress.survey_for(2, false).is_empty(), "...so a save with one loads with no survey for that level")
	var foreign := raw.duplicate()
	foreign.encode_u32(12, foreign.decode_u32(12) ^ 0x5A5A5A5A)
	var foreign_survey := Survey.unpack(Marshalls.raw_to_base64(foreign))
	_check(not foreign_survey.is_empty() and not Survey.fits(foreign_survey, maze), "a well-formed survey with a wrong fingerprint loads but never fits the maze")
	var clamped := Survey.unpack(Marshalls.raw_to_base64(weird))
	_check(not clamped.is_empty() and clamped.best_ms == Survey.MAX_MS and clamped.start.x == maze.cells.x - 1 and clamped.goal,
		"odd but well-formed values are clamped (time %d, start %s)" % [clamped.get("best_ms", -1), clamped.get("start", "")])
	var hostile := ConfigFile.new()
	hostile.set_value("progress", "levels_cleared", 1)
	hostile.set_value("maps", "level_1", "garbage")
	hostile.set_value("maps", "level_2", good)
	hostile.set_value("maps", "level_11", good)  # not a story level key
	hostile.set_value("maps", "level_-5", good)
	hostile.set_value("maps", "hint_seen", "yes")
	progress._read(hostile)
	_check(progress.maps.keys() == [2] and not progress.maps_hint_seen, "a hostile [maps] section keeps only the valid story level surveys")
	# A survey from a maze of another size is ignored where it's shown (locked), not drawn.
	progress.maps[4] = Survey.full(Levels.story_maze(1), 10.0)
	_check(not Survey.fits(progress.maps[4], Levels.story_maze(4)) and Survey.route_cells(progress.maps[4], Levels.story_maze(4)).is_empty(),
		"a survey of the wrong size never fits or draws on another maze")

	# Save code: all 20 levels fully surveyed (the --story-complete state) stays far under the cap.
	progress.reset_progress()
	var plain: int = progress.save_code().length()
	progress.enable_story_complete()
	var full_code: String = progress.save_code()
	var per_level := 0
	for key: int in progress.maps:
		per_level = maxi(per_level, Survey.pack(progress.maps[key]).length())
	print("  info save code: no maps %d chars, all 20 levels fully surveyed %d chars (largest survey %d base64 chars in save.cfg)" % [plain, full_code.length(), per_level])
	var restored: ConfigFile = progress.read_code(full_code)
	_check(restored != null and full_code.length() < progress.MAX_SAVE_CODE_LENGTH / 8,
		"with all 20 levels fully surveyed the save code is %d chars (cap %d)" % [full_code.length(), progress.MAX_SAVE_CODE_LENGTH])
	var packs := {}
	for key: int in progress.maps:
		packs[key] = Survey.pack(progress.maps[key])
	progress.maps = {}
	progress.saving_enabled = true
	progress.load_code(full_code)
	var same: bool = progress.maps.size() == 20
	for key: int in packs:
		same = same and progress.maps.has(key) and Survey.pack(progress.maps[key]) == packs[key]
	_check(same, "the save code carries every survey")
	# Worst case: random seen-bits and maximum-length routes on all 20 levels (no real run gets there).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for key: int in progress.maps:
		var s: Dictionary = progress.maps[key]
		var seen: PackedByteArray = s.seen
		for i in seen.size():
			seen[i] = rng.randi() & 255
		s.seen = seen
		var moves := PackedByteArray()
		moves.resize(Survey.MAX_MOVES)
		for i in moves.size():
			moves[i] = rng.randi() & 3
		s.moves = moves
	var worst: String = progress.save_code()
	print("  info save code worst case (random bits, %d-move routes on all 20): %d chars" % [Survey.MAX_MOVES, worst.length()])
	_check(progress.read_code(worst) != null and worst.length() < progress.MAX_SAVE_CODE_LENGTH / 2, "even the worst case stays under half the cap (%d)" % worst.length())

	# RESET PROGRESS clears the maps and the hint.
	progress.maps_hint_seen = true
	progress.reset_progress()
	_check(progress.maps.is_empty() and not progress.maps_hint_seen, "RESET PROGRESS clears the maps and the first-time hint")
	var reread := ConfigFile.new()
	reread.load(test_save)
	_check(not reread.has_section("maps"), "...and the saved file has no [maps] after it")


# ---------------------------------------------------------------- seeds

func _test_seeds() -> void:
	progress.enable_story_complete()
	var ok: bool = progress.maps.size() == 20
	for level in range(1, Levels.COUNT + 1):
		for hard in [false, true]:
			var s: Dictionary = progress.survey_for(level, hard)
			var maze := Levels.story_maze(level, hard)
			ok = ok and Survey.completeness(s, maze) == 1.0 and s.clear and s.goal \
				and Survey.route_cells(s, maze) == MazeGenerator.shortest_path(maze, maze.start, maze.goal) \
				and s.best_ms == roundi(progress.best_times[progress.survey_key(level, hard)] * 1000.0)
	_check(ok and progress.coins_earned() == Levels.total_coins(), "--story-complete: 20 full surveys (all seen, shortest route as the clear in the record time, goal), every coin found")
	progress.enable_dev_mode()
	_check(progress.maps.is_empty(), "dev mode (--unlock-all) starts with no surveys")
	progress.reset_progress()
	progress.saving_enabled = true
	for flags: Array in [["--unlock-all", "--maps=full"], ["--unlock-all"]]:
		var out: Array = []
		OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--headless", "-s", "res://tests/test_maps.gd", "--", CHILD_FLAG] + flags, out, true)
		var line := ""
		for chunk: String in out:
			for l in chunk.split("\n"):
				if l.begins_with("MAPS_CHILD"):
					line = l
		var want := "count=20 full=20" if "--maps=full" in flags else "count=0 full=0"
		_check(want in line and "dev=true" in line and "saving=false" in line, "a %s launch: %s" % [" ".join(flags), line])


# ---------------------------------------------------------------- the MAP TABLE screen

func _test_screen() -> void:
	progress.reset_progress()
	progress.dev_tools = false  # a player (dev mode would own every map paper: a PAPER button in the view)
	progress.saving_enabled = false
	progress.levels_cleared = 3
	progress.highest_unlocked = 4
	var maze := Levels.story_maze(2)
	var partial := Survey.blank(maze)
	var tiles := PackedByteArray()
	tiles.resize(maze.size.x * maze.size.y)
	for x in 7:  # the first few tiles of the start's row only
		tiles[(maze.start.y * 2 + 1) * maze.size.x + x] = 1
	Survey.merge_seen(partial, tiles)
	progress.maps[2] = partial
	progress.maps[3] = Survey.full(Levels.story_maze(3), 23.5)
	progress.maps[103] = Survey.full(Levels.story_maze(3, true), 30.0)
	progress.maps_hint_seen = false
	progress.hard_mode = false

	# Open from the hub.
	var hub_script: GDScript = load("res://scripts/hub.gd")
	hub_script.return_to = "maps"
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(3)
	_check(hub.near.get("id", "") == "maps" and hub.prompt_name.text == "MAP TABLE", "standing at the map table, the prompt says MAP TABLE")
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	var screen: Control = await _until_scene("res://scenes/maps.tscn")
	_check(screen != null, "F at the map table opens the MAP TABLE screen")
	if screen == null:
		return
	await _physics_frames(2)
	_check(screen.hint_label.text == screen.hint_text() and progress.maps_hint_seen, "the first opening shows the hint line")
	_check(screen.tiles.size() == 10 and screen.tiles[0].disabled and not screen.tiles[1].disabled and not screen.tiles[2].disabled and screen.tiles[3].disabled,
		"tiles: unsurveyed levels are locked (1, 4), surveyed ones open (2, 3)")
	_check(screen.tiles[2].get_meta("percent") == 100 and screen.tiles[1].get_meta("percent") < 30, "...with their survey %% (%d, %d)" % [screen.tiles[1].get_meta("percent"), screen.tiles[2].get_meta("percent")])
	var texts := _texts(screen.tiles[2])
	_check(texts == (["SANDSTONE SANCTUM", "100%"] as Array[String]), "...each with just its name and %% uncovered (%s)" % ", ".join(texts))
	var texts2 := _texts(screen.tiles[1])
	_check(texts2.size() == 2 and texts2[0] == "MOSSY MINES" and texts2[1].ends_with("%") and not "LAST TRY" in texts2,
		"...also without a clear: no LAST TRY or other labels (%s)" % ", ".join(texts2))
	_check(_texts(screen.tiles[0]) == (["DARK DUNGEON", "0%"] as Array[String]), "...and a locked tile: its name and 0%% (%s)" % ", ".join(_texts(screen.tiles[0])))
	_check(screen.get_viewport().gui_get_focus_owner() == screen.tiles[1] or screen.get_viewport().gui_get_focus_owner() == screen.tiles[2],
		"focus starts on a surveyed tile")

	# Keyboard: down to the next tile, Enter opens it; Esc closes it; ui_cancel too.
	screen.tiles[1].grab_focus()
	await _action("ui_down")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.tiles[2], "arrow keys move between tiles (2 -> 3)")
	await _action("ui_accept")
	_check(screen.viewing and screen.viewed_level == 3 and screen.view_root.visible and screen.view_map.texture != null,
		"Enter opens that level's map")
	_check(screen.view_title.text == "SANDSTONE SANCTUM" and screen.view_line.text == "100% UNCOVERED",
		"...titled with its name, one line with the %% uncovered, no time (%s / %s)" % [screen.view_title.text, screen.view_line.text])
	# Tab / Shift+Tab (ui_focus_next / prev) and the arrows keep focus on the view's BACK; the hidden
	# select (tiles, HARD, its BACK) can't be reached, so Enter never acts on it.
	var escaped := ""
	for act in ["ui_focus_next", "ui_focus_next", "ui_focus_prev", "ui_down", "ui_right", "ui_focus_next"]:
		await _action(act)
		var f := screen.get_viewport().gui_get_focus_owner()
		if f != screen.view_back and escaped == "":
			escaped = "%s -> %s" % [act, f]
	await _action("ui_accept")  # BACK: closes the view
	_check(escaped == "" and not screen.viewing and screen.hard == false and current_scene == screen,
		"in the map view Tab / Shift+Tab / arrows keep focus on BACK (%s); Enter then just closes the view" % ("ok" if escaped == "" else escaped))
	_check(screen.get_viewport().gui_get_focus_owner() == screen.tiles[2] and screen.tiles[2].focus_mode != Control.FOCUS_NONE and screen.hard_box.focus_mode != Control.FOCUS_NONE,
		"...and closing it gives the select its focus back (tile 3 focused, tiles and HARD focusable again)")
	await _action("ui_accept")
	_check(screen.viewing and screen.viewed_level == 3, "(reopened level 3)")
	var map_rect := Rect2(screen.view_map.position, screen.view_map.size)
	_check(Rect2(0, 12, 320, 150).encloses(map_rect) and map_rect.position == map_rect.position.floor(), "...fitting the screen at whole pixels (%s)" % map_rect)
	await _action("menu")
	_check(not screen.viewing and current_scene == screen and screen.get_viewport().gui_get_focus_owner() == screen.tiles[2],
		"Esc in the map goes back to the select (focus on its tile)")
	screen.open_view(2)
	await _action("ui_cancel")
	_check(not screen.viewing and current_scene == screen, "B / ui_cancel does too")
	screen.open_view(1)
	_check(not screen.viewing, "a locked level's map doesn't open")

	# Touch: a tap on a tile, then the BACK button.
	await _tap(screen.tiles[1].get_global_rect().get_center())
	_check(screen.viewing and screen.viewed_level == 2, "tapping a tile opens its map")
	await _tap(screen.view_back.get_global_rect().get_center())
	_check(not screen.viewing, "tapping BACK returns to the select")

	# The HARD switch shows hard mode's maps.
	screen.hard_box.button_pressed = true
	await _physics_frames(2)
	_check(screen.hard and not screen.tiles[2].disabled and screen.tiles[1].disabled and not progress.hard_mode,
		"HARD shows the hard maps (3 surveyed, 2 not) without changing the game's mode")
	screen.open_view(3)
	_check("HARD" in screen.view_title.text, "...and their maps say HARD")
	screen.close_view()
	screen.hard_box.button_pressed = false
	await _physics_frames(2)

	# No times anywhere on the map screens, whatever the record (the level select has those).
	progress.best_times[3] = 20.0
	screen._fill_grid()
	await _physics_frames(1)
	screen.open_view(3)
	var all_text := " ".join(_texts(screen))
	_check(not ":" in all_text and not "ROUTE" in all_text and not "BEST" in all_text and not "LAST TRY" in all_text,
		"no times or route labels on the select or the view (%s)" % all_text)
	screen.close_view()
	progress.best_times.erase(3)
	screen._fill_grid()
	await _physics_frames(1)

	# The tile pictures never read the survey's cells: two completely different surveys of level 5 at
	# the same % (one lit outward from the start, one from the goal, different routes) look the same.
	var m5 := Levels.story_maze(5)
	var from_start := _lit_survey(m5, m5.start, 37)
	var from_goal := _lit_survey(m5, m5.goal, roundi(Survey.completeness(from_start, m5) * 100.0))
	from_start.moves = Survey.moves_along(MazeGenerator.shortest_path(m5, m5.start, m5.goal))
	from_start.clear = true
	from_goal.moves = Survey.moves_along(MazeGenerator.shortest_path(m5, m5.start, m5.start + MazeGenerator.open_neighbors(m5, m5.start)[0] - m5.start))
	from_goal.clear = true
	progress.maps[5] = from_start
	screen._fill_grid()
	var pic_a := _tile_picture(screen, 5)
	var pct_a: int = screen.tiles[4].get_meta("percent")
	progress.maps[5] = from_goal
	screen._fill_grid()
	var pic_b := _tile_picture(screen, 5)
	var pct_b: int = screen.tiles[4].get_meta("percent")
	_check(pct_a == pct_b and pic_a != null and pic_b != null and pic_a.get_data() == pic_b.get_data(),
		"two completely different surveys at the same %% (%d / %d) give identical tile pictures" % [pct_a, pct_b])
	var no_moves := from_goal.duplicate(true)
	no_moves.moves = PackedByteArray()
	progress.maps[5] = no_moves
	screen._fill_grid()
	var pic_c := _tile_picture(screen, 5)
	_check(_count_color(pic_c, MapView.ROUTE) == 0 and _count_color(pic_a, MapView.ROUTE) > 0, "...and the red example route shows only when a route is recorded")
	progress.maps.erase(5)
	screen._fill_grid()
	_check(not screen.has_method("_process") and not screen.has_method("_physics_process"), "the map screen does no per-frame work (no _process)")
	var cached := true
	var rects := 0
	for tile in screen.tiles:
		for child in tile.get_children():
			if child is TextureRect:
				rects += 1
				cached = cached and Rect2(Vector2.ZERO, tile.size).encloses(Rect2(child.position, child.size))
	_check(rects == 10 and cached, "every tile has its picture, inside the tile (%d)" % rects)

	# The route in the opened map is the same red whatever skin is equipped.
	var skin_imgs: Array[Image] = []
	var old_skin: String = progress.selected_skin
	for skin in ["lime", "lemon", "crimson", "shadow", "frost"]:
		progress.selected_skin = skin
		screen.open_view(3)
		skin_imgs.append(screen.view_map.texture.get_image())
		screen.close_view()
	progress.selected_skin = old_skin
	var same := true
	for img in skin_imgs:
		same = same and img.get_data() == skin_imgs[0].get_data()
	_check(same and _count_color(skin_imgs[0], MapView.ROUTE) > 20, "the opened map's route is the same red (%d px) with lime, lemon, crimson, inkky and frost" % _count_color(skin_imgs[0], MapView.ROUTE))

	# Esc on the select goes back to the hub, facing the table.
	await _action("menu")
	var back: Node = await _until_scene("res://scenes/hub.tscn")
	_check(back != null and hub_script.return_to == "maps", "Esc on the select returns to the hub, facing the map table")
	if back:
		await _physics_frames(3)
		_check(back.near.get("id", "") == "maps", "...with the slime in front of the table")
		Input.action_press("interact")
		await _physics_frames(2)
		Input.action_release("interact")
		screen = await _until_scene("res://scenes/maps.tscn")
		await _physics_frames(2)
		_check(screen != null and screen.hint_label.text == "", "the hint shows only the first time")
		if screen:
			screen.back_button.pressed.emit()
			back = await _until_scene("res://scenes/hub.tscn")
			_check(back != null, "the select's BACK button returns to the hub")
	var last := current_scene
	current_scene = null
	if is_instance_valid(last):
		last.free()


# ---------------------------------------------------------------- drawing (MapView)

func _test_drawing() -> void:
	var none: Array[Vector2i] = []
	var maze := Levels.story_maze(2)
	# A survey that sees only the first few cells of the route (and the tiles next to them), with every
	# mark that could leak: the clear route running on over unseen cells, a coin on a seen cell and
	# coins on unseen ones, the goal flagged but unseen.
	var leaky := Survey.blank(maze)
	var tiles := PackedByteArray()
	tiles.resize(maze.size.x * maze.size.y)
	var route := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	for i in mini(5, route.size()):
		tiles[(route[i].y * 2 + 1) * maze.size.x + route[i].x * 2 + 1] = 1
	var coin_cells: Array[Vector2i] = Levels.story_coin_cells(2)
	tiles[(coin_cells[0].y * 2 + 1) * maze.size.x + coin_cells[0].x * 2 + 1] = 1
	Survey.merge_seen(leaky, tiles)
	leaky.moves = Survey.moves_along(route)
	leaky.clear = true
	leaky.best_ms = 30000
	leaky.goal = true
	var unseen_px := 0
	var edge_px := 0
	var seen_cells := 0
	var walls_ok := 0
	var walls_bad := 0
	for sz: Vector2i in MapView.SIZES:
		for theme: String in ["", "volcanic"]:
			var img := MapView.render(maze, leaky, sz, coin_cells, theme)
			var off := Vector2i.ONE * (MapView.FRAME if theme != "" else 0)
			var fog: Color = MapView.palette(theme).fog
			var wall: Color = MapView.palette(theme).wall
			for cy in maze.cells.y:
				for cx in maze.cells.x:
					var cell := Vector2i(cx, cy)
					var seen := _seen_cell(leaky, cell)
					seen_cells += int(seen)
					if not seen:  # no pixel at all on an unseen cell
						unseen_px += _count_not(img, Rect2i(MapView.cell_rect(cell, sz).position + off, MapView.cell_rect(cell, sz).size), fog)
					for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
						var other := cell + dir
						var r := MapView.edge_rect(cell, dir, sz)
						r.position += off
						if not seen and not _seen_cell(leaky, other):  # a line between two unseen cells: never drawn
							edge_px += _count_not(img, r, fog)
						elif MazeGenerator.is_wall(maze, cell * 2 + Vector2i.ONE + dir):  # beside a seen cell: drawn where a wall is
							if _count_not(img, r, wall) == 0:
								walls_ok += 1
							else:
								walls_bad += 1
			# The posts (where lines cross) only at a seen cell's corners.
			var step := sz.x + sz.y
			for py in maze.cells.y + 1:
				for px in maze.cells.x + 1:
					var near := false
					for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
						near = near or _seen_cell(leaky, Vector2i(px, py) + d)
					if not near:
						edge_px += _count_not(img, Rect2i(Vector2i(px, py) * step + off, Vector2i.ONE * sz.y), fog)
	_check(unseen_px == 0 and seen_cells > 0, "no pixel is drawn on an unseen cell, route/coins/goal included (%d px over %d sizes, plain and themed)" % [unseen_px, MapView.SIZES.size()])
	_check(edge_px == 0, "no wall line or post is drawn between unseen cells (%d px)" % edge_px)
	_check(walls_bad == 0 and walls_ok > 0, "every wall beside a seen cell is drawn as a line (%d drawn, %d missing)" % [walls_ok, walls_bad])

	# A hairpin: the route goes up one corridor and back down the one next to it (path[i + 3] is next
	# to path[i] across a wall). The wall line between the legs is drawn whole, both legs carry the
	# route, and floor shows between each leg and the wall.
	var hairpins := 0
	var hairpin_bad: Array[String] = []
	for level in [5, 10]:
		for hard_mode: bool in [false, true]:
			var m := Levels.story_maze(level, hard_mode)
			var full := Survey.full(m, 10.0)
			var path := Survey.route_cells(full, m)
			var sz := MapView.layout(m.cells, Vector2i(316, 149))
			var img := MapView.render(m, full, sz, none)
			var pal := MapView.palette()
			for i in path.size() - 3:
				var a := path[i]
				var b := path[i + 3]
				if (b - a).abs().x + (b - a).abs().y != 1 or i == 0 or b == m.goal:
					continue
				hairpins += 1
				var line := MapView.edge_rect(a, b - a, sz)
				var w := MapView.route_width(sz.x)
				var ra := MapView.cell_rect(a, sz)
				var rb := MapView.cell_rect(b, sz)
				var ca := ra.position + Vector2i.ONE * MapView.route_inset(sz.x)
				var cb := rb.position + Vector2i.ONE * MapView.route_inset(sz.x)
				# The pixel just inside each leg's cell next to the wall is floor (the route doesn't touch the wall).
				var a_side := _side_px(ra, b - a)
				var b_side := _side_px(rb, a - b)
				var ok: bool = _count_not(img, line, pal.wall) == 0 and img.get_pixelv(ca) == MapView.ROUTE and img.get_pixelv(cb) == MapView.ROUTE \
					and img.get_pixelv(a_side) == pal.floor and img.get_pixelv(b_side) == pal.floor and w < sz.x
				if not ok and hairpin_bad.size() < 3:
					hairpin_bad.append("L%d%s %s/%s at %s" % [level, "h" if hard_mode else "", a, b, sz])
	_check(hairpins > 0 and hairpin_bad.is_empty(),
		"a hairpin route shows a wall line between its two legs, with floor either side (%d hairpins on L5/L10 normal+hard; %s)" % [hairpins, ", ".join(hairpin_bad)])
	# The demo's U-turn walk (only the tiles beside it seen): the same, on a partly seen map.
	var demo: GDScript = load("res://tests/demo_maps.gd")
	var m5 := Levels.story_maze(5)
	var turn: Dictionary = demo.uturn(m5)
	var cells := Survey.route_cells(turn, m5)
	var sz5 := MapView.layout(m5.cells, Vector2i(316, 149))
	var img5 := MapView.render(m5, turn, sz5, none)
	var found := false
	for i in cells.size() - 3:
		if (cells[i + 3] - cells[i]).abs().x + (cells[i + 3] - cells[i]).abs().y == 1:
			found = _count_not(img5, MapView.edge_rect(cells[i], cells[i + 3] - cells[i], sz5), MapView.WALL) == 0
			break
	_check(found, "...also on a partly seen map (the demo's --uturn walk on level 5)")

	# Every story and hard maze fits the view at whole pixels, plain and themed; the biggest (36x20).
	var fit_bad: Array[String] = []
	var smallest := 99
	for level in range(1, Levels.COUNT + 1):
		for hard_mode: bool in [false, true]:
			var cells_n: Vector2i = Levels.story_maze(level, hard_mode).cells
			for framed: bool in [false, true]:
				var sz := MapView.layout(cells_n, Vector2i(316, 149), framed)
				var px := MapView.map_size(cells_n, sz) + Vector2i.ONE * (MapView.FRAME * 2 if framed else 0)
				smallest = mini(smallest, sz.x)
				if px.x > 316 or px.y > 149 or sz.x < 4:
					fit_bad.append("L%d%s%s %s" % [level, "h" if hard_mode else "", " themed" if framed else "", px])
	var big := MapView.layout(Levels.HARD_MAX_CELLS, Vector2i(316, 149))
	var big_px := MapView.map_size(Levels.HARD_MAX_CELLS, big)
	_check(fit_bad.is_empty() and big_px.x <= 316 and big_px.y <= 149 and big.x >= 5,
		"every story/hard maze fits the 316x149 view at whole pixels, themed too (smallest floor %d px; 36x20: %d+%d px = %s; %s)" % [smallest, big.x, big.y, big_px, ", ".join(fit_bad)])
	var rendered := MapView.render({cells = Levels.HARD_MAX_CELLS, size = Levels.HARD_MAX_CELLS * 2 + Vector2i.ONE, walls = PackedByteArray(), start = Vector2i.ZERO, goal = Vector2i.ZERO}, {}, big, none)
	_check(rendered.get_size() == big_px, "...and the image is exactly that size (%s)" % rendered.get_size())

	# The route: a 1 px line (a hairpin's legs, checked above, are single red pixels with floor beside
	# them), the same red whatever the skin (the skin isn't an input any more: MapView.palette).
	var odd := true
	for sz: Vector2i in MapView.SIZES:
		odd = odd and sz.x % 2 == 1 and MapView.route_width(sz.x) == 1 and MapView.route_inset(sz.x) * 2 + 1 == sz.x
	_check(odd, "every map size has an odd floor, so the 1 px route runs exactly down its middle")
	var reds_ok := true
	for theme: String in [""] + MapView.THEMED.keys():
		var pal := MapView.palette(theme)
		reds_ok = reds_ok and pal.route == MapView.ROUTE and absf((pal.route as Color).get_luminance() - (pal.floor as Color).get_luminance()) >= 0.2 \
			and (pal.route as Color).r > 0.8 and (pal.route as Color).g < 0.2
	_check(reds_ok, "the route is the same saturated red on every palette, and stands out from every paper")

	# Themes: every story level (normal and hard maps alike) has a palette.
	var missing: Array[String] = []
	for level in range(1, Levels.COUNT + 1):
		if not MapView.THEMED.has(Themes.for_level(level)):
			missing.append(str(level))
	_check(missing.is_empty() and MapView.THEMED.size() == Levels.COUNT, "a themed palette for all 10 levels, normal and hard (%s)" % ", ".join(missing))

	_test_previews()

	# A survey of another layout of the same size draws nothing at all.
	var foreign_maze := maze.duplicate(true)
	foreign_maze.goal = foreign_maze.start
	var foreign := Survey.full(foreign_maze, 5.0)
	var sizes := MapView.layout(maze.cells, Vector2i(316, 149))
	var blank_img := MapView.render(maze, foreign, sizes, coin_cells)
	_check(_count_not(blank_img, Rect2i(Vector2i.ZERO, blank_img.get_size()), MapView.FOG) == 0, "a same-size survey of another layout draws nothing on the map")
	# Themed maps are on (one switch to turn them off).
	var select: GDScript = load("res://scripts/ui/map_select.gd")
	_check(select.get_script_constant_map().THEMED_MAPS == true, "themed maps are on (map_select.THEMED_MAPS)")


## The select tiles' example mazes (MapView.preview).
func _test_previews() -> void:
	var walls_seen := {}
	var bad: Array[String] = []
	var unrelated := true
	for level in range(1, Levels.COUNT + 1):
		for hard_mode: bool in [false, true]:
			var ex := MapView.example(level, hard_mode)
			var m: Dictionary = ex.maze
			walls_seen[m.walls] = true
			var real := Levels.story_maze(level, hard_mode)
			unrelated = unrelated and m.cells != real.cells and m.cells == MapView.EXAMPLE_CELLS
			# A perfect maze: every cell reached, the route from start to goal along open passages.
			if ex.order.size() != m.cells.x * m.cells.y or ex.route[0] != m.start or ex.route[-1] != m.goal:
				bad.append("L%d%s" % [level, "h" if hard_mode else ""])
			for theme: String in ["", Themes.for_level(level)]:
				for state in [[0, 0, true], [22, 0, false], [60, 1, false], [100, 2, false]]:
					var img := MapView.preview(level, hard_mode, state[0], state[1], state[2], theme).get_image()
					if img.get_width() > MapView.THUMB.x or img.get_height() > MapView.THUMB.y:
						bad.append("L%d size %s" % [level, img.get_size()])
	_check(bad.is_empty(), "every example maze is whole, with a start-to-goal route, and every preview fits its %s box (%s)" % [MapView.THUMB, ", ".join(bad)])
	_check(walls_seen.size() == Levels.COUNT * 2, "the 20 example mazes (10 levels x normal/hard) are all different (%d distinct)" % walls_seen.size())
	_check(unrelated, "example mazes are tiny made-up ones (%s cells), never a real level's size or layout" % MapView.EXAMPLE_CELLS)
	# Deterministic: rebuilt from scratch they come out the same (pure integer hashing).
	var first: PackedByteArray = MapView.example(4, false).maze.walls
	var first_px := MapView.preview(4, false, 60, 2, false, "sunken").get_image().get_data()
	MapView._examples.clear()
	MapView._previews.clear()
	_check(MapView.example(4, false).maze.walls == first and MapView.preview(4, false, 60, 2, false, "sunken").get_image().get_data() == first_px,
		"example mazes and previews are deterministic (rebuilt from scratch: identical)")
	# Cached: the same tile state gives the same texture object (nothing rebuilt).
	_check(MapView.preview(4, false, 60, 2, false, "sunken") == MapView.preview(4, false, 60, 2, false, "sunken"), "previews are cached textures")

	# Lit in proportion to the %: lit cells = floor(% x cells), all at 100%, none when locked.
	var total := MapView.EXAMPLE_CELLS.x * MapView.EXAMPLE_CELLS.y
	var counts: Array[String] = []
	var proportional := true
	var last := -1
	for p in [0, 5, 22, 40, 60, 85, 99, 100]:
		var lit := _lit_cells(MapView.preview(2, false, p, 0, false, "mossy").get_image(), "mossy")
		var want: int = total if p == 100 else clampi(floori(p * total / 100.0), 1 if p > 0 else 0, total - 1)
		proportional = proportional and lit == want and lit >= last
		last = lit
		counts.append("%d%%=%d" % [p, lit])
	var locked_lit := _lit_cells(MapView.preview(2, false, 60, 2, true, "mossy").get_image(), "mossy")
	_check(proportional and locked_lit == 0, "previews light cells in proportion to the %% (%s of %d; locked: %d)" % [", ".join(counts), total, locked_lit])
	# The example route only with a recorded route: solid red for a best clear, dashed faint for a try.
	var pal := MapView.palette("frozen")
	var no_route := _count_color(MapView.preview(7, false, 100, 0, false, "frozen").get_image(), MapView.ROUTE) + _count_color(MapView.preview(7, false, 100, 0, false, "frozen").get_image(), pal.faint)
	var best := _count_color(MapView.preview(7, false, 100, 2, false, "frozen").get_image(), MapView.ROUTE)
	var tried := _count_color(MapView.preview(7, false, 100, 1, false, "frozen").get_image(), pal.faint)
	var locked_route := _count_color(MapView.preview(7, false, 0, 2, true, "frozen").get_image(), MapView.ROUTE)
	_check(no_route == 0 and best > 0 and tried == best and locked_route == 0,
		"the example route shows only with a recorded route (none %d px, best %d px red, last try %d px faint red, locked %d)" % [no_route, best, tried, locked_route])
	var gold := _count_color(MapView.preview(7, false, 100, 2, false, "frozen").get_image(), MapView.PREVIEW_GOLD)
	var not_gold := _count_color(MapView.preview(7, false, 99, 2, false, "frozen").get_image(), MapView.PREVIEW_GOLD)
	_check(gold > 0 and not_gold == 0, "a fully uncovered level's preview gets a gold frame (%d px; 99%%: %d)" % [gold, not_gold])


## How many of an example preview's cells are lit (their middle pixel is paper or route).
func _lit_cells(img: Image, theme: String) -> int:
	var pal := MapView.palette(theme)
	var n := 0
	for cy in MapView.EXAMPLE_CELLS.y:
		for cx in MapView.EXAMPLE_CELLS.x:
			var r := MapView.cell_rect(Vector2i(cx, cy), MapView.EXAMPLE_SIZES)
			var c := img.get_pixelv(r.position + Vector2i.ONE + Vector2i.ONE * MapView.route_inset(r.size.x))
			n += int(_near(c, pal.floor) or _near(c, MapView.ROUTE) or _near(c, pal.faint))
	return n


func _count_color(img: Image, color: Color) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			n += int(_near(img.get_pixel(x, y), color))
	return n


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.003 and absf(a.g - b.g) < 0.003 and absf(a.b - b.b) < 0.003 and absf(a.a - b.a) < 0.003


## A survey of `maze` with tiles lit one at a time breadth first from `from` until `percent`% shows.
func _lit_survey(maze: Dictionary, from: Vector2i, percent: int) -> Dictionary:
	var survey := Survey.blank(maze)
	var queue: Array[Vector2i] = [from * 2 + Vector2i.ONE]
	var reached := {queue[0]: true}
	var i := 0
	while i < queue.size() and roundi(Survey.completeness(survey, maze) * 100.0) < percent:
		var t := queue[i]
		i += 1
		Survey.mark_seen(survey, t)
		for d: Vector2i in MazeGenerator.DIRS:
			var n := t + d
			if n.x > 0 and n.y > 0 and n.x < maze.size.x - 1 and n.y < maze.size.y - 1 and not reached.has(n) and not MazeGenerator.is_wall(maze, n):
				reached[n] = true
				queue.append(n)
	return survey


## The picture on the select tile of `level`.
func _tile_picture(screen: Control, level: int) -> Image:
	for tile: Button in screen.tiles:
		if tile.get_meta("level") == level:
			for child in tile.get_children():
				if child is TextureRect:
					return child.texture.get_image()
	return null


## The middle pixel of `r`'s side facing `dir`.
func _side_px(r: Rect2i, dir: Vector2i) -> Vector2i:
	var c := r.position + Vector2i.ONE * (r.size.x / 2)
	if dir.x != 0:
		c.x = r.end.x - 1 if dir.x > 0 else r.position.x
	else:
		c.y = r.end.y - 1 if dir.y > 0 else r.position.y
	return c


func _seen_cell(survey: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and Survey.is_seen(survey, cell * 2 + Vector2i.ONE)


## How many pixels of `r` (clipped to the image) aren't `color`.
func _count_not(img: Image, r: Rect2i, color: Color) -> int:
	var clip := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var n := 0
	for y in range(clip.position.y, clip.end.y):
		for x in range(clip.position.x, clip.end.x):
			n += int(img.get_pixel(x, y) != color)
	return n


# ---------------------------------------------------------------- helpers

func _spawn_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await _physics_frames(2)  # _arm_survey runs deferred
	return game


## Ends a run like leaving it (restart / quit): the game leaves the tree.
func _stop(game: Node2D) -> void:
	current_scene = null
	game.free()
	await _physics_frames(1)


## Steers the slime cell by cell along `cells` (from its current cell) with a RoutePilot.
func _walk(game: Node2D, cells: Array[Vector2i]) -> void:
	var pilot := RoutePilot.new()
	pilot.cells = cells
	game.add_child(pilot)
	var done := [false]
	pilot.route_done.connect(func() -> void: done[0] = true)
	await _until(func() -> bool: return done[0] or game.finished, 1200)
	pilot.queue_free()
	await _physics_frames(10)


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _until_scene(path: String) -> Node:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return current_scene
	return null


func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _physics_frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _physics_frames(2)


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * at  # touches arrive in window pixels
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await _physics_frames(2)


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		out.append(label.text)
	return out


