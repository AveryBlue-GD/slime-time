extends SceneTree

## Visual polish pass: the trail has its rim/bevel shader, the slime's skin shader gets gloss and
## a charge tension while charging, and (further down) ambient effects and UI frames.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_polish.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.reduce_motion = false
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await _frames(10)

	var trail_material := game.trail_sprite.material as ShaderMaterial
	_check(trail_material != null and trail_material.shader.resource_path.ends_with("trail.gdshader"), "the trail uses the trail shader")
	_check(is_equal_approx(trail_material.get_shader_parameter("animate"), 1.0), "trail twinkle runs with full motion")

	var skin := game.slime.sprite.material as ShaderMaterial
	_check(is_equal_approx(skin.get_shader_parameter("gloss"), 1.0), "the slime's skin has gloss on")
	_check(is_equal_approx(skin.get_shader_parameter("charge"), 0.0), "no charge tension at rest")
	Input.action_press("jump")
	await _frames(30)
	_check(game.get_node("Slime").state == Slime.State.CHARGING and float(skin.get_shader_parameter("charge")) > 0.1, "charge tension rises while charging")
	Input.action_release("jump")
	await _frames(20)
	_check(is_equal_approx(skin.get_shader_parameter("charge"), 0.0), "tension relaxes after the leap")

	print("RESULT: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", message)
