extends Panel

## Marketing only (tools/trailer/portrait.gd): the skins screen's try-on stage (SkinShowcase) rebuilt
## for a 9:16 frame: any width and slime scale, the same dungeon floor under the same goo frame, and
## SkinShowcase.ROUTINE (idle, glide, charge, leap, land, celebrate, leap back, splat) spread over the
## width. `routine` false = the slime just idles in the middle (celebrate() plays the win hop).

var stage_size := Vector2(172, 76)
var px := 3
var routine := true
var slime: AnimatedSprite2D
var _time := 0.0
var _length := 0.0


func _init(size_: Vector2, scale_: int, routine_ := true) -> void:
	stage_size = size_
	px = scale_
	routine = routine_


func _ready() -> void:
	size = stage_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_lay_floor()
	var frame := Panel.new()
	var goo := GooBox.make_panel()
	goo.face = Color(0, 0, 0, 0)
	frame.add_theme_stylebox_override("panel", goo)
	frame.size = stage_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	for step: Array in SkinShowcase.ROUTINE:
		_length += step[1]


## SkinShowcase._lay_floor at this size (the same seed: mostly plain stone, the odd variant).
func _lay_floor() -> void:
	var atlas: Texture2D = load("res://assets/sprites/floors.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var inner := Rect2(Vector2(2, 2), stage_size - Vector2(4, 4))
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


## Where the slime's centre sits on the floor: its 20 px frame's bottom row on the stage's last row.
func floor_y() -> float:
	return stage_size.y - 1.0 - 10.0 * px


func show_skin(color: Color, rainbow: bool, jelly: bool, locked := false, clock := false) -> void:
	if slime:
		slime.queue_free()
	slime = UIKit.make_slime_preview(color, px, rainbow, jelly, clock)
	add_child(slime)
	if locked:
		slime.modulate = Color(0, 0, 0, 0.85)
	_time = 0.0
	_pose()


## The win hop (the wheel's try-on): celebrate, then idle again.
func celebrate() -> void:
	if slime == null:
		return
	slime.play("celebrate")
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(slime):
			slime.play("idle"))


func _process(delta: float) -> void:
	if slime and routine:
		_time = fmod(_time + delta, _length)
		_pose()


## SkinShowcase.ROUTINE's x (22..160 on its 220 px stage) spread over this stage's floor.
func _x(x: float) -> float:
	var edge := 10.0 * px + 2.0
	return edge + (x - 22.0) / 138.0 * (stage_size.x - 2.0 * edge)


func _pose() -> void:
	if not routine:
		slime.position = Vector2(roundf(stage_size.x / 2.0), floor_y())
		return
	var t := _time
	for step: Array in SkinShowcase.ROUTINE:
		if t < step[1] or step == SkinShowcase.ROUTINE[-1]:
			var progress := clampf(t / step[1], 0.0, 1.0)
			_show(step[0], progress)
			var x: float = lerpf(_x(step[2]), _x(step[3]), progress)
			var lift: float = step[4] * px / 2.0 * sin(progress * PI)
			slime.position = Vector2(roundf(x), roundf(floor_y() - lift))
			return
		t -= step[1]


## SkinShowcase._show: stepped animations (fps 0) follow the segment's progress.
func _show(anim: String, progress: float) -> void:
	var frames := slime.sprite_frames
	if frames.get_animation_speed(anim) <= 1.0 and not frames.get_animation_loop(anim):
		slime.animation = anim
		slime.pause()
		slime.frame = mini(int(progress * frames.get_frame_count(anim)), frames.get_frame_count(anim) - 1)
	elif slime.animation != anim or not slime.is_playing() and frames.get_animation_loop(anim):
		slime.play(anim)
