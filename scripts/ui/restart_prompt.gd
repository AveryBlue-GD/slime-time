class_name RestartPrompt
extends CanvasLayer

## Pressing R mid-run asks before throwing the run away: RESTART, UPGRADES (spend coins first;
## the upgrades screen's PLAY button comes back to the level) or CANCEL (also Esc or R again).
## Pauses the game while it's open.

## The title's top (its box is UIKit.title_h() tall: 20 in English).
const TITLE_Y := 30.0

var buttons: Array[Button] = []
var game: Node
var _focus_lock := {}
var _root: Control
var _title: Label
var _panel: Control
var _menu: Control
## Where the title's line box is now (TITLE_Y, or lower under the HUD pods: _place).
var _title_y := TITLE_Y


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	_root = root
	root.theme = UIKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# Three buttons (button_h() tall, GAP_S apart, as wide as the longest word needs: 100 in English)
	# in a panel PANEL_PAD around them, 2 px under the title's box (RESTART? at y 30; the panel then
	# starts at 52 in English, lower under a taller script's title).
	# i18n: title max 150px; buttons max 96px, 1 line each
	var title_text := Loc.t("restart.title", "RESTART?")
	var texts := [Loc.t("restart.restart", "RESTART"), Loc.t("restart.upgrades", "UPGRADES"), Loc.t("common.cancel", "CANCEL")]
	var button_w := 100
	for text: String in texts:
		button_w = UIKit.button_w(text, button_w)
	var panel_top := TITLE_Y + UIKit.title_h() + 2
	var panel_w := button_w + 2 * 10
	_panel = UIKit.add_panel(root, Rect2(UIKit.center_x(panel_w), panel_top, panel_w, UIKit.PANEL_PAD * 2 + 3 * UIKit.button_h() + 2 * UIKit.GAP_S))
	var title := UIKit.make_label(title_text, UIKit.FONT_BIG, UIKit.GOLD)
	_title = title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, TITLE_Y)
	title.size = Vector2(320, UIKit.title_h())
	root.add_child(title)
	var menu := VBoxContainer.new()
	menu.position = Vector2(UIKit.center_x(button_w), panel_top + UIKit.PANEL_PAD)
	menu.custom_minimum_size = Vector2(button_w, 0)
	menu.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(menu)
	_menu = menu
	buttons = [
		UIKit.make_button(texts[0], _restart, Vector2(0, UIKit.button_h())),
		UIKit.make_button(texts[1], _upgrades, Vector2(0, UIKit.button_h())),
		UIKit.make_button(texts[2], close, Vector2(0, UIKit.button_h())),
	]
	for button in buttons:
		menu.add_child(button)
		UIKit.note_text_w(button, texts, 100)
	UIKit.add_skin_text(root)
	UIKit.mirror_root(root)  # (right-to-left languages: flipped once built, docs/ui-rules.md 10.2)


func open() -> void:
	visible = true
	get_tree().paused = true
	var hud: Node = game.get("hud") if game else null
	_place(hud)
	if hud and hud.has_method("cover_area_texts"):
		hud.cover_area_texts()  # (they would show through around RESTART?; back on close)
	buttons[0].grab_focus()
	if _focus_lock.is_empty():  # the level's other controls can't take focus meanwhile
		_focus_lock = UIKit.lock_focus(get_parent(), self)


## RESTART?'s box (its text width, shadow included) keeps GAP_L from a HUD pod beside it (closer, the pod
## reads as part of the title: pseudo `[_RÉŚTÁRT?_]` 3 px from ALL FOUND; pl keeps 12 clear columns);
## else the title goes GAP_XS under those
## pods (its marks included) and the panel and buttons move down with it. English: always TITLE_Y (its
## source layout).
func _place(hud: Node) -> void:
	var y := TITLE_Y
	if hud and hud.has_method("pod_rects") and UIKit.locale() != UIKit.Lang.SOURCE_LOCALE:
		var pods: Array[Rect2] = hud.pod_rects()
		var w := float(UIKit.text_w(_title.text, UIKit.FONT_BIG))
		var x := floorf((UIKit.SCREEN.x - w) / 2.0)
		var above := float(UIKit.mark_rows(_title.text, UIKit.FONT_BIG))
		var moved := true
		while moved:
			moved = false
			var ink := Rect2(x, y - above, w, above + UIKit.title_h()).grow_individual(UIKit.GAP_L, 0, UIKit.GAP_L, 0)
			for pod in pods:
				if ink.intersects(pod):
					y = pod.end.y + UIKit.GAP_XS + above
					moved = true
	if y == _title_y:
		return
	UIKit.relayout(_root)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	var shift := y - _title_y
	_title_y = y
	_title.position.y += shift
	_panel.position.y += shift
	_menu.position.y += shift


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
