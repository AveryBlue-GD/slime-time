extends "res://tests/suite_base.gd"

## Map coins (MAP TABLE) and the map coin reveal (Economy.MAP_COIN_REVEAL_TEST, on for everyone since
## 2026-10-21, docs/spring-cleaning/map-coin-reveal-test.md). Checks:
## - collected coins are never drawn, in normal mode and in dev (Progress.map_coins, MapView.render);
## - an uncollected coin is revealed when its center is within the light (LIGHT_RADIUS + the
##   BRIGHTNESS reach: 20 / 28 / 36 / 45 px) by straight line, walls ignored: one cell over (32 px), behind
##   a wall, BRIGHTNESS 2 and 3 reach it; BRIGHTNESS 0..3 along the same walk reveal more and more coins; F1 FULL BRIGHT reveals
##   all; the revealed coins are drawn, also on fog cells;
## - normal runs reveal too and their revealed coins are saved ([maps] coins_N) and read back (broken
##   values dropped); `--nocoinreveal` (child launch) and mapcoinreveal_force = 0 turn it off;
## - dev runs (F1 ones too) record into memory only: the save file's md5 is unchanged; hard maps are
##   separate (their own key, no coins).
## Uses a throwaway save; the real save's md5 is checked unchanged at the end.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_map_coin_reveal.gd

const MAIN := preload("res://scenes/main.tscn")
const CHILD_FLAG := "--coinreveal-child"
const TILE := 16  # (game.gd TILE)
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000
	if CHILD_FLAG in OS.get_cmdline_user_args():
		print("REVEAL_CHILD on=%s dev=%s" % [Economy.map_coin_reveal_on(progress.dev_tools), progress.dev_tools])
		quit()
		return
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH)
	var real_md5 := FileAccess.get_md5(real) if FileAccess.file_exists(real) else ""
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.reset_progress()
	progress.tutorial_seen = 3
	progress.save_progress()

	_test_switch()
	_test_collected_never_drawn()
	await _test_reveal()
	await _test_not_outside_dev()
	_test_child_flag()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched (md5 %s)" % real_md5)
	_result()
	quit(1 if failures else 0)


func _test_switch() -> void:
	_check(Economy.MAP_COIN_REVEAL_TEST == true, "MAP_COIN_REVEAL_TEST is on (for everyone)")
	_check(Economy.map_coin_reveal_on(true) and Economy.map_coin_reveal_on(false), "on in dev and outside dev")
	Economy.mapcoinreveal_force = 0
	_check(not Economy.map_coin_reveal_on(true) and not Economy.map_coin_reveal_on(false), "mapcoinreveal_force = 0 (--nocoinreveal) turns it off")
	Economy.mapcoinreveal_force = -1


## Collected coins: absent from the render input (and the drawing) in normal and dev mode.
func _test_collected_never_drawn() -> void:
	var cells: Array[Vector2i] = Levels.story_coin_cells(2)
	var maze := Levels.story_maze(2)
	var survey := Survey.full(maze, 30.0)
	var seen: Array = []
	seen.assign(cells)
	survey.seen_coins = seen
	progress.maps[progress.survey_key(2, false)] = survey
	progress.collect_coin(2, cells[0])
	var sizes := MapView.layout(maze.cells, Vector2i(316, 149))
	progress.dev_tools = false
	var normal: Array[Vector2i] = progress.map_coins(2, false)
	_check(not cells[0] in normal and normal.size() == cells.size() - 1, "normal mode: the collected coin is absent, the other revealed ones are there (%d)" % normal.size())
	survey.erase("seen_coins")
	_check(progress.map_coins(2, false).is_empty(), "...no revealed coins, no coin marks")
	survey.seen_coins = seen
	progress.dev_tools = true
	var dev: Array[Vector2i] = progress.map_coins(2, false)
	_check(not cells[0] in dev and dev.size() == cells.size() - 1, "dev: the collected coin is absent, the other revealed ones are there (%d)" % dev.size())
	_check(_coin_px(MapView.render(maze, survey, sizes, dev, "", "", Color.WHITE, true)) > 0
		and _coin_px(MapView.render(maze, survey, sizes, [] as Array[Vector2i])) == 0, "dev: revealed coins are drawn, nothing when none")
	# Fog cells (nothing seen): coins only with fog_coins.
	var blank := Survey.blank(maze)
	_check(_coin_px(MapView.render(maze, blank, sizes, dev)) == 0
		and _coin_px(MapView.render(maze, blank, sizes, dev, "", "", Color.WHITE, true)) > 0,
		"revealed coins on fog cells are drawn only with fog_coins")
	progress.dev_tools = false
	progress.maps = {}
	progress.coins_found = {}


## Dev reveal: by radius through walls, more with BRIGHTNESS, everything with F1; in memory only.
func _test_reveal() -> void:
	var md5 := FileAccess.get_md5(ProjectSettings.globalize_path(test_save))
	progress.enable_dev_mode()  # saving off, maps cleared, as tools/play.sh --dev
	progress.coins_found = {}
	var maze := Levels.story_maze(1)
	var coins: Array[Vector2i] = Levels.story_coin_cells(1)
	# A coin and a cell one step over with a wall between them (32 px center to center).
	var target := Vector2i(-1, -1)
	var beside := Vector2i(-1, -1)
	for c in coins:
		for d: Vector2i in MazeGenerator.DIRS:
			var n := c + d
			if target.x < 0 and n.x >= 0 and n.y >= 0 and n.x < maze.cells.x and n.y < maze.cells.y \
					and MazeGenerator.is_wall(maze, c * 2 + Vector2i.ONE + d):
				target = c
				beside = n
	_check(target.x >= 0, "(a coin with a walled-off neighbor cell: %s beside %s)" % [target, beside])
	var counts: Array[int] = []
	var through: Array[bool] = []
	var path: Array[Vector2i] = MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	for level in 4:
		progress.maps = {}
		progress.coins_found = {}  # the same coin set at every level of BRIGHTNESS
		progress.upgrades["brightness"] = level
		var game := await _spawn_running(1)
		_check(game._coin_reveal and game._survey_live, "dev BRIGHTNESS %d: the reveal is on and the run records" % level)
		var centered := true  # coin.position is its cell's center, the distance the reveal measures
		for coin in game.coins:
			centered = centered and coin.position == MazeGenerator.cell_center(coin.cell, TILE)
		_check(centered and not game.coins.is_empty(), "coins sit at their cell centers")
		await _sweep(game, path)
		counts.append(game.survey_coins.size())
		game.slime.position = MazeGenerator.cell_center(beside, TILE)
		await _physics_frames(2)
		through.append(target in game.survey_coins)
		var noted: int = game.survey_coins.size()
		await _stop(game)
		var survey: Dictionary = progress.survey_for(1, false)
		_check(not survey.is_empty() and survey.get("seen_coins", []).size() == noted,
			"...the dev run's survey is in memory with its revealed coins (%d)" % survey.get("seen_coins", []).size())
	_check(through == [false, false, true, true], "a coin behind a wall one cell over (32 px): BRIGHTNESS 2 and 3 reach it (%s)" % [through])
	_check(counts[0] <= counts[1] and counts[1] <= counts[2] and counts[2] <= counts[3] and counts[3] > counts[0],
		"BRIGHTNESS 0..3 along the same route reveal more coins (non-decreasing, more at 3 than at 0) (%s)" % [counts])
	progress.maps = {}
	progress.upgrades["brightness"] = 0
	var game := await _spawn_running(1)
	game.set_dev_bright(true)  # F1
	await _physics_frames(2)
	var all_seen: bool = game.survey_coins.size() == coins.size()
	await _stop(game)
	_check(all_seen, "F1 FULL BRIGHT reveals every coin (%d)" % coins.size())
	_check(progress.map_coins(1, false).size() == coins.size(), "...and the F1 run's survey shows them all on the map")
	# Hard: its own survey, no coins.
	progress.hard_mode = true
	progress.start_story(1)
	game = await _spawn_running(1)
	await _stop(game)
	progress.hard_mode = false
	_check(progress.maps.has(progress.survey_key(1, true)) and progress.map_coins(1, true).is_empty()
		and progress.map_coins(1, false).size() == coins.size(), "a hard dev run records its own map (no coins), the normal one unchanged")
	_check(FileAccess.get_md5(ProjectSettings.globalize_path(test_save)) == md5, "dev runs saved nothing (save md5 unchanged)")
	var code_file := ConfigFile.new()
	code_file.parse(progress._write(true).encode_to_text())
	_check(not progress.maps.is_empty() and not code_file.has_section("maps"), "a dev session's in-memory maps stay out of save codes")
	progress.dev_tools = false
	progress.dev_bright = false


## Outside dev: normal runs reveal coins too, and the save keeps them.
func _test_not_outside_dev() -> void:
	progress.reset_progress()
	progress.saving_enabled = true
	progress.save_path = test_save
	progress.tutorial_seen = 3
	progress.upgrades["brightness"] = 3
	var game := await _spawn_running(1)
	_check(game._coin_reveal and game._survey_live, "normal run: the coin reveal is on and the run records")
	await _sweep(game, MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal).slice(0, 12))
	var noted: Array[Vector2i] = game.survey_coins.duplicate()
	await _stop(game)
	var survey: Dictionary = progress.survey_for(1, false)
	_check(not noted.is_empty() and survey.get("seen_coins", []).size() == noted.size(), "...it notes coins and records them (%d)" % noted.size())
	var text := FileAccess.get_file_as_string(test_save)
	_check("coins_1" in text, "the save holds the revealed coins ([maps] coins_1)")
	progress.load_progress()
	var back: Array = progress.survey_for(1, false).get("seen_coins", [])
	var same := back.size() == noted.size()
	for cell in noted:
		same = same and cell in back
	_check(same, "...and reads them back (%d)" % back.size())
	var file := ConfigFile.new()
	file.load(test_save)
	file.set_value("maps", "coins_1", [-5, "x", 99999, 1, 1, 2.5])
	file.save(test_save)
	progress.load_progress()
	_check(progress.survey_for(1, false).get("seen_coins", []) == [Vector2i(1, 0)], "broken coin values are dropped (%s)" % [progress.survey_for(1, false).get("seen_coins", [])])
	var maze := Levels.story_maze(2)
	var with := Survey.full(maze, 3.0)
	var plain := Survey.pack(with)
	with.seen_coins = [Vector2i(1, 1)]
	_check(Survey.pack(with) == plain, "Survey.pack itself is unchanged (coins are saved beside it)")
	progress.dev_tools = true
	Economy.mapcoinreveal_force = 0
	game = await _spawn_running(1)
	_check(not game._coin_reveal and not game._survey_live, "dev with mapcoinreveal_force = 0: no reveal, no recording (as before)")
	await _stop(game)
	Economy.mapcoinreveal_force = -1
	progress.dev_tools = false
	progress.upgrades["brightness"] = 0


func _test_child_flag() -> void:
	for flags: Array in [["--unlock-all"], ["--unlock-all", "--nocoinreveal"], []]:
		var out: Array = []
		OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--headless", "-s",
			"res://tests/test_map_coin_reveal.gd", "--", CHILD_FLAG] + flags, out, true)
		var line := ""
		for chunk: String in out:
			for l in chunk.split("\n"):
				if l.begins_with("REVEAL_CHILD"):
					line = l
		var want := "on=true dev=true" if flags == ["--unlock-all"] else ("on=false dev=true" if flags.size() == 2 else "on=true dev=false")
		_check(want in line, "a launch with %s: %s" % [flags, line])


## Puts the slime on each cell of `cells` in turn (a frame each).
func _sweep(game: Node2D, cells: Array[Vector2i]) -> void:
	for cell in cells:
		if game.finished:
			return
		game.slime.position = MazeGenerator.cell_center(cell, TILE)
		await _physics_frames(1)


func _coin_px(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(MapView.COIN):
				n += 1
	return n


func _spawn_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await _physics_frames(2)
	return game


func _stop(game: Node2D) -> void:
	current_scene = null
	game.free()
	await _physics_frames(1)
