class_name Levels
extends RefCounted

## The 10 levels. Tune difficulty here.
## - cells:     maze size in cells (each cell is 2x2 open tiles + walls)
## - branching: 0 = long winding corridors, higher = more side branches and dead ends
## - target:    fraction of the slime meter a perfect glide to the chalice uses
## Seeds were picked so the path to the chalice grows steadily: 14, 17, 20 ... 44 cells.

const COUNT := 10

const DATA := [
	{cells = Vector2i(6, 4), seed = 1019, branching = 0.05, target = 0.60},
	{cells = Vector2i(7, 4), seed = 2001, branching = 0.10, target = 0.63},
	{cells = Vector2i(8, 5), seed = 3019, branching = 0.15, target = 0.66},
	{cells = Vector2i(9, 5), seed = 4002, branching = 0.20, target = 0.70},
	{cells = Vector2i(10, 6), seed = 5021, branching = 0.25, target = 0.73},
	{cells = Vector2i(11, 6), seed = 6006, branching = 0.30, target = 0.77},
	{cells = Vector2i(12, 7), seed = 7001, branching = 0.35, target = 0.80},
	{cells = Vector2i(13, 7), seed = 8015, branching = 0.40, target = 0.83},
	{cells = Vector2i(14, 8), seed = 9040, branching = 0.45, target = 0.87},
	{cells = Vector2i(15, 9), seed = 10153, branching = 0.50, target = 0.90},
]

## Wall damage weights (intact, cracked, crumbling, broken) for level 1 and level 10;
## levels in between blend from one to the other.
const DAMAGE_FIRST := [60.0, 30.0, 8.0, 2.0]
const DAMAGE_LAST := [15.0, 30.0, 30.0, 25.0]
## Wall style weights: plain, mossy, stained.
const WALL_STYLE := [70.0, 15.0, 15.0]
## Floor type weights for level 1 and level 10 (order matches FLOOR_TYPES in the art script,
## minus rubble, which is placed under broken walls).
const FLOOR_FIRST := [60.0, 10.0, 10.0, 6.0, 8.0, 2.0, 4.0]
const FLOOR_LAST := [30.0, 18.0, 12.0, 12.0, 10.0, 10.0, 8.0]


static func get_config(level: int) -> Dictionary:
	return DATA[clampi(level, 1, COUNT) - 1]


static func damage_weights(level: int) -> PackedFloat32Array:
	return _blend(DAMAGE_FIRST, DAMAGE_LAST, level)


static func floor_weights(level: int) -> PackedFloat32Array:
	return _blend(FLOOR_FIRST, FLOOR_LAST, level)


static func _blend(first: Array, last: Array, level: int) -> PackedFloat32Array:
	var t := float(clampi(level, 1, COUNT) - 1) / (COUNT - 1)
	var out := PackedFloat32Array()
	for i in first.size():
		out.append(lerpf(first[i], last[i], t))
	return out
