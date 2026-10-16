class_name RestartPrompt
extends CanvasLayer

## Pressing R mid-run asks before throwing the run away: RESTART, UPGRADES (spend coins first;
## the upgrades screen's PLAY button comes back to the level) or CANCEL (also Esc or R again).
## Pauses the game while it's open.

var buttons: Array[Button] = []
var game: Node
var _focus_lock := {}


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
	# Three 13 px buttons 3 apart, PANEL_PAD above and below (like the pause menu).
	UIKit.add_panel(root, Rect2(100, 60 - UIKit.PANEL_PAD, 120, UIKit.PANEL_PAD * 2 + 3 * UIKit.BUTTON_H + 2 * UIKit.GAP_S))
	# i18n: title max 150px; buttons max 96px, 1 line each
	var title := UIKit.make_label(Loc.t("restart.title", "RESTART?"), UIKit.FONT_BIG, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(320, 20)
	root.add_child(title)
	var menu := VBoxContainer.new()
	menu.position = Vector2(110, 60)
	menu.custom_minimum_size = Vector2(100, 0)
	menu.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(menu)
	buttons = [
		UIKit.make_button(Loc.t("restart.restart", "RESTART"), _restart),
		UIKit.make_button(Loc.t("restart.upgrades", "UPGRADES"), _upgrades),
		UIKit.make_button(Loc.t("common.cancel", "CANCEL"), close),
	]
	for button in buttons:
		menu.add_child(button)
	UIKit.add_skin_text(root)


func open() -> void:
	visible = true
	get_tree().paused = true
	var hud: Node = game.get("hud") if game else null
	if hud and hud.has_method("cover_area_texts"):
		hud.cover_area_texts()  # (they would show through around RESTART?; back on close)
	buttons[0].grab_focus()
	if _focus_lock.is_empty():  # the level's other controls can't take focus meanwhile
		_focus_lock = UIKit.lock_focus(get_parent(), self)


func close() -> void:
	visible = false
	get_tree().paused = false
	var hud: Node = game.get("hud") if game else null
	if hud and hud.has_method("uncover_area_texts"):
		hud.uncover_area_texts()
	UIKit.unlock_focus(_focus_lock)


func _restart() -> void:
	close()
	game.retry("prompt RESTART")


func _upgrades() -> void:
	var transition := get_node_or_null("/root/Transition")
	if transition == null or transition.busy:
		close()
		game.go_to_upgrades()
		return
	# The level stays paused under the wipe (Transition.go unpauses as it swaps the scene).
	visible = false
	game.go_to_upgrades()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("restart")):
		get_viewport().set_input_as_handled()
		close()
