extends Node

## Debug overview for level design: the whole maze top-down with the fog off, the start (green
## ring), the chalice (gold ring), the solution route (dots) and the coins, plus the spawn class.
## Renders the level in a 1280x720 SubViewport (so a whole level fits) and saves it to --out=PATH
## (default .screens/overview.png), then quits. Needs a window (not --headless):
## ./tools/godot.sh --path . res://tests/demo_overview.tscn -- --unlock-all --level=5 [--hard] [--out=/abs/path.png]
## ./tools/godot.sh --path . res://tests/demo_overview.tscn -- --unlock-all --seed=4242   (randomizer)
## ./tools/godot.sh --path . res://tests/demo_overview.tscn -- --unlock-all --usage=550 [--upgrades=10,0,0]
##   (randomizer: the first seed 1, 7920, 15839 ... whose usage roll is within 10 permille of 550;
##   the ticket's cell gets a magenta ring and the second line shows u and the perfect run's usage)

const SIZE := Vector2i(1280, 720)

var game: Node2D
var view: SubViewport
var frames := 0
var out_path := ""


func _ready() -> void:
	var progress := get_node("/root/Progress")
	progress.saving_enabled = false
	progress.tutorial_seen = 3
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	out_path = ProjectSettings.globalize_path("res://.screens/overview.png")
	game = preload("res://scenes/main.tscn").instantiate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		if arg.begins_with("--seed="):
			progress.mode = progress.MODE_RANDOM
			game.random_seed = arg.trim_prefix("--seed=").to_int()
		if arg.begins_with("--usage="):
			var want := arg.trim_prefix("--usage=").to_int()
			var s := 1
			while absi(Levels.random_usage_permille(s) - want) > 10:
				s += 7919
			progress.mode = progress.MODE_RANDOM
			game.random_seed = s
	view.add_child(game)
	_overview.call_deferred()


func _process(_delta: float) -> void:
	frames += 1
	if frames == 20:
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		view.get_texture().get_image().save_png(out_path)
		print("Saved ", out_path)
		get_tree().quit()


func _overview() -> void:
	game.fog_sprite.visible = false
	if game.outer_fog:
		game.outer_fog.visible = false
	if game.slime_light:
		game.slime_light.visible = false
	game.hud.visible = false
	game.chalice.visible = true
	game.slime.set_physics_process(false)
	var maze: Dictionary = game.maze
	var world := Vector2(maze.size * game.TILE)
	var camera := Camera2D.new()
	camera.position = world / 2.0
	var fit := minf(SIZE.x / (world.x + 64.0), (SIZE.y - 40.0) / (world.y + 64.0))
	camera.zoom = Vector2.ONE * fit
	camera.offset = Vector2(0, -20.0 / fit)
	game.add_child(camera)
	camera.make_current()

	var marks := Node2D.new()
	marks.z_index = 30
	game.add_child(marks)
	var route := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	marks.draw.connect(func() -> void:
		for cell in route:
			marks.draw_circle(MazeGenerator.cell_center(cell, game.TILE), 2.5, Color(0.45, 0.95, 1.0, 0.9))
		var s := MazeGenerator.cell_center(maze.start, game.TILE)
		var g := MazeGenerator.cell_center(maze.goal, game.TILE)
		marks.draw_arc(s, 11.0, 0, TAU, 24, Color(0.3, 1.0, 0.4), 3.0)
		marks.draw_arc(g, 11.0, 0, TAU, 24, Color(1.0, 0.8, 0.2), 3.0)
		if game.ticket:
			marks.draw_arc(game.ticket.position, 9.0, 0, TAU, 24, Color(1.0, 0.3, 0.9), 3.0))
	marks.queue_redraw()

	var layer := CanvasLayer.new()
	layer.layer = 50
	view.add_child(layer)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.position = Vector2(12, 8)
	var d := SpawnPicker.edge_depth(maze.start, maze.cells)
	var title: String = ("RANDOM SEED %d" % game.random_seed) if game.is_random() else ("LEVEL %d%s" % [game.level, " HARD" if game.hard_mode else ""])
	label.text = "%s   %dx%d   START %s %s (EDGE DEPTH %d)   ROUTE %d / LONGEST %d   COINS %d" % [
		title, maze.cells.x, maze.cells.y, SpawnPicker.KIND_NAMES[maze.spawn_kind], maze.start, d,
		maze.goal_steps, maze.diameter, game.coins.size()]
	if game.is_random():
		label.text += "\nU %.2f   PERFECT RUN USES %d%% OF THE METER   MORE SLIME %d   CODE %s   TICKET %s" % [
			Levels.random_usage(game.random_seed, game.hard_mode), roundi(game.perfect_usage * 100.0), get_node("/root/Progress").upgrade_level("slime"),
			Levels.seed_code(game.random_seed, game.seed_level),
			("%d%% IN" % roundi(TicketSpawn.fraction_to(maze, game.ticket.cell, game.ticket_cost_per_tile) * 100.0)) if game.ticket else "NONE"]
	layer.add_child(label)
