extends Node

## The MAP TABLE screen for screenshots: `-- --story-complete [--map=N] [--map-hard] [--partial=N]`
## opens the select (with --map=N, level N's map view on top; --map-hard shows hard mode's maps).
## --partial=N replaces level N's survey with a made-up unfinished one (no clear: the faint LAST TRY
## route, only the tiles beside a walk into the maze seen, the goal unseen), to show how a map fills in.
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_maps.tscn --story-complete --map=10


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--partial="):
			var level := arg.trim_prefix("--partial=").to_int()
			Progress.maps[Progress.survey_key(level, "--map-hard" in args)] = _partial(Levels.story_maze(level, "--map-hard" in args))
	var screen: Control = load("res://scenes/maps.tscn").instantiate()
	add_child(screen)
	if "--map-hard" in args:
		screen.hard_box.button_pressed = true
	for arg in args:
		if arg.begins_with("--map="):
			screen.open_view.call_deferred(arg.trim_prefix("--map=").to_int())


## A walk from the start halfway along the route to the goal and then off into side branches, with
## the tiles next to every cell walked seen (as the trail and its light would show them).
func _partial(maze: Dictionary) -> Dictionary:
	var survey := Survey.blank(maze.size, maze.start)
	var path := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	var walk: Array[Vector2i] = path.slice(0, path.size() / 2)
	var cell: Vector2i = walk[-1]
	for i in 12:  # wander on through unvisited neighbours
		var next := MazeGenerator.open_neighbors(maze, cell).filter(func(c: Vector2i) -> bool: return not c in walk and not c in path)
		if next.is_empty():
			break
		cell = next[0]
		walk.append(cell)
	var tiles := PackedByteArray()
	tiles.resize(maze.size.x * maze.size.y)
	for c in walk:
		var t := c * 2 + Vector2i.ONE
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				tiles[(t.y + dy) * maze.size.x + t.x + dx] = 1
	Survey.merge_seen(survey, tiles)
	survey.moves = Survey.moves_along(walk)
	return survey
