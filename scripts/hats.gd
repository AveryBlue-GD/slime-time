class_name Hats
extends RefCounted

## Hats: won on the hat wheel in the hub (a spin lands on a random hat you don't have yet, and
## won hats come off the wheel; Progress.hats_owned), then picked on the Skins screen's hats page
## (Progress.selected_hat). The first spin is free, then 12 tickets rising by 2 per spin (Progress.spin_hat).
## Hats are never sold: the wheel's SHOP sells DYES instead (Economy.DYE_PRICE tickets each): the
## `dyeable` hats in another color (DYES), drawn in assets/sprites/hat_dyes.png (dye_region). Each
## dyeable hat skips the dye nearest its own color (`own`). Progress.hat_dye says which one is worn.
## Sprites are 32x16 frames in assets/sprites/hats.png (tools/make_hats.py), `column` = which
## frame. An animated hat (`frames` > 1: the propeller cap, the raincloud) has its first frame
## there (its still frame, as on the hat wheel's wedges) and the others after every hat's column
## (anim_column), played at `fps` (`fps_moving` while the slime glides or charges, `fps_flying`
## popped off by a leap; both default to `fps`). The Hat node (scripts/hat.gd) puts the chosen one on the slime and handles its physics.
##
## These are placeholders until the real hats are decided.

## Hats are out for every player (upgrades v2 batch 2). The switch stays so a test (or a future
## content gap) can turn the wheel back off: false = no spins and no hats worn outside dev mode.
static var available := true

## How much each missed spin fattens the rainbow hat's wedge.
const PITY_STEP := 0.15
const NONE := "none"
const NONE_NAME := "NO HAT"  # i18n: ignore (English source; shown via display_name)
## Each hat is drawn at five fitted widths (rows of hats.png) to fit the slime as it squashes and
## stretches (NARROW: stretched into a leap; NORMAL; BROAD: a little squashed; WIDE: squashed flat
## to charge or land; SQUEEZED: pressed sideways against a wall in a splat), plus LOOSE, its own
## shape off the head (popped off by a leap, or on the hat wheel). tools/make_hats.py fits them to
## the head widths width_for maps them from.
const FRAME := Vector2i(32, 16)
## Where the top of the slime's head goes in a frame: the hats reach down round the dome below it.
const HEAD := Vector2(16, 11)
enum Width { NARROW, NORMAL, WIDE, SQUEEZED, BROAD, LOOSE }
## Most a hat is ever lifted off the head to clear the eyes (lift).
const MAX_LIFT := 3
static var _lifts := {}
static var _image: Image
## The flowing hat's hue turn, as in assets/shaders/rainbow_hat.gdshader (its speed and steps).
const FLOW_SPEED := 0.35
const FLOW_STEPS := 12
static var _flow_frames := {}

const LIST := [
	{id = "tophat", name = "TOP HAT", column = 0, dyeable = true, own = "midnight"},  # i18n: ignore (English source; shown via display_name)
	{id = "beanie", name = "BEANIE", column = 1, dyeable = true, own = "cherry"},  # i18n: ignore (English source; shown via display_name)
	{id = "party", name = "PARTY HAT", column = 2},  # i18n: ignore (English source; shown via display_name)
	{id = "cap", name = "BASEBALL CAP", column = 3, dyeable = true, own = "cobalt"},  # i18n: ignore (English source; shown via display_name)
	{id = "cowboy", name = "COWBOY HAT", column = 4, dyeable = true},  # i18n: ignore (English source; shown via display_name)
	{id = "chef", name = "CHEF HAT", column = 5, dyeable = true, own = "snow"},  # i18n: ignore (English source; shown via display_name)
	{id = "wizard", name = "WIZARD HAT", column = 6, dyeable = true, own = "plum"},  # i18n: ignore (English source; shown via display_name)
	{id = "viking", name = "VIKING HELMET", column = 7, dyeable = true, own = "butter"},  # (a dye colors its rim)  # i18n: ignore (English source; shown via display_name)
	# Its propeller spins (frames, see Hat._animate): lazily at rest, faster on the move, fastest flying off in a leap.
	# A dye colors the propeller (both blades).
	{id = "propeller", name = "PROPELLER CAP", column = 8, frames = 8, fps = 8.0, fps_moving = 16.0, fps_flying = 24.0, dyeable = true},  # i18n: ignore (English source; shown via display_name)
	{id = "crown", name = "CROWN", column = 9},  # i18n: ignore (English source; shown via display_name)
	# A little cloud hovering over the head (`hovers`: it never touches it), raining on it.
	{id = "raincloud", name = "RAINCLOUD", column = 11, frames = 4, fps = 10.0, hovers = true, dyeable = true},  # i18n: ignore (English source; shown via display_name)
	# The rare one: a thin wedge on the wheel, and its colors flow (assets/shaders/rainbow_hat.gdshader).
	# A dye colors its two clouds (marked in hat_dyes.png so the shader leaves them as drawn).
	{id = "rainbow", name = "RAINBOW HAT", column = 10, flows = true, dyeable = true, own = "snow"},  # i18n: ignore (English source; shown via display_name)
]

## Hat dyes, in hat_dyes.png's block order (tools/make_hats.py DYES: the same ids, same order).
## `color` is the swatch shown in the SHOP.
const DYES := [
	{id = "cherry", color = Color8(206, 52, 62)},
	{id = "tangerine", color = Color8(232, 128, 48)},
	{id = "butter", color = Color8(240, 204, 76)},
	{id = "clover", color = Color8(72, 168, 84)},
	{id = "teal", color = Color8(44, 156, 156)},
	{id = "cobalt", color = Color8(62, 110, 214)},
	{id = "plum", color = Color8(124, 78, 196)},
	{id = "bubblegum", color = Color8(236, 120, 176)},
	{id = "midnight", color = Color8(52, 50, 72)},
	{id = "snow", color = Color8(232, 232, 240)},
	# Its colors flow (rainbow_hat.gdshader, material_for); Economy.DYE_RAINBOW_PRICE.
	{id = "rainbow", color = Color8(222, 62, 70), flows = true},
]
## The RAINBOW dye's look: false = the dyed part turns through the colors as one (like the rainbow
## hat's arch), true = a rainbow gradient flowing across it (like the rainbow jelly skin).
static var RAINBOW_GRADIENT := false
## A dye block's height in hat_dyes.png: every width's row (Width), like hats.png.
const DYE_BLOCK := 6 * 16


## Whether hat `id` comes in dyes.
static func is_dyeable(id: String) -> bool:
	return get_hat(id).get("dyeable", false)


## The dyes hat `id` comes in (none for a hat that isn't dyeable): every dye but its own color's.
static func dyes_for(id: String) -> Array[String]:
	var out: Array[String] = []
	if is_dyeable(id):
		for dye: Dictionary in DYES:
			if dye.id != get_hat(id).get("own", ""):
				out.append(dye.id)
	return out


## The block of dye `dye` in hat_dyes.png (-1: not a dye).
static func dye_index(dye: String) -> int:
	for i in DYES.size():
		if DYES[i].id == dye:
			return i
	return -1


static func dye_color(dye: String) -> Color:
	var i := dye_index(dye)
	return DYES[i].color if i >= 0 else Color.WHITE


static func dye_name(dye: String) -> String:
	# i18n: hat dye (a color) name, max 64px, 1 line; the SHOP's DYES tiles
	match dye:
		"cherry":
			return Loc.t("dye.cherry", "CHERRY")
		"tangerine":
			return Loc.t("dye.tangerine", "TANGERINE")
		"butter":
			return Loc.t("dye.butter", "BUTTER")
		"clover":
			return Loc.t("dye.clover", "CLOVER")
		"teal":
			return Loc.t("dye.teal", "TEAL")
		"cobalt":
			return Loc.t("dye.cobalt", "COBALT")
		"plum":
			return Loc.t("dye.plum", "PLUM")
		"bubblegum":
			return Loc.t("dye.bubblegum", "BUBBLEGUM")
		"midnight":
			return Loc.t("dye.midnight", "MIDNIGHT")
		"snow":
			return Loc.t("dye.snow", "SNOW")
		"rainbow":
			return Loc.t("dye.rainbow", "RAINBOW")
	# i18n: a dyeable hat in its own color (no dye), max 64px, 1 line; the SHOP's DYES tiles
	return Loc.t("dye.original", "ORIGINAL")


## The sheet hat `id` is drawn from in dye `dye` ("" or a dye it doesn't come in: hats.png).
static func texture_for(id: String, dye := "") -> Texture2D:
	if dye != "" and dye in dyes_for(id):
		return preload("res://assets/sprites/hat_dyes.png")
	return preload("res://assets/sprites/hats.png")


## region() in the sheet texture_for(id, dye) gives: hat_dyes.png's block for the dye.
static func dye_region(id: String, dye: String, width := Width.NORMAL, frame := 0) -> Rect2:
	var r := region(id, width, frame)
	if dye != "" and dye in dyes_for(id):
		r.position.y += dye_index(dye) * DYE_BLOCK
	return r


## Whether dye `dye`'s colors flow (the RAINBOW dye).
static func dye_flows(dye: String) -> bool:
	var i := dye_index(dye)
	return i >= 0 and DYES[i].get("flows", false)


## The material a hat sprite wears: the flowing-rainbow shader for the rainbow hat or a hat in the
## RAINBOW dye, else none.
static func material_for(id: String, dye := "") -> Material:
	if not get_hat(id).get("flows", false) and not (dye_flows(dye) and dye in dyes_for(id)):
		return null
	return flow_material(RAINBOW_GRADIENT and not get_hat(id).get("flows", false))


## The flowing-rainbow shader (assets/shaders/rainbow_hat.gdshader) as a new material; `gradient`:
## a rainbow running across the pixels and flowing (like the rainbow jelly skin) instead of the
## whole thing turning one color at a time (RAINBOW_GRADIENT picks the RAINBOW dye's look).
static func flow_material(gradient := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/rainbow_hat.gdshader")
	mat.set_shader_parameter("gradient", gradient)
	return mat


## A fixed step for the reviewer captures (tests/capture_i18n.gd; -1: the clock's). The clock's step
## makes a new texture whenever it turns, so a capture run's later RIDs (GooBox lumps) depended on timing.
static var frozen_flow_step := -1


## Which of the FLOW_STEPS hue turns the flowing hat shows now (the shader's, from the clock).
static func flow_step() -> int:
	if frozen_flow_step >= 0:
		return frozen_flow_step
	return int(floor(Time.get_ticks_msec() / 1000.0 * FLOW_SPEED * FLOW_STEPS)) % FLOW_STEPS


## Hat `id` at `width`, its colors turned `step` hue steps like rainbow_hat.gdshader does (every
## colorful pixel; whites, greys and the outline as drawn): for places that draw a hat without its
## shader (the hat wheel's wedges). Made once per frame and step.
static func flow_texture(id: String, width: int, step: int) -> Texture2D:
	var key := "%s:%d:%d" % [id, width, step]
	if _flow_frames.has(key):
		return _flow_frames[key]
	if _image == null:
		_image = preload("res://assets/sprites/hats.png").get_image()
		if _image.is_compressed():
			_image.decompress()
	var frame := _image.get_region(Rect2i(region(id, width)))
	frame.convert(Image.FORMAT_RGBA8)
	for y in frame.get_height():
		for x in frame.get_width():
			var c := frame.get_pixel(x, y)
			if c.a > 0.0 and c.s > 0.4 and c.v > 0.3:
				frame.set_pixel(x, y, Color.from_hsv(fposmod(c.h - float(step) / FLOW_STEPS, 1.0), c.s, c.v, c.a))
	var texture := ImageTexture.create_from_image(frame)
	_flow_frames[key] = texture
	return texture


static func get_hat(id: String) -> Dictionary:
	for hat: Dictionary in LIST:
		if hat.id == id:
			return hat
	return {}


static func display_name(id: String) -> String:
	# i18n: hat name, max 100px, 1 line; hat wheel and wardrobe
	match id:
		"none":
			return Loc.t("hat.none", "NO HAT")
		"tophat":
			return Loc.t("hat.tophat", "TOP HAT")
		"beanie":
			return Loc.t("hat.beanie", "BEANIE")
		"party":
			return Loc.t("hat.party", "PARTY HAT")
		"cap":
			return Loc.t("hat.cap", "BASEBALL CAP")
		"cowboy":
			return Loc.t("hat.cowboy", "COWBOY HAT")
		"chef":
			return Loc.t("hat.chef", "CHEF HAT")
		"wizard":
			return Loc.t("hat.wizard", "WIZARD HAT")
		"viking":
			return Loc.t("hat.viking", "VIKING HELMET")
		"propeller":
			return Loc.t("hat.propeller", "PROPELLER CAP")
		"crown":
			return Loc.t("hat.crown", "CROWN")
		"rainbow":
			return Loc.t("hat.rainbow", "RAINBOW HAT")
		"raincloud":
			return Loc.t("hat.raincloud", "RAINCLOUD")
	return get_hat(id).get("name", "")


## A hat's one-line flavor text ("" for hats without one), like Cosmetics.about.
static func about(id: String) -> String:
	# i18n: wardrobe / hat wheel info line, after the hat's name; max 150px, 1 line, keep it short
	match id:
		"raincloud":
			return Loc.t("hat.raincloud.desc", "ITS VERY OWN DRIZZLE")
	return ""


## A hat can be worn once it's been won on the hat wheel (`owned`), and only once hats are out.
static func is_unlocked(id: String, owned: Array) -> bool:
	return id == NONE or (available and not get_hat(id).is_empty() and id in owned)


## Every hat id, in wheel order.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for hat: Dictionary in LIST:
		out.append(hat.id)
	return out


## The hat's frame within hats.png, at one of its widths (`frame`: which frame of an animated hat,
## wrapped round; 0 = its still frame).
static func region(id: String, width := Width.NORMAL, frame := 0) -> Rect2:
	var hat := get_hat(id)
	var column := int(hat.get("column", 0))
	var n := frames(id)
	if n > 1 and posmod(frame, n) > 0:
		column = anim_column(id) + posmod(frame, n) - 1
	return Rect2(Vector2(column * FRAME.x, width * FRAME.y), Vector2(FRAME))


## How many frames hat `id` has (1: a still hat).
static func frames(id: String) -> int:
	return maxi(1, int(get_hat(id).get("frames", 1)))


## The column of hat `id`'s second frame: the animated hats' other frames follow every hat's own
## column, hat by hat in column order (tools/make_hats.py columns(); the raincloud's column comes
## after the rainbow hat's, though the rainbow hat stays last in LIST, so last on the wheel).
static func anim_column(id: String) -> int:
	var by_column := LIST.duplicate()
	by_column.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.column) < int(b.column))
	var column := LIST.size()
	for hat: Dictionary in by_column:
		if hat.id == id:
			return column
		column += maxi(1, int(hat.get("frames", 1))) - 1
	return column


## Every column of hats.png: a frame per hat, then the animated hats' other frames.
static func sheet_columns() -> int:
	var columns := 0
	for hat: Dictionary in LIST:
		columns += maxi(1, int(hat.get("frames", 1)))
	return columns


## How fast hat `id` animates (frames a second): `fps`, or `fps_moving` / `fps_flying` when the
## slime is on the move / the hat is flying off it.
static func fps(id: String, moving := false, flying := false) -> float:
	var hat := get_hat(id)
	var base := float(hat.get("fps", 8.0))
	if flying:
		return float(hat.get("fps_flying", hat.get("fps_moving", base)))
	if moving:
		return float(hat.get("fps_moving", base))
	return base


## How many px to lift hat `id` (at `width`) off the head in slime frame anim:frame so it doesn't
## cover the eyes: 0 almost always; 1-3 in the few frames whose eyes sit high (charging, and
## facing away diagonally). Worked out from the sprite sheets once per hat and frame.
static func lift(id: String, width: int, anim: String, frame: int) -> int:
	var key := "%s:%d:%s:%d" % [id, width, anim, frame]
	if _lifts.has(key):
		return _lifts[key]
	var eyes := Slime.eye_points(anim, frame)
	var lifted := 0
	if not eyes.is_empty():
		if _image == null:
			_image = preload("res://assets/sprites/hats.png").get_image()
			if _image.is_compressed():
				_image.decompress()
		for k in MAX_LIFT + 1:
			lifted = k
			var clear := true
			for f in frames(id):  # (every frame of an animated hat: it lifts the same through all)
				var r := region(id, width, f)
				for e: Vector2i in eyes:
					# The hat pixel that would land on this eye, with the hat raised k px.
					var at := Vector2i(r.position) + Vector2i(HEAD) + e + Vector2i(0, k)
					if at.y < int(r.position.y) + FRAME.y and _image.get_pixelv(at).a > 0.5:
						clear = false
						break
			if clear:
				break
	_lifts[key] = lifted
	return lifted


## Which width of hat fits a slime head `head_width` px across (Slime.head_width).
## (tools/make_hats.py WIDTH_CLASSES uses the same bands.)
static func width_for(head_width: int) -> int:
	if head_width <= 11:
		return Width.SQUEEZED
	if head_width <= 12:
		return Width.NARROW
	if head_width <= 14:
		return Width.NORMAL
	if head_width <= 16:
		return Width.BROAD
	return Width.WIDE
