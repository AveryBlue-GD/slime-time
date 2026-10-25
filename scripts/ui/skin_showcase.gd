class_name SkinShowcase
extends Panel

## The skins screen's preview stage: a double-size slime in the clicked skin acting out a loop —
## it idles, glides, charges a leap, lands and celebrates, then leaps back into the left edge and
## splats. Locked skins play it as a silhouette. In a right-to-left language the routine runs mirrored
## (docs/ui-rules.md 10.2: the try-on slime's position mirrors, the art never flips): it starts at the
## right end, and each east / west step plays the sheet's own west / east animation.

const STAGE_SIZE := Vector2(220, 48)
## Where the slime's center sits when it's on the floor (stage coordinates).
const FLOOR_Y := 27.0
## The routine: [animation, seconds, from x, to x, arc height]. Animations with an fps of 0 in the
## sheet (charge, launch, air, splat) are stepped through over their segment.
const ROUTINE := [
	["idle", 0.8, 22.0, 22.0, 0.0],
	["glide_e", 1.0, 22.0, 80.0, 0.0],
	["charge_e", 0.6, 80.0, 80.0, 0.0],
	["launch_e", 0.1, 80.0, 84.0, 2.0],
	["air_e", 0.6, 84.0, 160.0, 14.0],
	["land_e", 0.25, 160.0, 160.0, 0.0],
	["celebrate", 1.2, 160.0, 160.0, 0.0],
	["charge_w", 0.5, 160.0, 160.0, 0.0],
	["launch_w", 0.1, 160.0, 156.0, 1.0],
	["air_w", 0.45, 156.0, 22.0, 6.0],
	["splat_w", 0.45, 22.0, 22.0, 0.0],
	["recover", 0.25, 22.0, 22.0, 0.0],
]

var slime: AnimatedSprite2D
## The worn hat on the previewed slime (null = none) and the trail it leaves (the worn style, painted
## by `_trail` along the floor as the slime glides; Cosmetics.trail_look / trail_cell_at, 2 px cells like the game).
var hat: Hat
var _trail: Node2D
var _trail_look := {}
var _trail_color := Color.WHITE
var _trail_rainbow := false
var _trail_xs: Array[int] = []  # cell x (stage px, even), oldest first
var _trail_born: Array[float] = []  # _clock when each cell was laid
var _clock := 0.0
var _last_cell_x := -1
## A laid cell fades out over TRAIL_FADE seconds in TRAIL_STEPS integer alpha steps. Reduce Motion: no fade,
## a static tail of the last TRAIL_STATIC_CELLS cells.
const TRAIL_FADE := 1.0
const TRAIL_STEPS := 4
const TRAIL_STATIC_CELLS := 6
var _time := 0.0
var _length := 0.0
## The trail band: rows of 2 px cells (stage y = row * 2), around the floor line under the slime's body.
const TRAIL_ROWS := Vector2i(11, 17)


func _ready() -> void:
	size = STAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_lay_floor()
	# The goo frame over the floor's edges (see-through face), under the slime.
	var frame := Panel.new()
	var goo := GooBox.make_panel()
	goo.face = Color(0, 0, 0, 0)
	frame.add_theme_stylebox_override("panel", goo)
	frame.size = STAGE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_trail = TrailLayer.new()
	_trail.showcase = self
	add_child(_trail)
	for step: Array in ROUTINE:
		_length += step[1]


## The stage's trail painter (under the slime, over the floor).
class TrailLayer extends Node2D:
	var showcase: SkinShowcase

	func _draw() -> void:
		if showcase == null or showcase._trail_look.is_empty():
			return
		var look: Dictionary = showcase._trail_look
		for i in showcase._trail_xs.size():
			var x: int = showcase._trail_xs[i]
			var a := showcase._cell_alpha(i)
			if a <= 0.0:
				continue
			var cx := x / 2
			var hue := fposmod(x / SkinShowcase.STAGE_SIZE.x, 1.0) * 0.83
			for cy in range(SkinShowcase.TRAIL_ROWS.x, SkinShowcase.TRAIL_ROWS.y + 1):
				var deep := posmod(hash(Vector2i(cx, cy)), 5) == 0
				var c := Cosmetics.trail_cell_at(look, deep, float(x), Vector2i(cx, cy), hue)
				draw_rect(Rect2(cx * 2, cy * 2, 2, 2), Color(c.r, c.g, c.b, c.a * a))
			var center: Variant = Cosmetics.trail_center(look, float(x))
			if center != null:
				draw_rect(Rect2(cx * 2, 28, 2, 2), Color(center.r, center.g, center.b, center.a * a))


## Dungeon floor tiles under the goo frame (so the jelly has ground to show through), mostly plain
## stone with the odd variant, the same every time.
func _lay_floor() -> void:
	var atlas: Texture2D = load("res://assets/sprites/floors.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var inner := Rect2(Vector2(2, 2), STAGE_SIZE - Vector2(4, 4))
	var floor_root := Control.new()
	floor_root.position = inner.position
	floor_root.size = inner.size
	floor_root.clip_contents = true
	floor_root.modulate = Color(0.75, 0.75, 0.75)
	floor_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_root)
	for y in ceili(inner.size.y / 16.0):
		for x in ceili(inner.size.x / 16.0):
			var tile := TextureRect.new()
			var region := AtlasTexture.new()
			region.atlas = atlas
			var type := 0 if rng.randf() < 0.8 else rng.randi_range(1, 2)
			region.region = Rect2(type * 16, rng.randi_range(0, 3) * 16, 16, 16)
			tile.texture = region
			tile.position = Vector2(x * 16, y * 16)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			floor_root.add_child(tile)


## Shows skin `color` (`rainbow`, `jelly` = see-through, `locked` = silhouette) and
## starts the routine from the top.
func show_skin(color: Color, rainbow: bool, jelly: bool, locked := false, clock := false, outfit := {}) -> void:
	if slime:
		slime.queue_free()
	if hat:
		hat.queue_free()
		hat = null
	slime = UIKit.make_slime_preview(color, 1, rainbow, jelly, clock)
	add_child(slime)
	UIKit.keep_ltr(slime)  # (placed mirrored by _pose every frame, not by UIKit's one-off Node2D mirror)
	if locked:
		Skins.lock_look(slime)  # SPR-28
	# `outfit` = {hat, dye, trail}: the look worn now, so the whole look is seen before choosing.
	var hat_id: String = outfit.get("hat", Hats.NONE)
	if hat_id != Hats.NONE:
		hat = Hat.new()
		hat.scale = slime.scale
		add_child(hat)
		hat.setup(hat_id, slime, null, outfit.get("dye", ""))
		hat.modulate = slime.modulate
	_trail_look = Cosmetics.trail_look(outfit.get("trail", Cosmetics.DEFAULT_TRAIL), color, rainbow) if not locked else {}
	_clear_trail()
	_time = 0.0
	_pose()


func _process(delta: float) -> void:
	if slime and is_visible_in_tree():
		var before := _time
		_time = fmod(_time + delta, _length)
		_clock += delta
		if _time < before:  # (the routine looped: the tail just fades on)
			_last_cell_x = -1
		_pose()
		_age_trail()


func _pose() -> void:
	var t := _time
	if slime.has_node("StopwatchFace"):  # the stopwatch's clock follows the routine
		Stopwatch.request(_clock_mode(_time))
	for step: Array in ROUTINE:
		if t < step[1] or step == ROUTINE[-1]:
			var progress := clampf(t / step[1], 0.0, 1.0)
			var mirrored := _mirrored()
			_show(_mirror_anim(step[0]) if mirrored else step[0], progress)
			var x: float = lerpf(step[2], step[3], progress)
			if mirrored:
				x = STAGE_SIZE.x - x
			var lift: float = step[4] * sin(progress * PI)
			slime.position = Vector2(roundf(x), roundf(FLOOR_Y - lift))
			if lift == 0.0 and not _trail_look.is_empty() and step[2] != step[3]:
				_lay_to(int(slime.position.x) / 2 * 2)
			else:
				_last_cell_x = -1
			return
		t -= step[1]


func _clear_trail() -> void:
	_trail_xs.clear()
	_trail_born.clear()
	_last_cell_x = -1
	_trail.queue_redraw()


## Lays a cell under the slime at `cell_x`, filling every cell passed since the last frame (no gaps).
func _lay_to(cell_x: int) -> void:
	var from := cell_x if _last_cell_x < 0 else _last_cell_x
	var dir := 1 if cell_x >= from else -1
	for x in range(from, cell_x + dir, 2 * dir):
		if _last_cell_x >= 0 and x == _last_cell_x:
			continue
		_trail_xs.append(x)
		_trail_born.append(_clock)
	_last_cell_x = cell_x
	_trail.queue_redraw()


## Reduce-motion setting; the Progress autoload is fetched via the tree (a global-class script can't name it directly).
static func _reduce_motion() -> bool:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Progress").reduce_motion


## Alpha factor of the i-th trail cell: 1 = fresh, quantized to TRAIL_STEPS steps, 0 = gone.
func _cell_alpha(i: int) -> float:
	if _reduce_motion():
		return 1.0 if i >= _trail_xs.size() - TRAIL_STATIC_CELLS else 0.0
	var left := 1.0 - (_clock - _trail_born[i]) / TRAIL_FADE
	return ceilf(clampf(left, 0.0, 1.0) * TRAIL_STEPS) / TRAIL_STEPS


## Drops the faded cells and redraws when a cell crossed an alpha step.
func _age_trail() -> void:
	if _trail_xs.is_empty():
		return
	while not _trail_xs.is_empty() and (_clock - _trail_born[0] >= TRAIL_FADE or (_reduce_motion() and _trail_xs.size() > TRAIL_STATIC_CELLS)):
		_trail_xs.remove_at(0)
		_trail_born.remove_at(0)
	_trail.queue_redraw()


## True when the stage is drawn mirrored (an RTL language, under a mirror root). Not is_mirrored():
## a relayout drops the root to LTR until the frame's end, and the slime must not jump for that frame.
func _mirrored() -> bool:
	return UIKit.rtl() and UIKit.mirror_root_of(self) != null


## The routine's animation for the mirrored stage: east <-> west (the sheet has both; art never flips).
static func _mirror_anim(anim: String) -> String:
	if anim.ends_with("_e"):
		return anim.trim_suffix("_e") + "_w"
	if anim.ends_with("_w"):
		return anim.trim_suffix("_w") + "_e"
	return anim


## What the stopwatch's clock does at routine time `t`: runs while gliding, whirls while charging
## and flying, idles otherwise.
func _clock_mode(t: float) -> int:
	for step: Array in ROUTINE:
		if t < step[1]:
			var anim: String = step[0]
			if anim.begins_with("glide"):
				return Stopwatch.Mode.MOVE
			if anim.begins_with("charge") or anim.begins_with("launch") or anim.begins_with("air"):
				return Stopwatch.Mode.LEAP
			return Stopwatch.Mode.IDLE
		t -= step[1]
	return Stopwatch.Mode.IDLE


func _show(anim: String, progress: float) -> void:
	var frames := slime.sprite_frames
	if frames.get_animation_speed(anim) <= 1.0 and not frames.get_animation_loop(anim):
		# Stepped animations: pick the frame from how far through the segment we are.
		slime.animation = anim
		slime.pause()
		slime.frame = mini(int(progress * frames.get_frame_count(anim)), frames.get_frame_count(anim) - 1)
	elif slime.animation != anim or not slime.is_playing() and frames.get_animation_loop(anim):
		slime.play(anim)
