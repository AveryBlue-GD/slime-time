extends Node

## Capture scenario: SPLASHDOWN's training cues (chunk C; docs/tutorial/design.md section 3), nothing saved.
##   --shot=leap   the leap key on the straight beat, then held (the hold bar fills) and released
##   --shot=pulse  the first glide: the move glyph fades, the meter pod pulses once
##   --shot=dry    the meter runs out: the dry-up row with the accept glyph by RESTART
##   --device=keys|pad|touch  which prompts (touch: the on-screen controls are up)
## ./tools/godot.sh --path . --write-movie /tmp/tc/leap_keys.png --fixed-fps 60 --quit-after 150 \
##     res://tests/demo_training_cues.tscn -- --shot=leap --device=pad

var game: Node2D
var frame := 0
var shot := "leap"
var device := "keys"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.get_slice("=", 1)
		elif arg.begins_with("--device="):
			device = arg.get_slice("=", 1)
	var progress := get_node("/root/Progress")
	progress.saving_enabled = false
	progress.force_touch = device == "touch"
	progress.prepare_training(false)
	game = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	Platform.last_input = {keys = Platform.INPUT_KEYS, pad = Platform.INPUT_PAD, touch = Platform.INPUT_TOUCH}[device]
	if frame == 3:
		get_tree().current_scene = game
	match shot:
		"leap":
			if frame == 20:
				Input.action_press("move_right")
			elif frame == 26:
				Input.action_release("move_right")
			elif frame == 60:
				game.training_beat("straight")
			elif frame == 100:
				Input.action_press("jump")
			elif frame == 150:
				Input.action_release("jump")
		"pulse":
			if frame == 50:
				Input.action_press("move_right")
			elif frame == 64:
				Input.action_release("move_right")
		"dry":
			if frame == 20:
				Input.action_press("move_right")
			elif frame == 30:
				game.slime_remaining = 0.0
			elif frame == 34:
				Input.action_release("move_right")
