extends Node2D

## Hat audit (a throwaway diagnostic, not a test): renders contact sheets of every hat on every
## skin that matters, in every pose and animation frame, and saves each page as a 320x180 PNG.
## Pages: `lineup` (every hat x 7 poses, lime), `skins_<hat>` (10 skins x 7 poses),
## `frames_<hat>` (every frame of idle/glide/charge/launch/air/land/splat/celebrate/recover, lime),
## `anim_<hat>` (an animated hat's every frame, a row each, on lime / inkky / ember / rainbow x
## idle / glide / charge / land), `big` (2x, as on the title and skins screens), `rainbow_<n>` (the rainbow hat's flow over time),
## `wheel` (the hats as the hat wheel draws them: narrow, 1x, over its wedge colors),
## `squeezed` (every hat on the splat frames, 2x), and the real screens players see them on:
## `ui_wheel` (the hub's prize wheel), `ui_won` (just after a spin lands), `ui_shop` (the SHOP's
## DYES section: your dyeable hats), `ui_dyes` (one hat's colors, a dye focused on the try-on slimes),
## `ui_dyed` (the hub slime in a dyed hat), `ui_wardrobe` (the wardrobe's HATS page), `ui_hub` (the hub slime).
## ./tools/godot.sh --path . res://tests/demo_hat_audit.tscn -- --unlock-all --out=/abs/dir [--only=lineup,...]
## then: python3 -I tools/upscale_png.py OUT/lineup.png OUT/lineup_x4.png 4

const POSES := [
	["idle", 1, "IDLE"], ["glide_e", 0, "GLIDE"], ["charge_e", 3, "CHARGE"], ["launch_e", 0, "LAUNCH"],
	["air_e", 3, "AIR"], ["land_e", 0, "LAND"], ["splat_w", 0, "SPLAT"],
]
const FRAME_ANIMS := ["idle", "glide_e", "charge_e", "launch_e", "air_e", "land_e", "splat_e", "splat_w",
	"splat_n", "splat_s", "celebrate", "recover", "glide_n", "glide_s"]
const BG := Color8(34, 40, 58)
const BG_ALT := Color8(62, 58, 56)

var _out := "user://hat_audit"
var _only: Array[String] = []


func _skins() -> Array:
	# [label, color, rainbow, jelly, clock]
	return [
		["LIME", Skins.get_preset("lime").color, false, true, false],
		["OCEAN", Skins.get_preset("ocean").color, false, true, false],
		["GRAPE", Skins.get_preset("grape").color, false, true, false],
		["INKKY", Skins.get_preset("shadow").color, false, true, false],
		["FROST", Skins.get_preset("frost").color, false, true, false],
		["EMBER", Skins.get_preset("ember").color, false, true, false],
		["RAINB", Color8(236, 64, 76), true, true, false],
		["CUSTM", Color8(20, 170, 170), false, true, false],
		["SOLID", Skins.get_preset("lime").color, false, false, false],
		["CLOCK", Skins.STOPWATCH_BASE, false, true, true],
	]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			for p in arg.trim_prefix("--only=").split(","):
				_only.append(p)
	Hats.available = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await _page("lineup", _lineup)
	for id in Hats.ids():
		await _page("skins_" + id, _skins_page.bind(id))
		await _page("frames_" + id, _frames_page.bind(id))
	for id in Hats.ids():
		if Hats.frames(id) > 1:
			await _page("anim_" + id, _anim_page.bind(id))
	await _page("big", _big)
	await _page("wheel", _wheel)
	await _page("squeezed", _squeezed)
	await _ui_page("ui_wheel", _ui_wheel, 30)
	await _ui_page("ui_won", _ui_won, 4)
	await _ui_page("ui_shop", _ui_shop, 30)
	await _ui_page("ui_dyes", _ui_dyes, 30)
	await _ui_page("ui_dyed", _ui_dyed, 30)
	await _ui_page("ui_wardrobe", _ui_wardrobe, 30)
	await _ui_page("ui_hub", _ui_hub, 30)
	if _only.is_empty() or "rainbow" in _only:
		_clear()
		_rainbow()
		for n in 6:
			await _settle(9)
			_save("rainbow_%d" % n)
	get_tree().quit()


func _page(page_name: String, build: Callable) -> void:
	if not _only.is_empty() and not page_name in _only and not page_name.get_slice("_", 0) in _only:
		return
	_clear()
	build.call()
	await _settle(4)
	_save(page_name)


## A page built from a real screen, saved after `frames` frames (spins, tweens and fades settle).
func _ui_page(page_name: String, build: Callable, frames: int) -> void:
	if not _only.is_empty() and not page_name in _only and not "ui" in _only:
		return
	_clear()
	Progress.hats_owned.clear()
	Progress.selected_hat = "viking"
	Progress.spins = 3
	Progress.dev_tools = false  # a real player's wheel and prices (nothing is saved: a test run)
	Progress.tickets = 120
	seed(7)
	await build.call()
	await _settle(frames)
	_save(page_name)


func _clear() -> void:
	for child in get_children():
		child.free()


func _settle(count: int) -> void:
	for i in count:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(page_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(page_name + ".png"))
	print("saved ", page_name)


func _rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	add_child(r)


func _label(text: String, pos: Vector2, width := 32.0) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.modulate = Color(1, 1, 1, 0.55)
	add_child(l)


## One slime (frame pinned) wearing hat `id`, with its sprite's center at `pos`.
func _slime(pos: Vector2, id: String, anim: String, frame: int, skin: Array = [], scale := 1) -> void:
	if skin.is_empty():
		skin = _skins()[0]
	var preview := UIKit.make_slime_preview(skin[1], scale, skin[2], skin[3], skin[4])
	preview.position = pos
	add_child(preview)
	preview.animation = anim
	preview.frame = frame
	preview.pause()
	if id != Hats.NONE:
		var hat := Hat.new()
		hat.scale = Vector2(scale, scale)
		add_child(hat)
		hat.setup(id, preview)


func _lineup() -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var ids := Hats.ids()
	for r in POSES.size():
		if r % 2:
			_rect(Vector2(0, 4 + r * 25), Vector2(320, 25), BG_ALT)
		for c in ids.size():
			_slime(Vector2(15 + c * 29, 20 + r * 25), ids[c], POSES[r][0], POSES[r][1])


func _skins_page(id: String) -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var skins := _skins()
	for r in POSES.size():
		if r % 2:
			_rect(Vector2(0, 2 + r * 24), Vector2(320, 24), BG_ALT)
		for c in skins.size():
			_slime(Vector2(16 + c * 32, 17 + r * 24), id, POSES[r][0], POSES[r][1], skins[c])
	_label(id.to_upper(), Vector2(0, 170), 320)


func _frames_page(id: String) -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var frames := Slime.load_sprite_frames()
	var cells: Array = []
	for anim: String in FRAME_ANIMS:
		for f in frames.get_frame_count(anim):
			cells.append([anim, f])
	# 4 frames of an animation side by side; two animations per row (8 cells of 40 px).
	var col := 0
	var row := 0
	for cell: Array in cells:
		if col >= 8:
			col = 0
			row += 1
		if row % 2:
			_rect(Vector2(col * 40, 2 + row * 22), Vector2(40, 22), BG_ALT)
		_slime(Vector2(20 + col * 40, 16 + row * 22), id, cell[0], cell[1])
		col += 1
	_label(id.to_upper(), Vector2(0, 170), 320)


## Every frame of animated hat `id` (a row each) on four skins in four worn poses.
func _anim_page(id: String) -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var skins := [_skins()[0], _skins()[3], _skins()[5], _skins()[6]]
	var poses := [["idle", 1], ["glide_e", 0], ["charge_e", 3], ["land_e", 0]]
	var n := Hats.frames(id)
	var step := clampi(180 / n, 22, 40)
	for f in n:
		if f % 2:
			_rect(Vector2(0, f * step), Vector2(320, step), BG_ALT)
		for k in skins.size() * poses.size():
			_slime(Vector2(10 + k * 20, f * step + step - 9), id, poses[k % poses.size()][0], poses[k % poses.size()][1], skins[k / poses.size()])
			var hat := get_child(get_child_count() - 1) as Hat
			hat.set_process(false)
			hat.anim_frame = f
			hat._follow()


func _big() -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var ids := Hats.ids()
	for i in ids.size():
		var c := i % 6
		var r := i / 6
		_slime(Vector2(28 + c * 53, 52 + r * 80), ids[i], "idle", 1, _skins()[i % 8], 2)


func _wheel() -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var atlas: Texture2D = preload("res://assets/sprites/hats.png")
	var ids := Hats.ids()
	for i in ids.size():
		for k in HatWheel.WEDGE_COLORS.size():
			var at := Vector2(4 + i * 28, 4 + k * 28)
			_rect(at, Vector2(28, 28), HatWheel.WEDGE_COLORS[k])
			var s := Sprite2D.new()
			s.texture = atlas
			s.region_enabled = true
			s.region_rect = Hats.region(ids[i], Hats.Width.NARROW)
			s.centered = false
			s.position = at + Vector2(14, 14) - Vector2(Hats.FRAME) / 2.0
			add_child(s)


func _squeezed() -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	var ids := Hats.ids()
	var cells := [["splat_e", 0], ["splat_e", 1], ["splat_e", 2], ["splat_w", 2]]
	for k in cells.size():
		if k % 2:
			_rect(Vector2(0, 2 + k * 44), Vector2(320, 44), BG_ALT)
		for i in ids.size():
			_slime(Vector2(15 + i * 29, 26 + k * 44), ids[i], cells[k][0], cells[k][1], [], 2)


func _hub() -> Node:
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	return hub


func _ui_wheel() -> void:
	var hub := _hub()
	hub.open_hat_wheel.call_deferred()


func _ui_won() -> void:
	var hub := _hub()
	await get_tree().process_frame
	hub.open_hat_wheel()
	hub.hat_wheel.spin()
	await hub.hat_wheel.landed
	await get_tree().create_timer(0.6).timeout


func _ui_shop() -> void:
	var hub := _hub()
	await get_tree().process_frame
	hub.open_hat_wheel()
	hub.hat_wheel.show_tab("shop")
	hub.hat_wheel.show_section("hats")


## A player with five hats (four dyeable), two dyes for the propeller cap (wearing rainbow).
func _dyed_player() -> void:
	Progress.hats_owned.assign(["tophat", "beanie", "propeller", "wizard", "crown"])
	Progress.hat_dyes_owned.assign(["propeller:teal", "propeller:rainbow", "wizard:butter"])
	Progress.hat_dyes = {"propeller": "rainbow"}
	Progress.selected_hat = "propeller"
	Progress.tickets = 34


func _ui_dyes() -> void:
	_dyed_player()
	var hub := _hub()
	await get_tree().process_frame
	hub.open_hat_wheel()
	var wheel: Control = hub.hat_wheel
	wheel.show_tab("shop")
	wheel.shop_tiles["wizard"].pressed.emit()
	await get_tree().process_frame
	wheel.shop_tiles["wizard:prism"].grab_focus()


func _ui_dyed() -> void:
	_dyed_player()
	_hub()


func _ui_wardrobe() -> void:
	for id in Hats.ids():
		if id != "crown":
			Progress.hats_owned.append(id)
	var layer := CanvasLayer.new()  # (so the screen fills the window, as it does in the game)
	add_child(layer)
	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	layer.add_child(screen)
	screen.show_page.call_deferred("hats")


func _ui_hub() -> void:
	_hub()


func _rainbow() -> void:
	_rect(Vector2.ZERO, Vector2(320, 180), BG)
	_slime(Vector2(60, 100), "rainbow", "idle", 1, _skins()[0], 4)
	_slime(Vector2(160, 100), "rainbow", "idle", 1, _skins()[3], 4)
	_slime(Vector2(260, 100), "rainbow", "idle", 1, _skins()[6], 4)
