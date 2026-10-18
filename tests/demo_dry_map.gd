extends Node

## Screenshot scenario: drying up in level 1 (the choice row with MAP); with --map, MAP is pressed and the
## MAP TABLE opens on level 1. Frames: ~100 (row), ~260 (table).
## ./tools/godot.sh --path . --write-movie /tmp/x/f.png --fixed-fps 60 --quit-after 260 res://tests/demo_dry_map.tscn -- --skin=lime --map

var game: Node2D
var frame := 0


func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 1
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		get_tree().current_scene = game
	elif frame == 30:
		game.slime_remaining = 0.1
		game.slime.position.x += 4.0
	elif frame == 150 and OS.get_cmdline_user_args().has("--map"):
		game.hud.choice_buttons[2].pressed.emit()
