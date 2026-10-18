extends Node2D

## Capture scenario: the level 1-2 TutorialCues glyphs in fixed states, for a pixel check of their drawing
## (the training cues share it: tutorial_cues.gd's static helpers). Nothing moves; each step redraws:
##   frame 10: keyboard (W A S D, SPACE), frame 20: gamepad (d-pad, A), frame 30: touch (d-pad, JUMP),
##   frame 40: keyboard with the arrows bound to move and J to jump, frame 50: the same at the other bob step.
## Each row: a move-only cue, a leap-only cue, both at once (alpha 1), both at alpha 0.4.
## ./tools/godot.sh --path . --write-movie /tmp/cues/f.png --fixed-fps 60 --quit-after 56 res://tests/demo_cue_golden.tscn

## Stands in for game.gd: TutorialCues reads only `touch_controls.visible` and `finished` while drawing.
class FakeGame extends Node:
	var touch_controls := Control.new()
	var finished := false

var cues: Array[TutorialCues] = []
var fake := FakeGame.new()
var frame := 0


func _ready() -> void:
	var progress := get_node("/root/Progress")
	progress.saving_enabled = false
	RenderingServer.set_default_clear_color(Color.BLACK)
	add_child(fake)
	fake.add_child(fake.touch_controls)
	fake.touch_controls.visible = false
	var states := [[1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [0.4, 0.4]]
	for i in states.size():
		var cue := TutorialCues.new()
		cue.game = fake
		cue.position = Vector2(40 + i * 80, 100)
		cue.move_alpha = states[i][0]
		cue.leap_alpha = states[i][1]
		add_child(cue)
		cue.set_process(false)  # frozen: the state above, the first bob step
		cues.append(cue)


func _physics_process(_delta: float) -> void:
	frame += 1
	match frame:
		10:
			Platform.last_input = Platform.INPUT_KEYS
		20:
			Platform.last_input = Platform.INPUT_PAD
		30:
			Platform.last_input = Platform.INPUT_TOUCH
			fake.touch_controls.visible = true
		40:
			Platform.last_input = Platform.INPUT_KEYS
			fake.touch_controls.visible = false
			_bind("move_up", KEY_UP)
			_bind("move_left", KEY_LEFT)
			_bind("move_down", KEY_DOWN)
			_bind("move_right", KEY_RIGHT)
			_bind("jump", KEY_J)
		50:
			for cue in cues:
				cue._time = 0.5
		_:
			return
	for cue in cues:
		cue.queue_redraw()


## Puts `key` first on `action` (as a remap would), for this run only.
func _bind(action: String, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	for old in InputMap.action_get_events(action):
		if old is InputEventKey:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)
