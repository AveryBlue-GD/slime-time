class_name SkinShowcase
extends Panel

## The skins screen's preview stage: a double-size slime in the clicked skin acting out a loop —
## it idles, glides, charges a leap, lands and celebrates, then leaps back into the left edge and
## splats. Locked skins play it as a silhouette.

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
var _time := 0.0
var _length := 0.0


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
	for step: Array in ROUTINE:
		_length += step[1]


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
func show_skin(color: Color, rainbow: bool, jelly: bool, locked := false) -> void:
	if slime:
		slime.queue_free()
	slime = UIKit.make_slime_preview(color, 2, rainbow, jelly)
	add_child(slime)
	if locked:
		slime.modulate = Color(0, 0, 0, 0.85)
	_time = 0.0
	_pose()


func _process(delta: float) -> void:
	if slime and is_visible_in_tree():
		_time = fmod(_time + delta, _length)
		_pose()


func _pose() -> void:
	var t := _time
	for step: Array in ROUTINE:
		if t < step[1] or step == ROUTINE[-1]:
			var progress := clampf(t / step[1], 0.0, 1.0)
			_show(step[0], progress)
			var x: float = lerpf(step[2], step[3], progress)
			var lift: float = step[4] * sin(progress * PI)
			slime.position = Vector2(roundf(x), roundf(FLOOR_Y - lift))
			return
		t -= step[1]


func _show(anim: String, progress: float) -> void:
	var frames := slime.sprite_frames
	if frames.get_animation_speed(anim) <= 1.0 and not frames.get_animation_loop(anim):
		# Stepped animations: pick the frame from how far through the segment we are.
		slime.animation = anim
		slime.pause()
		slime.frame = mini(int(progress * frames.get_frame_count(anim)), frames.get_frame_count(anim) - 1)
	elif slime.animation != anim or not slime.is_playing() and frames.get_animation_loop(anim):
		slime.play(anim)
