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
	var paid: int = p.complete_random(false, p.random_seed, 1, 1.0, true, true)
	var r: Dictionary = p.record_daily(61000)
	_check(paid == 20 and p.tickets == t0 + 20 and Economy.DAILY_WIN_TICKETS == 20, "the first win of the day pays 20 tickets (%d)" % paid)
	_check(r.number == 30000 - Economy.DAILY_EPOCH_DAY + 1, "...as DAILY #%d" % r.number)
	_check(r.first and r.streak == 1 and r.best_ms == 61000 and p.daily_won_today(), "...streak 1, best time kept")
	# later win the same day: nothing extra, best only improves
	p.start_daily()
	var again: int = p.complete_random(true, p.random_seed, 1, 1.0)
	var r2: Dictionary = p.record_daily(70000)
	var r3: Dictionary = p.record_daily(55000)
	_check(again == 0 and p.tickets == t0 + 20, "a second win the same day pays nothing")
	var repeat_pay: int = p.random_payout(1, p.random_seed, 1.0, true).tickets
	_check(repeat_pay == 0, "...the seed has paid today: the payout is 0 too (%d)" % repeat_pay)
	var upgrades_before: Dictionary = p.upgrades
	p.upgrades = {}
	p.random_seed_fresh = true
	_check(p.random_payout(1, 424242, 1.0).tickets == p.TICKETS_NO_SLIME_CAP and p.random_payout(1, 424242, 1.0, true).tickets == 20, "the daily's 20 is exempt from the no-MORE-SLIME cap (a normal maze pays %d there)" % p.TICKETS_NO_SLIME_CAP)
	p.upgrades = upgrades_before
	p.random_seed_fresh = false
	_check(p.random_payout(1, 424242, 1.0, true).tickets == 20, "...and from the replay cap")
	_check(p.random_payout(1, 424242, 1.4, true).tickets == 20, "...and from the length factor")
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
	_check(p.tickets == t0 + 20 + 10, "...the 7th day paid 10 tickets once")
	p.day_override = 30007
	_check(p.daily_streak_now() == 7 and not p.daily_won_today(), "the streak shows until the day is missed")
	p.day_override = 30009
	_check(p.daily_streak_now() == 0, "a missed day shows 0")
	var r4: Dictionary = p.record_daily(60000)
	_check(r4.streak == 1 and p.daily_best_streak == 7 and r4.bonus == 0 and not r4.saved, "...the next win restarts at 1, the best streak stays 7")

	# the streak saver: one missed day is covered, once per 7 days
	_check(p.daily_saver_ready(30009) and not p.daily_saver_pending(), "a saver is free and nothing is pending on the day of a win")
	p.day_override = 30011  # day 30010 missed
	_check(p.daily_saver_pending() and p.daily_streak_now() == 1, "one missed day with a free saver: the streak shows as kept (pending)")
	var r5: Dictionary = p.record_daily(60000)
	_check(r5.saved and r5.streak == 2 and p.daily_saver_day == 30011 and not p.daily_saver_pending(), "...winning keeps it: streak 2, STREAK SAVED")
	var wfile: ConfigFile = p._write()
	_check(wfile.get_value("daily", "saver_day", 0) == 30011, "...saver_day is saved")
	p.daily_saver_day = 0
	p._read(wfile)
	_check(p.daily_saver_day == 30011, "...and read back")
	p.day_override = 30013  # day 30012 missed, the saver was used 2 days ago
	_check(not p.daily_saver_pending() and p.daily_streak_now() == 0, "a second miss within the week is not covered")
	var r6: Dictionary = p.record_daily(60000)
	_check(not r6.saved and r6.streak == 1, "...the streak restarts at 1")
	for d in range(30014, 30019):
		p.day_override = d
		p.record_daily(60000)
	_check(p.daily_streak == 6, "six days again (%d)" % p.daily_streak)
	p.day_override = 30020  # 30019 missed; the saver was used 9 days ago
	var r7: Dictionary = p.record_daily(60000)
	_check(r7.saved and r7.streak == 7, "a week later the saver is back (%d)" % r7.streak)
	p.day_override = 30023  # two days missed: not covered
	var r8: Dictionary = p.record_daily(60000)
	_check(not r8.saved and r8.streak == 1, "two missed days are never covered")
	_check(p.daily_number(Economy.DAILY_EPOCH_DAY) == 1 and p.daily_number(Economy.DAILY_EPOCH_DAY + 122) == 123 and p.daily_number(100) == 1, "the day number counts from the epoch (min 1)")
	_check(Economy.DAILY_EPOCH_DAY * 86400 == int(Time.get_unix_time_from_datetime_string("2026-11-01T00:00:00")), "...2026-11-01 is #1")

	_result()
