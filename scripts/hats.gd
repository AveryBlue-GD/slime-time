class_name Hats
extends RefCounted

## Hats: won on the hat wheel in the hub (a spin lands on a random hat you don't have yet, and
## won hats come off the wheel; Progress.hats_owned), then picked on the Skins screen's hats page
## (Progress.selected_hat). A spin costs 12 globs (the first is free; Progress.spin_hat), but the wheel stays dev-only
## while Hats.available is false.
## Sprites are 32x16 frames in assets/sprites/hats.png (tools/make_hats.py), `column` = which
## frame. The Hat node (scripts/hat.gd) puts the chosen one on the slime and handles its physics.
##
## These are placeholders until the real hats are decided.

## Hats are still placeholders, so for now they show "COMING SOON" and can't be worn (except in
## dev mode). Set to true once the real hats are in.
static var available := false

## How much each missed spin fattens the rainbow hat's wedge.
const PITY_STEP := 0.15
const NONE := "none"
const NONE_NAME := "NO HAT"
## Each hat is drawn at three widths (rows of hats.png) to fit the slime as it squashes and
## stretches: NARROW (stretched into a leap), NORMAL, WIDE (squashed to charge or land).
const FRAME := Vector2i(32, 16)
## Where the top of the slime's head goes in a frame: the hats reach down round the dome below it.
const HEAD := Vector2(16, 11)
enum Width { NARROW, NORMAL, WIDE }

const LIST := [
	{id = "tophat", name = "TOP HAT", column = 0},
	{id = "beanie", name = "BEANIE", column = 1},
	{id = "party", name = "PARTY HAT", column = 2},
	{id = "cap", name = "BASEBALL CAP", column = 3},
	{id = "cowboy", name = "COWBOY HAT", column = 4},
	{id = "chef", name = "CHEF HAT", column = 5},
	{id = "wizard", name = "WIZARD HAT", column = 6},
	{id = "viking", name = "VIKING HELMET", column = 7},
	{id = "propeller", name = "PROPELLER CAP", column = 8},
	{id = "crown", name = "CROWN", column = 9},
	# The rare one: a thin wedge on the wheel, and its colors flow (assets/shaders/rainbow_hat.gdshader).
	{id = "rainbow", name = "RAINBOW HAT", column = 10, weight = 0.3, flows = true},
]


## How likely the hat wheel is to land on a hat, next to an ordinary hat's 1 (its wedge's share).
## `pity` = spins that missed the rainbow hat since it was last rolled: each one makes the
## flowing (rainbow) hat's wedge a bit fatter (PITY_STEP).
static func weight(id: String, pity := 0) -> float:
	var hat := get_hat(id)
	var w := float(hat.get("weight", 1.0))
	if hat.get("flows", false):
		w += pity * PITY_STEP
	return w


## The hat a spin lands on: `roll` (0-1) walked along the hats' weights, in order.
static func pick(ids: Array, pity: int, roll: float) -> String:
	if ids.is_empty():
		return ""
	var total := 0.0
	for id: String in ids:
		total += weight(id, pity)
	var at := clampf(roll, 0.0, 0.999999) * total
	for id: String in ids:
		at -= weight(id, pity)
		if at < 0.0:
			return id
	return ids[-1]


## The material a hat sprite wears: the flowing-rainbow shader for the rainbow hat, else none.
static func material_for(id: String) -> Material:
	if not get_hat(id).get("flows", false):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/rainbow_hat.gdshader")
	return mat


static func get_hat(id: String) -> Dictionary:
	for hat: Dictionary in LIST:
		if hat.id == id:
			return hat
	return {}


static func display_name(id: String) -> String:
	return NONE_NAME if id == NONE else get_hat(id).get("name", "")


## A hat can be worn once it's been won on the hat wheel (`owned`), and only once hats are out.
static func is_unlocked(id: String, owned: Array) -> bool:
	return id == NONE or (available and not get_hat(id).is_empty() and id in owned)


## Every hat id, in wheel order.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for hat: Dictionary in LIST:
		out.append(hat.id)
	return out


## The hat's frame within hats.png, at one of its widths.
static func region(id: String, width := Width.NORMAL) -> Rect2:
	return Rect2(Vector2(int(get_hat(id).get("column", 0)) * FRAME.x, width * FRAME.y), Vector2(FRAME))


## Which width of hat fits a slime head `head_width` px across (Slime.head_width).
static func width_for(head_width: int) -> int:
	if head_width <= 12:
		return Width.NARROW
	if head_width >= 16:
		return Width.WIDE
	return Width.NORMAL
