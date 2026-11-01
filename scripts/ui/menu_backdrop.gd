class_name MenuBackdrop
extends Control

## Behind every menu: a dim maze drifting slowly back and forth under moving mist, darker toward
## the screen edges. The drift follows the engine clock, so it carries on smoothly from one menu
## screen to the next.

const MAZE_CELLS := Vector2i(30, 18)
const MAZE_SEED := 4242
## Drift speed in px per second; it ping-pongs across the part of the maze wider than the screen.
const DRIFT_SPEED := 5.0
## ENV-26: near-black, not the lifted navy of UIKit.BG, so the blacks stay black (UI-06 text contrast holds: darker is better).
const SCRIM := Color(0.039, 0.039, 0.071)
const SCRIM_ALPHA := 0.7
const DIM := Color(0.3, 0.3, 0.38)

var _maze_root: Node2D
var _travel := Vector2.ZERO
## The backdrop maze never changes (fixed seed and size): its tile cells are built once and every
## menu screen copies them in.
static var _cells: Array[PackedByteArray] = []
static var _cached_travel := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No clipping: the backdrop always fills the screen, which clips it anyway.

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
	for layer in [floor_layer, wall_layer, fillet_layer]:
		layer.collision_enabled = false  # scenery only: its walls must never block anything
	_maze_root.add_child(floor_layer)
	_maze_root.add_child(fillet_layer)
	_maze_root.add_child(wall_layer)
	var layers: Array[TileMapLayer] = [floor_layer, wall_layer, fillet_layer]
	if _cells.is_empty():
		var maze := MazeGenerator.generate(MAZE_CELLS, MAZE_SEED, 0.3)
		MazeTiles.fill(floor_layer, wall_layer, maze, MAZE_SEED, 6, fillet_layer)
		_cached_travel = Vector2(maze.size * MazeTiles.TILE) - Vector2(320, 180)
		for layer in layers:
			_cells.append(layer.tile_map_data)
	else:
		var tile_set := MazeTiles.make_tile_set()
		for i in layers.size():
			layers[i].tile_set = tile_set
			layers[i].tile_map_data = _cells[i]
	_travel = _cached_travel

	# UI-06: a scrim over the maze so hint text on the backdrop reads (the maze stays as texture).
	var scrim := ColorRect.new()
	scrim.color = Color(SCRIM, SCRIM_ALPHA)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

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
