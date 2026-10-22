class_name TicketPickup
extends Sprite2D

## A ticket voucher waiting in a randomizer maze (Economy.RANDOM_TICKETS of them, in seeded dead ends:
## cells_for): the gold ticket icon with a soft glow, bobbing a pixel up and down. Like a story coin it
## sits under the fog, so it only shows once that spot is lit (the slime's light or an ability). The
## game collects it when the slime touches it (Economy.RANDOM_TICKET_PAY tickets).

## Touching distance between the slime's center and the ticket's (as a coin's).
const REACH := 10.0
const GLOW := Color(1.0, 0.82, 0.36)
const BOB_SPEED := 3.0
## Pickups keep at least this many cells (Manhattan) from each other and from the start.
const SPACING := 5

## The maze cell it sits in (its id for the maze's taken pickups and the map).
var cell := Vector2i.ZERO
## Reduce Motion: no bobbing.
var still := false
var _time := 0.0
var _home := Vector2.ZERO


## Up to `count` cells for a maze's pickups: its dead ends (never the start or the goal) in a seeded
## shuffle, each kept SPACING cells from the start and the ones already picked. Same seed, same cells.
static func cells_for(maze: Dictionary, maze_seed: int, count: int) -> Array[Vector2i]:
	var depths := MazeGenerator.dead_end_depths(maze)
	var ends: Array[Vector2i] = []
	for y in maze.cells.y:
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			if depths.has(cell) and cell != maze.goal and cell != maze.start:
				ends.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed * 31 + 11
	for i in range(ends.size() - 1, 0, -1):  # a seeded shuffle
		var j := rng.randi_range(0, i)
		var swap := ends[i]
		ends[i] = ends[j]
		ends[j] = swap
	var picked: Array[Vector2i] = []
	for cell in ends:
		if picked.size() >= count:
			break
		var near := _steps(cell, maze.start) < SPACING
		for other in picked:
			near = near or _steps(cell, other) < SPACING
		if not near:
			picked.append(cell)
	return picked


static func _steps(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func setup(at_cell: Vector2i, at: Vector2) -> void:
	cell = at_cell
	texture = preload("res://assets/ui/icon_ticket.png")
	position = at
	_home = at
	_time = float(at_cell.x * 7 + at_cell.y * 3)  # (bobs out of step with the others, the same each run)
	var glow := Fx.make_light(22, Color(GLOW, 0.3))
	glow.z_index = -1
	add_child(glow)


## Collected: it pops into a few gold sparks and goes.
func collect(parent: Node) -> void:
	Fx.burst(parent, position, GLOW.lightened(0.25), 12, 40.0)
	queue_free()


func _process(delta: float) -> void:
	if still:
		return
	_time += delta * BOB_SPEED
	position = _home + Vector2(0, roundf(sin(_time)))
