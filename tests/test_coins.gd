extends "res://tests/suite_base.gd"

## Coins and upgrades: every story level hides its coins at dead ends (the same ones every
## time), together exactly enough to max the three regular upgrades; a coin is collected once,
## is saved right away and never comes back; upgrades are bought and refunded with coins and
## change the slime (more slime, speed, a wider light); randomizer mazes have no coins; wall
## power is dev-only, and with it a strong splat breaks a wall open. Uses a throwaway save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_coins.gd

const MAIN := preload("res://scenes/main.tscn")
const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	Economy.coincatch_force = 0  # assumes the instant pickup (coin catch has its own suite)
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.coins_found = {}
	progress.upgrades = {}
	progress.dev_tools = false
	progress.levels_cleared = 10
	progress.hard_mode = false  # your real save may have it on; coins only exist outside hard mode

	# --- The coin budget
	var total := 0
	for n in Levels.COINS:
		total += n
	_check(total == Upgrades.full_tree_cost() and total == 165,
		"the story hides %d coins: exactly enough to max all three upgrades" % total)
	# Dev mode adds its free coins to the balance (--dev / --unlock-all launches); a normal save never sees them.
	var earned_less_spent: int = progress.coins_earned() - progress.coins_spent()
	progress.dev_coins = 40
	progress.dev_tools = true
	_check(progress.coins() == earned_less_spent + 40, "dev mode: the balance is earned - spent + the 40 dev coins (%d)" % progress.coins())
	progress.dev_tools = false
	_check(progress.coins() == earned_less_spent, "outside dev mode the dev coins do not count (%d)" % progress.coins())
	progress.dev_coins = PROGRESS_SCRIPT.DEV_COINS
	var all_fit := true
	var at_dead_ends := true
	for level in range(1, Levels.COUNT + 1):
		var game := await _spawn_game({level = level})
		all_fit = all_fit and game.coins.size() == Levels.COINS[level - 1]
		for coin: Coin in game.coins:
			at_dead_ends = at_dead_ends and MazeGenerator.open_neighbors(game.maze, coin.cell).size() == 1
		game.free()
	_check(all_fit, "every level puts out its full set of coins")
	_check(at_dead_ends, "coins only sit at dead ends")

	# --- Collecting
	var game := await _spawn_game({level = 2})
	var first: Coin = game.coins[0]
	var cell := first.cell
	game.slime.position = first.position
	await physics_frame
	await physics_frame
	_check(progress.has_coin(2, cell) and not first in game.coins, "touching a coin collects it")
	_check(game.hud.coin_label.text == "1" and game.hud.coins_left_label.text == "%d LEFT" % (Levels.COINS[1] - 1),
		"the HUD counts it: %s in hand, %s here" % [game.hud.coin_label.text, game.hud.coins_left_label.text])
	game.free()
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = test_save
	reloaded.load_progress()
	_check(reloaded.has_coin(2, cell), "the coin is saved the moment it's grabbed")
	reloaded.free()
	game = await _spawn_game({level = 2})
	var cells: Array = game.coins.map(func(c: Coin) -> Vector2i: return c.cell)
	_check(not cell in cells and game.coins.size() == Levels.COINS[1] - 1, "a collected coin never comes back")
	game.free()
	game = await _spawn_game({random_seed = 99})
	_check(game.coins.is_empty() and not game.hud._coins_left_pod.visible, "randomizer mazes have no coins")
	game.free()

	# --- Buying and refunding upgrades
	for level in range(1, Levels.COUNT + 1):  # pretend every coin has been found
		progress.coins_found[level] = []
		for i in Levels.COINS[level - 1]:
			progress.coins_found[level].append("coin%d" % i)
	_check(progress.coins() == 165, "all coins found: 165 to spend")
	for i in 10:
		progress.buy_upgrade("slime")
		progress.buy_upgrade("speed")
	_check(progress.upgrade_level("slime") == 7 and progress.upgrade_level("speed") == 4 and progress.coins() == 165 - 126,
		"maxing MORE SLIME (7 levels, 80) and SPEED (4 levels, 46) costs 126")
	_check(not progress.buy_upgrade("slime"), "a maxed upgrade can't go higher")
	progress.refund_upgrade("speed")
	_check(progress.upgrade_level("speed") == 3 and progress.coins() == 57, "coins can be taken back out (SPEED 4 refunds 18)")
	for i in 10:
		progress.buy_upgrade("speed")
		progress.buy_upgrade("brightness")
	_check(progress.coins() == 0 and progress.upgrade_level("brightness") == 3, "every coin found maxes all three upgrades exactly")

	# --- Upgrade effects
	game = await _spawn_game({level = 1})
	var plain_speed := 72.0
	_check(absf(game.slime.max_speed - plain_speed * 1.5) < 0.01, "speed 4: the slime glides 50% faster")
	_check(game.light_reach == 25.0, "brightness 3: a wider light (25 px more reach)")
	var cost: float = game.slime_cost_per_tile
	game.free()
	progress.upgrades = {}
	game = await _spawn_game({level = 1})
	_check(absf(game.slime_cost_per_tile / cost - 2.0) < 0.01, "more slime 7: twice as far on a full meter")
	game.free()

	# --- Dev-only wall power
	progress.upgrades = {"power": 4}
	_check(progress.upgrade_level("power") == 0, "wall power does nothing outside dev mode")
	progress.dev_tools = true
	game = await _spawn_game({level = 1})
	var spot := _inner_wall_spot(game)
	_check(not spot.is_empty(), "found an inner wall to splat into")
	var wall_tile: Vector2i = spot.wall
	game.slime.position = spot.from
	game.last_slime_pos = spot.from
	game.slime.facing = Vector2(spot.dir)
	await physics_frame
	game.slime.launch(100.0)
	for i in 30:
		await physics_frame
	_check(not game.is_wall_tile(wall_tile) and game.wall_layer.get_cell_source_id(wall_tile) == -1,
		"dev mode, full power: one strong splat breaks the wall open")
	game.free()
	progress.dev_tools = false
	progress.upgrades = {}
	progress.coins_found = {}

	# --- Coins glint in their own metal
	game = await _spawn_game({level = 4})
	var glow: Sprite2D = game.coins[0].get_child(0)
	_check(game.coins[0].region_rect.size == Vector2(Coin.FRAME, Coin.FRAME) and Coin.FRAME == 12, "coins are 12x12 frames")
	_check(Color(glow.modulate, 1.0).is_equal_approx(Color(Coin.GLOW[3], 1.0)), "a coin's glow is its level's metal")
	game.free()

	# --- Glimmers through the fog: with distance traveled (not time), only over hidden coins
	game = await _spawn_game({level = 4})
	game.glimmer_view_only = false
	game.glimmer_reach = 100000.0  # any coin in the level counts as near, for the test
	for i in 240:  # standing still for 4 s
		await physics_frame
	_check(get_nodes_in_group("glimmer").is_empty(), "no glimmers while standing still")
	game.glimmer_travel = 10000.0  # as if it had traveled far
	await physics_frame
	var glimmers := get_nodes_in_group("glimmer")
	_check(glimmers.size() == 1, "traveling far enough brings a glimmer")
	if glimmers.size() == 1:
		var spark: Node2D = glimmers[0]
		var on_coin: bool = game.coins.any(func(c: Coin) -> bool: return c.position.round() == spark.position)
		_check(on_coin and game.fog_alpha_at(spark.position) >= 0.99 and spark.z_index > game.fog_sprite.z_index,
			"...right over a coin still hidden in the fog, drawn over the fog")
	game.free()
	for i in Levels.COINS[3]:  # every coin of level 4 found: nothing left to glimmer
		progress.coins_found[4] = progress.coins_found.get(4, []) + ["found%d" % i]
	progress.all_coins_debug = true
	game = await _spawn_game({level = 4})
	game.glimmer_view_only = false
	game.glimmer_reach = 100000.0
	game.glimmer_travel = 10000.0
	await physics_frame
	await physics_frame
	_check(game.coins.is_empty() and get_nodes_in_group("glimmer").is_empty(), "with every coin found there are no glimmers")
	progress.all_coins_debug = false
	progress.coins_found = {}

	# --- The maze edge: a double wall, then fog carrying on
	var w: int = game.maze.size.x
	_check(game.border_layer.get_cell_source_id(Vector2i(-1, 3)) != -1 and game.border_layer.get_cell_source_id(Vector2i(w, 3)) != -1,
		"a second ring of wall runs just outside the maze")
	_check(game.fog_alpha_at(Vector2(-40, -40)) == 1.0 and game.outer_fog != null and game.outer_fog.visible,
		"past the border, fog carries on (not black)")
	_check(game.camera.limit_left < -16 and game.camera.limit_right > w * 16 + 16, "the camera can look past the double wall")
	game.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
	quit(1 if failures else 0)


## A floor cell next to a wall that's not on the maze's outer edge: {from, dir, wall}.
func _inner_wall_spot(game: Node2D) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				if (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell):
					continue
				var center := MazeGenerator.cell_center(cell, 16)
				var wall := Vector2i((center / 16.0).floor()) + dir
				if game.is_wall_tile(wall) and not game._is_edge(wall):
					return {from = center, dir = dir, wall = wall}
	return {}


