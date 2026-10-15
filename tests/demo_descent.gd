extends Node

## Screenshot / clip scenarios for DESCENT runs (upgrades v2 batch 3), picked with `--shot=`:
##   portal   the hub's portal mode choice (RANDOM MAZE / DESCENT)
##   floor    a Descent floor in play (floor 3, a few boons held, the pot pod), the autopilot gliding
##   boons    the boon card after clearing a floor
##   cashout  the summary after CASH OUT
##   summary  the summary after a dry-up
##   demo     the autopilot plays a run: clears floors, picks the first boon offered, descends (a clip)
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_descent.tscn --story-complete --upgrades=4,1,1 --shot=portal
## ./tools/screenshot.sh --frames 200 --scene res://tests/demo_descent.tscn --story-complete --upgrades=4,1,1 --skin=lemon --shot=floor
## ./tools/screenshot.sh --frames 160 --scene res://tests/demo_descent.tscn --story-complete --upgrades=4,1,1 --skin=lemon --shot=boons
## ./tools/screenshot.sh --frames 200 --scene res://tests/demo_descent.tscn --story-complete --upgrades=4,1,1 --skin=lemon --shot=cashout
## ./tools/screenshot.sh --frames 260 --scene res://tests/demo_descent.tscn --story-complete --upgrades=4,1,1 --skin=lemon --shot=summary
## Clip: --write-movie with --shot=demo (Descent: docs/level-design.md section 9).

const RUN_SEED := 4242

var shot := ""
var game: Node2D
var _frame := 0
var _picked := -1


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	Progress.tutorial_seen = 3
	Progress.tickets_lifetime = maxi(Progress.tickets_lifetime, 1)
	match shot:
		"portal":
			Progress.descent_best_floor = 7
			(load("res://scripts/hub.gd") as GDScript).set("return_to", "random")  # the portal in front
			var hub: Node = load("res://scenes/hub.tscn").instantiate()
			add_child(hub)
			hub.open_portal_menu.call_deferred()
		"floor", "boons", "cashout", "summary":
			Progress.start_descent(RUN_SEED)
			var run: Dictionary = Progress.descent_run
			# Two floors cleared with boons picked, as a player would have.
			for i in 2:
				Progress.clear_descent_floor(run.meter - 22.0, 40.0)
				Progress.descend(Progress.descent_offers()[0])
			_start_game()
		"demo":
			Progress.start_descent(RUN_SEED)
			_start_game()


func _start_game() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred()


func _drive() -> void:
	get_tree().current_scene = game
	game.add_child(preload("res://tests/autopilot.gd").new())


func _physics_process(_delta: float) -> void:
	_frame += 1
	var cs := get_tree().current_scene
	if shot == "demo" and cs != null and cs != game and cs.get("descent") == true:
		game = cs  # the next floor (the scene was rebuilt): give it a pilot
		_picked = -1
		game.add_child(preload("res://tests/autopilot.gd").new())
	if game == null or not is_instance_valid(game):
		return
	match shot:
		"boons", "cashout":
			if _frame == 60 and not game.finished:
				game._on_goal_body_entered(game.slime)
			if shot == "cashout" and _frame == 140 and game.descent_card and game.descent_card.visible:
				game.cash_out()
		"summary":
			if _frame == 120 and not game.finished:
				game.slime_remaining = 0.0
		"demo":
			var card: DescentCard = game.descent_card
			if card and card.visible and card.boons_root.visible:
				if _picked < 0:
					_picked = _frame
					card._on_tile(0)
				elif _frame - _picked == 45:
					card._on_descend()
