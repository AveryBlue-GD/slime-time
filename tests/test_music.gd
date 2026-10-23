extends "res://tests/suite_base.gd"

## Music (scripts/music.gd): the hub plays one of the three hub loops, picked at random and never the same
## one twice in a row, keeps it on the hub's own screens and the settings pages, and fades it out for a
## level or the title; the story intro starts its own track, re-syncs it to a skipped-to shot and stops it
## at the end; the intro's shot starts match the sections tools/make_music.py composed (INTRO_SHOTS); the
## tracks load, the hub loops loop, and no demo export leaves them out.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_music.gd

var music: Node


func _initialize() -> void:
	await process_frame
	music = root.get_node("Music")
	var progress := root.get_node("Progress")
	progress.saving_enabled = false

	# --- The files: present, OGG, the hub loops loop, and every demo export keeps them
	var all_load := true
	for path: String in Music.HUB_TRACKS + [Music.INTRO_TRACK]:
		var stream := load(path) as AudioStreamOggVorbis
		all_load = all_load and stream != null and stream.get_length() > 10.0
	_check(all_load, "the three hub loops and the intro track load as OGG streams")
	var kept := true
	for web in [false, true]:
		var cut := Demo.export_cut(web)
		for path: String in Music.HUB_TRACKS + [Music.INTRO_TRACK]:
			kept = kept and not path in cut and not (path + ".import") in cut
	_check(kept, "no demo export (desktop or web) leaves the music out")

	# --- The hub: a random loop, kept across the hub's screens, a new pick after a level
	music.follow_scene("res://scenes/hub.tscn")
	_check(music.is_hub_music() and music.current in Music.HUB_TRACKS, "entering the hub starts a hub loop (%s)" % music.current.get_file())
	_check((music._player.stream as AudioStreamOggVorbis).loop, "the hub loop is set to loop")
	var first: String = music.current
	for screen in ["res://scenes/skins.tscn", "res://scenes/level_select.tscn", "res://scenes/controls.tscn", "res://scenes/hub.tscn"]:
		music.follow_scene(screen)
	_check(music.current == first and music._target == 1.0, "the same loop keeps playing on the hub's screens and the settings")
	progress.level_music = false  # (IMP-05: with LEVEL MUSIC off a level is silent as before)
	music.follow_scene("res://scenes/main.tscn")
	_check(music._target == 0.0, "starting a level fades the hub music out")
	for i in 90:
		await process_frame
	_check(music.current == "" and not music._player.playing, "after the fade the music has stopped")
	var picks := {}
	var repeats := 0
	var last: String = first
	for i in 40:
		music.follow_scene("res://scenes/hub.tscn")
		picks[music.current] = true
		if music.current == last:
			repeats += 1
		last = music.current
		music.stop(0.0)
		await process_frame
	_check(picks.size() == Music.HUB_TRACKS.size() and repeats == 0, "over 40 hub visits all %d loops come up, never the same twice in a row (%d seen, %d repeats)" % [Music.HUB_TRACKS.size(), picks.size(), repeats])
	music.follow_scene("res://scenes/hub.tscn")
	music.follow_scene("res://scenes/title.tscn")
	_check(music.current == Music.TITLE_TRACK, "IMP-05: going to the title swaps the hub music for the title loop")
	music.stop(0.0)
	await process_frame
	progress.level_music = true
	music.follow_scene("res://scenes/main.tscn")
	_check(music.current == Music.LEVEL_TRACK and (music._player.stream as AudioStreamOggVorbis).loop, "IMP-05: a level plays the quiet bed")
	music.stop(0.0)
	await process_frame

	# --- The story intro: its own track, synced to the shots, stopped at the end
	var make_music := FileAccess.get_file_as_string("res://tools/make_music.py")
	var shots := PackedStringArray()
	var at := 0.0
	shots.append("0.0")
	for card in Story.INTRO:
		at += float(card.time)
		shots.append(str(snappedf(at, 0.1)))
	var line := "INTRO_SHOTS = (%s)" % ", ".join(shots)
	_check(make_music.contains(line), "the intro track's sections match the intro's shots (%s)" % line)
	Story.mode = "intro"
	var screen: Control = load("res://scenes/story.tscn").instantiate()
	screen.leave_on_finish = false
	root.add_child(screen)
	await process_frame
	_check(music.current == Music.INTRO_TRACK and not (music._player.stream as AudioStreamOggVorbis).loop, "the intro starts its own track (not looped)")
	_check(is_equal_approx(screen.shot_start(3), 12.5) and screen.shot_start(0) == 0.0, "shot starts follow the intro's timeline (fall at 12.5 s)")
	screen.advance()
	screen.advance()
	await process_frame
	var pos: float = music._player.get_playback_position()
	_check(absf(pos - screen.shot_start(2)) < 0.5, "skipping to the crack shot jumps the music to its section (%.2f s)" % pos)
	screen.finish()
	_check(music._target == 0.0, "the end of the intro fades its music out")
	screen.queue_free()
	await process_frame
	music.stop(0.0)

	# --- Sound off: silent
	music.follow_scene("res://scenes/hub.tscn")
	progress.sound_on = false
	await process_frame
	_check(music._player.volume_db <= -79.0, "with sound off the music is silent")
	progress.sound_on = true
	music.stop(0.0)

	_result()
	quit(1 if failures else 0)
