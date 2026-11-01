extends "res://tests/suite_base.gd"

## IMP-02 economy integrity (Economy.PICKUPS_ON_WIN / PAY_BY_LENGTH / ABANDON_COUNTS, which suite_base
## switches OFF for the older suites): random-maze ticket pickups are held and paid only with the win,
## the win's table pay scales with the maze's length (clamped, min 1, caps still apply), and abandoning a
## maze after a move spends an attempt (the next maze starts one higher, capped; a win resets it).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_economy_integrity.gd

var test_save := throwaway_save()
const MAIN := preload("res://scenes/main.tscn")

var progress: Node


func _initialize() -> void:
	Economy.pickups_on_win_force = 1
	Economy.pay_by_length_force = 1
	Economy.abandon_counts_force = 1
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.saving_enabled = false
	progress.day_override = 30000
	progress.upgrades = {"slime": 1}

	# --- Pay by length: the factor is the seed's route over a typical maze's, clamped
	var lo := 0
	var hi := 0
	var lo_f := 9.0
	var hi_f := 0.0
	var in_range := true
	for i in 400:
		var s := 1000 + i * 7919
		var f: float = progress.random_length_factor(s, 1)
		in_range = in_range and f >= Economy.LENGTH_PAY_MIN - 0.0001 and f <= Economy.LENGTH_PAY_MAX + 0.0001
		if f < lo_f:
			lo_f = f
			lo = s
		if f > hi_f:
			hi_f = f
			hi = s
	_check(in_range and lo_f < 0.9 and hi_f > 1.1, "the length factor varies between seeds within %.1f-%.1f (%.2f .. %.2f)" % [Economy.LENGTH_PAY_MIN, Economy.LENGTH_PAY_MAX, lo_f, hi_f])
	_check(progress.random_length_factor(lo, 1) == progress.random_length_factor(lo, 1), "...and is deterministic")
	var short_pay: int = progress.random_payout(1, lo, lo_f).tickets
	var long_pay: int = progress.random_payout(1, hi, hi_f).tickets
	_check(short_pay < 10 and long_pay > 10 and short_pay == maxi(1, roundi(10 * lo_f)) and long_pay == roundi(10 * hi_f),
		"a short maze pays less than the table's 10 (%d), a long one more (%d)" % [short_pay, long_pay])
	_check(progress.random_payout(6, lo, 0.6).tickets == 1 and progress.random_payout(5, lo, 0.6).tickets == 1,
		"...never below 1")
	progress.random_seed_fresh = false
	_check(progress.random_payout(1, lo, 1.4).tickets == Economy.TICKETS_REPLAY_CAP and progress.random_payout(1, lo, 1.4).cap == "replay",
		"...and the replay cap still applies after it")
	progress.random_seed_fresh = true
	progress.upgrades = {}
	_check(progress.random_payout(1, lo, 1.4).tickets == Economy.TICKETS_NO_SLIME_CAP and progress.random_payout(1, lo, 1.4).cap == "slime",
		"...and so does the no-MORE-SLIME cap")
	progress.upgrades = {"slime": 1}
	Economy.pay_by_length_force = 0
	_check(progress.random_length_factor(hi, 1) == 1.0, "PAY_BY_LENGTH off: the factor is 1")
	Economy.pay_by_length_force = 1

	# --- Abandoning counts as an attempt (Progress level)
	progress.new_random_maze()
	var key := "k1"
	_check(progress.begin_random_attempt(key) == 1, "the very first maze starts at attempt 1")
	progress.begin_random_attempt(key)  # attempt 2 (a retry)
	progress.new_random_maze()  # abandoned without a move
	_check(progress.begin_random_attempt("k2") == 1, "NEW MAZE without a move gives a fresh attempt 1")
	progress.random_moved = true
	progress.new_random_maze()
	_check(progress.begin_random_attempt("k3") == 2, "NEW MAZE after a move: the next maze starts at attempt 2")
	progress.random_moved = true
	progress.new_random_maze()
	_check(progress.begin_random_attempt("k4") == 3, "...abandoning again counts on: attempt 3")
	for i in 8:
		progress.random_moved = true
		progress.new_random_maze()
		progress.begin_random_attempt("k%d" % (10 + i))
	_check(progress.begin_random_attempt("kx") <= progress.RANDOM_ATTEMPT_PAY.size() + 1
		and progress.random_attempts["k17"] == progress.RANDOM_ATTEMPT_PAY.size(),
		"...capped at the last pay tier (attempt %d)" % progress.random_attempts["k17"])
	progress.random_moved = true
	progress.complete_random(false, 5, 1)
	progress.new_random_maze()
	_check(progress.begin_random_attempt("kw") == 1, "a win resets it: the maze after a win starts at attempt 1")
	Economy.abandon_counts_force = 0
	progress.random_moved = true
	progress.new_random_maze()
	_check(progress.begin_random_attempt("koff") == 1, "ABANDON_COUNTS off: always attempt 1")
	Economy.abandon_counts_force = 1

	# --- In the game: pickups are held, lost on a retry, paid with the win; leaving after a move counts
	progress.tickets = 0
	progress.random_paid = 0
	progress.random_paid_seeds.clear()
	progress.mode = progress.MODE_RANDOM
	progress.new_random_maze()
	var maze_seed: int = progress.random_seed
	var game := await _spawn_random(maze_seed)
	var first_attempt: int = game.attempt
	_check(first_attempt == 1 and game.tickets.size() > 0, "a fresh maze: attempt 1 with %d pickups out" % game.tickets.size())
	var pods: int = game.hud.attempt_label.text.get_slice("TIX AVAILABLE ", 1).to_int()
	var out: int = game.tickets.size()
	var pick: TicketPickup = game.tickets[0]
	var pick_cell := pick.cell
	game.slime.position = pick.position
	await _physics_frames(4)
	_check(progress.tickets == 0 and game.held_tickets == Economy.RANDOM_TICKET_PAY and game.tickets.size() == out - 1,
		"touching a pickup pays nothing yet: it is held (+%d)" % game.held_tickets)
	_check(game.hud.attempt_label.text.get_slice("TIX AVAILABLE ", 1).to_int() == pods, "...and the pod still counts it as available (%d)" % pods)
	_check(progress.random_moved, "moving in the maze marks it as tried")
	game.slime_remaining = 0.0
	await _physics_frames(30)
	game.retry()
	game = await _current_game()
	_check(game.attempt == 2 and game.held_tickets == 0 and progress.tickets == 0, "a dry-up retry loses the held ticket (nothing paid)")
	# IMP-02 fix: a pickup that was only held (never paid) is lost with the attempt, so it is back in the maze
	_check(game.tickets.size() == out and not progress.random_ticket_taken(game.attempt_key, pick_cell), "...and the unpaid pickup is back in the maze on the retry")
	pick = game.tickets[0]
	game.slime.position = pick.position
	await _physics_frames(4)
	var expected: int = game.payout().tickets + game.held_tickets
	_check(game.held_tickets == Economy.RANDOM_TICKET_PAY and progress.tickets == 0, "a second pickup is held")
	game.slime.position = game.goal.position
	await _physics_frames(10)
	_check(game.won and progress.tickets == expected and game.reward.tickets == expected and expected > Economy.RANDOM_TICKET_PAY,
		"the win pays the chalice's tickets and the held pickups together (%d)" % progress.tickets)
	game.play_next()  # NEW MAZE after a win
	game = await _current_game()
	_check(game.attempt == 1, "the maze after a win starts at attempt 1")
	game.slime.position += Vector2(8, 0)
	await _physics_frames(4)
	game.play_next()  # NEW MAZE after moving: abandoned
	game = await _current_game()
	_check(game.attempt == 2, "NEW MAZE after moving in the game: the next maze is attempt 2 (%d)" % game.attempt)
	game.retry()
	game = await _current_game()
	_check(game.attempt == 3, "...and a retry goes on from there")
	await _stop(game)

	progress.tickets = 0
	Economy.pickups_on_win_force = 0
	progress.new_random_maze()
	game = await _spawn_random(progress.random_seed)
	pick = game.tickets[0]
	game.slime.position = pick.position
	await _physics_frames(4)
	_check(progress.tickets == Economy.RANDOM_TICKET_PAY and game.held_tickets == 0, "PICKUPS_ON_WIN off: a pickup pays on touch")
	await _stop(game)
	_result()


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
