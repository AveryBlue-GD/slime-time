extends "res://tests/suite_base.gd"

## The demo build (scripts/demo.gd, docs/demo-plan.md): one switch (Platform.is_demo, forced here with
## Platform.demo_override) and its gates. Checks, in this order:
## 1. a stripped demo export: with Demo.strip_test on, levels 1-3 are played to the chalice by the autopilot
##    and the last one leads (CONTINUE only, the first time) to the end screen; nothing full-only was asked
##    for or loaded (no level 4+ / hard 2+ data, no later theme art or ambience in the resource cache);
## 2. the full game with the switch off: every knob is the full game's, saves carry no demo marker;
## 3. every lock: levels (level select + archway), upgrade cap, abilities (only SLIME RIFLE, in the shop and
##    in a maze), hard (level 1 only), HEAT, randomizer (after level 3, its 3 fixed mazes, demo themes),
##    SHOP, skins, the web knobs; the end screen (WISHLIST hidden while the URL is empty, carry-over text
##    per platform, teaser cards) and the pause menu;
## 4. save carry-over both ways (files and codes): the demo marks its saves, the full game reads them and
##    drops the marker, and the demo never writes over a full-game save (byte-identical).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_demo.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	progress.hard_mode = false
	progress.reset_progress()
	await _check_stripped_run()
	await _check_stripped_full_save()
	_check_full_game()
	await _check_locks()
	await _check_screens()
	_check_carry_over()
	Platform.reset_overrides()
	Demo.strip_test = false
	_result()
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- 1. a stripped demo, played through

func _check_stripped_run() -> void:
	Platform.demo_override = 1
	Demo.strip_test = true
	Demo.denied.clear()
	progress.reset_progress()
	progress.story_seen = progress.STORY_INTRO
	for level in range(1, Demo.LEVELS + 1):
		progress.start_story(level)
		var game: Node2D = MAIN.instantiate()
		game.level = level
		root.add_child(game)
		current_scene = game
		await physics_frame
		game.add_child(preload("res://tests/autopilot.gd").new())
		for i in 150 * 60:
			await physics_frame
			if game.finished:
				break
		_check(game.won, "demo level %d: the autopilot reaches the chalice (%s)" % [level, Themes.for_level(level)])
		for i in int(game.CHOICE_DELAY * 60) + 10:
			await physics_frame
		if level < Demo.LEVELS:
			_check(game.hud.choice_buttons.size() == 3, "...level %d offers REPLAY / NEXT LEVEL / HUB" % level)
			current_scene = null
			game.free()
			continue
		var texts: Array = game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)
		_check(texts == ["CONTINUE"], "the demo's last level, the first time: CONTINUE only (%s)" % [texts])
		game.play_next()
		var opened := false
		for i in 240:
			await process_frame
			if current_scene != null and current_scene.scene_file_path == DemoEnd.SCENE:
				opened = true
				break
		_check(opened and DemoEnd.from == DemoEnd.FROM_STORY, "...CONTINUE opens the demo end screen")
		_check(progress.has_seen_story(Demo.END_SEEN_BIT), "...which is marked seen (saved in story_seen)")
		if current_scene:
			current_scene.free()
		current_scene = null
	_check(progress.levels_cleared == Demo.LEVELS and progress.is_randomizer_unlocked(), "after level %d the demo's randomizer is open" % Demo.LEVELS)
	_check(Demo.denied.is_empty(), "nothing asked for full-only data during the demo run (%s)" % [Demo.denied])
	var loaded: Array[String] = []
	for path in Demo.full_only_paths():
		if not path.ends_with(".import") and ResourceLoader.has_cached(path):
			loaded.append(path)
	_check(loaded.is_empty(), "no full-only file was loaded during the demo run (%s)" % [loaded])
	# The randomizer's first fixed maze, played stripped too.
	progress.start_random()
	_check(progress.random_seed == Demo.RANDOM_SEEDS[0] and progress.random_seed_fresh, "the first demo maze is Demo.RANDOM_SEEDS[0]")
	var maze: Node2D = MAIN.instantiate()
	root.add_child(maze)
	await physics_frame
	_check(maze.is_random() and maze.theme in Demo.themes(), "...in a demo theme (%s)" % maze.theme)
	maze.free()
	# A full-only level asked for anyway (a hand-made save, a bug) never crashes and is never built.
	progress.current_level = 7
	var forced: Node2D = MAIN.instantiate()
	forced.level = 7
	root.add_child(forced)
	await physics_frame
	_check(forced.level == Demo.LEVELS, "a full-game level falls back to the demo's last level (%d)" % forced.level)
	forced.free()
	_check(not Levels.has_data(4) and Levels.has_data(3) and not Levels.has_data(2, true) and Levels.has_data(1, true),
		"stripped: Levels.has_data sees levels 1-3 and hard 1 only")
	_check(Story.level_line(4) == "" and Story.level_line(3) != "", "stripped: no banner line for level 4")
	Demo.strip_test = false
	Demo.denied.clear()


## A stripped demo showing a FULL save's menus (someone who owns both): level select, map table, hub (coin board,
## HEAT pod, tour lines), skins, upgrades, settings and the end screen opened from a FULL GAME tile. Nothing
## full-only may be asked for or loaded (this runs before anything else in the suite loads later levels).
func _check_stripped_full_save() -> void:
	Platform.demo_override = 1
	Demo.strip_test = true
	Demo.denied.clear()
	progress.reset_progress()
	progress.story_seen = progress.STORY_INTRO | progress.STORY_FINALE
	progress.levels_cleared = Levels.COUNT
	progress.highest_unlocked = Levels.COUNT
	progress.current_level = 7
	progress.hard_cleared.assign([1, 2, 3, 4, 5])
	progress.heat_best = {1: 10, 2: 7, 4: 4}
	progress.best_times = {5: 40.0, 108: 70.0}
	progress.medals = {5: 3, 8: 2}
	progress.coins_found[8] = ["1,1", "2,3"]
	progress.upgrades = {slime = 7, speed = 4}
	progress.abilities = {splat = 2}
	progress.demo_guard = true
	for hard in [false, true]:
		progress.hard_mode = hard
		var select: Control = await _open("res://scenes/level_select.tscn")
		var flames := []
		for tile: Button in select.level_buttons:
			flames += tile.find_children("Flame", "", false, false)
		_check(flames.is_empty(), "full save, %s level select: no heat flames in the demo" % ("hard" if hard else "normal"))
		select.free()
		var maps: Control = await _open("res://scenes/maps.tscn")
		maps.free()
	progress.hard_mode = false
	var hub: Node = await _open("res://scenes/hub.tscn")
	hub.open_coin_board()
	await _frames(2)
	_check(not hub.heat_label.visible, "full save, hub: the HEAT n/100 pod is hidden in the demo")
	hub.close_coin_board()
	hub.free()
	for path in ["res://scenes/skins.tscn", "res://scenes/upgrades.tscn"]:
		var screen: Node = await _open(path)
		screen.free()
	var settings: Node = await _open("res://scenes/controls.tscn")
	var note: Label = settings.get_node_or_null("DemoGuardNote")
	_check(note != null and note.visible and note.text == "FULL GAME SAVE: THE DEMO WON'T CHANGE IT", "guarded: SETTINGS says the full save won't change")
	_check(settings.reset_confirm.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return "FULL GAME SAVE" in l.text),
		"guarded: so does the RESET confirm")
	settings.free()
	progress.demo_guard = false
	DemoEnd.from = DemoEnd.FROM_LOCKED
	var end: Control = await _open(DemoEnd.SCENE)
	_check(not progress.has_seen_story(Demo.END_SEEN_BIT), "the end screen from a FULL GAME tile doesn't count as seen (the pitch after level 3 stays)")
	end.free()
	# The hub tour's lines in the demo (desktop: CLEAR / BEAT 3; web: the stations that are off say FULL GAME).
	var tour: Node = load("res://scripts/hub_tour.gd").new()
	progress.levels_cleared = 0
	_check(tour.station_line("random") == "LOCKED: BEAT 3 LEVELS FIRST", "demo tour: the portal asks for the demo's 3 levels (%s)" % tour.station_line("random"))
	Platform.override = "web"
	_check(tour.station_line("random") == "FULL GAME" and tour.station_line("wheel") == "FULL GAME", "web demo tour: randomizer and wheel say FULL GAME")
	Platform.override = ""
	tour.free()
	_check(Demo.denied.is_empty(), "full save in a stripped demo: nothing full-only asked for (%s)" % [Demo.denied])
	var loaded: Array[String] = []
	for path in Demo.full_only_paths():
		if not path.ends_with(".import") and ResourceLoader.has_cached(path):
			loaded.append(path)
	_check(loaded.is_empty(), "...and nothing full-only loaded (%s)" % [loaded])
	Demo.strip_test = false
	Demo.denied.clear()
	progress.reset_progress()


# ---------------------------------------------------------------- 2. switch off: the full game

func _check_full_game() -> void:
	Platform.demo_override = 0
	progress.reset_progress()
	_check(not Demo.on() and Demo.levels() == Levels.COUNT and Demo.hard_levels() == Levels.COUNT and Demo.level_open(10, true),
		"switch off: every level, normal and hard")
	_check(Demo.upgrade_cap("slime") == Upgrades.max_level("slime") and Demo.heat_open() and Demo.shop_open()
		and Demo.randomizer_open() and Demo.hat_wheel_open() and Demo.ability_open("kaze") and Demo.skin_open("ember", true)
		and Demo.skin_open(Skins.RAINBOW, false), "switch off: no cap, HEAT, SHOP, randomizer, wheel, every ability and skin")
	_check(not progress.is_randomizer_unlocked(), "switch off: the randomizer still opens only after level %d" % Levels.COUNT)
	_check(not progress._write().has_section_key("meta", "demo") and not progress.demo_guard, "switch off: saves carry no demo marker")
	var seeds_ok := true
	for s in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 31 + 7
		seeds_ok = seeds_ok and Themes.for_seed(s) == Themes.BY_LEVEL[rng.randi_range(0, Themes.BY_LEVEL.size() - 1)]
	_check(seeds_ok, "switch off: randomizer themes are the full game's (every theme, same pick per seed)")
	var random_seeds := {}
	for i in 5:
		progress.new_random_maze()
		random_seeds[progress.random_seed] = true
	_check(random_seeds.size() == 5 and progress.random_seed_fresh, "switch off: random mazes are random seeds")
	_check(Levels.has_data(10, true) and Story.level_line(10) != "", "switch off: every level's data and line are there")


# ---------------------------------------------------------------- 3. the locks

func _check_locks() -> void:
	Platform.demo_override = 1
	progress.reset_progress()
	_check(Demo.levels() == 3 and Demo.hard_levels() == 1 and not Demo.level_open(4) and Demo.level_open(3)
		and not Demo.level_open(2, true) and Demo.level_open(1, true), "demo: levels 1-3, hard level 1")
	# Upgrades: capped at UPGRADE_CAP even with coins to spare.
	for level in range(1, 4):
		progress.coins_found[level] = Levels.coin_keys(level).duplicate()
	var bought := 0
	while progress.buy_upgrade("slime"):
		bought += 1
	_check(bought == Demo.UPGRADE_CAP and progress.upgrade_level("slime") == Demo.UPGRADE_CAP and progress.coins() >= Upgrades.cost("slime", Demo.UPGRADE_CAP),
		"upgrades stop at level %d with coins left (%d)" % [Demo.UPGRADE_CAP, progress.coins()])
	# Abilities: only SLIME RIFLE.
	progress.tickets = 60
	progress.tickets_lifetime = 60
	_check(progress.can_buy_ability("rifle") and not progress.can_buy_ability("splat") and not progress.can_buy_ability("kaze"),
		"abilities: only SLIME RIFLE can be bought")
	# SHOP.
	progress.spins = 20
	var cosmetic: String = Cosmetics.ids()[0]
	_check(not progress.can_buy_cosmetic(cosmetic) and not progress.buy_cosmetic(cosmetic) and not progress.can_buy_hat(progress.hats_left()[0]),
		"the SHOP sells nothing in the demo")
	_check(not progress.store_affordable("wheel") or progress.spin_cost() <= progress.tickets, "the wheel's '!' counts no SHOP goods")
	# Hard, HEAT.
	progress.hard_cleared.assign([1])
	_check(not progress.heat_unlocked(1), "HEAT is locked (hard level 1 cleared)")
	# Skins.
	progress.levels_cleared = 3
	_check(progress.is_skin_unlocked("ocean", false) and progress.is_skin_unlocked("lemon", false) and progress.is_skin_unlocked("lime", true),
		"demo skins: Lime..Ocean opaque, jelly Lime (and Mint: both hard level 1)")
	progress.levels_cleared = Levels.COUNT
	progress.hard_cleared.assign([1, 2, 3])
	_check(not progress.is_skin_unlocked("grape", false) and not progress.is_skin_unlocked("lemon", true) and not progress.is_skin_unlocked(Skins.CUSTOM, false),
		"full-game skins stay locked even on a full save (Grape, jelly Lemon, Chameleon)")
	# Randomizer: after level 3, its fixed mazes in turn, then replays.
	progress.reset_progress()
	progress.levels_cleared = 2
	_check(not progress.is_randomizer_unlocked(), "randomizer locked before level 3")
	progress.levels_cleared = 3
	_check(progress.is_randomizer_unlocked(), "randomizer open after level 3")
	var picked: Array[int] = []
	for won in Demo.RANDOM_SEEDS.size():
		progress.randoms_won = won
		progress.new_random_maze()
		picked.append(progress.random_seed)
		_check(progress.random_seed_fresh, "...maze %d is fresh (pays the full table)" % (won + 1))
	_check(picked == Demo.RANDOM_SEEDS, "the demo's mazes are its fixed seeds in order %s" % [picked])
	progress.randoms_won = Demo.RANDOM_SEEDS.size()
	progress.new_random_maze()
	_check(progress.random_seed == Demo.RANDOM_SEEDS[0] and not progress.random_seed_fresh, "...then they replay (replay pay)")
	var themes_ok := true
	for s in range(1, 300):
		themes_ok = themes_ok and Themes.for_seed(s) in Demo.themes()
	_check(themes_ok and Demo.themes() == ["dungeon", "mossy", "sandstone"], "random mazes use the demo's themes only")
	# Abilities in a maze: a full save's SPLAT / SLIMAKAZE don't work, RIFLE does.
	progress.abilities = {rifle = 1, splat = 2, kaze = 3}
	progress.tickets_lifetime = 5
	progress.start_random()
	var maze: Node2D = MAIN.instantiate()
	root.add_child(maze)
	await physics_frame
	var runner: Node = maze.get("abilities")
	_check(runner != null and runner.levels.keys() == ["rifle"], "in a demo maze only SLIME RIFLE works (%s)" % [runner.levels.keys() if runner else []])
	maze.free()
	progress.abilities = {}
	# Web knobs.
	Platform.override = "web"
	_check(not Demo.randomizer_open() and not Demo.hat_wheel_open() and Demo.levels() == Demo.WEB_LEVELS and not progress.is_randomizer_unlocked(),
		"web demo: no randomizer, no hat wheel, WEB_LEVELS levels")
	_check(Demo.full_only_paths(true).size() >= Demo.full_only_paths(false).size(), "the web list leaves out at least as much")
	Platform.override = ""
	_check(not Demo.wishlist_shown() and Demo.WISHLIST_URL == "", "WISHLIST is hidden while the URL is empty")
	# The exclude list: every level past 3, hard past 1, later themes' art and ambience, nothing of the demo's.
	var paths := Demo.full_only_paths()
	var demo_art := false
	for id in Demo.themes():
		demo_art = demo_art or Themes.atlas_path(id, "walls") in paths or ("res://assets/sounds/ambient_%s.wav" % id) in paths
	_check(Levels.data_path(4) in paths and Levels.data_path(10) in paths and not Levels.data_path(3) in paths
		and Levels.data_path(2, true) in paths and not Levels.data_path(1, true) in paths
		and Themes.atlas_path("volcanic", "border") in paths and "res://assets/sounds/ambient_sunken.wav" in paths and not demo_art,
		"full_only_paths: levels 4-10, hard 2-10, later themes' art + ambience; none of the demo's (%d paths)" % paths.size())
	var all_exist := true
	for path in paths:
		all_exist = all_exist and FileAccess.file_exists(path)
	_check(all_exist, "every listed path exists in the project")


# ---------------------------------------------------------------- 3b. the screens

func _check_screens() -> void:
	Platform.demo_override = 1
	progress.reset_progress()
	progress.levels_cleared = 3
	progress.highest_unlocked = 4
	progress.current_level = 4
	# Level select.
	var select: Control = await _open("res://scenes/level_select.tscn")
	var tiles: Array = select.level_buttons
	var full_ok := true
	for i in tiles.size():
		var full: bool = (tiles[i] as Button).has_meta("full_game")
		full_ok = full_ok and full == (i + 1 > 3) and (not full or not (tiles[i] as Button).disabled)
	_check(full_ok, "level select: tiles 4-10 carry the FULL GAME lock and open the end screen (enabled)")
	_check(select.get_viewport().gui_get_focus_owner() == tiles[2], "...the focus is on level 3 (the demo's last), not the locked 4")
	_check("FULL GAME" in select.info.text, "...the info lines name the full game (%s)" % select.info.text.replace("\n", " / "))
	select.hard_mode_box.button_pressed = true
	await _frames(2)
	_check(not select.heat_button.visible and (select.level_buttons[1] as Button).has_meta("full_game") and not (select.level_buttons[0] as Button).has_meta("full_game"),
		"hard mode: HEAT hidden, hard 2+ locked")
	select.hard_mode_box.button_pressed = false
	select.free()
	progress.hard_mode = false
	# Upgrades.
	for level in range(1, 4):
		progress.coins_found[level] = Levels.coin_keys(level).duplicate()
	progress.buy_upgrade("slime")
	progress.buy_upgrade("slime")
	var upg: Control = await _open("res://scenes/upgrades.tscn")
	var row: Dictionary = upg.rows["slime"]
	_check(row.cost.text == "FULL" and row.plus.disabled and not row.minus.disabled, "upgrades: MORE SLIME at %d shows FULL, + disabled" % Demo.UPGRADE_CAP)
	upg.free()
	# Skins.
	var skins: Control = await _open("res://scenes/skins.tscn")
	skins._refresh("grape")
	_check("FULL GAME" in skins.status.text, "skins: a full-game skin says so (%s)" % skins.status.text)
	skins._refresh("ocean")
	_check(not "FULL GAME" in skins.status.text, "...a demo skin doesn't")
	skins.free()
	# Hub: the archway's FULL GAME note.
	var hub: Node = await _open("res://scenes/hub.tscn")
	hub.near = hub._station("story")
	hub._show_prompt()
	_check(hub.prompt_key.text == "FULL GAME", "hub: the archway says FULL GAME when the next level is the full game's")
	_check(hub.wishlist_sign == null, "hub: no WISHLIST sign while the URL is empty")
	hub.free()
	# End screen.
	DemoEnd.from = DemoEnd.FROM_STORY
	var end: Control = await _open(DemoEnd.SCENE)
	_check(not end.wishlist_button.visible and end.keep_button.visible and end.get_viewport().gui_get_focus_owner() == end.keep_button,
		"end screen: WISHLIST hidden (no URL), KEEP PLAYING focused")
	_check(end.carry_label.text == "YOUR PROGRESS CARRIES OVER TO THE FULL GAME" and end.code_button == null, "...desktop: the carry-over line")
	var names: Array[String] = []
	for i in Demo.TEASER_LEVELS.size():
		end.show_card(i)
		names.append(end.area_label.text)
	_check(names.size() == 5 and names[0] == "SUNKEN SHRINE" and names[-1] == "VOLCANIC VAULT", "...teaser cards of later areas %s" % [names])
	var inside := true
	for control: Control in [end.keep_button, end.arrows[0], end.arrows[1]]:
		var rect := control.get_global_rect()
		inside = inside and rect.position.x >= UIKit.EDGE and rect.end.x <= UIKit.SCREEN.x - UIKit.EDGE and rect.end.y <= 177
	_check(inside, "...its buttons sit inside the screen edges")
	end.free()
	Platform.override = "web"
	end = await _open(DemoEnd.SCENE)
	_check(end.carry_label.text.begins_with("COPY YOUR SAVE CODE") and end.code_button != null and end.code_button.visible,
		"...web: SAVE CODE instead of a carry-over promise")
	end.free()
	Platform.override = ""
	# Pause menu: no seed typing, no WISHLIST while the URL is empty.
	progress.start_random()
	var maze: Node2D = MAIN.instantiate()
	root.add_child(maze)
	await physics_frame
	var pause: Node = maze.get_node_or_null("PauseMenu")
	if pause == null:
		for child in maze.get_children():
			if child.has_method("open") and child.get("seed_button") != null:
				pause = child
	if pause:
		pause.open()
		_check(not pause.seed_button.visible and not pause.wishlist_button.visible, "pause (demo maze): no seed typing, no WISHLIST without a URL")
		pause.resume()
	else:
		_check(false, "pause menu found")
	maze.free()
	get_root().get_tree().paused = false


# ---------------------------------------------------------------- 4. save carry-over

func _check_carry_over() -> void:
	var demo_path := throwaway_save("_demo")
	var full_path := throwaway_save("_full")
	# The demo writes its marker.
	Platform.demo_override = 1
	progress.reset_progress()
	progress.save_path = demo_path
	progress.demo_guard = false
	progress.complete_level(1)
	progress.complete_level(2)
	progress.complete_level(3)
	var file := ConfigFile.new()
	file.load(demo_path)
	_check(file.get_value("meta", "demo", false) == true, "the demo's save carries [meta] demo = true")
	var demo_code: String = progress.save_code()
	# The full game reads a demo save and drops the marker.
	Platform.demo_override = 0
	progress.save_path = test_save  # (RESET saves: never onto the file under test)
	progress.reset_progress()
	progress.save_path = demo_path
	progress.load_progress()
	_check(progress.levels_cleared == 3 and progress.highest_unlocked == 4 and not progress.demo_guard, "the full game loads a demo save fully (level 4 next)")
	progress.save_progress()
	file = ConfigFile.new()
	file.load(demo_path)
	_check(not file.has_section_key("meta", "demo") and file.get_value("progress", "levels_cleared") == 3, "...and its next save drops the marker")
	# A full-game save: the demo plays it in memory and never writes it.
	progress.reset_progress()
	progress.save_path = full_path
	for level in range(1, Levels.COUNT + 1):
		progress.complete_level(level, false)
	progress.upgrades = {slime = 7}
	progress.hard_cleared.assign([1, 2, 3, 4])
	progress.tickets = 40
	progress.save_progress()
	var before := FileAccess.get_md5(full_path)
	var full_code: String = progress.save_code()
	Platform.demo_override = 1
	progress.save_path = test_save
	progress.reset_progress()
	progress.save_path = full_path
	progress.load_progress()
	_check(progress.demo_guard and progress.levels_cleared == Levels.COUNT and not Demo.level_open(5), "the demo loads a full save (guarded, shows only demo content)")
	progress.complete_level(2)
	progress.buy_upgrade("speed")
	progress.reset_progress()
	progress.save_progress()
	_check(FileAccess.get_md5(full_path) == before, "...and never writes it (byte-identical after play and RESET)")
	# Codes: a demo code in the full game, a full code in the demo.
	Platform.demo_override = 0
	progress.demo_guard = false
	progress.save_path = demo_path
	_check(progress.load_code(demo_code) and progress.levels_cleared == 3 and not progress.demo_guard, "the full game loads a demo save code")
	file = ConfigFile.new()
	file.load(demo_path)
	_check(not file.has_section_key("meta", "demo"), "...and saves it without the marker")
	Platform.demo_override = 1
	before = FileAccess.get_md5(demo_path)
	_check(progress.load_code(full_code) and progress.demo_guard and progress.levels_cleared == Levels.COUNT, "the demo loads a full-game code, guarded")
	_check(FileAccess.get_md5(demo_path) == before, "...and doesn't write it over the save")
	# A guarded demo (the real file is a full save) given a DEMO code: still guarded, the file untouched.
	_check(progress.load_code(demo_code) and progress.demo_guard and progress.levels_cleared == 3, "a demo code pasted into a guarded demo keeps the guard")
	_check(FileAccess.get_md5(demo_path) == before, "...and the full save is still byte-identical")
	progress.demo_guard = false
	Platform.demo_override = 0
	progress.save_path = test_save


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame
