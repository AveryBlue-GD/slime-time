extends "res://tests/suite_base.gd"

## The demo's FULL GAME PREVIEW (Demo.PREVIEW, Progress.begin_demo_preview / end_demo_preview, game.gd `preview`):
## the RANDOM_WINS-th randomizer win leads into one fixed maze with every ability and a borrowed look, its card
## first, no attempts / pickups / pay, CONTINUE only into the end screen; nothing it borrows reaches the save
## (none written meanwhile, the state from before put back after), and it plays once per save.

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
	progress.end_demo_preview()
	_check(not progress.in_demo_preview() and not Demo.preview and not Demo.ability_open("kaze"), "end: the preview is over")
	_check(progress._write().encode_to_text() == saved_at_start, "...the state is exactly the one from before it")
	_check(progress.active_skin() == "lemon" and progress.selected_hat == Hats.NONE and progress.abilities == {rifle = 1}
		and progress.random_seed == player_seed and progress.skin_override == "",
		"...the player's skin, hat, abilities and maze")
	progress.save_progress()
	_check(_disk() == saved_at_start, "...and the next save writes that")
	_check(not progress.demo_preview_due(), "it plays once per save")
	progress.end_demo_preview()  # (twice is harmless)
	_check(progress._write().encode_to_text() == saved_at_start, "a second end_demo_preview changes nothing")
	_check(Demo.denied.is_empty(), "the preview loads nothing a stripped demo export leaves out (%s)" % [Demo.denied])
	current_scene = null
