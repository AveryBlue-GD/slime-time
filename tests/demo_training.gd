extends Node

## Watchable / capture scenario: the SPLASHDOWN training maze played by the autopilot (gate forced on, a
## clean in-memory fresh state, nothing saved): glides out of the start pocket, charges and leaps down the
## straight (full charge, landing short of the wall), picks up the practice coin, dries up on the low first
## meter, presses RESTART, glides to the chalice on attempt 2 and stops on the HUB row. Prints
## "CAPTURE <name> <frame>" at each moment (start, straight, fork, coin, dry, attempt2, win; the direction
## lines show at start, fork, coin, dry and attempt2) for picking movie frames.
## ./tools/godot.sh --path . --write-movie /tmp/x/frame.png --fixed-fps 60 --quit-after 2400 res://tests/demo_training.tscn

const MAIN := preload("res://scenes/main.tscn")
var game: Node2D
var frame := 0
var pilot: RoutePilot
## "start", "charge", "fly", "to_coin", "attempt2", "done".
var stage := "start"
var _charge_left := 0
var _printed := {}
var _hold := -1


func _ready() -> void:
	Economy.tutorial_force = 1
	Progress.saving_enabled = false
	Progress.reset_progress()
	Progress.dev_tools = false
	Progress.prepare_training(false)
	game = MAIN.instantiate()
	get_tree().root.add_child.call_deferred(game)


func _capture(what: String, delay := 0) -> void:
	if not _printed.has(what):
		_printed[what] = true
		print("CAPTURE %s %d" % [what, frame + delay])


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 2:
		get_tree().current_scene = game
	var current := get_tree().current_scene
	if current == null or not current.has_method("training_beat") or frame < 3:
		return
	if current != game:  # RESTART reloaded the maze
		game = current
		pilot = null
		stage = "attempt2"
	if stage == "start" and pilot == null and frame > 70:
		_capture("start", -1)
		var m: Dictionary = game.maze
		_pilot(MazeGenerator.shortest_path(m, m.start, Vector2i(2, 2)))
	elif stage == "start" and pilot != null and game.slime.position.distance_to(MazeGenerator.cell_center(Vector2i(2, 2), 16)) < 3.0:
		pilot.queue_free()
		pilot = null
		Input.action_release("move_up")
		Input.action_press("move_right")
		Input.action_press("jump")
		stage = "charge"
		_charge_left = 95
	elif stage == "charge":
		_charge_left -= 1
		if _charge_left == 10:
			_capture("straight")
		if _charge_left <= 0:
			Input.action_release("jump")
			Input.action_release("move_right")
			stage = "fly"
			_charge_left = 70
	elif stage == "fly":
		_charge_left -= 1
		if _charge_left <= 0:
			var m: Dictionary = game.maze
			var from := Vector2i((game.slime.position / 32).floor())
			var route := MazeGenerator.shortest_path(m, from, m.coin)
			route.append_array(MazeGenerator.shortest_path(m, m.coin, m.goal).slice(1))
			_pilot(route)
			stage = "to_coin"
	elif stage == "to_coin":
		if game.training_line == "coin_up":
			_capture("fork", 12)  # (the direction line: GO UP AND GRAB THE COIN!)
		if Training.coin_taken:
			_capture("coin", 6)
		if game.finished and not game.hud.choice_buttons.is_empty() and game.hud.choice_buttons[0].is_visible_in_tree():
			_capture("dry", 20)
			if _hold < 0:
				_hold = 60
			_hold -= 1
			if _hold == 0:
				_hold = -1
				game.hud.choice_buttons[0].pressed.emit()
	elif stage == "attempt2":
		if game.training_line == "chalice":
			_capture("attempt2", 30)  # (the chalice line after the dry-up)
		if pilot == null and frame > 3:
			var m: Dictionary = game.maze
			_pilot(MazeGenerator.shortest_path(m, m.start, m.goal))
		if game.finished and not game.hud.choice_buttons.is_empty() and game.hud.choice_buttons[0].is_visible_in_tree():
			_capture("win", 20)
			stage = "done"


func _pilot(cells: Array[Vector2i]) -> void:
	pilot = RoutePilot.new()
	pilot.cells = cells
	game.add_child(pilot)
