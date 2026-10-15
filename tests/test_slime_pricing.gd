extends SceneTree

## Tree 3 (docs/design/upgrades-v2.md A2.1 / A2.3): MORE SLIME is the premium track (80 of the 165
## coins) while the story stays fair. Checks: the price table (165 in all, every price >= 1, rising
## curves, MORE SLIME's share); the meter at each normal level's start with the design's median coins
## found and MORE SLIME bought first (>= the flat-difficulty line 1.8 x the perfect route, levels 2-7
## exactly as in tree 2), also on the playtime model's coins-invested column; the test autopilot
## clears every normal level at those MORE SLIME levels; the tree 2 -> 3 repricing of saves (levels
## kept when affordable, rounded down by coins invested otherwise, leftover back, never negative,
## idempotent, notice once); coin counters never show a negative balance; the debug coin flags.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_slime_pricing.gd

const PROGRESS := preload("res://scripts/progress.gd")
const AUTOPILOT := preload("res://tests/autopilot.gd")
const MAIN := preload("res://scenes/main.tscn")
## The design's median coins found before levels 2-10 (upgrades-v2.md A2.3).
const TYPICAL_COINS: Array[int] = [0, 3, 8, 12, 18, 25, 34, 45, 57, 74]
## The playtime model's coins invested in MORE SLIME at each level start (playtime-estimate.md note).
const MODEL_INVESTED: Array[int] = [0, 1, 6, 6, 10, 15, 21, 28, 45, 55]
## Flat-difficulty line: above ~1.8 x the perfect route the model's attempts no longer drop.
const FLAT := 1.8

var failures := 0
var progress: Node
var _made: Array[Node] = []


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.hard_mode = false
	_table()
	_story_meter()
	await _autopilot()
	_reprice()
	await _no_negative()
	_debug_flags()
	progress.upgrades = {}
	progress.coins_found = {}
	for node in _made:
		node.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _table() -> void:
	var slime := Upgrades.total_cost("slime", 7)
	var speed := Upgrades.total_cost("speed", 4)
	var bright := Upgrades.total_cost("brightness", 3)
	_check(slime + speed + bright == 165 and Upgrades.full_tree_cost() == Levels.total_coins(),
		"the core tree costs exactly the 165 story coins (%d + %d + %d)" % [slime, speed, bright])
	_check(slime >= 75 and slime <= 85 and slime > speed and slime > bright and slime * 100 / 165 >= 45,
		"MORE SLIME is the premium track: %d coins (%d%%), SPEED %d, BRIGHTNESS %d" % [slime, slime * 100 / 165, speed, bright])
	var ok := true
	var top := 0
	for id: String in ["slime", "speed", "brightness"]:
		var costs: Array = Economy.COIN_TRACKS[id].costs
		for i in costs.size():
			ok = ok and typeof(costs[i]) == TYPE_INT and costs[i] >= 1 and (i == 0 or costs[i] >= costs[i - 1])
			top = maxi(top, costs[i])
	_check(ok and top == Upgrades.cost("slime", 6), "every price is a whole number >= 1, each track rises, MORE SLIME 7 is the priciest step")
	_check(Upgrades.total_cost("slime", 4) == Upgrades.tree2_total_cost("slime", 4)
		and Upgrades.total_cost("slime", 7) > Upgrades.tree2_total_cost("slime", 7),
		"MORE SLIME 1-4 cost what they did in tree 2 (21); only levels 5-7 got pricier")
	_check(Upgrades.tree2_total_cost("slime", 7) + Upgrades.tree2_total_cost("speed", 4) + Upgrades.tree2_total_cost("brightness", 3) == 165
		and Upgrades.tree2_total_cost("power", 4) == 0, "tree 2's table (for migrating) also totals 165")


## Allowance = the level's meter / the perfect route, at a MORE SLIME level.
func _allowance(level: int, slime_level: int) -> float:
	var maze := Levels.story_maze(level)
	return AutoplayPlanner.level_meter_tiles(level, false, slime_level) / AutoplayPlanner.fastest_run(maze).tiles


func _tree2_level(coins: int) -> int:
	var level := 0
	while level < 7 and Upgrades.tree2_total_cost("slime", level + 1) <= coins:
		level += 1
	return level


func _story_meter() -> void:
	print("    Lv  coins  tree2 lv  allow   tree3 lv  allow   meter")
	var flat := true
	var early_same := true
	for level in range(1, Levels.COUNT + 1):
		var coins := TYPICAL_COINS[level - 1]
		var old := _tree2_level(coins)
		var now := Upgrades.level_for_coins("slime", coins)
		var a_old := _allowance(level, old)
		var a_now := _allowance(level, now)
		print("    %2d  %5d  %8d  %5.2f   %8d  %5.2f  %+5.1f%%" % [level, coins, old, a_old, now, a_now, (a_now / a_old - 1.0) * 100.0])
		flat = flat and a_now >= FLAT
		if level <= 7:
			early_same = early_same and now == old
	_check(flat, "median coins, MORE SLIME first: every normal level starts at >= %.1f x the perfect route" % FLAT)
	_check(early_same, "levels 1-7 start with the same MORE SLIME level as in tree 2 (only 8-10 lose a step)")
	var model := true
	var lines: Array[String] = []
	for level in range(1, Levels.COUNT + 1):
		var a := _allowance(level, Upgrades.level_for_coins("slime", MODEL_INVESTED[level - 1]))
		lines.append("%.2f" % a)
		model = model and a >= FLAT
	_check(model, "the playtime model's coins-invested column also stays >= %.1f (%s)" % [FLAT, ", ".join(lines)])


## The perfect-glide autopilot clears every normal level at the MORE SLIME level the median coins buy.
func _autopilot() -> void:
	var lines: Array[String] = []
	var ok := true
	for level in range(1, Levels.COUNT + 1):
		var slime := Upgrades.level_for_coins("slime", TYPICAL_COINS[level - 1])
		progress.upgrades = {slime = slime} if slime > 0 else {}
		var game: Node2D = MAIN.instantiate()
		game.level = level
		root.add_child(game)
		await physics_frame
		game.add_child(AUTOPILOT.new())
		for i in 60 * 180:
			if game.finished:
				break
			await physics_frame
		ok = ok and game.won and game.slime_remaining > 0.0
		lines.append("L%d S%d %.0f%%" % [level, slime, game.slime_remaining])
		game.free()
	progress.upgrades = {}
	_check(ok, "the autopilot clears every normal level with the median buys (slime left: %s)" % ", ".join(lines))


# ---------------------------------------------------------------- tree 2 -> 3 repricing

func _fresh() -> Node:
	var node: Node = PROGRESS.new()
	node.saving_enabled = false
	_made.append(node)
	return node


## A version 6 save on `tree` with `levels` and `coins` story coins found (real coin keys).
func _save(levels: Dictionary, coins: int, tree := 2) -> ConfigFile:
	var f := ConfigFile.new()
	f.set_value("meta", "version", 6)
	f.set_value("meta", "epoch", PROGRESS.RELEASE_EPOCH)
	f.set_value("progress", "levels_cleared", 10)
	f.set_value("progress", "highest_unlocked", 10)
	var left := coins
	for level in range(1, Levels.COUNT + 1):
		var keys: Array[String] = []
		var take := mini(left, Levels.COINS[level - 1])
		keys.assign(Levels.coin_keys(level).slice(0, take))
		left -= take
		if not keys.is_empty():
			f.set_value("coins", "level_%d" % level, keys)
	f.set_value("upgrades", "tree", tree)
	for id: String in levels:
		f.set_value("upgrades", id, levels[id])
	return f


func _read(levels: Dictionary, coins: int, tree := 2) -> Node:
	var p := _fresh()
	p._read(_save(levels, coins, tree))
	return p


func _reprice() -> void:
	# [tree 2 levels, coins found, want levels, want in hand, want notice, label]
	var cases := [
		[{slime = 7, speed = 4, brightness = 3}, 165, {slime = 7, speed = 4, brightness = 3}, 0, 0, "a maxed tree stays maxed (165 either way)"],
		[{slime = 7}, 57, {slime = 6}, 4, 2, "SLIME 7 at 57 found (55 in): can't afford 80, rounds down to 6 (53) with 4 in hand, 2 back"],
		[{slime = 7}, 100, {slime = 7}, 20, 0, "SLIME 7 with coins to spare: kept (80), 20 in hand"],
		[{slime = 5}, 34, {slime = 5}, 1, 0, "SLIME 5 at 34 found: kept (33 now), 1 in hand"],
		[{slime = 5, speed = 1}, 39, {slime = 5, speed = 1}, 0, 0, "SLIME 5 + SPEED 1 at 39 (all in): kept (33 + 6)"],
		[{speed = 4, brightness = 3}, 110, {speed = 4, brightness = 3}, 25, 25, "SPEED 4 + BRIGHTNESS 3 (110 in): kept at 85, 25 back"],
		[{slime = 6, speed = 2}, 63, {slime = 5, speed = 2}, 15, 15, "SLIME 6 + SPEED 2 at 63 (63 in): SLIME 53 now unaffordable with SPEED -> 5, 15 back"],
		[{}, 20, {}, 20, 0, "no upgrades: nothing changes"],
	]
	for c in cases:
		var p := _read(c[0], c[1])
		var got := {}
		for id: String in ["slime", "speed", "brightness"]:
			if p.upgrade_level(id) > 0:
				got[id] = p.upgrade_level(id)
		_check(got == c[2] and p.coins() == c[3] and p.tree_refund_notice == c[4] and p.coins() >= 0,
			"%s (got %s, %d in hand, notice %d)" % [c[5], got, p.coins(), p.tree_refund_notice])
	# Every tree 2 state against a range of coins found: never negative, never above what was held,
	# a level is kept whenever the whole set is affordable, and the notice never claims more than in hand.
	var ok := true
	for s in 8:
		for v in 5:
			for b in 4:
				for coins in [0, 13, 40, 77, 120, 165]:
					var had := {slime = s, speed = v, brightness = b}
					var p := _read(had, coins)
					var spent_old := Upgrades.tree2_total_cost("slime", s) + Upgrades.tree2_total_cost("speed", v) + Upgrades.tree2_total_cost("brightness", b)
					var new_cost := Upgrades.total_cost("slime", s) + Upgrades.total_cost("speed", v) + Upgrades.total_cost("brightness", b)
					ok = ok and p.coins() >= 0 and p.tree_refund_notice <= p.coins()
					ok = ok and p.upgrade_level("slime") <= s and p.upgrade_level("speed") <= v and p.upgrade_level("brightness") <= b
					if spent_old <= coins and new_cost <= coins:
						ok = ok and p.upgrade_level("slime") == s and p.upgrade_level("speed") == v and p.upgrade_level("brightness") == b
					if not ok:
						print("    first bad: %s with %d coins -> %s, %d in hand" % [had, coins, p.upgrades, p.coins()])
						break
	_check(ok, "every tree 2 state x coins found: never negative, never above what was held, all kept when affordable")
	# Idempotent; written as tree 3 and never repriced again; the notice is taken once.
	var a := _read({slime = 7, speed = 1}, 70)
	var b := _read({slime = 7, speed = 1}, 70)
	var written: ConfigFile = a._write()
	var again := _fresh()
	again._read(written)
	_check(a.upgrades == b.upgrades and a.coins() == b.coins() and written.get_value("upgrades", "tree") == 3
		and again.upgrades == a.upgrades and again.coins() == a.coins() and again.tree_refund_notice == a.tree_refund_notice,
		"the same tree 2 save reads the same twice; written back as tree 3, it is not repriced again (%s, %d in hand, notice %d)"
		% [a.upgrades, a.coins(), a.tree_refund_notice])
	var n: int = a.tree_refund_notice
	_check(n > 0 and again.take_tree_refund_notice() == n and again.take_tree_refund_notice() == 0, "the notice (+%d) is shown once" % n)
	var t3 := _read({slime = 7}, 57, 3)
	_check(t3.upgrades.is_empty() or t3.coins() >= 0, "a tree 3 save claiming more than found still never goes negative (%d)" % t3.coins())
	var pending := _save({speed = 4}, 100)
	pending.set_value("upgrades", "refund_notice", 5)
	var pp := _fresh()
	pp._read(pending)
	_check(pp.upgrade_level("speed") == 4 and pp.tree_refund_notice == 5 + 60 - 46 and pp.coins() == 54,
		"a tree 2 save with a notice still pending adds the repricing's coins to it (5 + 14)")


# ---------------------------------------------------------------- no negative coin counters

func _no_negative() -> void:
	progress.dev_tools = false
	progress.upgrades = {slime = 7, speed = 4}
	progress.coins_found = {1: ["a", "b"]}
	_check(progress.coins() < 0, "(setup: levels set without coins put the balance at %d)" % progress.coins())
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.coin_label.text == "0", "the upgrades screen shows 0, not %d" % progress.coins())
	screen.free()
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	game.hud.set_coins(-4, 0, 3)
	_check(game.hud.coin_label.text == "0", "the HUD shows 0 for -4")
	game.free()
	progress.levels_cleared = 1
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.open_coin_board()
	_check(hub.board_total.text.ends_with("IN HAND 0"), "the hub's coin board shows IN HAND 0 (%s)" % hub.board_total.text)
	hub.free()
	progress.levels_cleared = 0
	# Real paths: buying never overdraws; reading a save never ends below 0.
	progress.upgrades = {}
	progress.coins_found = {1: ["a", "b", "c", "d", "e"]}
	_check(progress.buy_upgrade("slime") and progress.buy_upgrade("slime") and not progress.buy_upgrade("slime") and progress.coins() == 0,
		"buying stops when the coins run out (5 coins: SLIME 1 + 2, 0 left)")
	progress.upgrades = {}
	progress.coins_found = {}


func _debug_flags() -> void:
	var p := _fresh()
	p.upgrades = {slime = 3, speed = 2, brightness = 1}
	p.coins_found = {1: Array(Levels.coin_keys(1)), 2: Array(Levels.coin_keys(2))}
	var found: int = p.coins_earned()
	p.settle_debug_coins(-1)
	_check(p.coins() == maxi(found - 36, 0) and p.coins() >= 0, "--upgrades= over too few coins: padded to 0 in hand, never negative (%d)" % p.coins())
	p.settle_debug_coins(12)
	_check(p.coins() == 12 and p.upgrade_level("slime") == 3, "--coins=12 with --upgrades=: exactly 12 in hand whatever the flag order")
	var q := _fresh()
	q.coins_found = {1: ["a", "b", "c"]}
	q.settle_debug_coins(-1)
	_check(q.coins() == 3, "no flags over a positive balance: unchanged")


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
