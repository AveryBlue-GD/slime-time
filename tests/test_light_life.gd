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

	# ENV-21: every preset skin lights within +-10% of the same luminance (strength x full-value luma)
	for preset: Dictionary in Skins.PRESETS:
		var c: Color = preset.color
		var lum: float = LightLife.luminance(LightLife.light_color("dungeon", c)) * LightLife.strength_scale(c)
		print("light luma ", preset.id, " ", snappedf(lum, 0.001))
		_check(absf(lum / LightLife.LIGHT_LUMA_TARGET - 1.0) <= 0.1, "%s skin light is within 10%% of the target luminance" % preset.id)

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
	_check(mat.get_shader_parameter("goal_fx") == null, "no chalice rays: the fog has no goal_fx (no hint through the fog)")
	game._on_goal_body_entered(game.slime)
	_check(Engine.time_scale == 1.0 and game._hitstop_frames == 2 and not game.is_physics_processing(), "win: 2-frame hit-stop freezes physics only")
	for i in 4:
		await process_frame
	_check(Engine.time_scale == 1.0 and game.is_physics_processing(), "hit-stop ends, time scale stays 1 and physics resumes within a few frames")
	await _wait_seconds(0.4)
	_check(game._sunrise_t > 0.0, "the sunrise clock runs")
	_check(float(mat.get_shader_parameter("sunrise")) >= 0.0, "sunrise reaches the fog")
	_check(mat.get_shader_parameter("ll_motion") == true, "motion on: the fog's ll_motion is true")
	game.queue_free()
	await process_frame

	# Reduce Motion: ll_motion false (no glint flicker, no sunrise ring) and no hit-stop
	progress.reduce_motion = true
	game = await _spawn_game({level = 10})
	mat = game.fog_sprite.material as ShaderMaterial
	await _physics_frames(3)
	_check(mat.get_shader_parameter("ll_motion") == false, "Reduce Motion: ll_motion is false")
	game._on_goal_body_entered(game.slime)
	_check(game._hitstop_frames == 0 and game.is_physics_processing(), "Reduce Motion: no hit-stop")
	progress.reduce_motion = false
	game.queue_free()
	Economy.lightlife_force = -1
	_result()
	quit(0 if failures == 0 else 1)
