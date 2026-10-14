class_name RestartPrompt
extends CanvasLayer

## Pressing R mid-run asks before throwing the run away: RESTART, UPGRADES (spend coins first;
## the upgrades screen's PLAY button comes back to the level) or CANCEL (also Esc or R again).
## Pauses the game while it's open.

var buttons: Array[Button] = []
var game: Node


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.theme = UIKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	UIKit.add_panel(root, Rect2(100, 52, 120, 76))
	var title := UIKit.make_label("RESTART?", 16, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(320, 20)
	root.add_child(title)
	var menu := VBoxContainer.new()
	menu.position = Vector2(110, 60)
	menu.custom_minimum_size = Vector2(100, 0)
	menu.add_theme_constant_override("separation", 3)
	root.add_child(menu)
	buttons = [
		UIKit.make_button("RESTART", _restart),
		UIKit.make_button("UPGRADES", _upgrades),
		UIKit.make_button("CANCEL", close),
	]
	for button in buttons:
		menu.add_child(button)
	UIKit.add_skin_text(root)


func open() -> void:
	visible = true
	get_tree().paused = true
	buttons[0].grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _restart() -> void:
	close()
	game.retry("prompt RESTART")


func _upgrades() -> void:
	close()
	game.go_to_upgrades()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("restart")):
		get_viewport().set_input_as_handled()
		close()
