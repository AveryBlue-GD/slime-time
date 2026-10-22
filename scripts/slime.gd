class_name Slime
extends CharacterBody2D

## Free gliding movement plus a charge jump, animated from assets/sprites/slime_sheet.png.
## Hold "jump" to charge: the slime slides to a stop and the movement keys only aim.
## Release to leap in the aimed direction. Hitting a wall mid-air is a splat.
## Speeds are in pixels per second at the 320x180 base resolution.

signal jump_landed(intended_distance: float, hit_wall: bool, wall_normal: Vector2)
## A knockback ricochet off another wall; `impact` = speed into the wall (px/s).
signal bounced(wall_normal: Vector2, impact: float)
## A leap begins: the slime moves along the floor at `floor_velocity` for `flight_time` seconds
## (a hat uses this to fly along with it).
signal launched(floor_velocity: Vector2, flight_time: float)

## Emitted when a SLIMAKAZE dash (Abilities) hits its wall (`wall_normal` points back at the slime).
signal dash_hit(wall_normal: Vector2)

## DASH: the SLIMAKAZE ability's straight dash to a wall (set by AbilityRunner through dash()).
enum State { GLIDE, CHARGING, AIRBORNE, STUNNED, DASH }

const TILE := 16
## Slime sheet frames are this many px square (slime_sheet.json frame_size).
const FRAME_SIZE := 20
## The eyes' dark color in the sheet (tools/make_placeholder_art.py; not a goo shade, so no skin swaps it).
const EYE_COLOR := Color8(26, 28, 44)
## Collision radius: the body is 14 px across in a 16 px corridor, a snug fit.
const RADIUS := 7.0
const CHARGE_TIME := 1.5
const MIN_JUMP_TILES := 1.0
const MAX_JUMP_TILES := 8.0
const JUMP_SPEED := 220.0
const SPLAT_STUN := 0.3
## A jump press made while the slime can't leap yet (stunned, airborne) is remembered for this
## long and, if the key is still down when it can charge again, starts the charge at once.
## A mere tap never auto-fires a leap.
const JUMP_BUFFER := 0.5
## Hit-stop: the slime's picture holds for up to this long on a hard splat (seconds, scaled by
## power; none with Reduce Motion). Only the sprite stops: movement, timers and the run clock go on.
const HIT_STOP_MAX := 0.06
## Splat knockback, pinball style. The jump distance still left when the slime hits a wall is
## its momentum: as a speed, sqrt(2 * friction * leftover) (the speed that would glide that far).
## Each wall hit splits the velocity into the part going into the wall, which bounces back
## scaled by RESTITUTION, and the part along the wall, which keeps WALL_GRIP of itself. So a
## head-on splat slides straight back BOUNCE_FACTOR (= RESTITUTION^2) of the leftover distance,
## an angled one ricochets off at an angle and can carry on into more walls (each one sapping
## energy) and a weak hop barely leaves the wall.
const BOUNCE_FACTOR := 0.4
const RESTITUTION := 0.632  # sqrt(BOUNCE_FACTOR)
const WALL_GRIP := 0.85
## Hitting a wall slower than this (px/s into it) just slides along it instead of bouncing.
const MIN_BOUNCE_SPEED := 30.0
## How far (px) a straight leap may be nudged sideways to slip past a corner it only clips.
const CORNER_LEEWAY := 3.0
## Ricochets closer together than this share one splat effect (narrow corridors rattle).
const BOUNCE_FX_GAP := 0.08
## Below this speed a knockback counts as over.
const KNOCKBACK_END_SPEED := 6.0
## How strongly a single-direction press pulls the slime onto the center line of its lane.
const LANE_PULL := 10.0
## Below this speed the slime shows its idle wobble instead of gliding.
const IDLE_SPEED := 6.0
const LAND_ANIM_TIME := 0.25
const RECOVER_ANIM_TIME := 0.15
## Seconds between squish sounds while gliding at full speed.
const SQUISH_INTERVAL := 0.28
## Share of a jump spent on the launch frames before the airborne frames.
const LAUNCH_SHARE := 0.15
## Gliding faster than this flicks goo droplets off behind the slime.
const DRIP_SPEED := 30.0
## Animation suffixes for 8 directions, in 45-degree steps clockwise from east (y points down).
const DIR_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

@export var max_speed := 72.0
@export var acceleration := 420.0
@export var friction := 260.0

## Seconds for a full leap charge and the splat stun: CHARGE_TIME / SPLAT_STUN, shortened by the
## ticket workshop's QUICK CHARGE and STICKY (game.gd `_apply_workshop`; never in hard mode).
var charge_time := CHARGE_TIME
var splat_stun := SPLAT_STUN
## Set by the game when the slime dries up or reaches the chalice.
var frozen := false
## False while the jump key means something else (the hub: next to a station it opens it).
var can_charge := true
## Maze helpers: lining up with the 16 px corridor lanes and slipping past corners a leap only
## clips. Off in the hub, a round room with no lanes (they'd tug the slime at invisible lines).
var maze_assist := true
var state := State.GLIDE
## 0-100 while charging.
var charge := 0.0
## Unit vector the slime is aiming/moving in (8 directions with keyboard input).
var facing := Vector2.RIGHT

var _jump_dir := Vector2.ZERO
var _tension := -1.0  # last charge tension sent to the skin shader
var _jump_distance := 0.0
var _jump_traveled := 0.0
## Distance actually flown by the latest jump (shorter than planned when it hits a wall).
var last_jump_traveled := 0.0
## True while sliding from a splat's knockback (that slide costs no slime).
var knocked_back := false
var _stun_left := 0.0
var _jump_buffer_left := 0.0
var _hit_stop_left := 0.0
var _bounce_fx_left := 0.0
## Wall ricochets since the last launch (after the splat itself).
var ricochets := 0
var _splat_side := "n"
var _land_anim_left := 0.0
var _squish_left := 0.0
var _recover_anim_left := 0.0
## Set by play_dry_up()/play_celebrate(); overrides the state-driven animation.
var _special_anim := ""
var _dash_target := Vector2.ZERO
## The dash's first leg: straight sideways onto the target's lane (as the lane assist would), so the
## body never cuts across a wall corner; `_dash_on_lane` once it is there.
var _dash_lane := Vector2.ZERO
var _dash_on_lane := true
var _dash_speed := 0.0
var _dash_stun := 0.0
## Soft bounce test (Economy.soft_bounce_on, read at launch; see _soft_hit). `last_hit_glancing`: the
## latest wall hit glanced off (the game then skips the splat's shake and big burst).
var last_hit_glancing := false
var _soft := false
## The current knockback is a soft slide (_soft_step: straight, braking evenly, no ricochets): first
## held still `_soft_hold_left` s (the squash), then `_soft_vel`, braking at `_soft_decel` px/s^2.
var _soft_slide := false
var _soft_hold_left := 0.0
var _soft_vel := Vector2.ZERO
var _soft_decel := 0.0
## The stun's full length (the splat frames run over it) and the recover animation after it.
var _stun_total := SPLAT_STUN
var _recover_after := RECOVER_ANIM_TIME
## Coin catch test (Economy.coin_catch_on, CoinCatch): a purely cosmetic hop of the SPRITE (never the
## body): seconds into it (< 0 = none) and the whole px it lifts the sprite this tick (added on top of
## whatever the tick set, taken off again at the start of the next one).
var catch_t := -1.0
var _hop_px := 0.0

static var _sprite_frames: SpriteFrames
## Top-center of the body for each animation frame (see head_point), and the sheet's pixels.
static var _heads := {}
static var _sheet_image: Image
var _drips: CPUParticles2D

## Where the slime and its sprite were when this physics tick began: what the renderer draws them
## between ticks from when physics interpolation is on (high refresh, see Transition), so drawn_shift
## can tell the nodes placed by hand each frame (fog hole, light, hat, camera) where it is drawn.
var _tick_from := Vector2.ZERO
var _sprite_from := Vector2.ZERO
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow


static func jump_distance_for(charge_value: float) -> float:
	return lerpf(MIN_JUMP_TILES, MAX_JUMP_TILES, clampf(charge_value, 0.0, 100.0) / 100.0) * TILE


## Builds SpriteFrames from the generated sheet + manifest (once, shared by every slime).
static func load_sprite_frames() -> SpriteFrames:
	if _sprite_frames:
		return _sprite_frames
	var sheet: Texture2D = preload("res://assets/sprites/slime_sheet.png")
	var manifest: Dictionary = preload("res://assets/sprites/slime_sheet.json").data
	var size := int(manifest.frame_size)
	_sprite_frames = SpriteFrames.new()
	_sprite_frames.remove_animation("default")
	for anim_name: String in manifest.anims:
		var info: Dictionary = manifest.anims[anim_name]
		_sprite_frames.add_animation(anim_name)
		_sprite_frames.set_animation_speed(anim_name, maxf(info.fps, 1.0))
		_sprite_frames.set_animation_loop(anim_name, info.loop)
		for i in int(info.frames):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(i * size, int(info.row) * size, size, size)
			_sprite_frames.add_frame(anim_name, frame)
	return _sprite_frames


## Which way the splat squashes ("n", "e", "s" or "w"; there are no diagonal splat frames): the
## side the wall is on. A corner hit gives a diagonal normal, so this picks its stronger axis.
static func splat_side(wall_normal: Vector2) -> String:
	if absf(wall_normal.x) > absf(wall_normal.y):
		return "w" if wall_normal.x > 0.0 else "e"
	return "n" if wall_normal.y > 0.0 else "s"


## Top-center of the slime's body in a frame, relative to the sprite's center: where a hat sits.
## Found from the sheet's pixels (the topmost row of the body), so it follows every squash,
## stretch and bounce of the animation. Whole pixels: a body that's an odd pixel off center (a
## half-pixel center) keeps the hat where it was rather than flicking it a pixel each frame.
static func head_point(anim: String, frame: int) -> Vector2:
	var key := "%s:%d" % [anim, frame]
	if _heads.has(key):
		return _heads[key]
	var point := Vector2(0, -7)
	var rows := _body_rows(anim, frame)
	if not rows.is_empty():
		var top: Vector3i = rows[0]
		var center := (top.y + top.z + 1) / 2.0 - FRAME_SIZE / 2.0
		point = Vector2(float(int(center)), top.x - FRAME_SIZE / 2.0)  # int() rounds +-0.5 to 0
	_heads[key] = point
	return point


## The eyes' dark pixels in a frame, relative to its head point (hats keep off them: Hats.lift).
static func eye_points(anim: String, frame: int) -> Array[Vector2i]:
	var key := "e%s:%d" % [anim, frame]
	if _heads.has(key):
		return _heads[key]
	var out: Array[Vector2i] = []
	var rows := _body_rows(anim, frame)
	if not rows.is_empty() and anim != "dry":  # (drying up, that color is the crust's cracks)
		var region := (load_sprite_frames().get_frame_texture(anim, frame) as AtlasTexture).region
		var head := Vector2i(head_point(anim, frame)) + Vector2i(FRAME_SIZE / 2, FRAME_SIZE / 2)
		for r: Vector3i in rows:
			for x in range(r.y, r.z + 1):
				var c := _sheet_image.get_pixel(int(region.position.x) + x, int(region.position.y) + r.x)
				if c.a > 0.5 and c.is_equal_approx(EYE_COLOR):
					out.append(Vector2i(x, r.x) - head)
	_heads[key] = out
	return out


## Loads the slime sheet's pixels into _sheet_image once (for the body measurements below).
static func _load_sheet_image() -> void:
	if _sheet_image == null:
		_sheet_image = preload("res://assets/sprites/slime_sheet.png").get_image()
		if _sheet_image.is_compressed():
			_sheet_image.decompress()


## The body's rows in a frame, top down, as (y, left x, right x): only its largest 4-connected
## blob of solid pixels, so loose sparkles (celebrate) and goo flecks (splats) don't count.
## (tools/make_hats.py measures the head the same way.)
static func _body_rows(anim: String, frame: int) -> Array[Vector3i]:
	var key := "r%s:%d" % [anim, frame]
	if _heads.has(key):
		return _heads[key]
	var rows: Array[Vector3i] = []
	var frames := load_sprite_frames()
	if frames.has_animation(anim) and frame < frames.get_frame_count(anim):
		var region := (frames.get_frame_texture(anim, frame) as AtlasTexture).region
		_load_sheet_image()
		var w := int(region.size.x)
		var h := int(region.size.y)
		var solid := {}
		for y in h:
			for x in w:
				if _sheet_image.get_pixel(int(region.position.x) + x, int(region.position.y) + y).a > 0.5:
					solid[Vector2i(x, y)] = true
		var seen := {}
		var best: Array[Vector2i] = []
		for y in h:
			for x in w:
				var start := Vector2i(x, y)
				if not solid.has(start) or seen.has(start):
					continue
				var blob: Array[Vector2i] = []
				var todo: Array[Vector2i] = [start]
				seen[start] = true
				while not todo.is_empty():
					var p: Vector2i = todo.pop_back()
					blob.append(p)
					for n: Vector2i in [p + Vector2i.RIGHT, p + Vector2i.LEFT, p + Vector2i.DOWN, p + Vector2i.UP]:
						if solid.has(n) and not seen.has(n):
							seen[n] = true
							todo.append(n)
				if blob.size() > best.size():
					best = blob
		var spans := {}
		for p in best:
			var span: Vector2i = spans.get(p.y, Vector2i(p.x, p.x))
			spans[p.y] = Vector2i(mini(span.x, p.x), maxi(span.y, p.x))
		var ys := spans.keys()
		ys.sort()
		for y: int in ys:
			rows.append(Vector3i(y, spans[y].x, spans[y].y))
	_heads[key] = rows
	return rows


## The opaque pixels' bounding box in a frame, relative to the sprite's center (the stopwatch skin
## fits its clock face inside it, so the clock squashes and stretches with the body).
static func body_box(anim: String, frame: int) -> Rect2:
	var key := "b%s:%d" % [anim, frame]
	if _heads.has(key):
		return _heads[key]
	var frames := load_sprite_frames()
	var box := Rect2(-7, -7, 14, 14)
	if frames.has_animation(anim) and frame < frames.get_frame_count(anim):
		var region := (frames.get_frame_texture(anim, frame) as AtlasTexture).region
		_load_sheet_image()
		var found := Rect2()
		var any := false
		for y in int(region.size.y):
			for x in int(region.size.x):
				if _sheet_image.get_pixel(int(region.position.x) + x, int(region.position.y) + y).a > 0.5:
					found = found.expand(Vector2(x, y)) if any else Rect2(x, y, 0, 0)
					any = true
		if any:
			box = Rect2(found.position - region.size / 2.0, found.size + Vector2.ONE)
	_heads[key] = box
	return box


## How wide the slime's head is in a frame: its body's width 3 px below its top (14 when idle,
## narrower when stretched into a leap or squeezed sideways in a splat, wider when squashed).
## Hats pick their width by it (Hats.width_for).
static func head_width(anim: String, frame: int) -> int:
	var rows := _body_rows(anim, frame)
	if rows.size() < 4:
		return 14
	return rows[3].z - rows[3].y + 1


## Name suffix ("e", "se", ...) for the 45-degree direction closest to v.
static func dir_name(v: Vector2) -> String:
	return DIR_NAMES[wrapi(roundi(v.angle() / (PI / 4.0)), 0, 8)]


## The way a leap aimed along `aim` goes: `aim` itself, or with diagonal leaps off
## (Economy.diagonal_leap_on) the stronger axis of it (an exact diagonal goes along x).
static func leap_dir(aim: Vector2) -> Vector2:
	if Economy.diagonal_leap_on() or aim.x == 0.0 or aim.y == 0.0:
		return aim
	return Vector2(signf(aim.x), 0.0) if absf(aim.x) >= absf(aim.y) else Vector2(0.0, signf(aim.y))


func _ready() -> void:
	# Moved on physics ticks, so drawn between them when interpolation is on (the scene root opts out,
	# Transition); the camera places itself (game.gd) and never interpolates (slime.tscn).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	get_tree().physics_frame.connect(_mark_tick)
	_mark_tick()
	sprite.sprite_frames = load_sprite_frames()
	sprite.material = Skins.make_material(Skins.get_preset(Skins.DEFAULT).color)
	sprite.play("idle")
	var skin := sprite.material as ShaderMaterial
	skin.set_shader_parameter("gloss", 1.0)
	var progress := get_node_or_null("/root/Progress")
	skin.set_shader_parameter("shine_motion", 0.0 if progress and progress.reduce_motion else 1.0)
	_drips = Fx.make_drips()
	_drips.show_behind_parent = true
	_drips.color = Skins.get_preset(Skins.DEFAULT).color
	add_child(_drips)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION and is_node_ready():
		_mark_tick()  # a teleport: drawn where it is, not swept from where it was


## The start of a physics tick (SceneTree.physics_frame, before any node moves): the renderer's
## "previous" transforms for the slime and its sprite.
func _mark_tick() -> void:
	_tick_from = position
	_sprite_from = sprite.position if sprite else Vector2.ZERO


## How far from its physics position the slime is drawn this frame (its node's share and, with
## `with_sprite`, the sprite's jump arc too): zero unless physics interpolation is on.
func drawn_shift(with_sprite := true) -> Vector2:
	if not is_physics_interpolated_and_enabled():
		return Vector2.ZERO
	var f := Engine.get_physics_interpolation_fraction()
	var shift := _tick_from.lerp(position, f) - position
	if with_sprite:
		shift += _sprite_from.lerp(sprite.position, f) - sprite.position
	return shift


## Jelly test: how see-through the goo body is (0 = solid).
func set_translucency(amount: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("translucency", amount)


## Recolors the slime (palette swap of its goo shades) and its droplets.
func apply_skin(color: Color, rainbow := false, clock := false) -> void:
	Skins.apply_to(sprite.material, color, rainbow, clock)
	Stopwatch.attach(sprite, clock)
	_drips.color = color
	_drips.color_initial_ramp = Fx.rainbow_gradient() if rainbow else null


## The stopwatch skin's clock speeds up and down with what the slime is doing.
func _process(_delta: float) -> void:
	if sprite.has_node("StopwatchFace"):
		Stopwatch.request(Stopwatch.mode_for(state, velocity.length()))


## In the air (a leap) or dashing (SLIMAKAZE): the ground doesn't drain, and a dry-up waits.
func is_airborne() -> bool:
	return state == State.AIRBORNE or state == State.DASH


## SLIMAKAZE: dashes in a straight line along `dir` to `target` (against a wall, worked out on the
## maze grid by Abilities) at `speed` px/s, then splats there (stunned `stun` s, dash_hit). Frozen
## meanwhile (a win or dry-up), it just stops where it is.
func dash(target: Vector2, dir: Vector2, speed: float, stun: float) -> void:
	_jump_dir = dir
	facing = dir
	_dash_target = target
	_dash_lane = Vector2(target.x, position.y) if dir.y != 0.0 else Vector2(position.x, target.y)
	_dash_on_lane = position.is_equal_approx(_dash_lane)
	_dash_speed = speed
	_dash_stun = stun
	velocity = Vector2.ZERO
	charge = 0.0
	knocked_back = false
	_soft_slide = false
	_soft_hold_left = 0.0
	_jump_buffer_left = 0.0
	state = State.DASH
	_sfx_stop("charge")
	launched.emit(dir * speed, position.distance_to(target) / maxf(speed, 1.0))


## Ends a dash at once at its target (tests, and the last step of a dash).
func finish_dash() -> void:
	if state != State.DASH:
		return
	position = _dash_target
	sprite.position.y = 0.0
	_hop_px = 0.0  # (called from outside a tick too: no catch hop left to take off)
	state = State.STUNNED
	_stun_left = _dash_stun
	_stun_total = _dash_stun
	_recover_after = RECOVER_ANIM_TIME
	_splat_side = splat_side(-_jump_dir)
	velocity = Vector2.ZERO
	_hit_stop(1.0)
	_sfx("splat", 2.0, 0.75)
	_buzz(120)
	dash_hit.emit(-_jump_dir)


func _dash_step(delta: float) -> void:
	if frozen:
		state = State.GLIDE  # the run ended mid-dash: stop here, no splat
		sprite.position.y = 0.0
		return
	var budget := _dash_speed * delta
	if not _dash_on_lane:
		budget -= position.distance_to(_dash_lane)
		position = position.move_toward(_dash_lane, _dash_speed * delta)
		_dash_on_lane = position.is_equal_approx(_dash_lane)
	if _dash_on_lane and budget > 0.0:
		position = position.move_toward(_dash_target, budget)
	if position.is_equal_approx(_dash_target):
		finish_dash()


## Stops a dash where it is with no splat (it reached the goal: AbilityRunner.settle_at_goal).
func stop_dash() -> void:
	if state != State.DASH:
		return
	state = State.GLIDE
	sprite.position.y = 0.0
	_hop_px = 0.0
	velocity = Vector2.ZERO


func play_dry_up() -> void:
	_sfx_stop("charge")
	_sfx("dry")
	_special_anim = "dry"
	cancel_catch_hop()
	sprite.play("dry")


func play_celebrate() -> void:
	_special_anim = "celebrate"
	sprite.position.y = 0.0
	_hop_px = 0.0
	catch_t = -1.0
	sprite.play("celebrate")


## Leaps in the facing direction. Called on releasing the jump key (and by tests).
func launch(charge_value: float) -> void:
	_jump_dir = leap_dir(facing)
	facing = _jump_dir
	_jump_distance = jump_distance_for(charge_value)
	_jump_traveled = 0.0
	ricochets = 0
	_soft = Economy.soft_bounce_on()
	last_hit_glancing = false
	_soft_slide = false
	_soft_hold_left = 0.0
	velocity = Vector2.ZERO
	charge = 0.0
	state = State.AIRBORNE
	_sfx_stop("charge")
	launched.emit(_jump_dir * JUMP_SPEED, _jump_distance / JUMP_SPEED)
	_sfx("jump", -4.0, lerpf(1.05, 0.8, _jump_distance / jump_distance_for(100.0)))


func _physics_process(delta: float) -> void:
	if _hop_px != 0.0:
		sprite.position.y += _hop_px  # last tick's catch hop off: the tick sees only its own offsets
		_hop_px = 0.0
	var input := Vector2.ZERO
	if not frozen:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO and (state == State.GLIDE or state == State.CHARGING):
		facing = input.normalized()

	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	if frozen or not can_charge or not Input.is_action_pressed("jump"):
		_jump_buffer_left = 0.0  # let go (or can't charge): the remembered press is void
	elif Input.is_action_just_pressed("jump") and state != State.GLIDE and state != State.CHARGING:
		_jump_buffer_left = JUMP_BUFFER  # pressed too early (stun, leap): remember it
	if state == State.GLIDE and not frozen and can_charge \
			and (Input.is_action_just_pressed("jump") or _jump_buffer_left > 0.0):
		_jump_buffer_left = 0.0
		state = State.CHARGING
		charge = 0.0
		_sfx("charge", -8.0)

	match state:
		State.GLIDE:
			_glide(input, delta)
		State.CHARGING:
			_glide(Vector2.ZERO, delta)
			if frozen:
				state = State.GLIDE
				charge = 0.0
				_sfx_stop("charge")
			else:
				charge = minf(charge + 100.0 / charge_time * delta, 100.0)
				if not Input.is_action_pressed("jump"):
					launch(charge)
		State.AIRBORNE:
			_fly(delta)
		State.DASH:
			_dash_step(delta)
		State.STUNNED:
			_glide(Vector2.ZERO, delta)  # the knockback slides on while stunned
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = State.GLIDE
				_recover_anim_left = _recover_after

	if knocked_back and _soft_hold_left <= 0.0 \
			and (state == State.GLIDE and (input != Vector2.ZERO or velocity.length() < KNOCKBACK_END_SPEED)):
		knocked_back = false
		_soft_slide = false
	_squish_left -= delta
	if state == State.GLIDE and velocity.length() > IDLE_SPEED and _squish_left <= 0.0:
		_squish_left = SQUISH_INTERVAL * max_speed / maxf(velocity.length(), 1.0)
		_sfx("squish", -12.0, randf_range(0.85, 1.15))
	_land_anim_left = maxf(_land_anim_left - delta, 0.0)
	var tension := charge / 100.0 if state == State.CHARGING else 0.0
	if not is_equal_approx(tension, _tension):
		_tension = tension
		(sprite.material as ShaderMaterial).set_shader_parameter("charge", tension)
	_bounce_fx_left = maxf(_bounce_fx_left - delta, 0.0)
	_recover_anim_left = maxf(_recover_anim_left - delta, 0.0)
	_drips.emitting = state == State.GLIDE and not frozen and velocity.length() > DRIP_SPEED
	if _drips.emitting:
		_drips.direction = -velocity.normalized()
	_animate()
	if catch_t >= 0.0:
		_catch_hop_step(delta)


## Coin catch test: the time from a hop's start to its catch moment, and its full length (s).
static func catch_moment() -> float:
	return Economy.COIN_CATCH_SQUASH_TIME + Economy.COIN_CATCH_HOP_TIME * Economy.COIN_CATCH_CATCH_SHARE


static func catch_hop_length() -> float:
	return Economy.COIN_CATCH_SQUASH_TIME + Economy.COIN_CATCH_HOP_TIME + Economy.COIN_CATCH_LAND_TIME


## Coin catch test: starts the little hop that catches a tossed coin (or joins the one under way when
## its catch is still COIN_CATCH_MIN_TOSS s off or more). Returns the seconds until the catch.
## Purely cosmetic: only the sprite moves (and its frames change while gliding).
func catch_hop() -> float:
	var left := catch_moment() - catch_t
	if catch_t >= 0.0 and left >= Economy.COIN_CATCH_MIN_TOSS:
		return left
	catch_t = 0.0
	return catch_moment()


## Ends a catch hop at once (a win, a dry-up, tests); the sprite drops back to where the tick put it.
func cancel_catch_hop() -> void:
	sprite.position.y += _hop_px
	_hop_px = 0.0
	catch_t = -1.0


## How high (whole px) the catch hop lifts the sprite `t` s in: a sine up and down over the hop.
static func catch_lift(t: float) -> float:
	var hop_t := t - Economy.COIN_CATCH_SQUASH_TIME
	if hop_t <= 0.0 or hop_t >= Economy.COIN_CATCH_HOP_TIME:
		return 0.0
	return roundf(sin(PI * hop_t / Economy.COIN_CATCH_HOP_TIME) * Economy.COIN_CATCH_HOP_PX)


func _catch_hop_step(delta: float) -> void:
	catch_t += delta
	if catch_t >= catch_hop_length() or _special_anim != "":
		catch_t = -1.0
		return
	_hop_px = catch_lift(catch_t)
	sprite.position.y -= _hop_px


## The catch hop's frames while gliding (squash, stretch up, airborne, landing squash), facing the way
## it moves. False when no hop is on (the usual animation plays).
func _catch_frames() -> bool:
	if catch_t < 0.0 or catch_t >= catch_hop_length():
		return false
	var way := dir_name(velocity) if velocity.length() > IDLE_SPEED else dir_name(facing)
	var hop_t := catch_t - Economy.COIN_CATCH_SQUASH_TIME
	if hop_t < 0.0:
		_show_frame("charge_" + way, lerpf(0.3, 0.9, catch_t / Economy.COIN_CATCH_SQUASH_TIME))
	elif hop_t < Economy.COIN_CATCH_HOP_TIME * 0.25:
		_show_frame("launch_" + way, hop_t / (Economy.COIN_CATCH_HOP_TIME * 0.25))
	elif hop_t < Economy.COIN_CATCH_HOP_TIME:
		_show_frame("air_" + way, (hop_t / Economy.COIN_CATCH_HOP_TIME - 0.25) / 0.75)
	else:
		_show_frame("land_" + way, (hop_t - Economy.COIN_CATCH_HOP_TIME) / Economy.COIN_CATCH_LAND_TIME)
	return true


## Picks the animation (and, for state-driven ones, the exact frame) for the current state.
func _animate() -> void:
	shadow.visible = state == State.AIRBORNE
	if _special_anim != "":
		return
	if _hit_stop_left > 0.0:
		_hit_stop_left -= get_physics_process_delta_time()
		if state == State.STUNNED:
			_show_frame("splat_" + _splat_side, 0.0)  # the first squashed frame, held
		return  # hit-stop: the picture holds on the moment of impact
	var facing_name := dir_name(facing)
	match state:
		State.GLIDE:
			if _catch_frames():
				pass  # coin catch test: the hop's own frames
			elif _recover_anim_left > 0.0:
				_play("recover")
			elif _land_anim_left > 0.0:
				_show_frame("land_" + facing_name, 1.0 - _land_anim_left / LAND_ANIM_TIME)
			elif velocity.length() > IDLE_SPEED:
				_play("glide_" + dir_name(velocity))
				sprite.speed_scale = clampf(velocity.length() / max_speed, 0.4, 1.0)
			else:
				_play("idle")
		State.CHARGING:
			_show_frame("charge_" + dir_name(leap_dir(facing)), charge / 100.0)
		State.AIRBORNE:
			var t := _jump_traveled / _jump_distance
			var jump_name := dir_name(_jump_dir)
			if t < LAUNCH_SHARE:
				_show_frame("launch_" + jump_name, t / LAUNCH_SHARE)
			else:
				_show_frame("air_" + jump_name, (t - LAUNCH_SHARE) / (1.0 - LAUNCH_SHARE))
		State.STUNNED:
			_show_frame("splat_" + _splat_side, 1.0 - _stun_left / maxf(_stun_total, 0.001))
		State.DASH:
			_show_frame("air_" + dir_name(_jump_dir), 0.5)


func _play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.speed_scale = 1.0
		sprite.play(anim)


## Shows the frame of `anim` at `progress` (0-1) without playing it on a timer.
func _show_frame(anim: String, progress: float) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.pause()
	var count := sprite.sprite_frames.get_frame_count(anim)
	sprite.frame = clampi(int(progress * count), 0, count - 1)


func _glide(input: Vector2, delta: float) -> void:
	if _soft_slide and knocked_back and input == Vector2.ZERO:
		_soft_step(delta)
		return
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed, acceleration * delta)
		if maze_assist:
			_center_in_lane(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if knocked_back and input == Vector2.ZERO:
		_ricochet(delta)
	else:
		move_and_slide()


## Knockback movement: like move_and_slide, but walls hit fast enough bounce the slime off.
func _ricochet(delta: float) -> void:
	var motion := velocity * delta
	for i in 4:  # a few hits per frame at most (corners)
		var hit := move_and_collide(motion)
		if hit == null:
			return
		var normal := hit.get_normal()
		var impact := -velocity.dot(normal)
		var left := hit.get_remainder().length()
		if impact > MIN_BOUNCE_SPEED:
			velocity = wall_bounce(velocity, normal)
			ricochets += 1
			if _bounce_fx_left <= 0.0:
				_bounce_fx_left = BOUNCE_FX_GAP
				_splat_side = splat_side(normal)
				_sfx("splat", lerpf(-14.0, -3.0, clampf(impact / 200.0, 0.0, 1.0)), randf_range(1.0, 1.2))
				_hit_stop(clampf(impact / 200.0, 0.0, 1.0) * 0.5)
				bounced.emit(normal, impact)
		else:
			velocity = velocity.slide(normal)
		if left <= 0.0 or velocity == Vector2.ZERO:
			return
		motion = velocity.normalized() * left


## Velocity after hitting a wall: the part into the wall bounces back at RESTITUTION, the part
## along it keeps WALL_GRIP.
static func wall_bounce(v: Vector2, wall_normal: Vector2) -> Vector2:
	var into := wall_normal * v.dot(wall_normal)
	return (v - into) * WALL_GRIP - into * RESTITUTION


## Pressing along one axis centers the slime on the other, so it lines up with the one-tile
## corridors and slides into side openings instead of catching on corners.
func _center_in_lane(input: Vector2) -> void:
	if input.x != 0.0 and input.y == 0.0:
		velocity.y = _lane_velocity(position.y)
	elif input.y != 0.0 and input.x == 0.0:
		velocity.x = _lane_velocity(position.x)


func _lane_velocity(coord: float) -> float:
	var center := (floorf(coord / TILE) + 0.5) * TILE
	return clampf((center - coord) * LANE_PULL, -max_speed, max_speed)


func _fly(delta: float) -> void:
	var step := minf(JUMP_SPEED * delta, _jump_distance - _jump_traveled)
	var collision := move_and_collide(_jump_dir * step)
	var moved := _moved_along(collision, step)
	if collision and maze_assist and _slip_past_corner(collision):
		collision = move_and_collide(_jump_dir * (step - moved))
		moved += _moved_along(collision, step - moved)
	_jump_traveled += moved
	var arc_height := 3.0 + _jump_distance / TILE * 1.5
	sprite.position.y = -roundf(sin(PI * _jump_traveled / _jump_distance) * arc_height)
	if collision:
		_land(true, collision.get_normal())
	elif _jump_traveled >= _jump_distance:
		_land(false, Vector2.ZERO)


## How far a flight step actually went along the leap (sideways push-outs from a wall don't count).
func _moved_along(collision: KinematicCollision2D, step: float) -> float:
	return clampf(collision.get_travel().dot(_jump_dir), 0.0, step) if collision else step


## Leeway for straight leaps: if the slime only clips the corner of a wall (hit from the side,
## not head-on), it's nudged up to CORNER_LEEWAY px sideways past it, as long as that clears
## the way, so a jump that looks clean is clean. Diagonal leaps get no leeway (their wall hits
## are real, and ricochet).
func _slip_past_corner(collision: KinematicCollision2D) -> bool:
	if absf(_jump_dir.x) > 0.01 and absf(_jump_dir.y) > 0.01:
		return false
	var normal := collision.get_normal()
	var across := _jump_dir.orthogonal()
	var side := signf(normal.dot(across))
	if side == 0.0 or normal.dot(_jump_dir) < -0.97:
		return false  # square into a wall: a real splat
	var ahead := _jump_dir * maxf(collision.get_remainder().length(), 1.0)
	for nudge in range(1, int(CORNER_LEEWAY) + 1):
		var shift := across * side * nudge
		if not test_move(global_transform.translated(shift), ahead):
			position += shift
			return true
	return false


func _land(hit_wall: bool, wall_normal: Vector2) -> void:
	sprite.position.y = 0.0
	last_jump_traveled = _jump_traveled
	if hit_wall and _soft:
		state = State.STUNNED
		_splat_side = splat_side(wall_normal)
		_soft_hit(wall_normal)
	elif hit_wall:
		state = State.STUNNED
		_stun_left = splat_stun
		_stun_total = splat_stun
		_recover_after = RECOVER_ANIM_TIME
		_soft_slide = false
		_splat_side = splat_side(wall_normal)
		_knock_back(wall_normal)
		_hit_stop(inverse_lerp(jump_distance_for(0.0), jump_distance_for(100.0), _jump_distance))
		_sfx("splat")
		_buzz(60)  # phones buzz on a splat (no effect elsewhere)
	else:
		state = State.GLIDE
		_land_anim_left = LAND_ANIM_TIME
		_sfx("land", -3.0)
	jump_landed.emit(_jump_distance, hit_wall, wall_normal)


## Throws the slime back off the wall it hit (see BOUNCE_FACTOR): the leftover jump distance,
## turned into a speed, bounces off the wall like a ball.
func _knock_back(wall_normal: Vector2) -> void:
	var leftover := maxf(_jump_distance - _jump_traveled, 0.0)
	velocity = wall_bounce(_jump_dir * sqrt(2.0 * friction * leftover), wall_normal)
	knocked_back = velocity.length() > KNOCKBACK_END_SPEED
	_bounce_fx_left = BOUNCE_FX_GAP


## Soft bounce test (Economy.soft_bounce_on): a wall hit mid-leap. Within ~20 deg of head-on
## (SOFT_BOUNCE_HEAD_ON_COS) it is a splat with a shorter stun and a short knockback straight off the
## wall; shallower, it glances: a quick squash on the wall, then a smooth slide along it that brakes
## evenly to a stop (SOFT_BOUNCE_SLIDE_*). Either way the slide is a knockback (free, like today's)
## moved by _soft_step, which never bounces.
func _soft_hit(wall_normal: Vector2) -> void:
	var leftover := maxf(_jump_distance - _jump_traveled, 0.0)
	velocity = Vector2.ZERO
	_soft_slide = true
	knocked_back = true
	_bounce_fx_left = BOUNCE_FX_GAP
	if -_jump_dir.dot(wall_normal) >= Economy.SOFT_BOUNCE_HEAD_ON_COS:
		last_hit_glancing = false
		_stun_total = minf(splat_stun, Economy.SOFT_BOUNCE_HEAD_STUN)
		_recover_after = Economy.SOFT_BOUNCE_HEAD_RECOVER
		var dist := minf(leftover * BOUNCE_FACTOR * Economy.SOFT_BOUNCE_HEAD_KNOCK, Economy.SOFT_BOUNCE_HEAD_KNOCK_MAX)
		_soft_decel = Economy.SOFT_BOUNCE_HEAD_DECEL
		_soft_vel = wall_normal * sqrt(2.0 * _soft_decel * dist)
		_soft_hold_left = 0.0
		velocity = _soft_vel
		_hit_stop(inverse_lerp(jump_distance_for(0.0), jump_distance_for(100.0), _jump_distance))
		_sfx("splat")
		_buzz(60)
	else:
		last_hit_glancing = true
		_stun_total = minf(splat_stun, Economy.SOFT_BOUNCE_GLANCE_STUN)
		_recover_after = 0.0  # straight on into the glide frames: it never stopped moving
		var along := _jump_dir.slide(wall_normal)
		var speed := JUMP_SPEED * along.length() * Economy.SOFT_BOUNCE_SPEED_SHARE
		var dist := clampf(leftover * Economy.SOFT_BOUNCE_SLIDE_PER_LEFT, Economy.SOFT_BOUNCE_SLIDE_MIN, Economy.SOFT_BOUNCE_SLIDE_MAX)
		_soft_vel = along.normalized() * speed
		_soft_decel = speed * speed / (2.0 * dist)
		_soft_hold_left = Economy.SOFT_BOUNCE_SQUASH
		_sfx("splat", Economy.SOFT_BOUNCE_PLAP_DB, Economy.SOFT_BOUNCE_PLAP_PITCH)
		_buzz(20)
	_stun_left = _stun_total


## Soft bounce test: one tick of a soft slide (see _soft_hit). Holds still through the squash, then
## glides on, braking evenly; anything in the way ahead (a corner) ends it on the spot. Walls beside
## it only slide it (move_and_slide), so a corridor never rattles.
func _soft_step(delta: float) -> void:
	if _soft_hold_left > 0.0:
		_soft_hold_left -= delta
		velocity = Vector2.ZERO
		if _soft_hold_left > 0.0:
			return
		velocity = _soft_vel
	var dir := velocity.normalized()
	velocity = velocity.move_toward(Vector2.ZERO, _soft_decel * delta)
	if velocity == Vector2.ZERO:
		return
	move_and_slide()
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_normal().dot(dir) < -0.5:
			velocity = Vector2.ZERO
			return


## A phone buzz of `ms` milliseconds, unless SETTINGS VIBRATION is off (no effect where there's no vibrator).
func _buzz(ms: int) -> void:
	var progress := get_node_or_null("/root/Progress")
	if progress and not progress.vibration:
		return
	Input.vibrate_handheld(ms)


## Holds the sprite for a moment on impact (`power` 0-1), unless Reduce Motion is on.
func _hit_stop(power: float) -> void:
	var progress := get_node_or_null("/root/Progress")
	if progress and progress.reduce_motion:
		return
	_hit_stop_left = maxf(_hit_stop_left, HIT_STOP_MAX * power)


func _sfx(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name, volume_db, pitch)


func _sfx_stop(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.stop(sound_name)
