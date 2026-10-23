class_name AbilityCoach
extends Node

## The ability tutorial (owner, 2026-10-22): one short line at a time on the HUD's training line pod, for each
## ability the run has that the player hasn't been shown yet (BITS in Progress.tutorial_seen; the demo's FULL GAME
## PREVIEW shows every one on its first run: Progress.STORY_DEMO_PREVIEW_COACHED): the key (on touch: TAP, and that
## ability's button blinks gold), the name and what it does. While a line shows the slime is held (Slime.hold: the
## direction keys only turn it, to aim; no clock, no drain) until that ability is used (an aimed one first says how to
## fire once its aim is up). Only the prompted ability works meanwhile (AbilityRunner.locked, owner 2026-10-23: the
## others don't fire and show dimmed, also between lines); all of them once it ends. SKIP (a pod under the top right
## pods: the use key F / pad X, or a tap or click) ends the whole tutorial. A line used or skipped is marked seen. Built by game.gd next to the AbilityRunner; it waits while
## the preview's card is up and stops when the run ends.

## Each ability's Progress.tutorial_seen bit: its coach line was shown (1-8 are the tutorial's own bits).
const BITS := {rifle = 16, splat = 32, kaze = 64, sense = 128}
## Seconds before the first line (the area banner goes first) and between lines.
const START_DELAY := 1.6
const GAP := 0.6
## How long the closing line stays (the preview only).
const DONE_TIME := 3.0

var game: Node
var runner: AbilityRunner
## The abilities still to show, in Abilities order.
var steps: Array[String] = []
var current := ""
var skipped := false
var _charges_at := 0
var _wait := START_DELAY
var _aim_shown := false
var _done_left := -1.0
var _layer: CanvasLayer
var skip_pod: PanelContainer
var skip_key: Label


## The coach for `owner_game`'s run (added as its child), or null when there is nothing to show.
static func create(owner_game: Node) -> AbilityCoach:
	var runner_node: AbilityRunner = owner_game.get("abilities")
	var progress: Node = owner_game.progress
	if runner_node == null or progress == null:
		return null
	var all: bool = owner_game.get("preview") == true
	if all and progress.has_seen_story(progress.STORY_DEMO_PREVIEW_COACHED):
		return null  # (a later preview run: just the maze)
	var todo: Array[String] = []
	for id in Abilities.ids():
		if runner_node.levels.has(id) and int(runner_node.charges.get(id, 0)) > 0 and (all or not progress.has_seen_tutorial(bit(id))):
			todo.append(id)
	if todo.is_empty():
		return null
	var coach := AbilityCoach.new()
	coach.game = owner_game
	coach.runner = runner_node
	coach.steps = todo
	owner_game.hud.ensure_training_line()
	owner_game.add_child(coach)
	runner_node.set_locked("")  # (none works until its line comes up)
	return coach


## The tutorial_seen bit of ability `id` (BITS).
static func bit(id: String) -> int:
	return int(BITS.get(id, 0))


## True when the touch controls are what the player uses (the lines say TAP, the button blinks).
static func on_touch() -> bool:
	return UIKit.touch_active() and not Platform.using_pad()


## The key (or pad button) of input action `action`.
static func key_text(action: String) -> String:
	var progress: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Progress")
	var key: String = progress.key_name(progress.bindings.get(action, 0)) if progress else ""
	return Platform.prompt_for(action, key)


## What ability `id` does, in a few words (the coach line's end).
static func what(id: String) -> String:
	# i18n: ability tutorial line's end (what the ability does), max 100px, 1 line
	match id:
		"rifle":
			return Loc.t("coach.rifle", "SHOOTS PAST WALLS")
		"splat":
			return Loc.t("coach.splat", "LOBS GOO OVER WALLS")
		"kaze":
			return Loc.t("coach.kaze", "DASHES INTO A WALL")
		"sense":
			return Loc.t("coach.sense", "PEEKS AT THE MAP")
	return Abilities.tag(id)


## The coach line for ability `id`: its key (TAP on touch), its name and what it does.
static func line(id: String) -> String:
	if on_touch() and id in AbilityRunner.AIMED:
		# i18n: ability tutorial line (touch, an aimed ability: hold its button, drag to aim, let go to fire), max 192px, 1 line; {name} = ability name
		return Loc.t("coach.line_touch_aim", "HOLD {name}, AIM, RELEASE", {name = Abilities.display_name(id)})
	if on_touch():
		# i18n: ability tutorial line (touch: its button blinks), max 192px, 1 line; {name} = ability name, {what} = coach.*
		return Loc.t("coach.line_touch", "TAP {name}: {what}", {name = Abilities.display_name(id), what = what(id)})
	# i18n: ability tutorial line, max 192px, 1 line; {key} = its key (1, 2, 3, M, a pad button), {name} = ability name, {what} = coach.*
	return Loc.t("coach.line", "{key} {name}: {what}", {key = key_text(Abilities.action(id)), name = Abilities.display_name(id), what = what(id)})


## The line while an aimed ability's aim is up: how to fire it.
static func aim_line() -> String:
	if on_touch():
		# i18n: ability tutorial line (touch, the aim is up while the button is held), max 192px, 1 line
		return Loc.t("coach.aim_touch", "DRAG TO AIM, LET GO TO FIRE")
	# i18n: ability tutorial line (aim mode is up), max 192px, 1 line; {key} = the leap key (SPACE, A)
	return Loc.t("coach.aim", "AIM, THEN {key} TO FIRE", {key = key_text("jump")})


## The closing line.
static func done_line() -> String:
	# i18n: ability tutorial's last line, max 192px, 1 line
	return Loc.t("coach.done", "THAT'S EVERY ABILITY, GOOD LUCK")


func _ready() -> void:
	_build_skip()


func _physics_process(delta: float) -> void:
	if game.finished:
		_stop()
		return
	if game.get("preview_card_up") == true:
		return
	game.hud.training_slime_rect = game._slime_screen_rect()
	game.hud.training_buttons_rect = game.touch_controls.ability_row_rect()
	_refresh_skip()
	if _done_left >= 0.0:
		_done_left -= delta
		if _done_left <= 0.0:
			_stop()
		return
	if current == "":
		_wait -= delta
		if _wait <= 0.0:
			_next()
		return
	game.touch_controls.step_coach(delta)
	if Input.is_action_just_pressed("interact"):
		skip()
		return
	if int(runner.charges.get(current, 0)) < _charges_at:
		_finish_step()
		return
	if runner.aiming == current and not _aim_shown:
		_aim_shown = true
		game.hud.show_training_line(aim_line())
	elif runner.aiming != current and _aim_shown:
		_aim_shown = false  # (the aim was cancelled: back to the ability's own line)
		game.hud.show_training_line(line(current))


func _next() -> void:
	if steps.is_empty():
		runner.set_locked("", true)  # (every line shown: all of them work)
		if game.get("preview") == true:
			_done_left = DONE_TIME
			game.hud.show_training_line(done_line())
		else:
			_stop()
		return
	current = steps.pop_front()
	runner.set_locked(current)
	_charges_at = int(runner.charges.get(current, 0))
	_aim_shown = false
	game.slime.hold = true
	game.touch_controls.set_coach(current)
	game.hud.show_training_line(line(current))


func _finish_step() -> void:
	game.progress.mark_tutorial_seen(bit(current))
	current = ""
	runner.set_locked("")  # (between lines: none)
	_wait = GAP
	game.slime.hold = false
	game.touch_controls.set_coach("")
	game.hud.hide_training_line()


## SKIP: the rest of the tutorial goes (every line left is marked seen) and the slime is free.
func skip() -> void:
	if current == "" and steps.is_empty():
		return
	skipped = true
	if current != "":
		steps.push_front(current)
	for id in steps:
		game.progress.mark_tutorial_seen(bit(id))
	steps.clear()
	current = ""
	_stop()


func _stop() -> void:
	runner.set_locked("", true)
	game.slime.hold = false
	game.touch_controls.set_coach("")
	game.hud.hide_training_line()
	if skip_pod:
		skip_pod.visible = false
	set_physics_process(false)


# ---------------------------------------------------------------- the SKIP pod

func _build_skip() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 3
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
	skip_pod.visible = false
	root.add_child(skip_pod)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	skip_pod.add_child(row)
	row.add_child(UIKit.make_label(Loc.t("hub.tour.skip", "SKIP"), 8, UIKit.TEXT))
	skip_key = UIKit.make_label("", 8, UIKit.TEXT_DIM)
	row.add_child(skip_key)


## Shows the pod while a line holds the slime, with the key the player uses now (none on touch: tap it).
## Its spot: under the top right pods (top left right-to-left), clear of the touch pause button.
func _refresh_skip() -> void:
	var show := current != ""
	skip_pod.visible = show
	if not show:
		return
	var key := "" if on_touch() else key_text("interact")
	if skip_key.text != key:
		skip_key.text = key
		skip_key.visible = key != ""
		skip_pod.reset_size()
	var size := skip_pod.get_combined_minimum_size()
	skip_pod.size = size
	var edge := UIKit.hud_edge()
	var y: float = edge.y + UIKit.pod_h() + UIKit.GAP_XS
	if game.touch_controls.visible:
		y = maxf(y, game.touch_controls.pause_rect.end.y + UIKit.GAP_XS)
	skip_pod.position = Vector2(edge.x if UIKit.rtl() else UIKit.SCREEN.x - edge.x - size.x, y)


## The pod's touch area: at least UIKit.TOUCH_MIN each way round it.
func skip_rect() -> Rect2:
	var rect := Rect2(skip_pod.position, skip_pod.size)
	var grow := Vector2(maxf(0.0, (UIKit.TOUCH_MIN - rect.size.x) / 2.0), maxf(0.0, (UIKit.TOUCH_MIN - rect.size.y) / 2.0))
	return rect.grow_individual(grow.x, grow.y, grow.x, grow.y)


## A tap or a left click on the SKIP pod skips (seen before the touch controls, which would take a tap for a JUMP).
func _input(event: InputEvent) -> void:
	if skip_pod == null or not skip_pod.visible:
		return
	var touch: bool = event is InputEventScreenTouch and event.pressed
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if (touch or click) and skip_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		skip()
