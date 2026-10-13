extends Node2D

## Screenshot scenario: the stopwatch skin in several poses at game size (labels under each), with a
## hat on one. `-- --clock=leap|move|idle` pins the clock speed, `--solid` shows the solid version.
## ./tools/screenshot.sh --frames 60 --scene res://tests/demo_stopwatch.tscn --unlock-all -- --clock=leap

const POSES := [
	["idle", 0, "IDLE"], ["glide_e", 1, "GLIDE"], ["charge_e", 3, "CHARGE"], ["launch_e", 1, "LAUNCH"],
	["air_e", 1, "AIR"], ["land_e", 1, "LAND"], ["splat_w", 0, "SPLAT"],
]
var _mode := Stopwatch.Mode.IDLE


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--clock=leap":
			_mode = Stopwatch.Mode.LEAP
		elif arg == "--clock=move":
			_mode = Stopwatch.Mode.MOVE
	var bg := ColorRect.new()
	bg.color = Color8(34, 40, 58)
	bg.size = Vector2(320, 180)
	add_child(bg)
	var solid := "--solid" in OS.get_cmdline_user_args()
	for i in POSES.size():
		var pose: Array = POSES[i]
		var slime := _slime(Vector2(26 + i * 44, 40), pose[0], pose[1], solid)
		_label(pose[2], Vector2(26 + i * 44, 56))
		if i == 0:
			var hat := Hat.new()
			slime.add_child(hat)
			hat.setup("tophat", slime.sprite, slime)
	# Lower row: other backgrounds (pale floor, mid-grey) for contrast.
	for i in 3:
		var tint: Color = [Color8(120, 130, 120), Color8(70, 50, 40), Color8(10, 10, 14)][i]
		var patch := ColorRect.new()
		patch.color = tint
		patch.position = Vector2(20 + i * 100, 80)
		patch.size = Vector2(60, 30)
		add_child(patch)
		_slime(Vector2(50 + i * 100, 95), "idle", 1, solid)
	var wide := _slime(Vector2(60, 140), "idle", 0, solid)
	wide.sprite.scale = Vector2(2, 2)  # the skins-screen showcase scale


func _slime(pos: Vector2, anim: String, frame: int, solid := false) -> Slime:
	var slime: Slime = preload("res://scenes/slime.tscn").instantiate()
	slime.get_node("Camera2D").queue_free()
	add_child(slime)
	slime.position = pos
	slime.set_physics_process(false)
	slime.apply_skin(Skins.STOPWATCH_BASE, false, true)
	slime.set_translucency(0.0 if solid else 1.0)
	slime.sprite.animation = anim
	slime.sprite.frame = frame
	slime.sprite.pause()
	return slime


func _label(text: String, pos: Vector2) -> void:
	var l := UIKit.make_label(text, 8, UIKit.TEXT)
	l.position = pos + Vector2(-20, 0)
	l.size = Vector2(40, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)


func _process(_delta: float) -> void:
	Stopwatch.request(_mode)
