extends "res://tests/suite_base.gd"

## The fog/trail bookkeeping (game.gd: bytes, exact disc spans, only cells new to the disc) must
## give byte-for-byte the fog and trail of the original per-cell Image code, which is kept below as
## the reference (ref_*: copied from game.gd as of 194d2cc). Replays glides along the real maze
## routes (sub-pixel jitter, standing still, Brightness changes, landings, wall stains, a broken
## wall, the rainbow trail, the 16-bit time clamp) on levels 1 and 10 and randomizer seed 5, and
## compares both images after every physics step. Also checks the lazy fog upload: the uploaded
## fog always looks the same as the current one (same fade band and refog for every cell).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_fog_bytes.gd

var game: Node
var ref_fog: Image
var ref_trail: Image
var ref_walls := {}
var ref_relit_tick := -1
var ref_relit_cell := Vector2i(-99999, -99999)
var ref_relit_radius := -1.0
## The fog as last uploaded, and the cells relit since then.
var gpu := PackedByteArray()
var touched := Rect2i()
var uploads := 0
var frames := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false

	var same := true
	for v in 256:
		var c := Color8(v, 255 - v, (v * 7) & 255, (v * 13) & 255)
		same = same and Main._rgba8(c) == (v | ((255 - v) << 8) | (((v * 7) & 255) << 16) | (((v * 13) & 255) << 24))
	_check(same, "Color8 values land in the RGBA8 bytes unchanged")

	await _replay(progress, 1, 0, [0.0, 25.0, 12.5], false)
	await _replay(progress, 10, 0, [25.0, 0.0, 25.0], true)
	await _replay(progress, 1, 5, [12.5, 25.0], false)
	# The upgrades v2 BRIGHTNESS breakpoints (Upgrades.light_reach 0 / 8 / 16 / 25 px).
	await _replay(progress, 4, 0, [Upgrades.light_reach(0), Upgrades.light_reach(1), Upgrades.light_reach(2), Upgrades.light_reach(3)], false)
	print("  (%d fog uploads over %d frames)" % [uploads, frames])
	_result()
	quit(0 if failures == 0 else 1)


const Main := preload("res://scripts/game.gd")


func _replay(progress: Node, level: int, random_seed: int, reaches: Array, clamp_time: bool) -> void:
	if random_seed != 0:
		progress.start_random()
		progress.random_seed = random_seed
	else:
		progress.mode = progress.MODE_STORY
		progress.current_level = level
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	ref_fog = game.fog_image
	ref_trail = game.trail_image
	ref_walls = game.revealed_walls.duplicate()
	ref_relit_tick = game._relit_tick
	ref_relit_cell = game._relit_cell
	ref_relit_radius = game._relit_radius
	gpu = game._fog_bytes.duplicate()
	touched = Rect2i()
	var name := ("random seed %d" % random_seed) if random_seed != 0 else ("level %d" % level)

	var pts: Array[Vector2] = []
	var path: Array[Vector2i] = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	for i in path.size() - 1:
		var a := MazeGenerator.cell_center(path[i], 16)
		var b := MazeGenerator.cell_center(path[i + 1], 16)
		var n := int(a.distance_to(b) / 1.23)
		for k in n:
			pts.append(a.lerp(b, float(k) / n) + Vector2(sin(k * 0.7) * 0.4, cos(k * 0.3) * 0.4))
		if i == path.size() / 3:
			for k in 150:
				pts.append(pts[-1])  # standing still 2.5 s
	var steps := 0
	var bad_step := -1
	var last := pts[0]
	var broke := false
	for s in pts.size():
		var p := pts[s]
		game.light_reach = reaches[s * reaches.size() / pts.size()]
		game.rainbow = s > pts.size() * 2 / 3
		if clamp_time and s == pts.size() / 2:
			game.elapsed = 4095.5  # the 16-bit lit time clamps at 4096 s
		game.elapsed += 1.0 / 60.0
		_step(p, last)
		if p.distance_to(last) > 0.0:
			last = p
		if s % 97 == 50:  # a landing splat, and a stain on the nearest wall
			game._paint_goo(p, game.LANDING_RADIUS)
			ref_paint_goo(p, game.LANDING_RADIUS)
			for dir: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				if game.is_wall_tile(Vector2i(((p + dir * 16.0) / 16.0).floor())):
					game._stain_wall(p, -dir)
					ref_stain_wall(p, -dir)
					break
		if not broke and s > pts.size() / 4:
			var tile := _breakable_wall_near(p)
			if tile != Vector2i(-1, -1):
				broke = true
				game._break_wall(tile)
				ref_walls.erase(tile)
				ref_fog.fill_rect(game._tile_cells(tile), Main._fog_color(game.elapsed, game.elapsed, false))
		_frame()
		steps += 1
		if bad_step < 0 and (game._fog_bytes != ref_fog.get_data() or game._trail_bytes != ref_trail.get_data()):
			bad_step = s
	_check(bad_step < 0, "%s: fog and trail bytes identical to the original after each of %d steps (first bad step %d)" % [name, steps, bad_step])
	_check(broke, "%s: a wall was broken mid-run" % name)
	game.queue_free()
	await process_frame


## One physics step as game._physics_process runs it (relight; paint and light reveal when moved).
func _step(p: Vector2, last: Vector2) -> void:
	game._relight(p)
	ref_relight(p)
	var radius: float = game.LIGHT_RADIUS + game.light_reach + 2.0
	var box := Rect2i(game._cell_at(p - Vector2(radius, radius)), Vector2i.ONE * int(radius))
	box.end = game._cell_at(p + Vector2(radius, radius)) + Vector2i.ONE
	touched = box if touched.size == Vector2i.ZERO else touched.merge(box)
	if p.distance_to(last) > 0.0:
		game._paint_goo(p, game.TRAIL_RADIUS)
		ref_paint_goo(p, game.TRAIL_RADIUS)
		if game.light_reach > 0.0:
			game._reveal_light(p)
			ref_reveal_light(p)


## A frame: the upload decision, and every cell the uploaded fog shows must look as the current one.
func _frame() -> void:
	frames += 1
	if game._fog_upload_due():
		uploads += 1
		game._flush_textures()
		gpu = game._fog_bytes.duplicate()
		touched = Rect2i()
		return
	game._flush_textures()
	var w: int = game._cells.x
	var r := touched.intersection(Rect2i(Vector2i.ZERO, game._cells))
	for cy in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			var i := (cy * w + cx) * 4
			var now: int = game._fog_bytes.decode_u32(i)
			var shown := gpu.decode_u32(i)
			if now != shown and (now >> 16 != shown >> 16 or _band(now) != _band(shown)):
				if failures < 20:
					_check(false, "lazy upload: cell %d,%d shows %x but is %x at %.3f s" % [cx, cy, shown, now, game.elapsed])
				return


## Which fade band (and hard-mode refog) the fog shader puts a cell in right now.
func _band(v: int) -> int:
	var age: float = game.elapsed - ((v & 255) * 256 + ((v >> 8) & 255)) / Main.FOG_TICKS
	var band := 0
	for t in Main.FADE_AFTER:
		if age >= t:
			band += 1
	return band


func _breakable_wall_near(p: Vector2) -> Vector2i:
	var t := Vector2i((p / 16.0).floor())
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var tile := t + d
		if game.is_wall_tile(tile) and not game._is_edge(tile):
			return tile
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- the original code (reference)

func ref_paint_goo(pos: Vector2, radius: float) -> void:
	ref_paint_cells(pos, radius, false)
	ref_reveal_walls_near(pos, radius)


func ref_stain_wall(pos: Vector2, wall_normal: Vector2) -> void:
	ref_paint_cells(pos - wall_normal * (Slime.RADIUS + 1.0), Main.STAIN_RADIUS, true)


func ref_paint_cells(pos: Vector2, radius: float, on_walls: bool) -> void:
	var first: Vector2i = game._cell_at(pos - Vector2(radius, radius))
	var last: Vector2i = game._cell_at(pos + Vector2(radius, radius))
	var bounds := Rect2i(Vector2i.ZERO, ref_trail.get_size())
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			var center: Vector2 = game._cell_pos(cell)
			if not bounds.has_point(cell) or center.distance_to(pos) > radius:
				continue
			var tile := Vector2i((center / Main.TILE).floor())
			if game.is_wall_tile(tile) != on_walls:
				continue
			if on_walls:
				ref_reveal_wall(tile)
			elif ref_trail.get_pixelv(cell).a > 0.0:
				continue
			ref_trail.set_pixelv(cell, game._goo_color(posmod(hash(cell), 5) == 0))
			ref_fog.set_pixelv(cell, Main._fog_color(game.elapsed, game.elapsed, false))


func ref_relight(pos: Vector2) -> void:
	var radius: float = Main.LIGHT_RADIUS + game.light_reach
	var tick := int(game.elapsed * Main.FOG_TICKS)
	var slime_cell: Vector2i = game._cell_at(pos)
	if tick == ref_relit_tick and slime_cell == ref_relit_cell and radius == ref_relit_radius:
		return
	ref_relit_tick = tick
	ref_relit_cell = slime_cell
	ref_relit_radius = radius
	var r := Vector2(radius, radius)
	var first: Vector2i = game._cell_at(pos - r).max(Vector2i.ZERO)
	var last: Vector2i = game._cell_at(pos + r).min(ref_fog.get_size() - Vector2i.ONE)
	var radius_sq := radius * radius
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			if game._cell_pos(cell).distance_squared_to(pos) > radius_sq:
				continue
			var packed := Main._fog_packed(ref_fog.get_pixelv(cell))
			if packed > 0 and Main._fog_lit_ticks(ref_fog.get_pixelv(cell)) < tick:
				ref_fog.set_pixelv(cell, Main._fog_color_ticks(tick, (packed >> 1) - 1, packed % 2 == 1))


func ref_reveal_light(pos: Vector2) -> void:
	var radius: float = Main.TRAIL_RADIUS + game.light_reach
	var first: Vector2i = game._cell_at(pos - Vector2(radius, radius)).max(Vector2i.ZERO)
	var last: Vector2i = game._cell_at(pos + Vector2(radius, radius)).min(ref_fog.get_size() - Vector2i.ONE)
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			var center: Vector2 = game._cell_pos(cell)
			if center.distance_to(pos) > radius or game.is_wall_tile(Vector2i((center / Main.TILE).floor())):
				continue
			if Main._fog_packed(ref_fog.get_pixelv(cell)) == 0:
				ref_fog.set_pixelv(cell, Main._fog_color(game.elapsed, game.elapsed, false))
	ref_reveal_walls_near(pos, radius)


func ref_reveal_walls_near(pos: Vector2, radius: float) -> void:
	var reach: float = radius + Main.WALL_REVEAL_REACH
	var first := Vector2i(((pos - Vector2(reach, reach)) / Main.TILE).floor())
	var last := Vector2i(((pos + Vector2(reach, reach)) / Main.TILE).floor())
	var border: int = Main.BORDER
	for ty in range(first.y, last.y + 1):
		for tx in range(first.x, last.x + 1):
			var tile := Vector2i(tx, ty)
			if not game.is_wall_tile(tile) or tx < -border or ty < -border or tx >= game.maze.size.x + border or ty >= game.maze.size.y + border:
				continue
			var rect := Rect2(Vector2(tile * Main.TILE), Vector2(Main.TILE, Main.TILE))
			if pos.clamp(rect.position, rect.end).distance_to(pos) <= reach:
				ref_reveal_wall(tile)


func ref_reveal_wall(tile: Vector2i) -> void:
	if ref_walls.has(tile):
		return
	ref_walls[tile] = true
	ref_fog.fill_rect(game._tile_cells(tile), Main._fog_color(game.elapsed, game.elapsed, true))


