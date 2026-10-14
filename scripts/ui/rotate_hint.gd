extends CanvasLayer

## Autoload "RotateHint": on a touchscreen held upright (portrait), covers the screen with a
## "rotate your phone" message, since the game is widescreen. While it shows, the game is paused
## (so a first-launch story or a level doesn't run on unseen behind it) and the cover takes the taps.

var _cover: Control
var _last_size := Vector2i(-1, -1)
## Whether the tree was already paused (e.g. the pause menu was open) when the cover came up, and
## the scene it came up over: put back as it was when the phone is turned sideways again.
var _was_paused := false
var _covered_scene: Node


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = Control.new()
	_cover.theme = UIKit.make_theme()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(bg)
	var text := UIKit.make_label("ROTATE YOUR PHONE\n\nSLIME TIME IS PLAYED SIDEWAYS", 8, UIKit.GOLD)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cover.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_update.call_deferred()


## The window size is checked every frame: with the `viewport` stretch mode the root viewport
## stays 320x180, so `size_changed` doesn't fire when a browser canvas turns from portrait to
## landscape (web QA pass: the cover stayed up after turning the phone until a finger touched).
func _process(_delta: float) -> void:
	var size := DisplayServer.window_get_size()
	if size != _last_size:
		_last_size = size
		_update()
	elif visible and not get_tree().paused:
		get_tree().paused = true  # something (a finished goo wipe) unpaused it under the cover


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_update()


func _update() -> void:
	set_shown(should_show(DisplayServer.window_get_size(), DisplayServer.is_touchscreen_available()))


## Shows or hides the cover, pausing the game under it and putting the pause state back after.
func set_shown(shown: bool) -> void:
	if shown == visible:
		return
	visible = shown
	var tree := get_tree()
	if shown:
		_was_paused = tree.paused
		_covered_scene = tree.current_scene
		tree.paused = true
	else:
		# A screen that changed under the cover starts unpaused, like any new screen (Transition.go).
		tree.paused = _was_paused and is_instance_valid(_covered_scene) and tree.current_scene == _covered_scene
		_covered_scene = null


static func should_show(window_size: Vector2i, touchscreen: bool) -> bool:
	return touchscreen and window_size.y > window_size.x
