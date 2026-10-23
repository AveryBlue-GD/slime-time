extends "res://tests/suite_base.gd"

## BUG2-07: the randomizer economy under the SHIPPING settings. suite_base switches pickups-on-win, pay-by-length,
## abandon-counts and the idle drain off for the older suites; this suite puts them back to the shipping values (no
## force at all) and covers what the others don't: held pickups paid on a win and lost on a dry-up, the length pay
## range, the abandon penalty through NEW MAZE and through DAILY -> hub -> RANDOM MAZE, a replay-then-leave not
## inflating the next maze, the daily paying once (also when UTC midnight passes during the run), and a leap
## that wins the maze stopping in the air (no splat, no drain after the result).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_shipping_config.gd

var test_save := throwaway_save()
const MAIN := preload("res://scenes/main.tscn")

var progress: Node


func _initialize() -> void:
	Economy.idle_drain_force = -1
	Economy.pickups_on_win_force = -1
	Economy.pay_by_length_force = -1
	Economy.abandon_counts_force = -1
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.saving_enabled = false
	progress.day_override = 30000
	progress.upgrades = {"slime": 1}
	_check(Economy.pickups_on_win() and Economy.pay_by_length() and Economy.abandon_counts() and Economy.idle_drain_on(),
		"the shipping settings are on: pickups on win, pay by length, abandon counts, idle drain")

	_length_pay()
	_abandon_progress_level()
	await _held_pickups()
	await _daily_pays_once()
	await _leap_win_stops()
	_difficulty_numbers()
	await _dry_up_row()
	_result()
	quit(0 if failures == 0 else 1)


## --- Length pay range
func _length_pay() -> void:
	var lo := 9.0
	var hi := 0.0
	var in_range := true
	for hard in [false, true]:
		for i in 300:
			var f: float = progress.random_length_factor(2000 + i * 7919, -1, hard)
			in_range = in_range and f >= Economy.LENGTH_PAY_MIN - 0.0001 and f <= Economy.LENGTH_PAY_MAX + 0.0001
			lo = minf(lo, f)
			hi = maxf(hi, f)
	_check(in_range and lo < hi, "the length factor stays within %.1f-%.1f for normal and hard mazes (%.2f .. %.2f)" % [Economy.LENGTH_PAY_MIN, Economy.LENGTH_PAY_MAX, lo, hi])
	var cheapest: int = progress.random_payout(1, 1, Economy.LENGTH_PAY_MIN).tickets
	var dearest: int = progress.random_payout(1, 1, Economy.LENGTH_PAY_MAX).tickets
	_check(cheapest >= 1 and cheapest < 10 and dearest > 10, "a first-try win pays %d to %d tickets over the length range" % [cheapest, dearest])


## --- IMP2-04 numbers: hard pay factor, length clamp, the reserve after 2 dry-ups on L8-L10, the soft hard allowances
func _difficulty_numbers() -> void:
	progress.upgrades = {"slime": 1}
	progress.random_seed_fresh = true
	progress.random_paid_seeds.clear()
	_check(is_equal_approx(progress.random_length_factor(5, -1, true), 1.4) and progress.random_payout(1, 5, 1.4).tickets == 14,
		"a hard random maze pays the flat 1.4 factor: 14 tickets on the first try")
	_check(is_equal_approx(Economy.LENGTH_PAY_MIN, 0.4) and is_equal_approx(Economy.LENGTH_PAY_MAX, 1.5), "the length clamp is 0.4-1.5")
	progress.hard_mode = false
	Economy.one_assist_force = 0  # (the old reserve; the one-assist offer is covered by test_chill_lane)
	progress.dry_ups = {7: 2, 8: 2, 10: 2, 3: 2}
	_check(not progress.assist_offered(7) and not progress.assist_offered(3) and progress.assist_offered(8) and progress.assist_offered(10),
		"the slime reserve is offered after 2 dry-ups on L8-L10 only")
	progress.dry_ups = {7: 3, 1: 3}
	_check(progress.assist_offered(7) and progress.assist_offered(1), "...and after 3 on the earlier levels")
	Economy.one_assist_force = -1
	progress.dry_ups = {}
	var allowances := []
	for n in range(1, 11):
		allowances.append(Levels.hard_data(n).allowance)
	_check(allowances.slice(0, 5) == [1.18, 1.18, 1.19, 1.20, 1.20], "hard L1-L5 allowances are 1.18 / 1.18 / 1.19 / 1.20 / 1.20 %s" % [allowances.slice(0, 5)])


## --- The 2nd dry-up with the coins for MORE SLIME in hand highlights UPGRADES and says what it buys
func _dry_up_row() -> void:
	progress.upgrades = {}
	progress.coins_found = {}
	progress.hard_mode = false
	progress.dry_ups = {}
	_check(progress.slime_upgrade_offer().is_empty(), "no coins, no upgrade offer")
	var cost: int = Upgrades.cost("slime", 0)
	var cells: Array = []
	for level in range(1, 4):
		for i in Levels.COINS[level - 1]:
			cells.append([level, Vector2i(i, 0)])
	for pair in cells:
		if progress.coins() >= cost:
			break
		progress.collect_coin(pair[0], pair[1])
	var offer: Dictionary = progress.slime_upgrade_offer()
	var expect_pct := roundi((Upgrades.slime_factor(1) / Upgrades.slime_factor(0) - 1.0) * 100.0)
	_check(progress.coins() >= cost and offer.get("cost", 0) == cost and offer.get("percent", 0) == expect_pct and expect_pct > 0,
		"%d coins in hand: the offer is +%d%% SLIME FOR %d COINS" % [progress.coins(), expect_pct, cost])
	var game := await _dry_story(1)
	_check(game.hud.choice_buttons[0].has_focus() and "SLIME FOR" not in " ".join(game.hud.rewards_texts), "the 1st dry-up: RESTART keeps the focus, no hint")
	await _stop(game)
	game = await _dry_story(1)
	_check(game.hud.choice_buttons[1].has_focus() and ("+%d%% SLIME FOR %d COINS" % [expect_pct, cost]) in " ".join(game.hud.rewards_texts),
		"the 2nd dry-up: UPGRADES is highlighted with +%d%% SLIME FOR %d COINS (%s)" % [expect_pct, cost, game.hud.rewards_texts])
	await _stop(game)


func _dry_story(level: int) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await _physics_frames(3)
	game.slime_remaining = 0.0
	for i in 200:
		await physics_frame
		if not game.hud.choice_buttons.is_empty() and game.hud.choice_buttons[0].is_visible_in_tree():
			break
	await _physics_frames(3)
	return game


## --- Abandon carry (Progress level): NEW MAZE, DAILY -> hub -> RANDOM, replay then leave
func _abandon_progress_level() -> void:
	progress.new_random_maze()
	progress.begin_random_attempt("a1")
	progress.random_moved = true
	progress.new_random_maze()
	_check(progress.begin_random_attempt("a2") == 2, "abandoning a moved maze through NEW MAZE: the next one is attempt 2")

	# a maze left for the daily keeps its penalty for the next random maze; the daily's own retries add nothing
	progress.new_random_maze()
	progress.begin_random_attempt("b1")
	progress.random_moved = true
	progress.start_daily()  # DAILY from the portal (the maze left, moved)
	progress.begin_random_attempt("daily")
	progress.begin_random_attempt("daily")  # a retry of the daily
	progress.random_moved = true
	progress.start_random()  # back through the hub: RANDOM MAZE
	_check(progress.begin_random_attempt("b2") == 2, "DAILY -> hub -> RANDOM MAZE: the left maze's penalty carries (attempt 2), the daily's retries don't leak")

	# replay a won maze, then leave: the next fresh maze is attempt 1
	progress.new_random_maze()
	progress.begin_random_attempt("c1")
	progress.complete_random(false, 777, 1, 1.0)
	progress.begin_random_attempt("c1")  # REPLAY MAZE
	progress.begin_random_attempt("c1")
	progress.begin_random_attempt("c1")
	progress.random_moved = true  # moved around in the replay
	progress.new_random_maze()
	_check(progress.begin_random_attempt("c2") == 1, "replaying a won maze and then leaving does not charge the next maze")


## --- Held pickups: paid with the win, lost on a dry-up
func _held_pickups() -> void:
	progress.tickets = 0
	progress.random_paid_seeds.clear()
	progress.new_random_maze()
	var game := await _spawn_random(progress.random_seed)
	_check(game.attempt == 1 and game.tickets.size() > 0, "a fresh maze: attempt 1, %d pickups out" % game.tickets.size())
	var out: int = game.tickets.size()
	var pick: TicketPickup = game.tickets[0]
	game.slime.position = pick.position
	await _physics_frames(4)
	_check(progress.tickets == 0 and game.held_tickets == Economy.RANDOM_TICKET_PAY, "a pickup is held, not paid (+%d held)" % game.held_tickets)
	game.slime_remaining = 0.0  # dry up
	await _physics_frames(30)
	game.retry()
	game = await _current_game()
	_check(game.attempt == 2 and game.held_tickets == 0 and progress.tickets == 0 and game.tickets.size() == out,
		"a dry-up loses the held pickup (nothing paid, it is back in the maze)")
	pick = game.tickets[0]
	game.slime.position = pick.position
	await _physics_frames(4)
	var expected: int = game.payout().tickets + game.held_tickets
	game.slime.position = game.goal.position
	await _physics_frames(10)
	_check(game.won and progress.tickets == expected and expected > Economy.RANDOM_TICKET_PAY,
		"the win pays the chalice and the held pickup together (%d)" % progress.tickets)
	await _stop(game)


## --- The daily pays once, also across UTC midnight
func _daily_pays_once() -> void:
	progress.random_pay_day = 0
	progress.day_override = 30000
	progress.tickets = 0
	progress.start_daily()
	var game := await _spawn_random(progress.random_seed)
	progress.day_override = 30001  # midnight passes during the run
	game.slime.position = game.goal.position
	await _physics_frames(10)
	_check(game.won and progress.tickets == Economy.DAILY_WIN_TICKETS and progress.daily_day == 30000,
		"the first daily win pays even when midnight passed during the run (%d tickets, recorded for day %d)" % [progress.tickets, progress.daily_day])
	await _stop(game)

	# day 30001: win it, then play it again and cross midnight into 30002
	progress.start_daily()
	game = await _spawn_random(progress.random_seed)
	game.slime.position = game.goal.position
	await _physics_frames(10)
	var paid_after_first: int = progress.tickets
	_check(game.won and paid_after_first == 2 * Economy.DAILY_WIN_TICKETS and progress.daily_won_today(), "day 30001's daily pays once (%d)" % paid_after_first)
	await _stop(game)
	var wins: int = progress.randoms_won
	progress.start_daily()  # the same day again
	game = await _spawn_random(progress.random_seed)
	var pick: TicketPickup = game.tickets[0]
	game.slime.position = pick.position
	await _physics_frames(4)
	_check(game.held_tickets == 0, "a pickup in an already-won daily is worth nothing")
	progress.day_override = 30002  # midnight again
	game.slime.position = game.goal.position
	await _physics_frames(10)
	_check(game.won and progress.tickets == paid_after_first and int(game.reward.get("tickets", 0)) == 0,
		"winning the same day's daily again pays nothing, midnight or not (%d)" % progress.tickets)
	_check(progress.randoms_won == wins,
		"...and a repeat daily win does not count toward randoms_won (%d)" % progress.randoms_won)
	await _stop(game)


## --- A leap that reaches the chalice wins the maze and stops in the air
func _leap_win_stops() -> void:
	progress.day_override = 30010
	progress.new_random_maze()
	var game := await _spawn_random(progress.random_seed)
	var goal_pos: Vector2 = game.goal.position
	var dir := Vector2.ZERO
	var start := Vector2.ZERO
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from: Vector2 = goal_pos - d * 16.0
		var xform: Transform2D = game.slime.global_transform.translated(from - game.slime.position)
		if not game.slime.test_move(xform, d * 16.0):
			dir = d
			start = from
			break
	_check(dir != Vector2.ZERO, "a clear run-up to the chalice exists for the leap")
	if dir == Vector2.ZERO:
		await _stop(game)
		return
	game.slime.position = start
	game.slime.state = Slime.State.AIRBORNE
	game.slime._jump_dir = dir
	game.slime._jump_distance = 64.0
	game.slime._jump_traveled = 0.0
	await _physics_frames(60)
	_check(game.won, "a leap into the chalice wins the maze")
	var pos: Vector2 = game.slime.position
	var meter: float = game.slime_remaining
	await _physics_frames(30)
	_check(game.slime.position == pos and game.slime.state == Slime.State.AIRBORNE and is_equal_approx(game.slime_remaining, meter),
		"...and the leap stops there: no more flight, splat or drain after the result")
	await _stop(game)


func _spawn_random(seed_value: int) -> Node2D:
	progress.mode = progress.MODE_RANDOM
	var game: Node2D = MAIN.instantiate()
	game.random_seed = seed_value
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _current_game() -> Node2D:
	for i in 3:
		await process_frame
	await physics_frame
	return current_scene


func _stop(game: Node2D) -> void:
	current_scene = null
	for i in int(game.CHOICE_DELAY * 60) + 10:
		await physics_frame
	game.free()
