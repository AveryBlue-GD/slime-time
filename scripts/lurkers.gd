class_name Lurkers
extends Node

## LURKERS (Economy.LURKERS_TEST, BM-01): pale, goofy, blind creatures living in the fog of every hard-mode maze (a hard
## story level: placed by its level, so retries are learnable) and of normal random mazes with SETTINGS LURKERS on (allowed). Only their 2 px eye glints
## show through the fog (the EyeLayer, above it); the body, under the fog, shows in the light.
## Pac-Man style on the maze grid: a lurker walks cell to cell and, at each cell, takes the open neighbour that is
## nearest (straight-line, in cells) to its target, never turning back unless it is a dead end (pick_next).
## CRAWLER -> the slime's cell, SNIFFER -> the trail (the cell 3 behind the slime's newest), LANTERN-EATER ->
## the brightest lit cell near the slime (not its own). Dormant until the slime is within LURKER_WAKE_DIST.
## Standing still past the idle grace = stealth: they lose track and wander. Contact costs LURKER_HIT percent of
## the meter (never the last 1%), pushes the slime back a tile and gives it LURKER_INVULN s; a pass without
## contact within LURKER_NEAR_MISS_DIST is a LURKER_SLOWMO s slow-motion. SLIME SPLAT stuns them, a leap landing
## on one bonks it away. Pure rules (spawn, placement, targets) are static so the tests can call them.

enum Kind { CRAWLER, SNIFFER, LANTERN }

const SHEET := preload("res://assets/sprites/lurkers.png")  # tools/make_lurkers.py
const TILE := 16
const FRAME := 12
const FRAMES := 4
## The eye glints' pixel in the 12x12 frame: x of the two eyes, y per frame (tools/make_lurkers.py prints them).
const EYE_X: Array[int] = [4, 7]
const EYE_Y: Array[int] = [6, 6, 5, 6]
const EYE_COLOR: Array[Color] = [Color8(255, 240, 180), Color8(255, 138, 150), Color8(244, 244, 244)]
const BODY_Z := 6  # under the fog (z 10), like a coin
const EYE_Z := 12  # over the fog (10) and the slime's lantern (11)
const WAKE_TIME := 0.5
const SLIDE_SPEED := 90.0
const SLIDE_TIME := 0.35
const RECOIL := 0.8
const BONK_DIST := 12.0
const PUSH_STEP := 3.0
const SPACING_CELLS := 6
const MIN_START_STEPS := 8
const TRAIL_KEEP := 8
const TRAIL_BEHIND := 3
const LANTERN_RADIUS := 4
const LANTERN_MIN := 0.15
const GROWL_NEAR := 160.0
const BLINK_GAP := 0.08
const SLOWMO_SCALE := 0.45


class Lurker:
	var kind := 0
	var cell := Vector2i.ZERO  # the last cell centre reached
	var prev := Vector2i.ZERO  # the one before (never turned back to, except at a dead end)
	var to := Vector2i.ZERO  # the cell it is walking to
	var pos := Vector2.ZERO
	var awake := false
	var wake_t := 0.0
	var stun := 0.0
	var slide := 0.0
	var near_active := false
	var near_hit := false
	var growl_left := 0.0
	var sprite: Sprite2D

	## Eyes show once awake, past the eye-open, and not while stunned.
	func eyes_open() -> bool:
		return awake and wake_t >= WAKE_TIME * 0.5 and stun <= 0.0


## Draws the eye glints above the fog.
class EyeLayer extends Node2D:
	var owner_lurkers: Lurkers

	func _draw() -> void:
		if owner_lurkers == null:
			return
		var t := owner_lurkers.elapsed
		var index := 0
		for l in owner_lurkers.lurkers:
			index += 1
			if not l.eyes_open():
				continue
			var base := (l.pos.round() - Vector2(FRAME / 2, FRAME / 2)).round()
			var frame := owner_lurkers.frame_of(l)
			var color: Color = EYE_COLOR[l.kind]
			color.a = 0.7 + 0.3 * sin(t * 3.0 + index)
			for ex in EYE_X:
				draw_rect(Rect2(base + Vector2(ex, EYE_Y[frame]), Vector2.ONE), color)


var game: Node
var slime: Slime
var maze: Dictionary
var lurkers: Array[Lurker] = []
var elapsed := 0.0
## Seconds of safety left after a hit, and the blink phase.
var invuln := 0.0
var hits := 0
var near_misses := 0
var bonks := 0
var _push_left := 0.0
var _push_dir := Vector2.ZERO
var _trail: Array[Vector2i] = []
var _slowmo_until_ms := -1
var _slowmo_acc := 0.0
var _eyes: EyeLayer
var _blink := 0.0
var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- rules (static)

## Whether this run has lurkers. Hard mode (a hard story level, or a hard random maze: `hard`) always does, whatever the
## settings (RELAXED too); a normal random maze only with SETTINGS LURKERS (`toggle`); never the daily / weekly (`shared`:
## the same maze for everyone), a normal story level, Descent, training, the demo, nor during the ability tutorial
## (`--lurkers` = force 2 forces them into every random maze, the tutorial included; `--nolurkers` = none).
static func allowed(random: bool, hard: bool, shared: bool, descent: bool, training: bool, demo: bool, toggle: bool,
		ability_tutorial: bool) -> bool:
	if not Economy.lurkers_on() or descent or training or demo:
		return false
	if hard and not shared:
		return true
	if not random:
		return false
	if Economy.lurkers_force >= 2:
		return true
	return toggle and not shared and not ability_tutorial


## Integer hash (the same on every platform).
static func seed_mix(seed_value: int, salt: int) -> int:
	var x := (seed_value ^ (salt * 0x9E3779B1)) & 0xFFFFFFFF
	x = ((x ^ (x >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	x = ((x ^ (x >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	return (x ^ (x >> 15)) & 0x7FFFFFFF


## 2 or 3 lurkers for a seed.
static func count_for(seed_value: int) -> int:
	return 2 + seed_mix(seed_value, 0x51) % 2


## The fixed seed of a hard story level's lurkers (its maze is always the same, so the creatures sit and walk the same
## way every try) and how many there are (2 on the first levels, then 3).
static func story_seed(level: int) -> int:
	return 7100 + level


static func story_count(level: int) -> int:
	return 2 if level <= Economy.LURKER_HARD_FEW_LEVELS else 3


## Where the seed's lurkers sleep: cells at least MIN_START_STEPS along the passages from the start (fewer if the
## maze is small), not the goal, SPACING_CELLS apart; in the order CRAWLER, SNIFFER, LANTERN-EATER.
static func place(the_maze: Dictionary, seed_value: int, count := -1) -> Array[Vector2i]:
	var dist := MazeGenerator.distances_from(the_maze, the_maze.start)
	var far := 0
	for cell: Vector2i in dist:
		far = maxi(far, int(dist[cell]))
	var min_steps := mini(MIN_START_STEPS, maxi(far / 2, 1))
	var pool: Array[Vector2i] = []
	for cell: Vector2i in dist:
		if int(dist[cell]) >= min_steps and cell != the_maze.goal:
			pool.append(cell)
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_mix(seed_value, 0x7C)
	var out: Array[Vector2i] = []
	var want := count if count > 0 else count_for(seed_value)
	var tries := 0
	while out.size() < want and not pool.is_empty() and tries < 200:
		tries += 1
		var pick: Vector2i = pool[rng.randi() % pool.size()]
		var ok := true
		for other in out:
			if maxi(absi(other.x - pick.x), absi(other.y - pick.y)) < SPACING_CELLS:
				ok = false
		if ok:
			out.append(pick)
	return out


## The greedy step: the open neighbour of `cell` nearest to `target` (straight line, in cells), never `came_from`
## unless it is the only way (a dead end). Ties go to the first of right, left, down, up.
static func pick_next(the_maze: Dictionary, cell: Vector2i, came_from: Vector2i, target: Vector2i) -> Vector2i:
	var options := MazeGenerator.open_neighbors(the_maze, cell)
	var best := cell
	var best_d := INF
	for n in options:
		if n == came_from and options.size() > 1:
			continue
		var d := Vector2(n - target).length_squared()
		if d < best_d:
			best_d = d
			best = n
	return best


## Wandering (stealth): a random open neighbour, not back unless a dead end.
static func pick_wander(the_maze: Dictionary, cell: Vector2i, came_from: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var options := MazeGenerator.open_neighbors(the_maze, cell)
	var ahead: Array[Vector2i] = []
	for n in options:
		if n != came_from or options.size() == 1:
			ahead.append(n)
	return cell if ahead.is_empty() else ahead[rng.randi() % ahead.size()]


## LANTERN-EATER's target: of the cells within `radius` (Chebyshev) of the slime's, other than the slime's own, the
## brightest (`bright.call(cell) -> 0..1`, at least LANTERN_MIN); ties to the one nearest the slime, then top-left.
## The slime's own cell when nothing is lit.
static func lantern_target(the_maze: Dictionary, slime_cell: Vector2i, bright: Callable, radius := LANTERN_RADIUS) -> Vector2i:
	var best := slime_cell
	var best_b := LANTERN_MIN
	var best_d := INF
	for y in range(slime_cell.y - radius, slime_cell.y + radius + 1):
		for x in range(slime_cell.x - radius, slime_cell.x + radius + 1):
			var cell := Vector2i(x, y)
			if cell == slime_cell or x < 0 or y < 0 or x >= the_maze.cells.x or y >= the_maze.cells.y:
				continue
			var b: float = bright.call(cell)
			var d := Vector2(cell - slime_cell).length_squared()
			if b > best_b + 0.0001 or (absf(b - best_b) <= 0.0001 and b > LANTERN_MIN and d < best_d):
				best_b = b
				best_d = d
				best = cell
	return best


# ---------------------------------------------------------------- the run

## Builds the run's lurkers (none when the rules say no) as a child of `owner_game`; null when there are none.
static func create(owner_game: Node) -> Lurkers:
	var random: bool = owner_game.is_random()
	var progress: Node = owner_game.progress
	var shared: bool = random and progress != null and (progress.random_daily or progress.random_weekly)
	var hard: bool = owner_game.hard_mode
	if not allowed(random, hard, shared, owner_game.descent, owner_game.training, Platform.is_demo() or owner_game.preview,
			progress != null and progress.lurkers_random, owner_game.coach != null):
		return null
	var seed_value: int = owner_game.random_seed if random else story_seed(owner_game.level)
	var count := -1 if random else story_count(owner_game.level)
	var cells := place(owner_game.maze, seed_value, count)
	if cells.is_empty():
		return null
	var node := Lurkers.new()
	node.game = owner_game
	node.slime = owner_game.slime
	node.maze = owner_game.maze
	node.name = "Lurkers"
	owner_game.add_child(node)
	node.spawn(cells, seed_value)
	return node


func spawn(cells: Array[Vector2i], seed_value: int) -> void:
	_rng.seed = seed_mix(seed_value, 0x33)
	var i := 0
	for cell in cells:
		var l := Lurker.new()
		l.kind = i % 3
		l.cell = cell
		l.prev = cell
		l.to = cell
		l.pos = MazeGenerator.cell_center(cell, TILE)
		l.sprite = Sprite2D.new()
		l.sprite.texture = SHEET
		l.sprite.hframes = FRAMES
		l.sprite.vframes = 3
		l.sprite.z_index = BODY_Z
		l.sprite.position = l.pos
		add_child(l.sprite)
		lurkers.append(l)
		i += 1
	_eyes = EyeLayer.new()
	_eyes.owner_lurkers = self
	_eyes.z_index = EYE_Z
	add_child(_eyes)
	for l in lurkers:
		_show(l)


## Which of the 4 sheet frames `l` shows now: shut eyes while dormant, waking or stunned, else the 3-frame wobble.
func frame_of(l: Lurker) -> int:
	if not l.awake or l.wake_t < WAKE_TIME * 0.5 or l.stun > 0.0:
		return 3
	return int(elapsed * 6.0 + float(lurkers.find(l))) % 3


func _show(l: Lurker) -> void:
	l.sprite.position = l.pos.round()
	l.sprite.frame = l.kind * FRAMES + frame_of(l)


## The maze cell whose area `pos` is in.
static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE) >> 1, floori(pos.y / TILE) >> 1)


func _process(_delta: float) -> void:
	if _slowmo_until_ms >= 0:
		_slowmo_step()
	if _eyes != null:
		_eyes.queue_redraw()
	if invuln > 0.0 and game.finished:
		invuln = 0.0
		_update_blink()


## The near-miss slow-motion never touches Engine.time_scale (it would outlive a pause): the level's
## physics runs on only SLOWMO_SCALE of the frames, and this node pauses with the tree.
func _slowmo_step() -> void:
	_slowmo_acc += SLOWMO_SCALE
	var run := _slowmo_acc >= 1.0
	if run:
		_slowmo_acc -= 1.0
	if Time.get_ticks_msec() >= _slowmo_until_ms:
		_slowmo_until_ms = -1
		run = true
	_slowmo_set(run)


func _slowmo_set(run: bool) -> void:
	if not is_instance_valid(game) or game._hitstop_frames > 0:
		return
	game.set_physics_process(run)
	if is_instance_valid(slime):
		slime.set_physics_process(run)


func _exit_tree() -> void:
	if _slowmo_until_ms >= 0:
		_slowmo_until_ms = -1
		_slowmo_set(true)
	if is_instance_valid(slime):
		slime.modulate.a = 1.0


## One physics tick of the lurkers (game._physics_process, while the run is live).
func step(delta: float) -> void:
	elapsed += delta
	var spos := slime.position
	_track_trail(spos)
	_push_step()
	if invuln > 0.0:
		invuln = maxf(invuln - delta, 0.0)
		_blink = maxf(_blink - delta, 0.0)
		_update_blink()
	var airborne := slime.is_airborne()
	var stealth: bool = game._still_time > Economy.IDLE_GRACE
	for l in lurkers:
		var d := spos.distance_to(l.pos)
		if not l.awake:
			if d <= Economy.LURKER_WAKE_DIST:
				_wake(l, stealth)
			_show(l)
			continue
		l.wake_t = minf(l.wake_t + delta, WAKE_TIME)
		if l.wake_t >= WAKE_TIME:
			_advance(l, delta, stealth)
		_proximity(l, d, delta)
		if l.stun <= 0.0 and invuln <= 0.0 and not airborne and not game.finished:
			if d <= Economy.LURKER_CONTACT_DIST:
				_hit(l)
				l.near_hit = true
		_near_miss(l, d)
		_show(l)


func _wake(l: Lurker, stealth: bool) -> void:
	l.awake = true
	l.wake_t = 0.0
	l.to = _decide(l, stealth)


## The cell `l` heads for next, from its kind's rule (or a wander while the slime keeps still).
func _decide(l: Lurker, stealth: bool) -> Vector2i:
	if stealth:
		return pick_wander(maze, l.cell, l.prev, _rng)
	return pick_next(maze, l.cell, l.prev, target_for(l.kind))


## The cell kind `kind` hunts now.
func target_for(kind: int) -> Vector2i:
	var here := cell_of(slime.position)
	match kind:
		Kind.SNIFFER:
			if _trail.is_empty():
				return here
			return _trail[maxi(_trail.size() - TRAIL_BEHIND, 0)]
		Kind.LANTERN:
			return lantern_target(maze, here, _brightness)
		_:
			return here


func _brightness(cell: Vector2i) -> float:
	return 1.0 - game.fog_alpha_at(MazeGenerator.cell_center(cell, TILE))


func _track_trail(spos: Vector2) -> void:
	if slime.is_airborne():
		return
	var cell := cell_of(spos)
	if _trail.is_empty() or _trail[_trail.size() - 1] != cell:
		_trail.append(cell)
		if _trail.size() > TRAIL_KEEP:
			_trail.remove_at(0)


func _advance(l: Lurker, delta: float, stealth: bool) -> void:
	if l.stun > 0.0:
		l.stun = maxf(l.stun - delta, 0.0)
		if l.slide <= 0.0:
			return
	var speed := Economy.LURKER_SPEED
	if l.slide > 0.0:
		speed = SLIDE_SPEED
		l.slide -= delta
	var goal := MazeGenerator.cell_center(l.to, TILE)
	var to_goal := goal - l.pos
	var step := speed * delta
	if to_goal.length() <= step:
		l.pos = goal
		l.prev = l.cell
		l.cell = l.to
		l.to = _decide(l, stealth)
	else:
		l.pos += to_goal.normalized() * step


## A low growl, quieter and slower the farther away; only awake lurkers within GROWL_NEAR.
func _proximity(l: Lurker, d: float, delta: float) -> void:
	if d > GROWL_NEAR or l.stun > 0.0:
		return
	l.growl_left -= delta
	if l.growl_left > 0.0:
		return
	var close := 1.0 - d / GROWL_NEAR
	l.growl_left = lerpf(4.5, 2.0, close)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("lurk_growl", lerpf(-30.0, -21.0, close), randf_range(0.9, 1.1))


## A pass within LURKER_NEAR_MISS_DIST that ends without a hit: a short slow-motion (not with Reduce Motion).
func _near_miss(l: Lurker, d: float) -> void:
	if not l.near_active:
		if d < Economy.LURKER_NEAR_MISS_DIST and l.stun <= 0.0:
			l.near_active = true
			l.near_hit = false
	elif d > Economy.LURKER_NEAR_MISS_DIST + 4.0:
		l.near_active = false
		if not l.near_hit and invuln <= 0.0:
			near_misses += 1
			if game.motion_scale() > 0.0 and _slowmo_until_ms < 0:
				_slowmo_acc = 0.0
				_slowmo_until_ms = Time.get_ticks_msec() + int(Economy.LURKER_SLOWMO * 1000.0)


## Contact: the meter loses LURKER_HIT percent (never its last 1%), the slime is pushed a tile away and is safe for a while.
func _hit(l: Lurker) -> void:
	hits += 1
	var amount := clampf(game.slime_remaining - 1.0, 0.0, Economy.LURKER_HIT_HARD if game.hard_mode else Economy.LURKER_HIT)
	game.spend_slime(amount)
	invuln = Economy.LURKER_INVULN_TOUCH if Platform.is_mobile_native() else Economy.LURKER_INVULN
	_blink = 0.0
	var away := slime.position - l.pos
	_push_dir = away.normalized() if away.length() > 0.1 else Vector2.UP
	_push_left = float(TILE)
	l.stun = RECOIL
	game.shake(2.5, 0.2)
	Fx.burst(game, slime.position, Color8(244, 244, 244), 10, 50.0, _push_dir, 120.0, false)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("lurk_bonk", -16.0)


func _push_step() -> void:
	if _push_left <= 0.0:
		return
	var d := minf(_push_left, PUSH_STEP)
	var hit := slime.move_and_collide(_push_dir * d)
	_push_left = 0.0 if hit != null else _push_left - d
	slime.knocked_back = true
	game.last_slime_pos = slime.position


func _update_blink() -> void:
	if invuln <= 0.0:
		slime.modulate.a = 1.0
	elif game.motion_scale() <= 0.0:
		slime.modulate.a = 0.6
	elif _blink <= 0.0:
		_blink = BLINK_GAP
		slime.modulate.a = 0.45 if slime.modulate.a > 0.9 else 1.0


## SLIME SPLAT: every awake lurker standing on one of `tiles` is stunned for `seconds`.
func stun_tiles(tiles: Array[Vector2i], seconds: float) -> int:
	var count := 0
	for l in lurkers:
		if l.awake and Vector2i((l.pos / TILE).floor()) in tiles:
			l.stun = maxf(l.stun, seconds)
			count += 1
	return count


## A leap landed at `pos`: an awake lurker there is bonked (stunned, thrown a cell away from the slime).
func on_landing(pos: Vector2) -> int:
	var count := 0
	for l in lurkers:
		if l.awake and pos.distance_to(l.pos) <= BONK_DIST:
			_bonk(l, pos)
			count += 1
	return count


func _bonk(l: Lurker, from: Vector2) -> void:
	bonks += 1
	l.stun = Economy.LURKER_STUN_BONK
	l.slide = SLIDE_TIME
	l.pos = MazeGenerator.cell_center(cell_of(l.pos), TILE)
	l.cell = cell_of(l.pos)
	l.prev = l.cell
	var best := l.cell
	var best_d := -1.0
	for n in MazeGenerator.open_neighbors(maze, l.cell):
		var d := MazeGenerator.cell_center(n, TILE).distance_squared_to(from)
		if d > best_d:
			best_d = d
			best = n
	l.to = best
	Fx.burst(game, l.pos, EYE_COLOR[l.kind], 8, 40.0, Vector2.UP, 160.0, false)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("lurk_bonk", -18.0, 1.2)
