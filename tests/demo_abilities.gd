extends Node

## Screenshot scenarios for ABILITIES v1, picked with `--shot=`:
##   coins     the cauldron's COINS tab (no explanation lines)
##   tickets   the cauldron's TICKETS tab (the abilities), `confirm` with the BUY confirm open
##   level     a story level with the abilities owned (`--abilities=r,s,k`); `--use=rifle|splat|kaze`
##             fires one at frame USE_FRAME from the start (SLIMAKAZE along the longest open line, RIFLE /
##             SPLAT across the nearest walls, since they pass over them) (before/after
##             shots: same flags, with and without --use). The HUD strip shows top left; `--touch`
##             shows the touch buttons.
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_abilities.tscn --story-complete --tickets=60 --shot=tickets --abilities=2,1,0
## ./tools/screenshot.sh --frames 75 --scene res://tests/demo_abilities.tscn --level 4 --skin=ocean --abilities=1,1,1 --shot=level --use=rifle

const USE_FRAME := 30

var shot := ""
var use := ""
var game: Node2D
var _frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--use="):
			use = arg.trim_prefix("--use=")
	Progress.tickets_lifetime = maxi(Progress.tickets_lifetime, maxi(Progress.tickets, 1))
	Progress.tutorial_seen = 3
	match shot:
		"coins":
			load("res://scripts/ui/upgrades_screen.gd").set("open_tab", "coins")
			add_child(load("res://scenes/upgrades.tscn").instantiate())
		"tickets", "confirm":
			load("res://scripts/ui/upgrades_screen.gd").set("open_tab", "abilities")
			var cauldron: Control = load("res://scenes/upgrades.tscn").instantiate()
			add_child(cauldron)
			if shot == "confirm":
				cauldron.ability_rows.splat.plus.pressed.emit.call_deferred()
		_:
			game = preload("res://scenes/main.tscn").instantiate()
			get_tree().root.add_child.call_deferred(game)
			_start.call_deferred()


func _start() -> void:
	get_tree().current_scene = game


func _physics_process(_delta: float) -> void:
	_frame += 1
	if game == null or use == "" or _frame != USE_FRAME or game.abilities == null:
		return
	var start := Vector2i((game.slime.position / 16.0).floor())
	var best := Vector2i.RIGHT
	var best_score := -1
	for d: Vector2i in MazeGenerator.DIRS:
		# SLIMAKAZE: the longest open line (the dash stops at a wall); RIFLE / SPLAT: the line that
		# crosses walls the soonest while staying inside the maze longest (they pass over walls).
		var score := Abilities.line_tiles(game.maze, start, d).size() * 100
		if use != "kaze":
			var reach := Abilities.rifle_tiles(game.maze, start, d, 14).size()
			score = reach * 10 + (50 - Abilities.line_tiles(game.maze, start, d).size()) if reach > 4 else 0
		if score > best_score:
			best = d
			best_score = score
	game.slime.facing = Vector2(best)
	game.abilities.use(use)
