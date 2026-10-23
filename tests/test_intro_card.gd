extends "res://tests/suite_base.gd"

## IMP2-01: the launch card. When it plays (cold launch only: never the first-ever launch, never a return from the
## hub, never in headless / tests / --story / --autoplay / screenshot runs), that a skip waits 0.15 s and is
## consumed (it never presses ENTER THE HUB), MOTION: LESS is the 0.4 s plain fade, the 1.8 s run hands the UI
## back, the sting leads into the title loop, and BUG2-05's clean 16 px text (tagline, ENTER THE HUB).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_intro_card.gd


var progress: Node
var music: Node
var presses := 0


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	music = root.get_node("Music")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.story_seen = progress.STORY_INTRO | progress.STORY_FINALE
	progress.reduce_motion = false

	# --- when it plays
	_check(IntroCard.env_skips(), "headless runs skip the card")
	_check(not IntroCard.due(true, progress), "a headless run (this test, without force) gets no card")
	IntroCard.force = true
	_check(IntroCard.due(true, progress), "forced past the environment skips: a cold launch on a save that saw the intro gets the card")
	_check(not IntroCard.due(false, progress), "a title that is not the boot title (a return from the hub) never gets it")
	progress.story_seen = 0
	_check(not IntroCard.due(true, progress), "the first-ever launch (the story intro is due) never gets it")
	progress.story_seen = progress.STORY_INTRO | progress.STORY_FINALE
	_check(IntroCard.capture_seconds() < 0.0, "no --intro-card flag here: no screenshot capture")

	# --- a cold launch: the card holds the title's UI hidden, a hub return gets none
	Story.launched = false
	var title := await _title()
	_check(title.intro_card != null and title.intro_card.running, "a cold title starts the card")
	_check(title.enter_button.modulate.a == 0.0, "the title's UI is held invisible under the card")
	_check(title.intro_card.mouse_filter == Control.MOUSE_FILTER_STOP and not title.intro_card.still, "the card blocks the mouse and is the full version")
	_check(is_equal_approx(title.intro_card.duration(), 1.8), "the card lasts 1.8 s")
	title.enter_button.pressed.connect(func() -> void: presses += 1)

	# --- a skip before 0.15 s is consumed but does not skip; after it, it skips and is consumed
	var first: IntroCard = title.intro_card
	root.push_input(_key(KEY_ENTER))
	_check(first.running and presses == 0, "a key at 0.0 s is eaten and does not skip yet")
	await _wait_seconds(0.25)
	_check(first.time > 0.15 and first.running, "the card is running at 0.25 s")
	root.push_input(_key(KEY_ENTER))
	await process_frame
	_check(not is_instance_valid(first) or not first.running, "a key after 0.15 s skips the card")
	_check(presses == 0, "the skip input never pressed ENTER THE HUB")
	_check(title.enter_button.modulate.a == 1.0, "a skip hands the title's UI back at full alpha")
	await _frames(3)
	_check(not is_instance_valid(first), "the skipped card frees itself")
	_check(music.current == music.TITLE_TRACK or not Economy.LEVEL_MUSIC, "a skip starts the title loop at once")
	title.queue_free()
	await process_frame

	# --- a full run: 1.8 s, then the title's UI is back and the card is gone
	Story.launched = false
	title = await _title()
	var full: IntroCard = title.intro_card
	_check(music.current == music.STING_TRACK or not Economy.LEVEL_MUSIC, "the card plays the title sting")
	await _wait_seconds(1.95)
	_check(title.enter_button.modulate.a == 1.0 and title.get_node("Logo").modulate.a == 1.0, "after 1.8 s the title's UI is fully visible")
	_check(not is_instance_valid(full), "the card is freed after its 1.8 s")
	title.queue_free()
	await process_frame

	# --- MOTION: LESS = the 0.4 s plain fade
	progress.reduce_motion = true
	Story.launched = false
	title = await _title()
	var card: IntroCard = title.intro_card
	_check(card != null and card.still and is_equal_approx(card.duration(), 0.4), "MOTION: LESS shows the 0.4 s plain fade")
	await _wait_seconds(0.2)
	_check(card.running and title.enter_button.modulate.a > 0.0 and title.enter_button.modulate.a < 1.0, "the fade is half way at 0.2 s")
	await _wait_seconds(0.3)
	_check(not is_instance_valid(card) or not card.running, "the still version is done by 0.5 s")
	_check(title.enter_button.modulate.a == 1.0, "and the title is fully back")
	title.queue_free()
	await process_frame
	progress.reduce_motion = false

	# --- a return from the hub: no card, UI visible
	Story.launched = true
	title = await _title()
	_check(title.intro_card == null and title.enter_button.modulate.a == 1.0, "a title reached after the boot (a hub return) shows no card")
	# --- BUG2-05: the tagline and ENTER THE HUB render without drips, headings keep theirs
	var clean := UIKit.clean_big_material()
	_check(clean.get_shader_parameter("clean_big") == true and title.enter_button.material == clean, "ENTER THE HUB uses the clean 16 px material")
	var tagline_clean := false
	for child in title.get_children():
		if child is Label and child.material == clean:
			tagline_clean = true
	_check(tagline_clean, "the tagline uses the clean 16 px material")
	_check(UIKit.text_material().get_shader_parameter("clean_big") != true, "the shared heading material keeps its 16 px drips")
	var shader_src := FileAccess.get_file_as_string("res://assets/shaders/text_drips.gdshader")
	_check(shader_src.contains("if (clean_big && big_font)"), "the shader reads clean_big and zeroes the 16 px drips")
	title.queue_free()
	IntroCard.force = false
	await process_frame
	_result()
	quit(0 if failures == 0 else 1)


func _title() -> Node:
	var title: Node = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	return title


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key
