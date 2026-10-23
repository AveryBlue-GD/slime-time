extends "res://tests/suite_base.gd"

## The demo's FULL GAME PREVIEW (Demo.PREVIEW, Progress.begin_demo_preview / end_demo_preview, game.gd `preview`):
## the RANDOM_WINS-th randomizer win leads into one fixed maze with every ability and a borrowed look, its card
## first, no attempts / pickups / pay, CONTINUE only into the end screen; nothing it borrows reaches the save
## (none written meanwhile, the state from before put back after); after it the randomizer portal always plays it again
## (just the maze: the ability tutorial is its first run's). The ability tutorial (AbilityCoach): a line per ability,
## the slime held (turning only, no clock) until that ability is used; SKIP ends it.

var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	progress.hard_mode = false
	Platform.demo_override = 1
	Demo.strip_test = true
	Demo.denied.clear()
	await _check_preview()
	Platform.reset_overrides()
	Demo.strip_test = false
	_result()
	quit(0 if failures == 0 else 1)


func _disk() -> String:
	return FileAccess.get_file_as_string(test_save)


func _check_preview() -> void:
	progress.reset_progress()
	progress.story_seen = progress.STORY_INTRO | progress.STORY_DEMO_END
	progress.levels_cleared = Demo.LEVELS
	progress.randoms_won = Demo.RANDOM_WINS
	progress.tickets = 7
	progress.tickets_lifetime = 12
	progress.abilities = {rifle = 1}
	progress.selected_skin = "lemon"
	progress.start_random()
	progress.save_progress()
	_check(progress.demo_preview_due(), "after the demo's randomizer wins the preview is due")
	Platform.demo_override = 0
	_check(not progress.demo_preview_due(), "...never in the full game")
	Platform.demo_override = 1
	var player_seed: int = progress.random_seed

	progress.begin_demo_preview()
	var saved_at_start := _disk()
	_check(progress.in_demo_preview() and Demo.preview and progress.has_seen_story(progress.STORY_DEMO_PREVIEW)
		and "story_seen=%d" % progress.story_seen in saved_at_start,
		"begin: the preview runs, its seen bit is saved first (plays once)")
	_check(progress.random_seed == Demo.PREVIEW_SEED and progress.mode == progress.MODE_RANDOM and not progress.hard_mode,
		"the hand-picked seed, a normal randomizer maze")
	var all_abilities := true
	for id in Abilities.ids():
		all_abilities = all_abilities and progress.ability_level(id) == Abilities.max_level(id) and Demo.ability_open(id)
	_check(all_abilities, "every ability at its top level, open in the demo while it runs")
	_check(progress.active_skin() != "lemon" and Skins.unlock_level(progress.active_skin()) >= Demo.LEVELS and progress.selected_hat != Hats.NONE
		and Cosmetics.kind_of(progress.trail_style) == Cosmetics.TRAIL,
		"a borrowed look: %s%s, hat %s, trail %s" % [progress.active_skin(), " jelly" if progress.jelly else (" pastel" if progress.pastel else ""),
		progress.selected_hat, progress.trail_style])
	progress.tickets += 50
	progress.save_progress()
	_check(_disk() == saved_at_start, "no save is written while it runs")
	progress.tickets -= 50

	# The maze: the card first, no attempts or pickups, all abilities, CONTINUE only.
	var game: Node2D = BASE_MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	_check(game.preview and game.random_seed == Demo.PREVIEW_SEED and game.seed_level == Demo.PREVIEW_LEVEL,
		"the game plays the preview maze (seed %d, level %d)" % [game.random_seed, game.seed_level])
	_check(game.tickets.is_empty() and game.attempt_key == "" and not game.hud.attempt_pod.visible, "no ticket pickups, attempts or pod")
	var runner: Node = game.get("abilities")
	_check(runner != null and runner.levels.size() == Abilities.ids().size(), "every ability works in it (%s)" % [runner.levels if runner else {}])
	_check(game.preview_card_up and game.slime.frozen and game.hud.message.visible and game.hud.choice_buttons.size() == 1,
		"the FULL GAME PREVIEW card is up, the slime waits under it")
	var clock: float = game.run_time
	await _physics_frames(10)
	_check(game.run_time == clock, "...the clock waits too")
	game.hud.choice_buttons[0].pressed.emit()
	await physics_frame
	_check(not game.preview_card_up and not game.slime.frozen and not game.hud.message.visible, "PLAY: the card goes, the run starts")
	# The ability tutorial: a line per ability, on to the next once it is used.
	var coach: AbilityCoach = game.coach
	_check(coach != null and coach.steps == Abilities.ids(), "the ability tutorial has every ability")
	await _wait_seconds(AbilityCoach.START_DELAY + 0.2)
	_check(game.hud.training_line_text() == AbilityCoach.line("rifle") and game.hud.training_line.visible or game.hud.training_line_on,
		"its first line: %s" % game.hud.training_line_text())
	var clock_held: float = game.run_time
	game.slime.position += Vector2.ZERO
	await _physics_frames(10)
	_check(game.slime.hold and game.run_time == clock_held and coach.skip_pod.visible, "the slime is held (no clock) while the line waits, SKIP shown")
	runner.start_aim("rifle")
	await _physics_frames(2)
	_check(game.hud.training_line_text() == AbilityCoach.aim_line(), "aiming: %s" % AbilityCoach.aim_line())
	runner.cancel_aim()
	runner.use("rifle")
	await _physics_frames(2)
	await _wait_seconds(AbilityCoach.GAP + 0.2)
	_check(coach.current == "splat" and game.hud.training_line_text() == AbilityCoach.line("splat") and game.slime.hold,
		"used: on to %s (held again)" % AbilityCoach.line("splat"))
	var widest := 0.0
	for text in [AbilityCoach.aim_line(), AbilityCoach.done_line()] + Abilities.ids().map(func(id: String) -> String: return AbilityCoach.line(id)):
		widest = maxf(widest, UIKit.text_w(text))
	_check(widest <= game.hud.TRAINING_LINE_W, "every coach line fits the line's %d px (widest %d)" % [game.hud.TRAINING_LINE_W, widest])
	await _physics_frames(2)
	_check(runner.use("sense") and game.random_map_view != null, "SLIME SENSE peeks at the map")
	game._close_run_map()
	await _physics_frames(2)
	var tickets_before: int = progress.tickets
	game._on_goal_body_entered(game.slime)
	await _wait_seconds(game.CHOICE_DELAY + 0.3)
	_check(game.won and game.hud.choice_buttons.size() == 1 and progress.tickets == tickets_before and progress.randoms_won == Demo.RANDOM_WINS,
		"a win pays and counts nothing, CONTINUE only")
	_check(game.preview_exit() == DemoEnd.SCENE and DemoEnd.from == DemoEnd.FROM_RANDOM, "QUIT in the pause menu goes on to the randomizer's end screen")
	game.free()
	var again: Node2D = BASE_MAIN.instantiate()
	root.add_child(again)
	current_scene = again
	await physics_frame
	_check(again.preview and not again.preview_card_up, "a restart goes straight in (the card is once)")
	again._dry_up()
	await _wait_seconds(again.DRY_CHOICE_DELAY + 0.3)
	_check(again.hud.choice_buttons.size() == 1, "a dry-up offers CONTINUE only")
	again.free()

	# The end: everything from before is back, and saving with it.
	var seen_then: int = progress.STORY_INTRO | progress.STORY_DEMO_END | progress.STORY_DEMO_PREVIEW
	progress.end_demo_preview()
	_check(not progress.in_demo_preview() and not Demo.preview and not Demo.ability_open("kaze"), "end: the preview is over")
	_check(progress.story_seen == seen_then | progress.STORY_DEMO_PREVIEW_COACHED and _disk() == progress._write().encode_to_text(),
		"...its tutorial is marked played (saved)")
	progress.story_seen = seen_then
	_check(progress._write().encode_to_text() == saved_at_start, "...otherwise the state is exactly the one from before it")
	_check(progress.active_skin() == "lemon" and progress.selected_hat == Hats.NONE and progress.abilities == {rifle = 1}
		and progress.random_seed == player_seed and progress.skin_override == "",
		"...the player's skin, hat, abilities and maze")
	progress.save_progress()
	_check(_disk() == saved_at_start, "...and the next save writes that")
	progress.story_seen = seen_then | progress.STORY_DEMO_PREVIEW_COACHED
	progress.save_progress()
	var after_first := _disk()
	_check(not progress.demo_preview_due(), "the 3rd win's preview is once")
	progress.end_demo_preview()  # (twice is harmless)
	_check(progress._write().encode_to_text() == after_first, "a second end_demo_preview changes nothing")
	# The randomizer portal after the demo: the preview maze again, without its tutorial.
	progress.start_random()
	_check(progress.in_demo_preview() and progress.random_seed == Demo.PREVIEW_SEED, "the portal plays the preview maze again (no new seed)")
	var replay: Node2D = BASE_MAIN.instantiate()
	root.add_child(replay)
	current_scene = replay
	await physics_frame
	_check(replay.preview and replay.preview_card_up and replay.coach == null, "...its card, then just the maze (no tutorial)")
	replay.free()
	progress.end_demo_preview()
	_check(progress._write().encode_to_text() == after_first, "...and leaves the save as it was")
	progress.story_seen = progress.STORY_INTRO | progress.STORY_DEMO_END  # (a demo whose preview hasn't played: its own randomizer)
	# Outside the preview: each ability's line once (the demo's own randomizer: SLIME SNIPER), then never again.
	progress.start_random()
	var maze: Node2D = BASE_MAIN.instantiate()
	root.add_child(maze)
	current_scene = maze
	await physics_frame
	_check(maze.coach != null and maze.coach.steps == ["rifle"], "a demo random maze coaches SLIME SNIPER the first time")
	await _wait_seconds(AbilityCoach.START_DELAY + 0.2)
	_check(maze.slime.hold and maze.coach.current == "rifle", "...holding the slime")
	maze.coach.skip()
	await _physics_frames(3)
	_check(not maze.slime.hold and not maze.coach.skip_pod.visible and progress.has_seen_tutorial(AbilityCoach.bit("rifle")), "SKIP: the slime is free, the line seen")
	maze.free()
	var later: Node2D = BASE_MAIN.instantiate()
	root.add_child(later)
	current_scene = later
	await physics_frame
	_check(later.coach == null, "...and not again")
	later.free()
	_check(Demo.denied.is_empty(), "the preview loads nothing a stripped demo export leaves out (%s)" % [Demo.denied])
	current_scene = null
