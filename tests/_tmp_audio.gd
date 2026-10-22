extends SceneTree
func _initialize():
	await process_frame
	change_scene_to_file("res://scenes/hub.tscn")
	var peaks := {}
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var last := t0
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
		for i in AudioServer.bus_count:
			var n := AudioServer.get_bus_name(i)
			peaks[n] = maxf(peaks.get(n, -200.0), AudioServer.get_bus_peak_volume_left_db(i, 0))
	var m = root.get_node("Music")
	print("AUDIO fps %.1f worst frame %d ms, music %s playing %s vol %.1f, peaks %s, driver %s" % [frames / 6.0, worst, m.current, m._player.playing, m._player.volume_db, peaks, AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?"])
	quit()
