extends "res://tests/suite_base.gd"

## Upgrades v2, batch 1 (docs/design/upgrades-v2.md A2): the core coin tree with few big breakpoints.
## Checks: the Economy table (MORE SLIME 7 / SPEED 4 / BRIGHTNESS 3 levels, exact costs and effects,
## 165 coins in all, the old maxima); brightness radii (reveal 9/17/25/34, relight 20/28/36/45 px, the
## same constants the fog code uses) and the lit area each level reveals in a real level; the save
## migration from the old 10-level tree (every old level per track -> new level + coins back, refund
## correctness, hostile values, idempotence, the file and save-code paths, [upgrades] tree = 2, save
## version 6); the one-time hub notice; seed codes N-L with the new 0-7 level (old 8-10 clamp); the
## randomizer route maths equal to the old one at an equal factor; the upgrades screen layout (every
## track's pips visible, nothing overlapping) in several states. Throwaway saves only.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_upgrades_v2.gd

const PROGRESS := preload("res://scripts/progress.gd")
const Main := preload("res://scripts/game.gd")

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.hard_mode = false
	_economy()
	_migration()
	_save_paths()
	_seed_codes()
	await _brightness()
	await _hub_notice()
	await _screen_layout()
	await _preview()
	progress.upgrades = {}
	progress.coins_found = {}
	progress.dev_tools = false
	for node in _made:
		node.free()
	_result()
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- the table

func _economy() -> void:
	_check(Upgrades.max_level("slime") == 7 and Upgrades.max_level("speed") == 4 and Upgrades.max_level("brightness") == 3
		and Upgrades.max_level("power") == 4 and Upgrades.max_level("nope") == 0, "track lengths: MORE SLIME 7, SPEED 4, BRIGHTNESS 3 (dev WALL POWER 4)")
	var costs := {slime = [1, 4, 7, 9, 12, 20, 27], speed = [6, 9, 13, 18], brightness = [9, 12, 18]}
	for id: String in costs:
		var got := []
		for level in Upgrades.max_level(id):
			got.append(Upgrades.cost(id, level))
		_check(got == costs[id], "%s costs %s" % [id, got])
	_check(Upgrades.total_cost("slime", 7) == 80 and Upgrades.total_cost("speed", 4) == 46 and Upgrades.total_cost("brightness", 3) == 39,
		"track totals 80 + 46 + 39 (tree 3: MORE SLIME is the premium track)")
	_check(Upgrades.full_tree_cost() == 165 and Levels.total_coins() == 165, "the whole tree costs exactly the 165 story coins")
	_check(Upgrades.cost("slime", 7) == 0 and Upgrades.cost("slime", -1) == 0 and Upgrades.total_cost("speed", 99) == 46
		and Upgrades.total_cost("power", 4) == 0, "no next cost past the top; totals clamp; dev wall power is free")
	var factors := []
	var want_factors := [1.0, 1.15, 1.3, 1.45, 1.6, 1.75, 1.9, 2.0]
	var factors_ok := true
	for level in 8:
		factors.append(Upgrades.slime_factor(level))
		factors_ok = factors_ok and is_equal_approx(factors[level], want_factors[level])
	_check(factors_ok, "MORE SLIME factors %s" % [factors])
	var speeds := []
	var want_speeds := [1.0, 1.12, 1.25, 1.37, 1.5]
	var speeds_ok := true
	for level in 5:
		speeds.append(Upgrades.speed_factor(level))
		speeds_ok = speeds_ok and is_equal_approx(speeds[level], want_speeds[level])
	_check(speeds_ok, "SPEED factors %s" % [speeds])
	_check(Upgrades.slime_factor(99) == 2.0 and Upgrades.slime_factor(-3) == 1.0 and Upgrades.speed_factor(4) == 1.5
		and Upgrades.light_reach(3) == 25.0, "maxima equal the old tree's (x2.0 meter, x1.5 speed, +25 px light); levels clamp")
	var percents := []
	for level in 8:
		percents.append(Upgrades.slime_percent(level))
	_check(percents == [100, 115, 130, 145, 160, 175, 190, 200], "slime factor in hundredths for the integer route maths")
	_check(is_equal_approx(Upgrades.wall_damage(4, 1.0), 10.0 * 12.0) and Upgrades.wall_damage(0, 1.0) == 0.0,
		"dev wall power 4 does what old power 10 did")


# ---------------------------------------------------------------- migration

## Every old level 0-10 of each track: [new level, coins back].
const MIGRATION := {
	slime = [[0, 0], [1, 0], [1, 2], [2, 1], [2, 5], [3, 3], [4, 0], [4, 7], [5, 5], [6, 2], [7, 0]],
	speed = [[0, 0], [0, 1], [0, 3], [0, 6], [1, 2], [1, 7], [2, 1], [2, 8], [3, 0], [3, 9], [3, 19]],
	brightness = [[0, 0], [0, 1], [0, 3], [0, 6], [0, 10], [1, 3], [1, 9], [2, 0], [2, 8], [2, 17], [3, 5]],
}


func _migration() -> void:
	for id: String in MIGRATION:
		var ok := true
		for old in 11:
			var want: Array = MIGRATION[id][old]
			var level := Upgrades.migrate_level(id, old)
			ok = ok and level == want[0] and Upgrades.old_total_cost(old) - Upgrades.tree2_total_cost(id, level) == want[1]
		_check(ok, "%s: every old level 0-10 maps by coins invested onto tree 2 prices, rounded down, the rest back in hand" % id)
	_check(Upgrades.migrate_level("slime", 99) == 7 and Upgrades.migrate_level("speed", -4) == 0 and Upgrades.migrate_level("power", 10) == 4
		and Upgrades.migrate_level("power", 4) == 1, "out-of-range old levels clamp; old dev power maps by equal damage (10 -> 4, 4 -> 1)")

	# Every old track level against a full coin purse, through _read: levels, coins in hand, the notice.
	for id: String in MIGRATION:
		var ok := true
		for old in 11:
			var p := _fresh()
			p._read(_old_save({id: old}, 165))
			var want: Array = MIGRATION[id][old]
			ok = ok and p.upgrade_level(id) == want[0] and p.coins() == 165 - Upgrades.total_cost(id, want[0])
			ok = ok and p.tree_refund_notice == maxi(0, Upgrades.old_total_cost(old) - Upgrades.total_cost(id, want[0]))
		_check(ok, "%s: a v5 save at every old level reads as the tree 2 level (kept at tree 3 prices: 165 found), coins back in hand, notice = coins back" % id)

	# A maxed old tree: SLIME 10 -> 7, SPEED 10 -> 3, BRIGHTNESS 10 -> 3: 165 - (80 + 28 + 39) = 18 back.
	var p := _fresh()
	p._read(_old_save({slime = 10, speed = 10, brightness = 10}, 165))
	_check(p.upgrade_level("slime") == 7 and p.upgrade_level("speed") == 3 and p.upgrade_level("brightness") == 3
		and p.coins() == 18 and p.tree_refund_notice == 18, "maxed old tree: 7 / 3 / 3 with 18 coins back (SPEED 4 costs 18 again)")
	var written: ConfigFile = p._write()
	_check(written.get_value("meta", "version") == 7 and PROGRESS.SAVE_VERSION == 7 and written.get_value("upgrades", "tree") == Economy.TREE_VERSION
		and written.get_value("upgrades", "refund_notice") == 18 and PROGRESS.RELEASE_EPOCH == 1 and Economy.TREE_VERSION == 3,
		"the next save is version 7 with [upgrades] tree = 3 and the pending notice (epoch stays 1)")
	var q := _fresh()
	q._read(written)
	_check(q.upgrades == p.upgrades and q.coins() == 18 and q.tree_refund_notice == 18, "read back: no second migration, the notice still pending")
	var r := _fresh()
	r._read(_old_save({slime = 10, speed = 10, brightness = 10}, 165))
	_check(r.upgrades == p.upgrades and r.coins() == p.coins(), "the same old save read again gives the same result (idempotent)")
	_check(q.take_tree_refund_notice() == 18 and q.take_tree_refund_notice() == 0 and q.tree_refund_notice == 0,
		"the notice is taken once")
	var shown: ConfigFile = q._write()
	_check(not shown.has_section_key("upgrades", "refund_notice"), "once shown it is not saved again")

	# A partial old tree with coins left over: SLIME 5 (15) -> 3 (12) +3, SPEED 2 (3) -> 0 +3.
	var partial := _fresh()
	partial._read(_old_save({slime = 5, speed = 2}, 40))
	_check(partial.upgrade_level("slime") == 3 and partial.upgrade_level("speed") == 0 and partial.coins() == 40 - 12
		and partial.tree_refund_notice == 6 and not partial.upgrades.has("speed"), "SLIME 5 -> 3 and SPEED 2 -> 0: 6 coins back, 28 in hand")
	var none := _fresh()
	none._read(_old_save({slime = 1, speed = 0}, 3))
	_check(none.upgrade_level("slime") == 1 and none.tree_refund_notice == 0, "SLIME 1 stays 1 (1 coin): nothing back, no notice")

	# Hostile values.
	var hostile := _old_save({slime = 999, speed = -5}, 10)
	hostile.set_value("upgrades", "brightness", "abc")
	hostile.set_value("upgrades", "power", 10)
	var h := _fresh()
	h._read(hostile)
	_check(h.coins() >= 0 and h.upgrade_level("slime") <= 7 and h.upgrade_level("speed") == 0 and h.upgrade_level("brightness") == 0
		and h.tree_refund_notice <= h.coins(), "hostile old levels clamp, never more spent than found, the notice never claims more than in hand")
	var claims := _old_save({slime = 10}, 0)
	var c := _fresh()
	c._read(claims)
	_check(c.upgrades.is_empty() and c.coins() == 0 and c.tree_refund_notice == 0, "an old tree with no coins found is dropped: no notice")
	var new_hostile := _old_save({slime = 99, speed = 99, brightness = 99}, 165)
	new_hostile.set_value("upgrades", "tree", 99)
	new_hostile.set_value("upgrades", "refund_notice", 99999)
	var n := _fresh()
	n._read(new_hostile)
	_check(n.upgrade_level("slime") == 7 and n.upgrade_level("speed") == 4 and n.upgrade_level("brightness") == 3 and n.coins() == 0
		and n.tree_refund_notice == 0, "a new-tree save's levels clamp to each track's top; a notice can't exceed coins in hand")
	var odd_tree := _old_save({speed = 10}, 165)
	odd_tree.set_value("upgrades", "tree", "2")
	var o := _fresh()
	o._read(odd_tree)
	_check(o.upgrade_level("speed") == 3 and o.tree_refund_notice == 27, "a tree mark that isn't an int counts as the old tree (migrated: 55 - 28 back)")
	var neg := _old_save({speed = 2}, 165)
	neg.set_value("upgrades", "tree", Economy.TREE_VERSION)
	neg.set_value("upgrades", "refund_notice", -5)
	var g := _fresh()
	g._read(neg)
	_check(g.upgrade_level("speed") == 2 and g.tree_refund_notice == 0, "a new-tree save is never remapped; a negative notice reads as none")
	var dev := _fresh()
	dev.dev_tools = true
	dev._read(_old_save({power = 10}, 0))
	_check(dev.upgrade_level("power") == 4 and dev.tree_refund_notice == 0, "old dev wall power 10 -> 4 (free), not counted in the notice")


## The save file and save-code paths (throwaway file next to the other test saves; removed after).
func _save_paths() -> void:
	var path := "%stree_%d.cfg" % [PROGRESS.THROWAWAY_PREFIX, OS.get_process_id()]
	var old := _old_save({slime = 10, speed = 10, brightness = 10}, 165)
	old.save(path)
	var p := _fresh()
	p.save_path = path
	p.saving_enabled = true
	p.load_progress()
	var after := ConfigFile.new()
	after.load(path)
	_check(p.upgrade_level("speed") == 3 and after.get_value("meta", "version") == 7 and after.get_value("upgrades", "tree") == 3
		and after.get_value("upgrades", "speed") == 3 and after.get_value("upgrades", "refund_notice") == 18,
		"an old save file is migrated and written back once (version 7, tree 3, levels 7/3/3, notice 18)")
	var p2 := _fresh()
	p2.save_path = path
	p2.saving_enabled = true
	p2.load_progress()
	_check(p2.upgrades == p.upgrades and p2.coins() == 18 and p2.take_tree_refund_notice() == 18, "loading it again changes nothing")
	var p3 := _fresh()
	p3.save_path = path
	p3.saving_enabled = true
	p3.load_progress()
	_check(p3.tree_refund_notice == 0 and p3.coins() == 18, "after the notice was shown it stays gone across launches")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(not FileAccess.file_exists(path), "(throwaway save removed)")

	var code := PROGRESS.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(old.encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var k := _fresh()
	_check(k.load_code(code) and k.upgrade_level("slime") == 7 and k.upgrade_level("speed") == 3 and k.coins() == 18 and k.tree_refund_notice == 18,
		"an old-tree save code migrates the same way")
	var again := _fresh()
	_check(again.load_code(k.save_code()) and again.upgrades == k.upgrades and again.coins() == 18, "and its new code reads back unchanged")
	var pre_epoch := _old_save({speed = 10}, 165)
	pre_epoch.erase_section_key("meta", "epoch")
	var e := _fresh()
	e.load_code(PROGRESS.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(pre_epoch.encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)))
	_check(e.upgrades.is_empty() and e.coins() == 0, "a pre-epoch save is still never read (fresh-start policy)")


# ---------------------------------------------------------------- seed codes

func _seed_codes() -> void:
	_check(Levels.parse_seed_code("123-7") == Vector2i(123, 7) and Levels.parse_seed_code("123-0") == Vector2i(123, 0)
		and Levels.parse_seed_code("123") == Vector2i(123, -1), "codes N-L read levels 0-7 (no level: the player's own)")
	_check(Levels.parse_seed_code("123-8") == Vector2i(123, 7) and Levels.parse_seed_code("123-10") == Vector2i(123, 7),
		"an old code's 8-10 clamps to 7 (the x2.0 meter)")
	_check(Levels.parse_seed_code("123-11") == Vector2i.ZERO and Levels.parse_seed_code("123--1") == Vector2i.ZERO
		and Levels.parse_seed_code("123-+3") == Vector2i.ZERO, "above 10 or malformed: not a code")
	_check(Levels.seed_code(123, 9) == "123-7" and Levels.seed_code(123, 4) == "123-4", "codes show the clamped level")
	var same := true
	for permille in range(100, 951, 7):
		# The old formula: u x 136 x (1 + L / 10); at an equal factor the route is the same.
		for pair in [[2, 3], [4, 6], [6, 9], [7, 10]]:
			var old := maxi(Levels.RANDOM_MIN_ROUTE, (permille * Levels.RANDOM_METER_TILES * (10 + pair[1]) + 8125 + 10000) / 20000)
			same = same and Levels.random_route_cells_for(permille, pair[0]) == old
	_check(same, "randomizer routes at new SLIME 2/4/6/7 equal the old ones at 3/6/9/10 (same factor, same maze)")
	_check(Levels.random_floor_cells(7) == Vector2i(25, 14) and Levels.random_floor_cells(0) == Levels.RANDOM_FLOOR_BASE
		and Levels.random_config(5, false, 9).slime_level == 7, "floor size grows with sqrt(factor); levels clamp to 7")
	_check(is_equal_approx(Levels.random_capacity_tiles(7), 272.0) and is_equal_approx(Levels.random_capacity_tiles(3), 136.0 * 1.45),
		"the randomizer meter is 136 tiles x the MORE SLIME factor")


# ---------------------------------------------------------------- brightness

func _brightness() -> void:
	_check(Economy.REVEAL_RADIUS == Main.TRAIL_RADIUS and Economy.RELIGHT_RADIUS == Main.LIGHT_RADIUS,
		"the Economy radii are the fog code's (TRAIL_RADIUS 9, LIGHT_RADIUS 20)")
	var reveal := []
	var relight := []
	for level in 4:
		reveal.append(Upgrades.reveal_radius(level))
		relight.append(Upgrades.relight_radius(level))
	_check(reveal == [9.0, 17.0, 25.0, 34.0] and relight == [20.0, 28.0, 36.0, 45.0], "reveal %s, relight %s px" % [reveal, relight])
	var gains := []
	for level in range(1, 4):
		gains.append(roundi((pow(reveal[level] / reveal[level - 1], 2.0) - 1.0) * 100.0))
	_check(gains == [257, 116, 85], "lit-disc area per step +%d%%, +%d%%, +%d%%" % gains)

	# In a real level: the cells the slime's light reveals around it (it shines as the slime moves:
	# one step of the light at the start position) grow with each level.
	var main: PackedScene = load("res://scenes/main.tscn")
	var counts := []
	for level in 4:
		progress.upgrades = {brightness = level} if level > 0 else {}
		var game: Node2D = main.instantiate()
		game.level = 4
		root.add_child(game)
		for i in 3:
			await physics_frame
		game._reveal_light(game.slime.position)
		var revealed := 0
		var bytes: PackedByteArray = game._fog_bytes
		for i in range(0, bytes.size(), 4):
			if bytes.decode_u32(i) >= 0x10000:
				revealed += 1
		counts.append(revealed)
		_check(game.light_reach == Upgrades.light_reach(level), "BRIGHTNESS %d: the game's light reach is %.0f px" % [level, game.light_reach])
		game.free()
	progress.upgrades = {}
	_check(counts[1] > counts[0] and counts[2] > counts[1] * 1.3 and counts[3] > counts[2] * 1.2 and counts[3] > counts[0] * 2,
		"each BRIGHTNESS level visibly widens what the light reveals at the start (%s fog cells)" % [counts])


# ---------------------------------------------------------------- the hub notice

func _hub_notice() -> void:
	var hub_scene: PackedScene = load("res://scenes/hub.tscn")
	progress.levels_cleared = 1
	progress.tree_refund_notice = 7
	var hub: Node = hub_scene.instantiate()
	root.add_child(hub)
	await process_frame
	var texts := []
	if hub.tree_notice:
		for label in hub.tree_notice.find_children("*", "Label", true, false):
			texts.append(label.text)
	_check(hub.tree_notice != null and hub.tree_notice.visible and texts == ["UPGRADES REWORKED", "COINS RETURNED +7"]
		and progress.tree_refund_notice == 0, "the hub shows UPGRADES REWORKED / COINS RETURNED +7 once")
	if hub.tree_notice:
		var rect := Rect2(hub.tree_notice.position, hub.tree_notice.size)
		_check(Rect2(0, 0, 320, 180).encloses(rect) and rect.position.y > 20, "the notice sits on screen below the ticket pod (%s)" % rect)
	hub.free()
	var hub2: Node = hub_scene.instantiate()
	root.add_child(hub2)
	await process_frame
	_check(hub2.tree_notice == null, "and never again")
	hub2.free()
	progress.levels_cleared = 0


# ---------------------------------------------------------------- the upgrades screen

func _screen_layout() -> void:
	var scene: PackedScene = load("res://scenes/upgrades.tscn")
	for state in [[{}, 0, false], [{slime = 3, speed = 1}, 20, false], [{slime = 7, speed = 4, brightness = 3}, 0, false],
			[{slime = 2, brightness = 2, power = 2}, 50, true]]:
		progress.dev_tools = state[2]
		progress.upgrades = state[0].duplicate()
		progress.coins_found = {0: []}
		for i in int(state[1]) + progress.coins_spent():
			progress.coins_found[0].append("t%d" % i)
		var screen: Control = scene.instantiate()
		root.add_child(screen)
		await process_frame
		var boxes: Array[Rect2] = []
		var names: Array[String] = []
		var ok := true
		var tracks: Array = screen.rows.keys()
		for id: String in tracks:
			var row: Dictionary = screen.rows[id]
			ok = ok and row.pips.size() == Upgrades.max_level(id)
			var level: int = progress.upgrade_level(id)
			for i in row.pips.size():
				var pip: ColorRect = row.pips[i]
				boxes.append(Rect2(pip.position, pip.size))
				names.append("%s pip %d" % [id, i])
				ok = ok and (pip.color == progress.skin_color()) == (i < level)
			for key in ["minus", "plus", "cost", "name"]:
				var node: Control = row[key]
				var size: Vector2 = node.size.max(node.get_combined_minimum_size())
				boxes.append(Rect2(node.position, size))
				names.append("%s %s" % [id, key])
			ok = ok and (row.cost.text == "MAX") == (level >= Upgrades.max_level(id))
			ok = ok and (row.cost.text == "MAX" or row.cost.text == str(Upgrades.cost(id, level)))
		for id in tracks:  # D12: every name sits on its row's middle (no tag pushes one up)
			ok = ok and screen.rows[id].name.position.y == screen.rows[id].y + 6
		var overlap := ""
		for i in boxes.size():
			if not Rect2(10, 20, 300, 150).encloses(boxes[i]):
				overlap = "%s off the rows area %s" % [names[i], boxes[i]]
			for j in range(i + 1, boxes.size()):
				if boxes[i].intersects(boxes[j]):
					overlap = "%s overlaps %s" % [names[i], names[j]]
		var want := 4 if state[2] else 3
		_check(ok and overlap == "" and tracks.size() == want,
			"upgrades screen %s%s: %d tracks, pips per track, MAX/costs right, nothing overlaps%s" % [state[0], " (dev)" if state[2] else "",
			tracks.size(), "" if overlap == "" else " - " + overlap])
		screen.free()
	progress.dev_tools = false
	progress.upgrades = {}
	progress.coins_found = {}
	_check(not UpgradesScreenScript().has_method("effect_text"), "no effect lines on the COINS rows (owner: no explanations)")


## No upgrade is recommended (D12); buying BRIGHTNESS shows the 1 s light-ring preview.
func _preview() -> void:
	progress.dev_tools = false
	progress.upgrades = {}
	progress.coins_found = {0: []}
	for i in 60:
		progress.coins_found[0].append("p%d" % i)
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(not "recommended" in screen and not _texts(screen).any(func(t: String) -> bool: return "RECOMMEND" in t),
		"no RECOMMENDED tag or any other upgrade nudge on the screen (D12)")
	screen.rows.brightness.plus.pressed.emit()
	await process_frame
	_check(screen.preview != null and not screen.hint.visible and progress.upgrade_level("brightness") == 1
		and screen.preview.find_children("*", "Label", true, false).is_empty(),
		"buying BRIGHTNESS shows the light-ring picture (no text) in place of the hint")
	for i in 75:
		await process_frame
	_check(screen.preview == null and screen.hint.visible, "...which is gone after about a second")
	screen.free()
	progress.upgrades = {}
	progress.coins_found = {}


func _texts(node: Node) -> Array:
	var out := []
	for label in node.find_children("*", "Label", true, false):
		out.append((label as Label).text)
	return out


func UpgradesScreenScript() -> GDScript:
	return load("res://scripts/ui/upgrades_screen.gd")


# ---------------------------------------------------------------- helpers

var _made: Array[Node] = []


func _fresh() -> Node:
	var node: Node = PROGRESS.new()
	node.saving_enabled = false
	_made.append(node)
	return node


## A version 5 save of this epoch from before the v2 tree (no [upgrades] tree) with `levels` and
## `coins` story coins found (as debug keys on level 1..10, which count by number).
func _old_save(levels: Dictionary, coins: int) -> ConfigFile:
	var f := ConfigFile.new()
	f.set_value("meta", "version", 5)
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
	for id: String in levels:
		f.set_value("upgrades", id, levels[id])
	return f


