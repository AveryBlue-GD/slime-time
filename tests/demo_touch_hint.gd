extends Node

## Screenshot scenario: level 1's move glyph (a d-pad, touch controls up) fading after a move made
## on the touch joystick: a real InputEventScreenTouch + ScreenDrag, as on a phone. With `--hitch`
## a half-second frame lands right after the first glide (as a phone browser's first-glide stall
## does), which used to leave the glyph stuck on screen. Prints the frame of the touch.
## ./tools/godot.sh --path . --write-movie /tmp/x/f.png --fixed-fps 60 --quit-after 150 res://tests/demo_touch_hint.tscn [-- --hitch]

const TOUCH_AT := 60
const StartDirs := preload("res://tests/start_dirs.gd")

var game: Node2D
var frame := 0
var hitched := false


func _ready() -> void:
	var progress := get_node("/root/Progress")
	progress.saving_enabled = false
	progress.tutorial_seen = 0
	progress.force_touch = true
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 1
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		get_tree().current_scene = game
	elif frame == TOUCH_AT:
		print("TOUCH at frame %d" % frame)
		var dir := StartDirs.open_dir(game.maze, game.maze.start)
		_touch(Vector2(50, 130), true)
		var drag := InputEventScreenDrag.new()
		drag.position = _window(Vector2(50, 130) + Vector2(dir) * 16.0)
		Input.parse_input_event(drag)
	elif frame > TOUCH_AT and not hitched and "--hitch" in OS.get_cmdline_user_args():
		for child in game.slime.get_children():
			if child is TutorialCues and child._moved:
				child._process(0.5)
				hitched = true
	if frame == TOUCH_AT + 30:
		_touch(Vector2(66, 130), false)


func _touch(view_pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = _window(view_pos)
	event.pressed = pressed
	Input.parse_input_event(event)


func _window(view_pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * view_pos
