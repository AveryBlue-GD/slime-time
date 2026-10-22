extends "res://tests/suite_base.gd"

## Randomizer extras: random (seeded) spawn cells, the TICKET as the maze's goal (no chalice node;
## the ticket stands on the goal cell, the autopilot wins by reaching it; story keeps the chalice),
## maze size growing with MORE SLIME, and save/story compatibility.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_random_tickets.gd

const SEEDS := 300



func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.saving_enabled = false

	# --- Deterministic: the same seed gives the same maze, start and goal (the ticket's cell)
	var cfg := Levels.random_config(4242)
	var a := MazeGenerator.generate_random(cfg)
	var b := MazeGenerator.generate_random(cfg)
	_check(a.walls == b.walls and a.start == b.start and a.goal == b.goal and a.goal_steps == b.goal_steps, "same seed: same maze, start and ticket cell")
	_check(Levels.random_config(4242).cells == Levels.random_config(4242).cells, "same seed: same size")

	# --- Many seeds: spawn variety, route length
	var starts := {}
	var corner := 0
	var wrong_route := 0
	var all_connected := true
	for i in SEEDS:
		var s := 1000 + i * 7919
		var c := Levels.random_config(s)
		var maze := MazeGenerator.generate_random(c)
		starts[maze.start] = true
		if maze.start == Vector2i.ZERO:
			corner += 1
		all_connected = all_connected and MazeGenerator.is_completable(maze)
		if maze.goal_steps != c.route:
			wrong_route += 1
	_check(all_connected, "every random-start maze is fully connected")
	_check(starts.size() >= SEEDS * 0.5, "spawn varies across seeds (%d distinct starts in %d)" % [starts.size(), SEEDS])
	_check(corner < SEEDS * 0.2, "the old top-left corner is no longer the usual start (%d/%d)" % [corner, SEEDS])
	_check(wrong_route == 0, "the start-to-ticket route is the length the seed's usage asks for (%d off)" % wrong_route)
	# --- Usually (not always) more than one route to the chalice (MazeGenerator.add_second_route)
	var two := 0
	for i in SEEDS:
		if MazeGenerator.has_second_route(MazeGenerator.generate_random(Levels.random_config(1000 + i * 7919))):
			two += 1
	_check(two >= SEEDS * 0.75 and two < SEEDS, "most random mazes have 2+ routes to the chalice, not all (%d/%d)" % [two, SEEDS])
	# --- Sizes vary (Levels.RANDOM_SIZE_SCALES): mostly smaller, sometimes full size
	var shares := {}
	for i in SEEDS:
		var share := Levels.random_size_scale(1000 + i * 7919)
		shares[share] = shares.get(share, 0) + 1
	_check(shares.size() == Levels.RANDOM_SIZE_SCALES.size() and shares.get(1.0, 0) < SEEDS / 3 and shares.get(1.0, 0) > 0
		and Levels.random_size_scale(5, true) == 1.0, "maze sizes vary, full size only sometimes %s (hard mode always full)" % [shares])
	var hard_two := 0
	for i in 40:
		var hard_maze := MazeGenerator.generate_random(Levels.random_config(1000 + i * 7919, true))
		if MazeGenerator.has_second_route(hard_maze):
			hard_two += 1
	_check(not Levels.random_config(1, true).second_route, "hard mode mazes get no added route (%d/40 have one anyway)" % hard_two)

	# --- Size scales with MORE SLIME (sized for the 95% route of the meter, which grows), never with u
	var last_area := 0
	var rising := true
	for level in range(0, Upgrades.max_level("slime") + 1):
		var area := 0
		for i in 40:
			var cells := Levels.random_cells(5000 + i, level)
			area += cells.x * cells.y
			rising = rising and cells.x <= Levels.RANDOM_MAX_CELLS.x and cells.y <= Levels.RANDOM_MAX_CELLS.y and cells.x >= Levels.RANDOM_MIN_CELLS.x and cells.y >= Levels.RANDOM_MIN_CELLS.y
		rising = rising and area >= last_area
		last_area = area
	_check(rising, "mazes get bigger with each MORE SLIME level, within %s .. %s" % [Levels.RANDOM_MIN_CELLS, Levels.RANDOM_MAX_CELLS])
	var small := Levels.random_cells(777, 0)
	var big := Levels.random_cells(777, 7)
	_check(big.x * big.y > small.x * small.y * 1.4, "MORE SLIME 7 is a much bigger maze than level 0 (%s -> %s)" % [small, big])
	_check(Levels.random_config(777, true, 7).cells == Levels.random_cells(777, 0, true), "hard mode has no upgrades, so no growth")

	# --- Story levels: a fixed spawn per level (the level's class, drawn from its own seed); par from the real route
	for level in range(1, Levels.COUNT + 1):
		var c := Levels.get_config(level)
		var m := Levels.story_maze(level)
		var again := Levels.story_maze(level)
		_check(m.start == again.start and m.goal == again.goal and m.spawn_kind == c.spawn, "story level %d: always the same %s start %s" % [level, SpawnPicker.KIND_NAMES[c.spawn], m.start])
	_check(is_equal_approx(Levels.level_par(1), Levels.par_for_path(Levels.story_maze(1).goal_steps * 2 - 13.0 / 16.0)), "story par uses the real start-to-chalice route")

	# --- Real game: the slime starts on the maze's start, the budget and par use the real start
	progress.mode = progress.MODE_RANDOM
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	game.random_seed = 4242
	root.add_child(game)
	await physics_frame
	_check(game.slime.position == MazeGenerator.cell_center(game.maze.start, 16) and game.maze.start == a.start, "the slime spawns on the seeded start cell %s" % game.maze.start)
	var real_tiles: float = game.maze.goal_steps * 2 - 13.0 / 16.0
	_check(is_equal_approx(game.par_time, Levels.par_for_path(real_tiles, game.slime.max_speed)), "par is measured along the real start-to-ticket route")
	var used: float = real_tiles * game.slime_cost_per_tile
	var want: float = Levels.random_usage(4242) * 100.0
	_check(absf(used - want) < 1.5, "a perfect run uses the seed's usage of the (fixed) meter: %.1f%% (u %.1f%%)" % [used, want])
	# The goal is the chalice again (Economy.RANDOM_CHALICE), on the goal cell.
	_check(Economy.RANDOM_CHALICE and game.chalice != null and game.goal == game.chalice and not (game.goal is TicketGoal)
		and game.goal.position == MazeGenerator.cell_center(game.maze.goal, 16),
		"the chalice stands on the goal cell %s" % game.maze.goal)
	_check(not game.goal.visible, "...hidden under the fog until the slime is near")
	_check((game.goal.get_node("CollisionShape2D").shape as CircleShape2D).radius == TicketGoal.GRAB_RADIUS and TicketGoal.GRAB_RADIUS == 6.0,
		"...with the chalice's grab circle (so the meter calibration is unchanged)")
	_check(game.hud.attempt_pod.visible and game.hud.attempt_label.text.begins_with("ATTEMPT "), "the HUD shows the attempt pod (%s)" % game.hud.attempt_label.text)
	# --- Ticket pickups: Economy.RANDOM_TICKETS in seeded dead ends, under the fog, 1 ticket each, gone on retries
	var cells := TicketPickup.cells_for(game.maze, 4242, Economy.RANDOM_TICKETS)
	_check(cells.size() == Economy.RANDOM_TICKETS and game.tickets.size() == cells.size() and cells == TicketPickup.cells_for(game.maze, 4242, Economy.RANDOM_TICKETS),
		"%d ticket pickups, the same cells every time %s" % [game.tickets.size(), cells])
	_check(game.tickets.all(func(t: TicketPickup) -> bool: return t.z_index < game.fog_sprite.z_index and not t.cell in [game.maze.start, game.maze.goal]),
		"...under the fog (found by exploring or an ability), never on the start or the chalice")
	var before_tickets: int = progress.tickets
	var pod_before: int = game.hud.attempt_label.text.get_slice("TIX AVAILABLE ", 1).to_int()
	_check(pod_before == game.ticket_offer() + cells.size() * Economy.RANDOM_TICKET_PAY,
		"TIX AVAILABLE counts the chalice's tickets and the pickups still out (%d)" % pod_before)
	var first: TicketPickup = game.tickets[0]
	var first_cell := first.cell
	game.slime.position = first.position
	for i in 3:
		await physics_frame
	var pod_after: int = game.hud.attempt_label.text.get_slice("TIX AVAILABLE ", 1).to_int()
	_check(pod_after == pod_before - Economy.RANDOM_TICKET_PAY, "...and counts down as one is taken (%d -> %d)" % [pod_before, pod_after])
	_check(progress.tickets == before_tickets + Economy.RANDOM_TICKET_PAY and game.tickets.size() == cells.size() - 1
		and progress.random_ticket_taken(game.attempt_key, first_cell), "touching one pays %d ticket and takes it" % Economy.RANDOM_TICKET_PAY)
	_check(progress.take_random_ticket(game.attempt_key, first_cell) == 0, "...a taken pickup never pays again (its retries don't put it out)")
	# --- The map: the chalice and the tickets as icons, only on seen cells
	var survey := Survey.full(game.maze, 10.0)
	survey.goal = true
	survey.tickets = game.ticket_cells()
	var sizes := MapView.layout(game.maze.cells, Vector2i(300, 140))
	var shown := MapView.render(game.maze, survey, sizes, [] as Array[Vector2i])
	_check(_px(shown, MapView.CHALICE_COLORS[0]) > 0 and _px(shown, MapView.TICKET_COLORS[0]) > 0, "the map draws the chalice and the tickets (cells %d px)" % sizes.x)
	var unseen := MapView.render(game.maze, Survey.blank(game.maze).merged({goal = true, tickets = game.ticket_cells()}, true), sizes, [] as Array[Vector2i])
	_check(_px(unseen, MapView.CHALICE_COLORS[0]) == 0 and _px(unseen, MapView.TICKET_COLORS[0]) == 0, "...none of them on unseen cells")
	# The two-line pod fits the 320x180 screen without touching the other pods, the area name (moved
	# under it) or the touch pause button (moved down too).
	await process_frame
	var hud: CanvasLayer = game.hud
	var pod: Rect2 = hud.attempt_pod.get_global_rect()
	var others: Array[Rect2] = [hud.time_label.get_parent().get_parent().get_global_rect(), hud.level_label.get_parent().get_parent().get_global_rect(),
		hud.coin_label.get_parent().get_parent().get_global_rect(), hud.label.get_parent().get_parent().get_global_rect()]
	var text_w: float = hud.area_label.get_theme_font("font").get_string_size(hud.area_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	others.append(Rect2(160.0 - text_w / 2.0, hud.area_label.offset_top, text_w, hud.area_label.offset_bottom - hud.area_label.offset_top))
	others.append(game.touch_controls.pause_rect)
	var clear := pod.position.x >= 0 and pod.end.x <= 320 and pod.end.y <= 180
	for r: Rect2 in others:
		clear = clear and not pod.intersects(r)
	_check(clear, "the attempt pod %s stays on screen and clear of the other pods, the area name and the touch pause button" % pod)
	game.slime.position = game.goal.position + Vector2(game.CHALICE_REVEAL_DISTANCE - 2.0, 0)
	await physics_frame
	await physics_frame
	_check(game.goal.visible, "the ticket shows once the slime is a couple of tiles away")
	game.queue_free()
	await process_frame

	# --- The autopilot wins a randomizer maze by gliding to the ticket
	for s in [4242, 777]:
		var run: Node2D = load("res://scenes/main.tscn").instantiate()
		run.random_seed = s
		root.add_child(run)
		await physics_frame
		run.add_child(preload("res://tests/autopilot.gd").new())
		var waited := 0.0
		while not run.finished and waited < 60.0:
			await physics_frame
			waited += 1.0 / 60.0
		_check(run.won and run.slime_remaining > 0.0 and run.slime.position.distance_to(run.goal.position) < 16.0,
			"seed %d: the autopilot reaches the ticket and wins (%.0f%% slime left)" % [s, run.slime_remaining])
		run.queue_free()
		await process_frame

	# --- Story levels keep the chalice as their goal
	progress.mode = progress.MODE_STORY
	var story: Node2D = load("res://scenes/main.tscn").instantiate()
	story.level = 1
	root.add_child(story)
	await physics_frame
	_check(story.chalice != null and story.goal == story.chalice and story.get_node_or_null("Chalice") != null and not (story.goal is TicketGoal)
		and not story.hud.attempt_pod.visible, "story levels keep the chalice (no ticket goal, no attempt pod)")
	story.queue_free()
	await process_frame

	# --- Save compatibility: an old save (no new keys) loads; the spins counter sets the wheel price
	var old := ConfigFile.new()
	old.set_value("meta", "version", 3)
	old.set_value("wallet", "globs", 40)
	old.set_value("hats", "spins", 4)
	var loaded: Node = preload("res://scripts/progress.gd").new()
	loaded._read(old)
	_check(loaded.tickets == 40 and loaded.spins == 4 and loaded.spin_cost() == 18, "an old save loads; 4 spins taken -> the next costs 18")
	var empty := ConfigFile.new()
	var fresh: Node = preload("res://scripts/progress.gd").new()
	fresh._read(empty)
	_check(fresh.spins == 0 and fresh.spin_cost() == 0, "a save with no spins: the first spin is free")
	loaded.free()
	fresh.free()

	_result()
	quit(0 if failures == 0 else 1)



func _px(img: Image, color: Color) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(color):
				n += 1
	return n


## Any node in the game made from the chalice scene or script.
func _find_chalice(node: Node) -> Node:
	if node.scene_file_path == "res://scenes/chalice.tscn" or (node.get_script() and (node.get_script() as Script).resource_path == "res://scripts/chalice.gd"):
		return node
	for child in node.get_children():
		var found := _find_chalice(child)
		if found:
			return found
	return null


