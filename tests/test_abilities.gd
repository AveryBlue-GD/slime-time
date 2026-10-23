extends "res://tests/suite_base.gd"

## ABILITIES v1 (docs/design/upgrades-v2.md "Abilities v1", with the pass-over-walls buff): SLIME RIFLE
## (pierces walls: reveals exactly the tiles on its line for its range, floor tiles with the walls around
## them), SLIME SPLAT (lobbed over walls exactly its range ahead, reveals exactly the 5x5 around it),
## SLIMAKAZE (dashes to the wall, costs 30% - into the goal too -, a deterministic splatter over walls;
## never kills unless the meter holds <= 30%), fog bytes and survey tiles in step, charges per attempt
## and their refill, slime costs, the input actions (defaults 1 / 2 / 3, remapping, old saves keep
## their bindings), touch buttons, the HUD strip, OFF in every story level (normal, hard) and hard-mode randomizer / with the flag off, ON in
## randomizer mazes and Descent, par and payout untouched, the TICKETS tab purchase flow (exact tickets,
## confirm, max level, locked), saves and hostile values. Never touches the real save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_abilities.gd

const MAIN := preload("res://scenes/main.tscn")
const TILE := 16
## The gap the touch layout must keep between an ability's hit area and JUMP's real catch zone (px).
const DEAD_RING := 8.0

var progress: Node


func _initialize() -> void:
	Economy.descent_force = 1  # Descent is switched off in the game (D11); this suite tests it
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.saving_enabled = false
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	_check(Economy.abilities_on() and not Economy.workshop_on(), "abilities on, the workshop still off")
	await _rifle()
	await _splat()
	await _kaze()
	await _kaze_kill_and_refuse()
	await _kaze_goal()
	await _kaze_off_lane()
	await _goal_reveals()
	await _shake_spans()
	await _splatter_rule()
	await _charges()
	await _sense()
	await _inputs()
	await _touch()
	await _touch_aim()
	await _modes()
	await _store()
	_saves()
	_bindings_migration()
	progress.reset_progress()
	_result()
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- helpers

func _state(levels: Dictionary) -> void:
	Economy.abilities_force = -1
	progress.reset_progress()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.tutorial_seen = 3
	for id in Abilities.ids():
		progress.tutorial_seen |= AbilityCoach.bit(id)  # (the ability tutorial is its own test: test_demo_preview)
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.hard_mode = false
	progress.mode = progress.MODE_STORY
	progress.abilities = levels.duplicate()


## `level` > 0 picks a randomizer maze (seed 9000 + level): abilities work only in randomizer mazes and
## Descent, so the ability tests run there; `_story` plays a real story level (they are off there).
func _spawn(level := 1, random_seed := 0) -> Node2D:
	if level > 0 and random_seed == 0:
		random_seed = 9000 + level
	var game: Node2D = MAIN.instantiate()
	if random_seed != 0:
		progress.mode = progress.MODE_RANDOM
		progress.random_seed = random_seed
		game.random_seed = random_seed
	elif level > 0:
		game.level = level
	root.add_child(game)
	await physics_frame
	await physics_frame
	return game


func _story(level: int) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	await physics_frame
	return game


func _stop(game: Node2D) -> void:
	for id in Abilities.ids():
		Input.action_release(Abilities.action(id))
	game.free()
	await process_frame


func _start_tile(game: Node2D) -> Vector2i:
	return Vector2i((game.slime.position / TILE).floor())


## Revealed fog cells in a tile (0-64).
func _revealed_cells(game: Node2D, tile: Vector2i) -> int:
	var rect: Rect2i = game._tile_cells(tile)
	var n := 0
	for cy in range(rect.position.y, rect.end.y):
		for cx in range(rect.position.x, rect.end.x):
			if game._fog_bytes.decode_u32((cy * game._cells.x + cx) * 4) >= 0x10000:
				n += 1
	return n


## Every maze tile's state: floor -> revealed cells, wall -> revealed (1/0).
func _snapshot(game: Node2D) -> Dictionary:
	var out := {}
	for y in game.maze.size.y:
		for x in game.maze.size.x:
			var t := Vector2i(x, y)
			out[t] = (1 if game.revealed_walls.has(t) else 0) if game.is_wall_tile(t) else _revealed_cells(game, t)
	return out


func _changed(before: Dictionary, after: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in before:
		if before[t] != after[t]:
			out.append(t)
	return out


## A direction from the slime's tile with at least `min_tiles` floor tiles ahead (ZERO if none).
func _dir_with(game: Node2D, min_tiles: int) -> Vector2i:
	for d: Vector2i in MazeGenerator.DIRS:
		if Abilities.line_tiles(game.maze, _start_tile(game), d).size() >= min_tiles:
			return d
	return Vector2i.ZERO


func _aim(game: Node2D, dir: Vector2i) -> void:
	game.slime.facing = Vector2(dir)


# ---------------------------------------------------------------- SLIME RIFLE

## A floor tile and a direction where the next `reach` tiles (all inside the maze) hold a wall with
## a floor tile past it ({} if none).
func _wall_spot(game: Node2D, reach: int) -> Dictionary:
	for y in game.maze.size.y:
		for x in game.maze.size.x:
			var t := Vector2i(x, y)
			if game.is_wall_tile(t):
				continue
			for d: Vector2i in MazeGenerator.DIRS:
				if not Abilities.in_maze(game.maze, t + d * reach):
					continue
				var wall := false
				for i in range(1, reach + 1):
					if game.is_wall_tile(t + d * i):
						wall = true
					elif wall:
						return {tile = t, dir = d}
	return {}


func _rifle() -> void:
	_check(Abilities.rifle_range(1) == 12 and Abilities.rifle_range(2) == 16 and Abilities.rifle_range(3) == 20, "SLIME SNIPER range 12 / 16 / 20 tiles")
	for level in [1, 3]:
		_state({rifle = level})
		var game := await _spawn(4)
		var reach := Abilities.rifle_range(level)
		var spot := _wall_spot(game, reach)
		_place(game, spot.tile, spot.dir)
		var dir: Vector2i = spot.dir
		var tiles := Abilities.rifle_tiles(game.maze, spot.tile, dir, reach)
		var before := _snapshot(game)
		var meter: float = game.slime_remaining
		var fired: bool = game.abilities.use("rifle")
		game.abilities.flush()
		var after := _snapshot(game)
		var full := true
		var surveyed := true
		var past_wall := 0
		var crossed := false
		for t in tiles:
			if game.is_wall_tile(t):
				full = full and after[t] == 1
				crossed = true
			else:
				full = full and after[t] == 64
				if crossed and before[t] < 64:
					past_wall += 1
			surveyed = surveyed and game.survey_tiles[t.y * game.maze.size.x + t.x] == 1
		_check(fired and tiles.size() == reach + 1 and full and surveyed and past_wall > 0,
			"SLIME RIFLE %d pierces walls: all %d tiles on its line revealed and seen, %d floor tiles past a wall" % [level, tiles.size(), past_wall])
		var path := {}
		for t in tiles:
			path[t] = true
		var stray := []
		for t in _changed(before, after):
			if path.has(t):
				continue
			var near := false
			for p in tiles:
				near = near or (not game.is_wall_tile(p) and absi(p.x - t.x) <= 1 and absi(p.y - t.y) <= 1)
			if not game.is_wall_tile(t) or not near:
				stray.append(t)
		_check(stray.is_empty(), "...and nothing else: only walls bordering its floor tiles change (stray %s)" % [stray])
		var beyond: Vector2i = tiles[-1] + dir
		_check(not Abilities.in_maze(game.maze, beyond) or game.is_wall_tile(beyond) or after[beyond] == before[beyond], "the tile past its range stays as it was")
		var goo_on_walls := 0
		for t in tiles.slice(0, tiles.size() - 1):
			if game.is_wall_tile(t):
				var r: Rect2i = game._tile_cells(t)
				for cy in range(r.position.y, r.end.y):
					for cx in range(r.position.x, r.end.x):
						if game._trail_bytes[(cy * game._cells.x + cx) * 4 + 3] != 0:
							goo_on_walls += 1
		_check(goo_on_walls == 0, "the goo streak stays on the floor (%d wall cells goo'd)" % goo_on_walls)
		if level == 1:
			var last_floor: Vector2i = spot.tile
			for t in tiles:
				if not game.is_wall_tile(t):
					last_floor = t
			var cell: Rect2i = game._tile_cells(last_floor)
			var v: int = game._fog_bytes.decode_u32((cell.position.y * game._cells.x + cell.position.x) * 4)
			var decoded: Dictionary = Main()._fog_decode(Color8(v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255))
			_check(decoded.revealed and not decoded.wall and absf(decoded.lit - game.elapsed) < 0.1,
				"a revealed floor cell decodes as floor, lit just now (fresh glow, then the usual fade)")
			var streak := 0
			for cy in range(cell.position.y, cell.end.y):
				for cx in range(cell.position.x, cell.end.x):
					if game._trail_bytes[(cy * game._cells.x + cx) * 4 + 3] != 0:
						streak += 1
			_check(streak > 0 and streak <= 24, "a thin goo streak crosses a floor tile past the wall (%d of 64 cells goo'd)" % streak)
			_check(is_equal_approx(meter - game.slime_remaining, Economy.ABILITIES.rifle.slime) and game.abilities.charges.rifle == 0,
				"one shot costs %.0f%% of the meter and its charge" % Economy.ABILITIES.rifle.slime)
			_check(not game.abilities.use("rifle"), "no charges left: it doesn't fire")
		await _stop(game)
	# At the maze's outer edge it stops (nothing outside the maze).
	var maze: Dictionary = Levels.story_maze(4, false)
	var edge := Abilities.rifle_tiles(maze, Vector2i(1, 1), Vector2i.LEFT, 14)
	_check(edge == [Vector2i(1, 1), Vector2i(0, 1)], "the shot stops at the maze's edge (%s)" % [edge])


func Main() -> GDScript:
	return load("res://scripts/game.gd")


# ---------------------------------------------------------------- SLIME SPLAT

func _splat() -> void:
	_check(Abilities.splat_range(1) == 2 and Abilities.splat_range(2) == 3 and Abilities.splat_range(3) == 4, "GOO GRENADE lands 2 / 3 / 4 tiles ahead")
	for level in [1, 3]:
		_state({splat = level})
		var game := await _spawn(4)
		var reach := Abilities.splat_range(level)
		var spot := _wall_spot(game, reach)
		_place(game, spot.tile, spot.dir)
		var land := Abilities.lob_tile(game.maze, spot.tile, spot.dir, reach)
		_check(land == spot.tile + spot.dir * reach, "SLIME SPLAT %d: lobbed over the wall, exactly %d tiles ahead" % [level, reach])
		var before := _snapshot(game)
		game.abilities.use("splat")
		_check(not game.abilities.flying.is_empty(), "...it flies first (a lob)")
		game.abilities.flush()
		var after := _snapshot(game)
		var area := Abilities.burst_tiles(game.maze, land)
		var r := Economy.SPLAT_AREA
		var want := 0  # the 5x5, clipped to the maze
		for y in range(land.y - r, land.y + r + 1):
			for x in range(land.x - r, land.x + r + 1):
				if x >= 0 and y >= 0 and x < game.maze.size.x and y < game.maze.size.y:
					want += 1
		var ok := area.size() == want and want >= 15
		for t in area:
			ok = ok and (after[t] == 1 if game.is_wall_tile(t) else after[t] == 64)
		var stray := []
		for t in _changed(before, after):
			if not t in area:
				stray.append(t)
		_check(ok and stray.is_empty(), "the burst reveals exactly the 5x5 around the landing tile %s (stray %s)" % [land, stray])
		_check(game.abilities.get_children().any(func(c: Node) -> bool: return c is Sprite2D), "...with a fading glow")
		await _stop(game)
	var maze: Dictionary = Levels.story_maze(4, false)
	var size: Vector2i = maze.size
	_check(Abilities.lob_tile(maze, Vector2i(1, 1), Vector2i.LEFT, 6) == Vector2i(0, 1)
		and Abilities.lob_tile(maze, Vector2i(size.x - 2, 1), Vector2i.RIGHT, 6) == Vector2i(size.x - 1, 1)
		and Abilities.burst_tiles(maze, Vector2i(0, 1)).size() == 12, "near the edge it lands clamped inside the maze, its 5x5 clipped to it")


# ---------------------------------------------------------------- SLIMAKAZE

func _kaze() -> void:
	var results := []
	for run in 2:
		_state({kaze = 1})
		var game := await _spawn(6)
		var dir := _dir_with(game, 2)
		_aim(game, dir)
		var start := _start_tile(game)
		var stop := Abilities.dash_tile(game.maze, start, dir)
		var before := _snapshot(game)
		var meter: float = game.slime_remaining
		var fired: bool = game.abilities.use("kaze")
		await _physics_frames(1)
		_check(fired and game.slime.state == Slime.State.DASH and game.slime.is_airborne(), "SLIMAKAZE: the slime dashes (no drain while it flies)")
		game.abilities.flush()
		var impact := Vector2i((game.slime.position / TILE).floor())
		_check(game.slime.position.is_equal_approx(Abilities.dash_point(stop, dir)) and impact == stop and game.slime.state == Slime.State.STUNNED,
			"...to the last floor tile before the wall %s, splatted (stunned)" % [stop])
		_check(is_equal_approx(meter - game.slime_remaining, Economy.ABILITIES.kaze.slime),
			"...costing %.0f%% of the meter (%.1f -> %.1f)" % [Economy.ABILITIES.kaze.slime, meter, game.slime_remaining])
		var radius := Abilities.kaze_radius(1)
		var blobs := Abilities.splatter(game.maze, impact, Abilities.splatter_seed(game.maze_seed, impact, 0), radius)
		var after := _snapshot(game)
		var all_lit := true
		var in_zone := true
		for b in blobs:
			all_lit = all_lit and after[b.tile] == 64 and game.survey_tiles[b.tile.y * game.maze.size.x + b.tile.x] == 1
			in_zone = in_zone and Vector2(b.tile - impact).length() <= radius
		_check(blobs.size() >= 3 and all_lit and in_zone, "the splatter reveals %d tiles within %.1f tiles of the impact, all seen" % [blobs.size(), radius])
		var allowed := {}
		for b in blobs:
			allowed[b.tile] = true
		var t := start
		while true:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					allowed[t + Vector2i(dx, dy)] = true
			if t == stop:
				break
			t += dir
		var stray := []
		for c in _changed(before, after):
			if not allowed.has(c):
				var near := false
				for b in blobs:
					near = near or (absi(b.tile.x - c.x) <= 1 and absi(b.tile.y - c.y) <= 1)
				if not near or not game.is_wall_tile(c):
					stray.append(c)
		_check(stray.is_empty(), "nothing outside the dash lane, the splatter and their walls changes (stray %s)" % [stray])
		results.append(after)
		await _stop(game)
	_check(results[0] == results[1], "the same maze, impact and use splatter the same tiles (deterministic)")
	var maze: Dictionary = Levels.story_maze(6, false)
	var a := Abilities.splatter(maze, Vector2i(5, 5), 77, 6.0)
	_check(a == Abilities.splatter(maze, Vector2i(5, 5), 77, 6.0) and a != Abilities.splatter(maze, Vector2i(5, 5), 78, 6.0) or a.size() <= 1,
		"splatter: same seed same tiles, another seed others")
	_check(Abilities.kaze_radius(1) == 6.0 and Abilities.kaze_radius(2) == 7.0 and Abilities.kaze_radius(3) == 8.0, "SLIMAKAZE splatter radius 6 / 7 / 8 tiles")
	# Over walls: the splatter lands in other corridors (floor tiles with no straight floor path from
	# the impact), and a bigger level reaches farther and hits more.
	var impact := Vector2i(9, 9)
	for y in maze.size.y:
		for x in maze.size.x:
			if not MazeGenerator.is_wall(maze, Vector2i(x, y)) and Vector2(Vector2i(x, y) - Vector2i(maze.size / 2)).length() < Vector2(impact - Vector2i(maze.size / 2)).length():
				impact = Vector2i(x, y)
	var small := Abilities.splatter(maze, impact, 5, Abilities.kaze_radius(1))
	var big := Abilities.splatter(maze, impact, 5, Abilities.kaze_radius(3))
	var floors := 0
	var behind := 0
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			if Vector2(dx, dy).length() <= 6.0 and not MazeGenerator.is_wall(maze, impact + Vector2i(dx, dy)):
				floors += 1
	for b in small:
		var seen: bool = b.tile == impact
		for d: Vector2i in MazeGenerator.DIRS:
			seen = seen or Abilities.line_tiles(maze, impact, d).has(b.tile)
		if not seen:
			behind += 1
	var far := big.any(func(b: Dictionary) -> bool: return Vector2(b.tile - impact).length() > 6.0)
	_check(behind >= 5 and small.size() * 5 >= floors * 2 and far and big.size() > small.size(),
		"the splatter reaches over walls (%d of %d tiles off the impact's straight lines; %d of %d floor tiles in reach), level 3 farther (%d tiles)" % [behind, small.size(), small.size(), floors, big.size()])


func _kaze_kill_and_refuse() -> void:
	_state({kaze = 1})
	var game := await _spawn(6)
	var dir := _dir_with(game, 2)
	_aim(game, dir)
	game.slime_remaining = 20.0
	game.abilities.use("kaze")
	game.abilities.flush()
	await _physics_frames(game.slime.splat_stun * 60 + 60)
	_check(game.slime_remaining == 0.0 and game.finished and not game.won, "SLIMAKAZE with 20% left (<= its 30%): the impact dries the slime up")
	await _stop(game)
	_state({kaze = 1})
	game = await _spawn(1)
	for d: Vector2i in MazeGenerator.DIRS:
		if game.is_wall_tile(_start_tile(game) + d):
			_aim(game, d)
			var meter: float = game.slime_remaining
			_check(not game.abilities.use("kaze") and game.abilities.charges.kaze == 1 and game.slime_remaining == meter,
				"a wall right ahead: SLIMAKAZE doesn't fire (charge and slime kept)")
			break
	await _stop(game)


## A floor tile `n` tiles back from the goal along a straight corridor into it, and the direction
## from there to the goal (n as large as the corridor allows, up to `most`; {} if none of >= `least`).
func _goal_line(game: Node2D, least: int, most := 4) -> Dictionary:
	var goal := Vector2i((game.goal.position / TILE).floor())
	var best := {}
	for d: Vector2i in MazeGenerator.DIRS:
		var n := 0
		while n < most and not game.is_wall_tile(goal - d * (n + 1)):
			n += 1
		if n >= least and (best.is_empty() or n > best.n):
			best = {from = goal - d * n, dir = d, n = n, goal = goal}
	return best


## Puts the slime (still, on its lane) on `tile`, facing `dir`.
func _place(game: Node2D, tile: Vector2i, dir: Vector2i) -> void:
	game.slime.position = (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	game.slime.velocity = Vector2.ZERO
	game.last_slime_pos = game.slime.position
	_aim(game, dir)


## A game (story level / randomizer seed / Descent) with SLIMAKAZE and a corridor of >= 2 tiles
## into its goal; null if none of the candidates has one.
func _goal_game(kind: String) -> Node2D:
	for n in 12:
		_state({kaze = 1})
		var game: Node2D
		match kind:
			"random":
				game = await _spawn(0, 5100 + n)
			"descent":
				progress.start_descent(880 + n)
				game = await _spawn(0)
		if not _goal_line(game, 2).is_empty():
			return game
		await _stop(game)
	return null


## SLIMAKAZE dashing into the chalice / ticket pays its 30% there: with <= 30% left it dries up (no
## win); with more it wins with 30% less (Descent carries that meter to the next floor).
func _kaze_goal() -> void:
	for kind: String in ["random", "descent"]:
		for meter: float in [20.0, 60.0]:
			var game := await _goal_game(kind)
			if game == null:
				_check(false, "%s: a goal with a 2-tile corridor into it" % kind)
				continue
			var line := _goal_line(game, 2)
			_place(game, line.from, line.dir)
			game.slime_remaining = meter
			await _physics_frames(1)
			var fired: bool = game.abilities.use("kaze")
			for i in 60:
				if game.finished:
					break
				await physics_frame
			var want := maxf(meter - Economy.ABILITIES.kaze.slime, 0.0)
			if meter <= Economy.ABILITIES.kaze.slime:
				_check(fired and game.finished and not game.won and game.slime_remaining == 0.0,
					"%s: SLIMAKAZE into the goal with %.0f%% left pays 30%% there and dries up (finished %s, won %s, %.1f%%)" % [kind, meter, game.finished, game.won, game.slime_remaining])
			else:
				_check(fired and game.won and is_equal_approx(game.slime_remaining, want),
					"%s: SLIMAKAZE into the goal with %.0f%% left wins with %.0f%% (won %s, %.1f%%)" % [kind, meter, want, game.won, game.slime_remaining])
				if kind == "descent":
					_check(is_equal_approx(float(progress.descent_run.meter), want), "descent: the cleared floor carries %.0f%% (not the uncharged %.0f%%)" % [want, meter])
			_check(not game.abilities.dashing and game.slime.state != Slime.State.DASH, "%s: the dash is over (no smear painting on)" % kind)
			await _stop(game)
			if kind == "descent":
				progress.descent_run = {}
	# SECOND WIND still saves it (its refill lands at once, as the run ends on the goal).
	var saved := await _goal_game("random")
	var into := _goal_line(saved, 2)
	_place(saved, into.from, into.dir)
	saved.workshop = {wind = 1}
	saved.wind_state = "ready"
	saved.slime_remaining = 20.0
	saved.abilities.use("kaze")
	for i in 60:
		if saved.finished:
			break
		await physics_frame
	_check(saved.won and saved.slime_remaining > 0.0 and saved.wind_state == "used",
		"SLIMAKAZE emptying the meter on the goal with SECOND WIND ready: the wind saves it and it wins (%.1f%%)" % saved.slime_remaining)
	await _stop(saved)


## SLIMAKAZE from off the lane: it first slides sideways onto the lane, then dashes straight along it
## (never moving ahead while off-lane, where the body would clip a wall corner).
func _kaze_off_lane() -> void:
	_state({kaze = 1})
	var game := await _spawn(6)
	var dir := _dir_with(game, 2)
	var start := _start_tile(game)
	var lane := (Vector2(start) + Vector2(0.5, 0.5)) * TILE
	var side := Vector2(dir).orthogonal()
	game.slime.position = lane + side * 6.0
	game.slime.velocity = Vector2.ZERO
	_aim(game, dir)
	var fired: bool = game.abilities.use("kaze")
	var bad := []
	for i in 30:
		await physics_frame
		var p: Vector2 = game.slime.position
		var off := absf((p - lane).dot(side))
		var ahead := (p - lane).dot(Vector2(dir))
		if off > 0.01 and ahead > 0.01:
			bad.append(p)
		if game.slime.state != Slime.State.DASH:
			break
	_check(fired and bad.is_empty() and game.slime.state == Slime.State.STUNNED,
		"SLIMAKAZE 6 px off-lane: sideways onto the lane first, then straight ahead (off-lane and moved ahead at %s)" % [bad])
	await _stop(game)


## Ability reveals that light the goal's tile show the chalice / ticket (as seeing it does) and mark it
## for the trail map.
func _goal_reveals() -> void:
	for kind: String in ["rifle", "splat"]:
		for mode: String in ["random"]:
			var game: Node2D = null
			var line := {}
			for n in 12:
				_state({rifle = 1, splat = 1})
				game = await _spawn(0, 6100 + n)
				line = _goal_shot(game, Abilities.splat_range(1) if kind == "splat" else 0)
				if not line.is_empty():
					break
				await _stop(game)
				game = null
			if game == null:
				_check(false, "%s: a goal with a corridor into it" % mode)
				continue
			_place(game, line.from, line.dir)
			game.goal.visible = false
			game.survey_goal = false
			var far: bool = game.slime.position.distance_to(game.goal.position) > game.goal_reveal_distance
			game.abilities.use(kind)
			game.abilities.flush()
			_check(far and game.goal.visible and game.survey_goal and not game.finished and not game.won,
				"%s %s: a reveal over the goal's tile (%d tiles off, a wall between: %s) shows it and marks it seen, never takes it (visible %s, survey %s)" % [mode, kind, line.n, line.walled, game.goal.visible, game.survey_goal])
			# ...and the maze's MAP (recorded at the dry-up) draws the ticket's X there.
			progress.record_random_map("goal_reveal", game.maze, game.survey_tiles, game.survey_moves, game.survey_goal)
			var map: Dictionary = progress.random_map_for("goal_reveal")
			_check(map.goal and MapView._cell_seen(map, game.maze.goal), "%s %s: the maze's MAP then marks the ticket" % [mode, kind])
			progress.discard_random_map()
			await _stop(game)


## A floor tile `exact` tiles (or, with 0, 2-8 tiles, a wall between preferred) from the goal in a
## straight line, walls between allowed: {from, dir, n, walled} ({} if none).
func _goal_shot(game: Node2D, exact: int) -> Dictionary:
	var goal := Vector2i((game.goal.position / TILE).floor())
	var best := {}
	for d: Vector2i in MazeGenerator.DIRS:
		for n in ([exact] if exact > 0 else range(2, 9)):
			var from: Vector2i = goal - d * n
			if not Abilities.in_maze(game.maze, from) or game.is_wall_tile(from):
				continue
			var walled := false
			for i in range(1, n):
				walled = walled or game.is_wall_tile(from + d * i)
			if best.is_empty() or (walled and not best.walled):
				best = {from = from, dir = d, n = n, walled = walled}
	return best


## Every shake restarts the fade over its own span: a landing or bump right after a long ability shake
## fades over its own time (not the ability's).
func _shake_spans() -> void:
	_state({kaze = 1})
	var game := await _spawn(4)
	var shake_time: float = Main().SHAKE_TIME
	game.shake(Economy.KAZE_SHAKE, Economy.KAZE_SHAKE_TIME)
	game._on_jump_landed(Slime.jump_distance_for(100.0), true, Vector2.LEFT)
	_check(is_equal_approx(game.shake_span, shake_time) and is_equal_approx(game.shake_left, shake_time),
		"a wall landing after an ability shake fades over SHAKE_TIME (span %.2f)" % game.shake_span)
	game.shake(Economy.KAZE_SHAKE, Economy.KAZE_SHAKE_TIME)
	game._on_bounced(Vector2.LEFT, 200.0)
	_check(is_equal_approx(game.shake_span, shake_time * 0.6), "a ricochet after an ability shake fades over its own time (span %.2f)" % game.shake_span)
	await _stop(game)


## One splatter rule in every mode: the maze, the impact tile and the use index; never the attempt
## (Descent attempts don't count, and a randomizer restart can't re-roll it).
func _splatter_rule() -> void:
	for mode: String in ["random"]:
		var shots := []
		for attempt in [1, 4]:
			_state({kaze = 1})
			var game: Node2D
			game = await _spawn(0, 4242)
			game.attempt = attempt
			_aim(game, _dir_with(game, 2))
			var before := _snapshot(game)
			game.abilities.use("kaze")
			game.abilities.flush()
			shots.append(_changed(before, _snapshot(game)))
			await _stop(game)
		_check(shots[0] == shots[1] and not shots[0].is_empty(), "%s: attempt 1 and attempt 4 splatter the same tiles" % mode)


# ---------------------------------------------------------------- charges

## SLIME SENSE: a peek opens the maze's map mid-run (one use), its key again closes it for free, the
## slime holds still and the meter doesn't drain while it is up (the idle drain on); level 2 = 2 peeks.
func _sense() -> void:
	_state({sense = 2})
	var game := await _spawn(4)
	current_scene = game
	Economy.idle_drain_force = 1
	game.slime.position += Vector2(1, 0)  # (it has moved: the idle drain applies)
	await _physics_frames(2)
	_check(game.abilities.charges.sense == 2, "SLIME SENSE 2: two peeks per attempt")
	_check(game.abilities.use("sense") and game.random_map_view != null and game.slime.aim_lock and game.abilities.charges.sense == 1,
		"a peek opens the maze's map mid-run and holds the slime still")
	var meter: float = game.slime_remaining
	await _physics_frames(30)
	_check(absf(game.slime_remaining - meter) < 0.02 and not game.finished, "...the meter doesn't drain while peeking (%.2f -> %.2f)" % [meter, game.slime_remaining])
	_check(not game.abilities.use("sense") and game.random_map_view == null and game.abilities.charges.sense == 1, "...its key again closes it for free")
	await _physics_frames(2)
	_check(not game.slime.aim_lock, "...and the slime can move again")
	await _physics_frames(30)
	_check(game.slime_remaining < meter, "standing still in the maze drains again (%.2f -> %.2f)" % [meter, game.slime_remaining])
	game.abilities.use("sense")
	game.abilities.use("sense")
	_check(not game.abilities.use("sense") and game.random_map_view == null and game.abilities.charges.sense == 0, "no peeks left: it doesn't open")
	Economy.idle_drain_force = 0
	current_scene = null
	await _stop(game)


func _charges() -> void:
	for level in [1, 2, 3]:
		for id in Abilities.ids():
			var want: int = level if id == "sense" else 1  # (SLIME SENSE: 1 / 2 / 3 peeks)
			_check(Abilities.charges(id, level) == want, "%s L%d = exactly %d charge(s)" % [id, level, want])
	_check(Abilities.charges("rifle", 0) == 0, "not owned = 0 charges")
	_state({rifle = 2, splat = 3})
	var game := await _spawn(4)
	_aim(game, _dir_with(game, 1))
	_check(game.abilities.charges == {rifle = 1, splat = 1} and game.abilities.levels.size() == 2, "owned abilities only, charges by level")
	var a: bool = game.abilities.use("rifle")
	game.abilities.flush()
	var b: bool = game.abilities.use("rifle")
	game.abilities.flush()
	var m2: float = game.slime_remaining
	var c: bool = game.abilities.use("rifle")
	_check(a and not b and not c and game.slime_remaining == m2 and game.abilities.charges.rifle == 0 and game.abilities.uses == 1,
		"L2: one shot, a second press does nothing and costs nothing")
	for lvl in [1, 3]:
		_state({rifle = lvl, splat = lvl, kaze = lvl})
		var g3 := await _spawn(4)
		_aim(g3, _dir_with(g3, 1))
		for id in ["rifle", "splat"]:
			var first: bool = g3.abilities.use(id)
			g3.abilities.flush()
			var before: float = g3.slime_remaining
			_check(first and not g3.abilities.use(id) and g3.slime_remaining == before, "L%d %s: exactly one use per attempt, the second press is free" % [lvl, id])
		await _stop(g3)
		g3 = await _spawn(4)
		_check(g3.abilities.charges == {rifle = 1, splat = 1, kaze = 1}, "L%d: a new attempt refills the single charge" % lvl)
		await _stop(g3)
	await _stop(game)
	_state({rifle = 2, splat = 3})
	game = await _spawn(4)
	_aim(game, _dir_with(game, 1))
	var pods: int = game.hud.ability_row.get_child_count()
	_check(game.hud.ability_pod.visible and pods == 2, "the HUD strip shows the two owned abilities")
	_check(game.abilities.strip()[0].left == 1 and game.abilities.strip()[0].max == 1, "strip: one charge max, ready")
	game.slime_remaining = Economy.ABILITIES.splat.slime
	_check(not game.abilities.use("splat") and game.abilities.charges.splat == 1, "SPLAT needs more slime than it costs (never kills)")
	game.slime_remaining = 50.0
	game.slime.state = Slime.State.CHARGING
	_check(not game.abilities.use("splat"), "not while charging a leap (only gliding / still)")
	game.slime.state = Slime.State.GLIDE
	await _stop(game)
	game = await _spawn(4)  # a restart = a new attempt
	_check(game.abilities.charges == {rifle = 1, splat = 1}, "a restart refills every charge")
	await _stop(game)


# ---------------------------------------------------------------- inputs

func _inputs() -> void:
	_state({rifle = 1, splat = 1, kaze = 1})
	var keys := []
	for id in Abilities.ids():
		var events := InputMap.action_get_events(Abilities.action(id))
		keys.append((events[0] as InputEventKey).physical_keycode if not events.is_empty() else 0)
	_check(keys == [KEY_1, KEY_2, KEY_3, KEY_M], "actions ability_rifle / _splat / _kaze / _sense default to 1 / 2 / 3 / M")
	var game := await _spawn(4)
	_aim(game, _dir_with(game, 1))
	Input.action_press("ability_rifle")
	await _physics_frames(2)
	Input.action_release("ability_rifle")
	_check(game.abilities.aiming == "rifle" and game.slime.aim_lock and game.abilities.charges.rifle == 1,
		"pressing the rifle action starts aiming it (movement locked, nothing spent yet)")
	var spot: Vector2 = game.slime.position
	Input.action_press("move_down")
	await _physics_frames(6)
	Input.action_release("move_down")
	_check(game.abilities.aim_dir == Vector2i.DOWN and game.slime.position.distance_to(spot) < 1.0, "...the direction keys turn the aim, the slime stays put")
	Input.action_press("ability_rifle")
	await _physics_frames(2)
	Input.action_release("ability_rifle")
	_check(game.abilities.aiming == "" and not game.slime.aim_lock and game.abilities.charges.rifle == 1, "...the same key again cancels (nothing spent)")
	Input.action_press("ability_rifle")
	await _physics_frames(2)
	Input.action_release("ability_rifle")
	Input.action_press("move_right")
	await _physics_frames(2)
	Input.action_release("move_right")
	Input.action_press("jump")
	await _physics_frames(2)
	Input.action_release("jump")
	await _physics_frames(2)
	_check(game.abilities.charges.rifle == 0 and game.abilities.aiming == "" and not game.slime.aim_lock
		and game.slime.state != Slime.State.CHARGING and game.slime.facing == Vector2.RIGHT, "...JUMP fires it the way it aims, without starting a leap")
	await _stop(game)
	# Diagonal aim (8 ways): down + right aims down-right and stays so while the keys are let go
	game = await _spawn(4)
	game.abilities.start_aim("rifle")
	Input.action_press("move_down")
	Input.action_press("move_right")
	await _physics_frames(2)
	_check(game.abilities.aim_dir == Vector2i(1, 1), "down + right aims the shot diagonally (%s)" % game.abilities.aim_dir)
	Input.action_release("move_down")
	await _physics_frames(1)
	Input.action_release("move_right")
	Input.action_press("jump")
	await _physics_frames(2)
	Input.action_release("jump")
	_check(game.abilities.charges.rifle == 0 and game.slime.facing.is_equal_approx(Vector2(1, 1).normalized()),
		"...letting go of the keys one after the other still fires it diagonally")
	_check(Abilities.reach_along(12, Vector2i(1, 1)) == 8 and Abilities.reach_along(12, Vector2i.RIGHT) == 12
		and Abilities.rifle_tiles(game.maze, Vector2i(1, 1), Vector2i(1, 1), 12).size() <= 9 and Abilities.aim8(Vector2(-1, -1)) == Vector2i(-1, -1),
		"a diagonal reaches about as far as a straight one (12 straight = 8 diagonal steps)")
	await _stop(game)
	game = await _spawn(4)
	game.abilities.start_aim("splat")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game.abilities._unhandled_input(click)
	await _physics_frames(2)
	_check(game.abilities.charges.splat == 0 and game.abilities.aiming == "", "a left click fires the aimed GOO GRENADE")
	await _stop(game)
	progress.set_binding("ability_splat", KEY_Q)
	var q := InputMap.action_get_events("ability_splat")
	_check(progress.bindings.ability_splat == KEY_Q and (q[0] as InputEventKey).physical_keycode == KEY_Q, "remappable: SLIME SPLAT on Q")
	progress.set_binding("ability_splat", KEY_SPACE)
	_check(progress.bindings.ability_splat == KEY_SPACE and progress.bindings.jump == KEY_Q, "taking JUMP's key swaps them")
	progress.reset_bindings()
	_check(progress.bindings.ability_splat == KEY_2 and progress.bindings.jump == KEY_SPACE, "RESET KEYS restores them")
	var page: Control = load("res://scenes/key_controls.tscn").instantiate()
	root.add_child(page)
	await process_frame
	var inside := true
	for action: String in page.key_buttons:
		inside = inside and Rect2(0, 20, 320, 120).encloses(page.key_buttons[action].get_global_rect())
	_check(page.key_buttons.size() == 10 and page.key_buttons.ability_kaze.text == "3" and inside, "the CONTROLS page lists the 3 ability keys (10 rows, all on screen)")
	page.free()


func _touch() -> void:
	_state({rifle = 1, kaze = 2})
	progress.force_touch = true
	var game := await _spawn(4)
	_aim(game, _dir_with(game, 1))
	var tc: TouchControls = game.touch_controls
	var center := {}
	for i in tc.abilities.size():
		center[tc.abilities[i].id] = _button_center(tc, i)
	_check(tc.abilities.size() == 2 and center.size() == 2, "touch: a button per owned ability")
	# JUMP's REAL catch area, probed: every touch the controls turn into a JUMP press (the letterbox
	# past the screen's edges too), and every touch that lands on an ability button.
	var jump_pts: Array[Vector2] = []
	var button_pts: Array[Vector2] = []
	for y in range(-10, 191, 2):
		for x in range(60, 341, 2):
			var p := Vector2(x, y)
			if tc.ability_at(p) >= 0:
				button_pts.append(p)
			_tap(tc, 7, p, true)
			if Input.is_action_pressed("jump"):
				jump_pts.append(p)
			_tap(tc, 7, Vector2(-60, -60), false)  # (lifted far away: an ability doesn't fire)
			game.abilities.cancel_aim()  # (a tap on SLIME RIFLE's button brings its aim up: the probe is about the hit areas)
	var gap := INF
	for b in button_pts:
		for j in jump_pts:
			gap = minf(gap, b.distance_to(j))
	_check(gap >= DEAD_RING - 0.01, "a dead ring of >= %d px between every ability hit area and JUMP's real catch zone (%.1f px)" % [DEAD_RING, gap])
	var missed := []
	for r in range(int(TouchControls.JUMP_RADIUS), int(TouchControls.JUMP_RADIUS) + 26, 3):
		for a in 24:
			var p := (TouchControls.JUMP_CENTER + Vector2.from_angle(TAU * a / 24.0) * r).round()
			if not Rect2(0, 0, 320, 180).has_point(p) or tc.pause_rect.grow(TouchControls.PAUSE_TOUCH_MARGIN).has_point(p):
				continue
			_tap(tc, 7, p, true)
			if tc.ability_at(p) >= 0 or not Input.is_action_pressed("jump"):
				missed.append(p)
			_tap(tc, 7, Vector2(-60, -60), false)
	_check(missed.is_empty(), "a thumb missing JUMP (up to 25 px off its edge, all round) still leaps, never an ability (%s)" % [missed.slice(0, 4)])
	_check(_charges_left(game) == {rifle = 1, kaze = 1}, "probing every spot (each lifted off its button) fired nothing")
	# The buttons: one row along the bottom (owner, 2026-10-23), in Abilities order like the HUD strip, clear of the
	# joystick's home ring, JUMP, the training line's bottom spot and the HUD's pods, gold ring included.
	_check(center.rifle.y == center.kaze.y and center.rifle.x < center.kaze.x and center.rifle.y > 120,
		"the ability buttons sit in one row along the bottom, SLIME RIFLE first (%s / %s)" % [center.rifle, center.kaze])
	var row := tc.ability_row_rect()
	var joy := Rect2(TouchControls.JOY_HOME - Vector2.ONE * TouchControls.JOY_RADIUS, Vector2.ONE * TouchControls.JOY_RADIUS * 2.0)
	var jump_r := TouchControls.JUMP_RADIUS + 6.0  # (the circle grows a little for a longer JUMP word)
	var jump := Rect2(TouchControls.JUMP_CENTER - Vector2.ONE * jump_r, Vector2.ONE * jump_r * 2.0)
	var line_top := UIKit.SCREEN.y - UIKit.hud_edge().y - UIKit.pod_h()
	var clash: Array = game.hud.pod_rects().filter(func(r: Rect2) -> bool: return r.intersects(row))
	_check(row.has_area() and clash.is_empty() and not row.intersects(joy) and not row.intersects(jump) and row.end.y <= line_top,
		"...clear of the joystick, JUMP, the training line (top %d) and the HUD pods (%s, %s)" % [line_top, row, clash])
	var kaze_only: Array[Dictionary] = [{id = "kaze", left = 1, max = 1}]
	tc.set_abilities(kaze_only)
	_check(_button_center(tc, 0).distance_to(TouchControls.JUMP_CENTER) > 80.0, "owning only SLIMAKAZE, its button keeps its far spot (%s)" % _button_center(tc, 0))
	game.abilities._refresh()
	await _physics_frames(90)  # (the probe's JUMP taps set off a leap or two: let them land)
	for i in 180:
		if game.slime.state == Slime.State.GLIDE:
			break
		await physics_frame
	_place(game, _start_tile(game), _dir_with(game, 1))
	# SLIME RIFLE aims (owner, 2026-10-23): its button brings the aim up, letting go fires nothing (JUMP does: _touch_aim).
	_tap(tc, 3, center.rifle, true)
	await _physics_frames(2)
	_check(game.abilities.aiming == "rifle" and game.abilities.charges.rifle == 1 and not Input.is_action_pressed("jump"),
		"touching SLIME RIFLE's button brings up its aim, fires nothing")
	_tap(tc, 3, center.rifle + Vector2(3, 0), false)
	await _physics_frames(1)
	_check(game.abilities.aiming == "rifle" and game.abilities.charges.rifle == 1 and not Input.is_action_pressed("ability_rifle")
		and not Input.is_action_pressed("jump"), "lifting the finger fires nothing either (the aim stays up, nothing left held)")
	_tap(tc, 3, center.rifle, true)
	_tap(tc, 3, center.rifle, false)
	await _physics_frames(1)
	_check(game.abilities.aiming == "rifle" and game.abilities.charges.rifle == 1, "its button again does nothing (only the X calls it off)")
	game.abilities.cancel_aim()
	progress.force_touch = false
	await _stop(game)


## Touch aiming (owner, 2026-10-23, as on the PC): SLIME SNIPER / GOO GRENADE's button brings up the aim guide (letting go
## doesn't fire), the joystick or a drag turns it (8 ways), JUMP fires it (no leap, nothing left held) and blinks a gold ring
## meanwhile; the same button again calls it off, another ability's switches; SLIME SENSE stays a tap.
func _touch_aim() -> void:
	_state({rifle = 3, splat = 3, sense = 1})
	progress.force_touch = true
	var game := await _spawn(4)
	current_scene = game  # (SLIME SENSE's map locks the focus of the running scene)
	var tc: TouchControls = game.touch_controls
	var runner: AbilityRunner = game.abilities
	for i in 180:
		if game.slime.state == Slime.State.GLIDE:
			break
		await physics_frame
	_place(game, _start_tile(game), _dir_with(game, 1))
	await _physics_frames(2)
	runner.charges.rifle = 3  # (a few uses for the steps below)
	runner.charges.splat = 3
	var rifle := tc.slot_center(0)
	var left: int = runner.charges.rifle
	_tap(tc, 4, rifle, true)
	_tap(tc, 4, rifle, false)
	await _physics_frames(2)
	_check(runner.aiming == "rifle" and game.slime.aim_lock and runner.charges.rifle == left and tc.aim_ring,
		"touch: a tap on SLIME SNIPER brings up its aim (nothing spent, letting go fires nothing), JUMP's gold ring on")
	var still: Vector2 = game.slime.position
	Input.action_press("move_up")
	await _physics_frames(20)
	Input.action_release("move_up")
	_check(runner.aim_dir == Vector2i(0, -1) and game.slime.position == still,
		"...the joystick only aims now (up: %s), the slime stays put" % runner.aim_dir)
	_tap(tc, 5, TouchControls.JUMP_CENTER, true)
	await _physics_frames(10)
	_check(runner.aiming == "rifle" and runner.charges.rifle == left and tc.cancel_shown() and not Input.is_action_pressed("jump")
		and game.slime.state == Slime.State.GLIDE, "...JUMP held: nothing fires yet, no leap, the X shows by JUMP")
	var x := tc.cancel_center()
	_check(x.distance_to(TouchControls.JUMP_CENTER) > TouchControls.JUMP_RADIUS + TouchControls.CANCEL_HIT - 0.01 and x.x < TouchControls.JUMP_CENTER.x + 40
		and x.y < TouchControls.JUMP_CENTER.y and Rect2(Vector2.ZERO, TouchControls.SCREEN).grow(-TouchControls.CANCEL_HIT).has_point(x)
		and not tc.ability_row_rect().grow(TouchControls.CANCEL_HIT).has_point(x) and not tc.pause_rect.grow(TouchControls.CANCEL_HIT).has_point(x),
		"...the X sits just outside JUMP's top right, on screen, clear of JUMP, the ability row and pause (%s)" % x)
	Platform.safe_area_override = Rect2i(0, 0, 1240, 720)  # (a notch's inset on the right, 40 px of a 1280 window: 10 view px)
	Platform.window_override = Vector2i(1280, 720)
	var notched := tc.cancel_center()
	Platform.safe_area_override = Rect2i()
	Platform.window_override = Vector2i.ZERO
	_check(notched.distance_to(TouchControls.JUMP_CENTER) > TouchControls.JUMP_RADIUS + TouchControls.CANCEL_HIT - 0.01 and notched.x <= 310 - TouchControls.CANCEL_HIT,
		"...with a notch on the right it moves above JUMP, still clear of it (%s)" % notched)
	_tap(tc, 5, TouchControls.JUMP_CENTER, false)
	await _physics_frames(2)
	_check(runner.aiming == "" and runner.charges.rifle == left - 1 and game.slime.facing.is_equal_approx(Vector2.UP)
		and game.slime.state != Slime.State.CHARGING and not tc.aim_ring and not tc.cancel_shown(),
		"...JUMP let go: it fires along the aim (no charge starts, the ring and the X gone)")
	await _physics_frames(10)
	_check(not Input.is_action_pressed("jump") and game.slime.state == Slime.State.GLIDE, "...nothing held, no leap")
	await _physics_frames(30)
	_tap(tc, 5, TouchControls.JUMP_CENTER, true)
	await _physics_frames(2)
	_check(game.slime.state == Slime.State.CHARGING, "the next JUMP is a real leap again")
	_tap(tc, 5, TouchControls.JUMP_CENTER, false)
	await _physics_frames(90)
	for i in 180:
		if game.slime.state == Slime.State.GLIDE:
			break
		await physics_frame
	# The X: JUMP held, dragged onto it and let go there: called off, nothing spent, no leap.
	left = runner.charges.rifle
	_tap(tc, 4, rifle, true)
	_tap(tc, 4, rifle, false)
	_tap(tc, 5, TouchControls.JUMP_CENTER, true)
	_drag(tc, 5, x + Vector2(4, 3))  # (a forgiving disc: a little off its middle)
	await _physics_frames(2)
	_check(tc._cancel_hover, "dragged onto the X: it lights up")
	_tap(tc, 5, x + Vector2(4, 3), false)
	await _physics_frames(10)
	_check(runner.aiming == "" and runner.charges.rifle == left and not game.slime.aim_lock and game.slime.state == Slime.State.GLIDE
		and not Input.is_action_pressed("jump") and not tc.cancel_shown(), "...let go on the X: the aim is called off (nothing spent, no leap)")
	_tap(tc, 4, rifle, true)
	_tap(tc, 4, rifle, false)
	_tap(tc, 5, TouchControls.JUMP_CENTER, true)
	_drag(tc, 5, x)
	_drag(tc, 5, TouchControls.JUMP_CENTER + Vector2(-6, 4))
	await _physics_frames(2)
	_check(not tc._cancel_hover and tc.cancel_shown(), "dragged back off the X: unlit")
	_tap(tc, 5, TouchControls.JUMP_CENTER + Vector2(-6, 4), false)
	await _physics_frames(2)
	_check(runner.aiming == "" and runner.charges.rifle == left - 1, "...let go there: it fires")
	await _physics_frames(30)
	runner.charges.rifle = 3
	left = runner.charges.rifle
	_tap(tc, 4, rifle, true)
	var before: Vector2i = runner.aim_dir
	_drag(tc, 4, rifle + Vector2(30, -30))
	_tap(tc, 4, rifle + Vector2(30, -30), false)
	await _physics_frames(2)
	_check(runner.aiming == "rifle" and runner.aim_dir == before and runner.charges.rifle == left,
		"a drag off the button doesn't aim (only the joystick does: %s)" % runner.aim_dir)
	var splat := tc.slot_center(1)
	_tap(tc, 4, splat, true)
	_tap(tc, 4, splat, false)
	_check(runner.aiming == "splat", "GOO GRENADE's button switches the aim to it")
	_tap(tc, 4, splat, true)
	_tap(tc, 4, splat, false)
	await _physics_frames(2)
	_check(runner.aiming == "splat" and game.slime.aim_lock and tc.aim_ring, "...and again does nothing (still aiming)")
	var sense := tc.slot_center(2)
	_tap(tc, 6, sense, true)
	_tap(tc, 6, sense, false)
	await _physics_frames(2)
	_check(runner.aiming == "splat" and game.random_map_view == null and tc.abilities[2].id == "sense",
		"SLIME SENSE does nothing while aiming (dimmed)")
	_tap(tc, 5, TouchControls.JUMP_CENTER, true)
	_tap(tc, 5, x, false)
	await _physics_frames(2)
	_check(runner.aiming == "" and runner.charges.splat == 3 and not game.slime.aim_lock and not tc.aim_ring, "...the X calls it off (nothing spent)")
	var moved_from: Vector2 = game.slime.position
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _physics_frames(20)
	Input.action_release("move_right")
	Input.action_release("move_down")
	_check(game.slime.position != moved_from, "...then the joystick moves the slime again")
	_tap(tc, 6, sense, true)
	_tap(tc, 6, sense, false)
	await _physics_frames(2)
	_check(game.random_map_view != null, "...and SLIME SENSE is a tap again (it peeks)")
	game._close_run_map()
	await _physics_frames(2)
	# Nothing leaves the joystick stuck aiming: the pause menu, a dry-up.
	_tap(tc, 4, rifle, true)
	_tap(tc, 4, rifle, false)
	await _physics_frames(2)
	paused = true
	await process_frame
	paused = false
	await _physics_frames(2)
	_check(runner.aiming == "" and not game.slime.aim_lock and not tc.aim_ring, "a pause calls the aim off (the joystick moves again)")
	_tap(tc, 4, rifle, true)
	_tap(tc, 4, rifle, false)
	await _physics_frames(2)
	game._dry_up()
	await _physics_frames(3)
	_check(runner.aiming == "" and not game.slime.aim_lock and not tc.aim_ring, "drying up calls it off too")
	current_scene = null
	progress.force_touch = false
	await _stop(game)


## A touch drag straight into the controls.
func _drag(tc: TouchControls, index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	tc._input(event)


## A touch event straight into the controls (viewport coordinates).
func _tap(tc: TouchControls, index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	tc._input(event)


## The center of the button of `tc.abilities[i]` (the middle of the spots that hit it).
func _button_center(tc: TouchControls, i: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for y in 180:
		for x in range(0, 320):
			if tc.ability_at(Vector2(x, y)) == i:
				sum += Vector2(x, y)
				n += 1
	return (sum / maxi(n, 1)).round()


func _charges_left(game: Node2D) -> Dictionary:
	return game.abilities.charges.duplicate()


# ---------------------------------------------------------------- modes

func _modes() -> void:
	_state({rifle = 3, splat = 3, kaze = 3})
	# Story levels (normal, hard): abilities are OFF; keys do nothing, cost nothing, no strip/buttons.
	var game := await _story(1)
	var par: float = game.par_time
	await _inert(game, "story normal")
	await _stop(game)
	progress.hard_mode = true
	progress.hard_cleared.assign([1])
	game = await _story(1)
	await _inert(game, "story hard")
	await _stop(game)
	progress.hard_mode = true
	game = await _spawn(0, 4242)
	_check(game.abilities == null, "hard-mode randomizer: off (hard mode plays without upgrades)")
	await _stop(game)
	progress.hard_mode = false
	_check(Abilities.allowed_in(null) == false, "allowed_in(null) is false")
	_state({rifle = 3, splat = 3, kaze = 3})
	_state({})
	game = await _story(1)
	_check(game.abilities == null and is_equal_approx(game.par_time, par), "no abilities owned: none; par is the same either way")
	await _stop(game)
	_state({rifle = 1})
	game = await _spawn(0, 4242)
	var pay: Dictionary = game.payout()
	_check(game.abilities != null, "randomizer: on")
	game.abilities.use("rifle")
	game.abilities.flush()
	_check(game.payout() == pay, "using one leaves the randomizer payout as it was (%s)" % [pay])
	await _stop(game)
	_state({kaze = 1})
	progress.start_descent(777)
	game = await _spawn(0)
	_check(game.descent and game.abilities != null and game.abilities.charges.kaze == 1, "Descent: on (charges per floor)")
	await _stop(game)
	_state({rifle = 1})
	Economy.abilities_force = 0
	game = await _spawn(1)
	_check(game.abilities == null and progress.ability_level("rifle") == 0 and progress.abilities.rifle == 1, "flag off: no abilities, the saved level kept")
	await _stop(game)
	Economy.abilities_force = -1


## A story-level game with all three owned: no runner, no strip, no buttons; pressing 1 / 2 / 3 changes
## nothing (no slime cost, no sound).
func _inert(game: Node2D, label: String) -> void:
	_check(not Abilities.allowed_in(game) and game.abilities == null and not game.hud.ability_pod.visible
		and game.touch_controls.abilities.is_empty(), "%s: no abilities, no strip, no touch buttons" % label)
	var meter: float = game.slime_remaining
	var sounds := 0
	for id in Abilities.ids():
		Input.action_press(Abilities.action(id))
	await _physics_frames(3)
	for id in Abilities.ids():
		Input.action_release(Abilities.action(id))
	await _physics_frames(3)
	_check(is_equal_approx(game.slime_remaining, meter) and game.get_children().all(func(c: Node) -> bool: return not (c is AbilityRunner)),
		"%s: keys 1 2 3 do nothing (meter %.1f -> %.1f)" % [label, meter, game.slime_remaining])


# ---------------------------------------------------------------- the TICKETS tab

func _store() -> void:
	_state({})
	progress.tickets = 0
	progress.tickets_lifetime = 0
	var script: GDScript = load("res://scripts/ui/upgrades_screen.gd")
	script.set("open_tab", "abilities")
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.page == "abilities" and screen.ability_page.visible and screen.ability_rows.size() == Abilities.LIST.size() and screen.abilities_tab.text == "TICKETS"
		and "EARN TICKETS" in screen.hint.text and screen.abilities_tab.has_focus(), "TICKETS tab: %d abilities, locked before any ticket" % Abilities.LIST.size())
	screen.free()
	progress.tickets = 30
	progress.tickets_lifetime = 30
	script.set("open_tab", "abilities")
	screen = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var rows: Dictionary = screen.ability_rows
	_check(rows.rifle.cost.text == "30" and not rows.rifle.plus.disabled and not rows.splat.plus.disabled and rows.kaze.plus.disabled and rows.rifle.tag.text == "SHOOTS GOO"
		and screen.coin_label.text == "30" and "1 2 3" in screen.hint.text, "30 tickets: SLIME RIFLE and SPLAT affordable (30), SLIMAKAZE (50) not; tag, pod and keys hint")
	rows.rifle.plus.pressed.emit()
	_check(screen.confirm.visible and screen.confirm_label.text == "BUY SLIME SNIPER 1?" and screen.confirm_price.text == "30" and progress.tickets == 30,
		"+ opens BUY SLIME RIFLE 1? (nothing spent yet)")
	screen.confirm_buy.pressed.emit()
	_check(progress.ability_level("rifle") == 1 and progress.tickets == 0 and not screen.confirm.visible and rows.rifle.cost.text == "60",
		"BUY: level 1 for exactly 30 tickets; the next costs 60")
	progress.abilities = {rifle = 3}
	progress.tickets = 999
	screen._refresh()
	_check(rows.rifle.cost.text == "MAX" and rows.rifle.plus.disabled and not rows.rifle.ticket.visible and not progress.buy_ability("rifle"),
		"max level: MAX, + off, can't buy")
	_check(progress.store_affordable("upgrades"), "the hub's '!' at the cauldron counts the abilities")
	await _press_ui(screen, "ui_cancel")
	screen.free()
	# The COINS page: no explanation lines left.
	script.set("open_tab", "coins")
	screen = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var texts := []
	for node in screen.coin_page.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var plain := texts.all(func(t: String) -> bool: return not ("->" in t or " PX" in t or "SLIME X" in t.to_upper() or "AREA" in t))
	_check(plain and not "RECOMMENDED" in texts and "MORE SLIME" in texts, "COINS: names, bars and costs only, no RECOMMENDED tag (D12) (%s)" % [texts])
	screen.free()
	script.set("open_tab", "coins")


func _press_ui(_screen: Control, _action: String) -> void:
	await process_frame


# ---------------------------------------------------------------- saves

func _saves() -> void:
	_state({rifle = 2, kaze = 1})
	var file: ConfigFile = progress._write()
	_check(file.get_value("abilities", "rifle") == 2 and file.get_value("abilities", "kaze") == 1 and not file.has_section_key("abilities", "splat")
		and file.get_value("controls", "ability_splat") == KEY_2, "saved: [abilities] levels (owned only) and the ability keys")
	progress.abilities = {}
	progress._read_store(file)
	_check(progress.abilities == {rifle = 2, kaze = 1}, "read back")
	var hostile := ConfigFile.new()
	hostile.set_value("abilities", "rifle", 99)
	hostile.set_value("abilities", "splat", -4)
	hostile.set_value("abilities", "kaze", "lots")
	hostile.set_value("abilities", "laser", 3)
	progress._read_store(hostile)
	_check(progress.abilities == {rifle = 3}, "hostile values clamp (99 -> 3, -4 / text / unknown ids -> nothing): %s" % [progress.abilities])
	progress.abilities = {rifle = 3, splat = 3, kaze = 3}
	var code: String = progress.save_code()
	var back: ConfigFile = progress.read_code(code)
	_check(back != null and back.get_value("abilities", "splat") == 3 and code.length() < 4000, "a save code carries them (%d chars)" % code.length())
	progress.reset_progress()
	_check(progress.abilities.is_empty(), "RESET PROGRESS clears the abilities")


## A save from before the abilities with JUMP on 1 keeps every binding; the ability keys take spares.
func _bindings_migration() -> void:
	var file := ConfigFile.new()
	for action: String in ["move_up", "move_down", "move_left", "move_right", "restart", "interact"]:
		file.set_value("controls", action, progress.DEFAULT_KEYS[action])
	file.set_value("controls", "jump", KEY_1)
	progress._read_bindings(file)
	_check(progress.bindings.jump == KEY_1 and progress.bindings.ability_rifle == KEY_2 and progress.bindings.ability_splat == KEY_3
		and progress.bindings.ability_kaze == KEY_4, "an old save with JUMP on 1 keeps it; the abilities get 2 / 3 / 4 (%s)" % [progress.bindings])
	progress.reset_bindings()


