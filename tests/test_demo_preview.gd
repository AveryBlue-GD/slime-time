extends "res://tests/suite_base.gd"

## The demo's FULL GAME PREVIEW (Demo.PREVIEW, Progress.begin_demo_preview / end_demo_preview, game.gd `preview`):
## the randomizer portal's first use after the demo's levels leads into one fixed maze with every ability and a borrowed look, its card
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
	await _check_restarts()
	await _check_try_button()
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
	progress.randoms_won = 0
	progress.tickets = 7
	progress.tickets_lifetime = 12
	progress.abilities = {rifle = 1}
	progress.selected_skin = "lemon"
	progress.random_seed = 4242
	progress.save_progress()
	_check(progress.demo_preview_due(), "right after the demo's levels the preview is due (no randomizer wins first, owner 2026-10-23)")
	Platform.demo_override = 0
	_check(not progress.demo_preview_due(), "...never in the full game")
	Platform.demo_override = 1
	var player_seed: int = progress.random_seed

	progress.start_random()  # (the randomizer portal's first use after the demo's END OF THE DEMO screen)
	var saved_at_start := _disk()
	_check(progress.in_demo_preview() and Demo.preview and progress.has_seen_story(progress.STORY_DEMO_PREVIEW)
		and "story_seen=%d" % progress.story_seen in saved_at_start,
		"the portal's first use: the preview runs, its seen bit is saved first (its first run plays once)")
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
	var locked_ids := func() -> Array:
		return game.touch_controls.abilities.filter(func(item: Dictionary) -> bool: return item.locked).map(func(item: Dictionary) -> String: return item.id)
	var splat_left: int = runner.charges.splat
	_check(not runner.use("splat") and runner.charges.splat == splat_left and not runner.start_aim("kaze") and runner.aiming == "",
		"only the prompted ability works: GOO GRENADE / SLIMAKAZE do nothing during SLIME SNIPER's line")
	_check(locked_ids.call() == ["splat", "kaze", "sense"], "...their buttons (and the HUD strip) show dimmed (%s)" % [locked_ids.call()])
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
	progress.force_touch = true
	var touch_lines: Array = [AbilityCoach.aim_line()] + Abilities.ids().map(func(id: String) -> String: return AbilityCoach.line(id)) \
		+ [AbilityCoach.cancel_line()]
	progress.force_touch = false
	var touch_widest := 0.0
	for text: String in touch_lines:
		touch_widest = maxf(touch_widest, UIKit.text_w(text))
	_check(touch_lines[1] == "TAP SLIME SNIPER, AIM, PRESS JUMP" and touch_lines[0] == "AIM, THEN PRESS JUMP"
		and touch_lines[3].begins_with("TAP ") and touch_lines[-1] == "LET GO TO FIRE, DRAG TO X TO CANCEL" and touch_widest <= game.hud.TRAINING_LINE_W,
		"on touch the aimed ones say how to aim (%s), all within %d px (widest %d)" % [touch_lines, game.hud.TRAINING_LINE_W, touch_widest])
	await _physics_frames(2)
	_check(locked_ids.call() == ["rifle", "kaze", "sense"] and not runner.use("sense") and game.random_map_view == null,
		"each one unlocks when its line comes up: GOO GRENADE's line, the others held back (%s)" % [locked_ids.call()])
	coach.skip()
	await _physics_frames(2)
	_check(locked_ids.call().is_empty() and runner.locked.is_empty(), "SKIP: every ability works")
	_check(runner.use("sense") and game.random_map_view != null, "SLIME SENSE peeks at the map")
	game._close_run_map()
	await _physics_frames(2)
	var tickets_before: int = progress.tickets
	game._on_goal_body_entered(game.slime)
	await _wait_seconds(game.CHOICE_DELAY + 0.3)
	_check(game.won and game.hud.choice_buttons.size() == 1 and progress.tickets == tickets_before and progress.randoms_won == 0,
		"a win pays and counts nothing, CONTINUE only")
	_check(game.preview_exit() == DemoEnd.SCENE and DemoEnd.from == DemoEnd.FROM_RANDOM, "QUIT in the pause menu goes on to the randomizer's end screen")
	game.free()
	var again: Node2D = BASE_MAIN.instantiate()
	root.add_child(again)
	current_scene = again
	await physics_frame
	_check(again.preview and not again.preview_card_up and again.random_seed == Demo.PREVIEW_SEED and progress.random_seed == Demo.PREVIEW_SEED,
		"a restart goes straight in (the card is once), the same maze (seed %d)" % again.random_seed)
	again._dry_up()
	await _wait_seconds(again.DRY_CHOICE_DELAY + 0.3)
	_check(again.hud.choice_buttons.size() == 1 and again.hud.choice_buttons[0].text == "CONTINUE",
		"a dry-up offers CONTINUE only (no NEW MAZE: %s)" % again.hud.choice_buttons[0].text)
	again.free()
	var reset: Node2D = BASE_MAIN.instantiate()
	root.add_child(reset)
	current_scene = reset
	await physics_frame
	_check(reset.preview and reset.random_seed == Demo.PREVIEW_SEED, "...and the restart after that dry-up is the same maze again")
	reset.free()

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
	_check(not progress.demo_preview_due(), "the first entry's preview (with its tutorial) is once")
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
	# Outside the preview (the full game's randomizer): each ability's line once, for the ones you have (SLIME SNIPER).
	Platform.demo_override = 0
	progress.start_random()
	_check(not progress.in_demo_preview() and progress.random_seed != Demo.PREVIEW_SEED, "the full game's portal: a new random maze")
	var maze: Node2D = BASE_MAIN.instantiate()
	root.add_child(maze)
	current_scene = maze
	await physics_frame
	_check(maze.coach != null and maze.coach.steps == ["rifle"], "a random maze coaches SLIME SNIPER the first time")
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
	Platform.demo_override = 1
	_check(Demo.denied.is_empty(), "the preview loads nothing a stripped demo export leaves out (%s)" % [Demo.denied])
	current_scene = null


## TRY THE FULL GAME (owner, 2026-10-23): the level 4 chalice's win row offers it first (focused, beside CONTINUE)
## and it goes straight into the preview maze with the ability tutorial, as the randomizer portal does.
func _check_try_button() -> void:
	progress.reset_progress()
	progress.story_seen = progress.STORY_INTRO
	progress.levels_cleared = Demo.LEVELS - 1
	progress.highest_unlocked = Demo.LEVELS
	progress.start_story(Demo.LEVELS)
	var game: Node2D = BASE_MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game._on_goal_body_entered(game.slime)
	await _wait_seconds(game.CHOICE_DELAY + 0.3)
	var texts: Array = game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)
	_check(game.won and texts == ["TRY THE FULL GAME", "CONTINUE"] and game.hud.choice_buttons[0].has_focus(),
		"level %d's chalice: TRY THE FULL GAME (focused) and CONTINUE (%s)" % [Demo.LEVELS, texts])
	_check(not progress.has_seen_story(progress.STORY_DEMO_PREVIEW), "...the preview not started yet")
	game.hud.choice_buttons[0].pressed.emit()
	var preview: Node = null
	for i in 240:
		await process_frame
		if current_scene != null and current_scene != game and current_scene.get("preview") == true:
			preview = current_scene
			break
	_check(preview != null and progress.in_demo_preview() and preview.random_seed == Demo.PREVIEW_SEED,
		"...pressed: the FULL GAME PREVIEW maze (seed %d)" % (preview.random_seed if preview else 0))
	if preview:
		preview._close_preview_card()
		await physics_frame
		_check(preview.coach != null and preview.coach.steps.size() + (1 if preview.coach.current != "" else 0) == Abilities.ids().size(),
			"...with the ability tutorial (every ability)")
		preview.free()
	current_scene = null
	progress.end_demo_preview()
	_check(not progress.in_demo_preview() and progress.levels_cleared == Demo.LEVELS, "...and afterwards the save is the player's (level %d cleared)" % Demo.LEVELS)
	progress.hard_mode = true
	progress.hard_cleared.clear()
	progress.start_story(1)
	var hard: Node2D = BASE_MAIN.instantiate()
	root.add_child(hard)
	current_scene = hard
	await physics_frame
	_check(not hard.can_try_full_game(), "hard level %d (the demo's last hard one): no TRY THE FULL GAME" % Demo.hard_levels())
	hard.free()
	current_scene = null
	progress.hard_mode = false


## A run's own look and maze (the slime's skin colours its goo trail, which draws the map).
func _fingerprint(game: Node) -> String:
	return "%d/%d/%s/%s/%d %s %s %s %s" % [game.random_seed, game.seed_level, game.theme, game.maze.get("start"), str(game.maze).hash(),
		progress.active_skin(), progress.jelly, progress.selected_hat, progress.trail_style]


## Bug (owner, 2026-10-23, on the phone): after the first restart the preview's map looked different. Every real
## restart path (the pause menu's RESTART, R) reloads the scene: the same maze AND the same borrowed look.
func _check_restarts() -> void:
	progress.reset_progress()
	progress.story_seen = progress.STORY_INTRO | progress.STORY_DEMO_END
	progress.levels_cleared = Demo.LEVELS
	progress.start_random()
	var game: Node2D = BASE_MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game._close_preview_card()
	var first := _fingerprint(game)
	var seen: Array[String] = [first]
	for n in 2:
		game.pause_menu._restart()  # (a reload of the scene, as on the phone)
		for i in 120:
			await process_frame
			if current_scene != null and current_scene != game:
				break
		game = current_scene
		await physics_frame
		seen.append(_fingerprint(game))
	_check(seen.all(func(f: String) -> bool: return f == first) and game.preview,
		"the preview maze is identical over two pause-menu restarts, its look too (%s)" % [seen])
	game.replay("R")
	for i in 120:
		await process_frame
		if current_scene != null and current_scene != game:
			break
	game = current_scene
	await physics_frame
	_check(_fingerprint(game) == first, "...and after R's replay (%s)" % _fingerprint(game))
	current_scene = null
	game.free()
	progress.end_demo_preview()
