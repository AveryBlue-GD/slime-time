extends Node

## The MAP TABLE screen for screenshots: `-- --story-complete [--map=N] [--map-hard] [--partial=N]`
## opens the select (with --map=N, level N's map view on top; --map-hard shows hard mode's maps).
## --partial=N replaces level N's survey with a made-up unfinished one (no clear: the faint LAST TRY
## route, only the tiles beside a walk into the maze seen, the goal unseen), to show how a map fills in.
## --uturn=N replaces it with a walk along level N's shortest route up to a few cells past its first
## hairpin (a U-turn into the parallel corridor next door), only the tiles beside the walk seen and
## drawn as a clear (add --uturn-try for the faint last attempt): the wall between the two legs must show.
## --themed shows the themed maps mockup (map_select.THEMED_MAPS, off in the game).
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_maps.tscn --story-complete --map=10


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--partial="):
			var level := arg.trim_prefix("--partial=").to_int()
			Progress.maps[Progress.survey_key(level, "--map-hard" in args)] = _partial(Levels.story_maze(level, "--map-hard" in args))
		if arg.begins_with("--uturn="):
			var level := arg.trim_prefix("--uturn=").to_int()
			Progress.maps[Progress.survey_key(level, "--map-hard" in args)] = uturn(Levels.story_maze(level, "--map-hard" in args), not "--uturn-try" in args)
	var screen: Control = load("res://scenes/maps.tscn").instantiate()
	screen.themed = "--themed" in args or screen.themed
	add_child(screen)
	if "--map-hard" in args:
		screen.hard_box.button_pressed = true
	for arg in args:
		if arg.begins_with("--map="):
			screen.open_view.call_deferred(arg.trim_prefix("--map=").to_int())


## A walk from the start halfway along the route to the goal and then off into side branches, with
## the tiles next to every cell walked seen (as the trail and its light would show them).
func _partial(maze: Dictionary) -> Dictionary:
	var survey := Survey.blank(maze)
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


## A walk along the shortest route to a few cells past its first hairpin (path[i + 3] next to path[i]
## across a wall), the 3x3 tiles round each walked cell seen; a clear (`clear`) or a last attempt.
static func uturn(maze: Dictionary, clear := true) -> Dictionary:
	var path := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	var end := path.size()
	for i in path.size() - 3:
		if (path[i + 3] - path[i]).abs().x + (path[i + 3] - path[i]).abs().y == 1:
			end = mini(path.size(), i + 10)
			break
	var walk: Array[Vector2i] = path.slice(0, end)
	var survey := Survey.blank(maze)
	var tiles := PackedByteArray()
	tiles.resize(maze.size.x * maze.size.y)
	for c in walk:
		var t := c * 2 + Vector2i.ONE
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				tiles[(t.y + dy) * maze.size.x + t.x + dx] = 1
	Survey.merge_seen(survey, tiles)
	survey.moves = Survey.moves_along(walk)
	survey.clear = clear
	survey.best_ms = 20000 if clear else 0
	return survey
