class_name AbilityCoach
extends Node

## The ability tutorial (owner, 2026-10-22): one short line at a time on the HUD's training line pod, for each
## ability the run has that the player hasn't been shown yet (BITS in Progress.tutorial_seen; the demo's FULL GAME
## PREVIEW shows every one, its bits rolled back with the rest): the key, the name and what it does. A line moves on
## when that ability is used (an aimed one first says how to fire once its aim is up), or by itself after LINE_TIME
## (so it never holds anyone up); a step shown is marked seen either way. Built by game.gd next to the
## AbilityRunner; it waits while the preview's card is up and stops when the run ends.

## Each ability's Progress.tutorial_seen bit: its coach line was shown (1-8 are the tutorial's own bits).
const BITS := {rifle = 16, splat = 32, kaze = 64, sense = 128}
## Seconds before the first line (the area banner goes first), between lines, and a line's longest hold.
const START_DELAY := 1.6
const GAP := 0.6
const LINE_TIME := 12.0
## How long the closing line stays.
const DONE_TIME := 3.0

var game: Node
var runner: AbilityRunner
## The abilities still to show, in Abilities order.
var steps: Array[String] = []
var current := ""
var _charges_at := 0
var _wait := START_DELAY
var _left := 0.0
var _aim_shown := false
var _done_left := -1.0


## The coach for `owner_game`'s run (added as its child), or null when there is nothing to show.
static func create(owner_game: Node) -> AbilityCoach:
	var runner_node: AbilityRunner = owner_game.get("abilities")
	var progress: Node = owner_game.progress
	if runner_node == null or progress == null:
		return null
	var all: bool = owner_game.get("preview") == true
	var todo: Array[String] = []
	for id in Abilities.ids():
		if runner_node.levels.has(id) and (all or not progress.has_seen_tutorial(bit(id))):
			todo.append(id)
	if todo.is_empty():
		return null
	var coach := AbilityCoach.new()
	coach.game = owner_game
	coach.runner = runner_node
	coach.steps = todo
	owner_game.hud.ensure_training_line()
	owner_game.add_child(coach)
	return coach


## The tutorial_seen bit of ability `id` (BITS).
static func bit(id: String) -> int:
	return int(BITS.get(id, 0))


## The key (or pad button) of input action `action`, "" on touch (the ability buttons are on screen).
static func key_text(action: String) -> String:
	if UIKit.touch_active() and not Platform.using_pad():
		return ""
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


## The coach line for ability `id`: its key, its name and what it does.
static func line(id: String) -> String:
	var key := key_text(Abilities.action(id))
	if key == "":
		# i18n: ability tutorial line (touch: its button is on screen), max 192px, 1 line; {name} = ability name, {what} = coach.*
		return Loc.t("coach.line_touch", "{name}: {what}", {name = Abilities.display_name(id), what = what(id)})
	# i18n: ability tutorial line, max 192px, 1 line; {key} = its key (1, 2, 3, M, a pad button), {name} = ability name, {what} = coach.*
	return Loc.t("coach.line", "{key} {name}: {what}", {key = key, name = Abilities.display_name(id), what = what(id)})


## The line while an aimed ability's aim is up: how to fire it.
static func aim_line() -> String:
	# i18n: ability tutorial line (aim mode is up), max 192px, 1 line; {key} = the leap key (SPACE, A)
	return Loc.t("coach.aim", "AIM, THEN {key} TO FIRE", {key = key_text("jump")})


## The closing line.
static func done_line() -> String:
	# i18n: ability tutorial's last line, max 192px, 1 line
	return Loc.t("coach.done", "THAT'S EVERY ABILITY, GOOD LUCK")


func _physics_process(delta: float) -> void:
	if game.finished:
		_stop()
		return
	if game.get("preview_card_up") == true:
		return
	game.hud.training_slime_rect = game._slime_screen_rect()
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
	_left -= delta
	var used := int(runner.charges.get(current, 0)) < _charges_at
	if used or _left <= 0.0:
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
		if game.get("preview") == true:
			_done_left = DONE_TIME
			game.hud.show_training_line(done_line())
		else:
			_stop()
		return
	current = steps.pop_front()
	_charges_at = int(runner.charges.get(current, 0))
	_left = LINE_TIME
	_aim_shown = false
	game.hud.show_training_line(line(current))


func _finish_step() -> void:
	game.progress.mark_tutorial_seen(bit(current))
	current = ""
	_wait = GAP
	game.hud.hide_training_line()


func _stop() -> void:
	game.hud.hide_training_line()
	set_physics_process(false)
