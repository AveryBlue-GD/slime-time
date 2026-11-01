extends "res://tests/suite_base.gd"

## Dev toggles (dev mode only): F1 = FULL BRIGHT (the fog layers hidden, the fog/trail bytes and
## reveal untouched, so switching it off restores the exact normal fog), F2 = NO DRAIN (the meter
## stays put, then drains on from there). Outside dev mode they don't exist: keys, setters, HUD tag
## and pause-menu switches are all inert or never built. A run with a toggle used sets no record or
## medal (or tickets, in a randomizer maze, where FULL BRIGHT shows the goal ticket). Uses a throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_dev_toggles.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	Economy.random_tickets_force = 0  # (the attempt pod's chalice number alone: no ticket pickups in these mazes)
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.save_path = test_save
	progress.hard_mode = false
	progress.levels_cleared = 10
	progress.tutorial_seen = 3

	# --- Outside dev mode: nothing at all
	progress.dev_tools = false
	progress.dev_bright = true  # even a stale session flag must not switch anything on
	progress.dev_no_drain = true
	var game := await _spawn(2)
	_check(not game.dev_bright and not game.dev_no_drain and game.fog_sprite.visible and game.outer_fog.visible,
		"normal play: the session flags are ignored, the fog is on")
	game.set_dev_bright(true)
	game.set_dev_no_drain(true)
	_check(not game.dev_bright and not game.dev_no_drain and game.fog_sprite.visible, "normal play: the setters do nothing")
	_check(not game.dev_key_pressed(_key(KEY_F1)) and not game.dev_key_pressed(_key(KEY_F2)) and not game.dev_bright,
		"normal play: F1 / F2 do nothing")
	_check(game.hud.dev_badge == null, "normal play: no DEV tag is ever built")
	_check(game.pause_menu.dev_panel == null, "normal play: the pause menu has no dev switches")
	var before: float = game.slime_remaining
	await _glide(game, Vector2(40, 0))
	_check(game.slime_remaining < before, "normal play: gliding drains the meter (%.1f -> %.1f)" % [before, game.slime_remaining])
	game.free()
	progress.dev_bright = false
	progress.dev_no_drain = false

	# --- Dev mode, nothing switched on yet: no tag
	progress.dev_tools = true
	game = await _spawn(2)
	_check(game.hud.dev_badge == null and game.pause_menu.dev_panel != null, "dev mode: switches in the pause menu, no tag until one is on")

	# --- FULL BRIGHT on and off again leaves the fog exactly as it was
	await _glide(game, Vector2(30, 0))
	var fog_before: PackedByteArray = game._fog_bytes.duplicate()
	var trail_before: PackedByteArray = game._trail_bytes.duplicate()
	var chalice_seen: bool = game.goal.visible
	_check(game.dev_key_pressed(_key(KEY_F1)) and game.dev_bright, "dev mode: F1 switches FULL BRIGHT on")
	_check(not game.fog_sprite.visible and not game.outer_fog.visible and game.goal.visible,
		"FULL BRIGHT: no fog layers, the chalice shows")
	_check(game.hud.dev_badge.visible and game.hud._dev_label.text == "DEV BRIGHT", "FULL BRIGHT: the HUD tag says %s" % game.hud._dev_label.text)
	_check(game._fog_bytes == fog_before and game._trail_bytes == trail_before, "FULL BRIGHT on: the fog and trail bytes are untouched")
	game.set_dev_bright(false)
	_check(game.fog_sprite.visible and game.outer_fog.visible and game.goal.visible == chalice_seen and not game.hud.dev_badge.visible,
		"FULL BRIGHT off: the fog is back, the chalice hidden again, the tag gone")
	_check(game._fog_bytes == fog_before and game._trail_bytes == trail_before, "FULL BRIGHT off: the fog bytes are exactly as before")
	game.free()

	# --- While it is on, the fog keeps working underneath exactly as without it
	# Two copies of the same level started on the same frame (fog times are stored in the bytes).
	var a: Node2D = MAIN.instantiate()
	var b: Node2D = MAIN.instantiate()
	for g: Node2D in [a, b]:
		g.level = 3
		root.add_child(g)
	await physics_frame
	_check(a._fog_bytes == b._fog_bytes, "two copies of a level start with the same fog")
	a.set_dev_bright(true)
	for step: Vector2 in [Vector2(40, 0), Vector2(0, 30), Vector2(-20, 0)]:
		for g: Node2D in [a, b]:
			g.slime.position += step
		await physics_frame
		await physics_frame
	_check(a._fog_bytes == b._fog_bytes and a._trail_bytes == b._trail_bytes and a.revealed_walls == b.revealed_walls,
		"FULL BRIGHT: revealing and fading go on identically underneath (same bytes as a normal run)")
	a.set_dev_bright(false)
	_check(a.fog_sprite.visible and a._fog_bytes == b._fog_bytes, "...and switching it off shows that same normal fog")
	# The chalice: seen for real while bright (the slime went to it) stays seen afterwards.
	a.set_dev_bright(true)
	a.slime.position = a.goal.position + Vector2(a.CHALICE_REVEAL_DISTANCE - 2.0, 0)
	await physics_frame
	await physics_frame
	a.set_dev_bright(false)
	_check(a.goal.visible, "the chalice reached while FULL BRIGHT was on stays revealed when it goes off")
	a.free()
	b.free()

	# --- NO DRAIN
	game = await _spawn(4)
	game.set_dev_no_drain(true)
	_check(game.hud.dev_badge.visible and game.hud._dev_label.text == "DEV NO DRAIN", "NO DRAIN: the HUD tag says %s" % game.hud._dev_label.text)
	var full: float = game.slime_remaining
	await _glide(game, Vector2(60, 0))
	game.slime.last_jump_traveled = 80.0
	game._on_jump_landed(Slime.jump_distance_for(100.0), false, Vector2.ZERO)
	_check(game.slime_remaining == full and game.last_jump_cost > 0.0, "NO DRAIN: gliding and leaping leave the meter at %.1f" % game.slime_remaining)
	game.slime_remaining = 0.5
	await _glide(game, Vector2(-60, 0))
	_check(not game.finished and game.slime_remaining == 0.5, "NO DRAIN: an almost empty slime never dries up")
	game.slime_remaining = 50.0
	game.dev_key_pressed(_key(KEY_F2))
	_check(not game.dev_no_drain and not game.hud.dev_badge.visible, "F2 again: draining is back, the tag gone")
	await _glide(game, Vector2(40, 0))
	_check(game.slime_remaining < 50.0 and game.slime_remaining > 40.0, "...and the meter drains on from where it was (%.1f)" % game.slime_remaining)
	game.set_dev_bright(true)
	game.set_dev_no_drain(true)
	_check(game.hud._dev_label.text == "DEV BRIGHT NO DRAIN", "both on: the tag names both")
	_check(progress.dev_bright and progress.dev_no_drain, "the toggles are kept for the session (restarts keep them)")
	game.free()
	game = await _spawn(4)
	_check(game.dev_bright and game.dev_no_drain and not game.fog_sprite.visible, "a restart comes back with both still on")
	game.free()

	# --- DEV MAP (whole maze with BRIGHT on) and DRAIN NOW
	game = await _spawn(4)
	var whole: Dictionary = game.dev_full_map()
	_check(whole.goal and MapView._cell_seen(whole, game.maze.goal) and Survey.completeness(whole, game.maze) >= 0.999,
		"BRIGHT's map: the whole maze seen, the goal marked (%.0f%%)" % (Survey.completeness(whole, game.maze) * 100.0))
	game.set_dev_bright(false)
	current_scene = game
	game.open_dev_map()
	_check(game.random_map_view != null, "the pause menu's MAP opens this maze's map")
	game.random_map_view.close()
	current_scene = null
	game.set_dev_no_drain(false)
	game.dev_drain()
	for i in 10:
		await physics_frame
	_check(game.finished and not game.won and game.dev_toggled, "DRAIN NOW: the slime dries up (a dev-toggled run)")
	game.free()
	progress.dev_bright = true  # (both back on: the toggled-run checks below start with them on)
	progress.dev_no_drain = true

	# --- Never saved
	progress.saving_enabled = true
	progress.save_progress()
	var text := FileAccess.get_file_as_string(test_save)
	_check(text != "" and not "dev_bright" in text and not "dev_no_drain" in text, "the toggles are never written to the save")

	# --- A run with a toggle used sets no record or medal (and still wins normally)
	progress.best_times.erase(5)
	progress.medals.erase(5)
	game = MAIN.instantiate()
	game.level = 5
	root.add_child(game)
	current_scene = game
	await physics_frame
	_check(game.dev_toggled, "a run started with the toggles on counts as toggled")
	game.run_time = 1.0
	game._on_goal_body_entered(game.slime)
	_check(game.won and game.finished, "the win goes through as usual")
	_check(progress.best_time(5) < 0.0 and progress.medals_for(5) == 0, "no record and no medal from a toggled run")
	_check("DEV" in " ".join(game.hud.rewards_texts), "the result says the dev toggles earn nothing: %s" % " ".join(game.hud.rewards_texts))
	current_scene = null
	game.free()
	progress.dev_bright = false
	progress.dev_no_drain = false

	# --- Randomizer: FULL BRIGHT shows the ticket goal; in dev mode a toggled run keeps its pay for testing (a plain launch pays 0, see test_boards)
	progress.upgrades = {"slime": 1}
	progress.mode = progress.MODE_RANDOM
	game = MAIN.instantiate()
	game.random_seed = 4242
	root.add_child(game)
	current_scene = game
	await physics_frame
	_check(game.hud.attempt_label.text.ends_with(" 10") and not game.goal.visible, "randomizer: the ticket starts hidden; the pod shows 10 available (%s)" % game.hud.attempt_label.text)
	game.set_dev_bright(true)
	_check(game.goal == game.chalice and game.goal.visible and game.hud.attempt_label.text.ends_with(" 10"), "FULL BRIGHT shows the chalice, and in dev mode the pod keeps 10 (%s)" % game.hud.attempt_label.text)
	game.set_dev_bright(false)
	_check(not game.goal.visible, "...hidden again when it goes off")
	var tickets_before: int = progress.tickets
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.won and progress.tickets == tickets_before + 10, "a dev-toggled randomizer win in dev mode still pays the 10 shown: %s" % " ".join(game.hud.rewards_texts))
	current_scene = null
	game.free()
	progress.mode = progress.MODE_STORY
	progress.dev_bright = false
	progress.dev_no_drain = false
	progress.dev_tools = false

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
	quit(1 if failures else 0)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


## Moves the slime by `by` in small steps over physics frames (as gliding would).
func _glide(game: Node2D, by: Vector2) -> void:
	var steps := 10
	for i in steps:
		game.slime.position += by / steps
		await physics_frame


func _spawn(level: int) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	return game


