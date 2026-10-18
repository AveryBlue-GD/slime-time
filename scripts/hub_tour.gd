extends Node

## SPLASHDOWN's hub tour, the first visit to the hub after the training maze (docs/tutorial/design.md
## section 5, chunk D). hub.gd adds it when Progress.hub_tour_due() and puts the slime next to the wheel.
## The player turns the room (the hub never turns itself): each time the room comes to rest, the station
## now at the back is lit and one short line about it shows in the hub's own prompt box (where ROTATE
## would be), with the use key after it. Once (from the second turn on, after HINT_DELAY seconds) the line
## says how to turn the room back. A full turn of the room ends back at the archway: THE WAY UP. WALK IN.
## (no key; walk to the archway, which opens the level select on level 1 as always) and the tour is done.
## Never blocking: the slime moves, leaps and uses stations as usual. Skippable at any time: Esc / B (the
## hub asks the tour before it goes to the title), the touch pause button (it presses `menu`) or a tap on
## the SKIP pod top right. Skipping, finishing at the archway or using any station ends it for good
## (Progress.finish_hub_tour: TUTORIAL_HUB is saved, except on a SETTINGS replay).

## Where the slime starts: beside the wheel (from hub.rotor.position), well inside USE_GAP of it.
const SPAWN_FROM_WHEEL := Vector2(0, 8)
## Seconds a station line stays before the turn-back hint takes its place (once, from the second turn on).
const HINT_DELAY := 3.0

var hub: Node2D
## The station at the back of the room now.
var back_id := ""
## Every station that has been at the back during the tour (the archway from the start).
var seen := {}
## Turns of the room taken during the tour.
var turns := 0
## The archway came back round after every station: the tour is done (finish_hub_tour called); the last
## line stays by the wheel until the room turns again or a station is used.
var done := false
## Nothing more to show (skipped, a station used, or the room turned on past the end).
var over := false
var skipped := false
## Seconds since the tour began, and when it was done (-1 = not yet).
var time := 0.0
var end_time := -1.0
var hint_shown := false
var hint_on := false
var _hint_t := 0.0
var _layer: CanvasLayer
var skip_pod: PanelContainer
var skip_label: Label
var skip_key: Label
var _prompt_key_shown := ""


func setup(the_hub: Node2D) -> void:
	hub = the_hub
	back_id = hub.back_station().id
	seen[back_id] = true
	hub.room_turned.connect(_on_room_turned)
	_build_skip()


## The SKIP pod in the top right corner (a HUD pod like the ticket pod, HUD edge from the corner): SKIP and
## the key that skips (ESC, B on a pad, none on touch: tap it).
func _build_skip() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)
	var root := Control.new()
	root.theme = UIKit.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_pod = PanelContainer.new()
	skip_pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	skip_pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_pod.custom_minimum_size.y = UIKit.pod_h()
	root.add_child(skip_pod)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	skip_pod.add_child(row)
	# i18n: the hub tour's SKIP pod (top right), max 40px, 1 line
	skip_label = UIKit.make_label(Loc.t("hub.tour.skip", "SKIP"), 8, UIKit.TEXT)
	row.add_child(skip_label)
	skip_key = UIKit.make_label("", 8, UIKit.TEXT_DIM)
	row.add_child(skip_key)
	_layout_skip()


func _skip_key_text() -> String:
	if hub._touch():
		return ""  # (tap the pod)
	return Platform.prompt_for("ui_cancel", "ESC")  # i18n: ignore (key name)


func _layout_skip() -> void:
	skip_key.text = _skip_key_text()
	skip_key.visible = skip_key.text != ""
	skip_pod.reset_size()
	var size := skip_pod.get_combined_minimum_size()
	skip_pod.size = size
	var edge := UIKit.hud_edge()
	skip_pod.position = Vector2(320 - edge.x - size.x, edge.y)


## The pod's touch area: at least UIKit.TOUCH_MIN each way round it.
func skip_rect() -> Rect2:
	var rect := Rect2(skip_pod.position, skip_pod.size)
	return rect.grow_individual(maxf(0.0, (UIKit.TOUCH_MIN - rect.size.x) / 2.0), maxf(0.0, (UIKit.TOUCH_MIN - rect.size.y) / 2.0),
		maxf(0.0, (UIKit.TOUCH_MIN - rect.size.x) / 2.0), maxf(0.0, (UIKit.TOUCH_MIN - rect.size.y) / 2.0))


func _process(delta: float) -> void:
	if over:
		return
	if not done:
		time += delta
		if _skip_key_text() != skip_key.text:
			_layout_skip()  # (keyboard / pad / touch: the key the player uses now)
		if not hint_shown and turns >= 2 and not hub.turning and hub.near.get("id", "") == "rotor":
			_hint_t += delta
			if _hint_t >= HINT_DELAY:
				hint_shown = true
				hint_on = true
				hub._show_prompt()
	if hub.near.get("id", "") == "rotor" and hub.prompt_key.text != key_text() and not hub.prompt_name.text.is_empty():
		hub._show_prompt()  # (the use key for the device in use now)


## A tap or a left click on the SKIP pod skips (seen before the touch controls, which would take a tap
## for a JUMP).
func _input(event: InputEvent) -> void:
	if over or done:
		return
	var touch: bool = event is InputEventScreenTouch and event.pressed
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not touch and not click:
		return
	if skip_rect().has_point(event.position):
		hub._sfx("click", 0.8)
		skip()
		get_viewport().set_input_as_handled()


func _on_room_turned(id: String, direction: int) -> void:
	if over:
		return
	if done:
		over = true  # (turned on past the end: the last line goes)
		return
	turns += 1
	back_id = id
	seen[id] = true
	hint_on = false
	_hint_t = 0.0
	if direction < 0:
		hint_shown = true  # (they found it themselves)
	if id == "story" and seen.size() >= hub.stations.size():
		_finish()


func _finish() -> void:
	done = true
	end_time = time
	_layer.visible = false
	Progress.finish_hub_tour()


## Esc / B from the hub: true when it skipped the tour (the hub then stays; the press is used up).
func back_pressed() -> bool:
	if over or done:
		over = true
		return false
	skip()
	return true


## Ends the tour at once (Esc / B / SKIP): saved as seen, the prompt by the wheel says ROTATE again.
func skip() -> void:
	if over:
		return
	skipped = true
	if not done:
		_finish()
	over = true
	hub._show_prompt()


## A station was used: the tour ends quietly (saved as seen).
func station_used(_id: String) -> void:
	if not done:
		_finish()
	over = true


## The station the hub lights up for the tour ("" = none): the one at the back while the room is still.
func lit_id() -> String:
	return "" if over or hub.turning else back_id


## The key after the line in the prompt: the use key (the wheel turns the room), none on the last line.
func key_text() -> String:
	return "" if done else hub._use_key()


## The tour's line in the prompt box for the station or wheel next to the slime ("" = the hub's own prompt).
func line_for(near_id: String) -> String:
	if over or near_id != "rotor":
		return ""
	if done:
		return Loc.t("hub.tour.end", "THE WAY UP. WALK IN.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
	if hint_on:
		return Loc.t("hub.tour.turn_back", "HOLD {left} TO TURN IT BACK.", {left = _left_name()})  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line; {left} = the left key (A), or LEFT on a pad / touch
	return station_line(back_id)


## The line for the station at the back of the room.
func station_line(id: String) -> String:
	match id:
		"story":
			return Loc.t("hub.tour.story", "HOME. IT TURNS. HIT THE WHEEL.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
		"maps":
			return Loc.t("hub.tour.maps", "MAPS OF EVERY LEVEL YOU SMEARED.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
		"upgrades":
			return Loc.t("hub.tour.upgrades", "COINS GO IN. STRONGER GOO COMES OUT.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
		"quit":
			return Loc.t("hub.tour.quit", "THE TRAPDOOR. FOR BEDTIME.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
		"coins":
			if not Progress.training_coin:
				return Loc.t("hub.tour.coins", "COINS STILL HIDING IN EACH LEVEL.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
			return Loc.t("hub.tour.coins_practice", "THE PRACTICE COIN WAS FAKE. SORRY.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line (the training's coin is never saved)
		"random":
			if Progress.is_randomizer_unlocked():
				return Loc.t("hub.tour.random", "A NEW MAZE EVERY TIME. NO MERCY.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
			return Loc.t("hub.tour.random_locked", "LOCKED. BEAT ALL {count} LEVELS FIRST.", {count = Levels.COUNT})  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line; {count} = 10
		"settings":
			return Loc.t("hub.tour.settings", "SOUND, KEYS, FOG. THE BORING SIGN.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
		"wheel":
			if Progress.spin_cost() == 0:
				return Loc.t("hub.tour.wheel_free", "SPIN FOR HATS. THE FIRST IS FREE.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
			return Loc.t("hub.tour.wheel", "SPIN FOR HATS. BRING TICKETS.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
		"wardrobe":
			return Loc.t("hub.tour.wardrobe", "SKINS, HATS, TRAILS. DRY UP IN STYLE.")  # i18n: hub tour line in the hub prompt box (the use key follows), max 192px, 1 line
	return ""


func _left_name() -> String:
	if hub._touch() or Platform.using_pad():
		return Loc.t("hub.tour.left", "LEFT")  # i18n: the stick / joystick held left, max 30px
	return Progress.key_name(Progress.bindings.move_left)
