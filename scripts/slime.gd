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

enum State { GLIDE, CHARGING, AIRBORNE, STUNNED }

const TILE := 16
## Collision radius: the body is 14 px across in a 16 px corridor, a snug fit.
const RADIUS := 7.0
const CHARGE_TIME := 1.5
const MIN_JUMP_TILES := 1.0
const MAX_JUMP_TILES := 8.0
const JUMP_SPEED := 220.0
const SPLAT_STUN := 0.3
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
var _jump_distance := 0.0
var _jump_traveled := 0.0
## Distance actually flown by the latest jump (shorter than planned when it hits a wall).
var last_jump_traveled := 0.0
## True while sliding from a splat's knockback (that slide costs no slime).
var knocked_back := false
var _stun_left := 0.0
var _bounce_fx_left := 0.0
## Wall ricochets since the last launch (after the splat itself).
var ricochets := 0
var _splat_side := "n"
var _land_anim_left := 0.0
var _squish_left := 0.0
var _recover_anim_left := 0.0
## Set by play_dry_up()/play_celebrate(); overrides the state-driven animation.
var _special_anim := ""

static var _sprite_frames: SpriteFrames
## Top-center of the body for each animation frame (see head_point), and the sheet's pixels.
static var _heads := {}
static var _sheet_image: Image
var _drips: CPUParticles2D

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
## Found from the sheet's pixels (the topmost row of the outline), so it follows every squash,
## stretch and bounce of the animation.
static func head_point(anim: String, frame: int) -> Vector2:
	var key := "%s:%d" % [anim, frame]
	if _heads.has(key):
		return _heads[key]
	var frames := load_sprite_frames()
	var point := Vector2(0, -7)
	if frames.has_animation(anim) and frame < frames.get_frame_count(anim):
		var region := (frames.get_frame_texture(anim, frame) as AtlasTexture).region
		if _sheet_image == null:
			_sheet_image = preload("res://assets/sprites/slime_sheet.png").get_image()
			if _sheet_image.is_compressed():
				_sheet_image.decompress()
		for y in int(region.size.y):
			var xs: Array[int] = []
			for x in int(region.size.x):
				if _sheet_image.get_pixel(int(region.position.x) + x, int(region.position.y) + y).a > 0.5:
					xs.append(x)
			if not xs.is_empty():
				var center := (xs[0] + xs[-1] + 1) / 2.0
				point = Vector2(center, y) - region.size / 2.0
				break
	_heads[key] = point
	return point


## Name suffix ("e", "se", ...) for the 45-degree direction closest to v.
static func dir_name(v: Vector2) -> String:
	return DIR_NAMES[wrapi(roundi(v.angle() / (PI / 4.0)), 0, 8)]


func _ready() -> void:
	sprite.sprite_frames = load_sprite_frames()
	sprite.material = Skins.make_material(Skins.get_preset(Skins.DEFAULT).color)
	sprite.play("idle")
	_drips = Fx.make_drips()
	_drips.show_behind_parent = true
	_drips.color = Skins.get_preset(Skins.DEFAULT).color
	add_child(_drips)


## Jelly test: how see-through the goo body is (0 = solid).
func set_translucency(amount: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("translucency", amount)


## Recolors the slime (palette swap of its goo shades) and its droplets.
func apply_skin(color: Color, rainbow := false) -> void:
	Skins.apply_to(sprite.material, color, rainbow)
	_drips.color = color
	_drips.color_initial_ramp = Fx.rainbow_gradient() if rainbow else null


func is_airborne() -> bool:
	return state == State.AIRBORNE


func play_dry_up() -> void:
	_sfx_stop("charge")
	_sfx("dry")
	_special_anim = "dry"
	sprite.play("dry")


func play_celebrate() -> void:
	_special_anim = "celebrate"
	sprite.position.y = 0.0
	sprite.play("celebrate")


## Leaps in the facing direction. Called on releasing the jump key (and by tests).
func launch(charge_value: float) -> void:
	_jump_dir = facing
	_jump_distance = jump_distance_for(charge_value)
	_jump_traveled = 0.0
	ricochets = 0
	velocity = Vector2.ZERO
	charge = 0.0
	state = State.AIRBORNE
	_sfx_stop("charge")
	launched.emit(_jump_dir * JUMP_SPEED, _jump_distance / JUMP_SPEED)
	_sfx("jump", -4.0, lerpf(1.05, 0.8, _jump_distance / jump_distance_for(100.0)))


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not frozen:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO and (state == State.GLIDE or state == State.CHARGING):
		facing = input.normalized()

	if state == State.GLIDE and not frozen and can_charge and Input.is_action_just_pressed("jump"):
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
				charge = minf(charge + 100.0 / CHARGE_TIME * delta, 100.0)
				if not Input.is_action_pressed("jump"):
					launch(charge)
		State.AIRBORNE:
			_fly(delta)
		State.STUNNED:
			_glide(Vector2.ZERO, delta)  # the knockback slides on while stunned
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = State.GLIDE
				_recover_anim_left = RECOVER_ANIM_TIME

	if knocked_back and (state == State.GLIDE and (input != Vector2.ZERO or velocity.length() < KNOCKBACK_END_SPEED)):
		knocked_back = false
	_squish_left -= delta
	if state == State.GLIDE and velocity.length() > IDLE_SPEED and _squish_left <= 0.0:
		_squish_left = SQUISH_INTERVAL * max_speed / maxf(velocity.length(), 1.0)
		_sfx("squish", -12.0, randf_range(0.85, 1.15))
	_land_anim_left = maxf(_land_anim_left - delta, 0.0)
	_bounce_fx_left = maxf(_bounce_fx_left - delta, 0.0)
	_recover_anim_left = maxf(_recover_anim_left - delta, 0.0)
	_drips.emitting = state == State.GLIDE and not frozen and velocity.length() > DRIP_SPEED
	if _drips.emitting:
		_drips.direction = -velocity.normalized()
	_animate()


## Picks the animation (and, for state-driven ones, the exact frame) for the current state.
func _animate() -> void:
	shadow.visible = state == State.AIRBORNE
	if _special_anim != "":
		return
	var facing_name := dir_name(facing)
	match state:
		State.GLIDE:
			if _recover_anim_left > 0.0:
				_play("recover")
			elif _land_anim_left > 0.0:
				_show_frame("land_" + facing_name, 1.0 - _land_anim_left / LAND_ANIM_TIME)
			elif velocity.length() > IDLE_SPEED:
				_play("glide_" + dir_name(velocity))
				sprite.speed_scale = clampf(velocity.length() / max_speed, 0.4, 1.0)
			else:
				_play("idle")
		State.CHARGING:
			_show_frame("charge_" + facing_name, charge / 100.0)
		State.AIRBORNE:
			var t := _jump_traveled / _jump_distance
			var jump_name := dir_name(_jump_dir)
			if t < LAUNCH_SHARE:
				_show_frame("launch_" + jump_name, t / LAUNCH_SHARE)
			else:
				_show_frame("air_" + jump_name, (t - LAUNCH_SHARE) / (1.0 - LAUNCH_SHARE))
		State.STUNNED:
			_show_frame("splat_" + _splat_side, 1.0 - _stun_left / SPLAT_STUN)


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
	if hit_wall:
		state = State.STUNNED
		_stun_left = SPLAT_STUN
		_splat_side = splat_side(wall_normal)
		_knock_back(wall_normal)
		_sfx("splat")
		Input.vibrate_handheld(60)  # phones buzz on a splat (no effect elsewhere)
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


func _sfx(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name, volume_db, pitch)


func _sfx_stop(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.stop(sound_name)
