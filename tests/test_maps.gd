extends SceneTree

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
## - the MAP TABLE screen: tiles locked until surveyed, thumbnail/percent/route marker, opening a map,
##   BACK / Esc / ui_cancel at each depth (Esc on the select returns to the hub), taps, the
##   first-time hint, and the map never drawing an unseen tile.
## Uses a throwaway save; the real save's md5 is checked unchanged at the end.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_maps.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_maps.cfg"
const CHILD_FLAG := "--maps-child"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
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
	progress.save_path = TEST_SAVE
	progress.saving_enabled = true
	progress.reset_progress()
	progress.levels_cleared = 2
	progress.highest_unlocked = 3
	progress.tutorial_seen = 3

	await _test_capture()
	_test_rules()
	_test_save()
	_test_seeds()
	await _test_screen()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched (md5 %s)" % real_md5)
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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
	await _frames(3)
	_check(game.finished and not game.won, "the second attempt dries up")
	await _frames(30)  # past its retry buttons' delay
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
	await _frames(60)  # past its win buttons' delay
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
	await _frames(3)
	_check(game.is_random(), "a randomizer maze...")
	game.slime.position += Vector2(16, 0)
	await _frames(20)
	await _stop(game)
	_check(progress.maps.is_empty(), "...records nothing (it is fresh every time)")
	progress.start_story(1)

	game = MAIN.instantiate()
	game.level = 1
	root.add_child(game)  # not the running scene: a test's or demo's loose game node
	await _frames(20)
	game.free()
	_check(progress.maps.is_empty(), "a game node that isn't the running scene records nothing")

	# Hard mode: its own survey under level + 100; seeing the goal marks it without a win.
	progress.hard_mode = true
	game = await _spawn_running(2)
	var hard_path: Array[Vector2i] = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	# Halfway between the last cell before the chalice and the chalice: in sight, not in reach.
	game.slime.position = (MazeGenerator.cell_center(hard_path[-2], game.TILE) + MazeGenerator.cell_center(hard_path[-1], game.TILE)) / 2.0
	await _frames(3)
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
	progress.maps = {}


# ---------------------------------------------------------------- save

func _test_save() -> void:
	progress.reset_progress()
	progress.levels_cleared = 4
	progress.highest_unlocked = 5
	var maze := Levels.story_maze(2)
	progress.maps[2] = Survey.full(maze, 21.5)
	progress.maps[103] = Survey.blank(Levels.story_maze(3, true).size, Levels.story_maze(3, true).start)
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
	reread.load(TEST_SAVE)
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
	progress.saving_enabled = false
	progress.levels_cleared = 3
	progress.highest_unlocked = 4
	var maze := Levels.story_maze(2)
	var partial := Survey.blank(maze.size, maze.start)
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

	# The map never draws an unseen tile.
	var sizes := MapView.layout(maze.cells, Vector2i(312, 146))
	var image := MapView.render(maze, partial, sizes, [] as Array[Vector2i], Skins.shades(Color.GREEN))
	var leaks := 0
	for ty in maze.size.y:
		for tx in maze.size.x:
			if Survey.is_seen(partial, Vector2i(tx, ty)):
				continue
			# The middle pixel of an unseen tile must be fog (the start ring / route may cross a tile's edge only).
			var px := Vector2i(MapView._tile_px(tx, sizes).x + MapView._tile_px(tx, sizes).y / 2, MapView._tile_px(ty, sizes).x + MapView._tile_px(ty, sizes).y / 2)
			var c := image.get_pixelv(px)
			if c != MapView.FOG and not (Vector2i(tx, ty) == maze.start * 2 + Vector2i.ONE):
				leaks += 1
	_check(leaks == 0, "the map draws nothing on unseen tiles (%d leaks)" % leaks)
	var big := MapView.layout(Vector2i(36, 20), Vector2i(312, 146))
	_check(MapView.map_size(Vector2i(36, 20), big).x <= 312 and MapView.map_size(Vector2i(36, 20), big).y <= 146 and big.x >= 4,
		"the largest maze (36x20 cells) fits the view at an integer %d px per cell" % big.x)

	# Open from the hub.
	var hub_script: GDScript = load("res://scripts/hub.gd")
	hub_script.return_to = "maps"
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _frames(3)
	_check(hub.near.get("id", "") == "maps" and hub.prompt_name.text == "MAP TABLE", "standing at the map table, the prompt says MAP TABLE")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	var screen: Control = await _until_scene("res://scenes/maps.tscn")
	_check(screen != null, "F at the map table opens the MAP TABLE screen")
	if screen == null:
		return
	await _frames(2)
	_check(screen.hint_label.text == screen.HINT and progress.maps_hint_seen, "the first opening shows the hint line")
	_check(screen.tiles.size() == 10 and screen.tiles[0].disabled and not screen.tiles[1].disabled and not screen.tiles[2].disabled and screen.tiles[3].disabled,
		"tiles: unsurveyed levels are locked (1, 4), surveyed ones open (2, 3)")
	_check(screen.tiles[2].get_meta("percent") == 100 and screen.tiles[1].get_meta("percent") < 30, "...with their survey %% (%d, %d)" % [screen.tiles[1].get_meta("percent"), screen.tiles[2].get_meta("percent")])
	var texts := _texts(screen.tiles[2])
	_check("SANDSTONE SANCTUM" in texts and "L3 100%" in texts and "0:23.5" in texts, "...name, number, %% and the best route's time (%s)" % ", ".join(texts))
	_check("LAST TRY" in _texts(screen.tiles[1]), "...or LAST TRY without a clear")
	_check("L1 NO SURVEY YET" in _texts(screen.tiles[0]), "...or NO SURVEY YET")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.tiles[1] or screen.get_viewport().gui_get_focus_owner() == screen.tiles[2],
		"focus starts on a surveyed tile")

	# Keyboard: down to the next tile, Enter opens it; Esc closes it; ui_cancel too.
	screen.tiles[1].grab_focus()
	await _action("ui_down")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.tiles[2], "arrow keys move between tiles (2 -> 3)")
	await _action("ui_accept")
	_check(screen.viewing and screen.viewed_level == 3 and screen.view_root.visible and screen.view_map.texture != null,
		"Enter opens that level's map")
	_check("LEVEL 3" in screen.view_title.text and "BEST ROUTE 0:23.5" in screen.view_line.text and "100%" in screen.view_line.text,
		"...titled, with its survey %% and best route (%s / %s)" % [screen.view_title.text, screen.view_line.text])
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
	await _frames(2)
	_check(screen.hard and not screen.tiles[2].disabled and screen.tiles[1].disabled and not progress.hard_mode,
		"HARD shows the hard maps (3 surveyed, 2 not) without changing the game's mode")
	screen.open_view(3)
	_check("HARD" in screen.view_title.text, "...and their maps say HARD")
	screen.close_view()
	screen.hard_box.button_pressed = false

	# Esc on the select goes back to the hub, facing the table.
	await _action("menu")
	var back: Node = await _until_scene("res://scenes/hub.tscn")
	_check(back != null and hub_script.return_to == "maps", "Esc on the select returns to the hub, facing the map table")
	if back:
		await _frames(3)
		_check(back.near.get("id", "") == "maps", "...with the slime in front of the table")
		Input.action_press("interact")
		await _frames(2)
		Input.action_release("interact")
		screen = await _until_scene("res://scenes/maps.tscn")
		await _frames(2)
		_check(screen != null and screen.hint_label.text == "", "the hint shows only the first time")
		if screen:
			screen.back_button.pressed.emit()
			back = await _until_scene("res://scenes/hub.tscn")
			_check(back != null, "the select's BACK button returns to the hub")
	var last := current_scene
	current_scene = null
	if is_instance_valid(last):
		last.free()


# ---------------------------------------------------------------- helpers

func _spawn_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await _frames(2)  # _arm_survey runs deferred
	return game


## Ends a run like leaving it (restart / quit): the game leaves the tree.
func _stop(game: Node2D) -> void:
	current_scene = null
	game.free()
	await _frames(1)


## Steers the slime cell by cell along `cells` (from its current cell) with a RoutePilot.
func _walk(game: Node2D, cells: Array[Vector2i]) -> void:
	var pilot := RoutePilot.new()
	pilot.cells = cells
	game.add_child(pilot)
	var done := [false]
	pilot.route_done.connect(func() -> void: done[0] = true)
	await _until(func() -> bool: return done[0] or game.finished, 1200)
	pilot.queue_free()
	await _frames(10)


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
	await _frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * at  # touches arrive in window pixels
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await _frames(2)


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		out.append(label.text)
	return out


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
