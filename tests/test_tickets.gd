extends "res://tests/suite_base.gd"

## Ticket vouchers (the renewable cosmetic currency): the ONLY faucet is the randomizer, whose goal is
## a ticket (a win pays by attempt: 5, 4, 3, 2, then 1; dry-up retries and restarts count, NEW MAZE
## resets; 5 paying wins per UTC day, so 25 a day at most; 1 at most with no MORE SLIME upgrade bought
## or for a typed / replayed seed; nothing for a seed already paid today), nothing else pays (first clears,
## hard clears, medals); the per-day cap goes forwards and backwards in time; the hat wheel's atomic
## spin (free first spin, 12 tickets after, picked + paid + won + saved before the wheel turns,
## rainbow pity) and its lock outside dev mode while hats are placeholders; the save (kept under the
## old [wallet] "globs" keys); reading saves and save codes (an existing balance kept as it is, no
## retro grant, the old paid masks dropped, idempotent, hostile values); RESET PROGRESS. Uses a
## throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_tickets.gd

var test_save := throwaway_save()
const MAIN := preload("res://scenes/main.tscn")

var progress: Node


func _initialize() -> void:
	Economy.random_tickets_force = 0  # (the attempt pod's chalice number alone: no ticket pickups in these mazes)
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	_check(not Economy.RANDOM_DAILY_CAP and not Economy.random_daily_cap_on(), "there is no daily limit on randomizer payouts by default")
	progress.random_paid = progress.RANDOM_PAID_PER_DAY
	progress.random_pay_day = progress.utc_day()
	_check(progress.random_payout(1).cap != "daily", "...so a win past the old 5 a day still pays")
	progress.random_paid = 0
	progress.random_pay_day = 0
	Economy.random_cap_force = 1  # the cap's own behaviour below (kept so it can come back)
	progress.hard_mode = false
	progress.reset_progress()

	# --- Story clears, hard clears and medals pay nothing
	var win: Dictionary = progress.record_clear(1, 5.0, 10.0, false, true)
	_check(win.tier == 3 and progress.tickets == 0 and progress.tickets_lifetime == 0, "a first clear with a gold medal pays no tickets")
	progress.hard_mode = true
	progress.record_clear(1, 5.0, 10.0, false, true)
	progress.hard_mode = false
	_check(progress.tickets == 0 and "tickets" not in win, "...nor does a hard clear or a result carry tickets")
	progress.add_tickets(30)
	var coins_before: int = progress.coins()
	progress.coins_found = {1: ["1,1", "2,2"]}
	_check(progress.coins() == coins_before + 2 and progress.tickets == 30, "tickets and coins never mix")
	progress.add_tickets(-progress.tickets)
	_check(progress.tickets == 0, "(spent down to zero)")
	progress.add_tickets(1_000_000)
	_check(progress.tickets == progress.TICKETS_MAX, "the balance is capped at 99,999")
	progress.reset_progress()

	# --- Randomizer payout by attempt: 5, 4, 3, 2, then 1 from the fifth on; 5 paying wins per UTC day
	progress.day_override = 20000
	progress.upgrades = {"slime": 1}
	var table_ok := true
	for n in range(1, 11):
		table_ok = table_ok and progress.random_tickets_due(n) == [10, 8, 6, 4, 2, 1, 1, 1, 1, 1][n - 1]
	_check(table_ok and progress.tickets_for_attempt(1) == 10 and progress.tickets_for_attempt(0) == 10 and progress.tickets_for_attempt(99) == 1,
		"attempt 1 pays 10, 2 pays 8, 3 pays 6, 4 pays 4, 5 pays 2, the 6th and every later one 1")
	var paid := 0
	for i in 8:
		paid += progress.complete_random(false, 0, 1)
	_check(progress.tickets == 50 and paid == 50 and progress.randoms_won == 8, "first-try wins pay 10 each, 5 paying wins a day: 50 at most (%d tickets from 8 wins)" % paid)
	_check(progress.random_tickets_due(1) == 0 and progress.random_payout(1).cap == "daily", "...a sixth win that day pays nothing (daily cap)")
	progress.day_override = 20001
	_check(progress.complete_random(false, 0, 3) == 6 and progress.tickets == 56, "the next UTC day pays again (attempt 3 = 6)")
	_check(progress.complete_random(true, 0, 1) == 0 and progress.tickets == 56, "an assisted (or dev-toggled) win never pays")
	# the clock moving backwards never reopens the cap; moving forwards does
	progress.reset_progress()
	progress.upgrades = {"slime": 1}
	progress.day_override = 20010
	for i in 5:
		progress.complete_random()
	_check(progress.random_tickets_due() == 0 and progress.random_pay_day == 20010, "five paid wins use up the day's cap")
	progress.day_override = 20005  # clock set back
	_check(progress.random_tickets_due() == 0 and progress.complete_random() == 0, "an earlier day (clock moved back) keeps the cap")
	# (5 days back is more than Progress.PAY_DAY_AHEAD: the stored day counts as today, with today's count kept)
	_check(progress.random_pay_day == 20005 and progress.random_paid == 5, "...and keeps the count (a stored day far ahead counts as today)")
	progress.day_override = 20011
	_check(progress.random_tickets_due() == 10 and progress.complete_random() == 10 and progress.random_pay_day == 20011 and progress.random_paid == 1, "a later day starts the cap over")
	progress.day_override = 20012
	_check(progress.random_tickets_due() == 10, "(the day after, again)")
	progress.day_override = -1
	progress.reset_progress()

	# --- No MORE SLIME bought: at most 1 a win, whatever the attempt
	progress.upgrades = {"speed": 4}
	_check(progress.random_tickets_due(1) == 1 and progress.random_payout(1).cap == "slime" and progress.random_tickets_due(5) == 1 and progress.random_payout(5).cap == "slime",
		"zero slime upgrades: a first-try win pays only 1 (capped), the 5th try too")
	progress.day_override = 20020
	_check(progress.complete_random(false, 0, 1) == 1 and progress.tickets == 1, "...and a real payout is 1")
	progress.upgrades = {"slime": 1}
	_check(progress.random_tickets_due(1) == 10, "one MORE SLIME level lifts the cap")
	progress.day_override = -1
	progress.reset_progress()

	# --- Through the game: the attempt pod, dry-up retries and restarts count, NEW MAZE resets
	progress.day_override = 30000
	progress.upgrades = {"slime": 1}
	progress.new_random_maze()
	var maze_seed: int = progress.random_seed
	var game := await _spawn_random(maze_seed)
	_check(game.attempt == 1 and game.hud.attempt_pod.visible and game.hud.attempt_label.text == "ATTEMPT 1\nTIX AVAILABLE 10", "first start: attempt 1, the pod says ATTEMPT 1\nTIX AVAILABLE 10 (%s)" % game.hud.attempt_label.text)
	game.slime_remaining = 0.0
	for i in 30:
		await physics_frame
	_check(game.finished and not game.won, "(dried up)")
	game.retry()  # the dry-up's RESTART button: the real scene reload
	game = await _current_game()
	_check(game.attempt == 2 and game.random_seed == maze_seed and game.hud.attempt_label.text == "ATTEMPT 2\nTIX AVAILABLE 8", "a dry-up retry is attempt 2: ATTEMPT 2\nTIX AVAILABLE 8 (%s)" % game.hud.attempt_label.text)
	var press := InputEventAction.new()  # R mid-run (no coins in hand: restarts at once)
	press.action = "restart"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	game = await _current_game()
	_check(game.attempt == 3 and game.hud.attempt_label.text == "ATTEMPT 3\nTIX AVAILABLE 6", "a manual restart counts too: ATTEMPT 3\nTIX AVAILABLE 6 (%s)" % game.hud.attempt_label.text)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.won and game.reward.tickets == 6 and progress.tickets == 6 and "TICKET! ATTEMPT 3 = +6" in game.hud.rewards_texts and game.hud.rewards_row.visible,
		"winning on attempt 3 pays 6 and the result says TICKET! ATTEMPT 3 = +6 (%s)" % [game.hud.rewards_texts])
	game.replay()  # REPLAY MAZE: another attempt at a seed that already paid today
	game = await _current_game()
	_check(game.attempt == 4 and game.hud.attempt_label.text == "ATTEMPT 4\nTIX AVAILABLE 0", "replaying the won maze is attempt 4 and would pay nothing (%s)" % game.hud.attempt_label.text)
	game.play_next()  # NEW MAZE
	game = await _current_game()
	_check(game.random_seed != maze_seed and game.attempt == 1 and progress.random_attempts.size() == 1 and game.hud.attempt_label.text == "ATTEMPT 1\nTIX AVAILABLE 10",
		"NEW MAZE starts over at attempt 1 (and forgets the old counts)")
	for i in 5:  # five more starts of this maze: attempts 2-6
		game.retry()
		game = await _current_game()
	_check(game.attempt == 6 and game.hud.attempt_label.text == "ATTEMPT 6\nTIX AVAILABLE 1", "the 6th attempt would pay 1 (%s)" % game.hud.attempt_label.text)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.reward.tickets == 1 and "TICKET! ATTEMPT 6 = +1" in game.hud.rewards_texts and game.hud.rewards_texts.size() == 1,
		"a 6th-try win pays 1, with no cap reason (%s)" % [game.hud.rewards_texts])
	await _stop(game)
	_check(progress.random_attempt_key(42, 3) == Levels.seed_code(42, 3) and progress.random_attempt_key(42, 0, true) != progress.random_attempt_key(42, 0),
		"attempts are counted per seed code (hard mode apart)")
	progress.reset_progress()

	# --- Caps on the result screen: typed / replayed seed, no MORE SLIME, daily limit; hard mode follows the table
	progress.day_override = 30000
	progress.upgrades = {"slime": 1}
	progress.random_seed_fresh = false  # typed in
	game = await _spawn_random(780)
	_check(game.hud.attempt_label.text == "ATTEMPT 1\nTIX AVAILABLE 1", "a typed seed's pod shows 1 ticket at most (%s)" % game.hud.attempt_label.text)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.reward.tickets == 1 and "TICKET! ATTEMPT 1 = +1" in game.hud.rewards_texts and "REPLAYED SEED" in game.hud.rewards_texts,
		"a typed seed's first-try win pays 1 and says REPLAYED SEED (%s)" % [game.hud.rewards_texts])
	await _stop(game)
	progress.reset_progress()
	progress.day_override = 30000
	game = await _spawn_random(777)
	_check(game.hud.attempt_label.text == "ATTEMPT 1\nTIX AVAILABLE 1", "no slime upgrade: the pod shows 1 ticket (%s)" % game.hud.attempt_label.text)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.reward.tickets == 1 and game.hud.rewards_texts == ["TICKET! ATTEMPT 1 = +1"],
		"no slime upgrade: a first-try win pays 1, and no line nudges toward an upgrade (D12) (%s)" % [game.hud.rewards_texts])
	await _stop(game)
	progress.reset_progress()
	progress.day_override = 30000
	progress.upgrades = {"slime": 1}
	progress.hard_mode = true
	game = await _spawn_random(778)
	game.queue_free()
	await process_frame
	game = await _spawn_random(778)
	_check(game.hard_mode and game.attempt == 2 and game.attempt_key.ends_with("H"), "hard mode counts attempts too (its own key)")
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.reward.tickets == 8 and progress.tickets == 8 and "TICKET! ATTEMPT 2 = +8" in game.hud.rewards_texts, "hard mode follows the same table (attempt 2 = +8)")
	await _stop(game)
	progress.hard_mode = false
	progress.random_paid = 5
	game = await _spawn_random(779)
	_check(game.hud.attempt_label.text == "ATTEMPT 1\nTIX AVAILABLE 0", "past the daily cap the pod shows 0 tickets (%s)" % game.hud.attempt_label.text)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(progress.tickets == 8 and "DAILY TICKET LIMIT REACHED" in game.hud.rewards_texts, "past the daily cap nothing is paid, and the screen says so")
	await _stop(game)
	progress.day_override = -1
	progress.reset_progress()

	# --- The hat wheel: live for every player; the Hats.available switch can still turn spins off
	progress.tickets = 100
	_check(Hats.available and progress.can_spin_hats(), "hats are live: a player can spin (upgrades v2 batch 2)")
	Hats.available = false
	_check(not progress.can_spin_hats() and progress.spin_hat() == "" and progress.tickets == 100,
		"with the switch off: no spin outside dev mode, even with tickets (nothing is taken)")
	Hats.available = true

	# --- Atomic spin
	progress.tickets = 100
	var cost: int = progress.spin_cost()
	_check(cost == 0, "the first spin is free")
	var first: String = progress.spin_hat(0.0)
	_check(first != "" and first in progress.hats_owned and progress.tickets == 100 and progress.spins == 1, "free spin: hat won, nothing paid (%s)" % first)
	_check(progress.spin_cost() == 20, "the next one costs 20")
	var second: String = progress.spin_hat(0.0)
	_check(second != "" and second != first and progress.tickets == 80 and progress.hats_owned.size() == 2, "spin 2: pays 20, never a hat you own (%s)" % second)
	# The whole spin is saved at once: a fresh load sees the payment AND the prize.
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = test_save
	reloaded.load_progress()
	_check(reloaded.tickets == 80 and second in reloaded.hats_owned and reloaded.spins == 2, "payment and prize are saved together, before any animation")
	reloaded.free()
	progress.tickets = 5
	_check(not progress.can_spin_hats() and progress.spin_hat() == "" and progress.tickets == 5 and progress.hats_owned.size() == 2,
		"too few tickets: no spin, nothing changes")
	_check(progress.spin_cost() == 20, "spin 3 costs 20 too (a flat price, owner 2026-10-22)")
	progress.tickets = 19
	_check(not progress.can_spin_hats(), "19 is not enough for 20")
	progress.tickets = 20
	_check(progress.spin_hat() != "" and progress.tickets == 0, "exactly 20 is enough")
	_check(progress.spin_cost_after(0) == 0 and progress.spin_cost_after(1) == 20 and progress.spin_cost_after(2) == 20 and progress.spin_cost_after(5) == 20
		and progress.spin_cost_after(15) == 20 and progress.spin_cost_after(500) == progress.SPIN_COST_MAX, "price: the first spin free, then 20 every time")
	var hostile_spins := [1 << 62, (1 << 62) - 1, 1 << 61, 9_223_372_036_854_775_807, 3_000_000_000, 100000, 21, 22]
	var safe := true
	for n in hostile_spins:
		var price: int = progress.spin_cost_after(n)
		safe = safe and price >= progress.SPIN_COST and price <= progress.SPIN_COST_MAX
	_check(safe and progress.spin_cost_after(1 << 62) == progress.SPIN_COST_MAX, "a huge spin count never gives a negative or free price")
	var evil := ConfigFile.new()
	evil.set_value("meta", "version", 3)
	evil.set_value("progress", "levels_cleared", 3)
	evil.set_value("hats", "spins", 1 << 62)
	var evil_progress: Node = preload("res://scripts/progress.gd").new()
	evil_progress._read(evil)
	_check(evil_progress.spins == evil_progress.SPINS_MAX and evil_progress.spin_cost() == evil_progress.SPIN_COST_MAX, "a hostile save's spins are clamped on load")
	var evil_code: String = evil_progress.save_code()
	evil_progress.free()
	_check(progress.read_code(evil_code) != null, "(the hostile save still round-trips as a save code)")
	var last_cost := 0
	var rising := true
	for n in range(1, 41):
		rising = rising and progress.spin_cost_after(n) >= last_cost
		last_cost = progress.spin_cost_after(n)
	_check(rising, "each spin costs at least as much as the last")
	progress.dev_tools = true
	progress.tickets = 0
	_check(progress.can_spin_hats() and progress.spin_cost() == 0 and progress.spin_hat() != "" and progress.tickets == 0, "dev mode spins free")
	progress.dev_tools = false

	# The wheel node asks Progress first: paid and won the moment spin() returns, before it turns.
	progress.reset_progress()
	progress.tickets = 38
	progress.spins = 1
	var wheel: Control = load("res://scripts/ui/hat_wheel.gd").new()  # (loaded late: it names the Progress autoload)
	root.add_child(wheel)
	await process_frame
	_check(wheel.spin() and wheel.spinning and progress.tickets == 18 and progress.hats_owned.size() + progress.cosmetics_owned.size() == 1,
		"the wheel's spin is already paid and won while it's still turning")
	var landed_ids: Array[String] = []
	wheel.landed.connect(func(id: String) -> void: landed_ids.append(id))
	for i in 60 * 6:
		await physics_frame
		if not landed_ids.is_empty():
			break
	var landed: String = landed_ids[0] if not landed_ids.is_empty() else ""
	var owned_now: Array[String] = progress.hats_owned + progress.cosmetics_owned
	_check(owned_now.size() == 1 and landed == owned_now[0] and wheel.hats[wheel.wedge_at(wheel.turn)] == landed,
		"...and the wheel lands on exactly the hat it already won (%s)" % landed)
	_check(progress.tickets == 18, "landing charges nothing more")
	wheel.free()

	# --- Rainbow pity
	_check(progress.wheel_weight("rainbow") == Economy.WHEEL_RARE_WEIGHT and is_equal_approx(progress.wheel_weight("rainbow", 4), Economy.WHEEL_RARE_WEIGHT + 4 * Hats.PITY_STEP)
		and progress.wheel_weight("tophat", 9) == Economy.WHEEL_WEIGHT, "each missed spin fattens only the rainbow wedge")
	var ids := Hats.ids()
	_check(ids[-1] == "rainbow" and progress.wheel_pick(ids, 0, 0.0) == "tophat" and progress.wheel_pick(ids, 0, 0.9999) == "rainbow",
		"a roll walks along the wedges in wheel order (the rainbow hat last)")
	var odds: Array[int] = []
	for pity in [0, 10, 40]:
		var hits := 0
		for i in 1000:
			if progress.wheel_pick(ids, pity, i / 1000.0) == "rainbow":
				hits += 1
		odds.append(hits)
	_check(odds[0] < odds[1] and odds[1] < odds[2], "rainbow odds grow with pity: %s in 1000" % [odds])
	progress.reset_progress()
	progress.tickets = 1000
	progress.spins = 1
	var miss := 0
	for i in 3:
		progress.spin_hat(0.0)  # always the first hat left, never the rainbow
		miss += 1
	_check(progress.rainbow_pity == miss, "every spin that misses the rainbow adds pity (%d)" % progress.rainbow_pity)
	progress.hats_owned.assign(ids.filter(func(id: String) -> bool: return id != "rainbow"))
	progress.cosmetics_owned.assign(Cosmetics.wheel_ids())  # (the wheel trails won too)
	_check(progress.spin_hat(0.0) == "rainbow" and progress.rainbow_pity == 0, "the last hat left is the rainbow one, and landing it resets the pity")
	_check(progress.hats_left().is_empty() and not progress.can_spin_hats(), "an empty wheel can't spin")
	Hats.available = false

	# --- The save: round trip (tickets under the old [wallet] "globs" keys, medals as tier ints)
	progress.reset_progress()
	progress.levels_cleared = 4
	progress.hard_cleared.assign([1])
	progress.tickets = 37
	progress.tickets_lifetime = 120
	progress.medals = {1: 3, 3: 2, 101: 1}
	progress.spins = 4
	progress.rainbow_pity = 3
	progress.random_pay_day = 20000
	progress.random_paid = 2
	var text: String = progress._write().encode_to_text()
	_check("[meta]" in text and "version=7" in text and "[wallet]" in text and "[medals]" in text and "globs=37" in text, "the save has [meta] version 7, [wallet] globs and [medals]")
	_check("clears_paid" not in text and "hard_clears_paid" not in text, "...and no clears_paid keys any more")
	var file := ConfigFile.new()
	file.parse(text)
	var copy: Node = preload("res://scripts/progress.gd").new()
	copy._read(file)
	_check(copy.tickets == 37 and copy.tickets_lifetime == 120 and copy.medals == {1: 3, 3: 2, 101: 1}
		and copy.spins == 4 and copy.rainbow_pity == 3 and copy.random_pay_day == 20000 and copy.random_paid == 2, "everything survives a save and a load")
	var same := true
	var again_file: ConfigFile = copy._write()
	for section in ["meta", "wallet", "medals", "hats"]:
		for key in file.get_section_keys(section):
			same = same and again_file.get_value(section, key) == file.get_value(section, key)
	_check(same, "...key for key")
	copy.free()

	# --- Hostile / odd values are clamped
	var odd := ConfigFile.new()
	odd.parse(text)
	odd.set_value("wallet", "globs", 9_999_999)
	odd.set_value("wallet", "random_paid", "many")
	odd.set_value("medals", "level_2", 99)
	odd.set_value("medals", "level_4", -3)
	odd.set_value("medals", "level_5", "gold")
	odd.set_value("hats", "rainbow_pity", -5)
	var tough: Node = preload("res://scripts/progress.gd").new()
	tough._read(odd)
	_check(tough.tickets == progress.TICKETS_MAX and tough.random_paid == 0 and tough.medals_for(2) == 0 and tough.medals_for(4) == 0 and tough.medals_for(5) == 0 and tough.rainbow_pity == 0,
		"out-of-range or wrong-typed wallet and medal values are clamped")
	tough.free()

	# --- Seed farming: a repeated seed pays nothing, a typed or replayed one 1 at most
	progress.reset_progress()
	progress.day_override = 30000
	progress.new_random_maze()
	progress.upgrades = {"slime": 1}
	_check(progress.random_seed_fresh and progress.complete_random(false, 111, 2) == 8, "a fresh seed won on attempt 2 pays 8")
	_check(not progress.random_seed_fresh and progress.seed_paid_today(111), "...then it counts as replayed and paid today")
	_check(progress.random_payout(1, 111).cap == "paid" and progress.complete_random(false, 111, 1) == 0 and progress.random_paid == 1, "replaying a paid seed pays nothing and doesn't use the daily cap")
	progress.random_seed_fresh = false  # typed in
	_check(progress.random_payout(1, 222).cap == "replay" and progress.complete_random(false, 222, 1) == 1 and progress.random_paid == 2, "a typed seed pays 1 at most, even on its first attempt")
	progress.new_random_maze()
	_check(progress.complete_random(false, 333, 1) == 10, "NEW MAZE makes the next seed fresh again")
	for i in 14:
		progress.random_paid = 0
		progress.complete_random(false, 1000 + i)
	_check(progress.random_paid_seeds.size() == progress.PAID_SEEDS_MAX and progress.random_paid_seeds[-1] == 1013 and not 111 in progress.random_paid_seeds, "the paid-seed list keeps the newest 10")
	progress.random_paid = 1
	progress.random_pay_day = 30000
	progress.day_override = 29999  # clock moved back: nothing clears
	progress.complete_random(false, 1013)
	_check(progress.random_paid_seeds.size() == 10 and progress.seed_paid_today(1013), "a day going backwards keeps the list")
	progress.day_override = 30001
	_check(not progress.seed_paid_today(1013) and progress.complete_random(false, 1013) == 1 and progress.random_paid_seeds == [1013], "a new day clears the list and the (replayed) seed pays again, 1")
	var game_seed: Node2D = await _spawn_random(5150)
	progress.random_paid_seeds.assign([5150])
	progress.random_pay_day = 30001
	game_seed.run_time = 1.0
	game_seed._on_goal_body_entered(game_seed.slime)
	_check("SEED ALREADY PAID TODAY - TRY NEW MAZE" in game_seed.hud.rewards_texts, "the result screen explains a repeated seed pays no tickets")
	await _stop(game_seed)

	# --- Medals in a save: tiers outside 1-3 are 0; best times without [medals] become tiers
	var vth := ConfigFile.new()
	vth.set_value("meta", "version", 5)
	vth.set_value("progress", "levels_cleared", 3)
	vth.set_value("records", "level_1", Levels.level_par(1) * 0.5)
	vth.set_value("medals", "level_1", 7)
	vth.set_value("medals", "level_2", 2)
	vth.set_value("medals", "level_3", 0)
	var vthp: Node = preload("res://scripts/progress.gd").new()
	vthp._read(vth)
	_check(vthp.medals_for(1) == 0 and vthp.medals_for(2) == 2 and vthp.medals_for(3) == 0, "a save's out-of-range tiers (7) are 0, valid ones kept")
	var vthb := ConfigFile.new()
	vthb.set_value("meta", "version", 5)
	vthb.set_value("progress", "levels_cleared", 3)
	vthb.set_value("records", "level_1", Levels.level_par(1) * 0.5)
	vthp._read(vthb)
	_check(vthp.medals_for(1) == 3, "a save with best times and no [medals] gets tiers from the times")
	vthp.free()
	_check_budget("computing par for all 20 levels", 100.0, func() -> float:
		var par_start := Time.get_ticks_usec()
		for lv in range(1, Levels.COUNT + 1):
			Levels._par_cache.erase(lv)
			Levels._par_cache.erase(lv + 100)
			Levels._maze_cache.erase(lv)  # cold every try: a retry must not measure a warm cache (0.1 ms)
			Levels._maze_cache.erase(lv + 100)
			Levels.level_par(lv)
			Levels.level_par(lv, true)
		return (Time.get_ticks_usec() - par_start) / 1000.0)

	# --- A save with the old wallet keys (globs, clears_paid): balance kept, paid masks dropped
	var par2: float = Levels.level_par(2)
	var old := _old_save()
	var veteran: Node = preload("res://scripts/progress.gd").new()
	veteran._read(old)
	_check(veteran.levels_cleared == 6 and veteran.coins_earned() == 2 and veteran.best_times[1] == snappedf(Levels.level_par(1) * 0.8, 0.125) and veteran.hats_owned == ["tophat"], "the save loads")
	_check(veteran.tickets == 37 and veteran.tickets_lifetime == 90, "the balance is kept as it is (%d, lifetime %d), no retro grant" % [veteran.tickets, veteran.tickets_lifetime])
	_check(veteran.medals_for(1) == 3 and veteran.medals_for(2) == 2 and veteran.medals_for(3) == 1 and veteran.medals_for(7) == 0, "stored tiers are read (%s)" % [veteran.medals])
	var written: ConfigFile = veteran._write()
	_check(written.get_value("meta", "version") == 7 and not written.has_section_key("wallet", "clears_paid") and not written.has_section_key("wallet", "hard_clears_paid"), "its next save is version 7 without the paid masks")
	var again := ConfigFile.new()
	again.parse(written.encode_to_text())
	var veteran2: Node = preload("res://scripts/progress.gd").new()
	veteran2._read(again)
	_check(veteran2.medals == veteran.medals and veteran2.tickets == 37, "loading the new save changes nothing")
	# losing the balance then re-reading does not re-pay anything
	veteran.tickets = 0
	var spent := ConfigFile.new()
	spent.parse(veteran._write().encode_to_text())
	veteran2._read(spent)
	_check(veteran2.tickets == 0, "a spent balance doesn't come back")
	veteran.free()
	veteran2.free()

	# --- A save from before tickets: no tickets, no retro grant
	var v1 := ConfigFile.new()
	v1.set_value("meta", "version", 5)
	v1.set_value("progress", "levels_cleared", 6)
	v1.set_value("progress", "highest_unlocked", 7)
	v1.set_value("progress", "hard_cleared", [1, 2])
	v1.set_value("records", "level_2", par2 * 0.5)
	var ancient: Node = preload("res://scripts/progress.gd").new()
	ancient._read(v1)
	_check(ancient.tickets == 0 and ancient.tickets_lifetime == 0 and ancient.levels_cleared == 6, "a save from before tickets gets no grant")
	_check(ancient.medals_for(2) == 3 and ancient.medals_for(1) == 1 and ancient.medals_for(7) == 0, "...and with no [medals] its clears and times become tiers (%s)" % [ancient.medals])
	ancient.free()

	# --- A hostile old save: junk, huge, NaN-ish and wrong-typed entries
	var junk := ConfigFile.new()
	junk.set_value("progress", "levels_cleared", 999999)
	junk.set_value("progress", "hard_cleared", [3, 3, 3, -5, 0, 64, 1000000, 63, Levels.COUNT, Levels.COUNT + 1, 2])
	junk.set_value("records", "level_1", -4.0)
	junk.set_value("records", "level_2", INF)
	junk.set_value("records", "level_3", NAN)
	junk.set_value("records", "level_4", 0.0)
	junk.set_value("records", "level_5", "fast")
	junk.set_value("medals", "level_6", 123456789)
	junk.set_value("medals", "level_7", "x")
	junk.set_value("wallet", "clears_paid", -1)
	junk.set_value("wallet", "globs", "lots")
	var hostile: Node = preload("res://scripts/progress.gd").new()
	hostile._read(junk)
	var ok := true
	for key: int in hostile.medals:
		ok = ok and hostile.medals[key] >= 1 and hostile.medals[key] <= 3 and (key % 100) >= 1 and (key % 100) <= Levels.COUNT
	_check(ok and hostile.tickets == 0 and hostile.levels_cleared == Levels.COUNT, "junk entries give only valid tiers (1-3) for real levels (%s)" % [hostile.medals])
	_check(hostile.medals.is_empty() and hostile.best_times.is_empty(), "...wild stored tiers and bad best times are dropped")
	hostile.free()

	# --- Save codes: from an old build and from this one
	progress.reset_progress()
	progress.load_progress()
	var old_code := _code(old)
	_check(not progress.load_code(old_code) and progress.tickets == 0 and progress.medals.is_empty(),
		"a code from a pre-release build (no release epoch) is refused and changes nothing")
	progress._read(old)
	_check(progress.tickets == 37 and progress.medals_for(1) == 3 and progress.medals_for(2) == 2 and progress.medals_for(3) == 1,
		"the same save read directly: balance kept, medals as tiers")
	progress.check_achievements()  # (goals the state meets are adopted at every save; settle them before the snapshot)
	var snapshot: String = progress._write().encode_to_text()
	_check("version=7" in snapshot, "...and re-saves as version 7")
	var new_code: String = progress.save_code()
	progress.reset_progress()
	_check(progress.tickets == 0 and progress.medals.is_empty() and progress.spins == 0 and progress.rainbow_pity == 0 and progress.random_paid == 0,
		"RESET PROGRESS empties the tickets, medals and wheel counters")
	_check(progress.load_code(new_code) and progress._write().encode_to_text() == snapshot, "a code from this build restores everything exactly, and loading it twice changes nothing")
	_check(progress.load_code(new_code) and progress._write().encode_to_text() == snapshot, "(twice)")
	# a code with every level at gold in both modes stays small
	progress.reset_progress()
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.hard_cleared.assign(range(1, 11))
	for level in range(1, 11):
		progress.medals[level] = 3
		progress.medals[level + 100] = 3
	progress.tickets = 99999
	var big: String = progress.save_code()
	_check(big.length() < progress.MAX_SAVE_CODE_LENGTH / 8, "even with every medal the save code stays small (%d of %d characters)" % [big.length(), progress.MAX_SAVE_CODE_LENGTH])
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
	quit(1 if failures else 0)


## A version 5 save with the old [wallet] keys (globs, clears_paid masks) and medal tiers (records on
## 1/8 s steps, so they survive a save code's text exactly).
func _old_save() -> ConfigFile:
	var old := ConfigFile.new()
	old.set_value("meta", "version", 5)
	old.set_value("progress", "levels_cleared", 6)
	old.set_value("progress", "highest_unlocked", 7)
	old.set_value("progress", "hard_cleared", [1, 2])
	old.set_value("coins", "level_1", ["2,3", "5,1"])
	old.set_value("hats", "owned", ["tophat"])
	old.set_value("records", "level_1", snappedf(Levels.level_par(1) * 0.8, 0.125))
	old.set_value("records", "level_2", snappedf(Levels.level_par(2) * 1.2, 0.125))
	old.set_value("records", "level_3", snappedf(Levels.level_par(3) * 2.0, 0.125))
	old.set_value("records", "level_101", snappedf(Levels.level_par(1, true) * 0.9, 0.125))
	old.set_value("wallet", "globs", 37)
	old.set_value("wallet", "globs_lifetime", 90)
	old.set_value("wallet", "clears_paid", 0b111111)
	old.set_value("wallet", "hard_clears_paid", 0b11)
	old.set_value("medals", "level_1", 3)
	old.set_value("medals", "level_2", 2)
	old.set_value("medals", "level_3", 1)
	old.set_value("medals", "level_101", 3)
	return old


## The code of a save, the way Progress.save_code makes it (minus the epoch Progress._write adds).
func _code(file: ConfigFile) -> String:
	var packed := file.encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return progress.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(packed)


func _spawn_random(seed_value: int) -> Node2D:
	progress.mode = progress.MODE_RANDOM
	var game: Node2D = MAIN.instantiate()
	game.random_seed = seed_value
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


## The game the last scene reload made (retry / replay / NEW MAZE), once it has started.
func _current_game() -> Node2D:
	for i in 3:
		await process_frame
	await physics_frame
	return current_scene


## Detaches the game before its end-of-level timer fires (so it doesn't reload), then frees it.
func _stop(game: Node2D) -> void:
	current_scene = null
	for i in int(game.CHOICE_DELAY * 60) + 10:
		await physics_frame
	game.free()


