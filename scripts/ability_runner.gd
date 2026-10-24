class_name AbilityRunner
extends Node2D

## ABILITIES v1 in a level (rules and geometry: Abilities, numbers: Economy.ABILITIES and the RIFLE_ /
## SPLAT_ / KAZE_ constants; design: docs/design/upgrades-v2.md "Abilities v1"). Made by game.gd
## (`create`) when the run has any ability: never in hard mode, never with the
## abilities switched off. Each owned ability has Abilities.charges uses per attempt (the scene is
## rebuilt by every restart, new maze, next level and Descent floor, so they refill there). Its key
## (Abilities.action, 1 / 2 / 3 by default) or touch button fires it along the slime's facing,
## snapped to the grid (Abilities.aim), while the slime is on the ground and free (gliding or still).
## The reveals are real reveals (fog bytes, survey tiles), so they count on the trail map; par,
## routes, the randomizer payout and seed codes never change. The autoplay bot never presses them.
## `flush()` completes every shot, bomb, dash and goo drop at once (tests).

## Draw order: above the fog (10) and the lantern (11), so shots glow over unexplored dark.
const Z := 12
## The goo trail's radius (game.TRAIL_RADIUS) for the dash's smear, and the bomb's splash (a landing's).
const TRAIL_RADIUS := Economy.REVEAL_RADIUS
const BURST_RADIUS := 18.0  # (11 for the old 3x3 blast)

var game: Node2D
var slime: Slime
## Owned abilities' levels (id -> 1-3) and the uses left this attempt.
var levels := {}
var charges := {}
## Abilities fired this attempt.
var uses := 0
## Shots, bombs and goo drops still flying (each has finish()).
var flying: Array[Node2D] = []
var dashing := false
var _dash_painted := Vector2.ZERO
var _kaze_uses := 0
## AIM MODE (owner, 2026-10-22): the SLIME SNIPER / GOO GRENADE key doesn't fire at once; the slime
## stops (Slime.aim_lock), the direction keys / stick turn the aim (4 ways, shown by the guide drawn
## here) and JUMP or a left click fires it; the same key again cancels (nothing spent), the other's
## key switches to it. SLIMAKAZE and the touch buttons still fire at once. "" = not aiming.
const AIMED: Array[String] = ["rifle", "splat"]
const AIM_DOT := Color(1.0, 1.0, 1.0, 0.75)
var aiming := ""
var aim_dir := Vector2i.RIGHT
## Ticks a straight aim must hold after a diagonal one before it takes over (see _aim_step).
const AIM_SETTLE := 6
var _aim_settle := 0


## The runner for `owner_game`'s run (added as its child), or null when this run has no abilities.
static func create(owner_game: Node2D) -> AbilityRunner:
	var progress: Node = owner_game.progress
	if progress == null or not Abilities.allowed_in(owner_game) or not Economy.abilities_on():
		return null
	var owned := {}
	for id in Abilities.ids():
		var level: int = progress.ability_level(id)
		if level > 0 and Demo.ability_open(id):  # (the demo: only its abilities, even with a full save)
			owned[id] = level
	if owned.is_empty():
		return null
	var runner := AbilityRunner.new()
	runner.game = owner_game
	runner.slime = owner_game.slime
	runner.levels = owned
	for id: String in owned:
		runner.charges[id] = Abilities.charges(id, owned[id])
	runner.z_index = Z
	owner_game.add_child(runner)
	runner.slime.dash_hit.connect(runner._on_dash_hit)
	owner_game.touch_controls.ability_tapped.connect(runner.use)
	runner._refresh()
	return runner


## The strip the HUD and the touch buttons show: [{id, left, max}] in Abilities order.
func strip() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in Abilities.ids():
		if levels.has(id):
			out.append({id = id, left = int(charges[id]), max = Abilities.charges(id, levels[id])})
	return out


func _refresh() -> void:
	game.hud.set_abilities(strip())
	game.touch_controls.set_abilities(strip())


func _physics_process(_delta: float) -> void:
	if dashing:
		_paint_dash()
	if aiming != "":
		_aim_step()
		return
	if game.random_map_view != null:  # (a SLIME SENSE peek is up: only its key, to close it)
		if levels.has("sense") and Input.is_action_just_pressed(Abilities.action("sense")):
			use("sense")
		return
	for id: String in levels:
		if Input.is_action_just_pressed(Abilities.action(id)):
			if id in AIMED:
				start_aim(id)
			else:
				use(id)
			break


## Enters aim mode for `id` (see AIMED) if it could fire now; false (a click) if not.
func start_aim(id: String) -> bool:
	if not can_use(id):
		_sfx("click", -10.0)
		return false
	aiming = id
	aim_dir = Abilities.aim(slime.facing)
	slime.aim_lock = true
	_sfx("click", -6.0)
	queue_redraw()
	return true


## Leaves aim mode without firing (nothing spent).
func cancel_aim() -> void:
	if aiming == "":
		return
	aiming = ""
	slime.aim_lock = false
	queue_redraw()


## Fires the aimed ability along aim_dir and leaves aim mode. The slime stays locked until the tick
## is over, so the JUMP press that fired doesn't also start a leap.
func fire_aim() -> bool:
	if aiming == "":
		return false
	var id := aiming
	aiming = ""
	queue_redraw()
	slime.facing = Vector2(aim_dir).normalized()
	var fired := use(id, aim_dir)
	slime.set_deferred("aim_lock", false)
	return fired


func _aim_step() -> void:
	if game.finished or slime.frozen or int(charges.get(aiming, 0)) <= 0:
		cancel_aim()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var want := Abilities.aim8(v)
	# Letting go of a diagonal never lands both keys on the same tick: a straight aim right after a
	# diagonal one has to hold AIM_SETTLE ticks first (so the diagonal stays aimed for JUMP).
	var diagonal_left := aim_dir.x != 0 and aim_dir.y != 0 and (want.x == 0 or want.y == 0)
	_aim_settle = _aim_settle + 1 if v != Vector2.ZERO and want != aim_dir and diagonal_left else 0
	if v != Vector2.ZERO and want != aim_dir and (not diagonal_left or _aim_settle >= AIM_SETTLE):
		aim_dir = want
		_aim_settle = 0
		slime.facing = Vector2(aim_dir).normalized()
		queue_redraw()
	if Input.is_action_just_pressed("jump"):
		fire_aim()
		return
	for id: String in levels:
		if Input.is_action_just_pressed(Abilities.action(id)):
			if id == aiming or not id in AIMED:
				cancel_aim()  # (the same key again: never mind; SLIMAKAZE's key backs out first)
			else:
				aiming = id  # (the other aimed ability: switch to it)
				queue_redraw()
			return


## A left click (mouse) fires while aiming.
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if aiming != "" and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		fire_aim()


## The aim guide: SNIPER, a dot on each tile the shot would cross; GRENADE, its blast square where it
## would land.
func _draw() -> void:
	if aiming == "":
		return
	var tile := Vector2i((slime.position / Abilities.TILE).floor())
	var size := float(Abilities.TILE)
	if aiming == "rifle":
		for t in Abilities.rifle_tiles(game.maze, tile, aim_dir, Abilities.rifle_range(levels.rifle)):
			draw_rect(Rect2((Vector2(t) + Vector2(0.5, 0.5)) * size - Vector2.ONE, Vector2(2, 2)), AIM_DOT)
	else:
		var land := Abilities.lob_tile(game.maze, tile, aim_dir, Abilities.splat_range(levels.splat))
		var r := Economy.SPLAT_AREA
		var box := Rect2(Vector2(land - Vector2i.ONE * r) * size, Vector2.ONE * size * (2 * r + 1))
		draw_rect(box.grow(-1.0), AIM_DOT, false, 1.0)
		draw_rect(Rect2((Vector2(land) + Vector2(0.5, 0.5)) * size - Vector2(1.5, 1.5), Vector2(3, 3)), AIM_DOT)


## True if ability `id` can fire right now: owned, a use left, the slime on the ground and free (not
## leaping, charging, stunned, dashing, frozen; the run not over) and, for RIFLE / SPLAT, more slime
## in the meter than one use costs (SLIMAKAZE may use the last of it).
func can_use(id: String) -> bool:
	if int(charges.get(id, 0)) <= 0 or game.finished or slime.frozen or slime.state != Slime.State.GLIDE:
		return false
	return id == "kaze" or game.slime_remaining > Abilities.slime_cost(id)


## Fires ability `id` along the slime's facing. False (nothing spent) if it can't now, or (SLIMAKAZE)
## when a wall is right ahead.
## `aimed`: the aim mode's direction (8 ways); zero = the facing snapped to the grid (4 ways).
func use(id: String, aimed := Vector2i.ZERO) -> bool:
	if id == "sense":
		return _peek()
	if not can_use(id):
		_sfx("click", -10.0)
		return false
	var dir := Abilities.aim(slime.facing) if aimed == Vector2i.ZERO else aimed
	var tile := Vector2i((slime.position / Abilities.TILE).floor())
	match id:
		"rifle":
			_fire_rifle(tile, dir)
		"splat":
			_throw_splat(tile, dir)
		"kaze":
			if not _start_kaze(tile, dir):
				_sfx("click", -10.0)
				return false
	charges[id] = int(charges[id]) - 1
	uses += 1
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.note_ability_used(id)
	if id != "kaze":
		game.spend_slime(Abilities.slime_cost(id))  # (SLIMAKAZE pays on impact)
	DevLog.log_event(get_tree(), "ability " + id, game)
	_refresh()
	return true


## SLIME SENSE: opens the maze's map mid-run (Game.toggle_run_map), one peek per use; with the map
## up it closes it (free).
func _peek() -> bool:
	if game.random_map_view != null:
		game.toggle_run_map()
		return false
	if not can_use("sense"):
		_sfx("click", -10.0)
		return false
	game.toggle_run_map()
	if game.random_map_view == null:
		return false
	charges.sense = int(charges.sense) - 1
	uses += 1
	DevLog.log_event(get_tree(), "ability sense", game)
	_refresh()
	return true


## Completes everything in flight at once: the dash (and its splatter), shots, bombs, goo drops.
func flush() -> void:
	for i in 64:
		if dashing and slime.state == Slime.State.DASH:
			slime.finish_dash()
			slime.reset_physics_interpolation()  # jumped to the wall: drawn there at once, not swept
		if flying.is_empty():
			return
		for node in flying.duplicate():
			if is_instance_valid(node):
				node.finish()


# ---------------------------------------------------------------- SLIME RIFLE

func _fire_rifle(tile: Vector2i, dir: Vector2i) -> void:
	var tiles := Abilities.rifle_tiles(game.maze, tile, dir, Abilities.rifle_range(levels.rifle))
	var lane := (Vector2(tile) + Vector2(0.5, 0.5)) * Abilities.TILE
	var from := lane
	if dir.x != 0 and dir.y != 0:
		from = lane  # (diagonal: from its tile's centre, along the tiles' diagonal)
	elif dir.x != 0:
		from.x = slime.position.x
	else:
		from.y = slime.position.y
	# It ends near the far edge of its last tile, or in the middle of it when that is a wall (the
	# maze's outer edge), splashing there.
	var end := (Vector2(tiles[-1]) + Vector2(0.5, 0.5)) * Abilities.TILE
	if not game.is_wall_tile(tiles[-1]):
		end += Vector2(dir).normalized() * (Abilities.TILE / 2.0 - 3.0)  # (its 2 px streak stays inside its range)
	var shot := GooShot.new()
	shot.runner = self
	shot.tiles = tiles
	shot.dir = Vector2(dir).normalized()
	shot.from = from
	shot.end = end
	shot.color = game.skin_color
	_launch(shot, from)
	_sfx("goo_shot", -3.0)
	Fx.burst(game, from + Vector2(dir) * 6.0, game.skin_color, 6, 40.0, Vector2(dir), 25.0, game.rainbow)
	game.shake(1.0, 0.12, -Vector2(dir))  # a little recoil


## A shot reached tile `index` of its path: that tile (and the walls around it) is revealed.
func _shot_tile(tile: Vector2i) -> void:
	game.reveal_tile(tile)


func _shot_hit(end: Vector2, dir: Vector2) -> void:
	if game.is_wall_tile(Vector2i((end / Abilities.TILE).floor())):
		game._paint_cells(end, 4.0, true)  # a splash on the maze's outer wall (out of range: it just bursts)
	Fx.burst(game, end - dir * 2.0, game.skin_color, 10, 45.0, -dir, 70.0, game.rainbow)
	_sfx("splat", -9.0, 1.35)


# ---------------------------------------------------------------- SLIME SPLAT

func _throw_splat(tile: Vector2i, dir: Vector2i) -> void:
	var land := Abilities.lob_tile(game.maze, tile, dir, Abilities.splat_range(levels.splat))
	var bomb := GooBomb.new()
	bomb.runner = self
	bomb.from = slime.position
	bomb.to = (Vector2(land) + Vector2(0.5, 0.5)) * Abilities.TILE
	bomb.tile = land
	bomb.color = game.skin_color
	_launch(bomb, bomb.from)
	_sfx("goo_lob", -4.0)


func _bomb_burst(tile: Vector2i, at: Vector2) -> void:
	var burst := Abilities.burst_tiles(game.maze, tile)
	for t in burst:
		game.reveal_tile(t, false)
	if game.lurkers != null:
		game.lurkers.stun_tiles(burst, Economy.LURKER_STUN_SPLAT)  # (BM-01: the splat stuns lurkers in its blast)
	game._paint_goo(at, BURST_RADIUS)
	var glow := Fx.make_light(32 * (2 * Economy.SPLAT_AREA + 1), Color(game.skin_color, 0.55))  # 96 for a 3x3 blast
	glow.position = at
	glow.z_index = 1  # (relative: above this runner, so above the fog)
	add_child(glow)
	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 0.0, Economy.SPLAT_GLOW_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(glow.queue_free)
	Fx.burst(game, at, game.skin_color, 24, 70.0, Vector2.UP, 180.0, game.rainbow)
	_sfx("goo_burst", -2.0)
	game.shake(2.0, 0.2)


# ---------------------------------------------------------------- SLIMAKAZE

func _start_kaze(tile: Vector2i, dir: Vector2i) -> bool:
	var stop := Abilities.dash_tile(game.maze, tile, dir)
	if stop == tile:
		return false  # a wall right ahead: no room to build up speed
	dashing = true
	_dash_painted = slime.position
	slime.dash(Abilities.dash_point(stop, dir), Vector2(dir), Economy.KAZE_SPEED, Economy.KAZE_STUN)
	_sfx("jump", -2.0, 0.6)
	return true


## Lays the goo trail along the dash so far (4 px apart, so it reads as one smear).
func _paint_dash() -> void:
	var to := slime.position
	var steps := ceili(_dash_painted.distance_to(to) / 4.0)
	for i in range(1, steps + 1):
		game._paint_goo(_dash_painted.lerp(to, float(i) / steps), TRAIL_RADIUS)
	_dash_painted = to


## The dash reached the goal (game._on_goal_body_entered, before it decides win or dry-up): it
## stops there and pays its Abilities.slime_cost("kaze") now (no wall, so no splat or splatter).
func settle_at_goal() -> void:
	if not dashing:
		return
	slime.stop_dash()
	_paint_dash()
	dashing = false
	game.spend_slime(Abilities.slime_cost("kaze"))
	game.last_slime_pos = slime.position


func _on_dash_hit(wall_normal: Vector2) -> void:
	if not dashing:
		return
	_paint_dash()
	dashing = false
	if game.finished:
		return
	game.spend_slime(Abilities.slime_cost("kaze"))
	game.last_slime_pos = slime.position
	game._stain_wall(slime.position, wall_normal)
	game.shake(Economy.KAZE_SHAKE, Economy.KAZE_SHAKE_TIME, -wall_normal * 3.0)
	Fx.burst(game, slime.position - wall_normal * Slime.RADIUS, game.skin_color, 40, 120.0, wall_normal, 100.0, game.rainbow)
	_sfx("kaze", 0.0)
	var impact := Vector2i((slime.position / Abilities.TILE).floor())
	var seed_value := Abilities.splatter_seed(game.maze_seed, impact, _kaze_uses)
	_kaze_uses += 1
	var center := slime.position
	for blob in Abilities.splatter(game.maze, impact, seed_value, Abilities.kaze_radius(levels.kaze)):
		var drop := SplatDrop.new()
		drop.runner = self
		drop.tile = blob.tile
		drop.from = center
		drop.to = (Vector2(blob.tile) + Vector2(0.5, 0.5)) * Abilities.TILE + blob.offset
		drop.radius = blob.radius
		drop.color = game.skin_color
		drop.time = 0.1 + center.distance_to(drop.to) / 260.0
		_launch(drop, center)


func _drop_landed(tile: Vector2i, at: Vector2, radius: float) -> void:
	game.reveal_tile(tile)
	game._paint_goo(at, radius)


# ---------------------------------------------------------------- shared

func _launch(node: Node2D, at: Vector2) -> void:
	node.position = at
	flying.append(node)
	add_child(node)


func _landed(node: Node2D) -> void:
	flying.erase(node)
	node.queue_free()


func _sfx(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name, volume_db, pitch)


## The goo shot: a glowing blob racing along the lane, revealing each tile it enters and painting
## a thin streak behind it, until it splashes on the wall.
class GooShot extends Node2D:
	var runner: AbilityRunner
	var tiles: Array[Vector2i] = []
	var dir := Vector2.RIGHT
	var from := Vector2.ZERO
	var end := Vector2.ZERO
	var color := Color.WHITE
	var traveled := 0.0
	var _next := 0
	var _done := false

	func _ready() -> void:
		var glow := Fx.make_light(24, Color(color, 0.6))
		add_child(glow)
		_advance(0.0)

	func _physics_process(delta: float) -> void:
		_advance(Economy.RIFLE_SPEED * delta)

	func finish() -> void:
		_advance(INF)

	func _advance(step: float) -> void:
		if _done:
			return
		var length := from.distance_to(end)
		var before := traveled
		traveled = minf(traveled + step, length)
		position = from + dir * traveled
		runner.game.paint_streak(from + dir * before, position)
		# A tile is revealed once the shot is inside it (its own tile at once).
		while _next < tiles.size():
			var tile_center := (Vector2(tiles[_next]) + Vector2(0.5, 0.5)) * Abilities.TILE
			if _next > 0 and (tile_center - dir * (Abilities.TILE / 2.0) - from).dot(dir) > traveled:
				break
			runner._shot_tile(tiles[_next])
			_next += 1
		queue_redraw()
		if traveled >= length:
			_done = true
			runner._shot_hit(end, dir)
			runner._landed(self)

	func _draw() -> void:
		var back := -dir
		var side := dir.orthogonal()
		var dark := color.darkened(0.45)
		for i in range(1, 6):  # a short fading tail
			draw_rect(Rect2((back * (i + 1) - Vector2(0.5, 0.5)).round(), Vector2.ONE), Color(color, 0.7 - i * 0.12))
		draw_rect(Rect2((-side * 1.0 - back - Vector2.ONE).round(), Vector2(3, 3)), dark)
		draw_rect(Rect2((-side * 1.0 - back - Vector2.ONE).round() + Vector2(0, 0), Vector2(2, 2)), color)
		draw_rect(Rect2((dir * 1.0 - Vector2(0.5, 0.5)).round(), Vector2.ONE), color.lightened(0.6))


## The goo bomb: lobbed in an arc (with a shadow on the floor), it bursts where it lands.
class GooBomb extends Node2D:
	var runner: AbilityRunner
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var tile := Vector2i.ZERO
	var color := Color.WHITE
	var t := 0.0
	var _done := false

	func _physics_process(delta: float) -> void:
		t += delta / Economy.SPLAT_FLIGHT
		if t >= 1.0:
			finish()
		else:
			position = from.lerp(to, t).round()
			queue_redraw()

	func finish() -> void:
		if _done:
			return
		_done = true
		position = to
		runner._bomb_burst(tile, to)
		runner._landed(self)

	func _draw() -> void:
		var height := roundf(sin(PI * t) * (6.0 + from.distance_to(to) / 8.0))
		draw_rect(Rect2(Vector2(-2, 1), Vector2(5, 2)), Color(0, 0, 0, 0.35))  # the shadow
		var c := Vector2(0, -height)
		draw_rect(Rect2(c + Vector2(-2, -3), Vector2(5, 5)), color.darkened(0.5))
		draw_rect(Rect2(c + Vector2(-1, -2), Vector2(3, 3)), color)
		draw_rect(Rect2(c + Vector2(-1, -2), Vector2.ONE), color.lightened(0.6))
		draw_rect(Rect2(c + Vector2(1, -5), Vector2(1, 2)), Color8(255, 205, 117))  # the lit fuse


## One drop of the SLIMAKAZE splatter: flies out from the impact and splats onto its tile.
class SplatDrop extends Node2D:
	var runner: AbilityRunner
	var tile := Vector2i.ZERO
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var radius := 3.0
	var color := Color.WHITE
	var time := 0.2
	var t := 0.0
	var _done := false

	func _physics_process(delta: float) -> void:
		t += delta / maxf(time, 0.01)
		if t >= 1.0:
			finish()
		else:
			position = from.lerp(to, t) + Vector2(0, -roundf(sin(PI * t) * 10.0))
			position = position.round()
			queue_redraw()

	func finish() -> void:
		if _done:
			return
		_done = true
		runner._drop_landed(tile, to, radius)
		runner._landed(self)

	func _draw() -> void:
		draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), color)
