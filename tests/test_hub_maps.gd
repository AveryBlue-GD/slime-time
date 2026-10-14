extends SceneTree

## The hub's ring with the MAP TABLE, at every rotation state the room can be in (9 stations; 8 on
## the web, without the trapdoor: checked in a child process with --web-ui). For each state:
## - the map table is there with its own art for its view (front / side, mirrored on the right /
##   back: rows 0-2 of maptable.png), exactly one station shows its front (the one at the back), no
##   station rests on the edge between two views;
## - no two stations' drawn pixels overlap (opaque-pixel bounding boxes of the frames they can show,
##   the flat trapdoor included), nor the wheel in the middle;
## - light pools sit under their stations; standing stations are y-sorted in `world`, the flat
##   trapdoor lies under everything;
## - every station (the map table included) can be used from each side the slime can reach
##   (8 directions round its footprint; at least 2 in every state), naming it in the prompt.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_hub_maps.gd

const WEB_FLAG := "--web-ui"

var failures := 0
var progress: Node
var hub_script: GDScript
var web := false


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.levels_cleared = Levels.COUNT
	progress.highest_unlocked = Levels.COUNT
	hub_script = load("res://scripts/hub.gd")
	web = WEB_FLAG in OS.get_cmdline_user_args()
	await _check_ring()
	if not web:
		# The web build's ring (no trapdoor), in a child process launched with --web-ui.
		var out: Array = []
		OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--headless", "-s",
			"res://tests/test_hub_maps.gd", "--", WEB_FLAG], out, true)
		var text := "\n".join(out)
		for line in text.split("\n"):
			if line.begins_with("  ok") or line.begins_with("  FAIL"):
				print(line.replace("  ok   ", "  ok   [web] ").replace("  FAIL ", "  FAIL [web] "))
		_check("RESULT: PASS" in text, "the web ring passes too")
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _check_ring() -> void:
	hub_script.return_to = ""
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await _frames(2)
	var n: int = hub.stations.size()
	var ids: Array = hub.stations.map(func(s: Dictionary) -> String: return s.id)
	_check(n == (8 if web else 9) and "maps" in ids and ("quit" in ids) != web,
		"%d stations round the room, the map table among them: %s" % [n, ", ".join(ids)])
	var maps: Dictionary = hub._station("maps")
	_check(maps.sprite.texture.resource_path.ends_with("maptable.png") and maps.size == Vector2i(30, 36) and maps.frames == 4
		and maps.sprite.texture.get_height() == 36 * 3 and maps.sprite.texture.get_width() == 30 * 4,
		"the map table has a front, side and back row of 4 lantern frames (30x36)")
	_check(maps.pool != null and maps.body != null and maps.sprite.get_parent() == hub.world, "...a light pool, a footprint, and it is y-sorted")
	var used := {}  # station id -> {view: opaque rect of the frames that view can show}
	for station: Dictionary in hub.stations:
		used[station.id] = _used_rects(station)
	var overlaps: Array[String] = []
	var bad_views: Array[String] = []
	var bad_pools: Array[String] = []
	var bad_use: Array[String] = []
	var unreached := 0
	for k in n:
		hub.turn = -k * hub.step
		hub._place_all()
		var fronts := 0
		for i in n:
			var station: Dictionary = hub.stations[i]
			var deg := rad_to_deg(wrapf(-PI / 2.0 + hub.turn + i * hub.step, -PI, PI))
			for edge in [-90.0 - hub_script.VIEW_ARC, -90.0 + hub_script.VIEW_ARC, 90.0 - hub_script.VIEW_ARC, 90.0 + hub_script.VIEW_ARC]:
				if absf(deg - edge) < 2.0:
					bad_views.append("%s on a view edge in state %d" % [station.id, k])
			if station.view == hub_script.View.FRONT:
				fronts += 1
				if not is_equal_approx(deg, -90.0):
					bad_views.append("%s front off the back in state %d" % [station.id, k])
			var row := 0 if station.flat else int(station.view)
			if station.sprite.region_rect.position.y != row * station.size.y:
				bad_views.append("%s shows the wrong row in state %d" % [station.id, k])
			if not station.flat and station.sprite.flip_h != (station.view == hub_script.View.SIDE and absf(deg) < 90.0):
				bad_views.append("%s mirrored wrongly in state %d" % [station.id, k])
			if station.pool and station.pool.position != (station.sprite.position + Vector2(0, -2)).round():
				bad_pools.append("%s in state %d" % [station.id, k])
		if fronts != 1:
			bad_views.append("%d fronts in state %d" % [fronts, k])
		var rects := []
		for station: Dictionary in hub.stations:
			rects.append(_screen_rect(station, used[station.id]))
		var rotor_rect := Rect2i(Vector2i(hub.rotor.position + hub.rotor.offset), Vector2i(26, 36))
		for i in n:
			if rects[i].intersects(rotor_rect):
				overlaps.append("%s/wheel in state %d" % [hub.stations[i].id, k])
			for j in range(i + 1, n):
				if rects[i].intersects(rects[j]):
					overlaps.append("%s/%s in state %d (%s)" % [hub.stations[i].id, hub.stations[j].id, k, rects[i].intersection(rects[j]).size])
		# Use from every side the slime can stand on.
		for station: Dictionary in hub.stations:
			var at: Vector2 = station.sprite.position + (Vector2.ZERO if station.flat else Vector2(0, -2))
			var radius: float = hub._footprint(station)
			var tested := 0
			for a in 8:  # the four sides and the four diagonals
				var dir := Vector2.from_angle(a * PI / 4.0)
				var edge := 1.0 / sqrt(pow(dir.x / radius, 2.0) + pow(dir.y / (radius * 0.5), 2.0))
				var spot := at + dir * (edge + Slime.RADIUS + 3.0)
				if not hub._on_floor(spot) or _blocked(hub, spot, station):
					unreached += 1
					continue
				tested += 1
				hub.slime.position = spot
				hub.near = {}
				hub._update_near()
				if hub.near.get("id", "") != station.id or hub.prompt_name.text != station.name:
					bad_use.append("%s from %s in state %d (got %s)" % [station.id, dir, k, hub.near.get("id", "-")])
			if tested < 2:
				bad_use.append("%s reachable from only %d side(s) in state %d" % [station.id, tested, k])
	_check(bad_views.is_empty(), "in all %d rotation states each station shows the right view, one front at the back: %s" % [n, ", ".join(bad_views)])
	_check(overlaps.is_empty(), "...no two stations (or a station and the wheel) overlap: %s" % ", ".join(overlaps))
	_check(bad_pools.is_empty(), "...light pools sit under their stations: %s" % ", ".join(bad_pools))
	_check(bad_use.is_empty(), "...every station is usable from every reachable side (%d side checks off the floor or behind another station skipped): %s"
		% [unreached, ", ".join(bad_use)])
	var flat_ok := true
	for station: Dictionary in hub.stations:
		flat_ok = flat_ok and (station.sprite.get_parent() != hub.world if station.flat else (station.sprite.get_parent() == hub.world and station.sprite.z_index == 0))
	_check(flat_ok and hub.world.y_sort_enabled and hub.slime.get_parent() == hub.world and hub.rotor.get_parent() == hub.world,
		"standing stations, the wheel and the slime are y-sorted together; the flat trapdoor lies under them")
	_check(hub.rotor.position == hub_script.CENTER + Vector2(0, 6) and is_equal_approx((hub.room.material as ShaderMaterial).get_shader_parameter("turn"), hub.turn),
		"the wheel stays in the middle and the floor shader follows the turn")
	# The map table turns to the back and faces you when you come back from it.
	hub.free()
	hub_script.return_to = "maps"
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await _frames(3)
	_check(hub._station("maps").view == hub_script.View.FRONT and hub.near.get("id", "") == "maps" and hub.prompt_name.text == "MAP TABLE",
		"coming back from the map table turns the room to face it, the slime in front of it")
	hub.free()
	hub_script.return_to = ""


## True when the slime at `spot` would stand in another station's footprint, or be nearer to one.
func _blocked(hub: Node2D, spot: Vector2, own: Dictionary) -> bool:
	var keep: Vector2 = hub.slime.position
	hub.slime.position = spot
	var own_gap: float = hub._gap_to(own.sprite.position + (Vector2.ZERO if own.flat else Vector2(0, -2)), hub._footprint(own))
	var blocked := false
	for other: Dictionary in hub.stations:
		if other != own and hub._gap_to(other.sprite.position + (Vector2.ZERO if other.flat else Vector2(0, -2)), hub._footprint(other)) <= own_gap:
			blocked = true
	hub.slime.position = keep
	return blocked


## The opaque-pixel rect (in the frame) of every frame each view of a station can show.
func _used_rects(station: Dictionary) -> Array:
	var image: Image = station.sprite.texture.get_image()
	var rows := []
	for row in (1 if station.flat else 3):
		var used := Rect2i()
		for f in station.frames:
			var r := image.get_region(Rect2i(f * station.size.x, row * station.size.y, station.size.x, station.size.y)).get_used_rect()
			if r.size == Vector2i.ZERO:
				continue
			used = r if used.size == Vector2i.ZERO else used.merge(r)
		rows.append(used)
	return rows


func _screen_rect(station: Dictionary, rows: Array) -> Rect2i:
	var used: Rect2i = rows[0 if station.flat else int(station.view)]
	if station.sprite.flip_h:
		used.position.x = station.size.x - used.end.x
	return Rect2i(Vector2i(station.sprite.position + station.sprite.offset) + used.position, used.size)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
