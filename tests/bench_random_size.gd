extends SceneTree

## Randomizer maze size benchmark (not a test suite): over N seeds (the golden test's seed spread)
## at MORE SLIME 0 / 4 / 7, prints the area distribution (min / p10 / median / p90 / max, mean),
## the share under the size floor (Levels.random_floor_cells: 18x10 scaled by sqrt(slime factor) per side), the build time
## (mean / p99 / worst) and, by usage band, the average area.
##   ./tools/godot.sh --path . --headless -s res://tests/bench_random_size.gd [-- --seeds=2000]

func _initialize() -> void:
	await process_frame
	root.get_node("Progress").saving_enabled = false
	var seeds := 2000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.trim_prefix("--seeds=").to_int()
	for level in [0, 4, 7]:
		var floor_cells := Levels.random_floor_cells(level)
		var floor_area := floor_cells.x * floor_cells.y
		var areas: Array[int] = []
		var times: Array[float] = []
		var below := 0
		var band_area := [0, 0, 0]
		var band_n := [0, 0, 0]
		var short := 0
		for i in seeds:
			var s := 1 + i if i < 500 else 1 + (i * 1103515245 + 12345) % 2000000000
			var t := Time.get_ticks_usec()
			var cfg := Levels.random_config(s, false, level)
			var maze := MazeGenerator.generate_random(cfg)
			times.append((Time.get_ticks_usec() - t) / 1000.0)
			var area: int = maze.cells.x * maze.cells.y
			areas.append(area)
			if area < floor_area:
				below += 1
			if maze.goal_steps < cfg.route:
				short += 1
			var band := 0 if cfg.usage < 0.3 else (1 if cfg.usage < 0.7 else 2)
			band_area[band] += area
			band_n[band] += 1
		areas.sort()
		times.sort()
		var total := 0
		for a in areas:
			total += a
		print("MORE SLIME %d (floor %dx%d = %d): area min %d p10 %d median %d p90 %d max %d mean %d; below floor %d of %d (%.1f%%); short routes %d" % [
			level, floor_cells.x, floor_cells.y, floor_area, areas[0], areas[seeds / 10], areas[seeds / 2], areas[seeds * 9 / 10], areas[-1],
			total / seeds, below, seeds, below * 100.0 / seeds, short])
		print("    mean area by u: <0.30 %d, 0.30-0.70 %d, >=0.70 %d;  build mean %.2f ms, p99 %.1f ms, worst %.1f ms" % [
			band_area[0] / maxi(band_n[0], 1), band_area[1] / maxi(band_n[1], 1), band_area[2] / maxi(band_n[2], 1),
			_mean(times), times[int(seeds * 0.99)], times[-1]])
	quit(0)


static func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1)
