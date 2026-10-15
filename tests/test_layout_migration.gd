extends SceneTree

## Story coin keys and save layouts since the pre-v5 save migrations were removed (spring cleaning,
## 2026-10-15: every release-epoch save is version 5+, docs/itch-release.md): a v5 save's coin keys are
## read as they are; old SLIME1- codes are refused (docs/itch-release.md); hostile values clamp; the
## story coins sit in deep dead ends.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_layout_migration.gd

const PROGRESS := preload("res://scripts/progress.gd")

var failures := 0


func _initialize() -> void:
	await process_frame

	# --- A v5 save's coin keys are read as they are
	var v5 := ConfigFile.new()
	v5.set_value("meta", "version", 5)
	v5.set_value("progress", "levels_cleared", 1)
	v5.set_value("coins", "level_1", ["9,9", "8,8"])
	var s := _fresh()
	s._read(v5)
	_check(s.coins_found[1] == ["9,9", "8,8"], "a version 5 save's coin keys are left as they are")

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
	_check(not h.coins_found.has(1) and not h.coins_found.has(3) and h.coins_found_in(2) == Levels.COINS[1],
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

	for node in [s, u, h]:
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
