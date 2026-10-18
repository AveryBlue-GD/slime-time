extends "res://tests/suite_base.gd"

## SPLASHDOWN, the training maze (chunk B of docs/tutorial/design.md; gate Economy.TUTORIAL_TEST, forced
## on here with Economy.tutorial_force): the hand-made layout parses (25x13, start, chalice, the practice
## coin two cells up a dead end, routes 44 / 52 tiles), a full leap from the straight's west end lands
## clear of the wall (a second one splats), a glide-only autopilot run on the low first meter picks up
## the coin and dries up after it, the dry-up row is RESTART only, RESTART is attempt 2 with a full meter
## and the coin kept, the chalice row is HUB only, the beats come once each in order, the R prompt has no
## UPGRADES, SKIP TRAINING ends it, and nothing is saved (coins, records, medals, maps, dry-ups, tickets,
## skin; a replay writes no bit). Gate off: a story level plays exactly as before (no training branch).
## Prints the autopilot's beat timings (a lower bound for a player: no reading, no hesitation).
## Uses a throwaway save; the real save's md5 is checked unchanged at the end.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_training_maze.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()
var progress: Node
## training_cue names with the physics frame they came on (this suite's clock).
var beats: Array = []
var frame := 0


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	Story.launched = true
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH)
	var real_md5 := FileAccess.get_md5(real) if FileAccess.file_exists(real) else ""
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	physics_frame.connect(func() -> void: frame += 1)
	node_added.connect(_on_node_added)  # (connected before _ready: a reloaded maze's first beat is caught too)

	_layout()
	await _gate_off()
	Economy.tutorial_force = 1
	await _leap_straight()
	await _full_run()
	await _restart_prompt()
	await _coin_line_source()
	await _skip()
	await _replay_writes_nothing()

	Economy.tutorial_force = -1
	progress.reset_progress()
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched")
	_result()
	quit(1 if failures > 0 else 0)


# --- The layout
func _layout() -> void:
	var maze := Training.build_maze()
	_check(maze.size == Vector2i(25, 13) and maze.cells == Vector2i(12, 6), "SPLASHDOWN is 25x13 tiles, 12x6 cells")
	_check(maze.start == Vector2i(0, 4) and maze.goal == Vector2i(10, 0) and maze.coin == Vector2i(8, 0), "start, chalice and coin cells")
	var direct := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	var to_coin := MazeGenerator.shortest_path(maze, maze.start, maze.coin)
	var coin_to_goal := MazeGenerator.shortest_path(maze, maze.coin, maze.goal)
	_check(not direct.is_empty() and not to_coin.is_empty(), "the chalice and the coin are reachable (solvable)")
	_check((direct.size() - 1) * 2 == 44, "direct route 44 tiles (%d)" % ((direct.size() - 1) * 2))
	_check((to_coin.size() - 1 + coin_to_goal.size() - 1) * 2 == 52, "route with the coin 52 tiles")
	_check(maze.goal_steps == 22, "goal_steps 22 cells")
	_check(MazeGenerator.open_neighbors(maze, maze.coin).size() == 1 and MazeGenerator.open_neighbors(maze, maze.start).size() == 1,
		"the coin sits at a dead end; the start is a pocket with one way out")
	var fork_cell := Vector2i(Training.FORK.x >> 1, Training.FORK.y >> 1)
	_check(MazeGenerator.shortest_path(maze, fork_cell, maze.coin).size() - 1 == 2 and MazeGenerator.open_neighbors(maze, fork_cell).size() == 3,
		"the coin is 2 cells up from the fork (the only fork)")
	var forks := 0
	for y in maze.cells.y:
		for x in maze.cells.x:
			if not MazeGenerator.is_wall(maze, Vector2i(x * 2 + 1, y * 2 + 1)) and MazeGenerator.open_neighbors(maze, Vector2i(x, y)).size() > 2:
				forks += 1
	_check(forks == 1, "exactly one fork")
	var straight := 0
	for x in range(Training.STRAIGHT_FROM.x, Training.FORK.x + 1):
		if not MazeGenerator.is_wall(maze, Vector2i(x, Training.STRAIGHT_FROM.y)):
			straight += 1
	_check(straight == 13, "the leap straight: 12 tiles from its west end to the fork")
	# A full leap from the straight's west end stops short of the wall (geometry; played below too).
	var from := MazeGenerator.cell_center(Vector2i(Training.STRAIGHT_FROM.x >> 1, Training.STRAIGHT_FROM.y >> 1), 16).x
	var room := (Training.FORK.x + 1) * 16 - Slime.RADIUS - from
	_check(Slime.jump_distance_for(100.0) <= room - 32.0, "a full leap (%d px) lands at least 2 tiles short of the wall (%d px of room)" % [Slime.jump_distance_for(100.0), room])
	_check(Training.start_percent(1) < 35.0 and Training.start_percent(2) == 100.0, "attempt 1 starts low (%.0f%%), attempt 2 full" % Training.start_percent(1))


# --- Gate off: no training anywhere, a story level as before
func _gate_off() -> void:
	Economy.tutorial_force = 0
	progress.reset_progress()
	progress.tutorial_seen = 3
	_check(not progress.tutorial_due() and not progress.in_training(), "gate off: nothing due, not in training")
	progress.start_story(1)
	var game := await _start_game()
	_check(not game.training and game.level == 1, "gate off: level 1 is a story level (no training branch)")
	_check((game.hud.time_label.get_parent().get_parent() as Control).visible, "...with its timer pod")
	_check(game.coins_here > 1, "...and its real coins (%d)" % game.coins_here)
	game.restart_prompt.open()
	_check(game.restart_prompt.buttons[1].visible, "...and the R prompt keeps UPGRADES")
	game.restart_prompt.close()
	game.pause_menu.open()
	_check(game.pause_menu.buttons[3].text == "QUIT TO HUB", "...and the pause menu says QUIT TO HUB")
	game.pause_menu.resume()
	await _stop(game)


# --- A full leap down the straight lands clear; a second one splats
func _leap_straight() -> void:
	progress.reset_progress()
	progress.prepare_training(false)
	var game := await _start_game()
	await _physics_frames(10)
	var slime: Slime = game.slime
	slime.position = MazeGenerator.cell_center(Vector2i(Training.STRAIGHT_FROM.x >> 1, Training.STRAIGHT_FROM.y >> 1), 16)
	slime.velocity = Vector2.ZERO
	game.last_slime_pos = slime.position
	slime.facing = Vector2.RIGHT
	var landings: Array = []
	slime.jump_landed.connect(func(_d: float, hit: bool, _n: Vector2) -> void: landings.append(hit))
	slime.launch(100.0)
	await _until(func() -> bool: return landings.size() >= 1, 240)
	_check(landings == [false], "a full leap from the straight's west end lands without a splat")
	var landed_x: float = slime.position.x
	await _physics_frames(30)
	slime.facing = Vector2.RIGHT
	slime.launch(100.0)
	await _until(func() -> bool: return landings.size() >= 2, 240)
	_check(landings.size() == 2 and landings[1] == true, "...a second full leap splats into the wall (landed at x %d)" % landed_x)
	await _stop(game)


# --- Attempt 1 dries up after the coin, RESTART, attempt 2 wins, HUB
func _full_run() -> void:
	progress.reset_progress()
	var before := _save_text()
	_check(progress.tutorial_due(), "gate on: a fresh save is due the training")
	var scene: String = progress.prepare_training(false)
	_check(scene == progress.TRAINING_SCENE and progress.in_training(), "prepare_training opens the training maze (no stub)")
	beats.clear()
	var game := await _start_game()
	var t0 := frame
	_check(game.training and game.training_attempt == 1, "the game scene plays SPLASHDOWN, attempt 1")
	_check(game.hud.level_label.text == "SPLASHDOWN", "the level pod says SPLASHDOWN")
	_check(not (game.hud.time_label.get_parent().get_parent() as Control).visible, "no timer pod")
	_check(game.coins_here == 1 and game.coins.size() == 1, "one practice coin waits")
	_check(absf(game.slime_remaining - Training.start_percent(1)) < 0.01, "the meter starts low (%.1f%%)" % game.slime_remaining)
	_check(progress.selected_skin == Skins.DEFAULT and progress.skin_override == "", "no first-run skin (the default Lime)")
	var maze: Dictionary = game.maze
	var route := MazeGenerator.shortest_path(maze, maze.start, maze.coin)
	route.append_array(MazeGenerator.shortest_path(maze, maze.coin, maze.goal).slice(1))
	var pilot := _pilot(game, route)
	var seen := {coin = -1}  # (a lambda can't assign the function's locals)
	await _until(func() -> bool:
		if seen.coin < 0 and Training.coin_taken:
			seen.coin = frame
		return game.finished, 60 * 60)
	var coin_frame: int = seen.coin
	pilot.queue_free()
	var dry_frame := frame
	_check(game.finished and not game.won, "attempt 1 (glide-only autopilot): dries up")
	_check(Training.coin_taken and coin_frame > 0, "...after picking up the coin")
	var dry_tile := Vector2i((game.slime.position / 16).floor())
	_check(dry_tile.x == Training.FORK.x and dry_tile.y >= 1 and dry_tile.y <= 7, "...just after it, around the fork (tile %s)" % dry_tile)
	await _until(func() -> bool: return _shown_buttons(game).size() > 0, 120)
	_check(_labels(game) == ["RESTART"], "the dry-up row is RESTART only: %s" % [_labels(game)])
	_check(not game.hud.choice_buttons.is_empty() and game.hud.choice_buttons[0].has_focus(), "...focused")
	var row_frame := frame
	_check(_names() == ["start", "first_drain", "straight", "fork", "dry"], "attempt 1 beats in order, once each: %s" % [_names()])
	_check(progress.dry_ups.is_empty(), "no dry-up counted")
	_check(progress.coins() == 0 and progress.coins_found.is_empty() and progress.coins_earned() == 0, "the practice coin is not saved")
	_check(game.hud.coin_label.text == "1", "...but the HUD shows it (%s)" % game.hud.coin_label.text)

	beats.clear()
	var old_id := game.get_instance_id()
	var press_frame := frame
	await _action("ui_accept")
	var game2: Node2D = await _until_scene_not(old_id, UIKit.GAME_SCENE)
	_check(game2 != null and game2.training and game2.training_attempt == 2, "RESTART: attempt 2")
	if game2 == null:
		return
	var t2 := frame
	await _physics_frames(2)
	_check(absf(game2.slime_remaining - 100.0) < 0.01, "...with a full meter")
	_check(game2.coins.is_empty() and Training.coin_taken and game2.hud.coins_left_label.text == "ALL FOUND", "...the coin kept (ALL FOUND)")
	pilot = _pilot(game2, MazeGenerator.shortest_path(game2.maze, game2.maze.start, game2.maze.goal))
	await _until(func() -> bool: return game2.finished, 60 * 60)
	pilot.queue_free()
	var win_frame := frame
	_check(game2.finished and game2.won, "attempt 2 reaches the chalice")
	_check(game2.slime_remaining >= 40.0, "...with at least 40%% left (%.0f%%)" % game2.slime_remaining)
	await _until(func() -> bool: return _shown_buttons(game2).size() > 0, 120)
	_check(_labels(game2) == ["HUB"], "the win row is HUB only: %s" % [_labels(game2)])
	_check(not game2.hud.rewards_row.visible, "no medal / reward row")
	# (once per name per attempt: the straight / fork / first drain come again on attempt 2)
	_check(_names() == ["start", "restart", "first_drain", "straight", "fork", "chalice"], "attempt 2 beats, once each: %s" % [_names()])
	_check(progress.best_times.is_empty() and progress.medals.is_empty() and progress.maps.is_empty() and progress.levels_cleared == 0 \
		and progress.tickets == 0, "no record, medal, map survey, clear or ticket")
	print("  timing (autopilot, glide only; 60 ticks/s): attempt 1 start->coin %.1f s, ->dry-up %.1f s, ->RESTART row %.1f s; attempt 2 start->chalice %.1f s; RESTART press->attempt 2 %.1f s; maze total %.1f s" % [
		(coin_frame - t0) / 60.0, (dry_frame - t0) / 60.0, (row_frame - t0) / 60.0, (win_frame - t2) / 60.0, (t2 - press_frame) / 60.0,
		(win_frame - t0) / 60.0])
	await _action("ui_accept")
	var hub: Node = await _until_scene(UIKit.HUB_SCENE)
	_check(hub != null, "HUB opens the hub")
	_check(progress.mode == progress.MODE_STORY and progress.has_seen_tutorial(progress.TUTORIAL_TRAINING) and progress.hub_tour_due(),
		"...training saved as done, the tour due")
	_check(not progress.training_skipped, "...not counted as skipped")
	_check(progress.training_coin, "...the practice coin was picked up (the tour's coin bag line says so)")
	var after := _save_text()
	_check(_without_tutorial(after) == _without_tutorial(before), "the save differs only in tutorial_seen")
	await _clear_scene()


# --- R mid-run: RESTART / CANCEL (no UPGRADES); RESTART from it is the same attempt again (attempt 1
# keeps its low meter: the staged dry-up isn't skipped; attempt 2 stays full)
func _restart_prompt() -> void:
	progress.reset_progress()
	progress.collect_coin(1, Levels.story_coin_cells(1)[0])  # (a coin in hand: the story prompt would offer UPGRADES)
	progress.prepare_training(false)
	var game := await _start_game()
	await _action("restart")
	await _physics_frames(2)
	var prompt: RestartPrompt = game.restart_prompt
	_check(prompt.visible and not prompt.buttons[1].visible and prompt.buttons[0].visible and prompt.buttons[2].visible,
		"R mid-run: the prompt shows RESTART / CANCEL, no UPGRADES")
	var old_id := game.get_instance_id()
	prompt.buttons[0].pressed.emit()
	var game2: Node2D = await _until_scene_not(old_id, UIKit.GAME_SCENE)
	_check(game2 != null and game2.training_attempt == 1 and absf(game2.slime_remaining - Training.start_percent(1)) < 0.01,
		"...its RESTART on attempt 1: attempt 1 again, the low meter (%s)" % (game2.training_attempt if game2 else -1))
	game2.pause_menu.open()
	old_id = game2.get_instance_id()
	game2.pause_menu.restart_button.pressed.emit()
	var game3: Node2D = await _until_scene_not(old_id, UIKit.GAME_SCENE)
	_check(game3 != null and game3.training_attempt == 1, "...the pause menu's RESTART mid-run too")
	game3.slime_remaining = 0.0
	await _until(func() -> bool: return _shown_buttons(game3).size() > 0, 240)
	old_id = game3.get_instance_id()
	_shown_buttons(game3)[0].pressed.emit()
	var game4: Node2D = await _until_scene_not(old_id, UIKit.GAME_SCENE)
	_check(game4 != null and game4.training_attempt == 2, "...after a dry-up, RESTART is attempt 2")
	await _physics_frames(2)
	await _action("restart")
	await _physics_frames(2)
	old_id = game4.get_instance_id()
	game4.restart_prompt.buttons[0].pressed.emit()
	var game5: Node2D = await _until_scene_not(old_id, UIKit.GAME_SCENE)
	_check(game5 != null and game5.training_attempt == 2 and absf(game5.slime_remaining - 100.0) < 0.01,
		"...R mid-run on attempt 2: attempt 2 again, full meter")
	await _clear_scene()


# --- The tour's coin bag line follows the practice coin, not the way the training ended
func _coin_line_source() -> void:
	progress.reset_progress()
	progress.prepare_training(false)
	var game := await _start_game()
	game.slime.position = game.goal.position
	await _until(func() -> bool: return _shown_buttons(game).size() > 0, 240)
	_check(game.won and not Training.coin_taken, "teleported to the chalice: a win without the coin")
	_shown_buttons(game)[0].pressed.emit()
	await _until_scene(UIKit.HUB_SCENE)
	_check(not progress.training_coin and not progress.training_skipped, "...a win without the coin: training_coin false")
	await _clear_scene()
	progress.reset_progress()
	progress.prepare_training(false)
	game = await _start_game()
	game.slime.position = MazeGenerator.cell_center(game.maze.coin, 16)
	await _until(func() -> bool: return Training.coin_taken, 120)
	game.slime_remaining = 100.0
	game.slime.position = game.goal.position
	await _until(func() -> bool: return _shown_buttons(game).size() > 0, 240)
	_check(game.won and Training.coin_taken, "the coin, then the chalice")
	game.pause_menu.open()
	game.pause_menu.buttons[3].pressed.emit()
	await _until_scene(UIKit.HUB_SCENE)
	_check(progress.training_coin and progress.training_skipped, "...then SKIP TRAINING from the win panel: training_coin true")
	await _clear_scene()


# --- SKIP TRAINING
func _skip() -> void:
	progress.reset_progress()
	progress.prepare_training(false)
	var game := await _start_game()
	await _action("menu")
	await process_frame
	_check(game.pause_menu.visible and game.pause_menu.buttons[3].text == "SKIP TRAINING", "the pause menu offers SKIP TRAINING")
	_check(game.pause_menu.buttons[0].has_focus(), "...RESUME keeps the focus")
	game.pause_menu.buttons[3].pressed.emit()
	var hub: Node = await _until_scene(UIKit.HUB_SCENE)
	_check(hub != null and progress.training_skipped and progress.has_seen_tutorial(progress.TUTORIAL_TRAINING) and progress.mode == progress.MODE_STORY,
		"SKIP TRAINING: the hub, training saved as skipped")
	_check(Training.attempt == 1 and not Training.coin_taken, "...the run's state is cleared")
	await _clear_scene()


# --- The SETTINGS replay writes nothing
func _replay_writes_nothing() -> void:
	progress.reset_progress()
	progress.levels_cleared = 3
	progress.tutorial_seen = 15
	progress.save_progress()
	var before := _save_text()
	progress.prepare_training(true)
	var game := await _start_game()
	game.slime_remaining = 0.0
	await _until(func() -> bool: return _shown_buttons(game).size() > 0, 240)
	_check(_labels(game) == ["RESTART"], "replay: the same RESTART-only row")
	game.pause_menu.open()
	game.pause_menu.buttons[3].pressed.emit()
	await _until_scene(UIKit.HUB_SCENE)
	_check(_save_text() == before and progress.dry_ups.is_empty(), "replay: nothing saved")
	await _clear_scene()


# --- helpers

func _start_game() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await _physics_frames(2)
	return game


func _pilot(game: Node2D, cells: Array[Vector2i]) -> Node:
	var pilot := RoutePilot.new()
	pilot.cells = cells
	game.add_child(pilot)
	return pilot


func _names() -> Array:
	return beats.map(func(b: Array) -> String: return b[0])


func _shown_buttons(game: Node2D) -> Array:
	return game.hud.choice_buttons.filter(func(b: Button) -> bool: return b.is_visible_in_tree())


func _labels(game: Node2D) -> Array:
	return game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)


func _until(done: Callable, frames: int) -> void:
	for i in frames:
		if done.call():
			return
		await physics_frame


func _until_scene(path: String) -> Node:
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and not root.get_node("Transition").busy:
			return current_scene
	return null


## The game scene that replaced `old` (a reload), once its transition is over.
func _until_scene_not(old_id: int, path: String) -> Node:
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id and current_scene.scene_file_path == path:
			return current_scene
	return null


func _on_node_added(node: Node) -> void:
	if node.has_signal("training_cue") and not node.is_connected("training_cue", _on_cue):
		node.connect("training_cue", _on_cue)


func _on_cue(n: String) -> void:
	beats.append([n, frame])


func _stop(game: Node2D) -> void:
	current_scene = null
	game.free()
	paused = false
	await _physics_frames(1)


func _clear_scene() -> void:
	root.get_node("Transition").busy = false
	paused = false
	if current_scene:
		var scene := current_scene
		current_scene = null
		scene.free()
	await _physics_frames(2)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _save_text() -> String:
	return FileAccess.get_file_as_string(test_save) if FileAccess.file_exists(test_save) else ""


func _without_tutorial(text: String) -> String:
	var keep: Array[String] = []
	for line in text.split("\n"):
		if not line.begins_with("tutorial_seen="):
			keep.append(line)
	return "\n".join(keep)
