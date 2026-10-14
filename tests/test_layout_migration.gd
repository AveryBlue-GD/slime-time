extends SceneTree

## Save migration to version 4 (the redesigned story layouts, docs/level-design.md): story coin
## keys from older saves are re-mapped by COUNT to the new layout's first N coins, so coins earned
## and spent (upgrades) are unchanged; stored medal tiers, normal best times and hard clears are kept
## (hard best times are dropped since version 5's bigger hard mazes, see test_hard_rebalance.gd);
## pre-v3 best times still become tiers against the OLD pars; migrating twice gives the same result;
## old SLIME1- codes are refused (docs/itch-release.md); hostile values clamp; v4 saves are untouched.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_layout_migration.gd

const PROGRESS := preload("res://scripts/progress.gd")

var failures := 0


func _initialize() -> void:
	await process_frame

	# --- Old (v3) save: partial coins per level, upgrades bought, medals, records, hard clears
	var old := _v3_save()
	var p := _fresh()
	p._read(old)
	_check(p.coins_found_in(1) == 2 and p.coins_found_in(4) == 5 and p.coins_found_in(2) == Levels.COINS[1] and p.coins_found_in(3) == 1,
		"each level keeps its coin COUNT (2, 9 capped, 1 of the valid strings, 5)")
	# (The old tree's SLIME 3 / SPEED 2 = 6 + 3 coins also go through the upgrades v2 remap, see
	# test_upgrades_v2.gd: SLIME 2 (5 coins) and SPEED 0, the other 4 coins back in hand.)
	_check(p.coins_earned() == 2 + 9 + 1 + 5 and p.coins_spent() == 5 and p.coins() == 12,
		"coins earned 17, spent 5 on upgrades after the tree remap, 12 in hand: nothing lost, nothing negative")
	_check(p.upgrade_level("slime") == 2 and p.upgrade_level("speed") == 0 and p.tree_refund_notice == 4, "bought upgrades are remapped by coins invested (4 back)")
	var keys1: Array = p.coins_found[1]
	_check(keys1 == Levels.coin_keys(1).slice(0, 2) and keys1 != ["2,3", "5,1"], "level 1's coins are now the first 2 coins of the new layout %s" % [keys1])
	var maze := Levels.story_maze(1)
	var cells := Levels.coin_cells(maze, 1, Levels.get_config(1).seed)
	_check(p.has_coin(1, cells[0]) and p.has_coin(1, cells[1]) and not p.has_coin(1, cells[2]), "...so those two are found and the rest still wait in the maze")
	_check(not p.coins_found.has(11) and not p.coins_found.has(5), "unknown levels and empty lists are dropped")
	_check(p.medals_for(1) == 3 and p.medals_for(2) == 1 and p.medals.get(101, 0) == 2, "stored medal tiers are kept (never downgraded), hard ones too")
	_check(p.best_times[1] == 12.5 and not p.best_times.has(101) and p.levels_cleared == 4 and p.hard_cleared == [1, 2],
		"normal best times, clears and hard clears are kept as they are; the old hard time is cleared (v5)")

	# --- Idempotent: the same old save read again, and the migrated save read back
	var q := _fresh()
	q._read(_v3_save())
	_check(q.coins_found == p.coins_found and q.medals == p.medals, "reading the same old save again gives the same result")
	var written: ConfigFile = p._write()
	_check(written.get_value("meta", "version") == PROGRESS.SAVE_VERSION, "the next save is version %d" % PROGRESS.SAVE_VERSION)
	var r := _fresh()
	r._read(written)
	_check(r.coins_found == p.coins_found and r.medals == p.medals and r.coins() == p.coins() and r.best_times == p.best_times,
		"a migrated save read back is unchanged (no second migration)")

	# --- A v4 save is not touched
	var v4 := ConfigFile.new()
	v4.set_value("meta", "version", 4)
	v4.set_value("progress", "levels_cleared", 1)
	v4.set_value("coins", "level_1", ["9,9", "8,8"])
	var s := _fresh()
	s._read(v4)
	_check(s.coins_found[1] == ["9,9", "8,8"], "a version 4 save's coin keys are left as they are")

	# --- v2 save: best times become tiers against the OLD layout's par (as before the redesign)
	var v2 := ConfigFile.new()
	v2.set_value("meta", "version", 2)
	v2.set_value("progress", "levels_cleared", 3)
	v2.set_value("progress", "hard_cleared", [2])
	v2.set_value("records", "level_1", Levels.legacy_par(1) * 0.95)
	v2.set_value("records", "level_2", Levels.legacy_par(2) * 1.2)
	v2.set_value("records", "level_102", Levels.legacy_par(2, true) * 0.9)
	v2.set_value("coins", "level_1", ["0,0"])
	var t := _fresh()
	t._read(v2)
	_check(t.medals_for(1) == 3 and t.medals_for(2) == 2 and t.medals_for(3) == 1 and t.medals.get(102, 0) == 3,
		"v2 best times -> tiers against the old pars (gold, silver, bronze; hard gold)")
	_check(t.coins_found[1] == Levels.coin_keys(1).slice(0, 1), "v2 coins migrate the same way")

	# --- Pre-release SLIME1- save codes are refused (fresh-start policy): nothing migrates in
	var code := "SLIME1-" + Marshalls.raw_to_base64(_v3_save().encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var u := _fresh()
	_check(not u.load_code(code) and u.coins_found.is_empty() and u.medals.is_empty() and u.is_old_code(code), "an old SLIME1- save code is refused as old")

	# --- Hostile values clamp safely
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", "four")
	bad.set_value("progress", "levels_cleared", 99)
	bad.set_value("coins", "level_1", 12345)
	var flood: Array = []
	for i in 5000:
		flood.append("x%d" % i)
	bad.set_value("coins", "level_2", flood)
	bad.set_value("coins", "level_3", [null, 7, [1], {"a": 1}])
	bad.set_value("upgrades", "slime", 99)
	bad.set_value("upgrades", "speed", -5)
	bad.set_value("medals", "level_1", 99)
	bad.set_value("records", "level_1", INF)
	var h := _fresh()
	h._read(bad)
	_check(not h.coins_found.has(1) and not h.coins_found.has(3) and h.coins_found_in(2) == Levels.COINS[1] and h.coins_found[2].size() == Levels.COINS[1],
		"junk coin lists: a number or non-strings count 0, a flood caps at the level's coins")
	_check(h.coins() >= 0 and h.upgrade_level("speed") == 0 and h.levels_cleared == Levels.COUNT, "upgrades are clamped to what was earned; levels clamp")
	_check(h.medals_for(1) <= 3, "a wild stored tier can't exceed gold")

	# --- The new coin layout prefers deep dead ends
	var deep := 0
	var total := 0
	for level in range(1, Levels.COUNT + 1):
		var m := Levels.story_maze(level)
		var depths := MazeGenerator.dead_end_depths(m)
		for cell in Levels.coin_cells(m, level, Levels.get_config(level).seed):
			total += 1
			if depths[cell] >= Levels.COIN_DEEP:
				deep += 1
	_check(total == Levels.total_coins() and deep * 100 >= total * 75, "%d of %d coins sit %d+ cells deep in their dead end" % [deep, total, Levels.COIN_DEEP])

	for node in [p, q, r, s, t, u, h]:
		node.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _fresh() -> Node:
	var node: Node = PROGRESS.new()
	node.saving_enabled = false
	return node


func _v3_save() -> ConfigFile:
	var f := ConfigFile.new()
	f.set_value("meta", "version", 3)
	f.set_value("progress", "levels_cleared", 4)
	f.set_value("progress", "highest_unlocked", 5)
	f.set_value("progress", "hard_cleared", [1, 2])
	f.set_value("coins", "level_1", ["2,3", "5,1"])
	var many: Array = []
	for i in 12:
		many.append("%d,0" % i)
	f.set_value("coins", "level_2", many)  # 12 keys on a 9-coin level (counted as 9 before too)
	f.set_value("coins", "level_3", ["1,1", 42])  # one valid string
	f.set_value("coins", "level_4", ["0,1", "0,2", "0,3", "0,4", "0,5"])
	f.set_value("coins", "level_5", [])
	f.set_value("coins", "level_11", ["0,0"])
	f.set_value("upgrades", "slime", 3)  # 1 + 2 + 3 = 6
	f.set_value("upgrades", "speed", 2)  # 1 + 2 = 3
	f.set_value("records", "level_1", 12.5)
	f.set_value("records", "level_101", 30.0)
	f.set_value("medals", "level_1", 3)
	f.set_value("medals", "level_2", 1)
	f.set_value("medals", "level_101", 2)
	return f


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
