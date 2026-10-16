extends Node

## Screenshot scenario: level 1's wordless teaching. Frame 30 shows the input glyph.
## ./tools/screenshot.sh --frames 120 --scene res://tests/demo_cues.tscn

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
