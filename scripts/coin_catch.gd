class_name CoinCatch
extends Node2D

## Coin catch test (Economy.COIN_CATCH_TEST, docs/spring-cleaning/coin-catch-test.md): the show after
## the slime touches a coin. The coin is already collected and saved (game.gd _pick_up_coins); this
## only presents it:
## 1. TOSS: the coin flips up in an arc over the slime (COIN_CATCH_TOSS_HEIGHT px over its center),
##    spinning fast with a glint at the top and a few gold sparkles, while the slime squashes and hops
##    (Slime.catch_hop, a cosmetic sprite offset) to catch it on its head (the coin sound).
## 2. DISSOLVE (COIN_CATCH_DISSOLVE_TIME): a jelly slime shows the coin sinking into its body (tinted
##    by the see-through goo), fizzing smaller with tiny bubbles rising; a solid one swallows it into its
##    top with a glint and a goo ripple. Then `done` (the game pops the HUD counter, a soft fizz).
## Reduce Motion: no toss, no hop, no particles: the coin sits in the slime and fades out slowly
## (COIN_CATCH_CALM_TIME).
## It is the slime's child, so it travels (and is drawn between physics ticks) with it; everything
## moves on physics ticks in whole px, like the slime's own sprite. Pausing the tree freezes it.

signal done(catch: CoinCatch)

enum Phase { TOSS, DISSOLVE }

const COIN_GOLD := Color8(255, 214, 110)
const GLINT := Color8(255, 248, 220)
## Where the coin lands, relative to the sprite's center: the top of the head; then where it sinks.
const HEAD_Y := -6.0
const JELLY_FROM_Y := -4.0
const JELLY_TO_Y := 2.0
const SOLID_FROM_Y := -4.0
const SOLID_TO_Y := -1.0
## A coin inside a jelly slime: tinted this much by the goo's light shade, at this opacity.
const JELLY_TINT := 0.45
const JELLY_ALPHA := 0.8
## Physics ticks a glint stays up.
const GLINT_TICKS := 6
const RIPPLE_DOTS := 14

var coin: Coin
var slime: Slime
var jelly := false
var calm := false
var phase := Phase.TOSS
## Seconds into the current phase, and the toss's length (until the hop's catch moment).
var t := 0.0
var toss_time := 0.0
var dissolve_time := Economy.COIN_CATCH_DISSOLVE_TIME
## The coin's start relative to the slime, and a sideways shift (a few at once don't stack exactly).
var _from := Vector2.ZERO
var _side := 0.0
var _sparkles: CPUParticles2D
var _bubbles: CPUParticles2D
var _tint := Color.WHITE
var _glint_left := 0
var _glint_at := Vector2.ZERO
var _ripple := Vector2(-1.0, 0.0)  # (radius, alpha); radius < 0 = none
var _ripple_at := Vector2.ZERO
var _dirty := false
var _topped := false


## Starts the show for `coin` (already taken off the game's coin list) on `slime`. `tint` is the
## skin's light shade (bubbles, ripple), `rainbow` makes them rainbow, `side` shifts it sideways (px).
static func begin(on_slime: Slime, the_coin: Coin, is_jelly: bool, is_calm: bool, tint: Color,
		rainbow: bool, side := 0.0) -> CoinCatch:
	var c := CoinCatch.new()
	c.slime = on_slime
	c.coin = the_coin
	c.jelly = is_jelly
	c.calm = is_calm
	c._tint = tint
	c._side = side
	c.process_physics_priority = 1  # after the slime has moved and set its sprite this tick
	c._from = (the_coin.global_position - on_slime.global_position).round()
	on_slime.add_child(c)
	the_coin.reparent(c, false)
	the_coin.z_index = 0
	the_coin.z_as_relative = true
	if is_calm:
		c._start_dissolve()
		c.dissolve_time = Economy.COIN_CATCH_CALM_TIME
	else:
		c.z_index = 2  # over the slime and its hat while in the air
		the_coin.position = c._from
		the_coin._spin = Economy.COIN_CATCH_TOSS_SPIN
		c.toss_time = on_slime.catch_hop()
		c._sparkles = c._particles(Economy.COIN_CATCH_SPARKLES, 0.35, COIN_GOLD, false)
		c._sparkles.local_coords = false  # a trail left in the air
		c._sparkles.position = c._from
		c._sparkles.emitting = true
		if rainbow:
			c._tint = Color.WHITE
	if not is_calm:
		c._bubbles = c._particles(Economy.COIN_CATCH_BUBBLES, 0.5, c._tint, rainbow)
		c._bubbles.direction = Vector2.UP
		c._bubbles.spread = 25.0
		c._bubbles.initial_velocity_min = 5.0
		c._bubbles.initial_velocity_max = 11.0
		c._bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		c._bubbles.emission_sphere_radius = 2.0
		c._bubbles.z_index = 1  # just over the body, inside its outline
	c.reset_physics_interpolation()
	the_coin.reset_physics_interpolation()
	return c


func _physics_process(delta: float) -> void:
	if not is_instance_valid(coin):
		return
	t += delta
	if _glint_left > 0:
		_glint_left -= 1
		_dirty = true
	var body := slime.sprite.position
	if phase == Phase.TOSS:
		var u := clampf(t / maxf(toss_time, 0.001), 0.0, 1.0)
		var head := body + Vector2(_side, HEAD_Y)
		var arc := maxf(Economy.COIN_CATCH_TOSS_HEIGHT + (_from.y + head.y) * 0.5, 4.0)
		var at := (_from.lerp(head, u) - Vector2(0.0, arc * sin(PI * u))).round()
		if u >= 0.5 and not _topped:
			_topped = true
			_glint_left = GLINT_TICKS  # a glint as it tops out
		coin.position = at
		_sparkles.position = at
		if _glint_left > 0:
			_glint_at = at + Vector2(3, -4)
		if u >= 1.0:
			_catch()
	else:
		var k := clampf(t / dissolve_time, 0.0, 1.0)
		var ease_k := 1.0 - (1.0 - k) * (1.0 - k)
		if calm:
			ease_k = 1.0  # Reduce Motion: it holds still in the body while it fades
		var sink := lerpf(JELLY_FROM_Y, JELLY_TO_Y, ease_k) if jelly else lerpf(SOLID_FROM_Y, SOLID_TO_Y, ease_k)
		coin.position = (body + Vector2(roundf(_side * 0.5), sink)).round()
		# Shrinks in whole even sizes (12, 10, ... 2 px), never a blurry in-between.
		var size := 2.0 * roundf(lerpf(6.0, 1.0, k))
		coin.scale = Vector2.ONE * (size / Coin.FRAME)
		coin.modulate.a = 1.0 - k * k * (0.6 if jelly else 0.8)
		if _bubbles:
			_bubbles.position = coin.position
			_bubbles.emitting = k < 0.85
		if _glint_left > 0:
			_glint_at = coin.position + Vector2(2, -3)
		if not calm and not jelly and t <= Economy.COIN_CATCH_RIPPLE_TIME:
			var r := t / Economy.COIN_CATCH_RIPPLE_TIME
			_ripple = Vector2(roundf(lerpf(2.0, Economy.COIN_CATCH_RIPPLE_PX, r)), 1.0 - r)
			_ripple_at = body + Vector2(0.0, SOLID_FROM_Y + 2.0)
			_dirty = true
		elif _ripple.x >= 0.0:
			_ripple.x = -1.0
			_dirty = true
		if k >= 1.0:
			finish()
			return
	if _dirty:
		_dirty = false
		queue_redraw()


## The coin lands on the slime's head: the coin sound, then the dissolve.
func _catch() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("coin", Economy.COIN_CATCH_COIN_DB)
	_sparkles.emitting = false
	_glint_left = GLINT_TICKS
	_start_dissolve()


func _start_dissolve() -> void:
	phase = Phase.DISSOLVE
	t = 0.0
	coin._spin = 1.0 if calm else 2.5
	z_index = 0  # over the body, under the hat
	if jelly:  # seen through the goo: tinted by it and a little faded
		coin.self_modulate = Color(Color.WHITE.lerp(_tint, JELLY_TINT), JELLY_ALPHA)
	if _bubbles:
		_bubbles.emitting = true
	_physics_process(0.0)  # placed right away


## Ends the show now (it ran out, or a win / dry-up / too many at once): `done`, then gone.
func finish() -> void:
	if is_queued_for_deletion():
		return
	set_physics_process(false)
	done.emit(self)
	queue_free()


func _draw() -> void:
	if _glint_left > 0:  # a little four-point star
		var g := _glint_at
		draw_rect(Rect2(g, Vector2.ONE), GLINT)
		var arm := Color(COIN_GOLD, 0.9)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2(g + d, Vector2.ONE), arm)
		if _glint_left > GLINT_TICKS / 2:
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(g + d * 2.0, Vector2.ONE), Color(COIN_GOLD, 0.5))
	if _ripple.x >= 0.0:  # a flat ring of goo spreading over the body's top
		var color := Color(_tint, 0.8 * _ripple.y)
		for i in RIPPLE_DOTS:
			var a := TAU * i / RIPPLE_DOTS
			draw_rect(Rect2((_ripple_at + Vector2(cos(a) * _ripple.x, sin(a) * _ripple.x * 0.5)).round(), Vector2.ONE), color)


func _particles(amount: int, life: float, color: Color, rainbow: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.gravity = Vector2.ZERO
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color = color
	p.color_ramp = Fx._fade_out()
	if rainbow:
		p.color_initial_ramp = Fx.rainbow_gradient()
	add_child(p)
	return p
