extends "res://tests/suite_base.gd"

## IMP-01 Chill lane: standing still drains nothing for the first Economy.IDLE_GRACE seconds (moving
## resets it), nothing while aiming an ability, R restarts at once even with coins in hand, and a RELAXED
## run has no idle drain and earns no medal / record / ticket (Game.no_credit).
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 -s res://tests/test_chill_lane.gd

const MAIN := preload("res://scenes/main.tscn")


func _initialize() -> void:
	Economy.idle_drain_force = 1
	var game := await _spawn(false)
	var s: Node2D = game.slime
	game._spawn_at = Vector2.INF  # (as after the first move)
	game._still_time = 0.0
	var before: float = game.slime_remaining
	await _wait_seconds(3.0)
	_check(game.slime_remaining == before, "no drain in the first 3 s of standing still")
	await _wait_seconds(2.5)
	var used: float = before - game.slime_remaining
	_check(used > 0.2 and used < 0.8, "drain starts after the %.0f s grace (%.2f%% used by 5.5 s)" % [Economy.IDLE_GRACE, used])
	game._idle_drain(1.0, 0.016)  # a moving frame resets the grace
	_check(game._still_time == 0.0, "moving resets the grace timer")
	before = game.slime_remaining
	await _wait_seconds(2.0)
	_check(game.slime_remaining == before, "grace is back after moving")

	game._still_time = 10.0
	s.aim_lock = true
	before = game.slime_remaining
	await _wait_seconds(1.0)
	_check(game.slime_remaining == before, "no idle drain while aiming an ability")
	s.aim_lock = false
	game.free()

	# R with coins in hand restarts at once
	game = await _spawn(false)
	game.progress.coins_found = {1: ["0,0"]}
	_check(game.progress.coins() > 0, "coins in hand")
	var attempt_before: int = game.attempt
	Input.action_press("restart")
	await physics_frame
	Input.action_release("restart")
	for i in 20:
		await physics_frame
	_check(not game.restart_prompt.visible, "R opens no prompt")
	_check(not is_instance_valid(game) or game.is_queued_for_deletion() or current_scene != game or game.attempt != attempt_before or game.run_time < 0.5,
		"R restarted the run")
	if is_instance_valid(game):
		game.free()

	# RELAXED
	game = await _spawn(true)
	_check(game.relaxed_run and game.no_credit(), "a RELAXED run earns no credit")
	game._spawn_at = Vector2.INF
	game._still_time = 20.0
	before = game.slime_remaining
	await _wait_seconds(1.0)
	_check(game.slime_remaining == before, "RELAXED: no idle drain even past the grace")
	var rec: Dictionary = game.progress.record_clear(1, 1.0, 100.0, game.no_credit(), true)
	_check(int(rec.tier) == 0 and game.progress.medals_for(1) == 0, "RELAXED: no medal recorded")
	game.free()

	# ONE ASSIST: RELAXED gives 25% more slime, +2% per dry-up on the level, at most +50%
	var pr: Node = root.get_node("Progress")
	pr.dry_ups = {}
	game = await _spawn(false)
	var plain: float = game.slime_cost_per_tile
	game.free()
	game = await _spawn(true)
	_check(is_equal_approx(game.slime_cost_per_tile, plain / 1.25), "RELAXED: 25% more slime")
	game.free()
	pr.dry_ups = {1: 5}
	game = await _spawn(true)
	_check(is_equal_approx(game.slime_cost_per_tile, plain / 1.35), "...+2% per dry-up on that level (5 dry-ups: +35%)")
	game.free()
	pr.dry_ups = {1: 40}
	_check(is_equal_approx(pr.relaxed_bonus(1), 0.5), "...capped at +50%")
	Economy.one_assist_force = 0
	_check(is_equal_approx(pr.relaxed_bonus(1), 0.0), "ONE_ASSIST off: a plain RELAXED")
	Economy.one_assist_force = -1
	# the offer
	pr.relaxed = false
	pr.hard_mode = false
	pr.calm_declined = {}
	pr.dry_ups = {1: 2, 8: 2}
	_check(not pr.calm_offered(1) and pr.calm_offered(8), "calm offer: after 3 dry-ups, 2 on L8-L10")
	pr.dry_ups = {1: 3}
	_check(pr.calm_offered(1) and not pr.assist_offered(1), "...replaces the old reserve offer")
	pr.calm_declined[1] = true
	_check(not pr.calm_offered(1), "NO hides it for the level this session")
	pr.calm_declined = {}
	pr.relaxed = true
	_check(not pr.calm_offered(1), "...and it isn't offered once RELAXED is on")
	pr.relaxed = false
	game = await _spawn(false)
	game._offer_retry()
	_check("CALM MODE? MORE SLIME, NO MEDALS" in " ".join(game.hud.rewards_texts), "the dry-up screen asks CALM MODE? (%s)" % " ".join(game.hud.rewards_texts))
	game.free()
	pr.relaxed = false
	pr.dry_ups = {}
	root.get_node("Progress").relaxed = false
	Economy.idle_drain_force = 0
	_result()


func _spawn(relaxed: bool) -> Node2D:
	root.get_node("Progress").relaxed = relaxed
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	await physics_frame
	return game
