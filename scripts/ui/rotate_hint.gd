extends CanvasLayer

## Autoload "RotateHint": on a touchscreen held upright (portrait), covers the screen with a
## "rotate your phone" message, since the game is widescreen.

var _cover: Control


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
	# Re-checked when the window changes size (turning the phone resizes it) or a finger touches
	# the screen, rather than every frame.
	get_window().size_changed.connect(_update)
	_update.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_update()


func _update() -> void:
	visible = should_show(DisplayServer.window_get_size(), DisplayServer.is_touchscreen_available())


static func should_show(window_size: Vector2i, touchscreen: bool) -> bool:
	return touchscreen and window_size.y > window_size.x
