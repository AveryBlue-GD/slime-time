extends SceneTree

## DESCENT runs (upgrades v2 batch 3, docs/design/upgrades-v2.md C2): the floor tables (usage u,
## refill, pot, theme cycle, size), determinism by run seed, boon offers and stacking, the refill /
## carry-over / pot / bank maths, every boon's effect in a real floor, goo drops, the run flow
## (start, clear, boon card, DESCEND, CASH OUT, dry-up, quit), the daily cap (2 paying runs, clock
## back / forward / far future), the no-MORE-SLIME cap, dev toggles, milestones (once, ABYSS trail),
## best floor, saves (keys, clamps, codes, reset, no in-run state) and the hub's portal choice.
## The autopilot runs (every floor solvable with the carried meter) are in test_descent_runs.gd.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_descent.gd

const MAIN := preload("res://scenes/main.tscn")
const SEED := 777

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	_tables()
	_determinism()
	_offers()
	_maths()
	_payout_and_caps()
	_milestones()
	_saves()
	await _game_floor()
	await _boon_effects()
	await _flow()
	await _portal()
	progress.reset_progress()
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _state(slime := 4) -> void:
	progress.reset_progress()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.tutorial_seen = 3
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.upgrades = {slime = slime} if slime > 0 else {}
	progress.day_override = 20000
	progress.workshop = {}


# ---------------------------------------------------------------- tables

func _tables() -> void:
	var ok := true
	for s in [1, 99, 4242, 1999999]:
		for f in range(1, 30):
			var u := Descent.usage_permille(s, f)
			var base := mini(300 + 50 * (f - 1), 850)
			ok = ok and u >= 250 and u <= 850 and absi(u - base) <= 50 and u == Descent.usage_permille(s, f)
	_check(ok, "usage u = 0.30 + 0.05 per floor (cap 0.85, floor 12+), +-0.05 seeded jitter, within 0.25-0.85")
	var mean_first := 0.0
	var mean_deep := 0.0
	for s in range(1, 201):
		mean_first += Descent.usage_permille(s, 1) / 200.0
		mean_deep += Descent.usage_permille(s, 14) / 200.0
	_check(absf(mean_first - 300.0) < 15.0 and mean_deep > 790.0 and mean_deep <= 850.0, "floor 1 averages u 0.30 (%.0f), floor 14 sits near the 0.85 cap (%.0f)" % [mean_first, mean_deep])
	var refills := []
	var pots := []
	for f in range(1, 13):
		refills.append(int(Descent.refill(f)))
		pots.append(Descent.pot_per_floor(f))
	_check(refills == [60, 60, 60, 50, 50, 50, 40, 40, 40, 35, 35, 35], "refill +60%% floors 1-3, +50 4-6, +40 7-9, +35 10+ (%s)" % [refills])
	_check(pots == [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4], "pot +1 floors 1-3, +2 4-6, +3 7-9, +4 10+ (%s)" % [pots])
	_check(Descent.theme_for(1) == Themes.for_level(1) and Descent.theme_for(5) == Themes.for_level(5) and Descent.theme_for(10) == Themes.for_level(10)
		and Descent.theme_for(11) == Themes.for_level(1) and Descent.theme_for(23) == Themes.for_level(3), "themes cycle in story order (floor 11 = the dungeon again)")
	var cfg := Descent.floor_config(SEED, 3, 4)
	_check(cfg.route == Levels.random_route_cells_for(Descent.usage_permille(SEED, 3), 4) and cfg.cells == Levels.random_cells(cfg.seed, 4)
		and cfg.seed == SEED * 1000 + 3 and cfg.theme == Descent.theme_for(3), "a floor's route = its u x the player's meter, its size the randomizer's (from the slime capacity)")
	var big := Descent.floor_config(SEED, 3, 7)
	_check(big.cells.x * big.cells.y >= cfg.cells.x * cfg.cells.y and big.route > cfg.route, "more MORE SLIME: longer routes, mazes at least as big")
	var maze := MazeGenerator.generate_random(cfg)
	_check(maze.goal_steps == cfg.route and MazeGenerator.is_completable(maze), "the floor's exit is exactly its route from the start (%d cells)" % cfg.route)
	var drops := Descent.drop_cells(maze, cfg.seed)
	var depths := MazeGenerator.dead_end_depths(maze)
	var good := drops.size() == 2 and drops[0] != drops[1]
	for c in drops:
		good = good and c != maze.start and c != maze.goal and depths.has(c)
	_check(good, "2 goo drops per floor, at dead ends (never the start or the exit): %s" % [drops])
	var t0 := Time.get_ticks_usec()
	for f in range(1, 21):
		MazeGenerator.generate_random(Descent.floor_config(SEED + 1, f, 7))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 20.0
	_check(ms < 40.0, "a floor builds fast (%.1f ms average at MORE SLIME 7; web budget ~20 ms native-equivalent)" % ms)


func _determinism() -> void:
	var a := MazeGenerator.generate_random(Descent.floor_config(SEED, 4, 2))
	var b := MazeGenerator.generate_random(Descent.floor_config(SEED, 4, 2))
	var c := MazeGenerator.generate_random(Descent.floor_config(SEED + 1, 4, 2))
	_check(a.walls == b.walls and a.start == b.start and a.goal == b.goal, "the same run seed and floor build the same maze")
	_check(a.walls != c.walls, "another run seed builds another maze")
	var variety := {}
	for s in range(1, 30):
		variety[str(Descent.offers(s, 2, {}))] = true
	_check(Descent.offers(SEED, 2, {}) == Descent.offers(SEED, 2, {}) and variety.size() > 10, "offers are seeded by run and floor (same run: same offers; %d different sets over 29 runs)" % variety.size())


func _offers() -> void:
	var seen := {}
	var ok := true
	for s in range(1, 400):
		var o := Descent.offers(s, 1 + s % 9, {})
		ok = ok and o.size() == 3 and o[0] != o[1] and o[1] != o[2] and o[0] != o[2]
		for id in o:
			seen[id] = int(seen.get(id, 0)) + 1
	_check(ok, "3 distinct offers every time")
	_check(seen.size() == 11, "all 11 boons get offered (%d)" % seen.size())
	_check(int(seen.get("gulp", 0)) > int(seen.get("glass", 0)), "weights: BIG GULP (1.0) is offered more often than GLASS SLIME (0.4) (%d vs %d)" % [seen.get("gulp", 0), seen.get("glass", 0)])
	var held := {feather = 1, rubber = 1, blaze = 1, sense = 1, glass = 1, tank = 2, slick = 2, thrift = 2, greedy = 2}
	var left_ok := true
	for s in range(1, 100):
		for id in Descent.offers(s, 5, held):
			left_ok = left_ok and id in ["gulp", "bladder"]
	_check(left_ok and Descent.offers(3, 5, held).size() == 2, "held non-stacking boons and maxed stacks are never offered (only BIG GULP / BACKUP BLADDER left)")
	_check(Descent.can_offer("tank", {tank = 1}) and not Descent.can_offer("tank", {tank = 2}) and Descent.can_offer("gulp", {gulp = 9}) and not Descent.can_offer("feather", {feather = 1}),
		"stacking: DEEP TANK 2x, BIG GULP no limit, FEATHER LEAP once")


func _maths() -> void:
	var run := Descent.new_run(SEED)
	_check(run.floor == 1 and run.meter == 100.0 and run.pot == 0, "a run starts on floor 1 with a full meter and an empty pot")
	var gain := Descent.clear_floor(run, 40.0, 30.0)
	_check(gain == 1 and run.pot == 1 and run.meter == 40.0 and run.cleared == 1, "clearing floor 1: +1 to the pot, the meter left is kept")
	Descent.descend(run, "thrift")
	_check(run.floor == 2 and run.meter == 100.0, "floor 2: 40 + 60 refill + 15 THRIFT = 115, capped at 100 (%.1f)" % run.meter)
	run.meter = 10.0
	Descent.clear_floor(run, 10.0, 0.0)
	Descent.descend(run, "gulp")
	_check(run.meter == 100.0, "BIG GULP 30 + refill 60 + THRIFT 15 on 10 left also caps at 100")
	run.meter = 5.0
	run.floor = 3
	run.cleared = 2
	Descent.clear_floor(run, 5.0, 0.0)
	Descent.descend(run, "tank")
	_check(is_equal_approx(run.meter, 5.0 / 1.15 + 50.0 + 15.0), "DEEP TANK keeps the slime left (in tiles) and refills floor 4 by +50 (+15): %.2f" % run.meter)
	run.boons = {greedy = 2, glass = 1}
	run.pot = 28
	run.floor = 10
	Descent.clear_floor(run, 50.0, 0.0)
	_check(run.pot == 30, "the pot never exceeds 30")
	_check(Descent.floor_gain(10, {greedy = 2}) == 6 and Descent.floor_gain(1, {}) == 1, "GREEDY GOO adds +1 per floor per stack")
	_check(Descent.bank(10, true, {}) == 10 and Descent.bank(11, false, {}) == 5 and Descent.bank(10, true, {glass = 1}) == 15 and Descent.bank(11, false, {glass = 1}) == 7
		and Descent.bank(30, true, {glass = 1}) == 30, "bank: CASH OUT the whole pot, dry-up half (rounded down), GLASS SLIME x1.5, never above 30")
	_check(is_equal_approx(Descent.capacity({tank = 2, greedy = 1}), 1.2) and is_equal_approx(Descent.speed({slick = 2}), 1.3)
		and Descent.jump_cost({feather = 1}, 0.5) == 0.35 and Descent.splat_factor({rubber = 1, glass = 1}) == 0.0 and Descent.splat_factor({glass = 1}) == 2.0,
		"capacity, speed, leap cost and splat factors per the table")
	_check(Descent.light_reach({blaze = 1}, 0) == Upgrades.light_reach(1) and Descent.light_reach({blaze = 1}, 3) == 33.0 and Descent.light_reach({}, 2) == Upgrades.light_reach(2),
		"BLAZE: one BRIGHTNESS step more (past the top: reveal 42 px)")


# ---------------------------------------------------------------- pay rules

func _end(cashed: bool, pot: int, boons := {}, tainted := false) -> Dictionary:
	progress.start_descent(SEED)
	progress.descent_run.pot = pot
	progress.descent_run.boons = boons
	progress.descent_run.cleared = 1 if cashed else 0
	return progress.end_descent(cashed, tainted)


func _payout_and_caps() -> void:
	_state()
	var before: int = progress.tickets
	var r1 := _end(true, 8)
	var r2 := _end(false, 9)
	var r3 := _end(true, 8)
	_check(r1.tickets == 8 and r2.tickets == 4 and r3.tickets == 0 and r3.cap == "practice" and progress.tickets == before + 12,
		"the first 2 banking runs of the day pay (CASH OUT 8, dry-up half of 9 = 4), the 3rd is PRACTICE (%d, %d, %d)" % [r1.tickets, r2.tickets, r3.tickets])
	_check(not progress.descent_day_open() and progress.descent_paid_left() == 0, "no paying runs left today")
	progress.day_override = 19999
	_check(_end(true, 5).tickets == 0, "the clock moved back: still no new day (forward-only)")
	progress.day_override = 20001
	_check(progress.descent_paid_left() == 2 and _end(true, 5).tickets == 5, "the next UTC day pays again")
	_state()
	_check(_end(false, 1).tickets == 0 and progress.descent_paid_left() == 2, "a run that banks nothing (half of 1) uses no paying slot")
	progress.descent_pay_day = 20000 + 500
	progress.descent_paid = 1
	_check(progress.descent_day_open() and progress.descent_pay_day == 20000 and progress.descent_paid_left() == 1, "a far-future pay day counts as today, keeping its count (a wrong clock can't lock the payouts)")
	_state(0)
	var slime := _end(true, 9)
	_check(slime.tickets == 1 and slime.cap == "slime", "no MORE SLIME bought: a run pays at most 1")
	progress.dev_tools = true
	_check(_end(true, 9).tickets == 9, "dev mode: no slime cap (the save is off anyway)")
	_state()
	var dev := _end(true, 9, {}, true)
	_check(dev.tickets == 0 and dev.cap == "dev" and progress.descent_paid_left() == 2, "a dev-toggled run pays nothing and uses no slot")
	_check(_end(true, 10, {glass = 1}).tickets == 15, "GLASS SLIME: the cashed pot x1.5")
	progress.day_override = 20100
	progress.start_descent(SEED)
	progress.descent_run.pot = 6
	var runs: int = progress.descent_runs
	var money: int = progress.tickets
	var once: Dictionary = progress.end_descent(true)
	var again: Dictionary = progress.end_descent(true)
	_check(once.tickets == 6 and again.tickets == 6 and progress.descent_paid == 1 and progress.descent_runs == runs + 1 and progress.tickets == money + 6, "ending a run twice banks it once")


func _milestones() -> void:
	_state()
	var start: int = progress.tickets
	progress.start_descent(SEED)
	for f in range(1, 11):
		progress.clear_descent_floor(60.0, 20.0)
		progress.descend(progress.descent_offers()[0])
	_check(progress.descent_run.floor == 11 and progress.tickets == start + 10 + 15, "reaching floors 5 and 10 pays +10 and +15 once (%d)" % (progress.tickets - start))
	_check(progress.owns_cosmetic("abyss") and progress.cosmetic_earned("abyss") and not progress.can_buy_cosmetic("abyss"), "floor 10 unlocks the ABYSS trail (earned, never sold)")
	_check(progress.descent_best_floor == 11 and progress.descent_best_time > 0.0, "best floor 11 recorded with its time (%.0f s)" % progress.descent_best_time)
	_check(not "abyss" in Cosmetics.ids() and "abyss" in Cosmetics.trail_ids(), "ABYSS is not in the SHOP list, but in the wardrobe's trails")
	progress.start_descent(SEED + 1)
	var mid: int = progress.tickets
	for f in range(1, 11):
		progress.clear_descent_floor(60.0, 20.0)
		progress.descend(progress.descent_offers()[0])
	_check(progress.tickets == mid, "milestones pay once ever")
	_check(not progress.descend("gulp"), "DESCEND needs the floor cleared first")
	_state()
	progress.start_descent(SEED)
	progress.descent_run.tainted = true
	for f in range(1, 6):
		progress.clear_descent_floor(60.0, 20.0)
		progress.descend(progress.descent_offers()[0])
	_check(progress.descent_milestones == 0 and progress.descent_best_floor <= 1, "a dev-toggled run earns no milestone and sets no record")
	var total := 0
	for f: int in Economy.DESCENT_MILESTONES:
		total += Economy.DESCENT_MILESTONES[f]
	_check(total == 70, "milestones total 70 tickets")


# ---------------------------------------------------------------- saves

func _saves() -> void:
	_state()
	progress.descent_best_floor = 12
	progress.descent_best_time = 321.5
	progress.descent_runs = 7
	progress.descent_pay_day = 20000
	progress.descent_paid = 1
	progress.descent_milestones = 3
	progress.cosmetics_owned.assign(["abyss"])
	progress.start_descent(SEED)
	var file: ConfigFile = progress._write()
	_check(file.get_value("descent", "best_floor", -1) == 12 and file.get_value("descent", "milestones", -1) == 3 and file.get_value("descent", "paid_runs", -1) == 1,
		"[descent] best_floor, best_time, runs, paid_day, paid_runs, milestones are saved")
	_check(not "run" in file.get_section_keys("descent") and not file.has_section_key("descent", "floor") and not file.has_section_key("descent", "pot"),
		"no in-run state is saved (quitting the app mid-run banks nothing)")
	progress.reset_progress()
	progress._read(file)
	_check(progress.descent_best_floor == 12 and is_equal_approx(progress.descent_best_time, 321.5) and progress.descent_runs == 7 and progress.descent_paid == 1
		and progress.descent_milestones == 3 and progress.descent_run.is_empty() and progress.owns_cosmetic("abyss"), "read back exactly; no run in progress after loading")
	var code: String = progress.save_code()
	var back: ConfigFile = progress.read_code(code)
	_check(back != null and back.get_value("descent", "best_floor", 0) == 12 and code.length() < 2000, "the save code carries [descent] (%d chars)" % code.length())
	var bad := ConfigFile.new()
	bad.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	bad.set_value("descent", "best_floor", 999999)
	bad.set_value("descent", "paid_runs", 9)
	bad.set_value("descent", "milestones", 255)
	bad.set_value("descent", "runs", -4)
	bad.set_value("descent", "best_time", "x")
	bad.set_value("cosmetics", "owned", ["abyss", "gold"])
	progress._read(bad)
	_check(progress.descent_best_floor == progress.DESCENT_FLOOR_MAX and progress.descent_paid == 2 and progress.descent_milestones == 15 and progress.descent_runs == 0 and progress.descent_best_time == 0.0,
		"hostile values are clamped")
	var no_abyss := ConfigFile.new()
	no_abyss.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	no_abyss.set_value("cosmetics", "owned", ["abyss", "gold"])
	progress._read(no_abyss)
	_check(not progress.owns_cosmetic("abyss") and progress.owns_cosmetic("gold"), "an ABYSS trail without its floor-10 milestone is dropped on load")
	var empty := ConfigFile.new()
	empty.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	progress._read(empty)
	_check(progress.descent_best_floor == 0 and progress.descent_paid == 0 and not progress._write().has_section("descent"), "missing keys default to 0, and an unplayed save has no [descent] section")
	progress.descent_best_floor = 3
	progress.reset_progress()
	_check(progress.descent_best_floor == 0 and progress.descent_runs == 0 and progress.descent_run.is_empty(), "RESET PROGRESS clears Descent")


# ---------------------------------------------------------------- in a real floor

func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	root.add_child(game)
	await physics_frame
	return game


func _game_floor() -> void:
	_state()
	progress.hard_mode = true  # Descent ignores the hard mode setting
	progress.start_descent(SEED)
	var game := await _spawn()
	var run: Dictionary = progress.descent_run
	_check(game.descent and not game.is_random() and not game.hard_mode, "the game plays a Descent floor (normal rules even with HARD MODE on)")
	_check(game.goal == game.chalice and game.chalice != null, "the floor's exit is the chalice")
	_check(game.theme == Descent.theme_for(1) and game.maze.goal_steps == Descent.floor_config(SEED, 1, 4).route, "floor 1: the dungeon, the route of its u")
	var expect: float = Descent.usage_permille(SEED, 1) / 10.0
	_check(absf(game.perfect_usage * 100.0 - expect) < 1.5, "a perfect glide uses the floor's u of the meter (%.1f%% vs %.1f%%)" % [game.perfect_usage * 100.0, expect])
	_check(game.drops.size() == 2 and game.coins.is_empty(), "two goo drops, no coins")
	_check(game.hud.attempt_pod.visible and game.hud.attempt_label.text.begins_with("POT 0") and game.hud.level_label.text == "DESCENT  FLOOR 1", "HUD: DESCENT FLOOR 1 and the pot pod")
	game.slime_remaining = 50.0
	var drop: GooDrop = game.drops[0]
	game.slime.position = drop.position
	game.last_slime_pos = drop.position
	await physics_frame
	await physics_frame
	_check(game.drops.size() == 1 and absf(game.slime_remaining - 58.0) < 0.5, "touching a goo drop adds 8%% (%.1f)" % game.slime_remaining)
	game.glimmer_view_only = false
	game.glimmer_reach = 99999.0
	var other: GooDrop = game.drops[0]
	game._spawn_glimmer()
	var twinkles := get_nodes_in_group("glimmer").filter(func(n: Node) -> bool: return n.position == other.position.round())
	_check(not twinkles.is_empty(), "a fog glimmer twinkles over a goo drop")
	game.free()
	progress.hard_mode = false
	progress.workshop = {magnet = 3}
	progress.start_descent(SEED)
	game = await _spawn()
	var far: GooDrop = game.drops[0]
	var far_at := far.position
	game._fill_fog(Rect2i(Vector2i.ZERO, game._cells), game._fog_color(game.elapsed, game.elapsed, false))
	var spot := _open_spot_near(game, far_at, 30.0)
	if spot != Vector2.INF:
		game.slime.position = spot
		game.last_slime_pos = spot
		await physics_frame
		_check(game.drops.size() == 1, "MAGNET pulls a goo drop in plain sight from %d px" % roundi(spot.distance_to(far_at)))
	game.free()
	progress.workshop = {}
	run = progress.descent_run
	_check(run.floor == 1, "(the run is untouched by building the floor)")


## An open floor point within `reach` px of `target` with no wall between (INF if none).
func _open_spot_near(game: Node2D, target: Vector2, reach: float) -> Vector2:
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var p := target + dir * (reach - 2.0)
		if not game.is_wall_tile(Vector2i(floori(p.x / 16), floori(p.y / 16))) and game.clear_line(p, target):
			return p
	return Vector2.INF


func _boon_effects() -> void:
	_state()
	progress.start_descent(SEED)
	var plain := await _spawn()
	var base_cost: float = plain.slime_cost_per_tile
	var base_speed: float = plain.slime.max_speed
	var base_reach: float = plain.light_reach
	plain.free()
	var boons := {tank = 2, slick = 1, feather = 1, rubber = 1, blaze = 1, sense = 1}
	progress.start_descent(SEED)
	progress.descent_run.boons = boons
	progress.descent_run.bladders = 2
	var game := await _spawn()
	_check(is_equal_approx(game.slime_cost_per_tile, base_cost / 1.3), "DEEP TANK x2: each tile costs 1/1.3 as much")
	_check(is_equal_approx(game.slime.max_speed, base_speed * 1.15), "SLICK: glide +15%")
	_check(game.jump_cost_factor == 0.35 and game.splat_factor == 0.0, "FEATHER LEAP: leaps cost 35%; RUBBER BODY: splats cost nothing")
	_check(game.light_reach == Descent.light_reach({blaze = 1}, progress.upgrade_level("brightness")) and game.light_reach > base_reach, "BLAZE: one more BRIGHTNESS step (%.0f -> %.0f px)" % [base_reach, game.light_reach])
	_check(game.goal_reveal_distance == 96.0, "CHALICE SENSE: the exit shows from 6 tiles")
	_check(game.hud.boon_pod.visible and game.hud.boon_icons.count("tank") == 2 and game.hud.boon_icons.count("bladder") == 2, "the HUD strip shows the boons (stacks repeat, unused bladders)")
	# BACKUP BLADDER: the meter at 0 refills to 25% instead of drying up, twice, then the run ends.
	game.slime_remaining = 0.0
	for i in 40:
		await physics_frame
	_check(not game.finished and absf(game.slime_remaining - 25.0) < 0.5 and game.bladders == 1 and progress.descent_run.bladders == 1, "BACKUP BLADDER: at 0 the meter refills to 25%% (%.1f)" % game.slime_remaining)
	game.slime_remaining = 0.0
	for i in 40:
		await physics_frame
	game.slime_remaining = 0.0
	for i in 5:
		await physics_frame
	_check(game.finished and not game.won and progress.descent_run.ended, "with the bladders used up, the next empty meter ends the run")
	game.free()
	progress.start_descent(SEED)
	progress.descent_run.boons = {glass = 1}
	game = await _spawn()
	_check(game.splat_factor == 2.0, "GLASS SLIME: splats cost double")
	game.free()
	progress.start_descent(SEED)
	progress.descent_run.boons = {greedy = 1}
	game = await _spawn()
	_check(is_equal_approx(game.slime_cost_per_tile, base_cost / 0.9), "GREEDY GOO: capacity -10%")
	game.free()
	# SECOND WIND: once per run, not per floor.
	progress.workshop = {wind = 2}
	progress.start_descent(SEED)
	game = await _spawn()
	_check(game.wind_state == "ready", "SECOND WIND is ready on floor 1")
	game.slime_remaining = 0.0
	await physics_frame
	_check(game.wind_state == "refilling" and progress.descent_run.wind_used, "it fires once the meter is empty")
	game.free()
	game = await _spawn()
	_check(game.wind_state == "used", "the next floor of the same run: already used")
	game.free()
	progress.workshop = {}
	# Dev toggles on one floor keep the whole run unpaid.
	progress.start_descent(SEED)
	progress.descent_run.tainted = true
	game = await _spawn()
	_check(game.dev_toggled and game.hud.attempt_label.text.contains("NO TICKETS"), "a dev toggle on an earlier floor keeps the run unpaid (pod says NO TICKETS)")
	game.free()


# ---------------------------------------------------------------- the flow

func _flow() -> void:
	_state()
	progress.start_descent(SEED)
	var game := await _spawn()
	game.slime_remaining = 70.0
	game.run_time = 12.0
	game._on_goal_body_entered(game.slime)
	var run: Dictionary = progress.descent_run
	_check(game.finished and game.won and run.cleared == 1 and run.pot == 1 and run.meter == 70.0, "reaching the chalice clears the floor: pot +1, the meter left is kept")
	_check(not progress.descend("feather" if not "feather" in progress.descent_offers() else "nope"), "DESCEND only takes an offered boon")
	game._open_boon_card()
	var card: DescentCard = game.descent_card
	_check(card.visible and card.boons_root.visible and card.tiles.size() == 3 and card.tile_ids == progress.descent_offers(), "the boon card shows the 3 offers")
	_check(card.title.text == "FLOOR 1 CLEARED" and card.pot_label.text.begins_with("POT 1 (+1)") and card.cash_button.text == "CASH OUT +1", "with the floor, the pot and CASH OUT +1")
	card._on_descend()
	_check(run.floor == 1 and card.status.text == "PICK A BOON FIRST", "DESCEND without a pick asks for one")
	var pick: String = card.tile_ids[1]
	card._on_tile(1)
	card._on_descend()
	_check(run.floor == 2 and Descent.held(run.boons, pick) == 1 and run.meter == minf(100.0, 70.0 * Descent.capacity({}) / Descent.capacity(run.boons) + (30.0 if pick == "gulp" else 0.0) + Descent.floor_refill(2, run.boons)),
		"picking a tile then DESCEND: floor 2 with %s and the meter refilled (%.1f)" % [pick, run.meter])
	game.free()
	game = await _spawn()
	_check(game.hud.level_label.text == "DESCENT  FLOOR 2" and absf(game.slime_remaining - run.meter) < 0.01 and game.theme == Descent.theme_for(2), "floor 2 starts with the carried meter, its own theme")
	game.slime_remaining = 40.0
	game._on_goal_body_entered(game.slime)
	var before: int = progress.tickets
	game.cash_out()
	_check(run.ended and progress.tickets == before + 2 and game.descent_card.summary_root.visible, "CASH OUT banks the whole pot (2) and shows the summary")
	_check(game.descent_card.summary_title.text == "CASHED OUT" and game.descent_card.new_run_button.has_focus(), "the summary: CASHED OUT, NEW RUN focused")
	game.free()
	# Dry-up: half the pot.
	progress.start_descent(SEED)
	run = progress.descent_run
	for i in 4:
		progress.clear_descent_floor(80.0, 10.0)
		progress.descend(_plain(progress.descent_offers()))
	_check(run.pot == 1 + 1 + 1 + 2, "4 floors cleared: pot 5")
	game = await _spawn()
	before = progress.tickets
	for b in ["bladder"]:
		run.boons.erase(b)
	game.bladders = 0
	game.wind_state = ""
	game.slime_remaining = 0.0
	for i in 3:
		await physics_frame
	_check(game.finished and run.ended and progress.tickets == before + 2 and run.result.tickets == 2, "a dry-up ends the run and banks half the pot (5 -> 2)")
	game.free()
	# Quitting mid-floor counts as a dry-up; on the boon card as a CASH OUT.
	progress.day_override = 20002
	progress.start_descent(SEED)
	run = progress.descent_run
	run.pot = 6
	game = await _spawn()
	before = progress.tickets
	game.quit_descent()
	_check(run.ended and progress.tickets == before + 3, "QUIT TO HUB mid-floor banks half the pot")
	game.free()
	progress.day_override = 20003
	progress.start_descent(SEED)
	run = progress.descent_run
	run.pot = 6
	game = await _spawn()
	game._on_goal_body_entered(game.slime)
	before = progress.tickets
	game.quit_descent()
	_check(run.ended and progress.tickets == before + 7, "QUIT TO HUB on the boon card cashes out (6 + 1)")
	game.free()
	# A new run from the summary.
	var old_seed: int = run.seed
	progress.start_descent()
	_check(progress.descent_active() and progress.descent_run.floor == 1 and progress.descent_run.pot == 0 and progress.mode == progress.MODE_DESCENT, "NEW RUN: a fresh run on floor 1 (seed %d -> %d)" % [old_seed, progress.descent_run.seed])
	# R is ignored in Descent (a floor can't be replayed).
	game = await _spawn()
	var r := InputEventAction.new()
	r.action = "restart"
	r.pressed = true
	current_scene = game
	game._unhandled_input(r)
	_check(not game.restart_prompt.visible and progress.descent_run.floor == 1, "R does nothing in a Descent floor")
	current_scene = null
	game.free()


func _portal() -> void:
	_state()
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await process_frame
	hub._use(hub._station("random"))
	_check(hub.portal_menu.visible and hub.maze_button.has_focus() and hub.slime.frozen, "the portal opens RANDOM MAZE / DESCENT (focus on RANDOM MAZE)")
	_check(hub.portal_info.text.contains("PAID RUNS 2/2"), "it shows today's paying runs (%s)" % hub.portal_info.text)
	hub.close_portal_menu()
	_check(not hub.portal_menu.visible and not hub.slime.frozen, "BACK closes it")
	progress.descent_best_floor = 6
	hub.open_portal_menu()
	_check(hub.portal_info.text.begins_with("BEST FLOOR 6"), "and the best floor")
	hub._start_descent()
	_check(progress.mode == progress.MODE_DESCENT and progress.descent_active(), "DESCENT starts a run")
	current_scene = null
	hub.free()
	_state()
	progress.levels_cleared = 3
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._use(hub._station("random"))
	_check(not hub.portal_menu.visible, "a locked portal (story not beaten) opens nothing")
	hub.free()
	for i in 3:
		await process_frame


## An offer that doesn't change the pot or the bank (not GREEDY GOO / GLASS SLIME).
func _plain(offers: Array[String]) -> String:
	for id in offers:
		if not id in ["greedy", "glass"]:
			return id
	return offers[0]


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
