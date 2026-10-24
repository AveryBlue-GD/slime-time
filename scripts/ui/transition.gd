extends CanvasLayer

## Autoload `Transition`: goo-wipe screen changes. `go(scene)` drops a sheet of goo in the skin's
## color over the screen, swaps scenes underneath, then lets it slide off. `reveal()` only does
## the slide-off half (for instant reloads, so a restarted level still eases in).

const COVER_TIME := 0.22
const UNCOVER_TIME := 0.32
## A little past 1 so the longest drips clear the bottom of the screen.
const OFF_SCREEN := 1.3
const SCREEN_HEIGHT := 180.0

## Physics interpolation (project setting on; see _process): only while frames come faster than the
## 60 Hz physics ticks. Between ON_ABOVE_FPS and OFF_BELOW_FPS it keeps its state, so a display near
## one of them doesn't flicker it on and off.
const INTERPOLATION_ON_ABOVE_FPS := 72.0
const INTERPOLATION_OFF_BELOW_FPS := 66.0
## The frame rate must stay past a threshold this long (seconds, without a break) before the switch
## flips: a hitch or a short slowdown never flips it (each flip is a frame the camera and slime
## change how they are placed), a lasting change flips it once.
const INTERPOLATION_SWITCH_HOLD := 0.5
## A frame longer than this (s) is a hitch (a first-use compile, an autosave, a background spike):
## left out of the estimate and the hold. Only a run of HITCH_RUN of them in a row counts (the game
## really runs that slowly now).
const HITCH_FRAME := 0.05
const HITCH_RUN := 3
## How fast the frame-rate estimate follows (share of each new frame).
const FPS_FOLLOW := 0.1

var busy := false
## Seconds per frame, smoothed (render frames, unscaled by Engine.time_scale).
var _frame_time := 1.0 / 60.0
## Seconds the estimate has been past the threshold for the other state, without a break.
var _switch_wait := 0.0
## Hitch frames in a row (see HITCH_FRAME).
var _hitches := 0
var _sheet: ColorRect
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Interpolation is opt-in: only nodes moved on physics ticks (the slime) turn it on; everything
	# placed per frame (menus, the hat, lights, the camera) would wobble between stale ticks.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_set_interpolation(false)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/goo_wipe.gdshader")
	_sheet = ColorRect.new()
	_sheet.material = _material
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false
	add_child(_sheet)


## High refresh: physics stays at 60 ticks a second (jump arcs, drain and timers never change), and
## above 60 Hz the slime is drawn between ticks (physics interpolation) instead of on a 60 Hz cadence
## held for 2-3 frames. At 60 Hz the frames are exactly what they were without it: interpolation
## would only draw everything one tick late there, so it stays off.
func _process(delta: float) -> void:
	_pump_notice(delta)
	if DisplayServer.get_name() != "headless":  # (nothing drawn there, and frames are unpaced)
		follow_frame_rate(delta / maxf(Engine.time_scale, 0.001))


## Takes one render frame's length (s) into the frame-rate estimate and switches interpolation once
## the estimate has stayed past the threshold for INTERPOLATION_SWITCH_HOLD.
func follow_frame_rate(frame: float) -> void:
	if frame <= 0.0:
		return
	if frame > HITCH_FRAME:
		_hitches += 1
		if _hitches < HITCH_RUN:
			return
	else:
		_hitches = 0
	_frame_time = lerpf(_frame_time, frame, FPS_FOLLOW)
	var fps := 1.0 / _frame_time
	var on := get_tree().physics_interpolation
	if (fps > INTERPOLATION_ON_ABOVE_FPS) if not on else (fps < INTERPOLATION_OFF_BELOW_FPS):
		_switch_wait += frame
		if _switch_wait >= INTERPOLATION_SWITCH_HOLD:
			_set_interpolation(not on)
	else:
		_switch_wait = 0.0


func _set_interpolation(on: bool) -> void:
	_switch_wait = 0.0
	get_tree().physics_interpolation = on
	# Godot's advice: no jitter fix with interpolation (the fraction does the pacing); its default
	# (0.5) otherwise, as before.
	Engine.physics_jitter_fix = 0.0 if on else 0.5
	get_tree().root.reset_physics_interpolation()


## Covers the screen, changes to `scene`, then uncovers.
func go(scene: String) -> void:
	if busy:
		return
	busy = true
	var music := get_node_or_null("/root/Music")
	if music:
		music.follow_scene(scene)  # the hub music starts fading as the wipe covers the screen
	_paint()
	_set_edges(0.0, 0.0)
	_sheet.visible = true
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _set_edges(v, 0.0), 0.0, OFF_SCREEN, COVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween.finished
	get_tree().paused = false  # never arrive on a new screen still paused
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	busy = false
	_uncover()


## Draws the sheet for one frame slid fully off the screen (every pixel discarded, nothing shows):
## its first draw costs several ms (7-8 ms on the M3), which otherwise lands on the first frame of
## the first screen change. The title calls this while it shows (title.gd _warm_up_shaders).
func warm_up() -> void:
	if busy or _sheet.visible:
		return
	_set_edges(OFF_SCREEN, OFF_SCREEN)
	_sheet.visible = true
	await get_tree().process_frame
	if not busy and not (_tween and _tween.is_valid() and _tween.is_running()):
		_sheet.visible = false


## Starts fully covered and slides the goo off (no scene change).
func reveal() -> void:
	if busy:
		return
	_paint()
	_uncover()


func _uncover() -> void:
	if _tween:
		_tween.kill()
	_sheet.visible = true
	_set_edges(OFF_SCREEN, 0.0)
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _set_edges(OFF_SCREEN, v), 0.0, OFF_SCREEN, UNCOVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: _sheet.visible = false)


func _set_edges(bottom: float, top: float) -> void:
	_material.set_shader_parameter("bottom", bottom)
	_material.set_shader_parameter("top", top)
	# The sheet's texture slides with it: down with the bottom edge, then on down with the top.
	_material.set_shader_parameter("slide", (bottom + top) * SCREEN_HEIGHT)


## Goo in the equipped skin's shades; with the rainbow skin, a random rainbow color each time.
func _paint() -> void:
	var progress := get_node_or_null("/root/Progress")
	var color: Color = Skins.get_preset(Skins.DEFAULT).color
	if progress:
		color = random_rainbow_color() if progress.is_rainbow() else progress.skin_color()
	var shades := Skins.shades(color)
	_material.set_shader_parameter("goo", shades.mid)
	_material.set_shader_parameter("goo_dark", shades.dark)
	_material.set_shader_parameter("goo_light", shades.light)
	_material.set_shader_parameter("goo_deep", shades.deep)
	_material.set_shader_parameter("goo_highlight", shades.highlight)


## A random color from the rainbow (red through violet).
static func random_rainbow_color() -> Color:
	return Color.from_hsv(randf() * 0.83, 0.78, 0.95)


## Each toast stays this long (s), the last NOTICE_FADE of it fading out.
const NOTICE_TIME := 2.5
const NOTICE_FADE := 0.3
## A toast that grants a cosmetic offers WEAR IT: it stays this long (s) and F / a tap on it equips the item.
const NOTICE_WEAR_TIME := 5.0
var _notice: Control
var _notice_left := 0.0
var _wore_msec := -1000  # (when F last wore a toast item: that press is spent, see interact_free)
var _notice_wear := ""  # (the cosmetic id the toast up now offers, "" = none)


## Whether a run is in progress in the current scene (the maze is being played: not finished, not the result).
func _run_in_progress() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == UIKit.GAME_SCENE and not bool(scene.get("finished"))


## Shows Progress.notices one at a time as a short toast at the top centre, inside the safe area, in the
## menus' goo panel (Progress.notify_once). Good news (an achievement, a medal reward) waits while a run is in
## progress (it shows on the result or in the hub) and several waiting achievements merge into "+3 ACHIEVEMENTS".
func _pump_notice(delta: float) -> void:
	if _notice != null:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left / NOTICE_FADE, 0.0, 1.0)
		if _notice_left <= 0.0:
			_notice.queue_free()
			_notice = null
			_notice_wear = ""
		return
	var progress := get_node_or_null("/root/Progress")
	if progress == null or progress.notices.is_empty():
		return
	var pick := -1
	for i in progress.notices.size():
		if progress.notice_groups.get(progress.notices[i], "") == "" or not _run_in_progress():
			pick = i
			break
	if pick < 0:
		return
	var text: String = progress.notices[pick]
	progress.notices.remove_at(pick)
	var group: String = progress.notice_groups.get(text, "")
	progress.notice_groups.erase(text)
	var wear: String = progress.notice_wear.get(text, "")
	progress.notice_wear.erase(text)
	if group == "ach":
		var merged := 1
		var rest: Array[String] = []
		for other in progress.notices:
			if progress.notice_groups.get(other, "") == "ach":
				merged += 1
				progress.notice_groups.erase(other)
			else:
				rest.append(other)
		if merged > 1:
			progress.notices.assign(rest)
			wear = ""  # (several at once: no single item to wear)
			# i18n: toast, max 150px, 1 line; {n} = how many achievements unlocked at once (2 or more)
			text = Loc.t("ach.toast_many", "+{n} ACHIEVEMENTS", {n = merged})
	var label := UIKit.make_label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = UIKit.autowrap_mode()
	var safe := UIKit.safe_rect()
	var w := minf(UIKit.text_w(text), safe.size.x - 2.0 * (UIKit.PANEL_PAD + UIKit.EDGE))
	label.custom_minimum_size = Vector2(w, 0)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.panel_style())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", UIKit.GAP_XS)
	column.add_child(label)
	if wear != "" and progress.owns_cosmetic(wear):
		var hint := UIKit.make_label(_wear_hint())
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(hint)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.gui_input.connect(_on_notice_input)
		_notice_wear = wear
	else:
		_notice_wear = ""
	box.add_child(column)
	add_child(box)
	box.reset_size()
	box.position = Vector2(roundf(safe.position.x + (safe.size.x - box.size.x) / 2.0), safe.position.y + UIKit.EDGE)
	_notice = box
	_notice_left = NOTICE_WEAR_TIME if _notice_wear != "" else NOTICE_TIME
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("coin", -14.0, 0.7)  # a short soft chime


## The second line of a toast that offers a cosmetic: the key (or a tap on the toast) wears it.
func _wear_hint() -> String:
	if UIKit.touch_active():
		return Loc.t("notice.wear_touch", "TAP: WEAR IT")  # i18n: toast action line, max 150px, 1 line; touch screens (tap the toast)
	var key := Platform.prompt_for("interact", Progress.key_name(Progress.bindings.interact))
	return Loc.t("notice.wear_key", "PRESS {key}: WEAR IT", {key = key})  # i18n: toast action line, max 150px, 1 line; {key} = the use key's name (e.g. F) or the pad button


## Equips the cosmetic the toast up offers (one save) and closes the offer. True when it was worn.
func wear_notice() -> bool:
	if _notice == null or _notice_wear == "":
		return false
	var id := _notice_wear
	_notice_wear = ""
	var progress := get_node_or_null("/root/Progress")
	if progress == null or not progress.equip_cosmetic(id):
		return false
	_notice_left = minf(_notice_left, 0.8)
	_wore_msec = Time.get_ticks_msec()  # (a tap wearing it is spent too: see wore_recently)
	if _notice != null:
		_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (worn: the box no longer eats taps meant for the hub)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("coin", -10.0, 1.0)
	return true


func _on_notice_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		wear_notice()


## True when a touch at `pos` (viewport pixels) is on a WEAR IT toast: it wears the item and the touch is spent
## (TouchControls then neither moves, leaps, uses nor glides on it).
func tap_toast(pos: Vector2) -> bool:
	if _notice == null or _notice_wear == "" or not _notice.get_global_rect().has_point(pos):
		return false
	wear_notice()
	return true


## True for 150 ms after a toast's item was worn (by key or tap): the hub ignores `tapped` / `jump` meanwhile.
func wore_recently() -> bool:
	return Time.get_ticks_msec() - _wore_msec <= 150


## True when F was just pressed and was not spent wearing a toast's item (the hub, the coach: the
## polled `interact` must not also use the station next to the slime).
func interact_free() -> bool:
	return Input.is_action_just_pressed("interact") and Time.get_ticks_msec() - _wore_msec > 150


func _input(event: InputEvent) -> void:
	if _notice_wear != "" and event.is_action_pressed("interact") and wear_notice():
		_wore_msec = Time.get_ticks_msec()
		get_viewport().set_input_as_handled()
