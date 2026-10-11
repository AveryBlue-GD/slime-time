extends SceneTree

## Coins and upgrades: every story level hides its coins at dead ends (the same ones every
## time), together exactly enough to max the three regular upgrades; a coin is collected once,
## is saved right away and never comes back; upgrades are bought and refunded with coins and
## change the slime (more slime, speed, a wider light); randomizer mazes have no coins; wall
## power is dev-only, and with it a strong splat breaks a wall open. Uses a throwaway save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_coins.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.coins_found = {}
	progress.upgrades = {}
	progress.dev_tools = false
	progress.levels_cleared = 10

	# --- The coin budget
	var total := 0
	for n in Levels.COINS:
		total += n
	_check(total == Upgrades.full_tree_cost() and total == 165,
		"the story hides %d coins: exactly enough to max all three upgrades" % total)
	var all_fit := true
	var at_dead_ends := true
	for level in range(1, Levels.COUNT + 1):
		var game := await _spawn({level = level})
		all_fit = all_fit and game.coins.size() == Levels.COINS[level - 1]
		for coin: Coin in game.coins:
			at_dead_ends = at_dead_ends and MazeGenerator.open_neighbors(game.maze, coin.cell).size() == 1
		game.free()
	_check(all_fit, "every level puts out its full set of coins")
	_check(at_dead_ends, "coins only sit at dead ends")

	# --- Collecting
	var game := await _spawn({level = 2})
	var first: Coin = game.coins[0]
	var cell := first.cell
	game.slime.position = first.position
	await physics_frame
	await physics_frame
	_check(progress.has_coin(2, cell) and not first in game.coins, "touching a coin collects it")
	_check(game.hud.coin_label.text == "1" and game.hud.coin_found_label.text == "1/%d" % Levels.COINS[1],
		"the HUD counts it (%s, %s)" % [game.hud.coin_label.text, game.hud.coin_found_label.text])
	game.free()
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.has_coin(2, cell), "the coin is saved the moment it's grabbed")
	reloaded.free()
	game = await _spawn({level = 2})
	var cells: Array = game.coins.map(func(c: Coin) -> Vector2i: return c.cell)
	_check(not cell in cells and game.coins.size() == Levels.COINS[1] - 1, "a collected coin never comes back")
	game.free()
	game = await _spawn({random_seed = 99})
	_check(game.coins.is_empty() and not game.hud.coin_found_label.visible, "randomizer mazes have no coins")
	game.free()

	# --- Buying and refunding upgrades
	for level in range(1, Levels.COUNT + 1):  # pretend every coin has been found
		progress.coins_found[level] = []
		for i in Levels.COINS[level - 1]:
			progress.coins_found[level].append("coin%d" % i)
	_check(progress.coins() == 165, "all coins found: 165 to spend")
	for i in Upgrades.MAX_LEVEL:
		progress.buy_upgrade("slime")
		progress.buy_upgrade("speed")
	_check(progress.upgrade_level("slime") == 10 and progress.coins() == 165 - 110, "maxing two upgrades costs 110")
	_check(not progress.buy_upgrade("slime"), "a maxed upgrade can't go higher")
	progress.refund_upgrade("speed")
	_check(progress.upgrade_level("speed") == 9 and progress.coins() == 65, "coins can be taken back out (refund 10)")
	for i in Upgrades.MAX_LEVEL:
		progress.buy_upgrade("speed")
		progress.buy_upgrade("brightness")
	_check(progress.coins() == 0 and progress.upgrade_level("brightness") == 10, "every coin found maxes all three upgrades exactly")

	# --- Upgrade effects
	game = await _spawn({level = 1})
	var plain_speed := 72.0
	_check(absf(game.slime.max_speed - plain_speed * 1.5) < 0.01, "speed 10: the slime glides 50% faster")
	_check(game.light_reach == 25.0, "brightness 10: a wider light")
	var cost: float = game.slime_cost_per_tile
	game.free()
	progress.upgrades = {}
	game = await _spawn({level = 1})
	_check(absf(game.slime_cost_per_tile / cost - 2.0) < 0.01, "more slime 10: twice as far on a full meter")
	game.free()

	# --- Dev-only wall power
	progress.upgrades = {"power": 10}
	_check(progress.upgrade_level("power") == 0, "wall power does nothing outside dev mode")
	progress.dev_tools = true
	game = await _spawn({level = 1})
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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
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


func _spawn(settings: Dictionary) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	for key: String in settings:
		game.set(key, settings[key])
	root.add_child(game)
	await physics_frame
	return game


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
