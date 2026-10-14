extends SceneTree

## `--story-complete` (./tools/play.sh --story): a player who beat the whole story on normal and hard
## with every coin found, for testing the postgame. Plain player state (no dev tools), no upgrades
## bought (all 165 coins in hand), medals derived from the preset best times, nothing saved and the
## real save never touched. Boots to the title, hub and level select. Never touches the real save
## (only compares it if it exists).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_story_complete.gd

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	var real: String = PROGRESS_SCRIPT.REAL_SAVE_PATH
	var real_exists := FileAccess.file_exists(real)
	var real_md5 := FileAccess.get_md5(real) if real_exists else ""
	var real_mtime := FileAccess.get_modified_time(real) if real_exists else 0

	# Start from a messy state: the flag must replace it all.
	progress.saving_enabled = false
	progress.upgrades = {"slime": 2}
	progress.coins_found = {0: ["debug0"]}
	progress.medals = {3: 1}
	progress.hard_mode = true
	progress.enable_story_complete()

	_check(not progress.saving_enabled and not progress.dev_tools and not progress.dev_bright and not progress.dev_no_drain,
		"nothing is saved and it is not dev mode (no dev tools; F1/F2 stay off)")
	_check(progress.levels_cleared == Levels.COUNT and progress.highest_unlocked == Levels.COUNT and progress.current_level == 1,
		"every level cleared and unlocked on normal")
	var hard_all := true
	for level in range(1, Levels.COUNT + 1):
		hard_all = hard_all and level in progress.hard_cleared
	_check(hard_all and progress.hard_cleared.size() == Levels.COUNT and not progress.hard_mode, "...and on hard (hard mode itself off)")
	_check(Levels.total_coins() == 165 and progress.coins_earned() == Levels.total_coins(), "all %d story coins found" % Levels.total_coins())
	var keys_match := true
	for level in range(1, Levels.COUNT + 1):
		keys_match = keys_match and progress.coins_found.get(level, []) == Array(Levels.coin_keys(level))
		for key: String in Levels.coin_keys(level):
			var xy := key.split(",")
			keys_match = keys_match and progress.has_coin(level, Vector2i(xy[0].to_int(), xy[1].to_int()))
	_check(keys_match and not progress.all_coins_debug, "...as the levels' real coin keys (every coin cell counts as taken)")
	_check(progress.upgrades.is_empty() and progress.coins_spent() == 0 and progress.coins() == 165,
		"no upgrades bought: 165 coins in hand (%d)" % progress.coins())
	_check(progress.has_seen_story(PROGRESS_SCRIPT.STORY_INTRO) and progress.has_seen_story(PROGRESS_SCRIPT.STORY_FINALE)
		and not Story.intro_due(progress), "story intro and finale seen (no cinematic on launch)")
	_check(progress.has_seen_tutorial(PROGRESS_SCRIPT.TUTORIAL_MOVE) and progress.has_seen_tutorial(PROGRESS_SCRIPT.TUTORIAL_LEAP), "tutorial seen")
	_check(progress.is_randomizer_unlocked() and not progress.is_fresh_save(), "randomizer unlocked, not a fresh save")

	var times_ok := true
	for level in range(1, Levels.COUNT + 1):
		for hard in [false, true]:
			var key: int = level + (PROGRESS_SCRIPT.HARD_RECORDS if hard else 0)
			var par := Levels.level_par(level, hard)
			var best: float = progress.best_times.get(key, -1.0)
			var gold: bool = not hard and level <= Levels.COUNT / 2
			times_ok = times_ok and best > par * 0.9 and (best <= par if gold else (best > par and best <= par * PROGRESS_SCRIPT.SILVER_FACTOR))
			times_ok = times_ok and progress.medals.get(key, 0) == PROGRESS_SCRIPT.tier_for(best, par)
	_check(times_ok, "best times near par (normal 1-5 under it, the rest within silver), tiers derived from them")
	_check(progress.medals_total(false) == 25 and progress.medals_total(true) == 20 and not progress.all_medals(),
		"medals: 25/30 normal, 20/30 hard (normal %d, hard %d)" % [progress.medals_total(false), progress.medals_total(true)])

	var skins_ok := true
	for preset: Dictionary in Skins.PRESETS:
		skins_ok = skins_ok and progress.is_skin_unlocked(preset.id, true) and progress.is_skin_unlocked(preset.id, false)
	for id in [Skins.CUSTOM, Skins.RAINBOW]:
		skins_ok = skins_ok and progress.is_skin_unlocked(id, true) and progress.is_skin_unlocked(id, false)
	_check(skins_ok and not progress.is_skin_unlocked(Skins.STOPWATCH), "every jelly and solid skin (rainbow too); stopwatch still locked")
	_check(progress.is_skin_unlocked(progress.selected_skin), "the selected skin (%s) is unlocked" % progress.selected_skin)

	# Nothing is written: neither the throwaway file nor the real save.
	progress.save_progress()
	progress.collect_coin(1, Vector2i(99, 99))
	_check(not FileAccess.file_exists(progress.save_path), "saving writes nothing (not even the throwaway file)")

	# Boots fine: title, hub (medal count, open portal), level select.
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _frames(3)
	_check(title.enter_button.text == "ENTER THE HUB", "the title boots (ENTER THE HUB)")
	title.free()
	load("res://scripts/hub.gd").return_to = ""
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await _frames(3)
	_check(hub.medal_label.text == "25/30", "the hub shows 25/30 medals (%s)" % hub.medal_label.text)
	hub.free()
	var select: Control = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await _frames(3)
	var open := 0
	for button: Button in select.level_buttons:
		open += 0 if button.disabled else 1
	_check(open == Levels.COUNT, "level select: all %d levels open (%d)" % [Levels.COUNT, open])
	select.free()

	if real_exists:
		_check(FileAccess.get_md5(real) == real_md5 and FileAccess.get_modified_time(real) == real_mtime,
			"the real save is byte-identical and untouched")
	else:
		_check(not FileAccess.file_exists(real), "no real save was created")

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
