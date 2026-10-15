extends "res://tests/suite_base.gd"

## The ticket workshop is switched off by ONE flag (Economy.WORKSHOP_ENABLED = false). With it off:
## nothing is offered (no TICKETS tab or page, no buying, no hub '!'), nothing is applied (story,
## randomizer, Descent, hard: every workshop effect is inert, no WIND tag, the payout ignores SECOND
## WIND) and levels already in a save are KEPT (in memory, in the file, in a save code) so turning the
## flag back on restores them. Also measures the COINS bars: all three the same width and edges, one
## whole-pixel segment per level with 1 px gaps. The workshop itself is tested (flag forced on, see
## Economy.workshop_force) by test_workshop.gd / test_store.gd / test_descent.gd.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_workshop_off.gd

const MAIN := preload("res://scenes/main.tscn")
const FULL := {wind = 3, charge = 3, sticky = 3, magnet = 3, nose = 3}

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.saving_enabled = false
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	_check(Economy.workshop_force == -1 and not Economy.WORKSHOP_ENABLED and not Economy.workshop_on(), "shipped with the workshop off")
	_state()
	_data()
	_saves()
	await _games()
	await _screen()
	progress.reset_progress()
	_result()
	quit(0 if failures == 0 else 1)


func _state(workshop := FULL) -> void:
	progress.reset_progress()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.tutorial_seen = 3
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.mode = progress.MODE_STORY
	progress.tickets = 900
	progress.tickets_lifetime = 900
	progress.workshop = workshop.duplicate()


func _data() -> void:
	var inert := true
	for id: String in FULL:
		inert = inert and progress.workshop_level(id) == 0 and not progress.can_buy_workshop(id) and not progress.buy_workshop(id)
	_check(inert and not progress.workshop_open() and progress.tickets == 900, "off: every level reads 0, nothing opens or sells")
	_check(progress.workshop == FULL and progress.workshop_saved_level("wind") == 3, "off: the saved levels are still held")
	_state({})
	Economy.abilities_force = 0
	_check(not progress.store_affordable("upgrades"), "off: the cauldron '!' ignores the workshop (abilities off too)")
	Economy.abilities_force = -1
	progress.dev_tools = true
	_check(not progress.workshop_open() and not progress.store_affordable("upgrades"), "off: not even dev mode opens it")
	progress.dev_tools = false
	Economy.workshop_force = 1
	_check(progress.workshop_open() and progress.store_affordable("upgrades"), "forced on: open, and the '!' is back (900 tickets)")
	Economy.workshop_force = -1


func _saves() -> void:
	_state()
	var path := throwaway_save("_saves")
	progress.save_path = path
	progress.saving_enabled = true
	progress.save_progress()
	var file := ConfigFile.new()
	_check(file.load(path) == OK and int(file.get_value("workshop", "wind", 0)) == 3 and int(file.get_value("workshop", "nose", 0)) == 3,
		"off: the levels are written to the save file unchanged")
	progress.workshop = {}
	progress.load_progress(path)
	_check(progress.workshop == FULL, "off: a reload keeps them (%s)" % progress.workshop)
	var code: String = progress.save_code()
	progress.saving_enabled = false
	progress.workshop = {}
	_check(code != "" and progress.load_code(code) and progress.workshop == FULL, "off: a save code carries them too")
	Economy.workshop_force = 1
	_check(progress.workshop_level("wind") == 3 and progress.workshop_level("nose") == 3, "forced on again: the levels have their effect back")
	Economy.workshop_force = -1
	progress.saving_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _spawn(level := 1, random_seed := 0) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	if random_seed != 0:
		progress.mode = progress.MODE_RANDOM
		progress.random_seed = random_seed
		game.random_seed = random_seed
	else:
		game.level = level
	root.add_child(game)
	await physics_frame
	await physics_frame
	return game


func _inert(game: Node2D) -> bool:
	return game.workshop.is_empty() and game.slime.charge_time == Slime.CHARGE_TIME and game.slime.splat_stun == Slime.SPLAT_STUN \
		and game.splat_factor == 1.0 and game.coin_reach == Coin.REACH and game.glimmer_rate == 1.0 \
		and game.wind_state == "" and not game.hud.wind_pod.visible


func _games() -> void:
	_state()
	var game := await _spawn(3)
	_check(_inert(game), "story: every workshop effect is inert, no WIND tag")
	game.free()
	_state()
	progress.hard_mode = true
	game = await _spawn(3)
	_check(_inert(game), "hard mode: inert")
	game.free()
	progress.hard_mode = false
	_state()
	progress.upgrades = {slime = 1}
	progress.random_attempts.clear()
	game = await _spawn(0, 777001)
	var before: int = game.payout().tickets
	game.slime_remaining = 0.0
	for i in 8:
		await physics_frame
	_check(_inert(game) and game.pay_attempt() == 1 and game.payout().tickets == before and not game.wind_fired,
		"randomizer: SECOND WIND never fires, the payout stays %d and the attempt step 1" % before)
	game.free()
	_state()
	progress.start_descent(4242)
	game = MAIN.instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	_check(_inert(game), "descent: inert (boons are separate and still on)")
	game.free()
	progress.hard_mode = false
	await process_frame


func _bar(row: Dictionary) -> Array:
	var pips: Array = row.pips
	var widths: Array[int] = []
	for pip: ColorRect in pips:
		widths.append(int(pip.size.x))
	var gaps_ok := true
	for i in range(1, pips.size()):
		gaps_ok = gaps_ok and int(pips[i].position.x - pips[i - 1].position.x - pips[i - 1].size.x) == 1
	var same_y := true
	for pip: ColorRect in pips:
		same_y = same_y and pip.position.y == pips[0].position.y and pip.size.y == pips[0].size.y
	return [int(pips[0].position.x), int(pips[-1].position.x + pips[-1].size.x), widths, gaps_ok, same_y]


func _screen() -> void:
	_state()
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	_check(screen.tickets_tab == null and screen.ticket_page == null and screen.ticket_rows.is_empty()
		and screen.abilities_tab != null and screen.abilities_tab.text == "TICKETS" and screen.ability_rows.size() == 3
		and screen.page == "coins" and screen.coin_page.visible and screen.rows.size() == 3,
		"off: the cauldron is the three coin rows and the TICKETS tab holds the abilities (no workshop page)")
	var bars := {}
	for id: String in ["slime", "speed", "brightness"]:
		bars[id] = _bar(screen.rows[id])
	var left: int = bars.slime[0]
	var right: int = bars.slime[1]
	var same := true
	for id: String in bars:
		same = same and bars[id][0] == left and bars[id][1] == right and bars[id][3] and bars[id][4]
	_check(same and right - left == 83,
		"the three bars share their left and right edges (x %d .. %d = 83 px, 1 px gaps)" % [left, right])
	_check(bars.slime[2] == [11, 11, 11, 11, 11, 11, 11] and bars.speed[2] == [20, 20, 20, 20] and bars.brightness[2] == [27, 27, 27],
		"segments: 7 x 11, 4 x 20, 3 x 27 px (%s %s %s)" % [bars.slime[2], bars.speed[2], bars.brightness[2]])
	var minus_left: float = screen.rows.slime.minus.position.x
	_check(right < minus_left and left > screen.rows.slime.name.position.x, "the bars end before the - button (x %d < %d)" % [right, minus_left])
	# Several upgrade states: every state keeps the same extents.
	for state: Dictionary in [{}, {slime = 3, speed = 2, brightness = 1}, {slime = 7, speed = 4, brightness = 3}]:
		progress.upgrades = state.duplicate()
		screen._refresh()
		var lit := 0
		for id: String in screen.rows:
			for pip: ColorRect in screen.rows[id].pips:
				lit += 1 if pip.color != Color8(74, 70, 96) else 0
		var want := 0
		for id: String in state:
			want += state[id]
		_check(lit == want and _bar(screen.rows.slime)[0] == left and _bar(screen.rows.brightness)[1] == right, "upgrade state %s: %d lit segments, same extents" % [state, lit])
	screen.free()
	# Flag forced on: the tabs and the workshop page are back, with the saved levels in effect and the same bars.
	Economy.workshop_force = 1
	_state()
	screen = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	_check(screen.tickets_tab != null and screen.ticket_rows.size() == 5 and progress.workshop_level("wind") == 3
		and _bar(screen.ticket_rows.wind)[0] == left and _bar(screen.ticket_rows.wind)[1] == right and _bar(screen.ticket_rows.wind)[2] == [27, 27, 27],
		"forced on: TICKETS tab back, levels restored, workshop bars the same width")
	screen.free()
	Economy.workshop_force = -1


