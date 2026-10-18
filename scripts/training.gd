class_name Training
extends RefCounted

## SPLASHDOWN, the first-session training maze (Economy.TUTORIAL_TEST; docs/tutorial/design.md sections 3
## and 14). Hand-made, not generated: the layout below in the MazeGenerator format (cell (cx, cy) = tile
## (2cx+1, 2cy+1), 1-tile corridors), so the game's fog, trail, coins, chalice and HUD run unchanged.
## game.gd plays it in Progress.MODE_TRAINING (its `training` branch); this file holds the layout, the
## meter numbers, the beat tiles and the state that carries across a RESTART (the scene reloads).
##
## Beats (design section 3): B1 glide out of a dead-end pocket (S), B2 the 12-tile leap straight (a full
## 8-tile leap from its west end lands 4 tiles short of the wall), B3 the fork with the practice coin two
## cells up a dead end (C, a forced glimmer), B4 the low first meter dries up just after the coin, B5
## RESTART only (coin kept, full meter), B6 the long leg round to the chalice (G), B7 HUB only.

## The maze, one string per tile row: '#' wall, '.' floor, '-' floor of the leap straight (drawn as
## floor), 'S' start, 'C' the practice coin, 'G' the golden chalice. 25 x 13 tiles (12 x 6 cells).
const LAYOUT: Array[String] = [
	"#########################",
	"#################C###G..#",
	"#################.#####.#",
	"#################.#####.#",
	"#################.#####.#",
	"#####..-----------#####.#",
	"#####.###########.#####.#",
	"#####.###########.#####.#",
	"#####.###########.#####.#",
	"#S....###########.#####.#",
	"#################.#####.#",
	"#################.......#",
	"#########################",
]

## The tile seed for MazeTiles (wall / floor variants and the border's rubble; any fixed number).
const SEED := 20261018
## The meter, in tiles of gliding: full (attempt 2 on), and the first attempt's low start (the splat
## from the intro left goo all over the walls). Gliding start -> coin is about 23.4 tiles (the coin is
## grabbed from Coin.REACH px), so a glide-only first attempt picks up the coin and dries up about 4
## tiles later, back at the fork; one leap on the straight saves ~6 tiles and dries up on the south
## leg; reaching the chalice on attempt 1 needs the coin skipped and every straight leapt (experts).
const FULL_METER_TILES := 90.0
const FIRST_METER_TILES := 28.0
## The leap straight: tiles (STRAIGHT_FROM.x .. FORK.x - 1) on row STRAIGHT_FROM.y; entering it is
## the "straight" beat. The fork tile ("fork" beat, forced glimmer over the coin).
const STRAIGHT_FROM := Vector2i(5, 5)
const FORK := Vector2i(17, 5)
## Seconds the meter takes to fill up visibly at the start of attempt 2 on (design B5).
const FILL_TIME := 0.6
## Seconds between the two forced glimmers at the fork (one twinkle is easy to miss).
const GLIMMER_REPEAT := 1.2

## The run in progress, kept across the scene reloads of RESTART (game.gd retry): which attempt this is
## (1 = the low first meter) and whether the practice coin was picked up (it stays found, never saved).
## `_restart_pending` is set by game.gd right before it reloads for a RESTART; any other way into the
## maze (the intro hand-off, PLAY, the SETTINGS replay) starts a fresh run at attempt 1.
static var attempt := 1
static var coin_taken := false
static var _restart_pending := false
static var _restart_next := true


## The maze name (level pod and area banner).
static func display_name() -> String:
	# i18n: training maze name; HUD level pod (max 120px) and the 16 px area banner (max 296px), 1 line
	return Loc.t("training.name", "SPLASHDOWN")


## The joke under the name on the area banner (must not repeat level 1's splat line).
static func banner_line() -> String:
	# i18n: joke under the training maze's name, one line, max 296px. Keep it funny, not literal.
	return Loc.t("training.line", "ROCK BOTTOM. NICE LANDING.")


## The tile config game.gd feeds MazeTiles (the Dark Dungeon look, level 1's tile wear).
static func config() -> Dictionary:
	return {seed = SEED, theme = Themes.DUNGEON, tile_level = 1}


## Parses LAYOUT into a MazeGenerator maze: {size, cells, walls, start, goal, goal_steps} plus `coin`
## (the practice coin's cell).
static func build_maze() -> Dictionary:
	var size := Vector2i(LAYOUT[0].length(), LAYOUT.size())
	var walls := PackedByteArray()
	walls.resize(size.x * size.y)
	var start := Vector2i.ZERO
	var goal := Vector2i.ZERO
	var coin := Vector2i.ZERO
	for y in size.y:
		var row: String = LAYOUT[y]
		assert(row.length() == size.x, "SPLASHDOWN rows are all as wide")
		for x in size.x:
			var ch := row[x]
			walls[y * size.x + x] = 1 if ch == "#" else 0
			var cell := Vector2i(x >> 1, y >> 1)
			match ch:
				"S":
					start = cell
				"G":
					goal = cell
				"C":
					coin = cell
	var maze := {size = size, cells = (size - Vector2i.ONE) / MazeGenerator.CELL_SPAN, walls = walls,
		start = start, goal = goal, coin = coin}
	maze.goal_steps = int(MazeGenerator.distances_from(maze, start).get(goal, 0))
	return maze


## The meter's start (percent of the full meter) for attempt `n`.
static func start_percent(n: int) -> float:
	return (FIRST_METER_TILES if n <= 1 else FULL_METER_TILES) / FULL_METER_TILES * 100.0


## game.gd, right before reloading the scene for a RESTART: the next run is the next attempt
## (`next`: after a dry-up) or this attempt again (R / pause RESTART mid-run); the coin stays found.
static func mark_restart(next := true) -> void:
	_restart_pending = true
	_restart_next = next


## game.gd's _ready: begins a run and returns its attempt number. After mark_restart it is the next
## attempt (or the same one, mark_restart(false)) with the coin kept; otherwise a fresh run (attempt 1, no coin).
static func begin_run() -> int:
	if _restart_pending:
		_restart_pending = false
		if _restart_next:
			attempt += 1
	else:
		attempt = 1
		coin_taken = false
	return attempt


## True on the leap straight (the corner at its west end included, the fork excluded).
static func on_straight(tile: Vector2i) -> bool:
	return tile.y == STRAIGHT_FROM.y and tile.x >= STRAIGHT_FROM.x and tile.x < FORK.x
