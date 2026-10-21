extends "res://tests/suite_base.gd"

## The demo build (scripts/demo.gd, docs/demo-plan.md): one switch (Platform.is_demo, forced here with
## Platform.demo_override) and its gates. Checks, in this order:
## 1. a stripped demo export: with Demo.strip_test on, levels 1-4 are played to the chalice by the autopilot
##    and the last one leads (CONTINUE only, the first time) to the end screen; nothing full-only was asked
##    for or loaded (no level 5+ / hard 2+ data, no later theme art or ambience in the resource cache);
## 2. the full game with the switch off: every knob is the full game's, saves carry no demo marker;
## 3. every lock: levels (level select + archway), the per-upgrade caps (and their coin math), abilities (only
##    SLIME RIFLE, in the shop and in a maze), hard (level 1 only), randomizer (after level 4, new random
##    mazes, demo themes), the hat wheel (shut until the end screen, then a free spin, at most HATS_MAX hats),
##    SHOP, skins, the web knobs; the title's DEMO sticker (demo only, at its constant, clear of the logo's
##    letters and ENTER THE HUB); the end screen (WISHLIST hidden while the URL is empty, teaser cards) and the
##    pause menu; no screen says the demo's progress carries over (end screen, SETTINGS, RESET confirm);
##    locked level tiles are plain locks (no FULL text) and pressing one does nothing;
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
	# Randomizer mazes, played stripped too: each attempt a new random maze (seed, start) in a demo theme.
	var seen := {}
	var starts := {}
	for attempt in 6:
		if attempt == 0:
			progress.start_random()
		else:
			progress.new_random_maze()  # (NEW MAZE after a dry-up or a win)
		var maze: Node2D = MAIN.instantiate()
		root.add_child(maze)
		await physics_frame
		_check(maze.is_random() and maze.theme in Demo.themes() and progress.random_seed_fresh,
			"demo maze %d: random seed %d, a demo theme (%s), fresh" % [attempt + 1, progress.random_seed, maze.theme])
		seen[progress.random_seed] = maze.theme
		starts[maze.maze.start] = true
		maze.free()
	_check(seen.size() == 6 and starts.size() >= 2, "consecutive demo mazes differ: %d seeds, %d starts, themes %s" % [seen.size(), starts.size(), seen.values()])
	_check(Demo.denied.is_empty(), "...no full-only data asked for by the random mazes (%s)" % [Demo.denied])
	# A full-only level asked for anyway (a hand-made save, a bug) never crashes and is never built.
	progress.current_level = 7
	var forced: Node2D = MAIN.instantiate()
	forced.level = 7
	root.add_child(forced)
	await physics_frame
	_check(forced.level == Demo.LEVELS, "a full-game level falls back to the demo's last level (%d)" % forced.level)
	forced.free()
	_check(not Levels.has_data(Demo.LEVELS + 1) and Levels.has_data(Demo.LEVELS) and not Levels.has_data(2, true) and Levels.has_data(1, true),
		"stripped: Levels.has_data sees levels 1-%d and hard 1 only" % Demo.LEVELS)
	_check(Story.level_line(Demo.LEVELS + 1) == "" and Story.level_line(Demo.LEVELS) != "", "stripped: no banner line for level %d" % (Demo.LEVELS + 1))
	Demo.strip_test = false
	Demo.denied.clear()


## A stripped demo showing a FULL save's menus (someone who owns both): level select, map table, hub (coin board,
## tour lines), skins, upgrades, settings and the end screen opened from a FULL GAME tile. Nothing
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
	progress.best_times = {5: 40.0, 108: 70.0}
	progress.medals = {5: 3, 8: 2}
	progress.coins_found[8] = ["1,1", "2,3"]
	progress.upgrades = {slime = 7, speed = 4}
	progress.abilities = {splat = 2}
	progress.demo_guard = true
	for hard in [false, true]:
		progress.hard_mode = hard
		var select: Control = await _open("res://scenes/level_select.tscn")
		select.free()
		var maps: Control = await _open("res://scenes/maps.tscn")
		maps.free()
	progress.hard_mode = false
	var hub: Node = await _open("res://scenes/hub.tscn")
	hub.open_coin_board()
	await _frames(2)
	_check(_coin_bag_ok(hub, true), "full save, hub coin bag: levels 5-10 show ?/?, the total only the demo's (%s)" % hub.board_total.text)
	for web in [false, true]:
		Platform.override = "web" if web else ""
		progress.medals = {1: 3, 2: 1, 4: 2, 5: 3, 8: 2}
		hub._refresh_tickets()
		var want := "6/12"  # (4 levels on both since 2026-10-21)
		_check(hub.medal_label.text == want, "%s demo hub medals: only the demo's levels, earned and total (%s, want %s)" % ["web" if web else "desktop", hub.medal_label.text, want])
	Platform.override = ""
	Platform.demo_override = 0
	hub._refresh_tickets()
	_check(hub.medal_label.text == "11/30", "full game hub medals: every level, out of 30 (%s)" % hub.medal_label.text)
	Platform.demo_override = 1
	progress.medals = {5: 3, 8: 2}
	hub.close_coin_board()
	hub.free()
	for path in ["res://scenes/skins.tscn", "res://scenes/upgrades.tscn"]:
		var screen: Node = await _open(path)
		screen.free()
	var settings: Node = await _open("res://scenes/controls.tscn")
	var said := _save_talk(_texts(settings, false), ["SAVE CODE"])  # (the page's own SAVE CODE button and panel title)
	_check(settings.get_node_or_null("DemoGuardNote") == null and said.is_empty(), "guarded: SETTINGS and the RESET confirm say nothing about the full save (%s)" % [said])
	settings.free()
	progress.demo_guard = false
	# The hub tour's lines in the demo (desktop: CLEAR / BEAT 4; web: the stations that are off say FULL GAME).
	var tour: Node = load("res://scripts/hub_tour.gd").new()
	progress.levels_cleared = 0
	_check(tour.station_line("random") == "LOCKED: BEAT %d LEVELS FIRST" % Demo.LEVELS, "demo tour: the portal asks for the demo's %d levels (%s)" % [Demo.LEVELS, tour.station_line("random")])
	_check(tour.station_line("wheel") == "SPIN FOR HATS AFTER LEVEL %d" % Demo.LEVELS, "demo tour: the wheel opens after the last level, no free-spin promise yet (%s)" % tour.station_line("wheel"))
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
	_check(Demo.upgrade_cap("slime") == Upgrades.max_level("slime") and Demo.shop_open()
		and Demo.randomizer_open() and Demo.hat_wheel_open() and Demo.ability_open("kaze") and Demo.skin_open("ember", true)
		and Demo.skin_open(Skins.RAINBOW, false), "switch off: no cap, SHOP, randomizer, wheel, every ability and skin")
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
	_check(Demo.levels() == 4 and Demo.hard_levels() == 1 and not Demo.level_open(5) and Demo.level_open(4)
		and not Demo.level_open(2, true) and Demo.level_open(1, true), "demo: levels 1-4, hard level 1")
	# Upgrades: each stops at its own cap (MORE SLIME 3, SPEED 2, BRIGHTNESS 1, the dev wall power 0), at the
	# demo's own prices, which add up to exactly the coins its levels hide (desktop 34, web 22).
	_check(Demo.upgrade_cap("slime") == 3 and Demo.upgrade_cap("speed") == 2 and Demo.upgrade_cap("brightness") == 1 and Demo.upgrade_cap("power") == 0,
		"demo caps: MORE SLIME 3, SPEED 2, BRIGHTNESS 1, anything else 0")
	_check(Upgrades.cost("slime", 0) == 1 and Upgrades.cost("slime", 2) == 6 and Upgrades.cost("speed", 1) == 8 and Upgrades.cost("slime", 3) == 0
		and Upgrades.total_cost("speed", 4) == 14, "demo prices: Demo.PRICES (slime 3rd level 6, speed 2nd 8, none past the cap)")
	for web in [false, true]:
		Platform.override = "web" if web else ""
		var hidden := 0
		for level in range(1, Demo.levels() + 1):
			hidden += Levels.COINS[level - 1]
		var priced := 0
		var lists_fit := true
		for upgrade: Dictionary in Upgrades.LIST:
			var id: String = upgrade.id
			priced += Upgrades.total_cost(id, Upgrades.max_level(id))
			lists_fit = lists_fit and (upgrade.get("dev", false) or Demo.prices(id).size() == Demo.upgrade_cap(id))
		var name := "web" if web else "desktop"
		_check(lists_fit and hidden == Demo.coins_total() and priced == hidden and hidden == 34,
			"%s demo: one price per capped level, prices %d == coins in levels 1-%d %d" % [name, priced, Demo.levels(), hidden])
		progress.upgrades = {}
		progress.coins_found.clear()
		for level in range(1, Demo.levels() + 1):
			progress.coins_found[level] = Levels.coin_keys(level).duplicate()
		var bought := {}
		for id: String in ["slime", "speed", "brightness", "power"]:
			while progress.buy_upgrade(id):
				bought[id] = int(bought.get(id, 0)) + 1
		var caps: Dictionary = Demo.WEB_UPGRADE_CAPS if web else Demo.UPGRADE_CAPS
		_check(bought == caps and progress.upgrades == caps and progress.coins() == 0 and progress.coins_spent() == hidden,
			"%s demo: every coin buys every capped level, 0 left (%s, %d left)" % [name, bought, progress.coins()])
		var refunded := 0
		while progress.refund_upgrade("slime"):
			refunded += 1
		_check(refunded == int(caps.slime) and progress.coins() == Upgrades.total_cost("slime", int(caps.slime)),
			"%s demo: refunds return the demo prices (%d coins)" % [name, progress.coins()])
	Platform.override = ""
	progress.upgrades = {}
	progress.coins_found.clear()
	for level in range(1, Demo.LEVELS + 1):
		progress.coins_found[level] = Levels.coin_keys(level).duplicate()
	# Abilities: only SLIME RIFLE.
	progress.tickets = 60
	progress.tickets_lifetime = 60
	_check(progress.can_buy_ability("rifle") and not progress.can_buy_ability("splat") and not progress.can_buy_ability("kaze"),
		"abilities: only SLIME RIFLE can be bought")
	var rifle_1 := Abilities.cost("rifle", 0)
	_check(rifle_1 == int(Demo.ABILITY_PRICES.rifle[0]) and rifle_1 <= Economy.RANDOM_ATTEMPT_PAY[0] 			and Abilities.cost("rifle", 1) == int(Economy.ABILITIES.rifle.costs[1]) and Abilities.total_cost("rifle", 2) == rifle_1 + int(Economy.ABILITIES.rifle.costs[1]),
		"SLIME RIFLE level 1 costs %d tickets in the demo (one first-try randomizer win pays %d), later levels the full price" % [rifle_1, Economy.RANDOM_ATTEMPT_PAY[0]])
	# SHOP.
	progress.spins = 20
	var cosmetic: String = Cosmetics.ids()[0]
	_check(not progress.can_buy_cosmetic(cosmetic) and not progress.buy_cosmetic(cosmetic) and not progress.can_buy_hat(progress.hats_left()[0]),
		"the SHOP sells nothing in the demo")
	_check(not progress.store_affordable("wheel") or progress.spin_cost() <= progress.tickets, "the wheel's '!' counts no SHOP goods")
	progress.hard_cleared.assign([1])
	# Skins.
	progress.levels_cleared = Demo.LEVELS
	_check(progress.is_skin_unlocked("grape", false) and progress.is_skin_unlocked("lemon", false) and progress.is_skin_unlocked("lime", true),
		"demo skins: Lime..Grape opaque (Grape: level 4's reward), jelly Lime (and Mint: both hard level 1)")
	progress.levels_cleared = Levels.COUNT
	progress.hard_cleared.assign([1, 2, 3])
	_check(not progress.is_skin_unlocked("crimson", false) and not progress.is_skin_unlocked("lemon", true) and not progress.is_skin_unlocked(Skins.CUSTOM, false),
		"full-game skins stay locked even on a full save (Crimson, jelly Lemon, Chameleon)")
	Platform.override = "web"
	_check(progress.is_skin_unlocked("grape", false) and not progress.is_skin_unlocked("crimson", false), "web demo (4 levels, like the desktop): Grape is earnable, Crimson stays locked")
	Platform.override = ""
	# Hat wheel: shut until the end screen was seen, then the first spin is free, later ones cost tickets,
	# up to HATS_MAX hats.
	progress.reset_progress()
	progress.levels_cleared = Demo.LEVELS - 1
	progress.tickets = 200
	_check(progress.demo_wheel_block() == "closed" and not progress.can_spin_hats() and progress.spin_hat(0.5) == "" and not progress.store_affordable("wheel"),
		"hat wheel: shut before the demo is completed (no spin, no '!')")
	progress.dev_tools = true
	_check(not progress.can_spin_hats(), "...dev mode doesn't open it either")
	progress.dev_tools = false
	progress.levels_cleared = Demo.LEVELS
	_check(progress.demo_wheel_block() == "" and not progress.has_seen_story(Demo.END_SEEN_BIT),
		"...open once level %d is cleared, even if the game closed on the win row (end screen not seen)" % Demo.LEVELS)
	progress.levels_cleared = 0
	progress.mark_story_seen(Demo.END_SEEN_BIT)
	_check(progress.demo_wheel_block() == "" and progress.spin_cost() == 0 and progress.can_spin_hats(), "...open after the end screen, the first spin free")
	progress.levels_cleared = Demo.LEVELS
	var wheel_won: Array[String] = []
	for i in Demo.HATS_MAX + 2:
		var hat: String = progress.spin_hat(0.5)
		if hat != "":
			wheel_won.append(hat)
	_check(wheel_won.size() == Demo.HATS_MAX and progress.hats_owned.size() == Demo.HATS_MAX and progress.tickets == 200 - progress.spin_cost_after(1),
		"...%d hats won (free + %d tickets), then no more spins (%s)" % [wheel_won.size(), progress.spin_cost_after(1), wheel_won])
	_check(progress.demo_wheel_block() == "full" and not progress.can_spin_hats() and not progress.store_affordable("wheel") and not progress.hats_left().is_empty(),
		"...at HATS_MAX: blocked though hats are left, no '!'")
	progress.hats_owned.assign(Hats.ids().slice(0, 5))
	_check(not progress.can_spin_hats() and progress.spin_hat(0.5) == "" and progress.hats_owned.size() == 5, "...a save with more hats (a full save) just can't spin")
	Platform.demo_override = 0
	_check(progress.demo_wheel_block() == "" and progress.can_spin_hats(), "switch off: the wheel spins as always")
	Platform.demo_override = 1
	# Randomizer: after level 4, new random mazes (as the full game), the end screen after RANDOM_WINS wins.
	progress.reset_progress()
	progress.levels_cleared = Demo.LEVELS - 1
	_check(not progress.is_randomizer_unlocked(), "randomizer locked before level %d" % Demo.LEVELS)
	progress.levels_cleared = Demo.LEVELS
	_check(progress.is_randomizer_unlocked(), "randomizer open after level %d" % Demo.LEVELS)
	var picked := {}
	var fresh := true
	for won in [0, 0, 1, Demo.RANDOM_WINS, Demo.RANDOM_WINS + 2]:  # (a dry-up keeps the wins: still a new maze)
		progress.randoms_won = won
		progress.new_random_maze()
		picked[progress.random_seed] = true
		fresh = fresh and progress.random_seed_fresh
	_check(picked.size() == 5 and fresh, "every demo maze is a new random seed, fresh (pays the full table), wins or not (%s)" % [picked.keys()])
	var gentle := true
	var steep := 0
	for won in Demo.GENTLE_MAZES + 1:
		progress.randoms_won = won
		for i in 40:
			progress.new_random_maze()
			var u := Levels.random_usage_permille(progress.random_seed)
			if won < Demo.GENTLE_MAZES:
				gentle = gentle and u <= Demo.GENTLE_MAX_USAGE
			elif u > Demo.GENTLE_MAX_USAGE:
				steep += 1
	_check(gentle and steep > 0, "the first %d demo mazes ask for at most %d%% of the meter, later ones any amount (%d of 40 steeper)"
		% [Demo.GENTLE_MAZES, Demo.GENTLE_MAX_USAGE / 10, steep])
	progress.randoms_won = 0
	var theme_seen := {}
	for s in range(1, 300):
		theme_seen[Themes.for_seed(s)] = true
	_check(theme_seen.size() == Demo.themes().size(), "...drawn from every demo theme (%s)" % [theme_seen.keys()])
	var themes_ok := true
	for s in range(1, 300):
		themes_ok = themes_ok and Themes.for_seed(s) in Demo.themes()
	_check(themes_ok and Demo.themes() == ["dungeon", "mossy", "sandstone", "sunken"], "random mazes use the demo's themes only (%s)" % [Demo.themes()])
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
	_check(Demo.WEB_LEVELS == Demo.LEVELS and Demo.full_only_paths(true) == Demo.full_only_paths(false), "the web demo has the desktop's 4 levels and cuts the same files")
	_check(Demo.themes() == ["dungeon", "mossy", "sandstone", "sunken"] and Demo.teasers() == [5, 6, 7, 9, 10], "web demo: 4 themes, teasers from level 5 %s" % [Demo.teasers()])
	var web_cut := Demo.export_cut(true)
	_check(not Levels.data_path(4) in web_cut and not Themes.atlas_path("sunken", "walls") in web_cut and Levels.data_path(5) in web_cut,
		"level 4 + Sunken Shrine ship in the web demo, level 5 is cut")
	Platform.override = ""
	_check(Demo.teasers() == [5, 6, 7, 9, 10], "desktop demo: teasers from level 5 %s" % [Demo.teasers()])
	_check(not Demo.wishlist_shown() and Demo.store_url() == "", "WISHLIST is hidden while there is no store page")
	# The exclude list: every level past 3, hard past 1, later themes' art and ambience, nothing of the demo's.
	var paths := Demo.full_only_paths()
	var demo_art := false
	for id in Demo.themes():
		demo_art = demo_art or Themes.atlas_path(id, "walls") in paths or ("res://assets/sounds/ambient_%s.wav" % id) in paths
	_check(Levels.data_path(5) in paths and Levels.data_path(10) in paths and not Levels.data_path(4) in paths
		and Levels.data_path(2, true) in paths and not Levels.data_path(1, true) in paths
		and Themes.atlas_path("volcanic", "border") in paths and "res://assets/sounds/ambient_sewers.wav" in paths and not demo_art,
		"full_only_paths: levels 5-10, hard 2-10, later themes' art + ambience; none of the demo's (%d paths)" % paths.size())
	var all_exist := true
	for path in paths:
		all_exist = all_exist and FileAccess.file_exists(path)
	_check(all_exist, "every listed path exists in the project")


# ---------------------------------------------------------------- 3b. the screens

func _check_screens() -> void:
	Platform.demo_override = 1
	progress.reset_progress()
	progress.levels_cleared = Demo.LEVELS
	progress.highest_unlocked = Demo.LEVELS + 1
	progress.current_level = Demo.LEVELS + 1
	# Title: the DEMO sticker (demo builds only), at its constant, inside the screen, clear of ENTER THE HUB and
	# below the logo's letters (only its drips may run under it).
	var title: Control = await _open("res://scenes/title.tscn")
	var title_script: GDScript = title.get_script()
	var sticker: TextureRect = title.get_node_or_null("DemoSticker")
	_check(sticker != null and sticker.visible and sticker.texture != null and sticker.position == title_script.DEMO_STICKER_POS,
		"title: the DEMO sticker is shown in the demo, at DEMO_STICKER_POS")
	if sticker:
		var rect := Rect2(sticker.position, sticker.texture.get_size())
		var logo: TextureRect = title.get_node("Logo")
		_check(Rect2(Vector2.ZERO, UIKit.SCREEN).encloses(rect) and rect.position == rect.position.round(), "...whole pixels, inside the screen (%s)" % rect)
		_check(not rect.intersects(title.enter_button.get_global_rect()), "...clear of ENTER THE HUB (%s / %s)" % [rect, title.enter_button.get_global_rect()])
		_check(rect.position.y >= logo.position.y + title_script.LOGO_LETTER_ROWS, "...under the logo's letters (top %d, letters end %d)" % [rect.position.y, logo.position.y + title_script.LOGO_LETTER_ROWS])
		_check((sticker.material as ShaderMaterial).shader == (logo.material as ShaderMaterial).shader, "...its letters take the skin (the logo's skin shader)")
	title.free()
	Platform.demo_override = 0
	title = await _open("res://scenes/title.tscn")
	_check(title.get_node_or_null("DemoSticker") == null, "title: no DEMO sticker in the full game")
	title.free()
	Platform.demo_override = 1
	# Level select.
	var select: Control = await _open("res://scenes/level_select.tscn")
	var tiles: Array = select.level_buttons
	_check(_plain_locks(tiles, Demo.LEVELS), "level select: tiles 5-10 are plain locks (disabled, the dim lock, no FULL text)")
	_check(select.get_viewport().gui_get_focus_owner() == tiles[Demo.LEVELS - 1], "...the focus is on level 4 (the demo's last), not the locked 5")
	_check(not "FULL" in select.info.text, "...the info lines don't name the full game (%s)" % select.info.text.replace("\n", " / "))
	var before_level: int = progress.current_level
	(tiles[Demo.LEVELS] as Button).pressed.emit()
	select._play(6)
	await _frames(2)
	var transition := root.get_node_or_null("Transition")
	_check(progress.current_level == before_level and (transition == null or not transition.busy) and select.is_inside_tree(),
		"...pressing a locked tile does nothing (no end screen, no level)")
	var normal_box: Vector2 = select.hard_mode_box.position
	var normal_panel: Rect2 = Rect2(select.info_panel.position, select.info_panel.size)
	var normal_top: float = select.info.offset_top
	select.hard_mode_box.button_pressed = true
	await _frames(2)
	var one_line := UIKit.text_block_h(1)
	var spare := UIKit.text_block_h(2) - one_line
	_check(select.info.text.count("\n") == 0 and select.info.offset_top == normal_top + floori(spare / 2.0)
		and select.hard_mode_box.position == normal_box and Rect2(select.info_panel.position, select.info_panel.size) == normal_panel,
		"...hard's one info line sits in the middle of the two-line block (top %d, normal %d), the panel and checkbox stay put" % [select.info.offset_top, normal_top])
	_check(_plain_locks(select.level_buttons, 1), "hard mode: hard 2+ plain locks")
	_check(not "FULL" in select.info.text, "...no FULL GAME line on hard either (%s)" % select.info.text.replace("\n", " / "))
	select.hard_mode_box.button_pressed = false
	select.free()
	progress.hard_mode = false
	# Upgrades: every row at its cap shows FULL.
	for level in range(1, Demo.LEVELS + 1):
		progress.coins_found[level] = Levels.coin_keys(level).duplicate()
	for id in ["slime", "speed", "brightness"]:
		while progress.buy_upgrade(id):
			pass
	var upg: Control = await _open("res://scenes/upgrades.tscn")
	for id: String in ["slime", "speed", "brightness"]:
		var row: Dictionary = upg.rows[id]
		_check(row.cost.text == "FULL" and row.plus.disabled and not row.minus.disabled, "upgrades: %s at %d shows FULL, + disabled" % [id, Demo.upgrade_cap(id)])
	_check("MORE UPGRADE LEVELS" in upg.hint.text, "...the hint says more levels are in the full game (%s)" % upg.hint.text.replace("\n", " / "))
	upg.free()
	# Skins.
	var skins: Control = await _open("res://scenes/skins.tscn")
	skins._refresh("crimson")
	_check("FULL GAME" in skins.status.text, "skins: a full-game skin says so (%s)" % skins.status.text)
	skins._refresh("grape")
	_check(not "FULL GAME" in skins.status.text, "...a demo skin doesn't")
	skins.free()
	# Hub: the archway on a full-game level is plainly LOCKED.
	var hub: Node = await _open("res://scenes/hub.tscn")
	hub.open_coin_board()
	_check(_coin_bag_ok(hub, true) and hub.board_total.text.begins_with("STORY 34/34 "),
		"hub coin bag (demo): ?/? past level %d, STORY 34/34 (%s)" % [Demo.LEVELS, hub.board_total.text])
	hub.close_coin_board()
	Platform.demo_override = 0
	var full_hub: Node = await _open("res://scenes/hub.tscn")
	full_hub.open_coin_board()
	_check(_coin_bag_ok(full_hub, false) and "/%d " % Levels.total_coins() in full_hub.board_total.text,
		"hub coin bag (switch off): every level's numbers, the story total %d (%s)" % [Levels.total_coins(), full_hub.board_total.text])
	full_hub.free()
	Platform.demo_override = 1
	hub.near = hub._station("story")
	hub._show_prompt()
	_check(hub.prompt_key.text == "LOCKED" and not "FULL" in hub.prompt_name.text, "hub: the archway says LOCKED (no FULL GAME) when the next level is the full game's (%s / %s)" % [hub.prompt_name.text, hub.prompt_key.text])
	_check(hub.wishlist_sign == null, "hub: no WISHLIST sign while the URL is empty")
	# Hub: the hat wheel before the demo is completed (LOCKED, CLEAR LEVEL 4, the overlay stays shut) and at HATS_MAX.
	progress.levels_cleared = Demo.LEVELS - 1
	hub.near = hub._station("wheel")
	hub._show_prompt()
	_check(hub.prompt_key.text == "LOCKED" and not hub.prompt_bang.visible, "hub: the wheel says LOCKED before the end screen (%s)" % hub.prompt_key.text)
	hub._use(hub.near)
	_check(not hub.hat_wheel.visible and hub.prompt_key.text == "CLEAR LEVEL %d" % Demo.LEVELS, "...using it: CLEAR LEVEL %d, the wheel stays shut (%s)" % [Demo.LEVELS, hub.prompt_key.text])
	hub.free()
	progress.levels_cleared = Demo.LEVELS
	hub = await _open("res://scenes/hub.tscn")
	hub.near = hub._station("wheel")
	hub._show_prompt()
	_check(hub.prompt_key.text == "FREE", "hub: after the end screen the first spin is FREE (%s)" % hub.prompt_key.text)
	var tour: Node = load("res://scripts/hub_tour.gd").new()
	_check(tour.station_line("wheel") == "SPIN FOR HATS, THE FIRST IS FREE", "...the tour says so now (%s)" % tour.station_line("wheel"))
	progress.hats_owned.assign(Hats.ids().slice(0, Demo.HATS_MAX))
	progress.spins = Demo.HATS_MAX
	progress.tickets = 100
	hub._show_prompt()
	_check(hub.prompt_key.text == "LOCKED" and tour.station_line("wheel") == "NO MORE HATS IN THE DEMO", "hub: at HATS_MAX the wheel says LOCKED, the tour NO MORE HATS IN THE DEMO")
	tour.free()
	hub._use(hub.near)
	await _frames(2)
	_check(hub.hat_wheel.visible and hub.hat_wheel.spin_button.disabled and hub.hat_wheel.result.text == "NO MORE HATS IN THE DEMO",
		"...the wheel opens with SPIN disabled and says why (%s)" % hub.hat_wheel.result.text)
	hub.close_hat_wheel()
	hub.free()
	progress.hats_owned.clear()
	progress.spins = 0
	progress.story_seen &= ~Demo.END_SEEN_BIT
	# End screen.
	DemoEnd.from = DemoEnd.FROM_STORY
	var end: Control = await _open(DemoEnd.SCENE)
	_check(not end.wishlist_button.visible and end.keep_button.visible and end.get_viewport().gui_get_focus_owner() == end.keep_button,
		"end screen: WISHLIST hidden (no URL), KEEP PLAYING focused")
	_check(end.random_hint != null and end.random_hint.text == "NOW TRY THE RANDOMIZER IN THE HUB"
		and end.random_hint.get_global_rect().end.y <= UIKit.BOTTOM_ROW_Y,
		"...after the story it points at the randomizer, above KEEP PLAYING")
	DemoEnd.from = DemoEnd.FROM_RANDOM
	_check(not DemoEnd.random_hint_shown(), "...not after the randomizer's own end")
	DemoEnd.from = DemoEnd.FROM_STORY
	Platform.override = "web"
	_check(not DemoEnd.random_hint_shown(), "...not on the web demo (no randomizer there)")
	Platform.override = ""
	var said := _save_talk(_texts(end))
	_check(said.is_empty(), "...desktop: no line about progress carrying over (%s)" % [said])
	var names: Array[String] = []
	for i in Demo.teasers().size():
		end.show_card(i)
		names.append(end.area_label.text)
	_check(names.size() == 5 and names[0] == "TOXIC TUNNELS" and names[-1] == "VOLCANIC VAULT", "...teaser cards of later areas %s" % [names])
	end.show_card(0)
	_check(end.feature_label.text == "6 MORE AREAS", "...the first card counts the areas past the demo (%s)" % end.feature_label.text)
	# Teasers name only full-game content (QA must-fix 4): nothing the demo already gives, no HEAT.
	var lines: Array[String] = [DemoEnd.top_line(DemoEnd.FROM_RANDOM)]
	for i in Demo.teasers().size():
		end.show_card(i)
		lines.append(end.feature_label.text)
	var banned: Array[String] = []
	for text in lines:
		for word in ["HEAT", "ENDLESS", "JELLY", "HATS", "LOOP", "HARD MODE", "NEW ABILITIES"]:
			if word in text:
				banned.append("%s (%s)" % [text, word])
	_check(banned.is_empty() and "2 MORE ABILITIES" in lines and "9 MORE HARD LEVELS" in lines
		and lines[0] == "THE FULL GAME ADDS 2 ABILITIES AND THE SHOP", "...teaser lines only name full-game content %s %s" % [lines, banned])
	var inside := true
	for control: Control in [end.keep_button, end.arrows[0], end.arrows[1]]:
		var rect := control.get_global_rect()
		inside = inside and rect.position.x >= UIKit.EDGE and rect.end.x <= UIKit.SCREEN.x - UIKit.EDGE and rect.end.y <= 177
	_check(inside, "...its buttons sit inside the screen edges")
	end.free()
	Platform.override = "web"
	end = await _open(DemoEnd.SCENE)
	said = _save_talk(_texts(end))
	_check(said.is_empty(), "...web: no save-code pitch either (%s)" % [said])
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
	# A demo save from older, higher caps (SPEED 2): loaded back to today's caps, the coins return.
	var old_path := throwaway_save("_oldcaps")
	progress.save_path = old_path
	for level in range(1, Demo.LEVELS + 1):
		progress.coins_found[level] = Levels.coin_keys(level).duplicate()
	progress.upgrades = {slime = 4, speed = 2, brightness = 1}  # (over today's MORE SLIME cap)
	progress.save_progress()
	progress.save_path = test_save
	progress.reset_progress()
	progress.save_path = old_path
	progress.load_progress()
	_check(not progress.demo_guard and progress.upgrades == Demo.UPGRADE_CAPS and progress.coins() == 0,
		"an older demo save is clamped to today's caps on load (%s, %d coins in hand)" % [progress.upgrades, progress.coins()])
	Platform.override = "web"  # the web demo: its caps and prices (the desktop's: 34 coins in levels 1-4)
	progress.save_path = test_save
	progress.reset_progress()
	progress.save_path = old_path
	progress.load_progress()
	_check(progress.upgrades == Demo.WEB_UPGRADE_CAPS and progress.coins_earned_here() == 34 and progress.coins() == 0 and not progress.upgrade_buyable(),
		"...the web demo clamps it to its caps, counts only levels 1-4 (%s, %d of 34 found, %d in hand)" % [progress.upgrades, progress.coins_earned_here(), progress.coins()])
	Platform.override = ""
	Platform.demo_override = 0
	progress.save_path = test_save
	progress.reset_progress()
	progress.save_path = old_path
	progress.load_progress()
	# Full prices: slime 3 = 12, speed 2 = 15, brightness 1 = 9 = 36 > 34 found: the priciest top step goes.
	_check(progress.upgrades == {slime = 3, speed = 1, brightness = 1} and progress.coins() == 34 - 27,
		"...the full game refits it to its prices a level at a time (%s, %d in hand)" % [progress.upgrades, progress.coins()])
	Platform.demo_override = 1
	progress.save_path = demo_path
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
	for level in range(1, Levels.COUNT + 1):
		progress.coins_found[level] = Levels.coin_keys(level).duplicate()
	progress.upgrades = {slime = 7, speed = 4}
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
	_check(progress.upgrades == {slime = 7, speed = 4}, "...its upgrades are left alone (in memory only; %s)" % [progress.upgrades])
	# Demo coin math on it: only levels 1-4's coins (34), only the levels within the caps cost (11 + 14).
	_check(progress.coins_earned_here() == 34 and progress.coins() == 34 - 25 and progress.upgrade_buyable(),
		"...its hand counts only the demo's coins and capped levels (%d in hand, BRIGHTNESS 1 buyable)" % progress.coins())
	progress.refund_upgrade("slime")
	_check(progress.upgrade_level("slime") == 6 and progress.coins() == 9, "...a level above the cap refunds nothing (%d in hand)" % progress.coins())
	progress.upgrades = {slime = 7, speed = 4, brightness = 3}  # a maxed full save
	_check(progress.coins() == 0 and progress.coins() <= Demo.coins_total() and not progress.upgrade_buyable(),
		"...maxed: 0 in hand (not 165 - 34), nothing buyable (no R-prompt nag)")
	Platform.override = "web"
	_check(progress.coins_earned_here() == 34 and progress.coins() == 0 and not progress.upgrade_buyable(), "...web demo, maxed: 0 in hand of 34")
	progress.upgrades = {slime = 7, speed = 4}
	_check(progress.coins() == 22 - 6 - 7 and progress.upgrade_buyable(), "...web demo, no BRIGHTNESS: %d in hand at WEB_PRICES" % progress.coins())
	Platform.override = ""
	progress.save_path = test_save
	progress.reset_progress()
	progress.save_path = full_path
	Platform.override = "web"  # a guarded full save whose capped levels cost more than its demo coins: left alone, hand 0
	progress.load_progress()
	progress.coins_found.clear()
	_check(progress.upgrades == {slime = 7, speed = 4} and progress.coins() == 0, "...web, no demo coins found: upgrades kept, hand 0 (never negative)")
	Platform.override = ""
	progress.load_progress()
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


## Every Label / Button text under `node` (only the visible ones, unless `visible_only` is false: the
## SETTINGS page's closed RESET confirm counts too).
func _texts(node: Node, visible_only := true) -> Array[String]:
	var out: Array[String] = []
	for child in node.find_children("*", "Control", true, false):
		if visible_only and not (child as Control).is_visible_in_tree():
			continue
		if (child is Label or child is Button) and child.text != "":
			out.append(child.text)
	return out


## The texts that talk about the demo's progress / save reaching (or being kept from) the full game.
func _save_talk(texts: Array[String], allowed: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	for text in texts:
		if text in allowed:
			continue
		for word in ["CARRIES", "CARRY", "KEEP YOUR PROGRESS", "SAVE CODE", "FULL GAME SAVE", "THE DEMO WON'T", "THIS SESSION"]:
			if word in text:
				out.append(text)
				break
	return out


## The hub's coin bag rows: "?/?" (dim) past the demo's levels when `demo`, else "found/total" for every
## level; the total line never names the full game's 165 in the demo.
func _coin_bag_ok(hub: Node, demo: bool) -> bool:
	var ok := true
	for i in Levels.COUNT:
		var text: String = hub.board_rows[i].text
		if demo and i + 1 > Demo.levels():
			ok = ok and text == "?/?"
		else:
			ok = ok and text == "%d/%d" % [progress.coins_found_in(i + 1), Levels.COINS[i]]
	if demo:
		ok = ok and "/%d " % Demo.coins_total() in hub.board_total.text and not str(Levels.total_coins()) in hub.board_total.text
	return ok


## Tiles past `last` are plain locks: disabled, the dim lock (no gold), no text but the number.
func _plain_locks(tiles: Array, last: int) -> bool:
	for i in tiles.size():
		var tile := tiles[i] as Button
		var locked := i + 1 > last
		if tile.disabled != locked or (tile.get_node_or_null("Lock") != null) != locked:
			return false
		for label: Label in tile.find_children("*", "Label", true, false):
			if "FULL" in label.text:
				return false
		if locked:
			for icon in tile.get_node("Lock").get_children():
				if icon is CanvasItem and (icon as CanvasItem).modulate == UIKit.GOLD:
					return false
	return true


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame
