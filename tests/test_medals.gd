extends "res://tests/suite_base.gd"

## Level medals: 1-3 per level by clear TIME against the level's par (path / base speed x 1.35 + 1 s):
## gold <= par, silver <= 1.3 x par, bronze = any unassisted clear. The best tier is kept per level
## and mode (hard has its own), shown as pips on the level select and under the win text with a
## NEW BEST cue, never pays tickets, and an assisted run earns nothing. all_medals() = every normal
## level gold. Runs real wins (the game as the current scene). Throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_medals.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.hard_mode = false
	progress.reset_progress()

	# --- The tier thresholds
	_check(progress.tier_for(10.0, 12.0) == 3 and progress.tier_for(12.0, 12.0) == 3, "at or under par: gold (3)")
	_check(progress.tier_for(12.1, 12.0) == 2 and progress.tier_for(15.6, 12.0) == 2, "up to 1.3 x par: silver (2)")
	_check(progress.tier_for(15.7, 12.0) == 1 and progress.tier_for(999.0, 12.0) == 1, "slower than that: bronze (1)")
	_check(progress.medals_max() == Levels.COUNT * 3 and Levels.COUNT * 3 == 30, "30 medals to win in all")

	# --- Par comes from the solution path: longer levels get more time, upgrades don't move it
	var par1 := await _par(1)
	var par10 := await _par(10)
	_check(par1 > 5.0 and par10 > par1 * 3.0, "par grows with the path: level 1 %.1f s, level 10 %.1f s" % [par1, par10])
	progress.upgrades = {"speed": 3}
	var fast_par := await _par(1)
	progress.upgrades = {}
	_check(is_equal_approx(fast_par, par1), "speed upgrades don't change the par time")
	_check(is_equal_approx(Levels.level_par(1), par1) and is_equal_approx(Levels.level_par(10), par10), "Levels.level_par (used to migrate old saves) matches the game's par")
	progress.hard_mode = true
	var hard_par := await _par(4)
	progress.hard_mode = false
	_check(is_equal_approx(Levels.level_par(4, true), hard_par), "...also on hard mode (%.1f s)" % hard_par)

	# --- Real clean, quick wins with the autopilot's perfect glide: gold, NEW BEST, no tickets
	for level in [1, 10]:
		progress.reset_progress()
		var game := await _spawn_running(level)
		game.add_child(preload("res://tests/autopilot.gd").new())
		await _until_finished(game, 120.0)
		_check(game.won and game.run_time <= game.par_time, "level %d: a perfect glide (%.1f s) beats its par (%.1f s)" % [level, game.run_time, game.par_time])
		_check(game.reward.tier == 3 and game.reward.new_best and progress.medals_for(level) == 3, "...gold, saved, and a NEW BEST")
		_check(progress.tickets == 0, "...medals pay no tickets")
		_check("GOLD" in game.hud.rewards_texts and "NEW BEST!" in game.hud.rewards_texts and game.hud.rewards_row.visible, "...and the win screen shows GOLD and NEW BEST!")
		await _stop(game)

	# --- The best tier is kept: slower replays don't lower it, faster ones raise it
	progress.reset_progress()
	var r: Dictionary = progress.record_clear(1, 99.0, 10.0)
	_check(r.tier == 1 and r.new_best and progress.medals_for(1) == 1, "a slow first clear is bronze and counts as a new best")
	r = progress.record_clear(1, 99.0, 10.0)
	_check(r.tier == 1 and not r.new_best and progress.medals_for(1) == 1, "the same tier again is no new best")
	r = progress.record_clear(1, 12.0, 10.0)
	_check(r.tier == 2 and r.new_best and progress.medals_for(1) == 2, "faster: silver, new best")
	r = progress.record_clear(1, 99.0, 10.0)
	_check(r.tier == 1 and r.best == 2 and not r.new_best and progress.medals_for(1) == 2, "a slower replay keeps the silver")
	r = progress.record_clear(1, 9.0, 10.0)
	_check(r.tier == 3 and progress.medals_for(1) == 3, "gold")
	_check(progress.tickets == 0 and progress.tickets_lifetime == 0, "no medal ever pays tickets")

	# --- Assisted runs earn nothing
	r = progress.record_clear(2, 1.0, 10.0, true, true)
	_check(r.assisted and r.tier == 0 and not r.new_best and progress.medals_for(2) == 0 and progress.levels_cleared == 0 and not progress.best_times.has(2),
		"an assisted clear earns no tier, record or cleared mark")

	# --- Hard mode: its own tiers (level_N+100), not counted toward all_medals()
	progress.hard_mode = true
	r = progress.record_clear(2, 4.0, 10.0, false, true)
	_check(r.tier == 3 and progress.medals_for(2) == 3 and progress.medal_key(2) == 102 and progress.medals.get(2, 0) == 0, "hard clears keep their own tiers (level_102)")
	_check(progress.medals_total() == 3 and progress.medals_total(false) == 3 and progress.medals_total(true) == 3, "(1 normal + 1 hard gold)")
	progress.hard_mode = false
	_check(progress.medals_for(2) == 0, "...the normal tier for that level is untouched")
	progress.reset_progress()
	progress.hard_mode = true
	var game := await _spawn_running(2)
	game.add_child(preload("res://tests/autopilot.gd").new())
	await _until_finished(game, 120.0)
	_check(game.won and game.reward.tier == 3 and progress.medals.get(102, 0) == 3, "a perfect hard-mode glide is gold too (%.1f s of par %.1f s)" % [game.run_time, game.par_time])
	await _stop(game)
	progress.hard_mode = false

	# --- all_medals()
	progress.reset_progress()
	_check(not progress.all_medals(), "all_medals is false on a fresh save")
	for level in range(1, Levels.COUNT + 1):
		progress.medals[level] = 3
	_check(progress.all_medals() and progress.medals_total() == 30, "true when every normal level is gold (30/30)")
	progress.medals[7] = 2
	_check(not progress.all_medals() and progress.medals_total() == 29, "one silver breaks it")
	progress.medals[7] = 3
	progress.medals.erase(3)
	for level in range(1, Levels.COUNT + 1):
		progress.medals[level + 100] = 3
	_check(not progress.all_medals(), "hard-mode gold doesn't stand in for a normal level")
	progress.medals[3] = 3
	_check(progress.all_medals(), "(and all 10 gold counts regardless of hard tiers)")

	# --- Saved small, and shown on the level select
	progress.reset_progress()
	progress.medals = {1: 3, 2: 2, 102: 1}
	var file: ConfigFile = progress._write()
	_check(file.get_value("medals", "level_1") == 3 and file.get_value("medals", "level_102") == 1 and file.get_section_keys("medals").size() == 3,
		"medals are small ints under [medals] level_N (hard under N+100)")
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	progress.highest_unlocked = 4
	root.add_child(screen)
	await process_frame
	var pips: Array[int] = []
	for tile in 3:
		var gold := 0
		for child in screen.level_buttons[tile].get_children():
			if child is ColorRect and child.color == UIKit.GOLD:
				gold += 1
		pips.append(gold)
	_check(pips == [3, 2, 0], "tiles show 3 / 2 / 0 gold pips for gold / silver / none (%s)" % [pips])
	screen.free()
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
	quit(1 if failures else 0)


func _par(level: int) -> float:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	var par: float = game.par_time
	game.free()
	return par


func _spawn_running(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _until_finished(game: Node2D, max_seconds: float) -> void:
	for i in int(max_seconds * 60.0):
		await physics_frame
		if game.finished:
			return


## Detaches the game before its end-of-level timer fires (so it doesn't reload), then frees it.
func _stop(game: Node2D) -> void:
	current_scene = null
	for i in int(game.CHOICE_DELAY * 60) + 10:
		await physics_frame
	game.free()


