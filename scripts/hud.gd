extends CanvasLayer

## Three framed pods along the top: slime meter (goo-drop icon + segmented bar in the skin's
## color + percent), run timer (clock icon), level name. Plus a center message on a panel, the
## gold NEW RECORD! banner with sparkling chalices, and a soft vignette under it all.

## Four 25% chunks: 12 px each with 1 px gaps (4 * 12 + 3 = 51).
const BAR_SIZE := Vector2(51, 6)
const SEGMENTS := 4
const CHUNK := 12
const POD_MARGIN := 3
## Below this percent the meter turns red and pulses.
const LOW_PERCENT := 20.0
## Seconds the area name stays up before fading.
const AREA_NAME_TIME := 2.0
## Where the area name sits in a randomizer maze, clear of the two-line attempt pod (normally y 20).
const AREA_TOP_UNDER_ATTEMPT := 44
const FRAME_COLOR := Color8(26, 28, 44)
const LOW_COLOR := Color8(220, 40, 50)
const GOLD := Color8(255, 205, 117)
const CHALICE_FPS := 5.0
## One frame of assets/sprites/chalice_sheet.png (4 frames side by side).
const CHALICE_FRAME := Vector2(16, 20)

var fill: ColorRect
var _shine: ColorRect
var _drop: TextureRect
var _low := false
var _pulse := 0.0
var goo_color := Color8(239, 125, 47)
var _rainbow := false
var _hue := 0.0
var label: Label
var level_label: Label
var message: Label
## The area's name (the level theme), shown under the top bar as a maze starts, then fading.
var area_label: Label
## A story line under the area name (see Story.level_line).
var story_label: Label
var _message_panel: PanelContainer
var time_label: Label
## Coins in hand (top bar, beside the slime meter), and coins still to find in this story level
## (top bar, beside the level name; hidden in randomizer mazes, which have none).
var coin_label: Label
var coins_left_label: Label
var _coins_left_pod: Control
## Randomizer only: the attempt on this maze and the tickets a win would pay now
## ("ATTEMPT 2" over "TIX AVAILABLE 4").
var attempt_pod: Control
var attempt_label: Label
var _attempt_icon: TextureRect
## The attempt pod's pop (set_attempt): a bright copy of the TIX AVAILABLE line, flashed over it.
var _attempt_flash: Label
var _attempt_tween: Tween
## Pop timing: wait for the restart's goo wipe (Transition.UNCOVER_TIME 0.32 s) to clear the top of
## the screen, blink bright, dim, bright, then fade (about half a second in all).
const ATTEMPT_POP_DELAY := 0.2
const ATTEMPT_POP_BLINK := 0.08
const ATTEMPT_POP_FADE := 0.34
const ATTEMPT_POP_COLOR := Color(1.6, 1.5, 1.2)
const ATTEMPT_FLASH_TINT := Color.WHITE
const ATTEMPT_POP_PANEL := Color(2.2, 2.0, 1.6)
## DESCENT: the boons held this run, an 8x8 icon each (stacks repeat; unused BACKUP BLADDERs only).
var boon_pod: Control
var boon_strip: GridContainer
## The ids the strip shows, in order (for tests).
var boon_icons: Array[String] = []
const BOON_COLUMNS := 8
## Shown only when a level is beaten faster than its saved record.
var record_banner: CenterContainer
var record_time_label: Label
var _chalices: Array[TextureRect] = []
var _chalice_clock := 0.0
## Buttons offered after a win (replay / next).
var choice_buttons: Array[Button] = []
var _choice_root: Control
var _skin_text: SkinText
## Under the result text: the level's medal tier or the tickets earned (see show_rewards).
var rewards_row: HBoxContainer
var rewards_texts: Array[String] = []
## Shown on the left while an attempt is played with the slime reserve (ASSIST).
var assist_pod: Control
## The ticket workshop's SECOND WIND (set_wind): a drop + WIND tag under the meter, full color while
## ready, dim once used, hidden when it isn't on this run (not bought, hard mode, a first clear).
var wind_pod: Control
var _wind_icon: TextureRect
var wind_state := ""
const WIND_TINT := Color8(170, 236, 255)
const WIND_USED := Color(0.45, 0.45, 0.5, 0.75)
## Dev mode only: a tag naming the dev toggles that are on (made on first use, so it never exists
## in normal play; see set_dev_badge).
var dev_badge: Control
var _dev_label: Label
var _left_bar: BoxContainer
var _vignette: ColorRect
const DEV_TINT := Color8(255, 120, 220)
const MEDAL_GOLD := Color8(255, 205, 117)
const MEDAL_OWNED := Color8(150, 134, 100)
const MEDAL_OFF := Color8(70, 74, 96)
const TIER_COLORS: Array[Color] = [Color8(70, 74, 96), Color8(214, 140, 84), Color8(206, 214, 232), Color8(255, 205, 117)]
const TICKET_TINT := Color8(255, 226, 150)
const TICKET_DIM := Color(0.55, 0.55, 0.6)
const NEW_BEST_COLOR := Color8(255, 245, 190)
const ASSIST_TINT := Color8(110, 236, 214)


func _ready() -> void:
	var vignette := ColorRect.new()
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = preload("res://assets/shaders/atmosphere.gdshader")
	vignette_material.set_shader_parameter("mist_strength", 0.0)
	# Corners only and light: it must not darken the lit trail (the fog shader has its own edge fall-off).
	vignette_material.set_shader_parameter("vignette_strength", 0.3)
	vignette_material.set_shader_parameter("vignette_start", 0.6)
	vignette_material.set_shader_parameter("vignette_end", 1.15)
	vignette.material = vignette_material
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	_vignette = vignette

	# The top bar, mirrored: the meter on the left with the coins in hand under it, the timer in
	# the middle, the level on the right with the coins left to find here under it.
	var left_bar := _make_bar(Control.PRESET_TOP_LEFT)
	_left_bar = left_bar
	var right_bar := _make_bar(Control.PRESET_TOP_RIGHT)

	# Left pod: goo drop, segmented meter, percent.
	var meter_row := _make_pod(left_bar)
	_drop = UIKit.make_icon("drop", goo_color)
	meter_row.add_child(_drop)
	meter_row.add_child(_build_meter())
	label = _make_label()
	label.custom_minimum_size = Vector2(22, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter_row.add_child(label)

	# Coins in hand.
	var coin_row := _make_pod(left_bar)
	coin_row.add_child(UIKit.make_icon("coin", Color.WHITE))
	coin_label = _make_label()
	coin_row.add_child(coin_label)

	# The slime reserve tag (hidden unless this attempt is assisted).
	var assist_row := _make_pod(left_bar)
	assist_pod = assist_row.get_parent()
	assist_row.add_child(UIKit.make_icon("drop", ASSIST_TINT))
	assist_row.add_child(UIKit.make_label("ASSIST +%d%%" % roundi(Progress.ASSIST_BONUS * 100.0), 8, GOLD))
	assist_pod.visible = false

	# SECOND WIND (hidden unless it's on this run).
	var wind_row := _make_pod(left_bar)
	wind_pod = wind_row.get_parent()
	_wind_icon = UIKit.make_icon("drop", WIND_TINT)
	wind_row.add_child(_wind_icon)
	wind_row.add_child(UIKit.make_label("WIND", 8, WIND_TINT))
	wind_pod.visible = false

	# Center pod: clock + run time.
	var time_row := _make_pod(null)
	time_row.add_child(UIKit.make_icon("clock", UIKit.TEXT))
	time_label = _make_label()
	time_label.custom_minimum_size = Vector2(37, 0)  # "0:00.0" + 1: an even-width pod sits exactly on center
	time_row.add_child(time_label)

	# The level name, and under it the coins still hidden in this level (a dim coin).
	var level_row := _make_pod(right_bar)
	level_label = _make_label()
	level_row.add_child(level_label)
	var left_row := _make_pod(right_bar)
	_coins_left_pod = left_row.get_parent()
	left_row.add_child(UIKit.make_icon("coin", Color(0.75, 0.75, 0.8)))
	coins_left_label = _make_label(SkinText.ROLE_DIM)
	left_row.add_child(coins_left_label)

	# Randomizer mazes: the attempt and the tickets a win would pay now (see set_attempt).
	var attempt_row := _make_pod(right_bar)
	attempt_pod = attempt_row.get_parent()
	_attempt_icon = UIKit.make_icon("ticket", Color.WHITE)
	attempt_row.add_child(_attempt_icon)
	attempt_label = UIKit.make_label("", 8, TICKET_TINT)
	attempt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	attempt_row.add_child(attempt_label)
	_attempt_flash = UIKit.make_label("", 8, ATTEMPT_FLASH_TINT)
	_attempt_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_attempt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attempt_flash.modulate.a = 0.0
	attempt_label.add_child(_attempt_flash)
	attempt_pod.visible = false

	# DESCENT: the run's boons as a strip of icons (see set_boons), under the pot pod.
	var boon_row := _make_pod(right_bar)
	boon_pod = boon_row.get_parent()
	boon_strip = GridContainer.new()
	boon_strip.columns = BOON_COLUMNS
	boon_strip.add_theme_constant_override("h_separation", 1)
	boon_strip.add_theme_constant_override("v_separation", 1)
	boon_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boon_row.add_child(boon_strip)
	boon_pod.visible = false

	area_label = _make_label(SkinText.ROLE_DIM)
	area_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	area_label.offset_top = 20
	area_label.offset_bottom = 30
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_label.visible = false
	add_child(area_label)
	story_label = _make_label(SkinText.ROLE_DIM)
	story_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	story_label.offset_top = 31
	story_label.offset_bottom = 41
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.visible = false
	add_child(story_label)

	var message_center := CenterContainer.new()
	message_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_center.offset_top = 20
	message_center.offset_bottom = -40
	message_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_center)
	_message_panel = PanelContainer.new()
	_message_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_center.add_child(_message_panel)
	var message_box := VBoxContainer.new()
	message_box.add_theme_constant_override("separation", 4)
	message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.add_child(message_box)
	message = _make_label(SkinText.ROLE_TITLE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_box.add_child(message)
	rewards_row = HBoxContainer.new()
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.add_theme_constant_override("separation", 6)
	rewards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards_row.visible = false
	message_box.add_child(rewards_row)
	# The panel shows whenever the message does.
	message.visibility_changed.connect(func() -> void: _message_panel.visible = message.visible)
	message.visible = false
	_message_panel.visible = false

	_build_record_banner()
	_build_choice_row()
	set_slime(100.0)
	set_time(0.0)
	_skin_text = SkinText.new()
	_skin_text.theme_owner = _choice_root
	add_child(_skin_text)


func set_slime(percent: float) -> void:
	fill.size.x = roundf(BAR_SIZE.x * clampf(percent, 0.0, 100.0) / 100.0)
	_shine.size.x = fill.size.x
	_low = percent < LOW_PERCENT
	fill.color = LOW_COLOR if _low else goo_color
	if not _low:
		fill.modulate = Color.WHITE
	label.text = "%d%%" % ceili(percent)


## A column of pods anchored to a top corner, each hugging that side; the right one grows
## leftward.
func _make_bar(preset: Control.LayoutPreset) -> BoxContainer:
	var bar := VBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_theme_constant_override("separation", 2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_preset(preset)
	bar.offset_top = POD_MARGIN
	if preset == Control.PRESET_TOP_RIGHT:
		bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		bar.offset_left = -POD_MARGIN
		bar.offset_right = -POD_MARGIN
	else:
		bar.offset_left = POD_MARGIN
		bar.offset_right = POD_MARGIN
	return bar


## A framed pod: in `bar`, or (null) on its own centered at the top. Returns its row to fill.
func _make_pod(bar: BoxContainer) -> HBoxContainer:
	var pod := PanelContainer.new()
	pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bar:
		bar.add_child(pod)
		var right := bar.grow_horizontal == Control.GROW_DIRECTION_BEGIN
		pod.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	else:
		# A CenterContainer keeps it on whole pixels as the time's width changes.
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		center.offset_top = POD_MARGIN
		center.add_child(pod)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod.add_child(row)
	return row


## The slime bar: dark frame, sunken track, goo fill with a 1 px shine, segment ticks.
func _build_meter() -> Control:
	var meter := Control.new()
	meter.custom_minimum_size = BAR_SIZE + Vector2(2, 2)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_rect(meter, Vector2.ZERO, BAR_SIZE + Vector2(2, 2), FRAME_COLOR)
	_add_rect(meter, Vector2.ONE, BAR_SIZE, Color8(40, 34, 52))
	fill = _add_rect(meter, Vector2.ONE, BAR_SIZE, goo_color)
	_shine = _add_rect(meter, Vector2.ONE, Vector2(BAR_SIZE.x, 1), Color(1, 1, 1, 0.35))
	for i in range(1, SEGMENTS):
		_add_rect(meter, Vector2(i * (CHUNK + 1), 1), Vector2(1, BAR_SIZE.y), Color(FRAME_COLOR, 0.6))
	return meter


func _add_rect(parent: Control, at: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## Updates the coin counts: `total` in hand, and `found` of the `here` coins in this level
## (`here` = 0 hides that pod: randomizer mazes have no coins). `pop` flashes the total gold
## (a coin was just picked up).
func set_coins(total: int, found: int, here: int, pop := false) -> void:
	coin_label.text = str(mini(total, 999))
	coins_left_label.text = "ALL FOUND" if found >= here else "%d LEFT" % (here - found)
	_coins_left_pod.visible = here > 0
	if pop:
		coin_label.add_theme_color_override("font_color", GOLD)
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_callback(func() -> void: _skin_text.recolor())


## The attempt pod (randomizer mazes only): which attempt at this maze it is and the tickets a win
## would pay right now (every cap applied), counting down attempt by attempt: "ATTEMPT 1" over
## "TIX AVAILABLE 5", then 4, 3, 2 and 1 from the 5th; 1 when capped, dim 0 when a win would pay
## nothing. Called every frame by the game (only a changed text touches the label).
## `pop`: the number just changed (a restart): the TIX AVAILABLE line flashes bright twice and
## fades back (ATTEMPT_POP_*, about half a second, after the restart's goo wipe has cleared the top).
func set_attempt(attempt: int, payout: int, pop := false) -> void:
	var text := "ATTEMPT %d\nTIX AVAILABLE %d" % [mini(attempt, 99), payout]
	if text == attempt_label.text and attempt_pod.visible and not pop:
		return  # called every frame: only a change touches the label
	attempt_pod.visible = true
	# The two-line pod reaches down to y 40: the area name moves under it instead of under the timer.
	area_label.offset_top = AREA_TOP_UNDER_ATTEMPT
	area_label.offset_bottom = AREA_TOP_UNDER_ATTEMPT + 10
	attempt_label.text = text
	var color := TICKET_TINT if payout > 0 else MEDAL_OWNED
	attempt_label.add_theme_color_override("font_color", color)
	_attempt_icon.modulate = Color.WHITE if payout > 0 else TICKET_DIM
	# The flash: a bright copy of the second line drawn over it (the first line left blank).
	_attempt_flash.text = " \nTIX AVAILABLE %d" % payout
	if _attempt_tween:
		_attempt_tween.kill()
		_attempt_tween = null
	_attempt_flash.modulate.a = 0.0
	_attempt_icon.self_modulate = Color.WHITE
	attempt_pod.self_modulate = Color.WHITE
	if not pop:
		return
	var flash := func(a: float) -> void:
		_attempt_flash.modulate.a = a
		_attempt_icon.self_modulate = Color.WHITE.lerp(ATTEMPT_POP_COLOR, a)
		attempt_pod.self_modulate = Color.WHITE.lerp(ATTEMPT_POP_PANEL, a)
	_attempt_tween = create_tween()
	_attempt_tween.tween_interval(ATTEMPT_POP_DELAY)
	_attempt_tween.tween_method(flash, 1.0, 1.0, ATTEMPT_POP_BLINK)
	_attempt_tween.tween_method(flash, 0.25, 0.25, ATTEMPT_POP_BLINK)
	_attempt_tween.tween_method(flash, 1.0, 0.0, ATTEMPT_POP_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_attempt_tween.tween_callback(func() -> void: _attempt_tween = null)


## DESCENT: the pot pod (in the attempt pod's place): "POT 6" with the ticket icon, and a second
## line when the run would pay less: PRACTICE (today's paying runs used), NO TICKETS (dev toggles),
## PAYS 1 (no MORE SLIME). `gain` > 0 adds "+N" (the floor just cleared). Dim when it pays nothing.
func set_pot(pot: int, cap: String, gain := 0) -> void:
	var text := "POT %d" % pot
	if gain > 0:
		text += " +%d" % gain
	var why: String = {"practice": "PRACTICE", "dev": "NO TICKETS", "slime": "PAYS 1"}.get(cap, "")
	if why != "":
		text += "\n" + why
	if text == attempt_label.text and attempt_pod.visible:
		return
	attempt_pod.visible = true
	area_label.offset_top = AREA_TOP_UNDER_ATTEMPT
	area_label.offset_bottom = AREA_TOP_UNDER_ATTEMPT + 10
	story_label.offset_top = AREA_TOP_UNDER_ATTEMPT + 11  # the floor number under the area name
	story_label.offset_bottom = AREA_TOP_UNDER_ATTEMPT + 21
	attempt_label.text = text
	var pays := cap == "" or cap == "slime"
	attempt_label.add_theme_color_override("font_color", TICKET_TINT if pays else MEDAL_OWNED)
	_attempt_icon.modulate = Color.WHITE if pays else TICKET_DIM


## DESCENT: shows the run's boons (Descent.IDS order; stacks repeat; BIG GULP, used at once, and
## used BACKUP BLADDERs are left out). Hidden when there are none.
func set_boons(boons: Dictionary, bladders_left := 0) -> void:
	for child in boon_strip.get_children():
		child.queue_free()
	boon_icons.clear()
	for id in Descent.IDS:
		var n := Descent.held(boons, id)
		if id == "gulp":
			n = 0
		elif id == "bladder":
			n = bladders_left
		for i in n:
			boon_strip.add_child(BoonIcons.make(id))
			boon_icons.append(id)
	boon_pod.visible = not boon_icons.is_empty()


## True while the attempt pod's pop is still playing (or waiting for the goo wipe to clear).
func attempt_flashing() -> bool:
	return _attempt_tween != null and _attempt_tween.is_valid() and _attempt_tween.is_running()


func set_time(seconds: float) -> void:
	time_label.text = UIKit.format_time(seconds)


## The assist tag in the top bar.
func set_assist(on: bool) -> void:
	assist_pod.visible = on


## SECOND WIND's tag: "" hides it, "ready" full color, "refilling" flashes bright, "used" dim.
func set_wind(state: String) -> void:
	wind_state = state
	wind_pod.visible = state != ""
	match state:
		"ready":
			wind_pod.modulate = Color.WHITE
		"refilling":
			wind_pod.modulate = Color(1.8, 1.8, 1.8)
			var tween := wind_pod.create_tween()
			tween.tween_property(wind_pod, "modulate", WIND_USED, 0.6)
		"used":
			wind_pod.modulate = WIND_USED


## Dev mode: a DEV tag under the meter naming the toggles that are on ("" hides it). Only ever
## called by the dev toggles, so normal play never builds it.
func set_dev_badge(text: String) -> void:
	if text == "" and dev_badge == null:
		return
	if dev_badge == null:
		var row := _make_pod(_left_bar)
		dev_badge = row.get_parent()
		_dev_label = UIKit.make_label("", 8, DEV_TINT)
		row.add_child(_dev_label)
	_dev_label.text = "DEV " + text
	dev_badge.visible = text != ""


## The corner vignette (off while the dev FULL BRIGHT toggle is on).
func set_vignette(on: bool) -> void:
	_vignette.visible = on


## Under the result text. A story clear shows its medal tier as three icons (gold up to the tier
## won this run, dim gold up to an older better tier, dark for the rest), the tier name and NEW BEST
## when it raised the saved one. `info` is Progress.record_clear's result. A randomizer win shows
## the ticket vouchers it paid ({tickets, attempt, cap}: "TICKET! ATTEMPT 2 = +4", plus why when
## capped to 1: cap "replay" = REPLAYED SEED, "slime" = MORE SLIME = MORE); `capped` says the day's
## limit is used up, `repeat` that this seed already paid today.
## An assisted run says it earns nothing instead.
func show_rewards(info: Dictionary) -> void:
	for child in rewards_row.get_children():
		child.queue_free()
	rewards_texts.clear()
	if info.get("dev", false):
		_reward_label("DEV TOGGLES: NO MEDALS, RECORDS OR TICKETS", MEDAL_OWNED)
	elif info.get("offer", false):
		_reward_label("ASSIST: +%d%% SLIME, NO MEDALS/TICKETS" % roundi(Progress.ASSIST_BONUS * 100.0), MEDAL_OWNED)
	elif info.get("assisted", false):
		_reward_label("ASSIST: NO MEDALS, RECORDS OR TICKETS", MEDAL_OWNED)
	elif info.has("tier"):
		var tier: int = info.tier
		var best: int = info.best
		var names := ["", "BRONZE", "SILVER", "GOLD"]
		for i in range(1, 4):
			var color: Color = TIER_COLORS[tier] if tier >= i else (MEDAL_OWNED if best >= i else MEDAL_OFF)
			rewards_row.add_child(UIKit.make_icon("medal", color))
		_reward_label(names[tier], TIER_COLORS[tier])
		if info.new_best:
			_reward_label("NEW BEST!", NEW_BEST_COLOR)
		elif best > tier:
			_reward_label("BEST " + names[best], MEDAL_OWNED)
	elif info.get("repeat", false):
		_reward_label("SEED ALREADY PAID TODAY - TRY NEW MAZE", MEDAL_OWNED)
	elif info.get("capped", false):
		_reward_label("DAILY TICKET LIMIT REACHED", MEDAL_OWNED)
	else:
		rewards_row.add_child(UIKit.make_icon("ticket", Color.WHITE))
		if info.has("attempt"):
			_reward_label("TICKET! ATTEMPT %d = +%d" % [info.attempt, info.tickets], TICKET_TINT)
		else:
			_reward_label("+%d TICKETS" % info.tickets, TICKET_TINT)
		match info.get("cap", ""):
			"replay":
				_reward_label("REPLAYED SEED", MEDAL_OWNED)
			"slime":
				_reward_label("MORE SLIME = MORE", MEDAL_OWNED)
	rewards_row.visible = true


func _reward_label(text: String, color: Color) -> void:
	var l := UIKit.make_label(text, 8, color)
	rewards_row.add_child(l)
	rewards_texts.append(text)


## The gold NEW RECORD! banner (big text + the new time) between two sparkling chalices.
func show_record(seconds: float) -> void:
	record_time_label.text = UIKit.format_time(seconds)
	record_banner.visible = true


## Shows a row of buttons, each [text, Callable]; button `focus` (default: the last) gets
## keyboard focus.
func show_choices(options: Array, focus := -1) -> void:
	var row: HBoxContainer = _choice_root.get_child(0).get_child(0)
	for child in row.get_children():
		child.queue_free()
	choice_buttons.clear()
	for option: Array in options:
		var button := UIKit.make_button(option[0], option[1], Vector2(84, 13))
		row.add_child(button)
		choice_buttons.append(button)
	_choice_root.visible = true
	_skin_text.recolor()
	choice_buttons[focus].grab_focus()


func _build_choice_row() -> void:
	_choice_root = Control.new()
	_choice_root.theme = UIKit.make_theme()
	_choice_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.visible = false
	add_child(_choice_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 152
	center.offset_bottom = 168
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)


func _build_record_banner() -> void:
	record_banner = CenterContainer.new()
	record_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	record_banner.offset_top = 109
	record_banner.offset_bottom = 150
	record_banner.visible = false
	add_child(record_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	record_banner.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 5)  # room for the title's drips (they hang below its line box)
	var title := _gold_label("NEW RECORD!", 16)
	record_time_label = _gold_label("", 8)
	words.add_child(title)
	words.add_child(record_time_label)
	row.add_child(_make_chalice())
	row.add_child(words)
	row.add_child(_make_chalice())


func _make_chalice() -> TextureRect:
	var chalice := TextureRect.new()
	var frame := AtlasTexture.new()
	frame.atlas = preload("res://assets/sprites/chalice_sheet.png")
	frame.region = Rect2(Vector2.ZERO, CHALICE_FRAME)
	chalice.texture = frame
	# Drawn at 2x (whole pixels stay crisp) to match the big NEW RECORD! text.
	chalice.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chalice.stretch_mode = TextureRect.STRETCH_SCALE
	chalice.custom_minimum_size = CHALICE_FRAME * 2
	chalice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chalices.append(chalice)
	return chalice


## Gold text that keeps its color whatever the skin (not in the SkinText group).
func _gold_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.material = UIKit.text_material()
	UIKit.use_big_font(l, size)
	return l


## Shows the area name for a moment, then fades it out.
func show_area_name(text: String, story_line := "") -> void:
	area_label.text = "- %s -" % text
	area_label.visible = true
	area_label.modulate.a = 1.0
	story_label.text = story_line
	story_label.visible = story_line != ""
	story_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(AREA_NAME_TIME + (1.0 if story_line != "" else 0.0))
	tween.tween_property(area_label, "modulate:a", 0.0, 0.8)
	tween.parallel().tween_property(story_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		area_label.visible = false
		story_label.visible = false)


func set_level_text(text: String) -> void:
	level_label.text = text


func set_skin_color(color: Color, rainbow := false) -> void:
	goo_color = color
	fill.color = color
	_drop.modulate = color
	_rainbow = rainbow


## Rainbow skin: the meter cycles through the rainbow (unless it's low and flashing red).
func _process(delta: float) -> void:
	if record_banner.visible:
		_chalice_clock += delta
		var frame := int(_chalice_clock * CHALICE_FPS) % 4
		for i in _chalices.size():
			# Glints alternate between the two chalices.
			(_chalices[i].texture as AtlasTexture).region.position.x = ((frame + i * 2) % 4) * CHALICE_FRAME.x
	if _low:
		_pulse += delta
		fill.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.6), 0.5 + 0.5 * sin(_pulse * 10.0))
	if not _rainbow:
		return
	_hue = fposmod(_hue + delta * 0.25, 0.83)
	goo_color = Color.from_hsv(_hue, 0.8, 0.95)
	_drop.modulate = goo_color
	if fill.color != LOW_COLOR:
		fill.color = goo_color


## Shows a message for a few seconds (unless something else replaces it meanwhile).
func flash_message(text: String, seconds: float) -> void:
	show_message(text)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(message) and message.text == text:
		message.visible = false


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func _make_label(role := SkinText.ROLE_TEXT) -> Label:
	var l := Label.new()
	l.material = UIKit.text_material()
	l.set_meta("role", role)
	l.add_to_group(SkinText.GROUP)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_constant_override("line_spacing", UIKit.LINE_SPACING)
	l.add_theme_color_override("font_shadow_color", Color(FRAME_COLOR, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
