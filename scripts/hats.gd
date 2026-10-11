class_name Hats
extends RefCounted

## Hats: a reward for playing randomizer mazes. Each unlocks after `wins` randomizer wins and is
## picked on the Skins screen's hats page (Progress.selected_hat). Sprites are 16x12 frames in
## assets/sprites/hats.png (tools/make_hats.py), `column` = which frame. The Hat node
## (scripts/hat.gd) puts the chosen one on the slime and handles its physics.
##
## These ten are placeholders until the real hats are decided; each needs more randomizer wins
## than the last, so there's always another one to chase.

## Hats are still placeholders, so for now they show "COMING SOON" and can't be worn (except in
## dev mode). Set to true once the real hats are in.
static var available := false

const NONE := "none"
const NONE_NAME := "NO HAT"
const FRAME := Vector2i(16, 12)

const LIST := [
	{id = "tophat", name = "TOP HAT", wins = 1, column = 0},
	{id = "beanie", name = "BEANIE", wins = 2, column = 1},
	{id = "party", name = "PARTY HAT", wins = 3, column = 2},
	{id = "cap", name = "BASEBALL CAP", wins = 5, column = 3},
	{id = "cowboy", name = "COWBOY HAT", wins = 7, column = 4},
	{id = "chef", name = "CHEF HAT", wins = 10, column = 5},
	{id = "wizard", name = "WIZARD HAT", wins = 13, column = 6},
	{id = "viking", name = "VIKING HELMET", wins = 16, column = 7},
	{id = "propeller", name = "PROPELLER CAP", wins = 20, column = 8},
	{id = "crown", name = "CROWN", wins = 25, column = 9},
]


static func get_hat(id: String) -> Dictionary:
	for hat: Dictionary in LIST:
		if hat.id == id:
			return hat
	return {}


static func display_name(id: String) -> String:
	return NONE_NAME if id == NONE else get_hat(id).get("name", "")


## Randomizer wins needed for a hat (0 for no hat).
static func wins_needed(id: String) -> int:
	return int(get_hat(id).get("wins", 0))


static func is_unlocked(id: String, randoms_won: int) -> bool:
	return id == NONE or (available and not get_hat(id).is_empty() and randoms_won >= wins_needed(id))


## The hat's frame within hats.png.
static func region(id: String) -> Rect2:
	return Rect2(Vector2(int(get_hat(id).get("column", 0)) * FRAME.x, 0), Vector2(FRAME))
