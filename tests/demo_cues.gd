extends Node

## Screenshot scenario: level 1's wordless teaching. Frame 30 shows the input glyph; with
## `--beacon` the slime has idled (and dried up once), so the chalice beacon shows too.
## ./tools/screenshot.sh --frames 120 --scene res://tests/demo_cues.tscn [--beacon]

var game: Node2D
var frame := 0


func _ready() -> void:
	var progress := get_node("/root/Progress")
	progress.saving_enabled = false
	progress.tutorial_seen = 0
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 1
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		get_tree().current_scene = game
	elif frame == 20 and "--beacon" in OS.get_cmdline_user_args():
		get_node("/root/Progress").dry_ups[1] = 1
