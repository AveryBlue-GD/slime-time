extends "res://tests/suite_base.gd"

## The unbreakable border outside the maze (MazeTiles.add_border / border_cells): the ring next to
## the maze collides exactly like before (a full wall square on every ring tile, nothing past it),
## the art is picked deterministically with integer math (same tiles every build, every platform),
## no border tile ever lands inside the playable maze, the brightness light reveals the ring like any
## wall, and the theme art regenerates to exactly the checked-in atlases. Uses a throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_border.gd

const MAIN := preload("res://scenes/main.tscn")

var progress: Node


var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.hard_mode = false
	progress.dev_tools = false
	progress.tutorial_seen = 3

	# --- Integer hashing gives fixed values (the same on desktop and web)
	_check(MazeTiles.border_hash(3, -2, 1118) == 638858610 and MazeTiles.border_hash(-7, 40, 2000000000) == 585960247,
		"border_hash: fixed 64-bit integer results (%d, %d)" % [MazeTiles.border_hash(3, -2, 1118), MazeTiles.border_hash(-7, 40, 2000000000)])

	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for level in range(1, Levels.COUNT + 1):
		var game := await _spawn(level, 0)
		_check_border(game, "level %d (%s)" % [level, game.theme], square)
		game.free()
	var random_game := await _spawn(0, 4242)
	_check_border(random_game, "randomizer seed 4242 (%s)" % random_game.theme, square)
	random_game.free()

	# --- Deterministic: the same maze gets the same border, another salt a different one
	var size := Vector2i(31, 17)
	var once := MazeTiles.border_cells(size, 1, 3, 2136)
	var again := MazeTiles.border_cells(size, 1, 3, 2136)
	var other := MazeTiles.border_cells(size, 1, 3, 2137)
	_check(once == again, "border_cells: the same tiles every time for the same maze and seed")
	_check(once != other, "border_cells: another seed lays a different border")
	var rows := {}
	var masks := {}
	for tile: Vector2i in once:
		rows[once[tile].y] = true
		masks[once[tile].x] = true
	_check(rows.size() >= 6 and masks.size() >= 10, "variety: %d atlas rows and %d columns in use (corner terrain, props, boulders)" % [rows.size(), masks.size()])
	var a := await _spawn(3, 0)
	var b := await _spawn(3, 0)
	var same := true
	for layer: String in ["border_layer", "bedrock_layer"]:
		var la: TileMapLayer = a.get(layer)
		var lb: TileMapLayer = b.get(layer)
		same = same and la.get_used_cells().size() == lb.get_used_cells().size()
		for tile: Vector2i in la.get_used_cells():
			same = same and la.get_cell_atlas_coords(tile) == lb.get_cell_atlas_coords(tile) \
				and la.get_cell_source_id(tile) == lb.get_cell_source_id(tile)
	_check(same, "two builds of level 3 lay identical border tiles")

	# --- The brightness light reveals ring tiles like any wall, never the bedrock past them
	a.light_reach = Upgrades.light_reach(3)
	for x in range(1, a.maze.size.x - 1):
		if not a.is_wall_tile(Vector2i(x, 1)):
			a._reveal_light((Vector2(x, 1) + Vector2(0.5, 0.5)) * a.TILE)
	var ring_seen := 0
	var past_seen := 0
	for tile: Vector2i in a.revealed_walls:
		var d := MazeTiles.border_depth(tile, a.maze.size)
		if d == 1:
			ring_seen += 1
		elif d > 1:
			past_seen += 1
	_check(ring_seen > 5 and past_seen == 0, "the light reveals %d ring tiles and nothing past the ring" % ring_seen)
	a.free()
	b.free()

	# --- The art: what tools/make_theme_art.py draws, exactly (and drawn twice the same)
	_check_generator()

	_result()
	quit(1 if failures else 0)


func _check_border(game: Node2D, what: String, square: PackedVector2Array) -> void:
	var size: Vector2i = game.maze.size
	var depth: int = game.BORDER + game.EDGE_FOG
	var ok_ring := true
	var ok_past := true
	var ok_inside := true
	var covered := true
	var opaque := true
	for y in range(-depth - 1, size.y + depth + 1):
		for x in range(-depth - 1, size.x + depth + 1):
			var tile := Vector2i(x, y)
			var d := MazeTiles.border_depth(tile, size)
			var source: int = game.wall_layer.get_cell_source_id(tile)
			if d > 0:
				# Outside the maze: the ring on the border layer, the bedrock on its own layer, never both
				# (the walls layer stops at the maze's edge).
				var ring_source: int = game.border_layer.get_cell_source_id(tile)
				var deep_source: int = game.bedrock_layer.get_cell_source_id(tile)
				covered = covered and source == -1 and (ring_source == -1 or deep_source == -1)
				source = ring_source if ring_source != -1 else deep_source
			if d == 0:
				# Inside the maze: only the maze's own walls and floors, as before.
				ok_inside = ok_inside and (source == -1 or source == MazeTiles.WALL_SOURCE) == true \
					and game.floor_layer.get_cell_source_id(tile) == MazeTiles.FLOOR_SOURCE
				if game.is_wall_tile(tile) != (source == MazeTiles.WALL_SOURCE):
					ok_inside = false
			elif d <= game.BORDER:
				# The ring: a wall tile whose collision is the same full square as every maze wall.
				var data: TileData = game.border_layer.get_cell_tile_data(tile)
				ok_ring = ok_ring and source == MazeTiles.BORDER_SOURCE and data != null \
					and data.get_collision_polygons_count(0) == 1 and data.get_collision_polygon_points(0, 0) == square \
					and game.is_wall_tile(tile)
			elif d <= depth:
				var data: TileData = game.bedrock_layer.get_cell_tile_data(tile)
				ok_past = ok_past and source == MazeTiles.BORDER_DEEP_SOURCE and data.get_collision_polygons_count(0) == 0
			else:
				covered = covered and source == -1
			if d > 0 and game.floor_layer.get_cell_source_id(tile) != -1:
				opaque = false  # no floor laid under the border (its art is fully opaque)
	_check(ok_inside, what + ": the maze inside is untouched (its own walls and floors only)")
	_check(ok_ring, what + ": every ring tile is a border wall with the full collision square")
	_check(ok_past, what + ": the bedrock past the ring has art and no collision")
	_check(covered, what + ": nothing beyond the %d tiles the camera can see" % depth)
	_check(opaque, what + ": no floor under the border")
	# Physically: the ring blocks, the bedrock past it (never reachable) doesn't.
	var space := game.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(size.x * 0.5 * game.TILE, -0.5 * game.TILE)
	var ring_hit := not space.intersect_point(query).is_empty()
	query.position = Vector2(size.x * 0.5 * game.TILE, -2.5 * game.TILE)
	var past_hit := not space.intersect_point(query).is_empty()
	_check(ring_hit and not past_hit, what + ": a point in the ring hits a wall, one past it doesn't")


## The theme atlases (border included) are exactly what tools/make_theme_art.py draws, twice over.
func _check_generator() -> void:
	for python: String in ["python3", "python"]:
		var out := []
		var code := OS.execute(python, [ProjectSettings.globalize_path("res://tools/make_theme_art.py"), "--check"], out, true)
		if code == -1 or (code != 0 and "theme art check" not in "".join(out)):
			continue  # no such interpreter here
		_check(code == 0, "theme atlases match tools/make_theme_art.py, deterministically (%s)" % "".join(out).strip_edges())
		return
	print("  skip (no python): generator determinism")


func _spawn(level: int, random_seed: int) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	if random_seed:
		game.random_seed = random_seed
	else:
		game.level = level
	root.add_child(game)
	await physics_frame
	await physics_frame
	return game


