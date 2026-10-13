class_name Stopwatch
extends RefCounted

## The STOPWATCH skin's clock (unlocked by all 30 medals). ONE accumulated clock value `time`
## (clock seconds, wrapped every 12 hours) drives every hand through real gearing: the second hand
## turns once per 60 clock seconds, the minute hand once per 3600 (1/60 of the second hand's speed)
## and the hour hand once per 43200 (the minute hand's angle / 12), so they always stay in
## proportion, whatever the speed. The speed ("rate", clock seconds per real second) eases toward a
## target that depends on what the slime is doing: ticking 1/s when idle, a modest tick rate while
## gliding, a fast whirl while charging or leaping, easing back down after the landing. The shader
## (slime_skin.gdshader, `clock_*` uniforms) draws the face; `StopwatchFace` feeds it.

enum Mode { IDLE, MOVE, LEAP }

## Clock seconds in 12 hours: all three hands are periodic in this.
const WRAP := 43200.0
## Where the hands rest at the start: 11:15:00 (hour hand up, minute hand right: well apart, so both read
## at 14 px).
const START_TIME := 11.0 * 3600.0 + 15.0 * 60.0
## Target rates in clock seconds per real second (= second-hand ticks per second while it ticks).
## Idle: 1 tick/s (second hand 0.017 rev/s = 0.105 rad/s). Move: 5 ticks/s (0.083 rev/s = 0.52 rad/s).
## Leap: 600 (second hand 10 rev/s = 62.8 rad/s, minute hand 1 rev/s, hour hand 1/12 rev/s).
const RATE_IDLE := 1.0
const RATE_MOVE := 5.0
const RATE_LEAP := 600.0
## Reduce Motion: a calm slow tick, no whirl.
const RATE_IDLE_CALM := 1.0
const RATE_MOVE_CALM := 2.0
## Ease constants (1/s): speeding up is quick, slowing down lingers.
const RAMP_UP := 7.0
const RAMP_DOWN := 2.2
## Below TICK_FULL the hands step in whole clock seconds; above TICK_NONE they sweep smoothly.
const TICK_FULL := 12.0
const TICK_NONE := 40.0

static var time := START_TIME
static var rate := RATE_IDLE
static var _requested := Mode.IDLE
static var _last_frame := -1


## Target rate for a mode (clock seconds per second).
static func target_rate(mode: int, reduce_motion := false) -> float:
	if reduce_motion:
		return RATE_MOVE_CALM if mode != Mode.IDLE else RATE_IDLE_CALM
	match mode:
		Mode.MOVE:
			return RATE_MOVE
		Mode.LEAP:
			return RATE_LEAP
	return RATE_IDLE


## One easing step of `current` toward `target` over `delta` seconds (framerate independent).
static func ramp(current: float, target: float, delta: float) -> float:
	var k := RAMP_UP if target > current else RAMP_DOWN
	return current + (target - current) * (1.0 - exp(-k * delta))


## The hand angles (radians, clockwise from 12) for a clock value: x hour, y minute, z second.
## Exact gearing: second = minute * 60 (mod a turn), minute = hour * 12 (mod a turn).
static func angles(clock: float) -> Vector3:
	return Vector3(TAU * clock / 43200.0, TAU * clock / 3600.0, TAU * clock / 60.0)


## The clock value the hands show at `speed`: whole clock seconds while slow (a ticking
## mechanism), smooth while whirling, blended between. All three hands use the same value.
static func shown_time(clock: float, speed: float) -> float:
	var smooth := smoothstep(TICK_FULL, TICK_NONE, speed)
	return lerpf(floorf(clock), clock, smooth)


## Asks for a mode this frame (the fastest request wins); Stopwatch.advance consumes it.
static func request(mode: int) -> void:
	_requested = maxi(_requested, mode)


## Advances the shared clock once per rendered frame (the first face to ask each frame does it).
static func advance(delta: float, reduce_motion := false) -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_frame:
		return
	_last_frame = frame
	step(delta, _requested, reduce_motion)
	_requested = Mode.IDLE


## One clock update: ease `rate` toward the mode's target and turn `time` by it. (Separate from
## advance so tests can step it by hand.)
static func step(delta: float, mode: int, reduce_motion := false) -> void:
	rate = ramp(rate, target_rate(mode, reduce_motion), delta)
	time = fposmod(time + rate * delta, WRAP)


static func reset() -> void:
	time = START_TIME
	rate = RATE_IDLE
	_requested = Mode.IDLE
	_last_frame = -1


## The mode a slime in this state asks for: charging and leaping whirl the clock, gliding runs it.
static func mode_for(state: int, speed: float) -> int:
	if state == Slime.State.CHARGING or state == Slime.State.AIRBORNE:
		return Mode.LEAP
	if speed > Slime.IDLE_SPEED:
		return Mode.MOVE
	return Mode.IDLE


## The face (center x, center y, radius x, radius y) inside a frame's body, in sprite-local pixels.
static func face_for(anim: String, frame: int) -> Vector4:
	var box := Slime.body_box(anim, frame)
	var c := box.get_center()
	var radii := box.size / 2.0 - Vector2(1.5, 1.5)
	return Vector4(c.x, c.y, maxf(radii.x, 2.0), maxf(radii.y, 2.0))


## Makes `sprite` (an AnimatedSprite2D with a slime_skin material) run the clock, or stops it.
static func attach(sprite: AnimatedSprite2D, on: bool) -> void:
	var existing := sprite.get_node_or_null("StopwatchFace")
	if existing:
		existing.free()
	var material := sprite.material as ShaderMaterial
	if material:
		material.set_shader_parameter("clock_on", 1.0 if on else 0.0)
	if on:
		var face := StopwatchFace.new()
		face.name = "StopwatchFace"
		sprite.add_child(face)


## Per-sprite driver: refits the face to the current animation frame and feeds the hand angles.
class StopwatchFace extends Node:
	var _anim := ""
	var _frame := -1
	var _material: ShaderMaterial

	func _ready() -> void:
		_update(0.0)

	func _process(delta: float) -> void:
		_update(delta)

	func _update(delta: float) -> void:
		var sprite := get_parent() as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial if sprite else null
		if material == null:
			return
		var progress := get_node_or_null("/root/Progress")
		var calm: bool = progress != null and progress.reduce_motion
		Stopwatch.advance(delta, calm)
		if sprite.animation != _anim or sprite.frame != _frame or material != _material:
			_material = material
			_anim = sprite.animation
			_frame = sprite.frame
			material.set_shader_parameter("clock_face", Stopwatch.face_for(_anim, _frame))
		var shown := Stopwatch.shown_time(Stopwatch.time, Stopwatch.rate)
		material.set_shader_parameter("clock_hands", Stopwatch.angles(shown))
