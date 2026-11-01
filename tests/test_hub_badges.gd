extends "res://tests/suite_base.gd"

## The hub's gold "!" badges never cover a visible station name or each other, whatever way the room is turned
## (IMP2-06 fix). Every station's news is forced on, the names held visible, and the room swept through a full turn.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_hub_badges.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.levels_cleared = Levels.COUNT
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(3)
	var safe := UIKit.safe_rect()
	var checked := 0
	var shifted := 0
	var bad := 0
	for idx in 144:  # (a full turn on the desktop, then a full turn with the touch controls showing)
		var step := idx % 72
		if hub._touch_controls != null:
			hub._touch_controls.visible = idx >= 72
		hub.turn = TAU * step / 72.0
		hub._place_all()
		for id: String in hub.badges:
			hub.badges[id].text = "!"
			hub.badges[id].visible = true
		hub.near = {}
		hub._names_t = 0.0
		await _physics_frames(3)
		for id: String in hub.badge_art:
			_check(not hub.badge_art[id].node.visible, "no badge %s while the names show" % id)
		hub._names_t = hub.NAMES_TIME
		for id: String in hub.badges:  # (a refresh may have reset the forced news)
			hub.badges[id].text = "!"
			hub.badges[id].visible = true
		await _physics_frames(30)  # (the stagger and the pop-in are over, the bob has moved)
		hub._place_hints()  # (solved afresh for this turn, as the hub does when the names show)
		var rects: Array[Rect2] = []
		var labels: Array[Rect2] = []
		for id: String in hub.name_labels:
			var label: Label = hub.name_labels[id]
			if label.visible and hub.name_layer.visible:
				labels.append(Rect2(label.position, label.size))
		# UI-24: no station name sits across another prop's sprite (the SETTINGS name on the DAILY sign, DAILY MAZE
		# over the portal), nor across a touch circle when the touch controls show
		for st: Dictionary in hub._all_props():
			var nl: Label = hub.name_labels[st.id]
			var nr := Rect2(nl.position, nl.size)
			for other: Dictionary in hub._all_props():
				if other.id == st.id:
					continue
				var op: Vector2 = other.sprite.position
				var box := Rect2(op.x - other.size.x / 2.0, op.y - other.size.y, other.size.x, other.size.y)
				_check(box.intersection(nr).get_area() <= 0.6 * nr.get_area(), "the name %s stays off the %s prop at turn step %d (%s vs %s)" % [st.id, other.id, step, nr, box])
			# every name is nearer its own prop than any other (it reads as that prop's)
			var nc := nr.get_center()
			var d_own := nc.distance_to(Vector2(st.sprite.position.x, st.sprite.position.y - st.size.y / 2.0))
			for other: Dictionary in hub._all_props():
				if other.id != st.id:
					var d_other := nc.distance_to(Vector2(other.sprite.position.x, other.sprite.position.y - other.size.y / 2.0))
					_check(d_own < d_other, "the name %s is nearer its own prop than %s at idx %d (%.1f vs %.1f)" % [st.id, other.id, idx, d_own, d_other])
			if hub._touch_controls != null and hub._touch_controls.visible:
				for circle: Rect2 in hub._touch_circles():
					if st.id == "settings" or st.id == "quit":  # (the others stay attached and may graze a circle)
						_check(not circle.intersects(nr), "the name %s stays off the touch circles at idx %d (%s)" % [st.id, idx, nr])
		for id: String in hub.badge_art:
			var node: TextureRect = hub.badge_art[id].node
			if not node.visible:
				continue
			checked += 1
			var r := Rect2(node.position, Vector2(hub.BADGE_SIZE))
			rects.append(r)
			_check(node.position == node.position.round(), "badge %s on whole pixels" % id)
			# IMP3-03: the badge stays with its station through the turn (within its head rect: the sprite's width
			# plus a badge on each side, from the head up to a badge or two above it)
			var prop: Dictionary = {}
			for candidate: Dictionary in hub._all_props():
				if candidate.id == id:
					prop = candidate
			var at: Vector2 = prop.sprite.position
			var head := Rect2(at.x - prop.size.x / 2.0 - 12.0, at.y - prop.size.y - 2.0 * hub.BADGE_SIZE.y - 8.0, prop.size.x + 24.0, 2.0 * hub.BADGE_SIZE.y + 12.0)
			head.position.y = maxf(head.position.y, safe.position.y)  # (a station at the very top: its badge sits on the safe edge)
			head.size.y = maxf(head.size.y, 2.0 * hub.BADGE_SIZE.y + 12.0)
			if not head.encloses(r):
				bad += 1
				_check(false, "badge %s follows its station at turn %d (%s outside head rect %s)" % [id, step, r, head])
			_check(safe.encloses(r), "badge %s inside the safe rect (%s)" % [id, r])
			for l in labels:
				if r.intersects(l):
					bad += 1
					_check(false, "badge %s covers a name at turn %d (%s vs %s)" % [id, step, r, l])
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					bad += 1
					_check(false, "two badges overlap at turn %d (%s %s)" % [step, rects[i], rects[j]])
	# No Label "!" is drawn but the prompt's own bang (the badges are sprites; the logical labels are invisible).
	hub.near = hub.stations_by_id("wheel") if hub.has_method("stations_by_id") else {}
	await _physics_frames(5)
	var stray := 0
	for n in hub.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text == "!" and l.is_visible_in_tree() and l != hub.prompt_bang and l.self_modulate.a > 0.0 and l.get_theme_color("font_color").a > 0.0:
			stray += 1
	_check(stray == 0, "no stray visible ! label in the hub (%d)" % stray)
	# IMP3-03: the UPGRADES / WHEEL news waits for something newly affordable since the station was last used.
	progress.hub_seen.clear()
	progress.tickets = 500
	_check(progress.hub_news("wheel", true), "never opened: an affordable wheel has news")
	var saves_before: int = progress.saves_written
	progress.hub_mark_seen("wheel")
	_check(progress.saves_written == saves_before, "BUG4-08: opening a station writes no save")
	_check(not progress.hub_news("wheel", true), "opened, nothing new: no news")
	progress.tickets += 5
	_check(not progress.hub_news("wheel", true), "BUG4-12: one more coin for the same item is no news")
	_check(not progress.hub_news("wheel", false), "not affordable: none")
	progress.tickets = 0
	_check(not progress.hub_news("wheel", false) and not progress.hub_seen.has("wheel"), "broke: the marker is cleared")
	progress.tickets = 500
	_check(progress.hub_news("wheel", true), "affordable again after being broke is news")
	progress.hub_mark_seen("wheel")
	progress.hub_seen["wheel"] = progress.hub_seen["wheel"] + 100  # (the visit saw only a dearer item: a cheaper one now is news)
	_check(progress.hub_news("wheel", true), "a cheaper item than the visit's cheapest is news")
	# [hub] seen_upgrades / seen_wheel survive a save round trip
	progress.hub_seen = {"upgrades": 123, "wheel": 45}
	var seen_file: ConfigFile = progress._write()
	_check(seen_file.get_value("hub", "seen_upgrades", -1) == 123 and seen_file.get_value("hub", "seen_wheel", -1) == 45, "[hub] seen_upgrades / seen_wheel are written")
	progress.hub_seen = {}
	progress._read(seen_file)
	_check(progress.hub_seen.get("upgrades", -1) == 123 and progress.hub_seen.get("wheel", -1) == 45, "...and read back")
	_check(checked > 100, "many badges were checked (%d)" % checked)
	_check(bad == 0, "no badge covers a name or another badge")
	current_scene = null
	hub.free()
	_result()
	quit(1 if failures > 0 else 0)
