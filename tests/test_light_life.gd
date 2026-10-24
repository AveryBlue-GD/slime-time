extends "res://tests/suite_base.gd"

## BM-09 LIGHT & LIFE (Economy.LIGHT_LIFE_TEST): the fog material gets the light settings only with the flag on
## (off = the old shader path), every theme has a light colour, the motes stay capped at 40, the goal's rays and the
## win's sunrise / 2-frame hit-stop run and the time scale is back to 1 afterwards.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_light_life.gd


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false
	_check(Economy.LIGHT_LIFE_TEST == true, "LIGHT_LIFE_TEST is on in this test build")
	Economy.lightlife_force = 0
	_check(not Economy.light_life_on(), "lightlife_force = 0 (--nolightlife) turns it off")
	for theme in Themes.BY_LEVEL:
		_check(LightLife.THEME_LIGHT.has(theme), "theme %s has a light colour" % theme)
		Economy.lightlife_force = 1
		_check(Ambient.amount_for(theme, false) <= Ambient.LIGHT_LIFE_MAX, "%s motes capped at 40" % theme)
		Economy.lightlife_force = 0
		_check(Ambient.amount_for(theme, false) <= Ambient.MAX_AMOUNT, "%s motes unchanged off" % theme)

	var off: Node2D = await _spawn_game({level = 1})
	var off_mat := off.fog_sprite.material as ShaderMaterial
	_check(off_mat.get_shader_parameter("ll_on") != true, "flag off: the fog's ll_on stays false")
	off.queue_free()
	await physics_frame

	Economy.lightlife_force = 1
	var game: Node2D = await _spawn_game({level = 10})
	var mat := game.fog_sprite.material as ShaderMaterial
	_check(mat.get_shader_parameter("ll_on") == true, "flag on: ll_on")
	_check(mat.get_shader_parameter("trail_tex") == game.trail_sprite.texture, "the trail texture is shared")
	await _physics_frames(3)
	var fx: Vector4 = mat.get_shader_parameter("goal_fx")
	_check(fx.w == 1.0 and fx.z == 192.0 and Vector2(fx.x, fx.y).is_equal_approx(game.goal.position), "goal rays aimed at the goal")
	game._on_goal_body_entered(game.slime)
	_check(Engine.time_scale == 0.0 and game._hitstop_frames == 2, "win: 2-frame hit-stop")
	for i in 4:
		await process_frame
	_check(Engine.time_scale == 1.0, "hit-stop ends, time scale back to 1")
	await _wait_seconds(0.4)
	_check(game._sunrise_t > 0.0, "the sunrise clock runs")
	_check(float(mat.get_shader_parameter("sunrise")) >= 0.0, "sunrise reaches the fog")
	game.queue_free()
	Economy.lightlife_force = -1
	_result()
	quit(0 if failures == 0 else 1)
