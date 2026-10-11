class_name MenuBackdrop
extends Control

## Behind every menu: a dim maze drifting slowly back and forth under moving mist, darker toward
## the screen edges. The drift follows the engine clock, so it carries on smoothly from one menu
## screen to the next.

const MAZE_CELLS := Vector2i(30, 18)
const MAZE_SEED := 4242
## Drift speed in px per second; it ping-pongs across the part of the maze wider than the screen.
const DRIFT_SPEED := 5.0
const DIM := Color(0.3, 0.3, 0.38)

var _maze_root: Node2D
var _travel := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_maze_root = Node2D.new()
	_maze_root.modulate = DIM
	add_child(_maze_root)
	var floor_layer := TileMapLayer.new()
	var wall_layer := TileMapLayer.new()
	var fillet_layer := TileMapLayer.new()
	_maze_root.add_child(floor_layer)
	_maze_root.add_child(fillet_layer)
	_maze_root.add_child(wall_layer)
	var maze := MazeGenerator.generate(MAZE_CELLS, MAZE_SEED, 0.3)
	MazeTiles.fill(floor_layer, wall_layer, maze, MAZE_SEED, 6, fillet_layer)
	_travel = Vector2(maze.size * MazeTiles.TILE) - Vector2(320, 180)

	var mist := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/atmosphere.gdshader")
	mist.material = material
	mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mist)
	_drift()


func _process(_delta: float) -> void:
	_drift()


## Moves the maze along a slow diagonal ping-pong path.
func _drift() -> void:
	var t := Time.get_ticks_msec() / 1000.0 * DRIFT_SPEED
	var x := pingpong(t, _travel.x)
	var y := pingpong(t * 0.6, _travel.y)
	_maze_root.position = -Vector2(x, y).round()
