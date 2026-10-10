extends SceneTree

## Phase 4 checks: the sprite sheet has every animation with enough frames, each game state
## shows the right animation, and lit areas fade back toward darkness in steps.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_phase4.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
	var manifest: Dictionary = preload("res://assets/sprites/slime_sheet.json").data.anims
	var glide_frames := 0
	var jump_frames := 0
	for anim_name: String in manifest:
		var count := int(manifest[anim_name].frames)
		if anim_name.begins_with("glide_") or anim_name == "idle":
			glide_frames += count
		elif anim_name.get_slice("_", 0) in ["charge", "launch", "air", "land", "splat"] or anim_name == "recover":
			jump_frames += count
	_check(glide_frames >= 16, "%d gliding/idle frames (8 directions)" % glide_frames)
	_check(jump_frames >= 20, "%d jumping frames (charge, launch, air, land, splat, recover)" % jump_frames)
	for anim_name in ["dry", "celebrate", "splat_n", "splat_e", "splat_s", "splat_w", "glide_ne", "air_sw"]:
		_check(manifest.has(anim_name), "has animation '%s'" % anim_name)

	var game := await _spawn()
	var slime: Slime = game.slime
	var open_right: bool = Vector2i.RIGHT in MazeGenerator.open_neighbors(game.maze, game.maze.start)
	var action := "move_right" if open_right else "move_down"
	var glide_anim := "glide_e" if open_right else "glide_s"
	_check(slime.sprite.animation == "idle", "standing still shows idle")
	Input.action_press(action)
	await _wait(0.3)
	_check(slime.sprite.animation == glide_anim and slime.sprite.is_playing(),
		"gliding shows %s (got %s)" % [glide_anim, slime.sprite.animation])
	Input.action_release(action)
	await _wait(1.0)
	_check(slime.sprite.animation == "idle", "stopping returns to idle")

	Input.action_press("jump")
	await _wait(0.8)
	_check(slime.sprite.animation.begins_with("charge_") and slime.sprite.frame == 2,
		"charging shows charge frames that follow the meter (frame %d at %.0f%%)" % [slime.sprite.frame, slime.charge])
	slime.facing = Vector2.UP
	Input.action_release("jump")
	await physics_frame
	await physics_frame
	_check(slime.sprite.animation == "launch_n", "jumping starts with launch frames (got %s)" % slime.sprite.animation)
	_check(slime.shadow.visible, "a shadow shows under the slime in the air")
	for i in 60:
		if slime.state == Slime.State.STUNNED:
			break
		await physics_frame
	_check(slime.sprite.animation == "splat_n", "hitting the wall above shows splat_n (got %s)" % slime.sprite.animation)
	_check(not slime.shadow.visible, "shadow hides on landing")
	await _wait(0.35)
	_check(slime.sprite.animation == "recover", "after the stun the slime wobbles back (got %s)" % slime.sprite.animation)

	# Fading: the start is lit, then left alone it steps down toward darkness.
	var start: Vector2 = MazeGenerator.cell_center(game.maze.start, 16)
	_check(game.fog_alpha_at(start) == 0.0, "the area around the slime is fully lit")
	var path := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	var far := MazeGenerator.cell_center(path[path.size() / 2], 16)  # well away from the start and the chalice
	slime.position = far
	game.last_slime_pos = far
	await _wait(2.0)
	var after_4: float = game.fog_alpha_at(start)
	await _wait(3.0)
	var after_9: float = game.fog_alpha_at(start)
	await _wait(5.0)
	var after_21: float = game.fog_alpha_at(start)
	_check(after_4 > 0.0 and after_9 > after_4 and after_21 > after_9 and after_21 < 1.0,
		"left behind, it darkens in layers: %.2f -> %.2f -> %.2f (never fully black)" % [after_4, after_9, after_21])
	_check(game.fog_alpha_at(far) == 1.0, "unexplored areas stay black even next to the slime")
	slime.position = start
	game.last_slime_pos = start
	await _wait(0.1)
	_check(game.fog_alpha_at(start) == 0.0, "coming back relights it")
	_check(game.fade_alpha(0.0) == 0.0 and game.fade_alpha(1000.0) == game.FADE_ALPHA[-1], "fade starts lit and ends at the memory level")
	game.free()

	game = await _spawn()
	game.slime_remaining = 0.2
	Input.action_press(action)
	await _wait(0.5)
	Input.action_release(action)
	_check(game.slime.sprite.animation == "dry", "running out of slime plays the dry-up")
	game.free()

	game = await _spawn()
	game.slime.position = game.chalice.position
	await _wait(0.1)
	_check(game.slime.sprite.animation == "celebrate", "reaching the chalice plays the celebration")
	game.free()

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	return game


func _wait(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
