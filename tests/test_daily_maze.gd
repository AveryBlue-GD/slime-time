extends "res://tests/suite_base.gd"

## IMP-06 daily maze (Economy.DAILY_MAZE): one seed per UTC day, MORE SLIME 0 and normal rules, the first
## win of a day pays like attempt 1 and later wins nothing, best time per day, a win streak (a missed
## day resets it) with 10 tickets at every 7th day, and the [daily] save round trip.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_daily_maze.gd

var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	var p: Node = root.get_node("Progress")
	p.save_path = test_save
	p.dev_tools = false
	p.saving_enabled = false
	p.day_override = 30000
	p.upgrades = {"slime": 1}

	var s0: int = p.daily_seed(30000)
	_check(s0 == p.daily_seed(30000) and s0 >= 1 and s0 <= 2_000_000_000, "the seed is stable for a day and in range (%d)" % s0)
	_check(p.daily_seed(30001) != s0 and p.daily_seed(29999) != s0, "...and differs on the next day")
	p.start_daily()
	_check(p.random_daily and p.random_seed == s0 and p.random_level == 0 and p.random_seed_fresh, "start_daily sets today's seed at MORE SLIME 0")
	var cfg := Levels.random_config(p.random_seed, false, 0)
	_check(cfg.cells.x > 0 and Economy.daily_maze(), "...a valid maze, and the daily is on")
	p.new_random_maze()
	_check(not p.random_daily, "NEW MAZE leaves the daily")

	# first win of the day: pays attempt 1, streak 1
	var t0: int = p.tickets
	p.start_daily()
	var paid: int = p.complete_random(false, p.random_seed, 1, 1.0)
	var r: Dictionary = p.record_daily(61000)
	_check(paid == 10 and p.tickets == t0 + 10, "the first win of the day pays attempt 1 (%d)" % paid)
	_check(r.first and r.streak == 1 and r.best_ms == 61000 and p.daily_won_today(), "...streak 1, best time kept")
	# later win the same day: nothing extra, best only improves
	p.start_daily()
	var again: int = p.complete_random(true, p.random_seed, 1, 1.0)
	var r2: Dictionary = p.record_daily(70000)
	var r3: Dictionary = p.record_daily(55000)
	_check(again == 0 and p.tickets == t0 + 10, "a second win the same day pays nothing")
	_check(not r2.first and r2.streak == 1 and r2.best_ms == 61000 and not r2.new_best and r3.new_best and r3.best_ms == 55000, "...the streak stays, the best time only improves")

	# save round trip
	var file: ConfigFile = p._write()
	_check(file.get_value("daily", "day", 0) == 30000 and file.get_value("daily", "best_ms", 0) == 55000 and file.get_value("daily", "streak", 0) == 1, "[daily] is written")
	p.daily_day = 0
	p.daily_best_ms = 0
	p.daily_streak = 0
	p.daily_best_streak = 0
	p._read(file)
	_check(p.daily_day == 30000 and p.daily_best_ms == 55000 and p.daily_streak == 1 and p.daily_best_streak == 1, "...and read back")
	var old := ConfigFile.new()
	p._read(old)
	_check(p.daily_day == 0 and p.daily_streak == 0, "a save without [daily] reads as defaults")
	p._read(file)

	# streak: consecutive days grow, 7th pays 10 tickets, a missed day resets
	for d in range(30001, 30007):
		p.day_override = d
		p.record_daily(60000)
	_check(p.daily_streak == 7 and p.daily_best_streak == 7, "seven days in a row make a streak of 7")
	_check(p.tickets == t0 + 10 + 10, "...the 7th day paid 10 tickets once")
	p.day_override = 30007
	_check(p.daily_streak_now() == 7 and not p.daily_won_today(), "the streak shows until the day is missed")
	p.day_override = 30009
	_check(p.daily_streak_now() == 0, "a missed day shows 0")
	var r4: Dictionary = p.record_daily(60000)
	_check(r4.streak == 1 and p.daily_best_streak == 7 and r4.bonus == 0, "...the next win restarts at 1, the best streak stays 7")

	_result()
