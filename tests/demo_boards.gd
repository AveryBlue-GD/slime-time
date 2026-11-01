extends Node

## BM-03 screenshots: the BOARDS page with some times, or (`-- --race`) a daily maze with a ghost racing the slime.
## .\tools\screenshot.ps1 -Frames 40 -Scene res://tests/demo_boards.tscn -GameArgs --skin=lime[,--race]


func _ready() -> void:
	var progress := get_node("/root/Progress")
	var today: int = progress.utc_day()
	for ms in [31420, 33900, 38050, 41200]:
		progress.post_board("daily", ms, today)
	for ms in [92500, 101300]:
		progress.post_board("weekly", ms, today)
	progress.board_best_daily_ms = 29880
	if "--race" in OS.get_cmdline_user_args():
		progress.start_daily()
		var game: Node2D = preload("res://scenes/main.tscn").instantiate()
		game.random_seed = progress.random_seed
		add_child(game)
		await get_tree().physics_frame
		var start: Vector2 = game.slime.position
		var pts: Array[int] = []
		for i in 100:
			pts.append(Boards.pack(start + Vector2(minf(i * 2.0, 22.0), 0)))
		progress._ghosts = {daily = {key = today, ms = 30000, pts = pts}}
		progress._ghosts_loaded = true
		var racer := GhostRacer.create(game)
		game.ghost = racer
	else:
		add_child(preload("res://scenes/boards.tscn").instantiate())
