extends Node

## Autoload "Progress": levels cleared/unlocked, the chosen skin, key bindings, and which
## mode the game scene should start in. Saved to user://save.cfg.
## Debug (after `--` on the command line, never saved): `--level=N` starts on level N,
## `--unlock-all` unlocks every level and skin, `--skin=ID` picks a skin, `--random` plays randomizer mazes.

const MODE_STORY := "story"
const MODE_RANDOM := "random"

## Remappable actions and their default (primary) keys. Movement also keeps the arrow keys
## as fixed secondary keys, so the game stays playable whatever gets remapped.
const DEFAULT_KEYS := {
	move_up = KEY_W, move_down = KEY_S, move_left = KEY_A, move_right = KEY_D,
	jump = KEY_SPACE, restart = KEY_R,
}
const SECONDARY_KEYS := {move_up = KEY_UP, move_down = KEY_DOWN, move_left = KEY_LEFT, move_right = KEY_RIGHT}

var save_path := "user://save.cfg"
## Highest level the player may start (1-10).
var highest_unlocked := 1
## Number of story levels beaten so far (0-10). Also decides which skins are unlocked.
var levels_cleared := 0
## Story level the game scene loads next.
var current_level := 1

var selected_skin := Skins.DEFAULT
var custom_color := Color8(239, 125, 47)
## Glow strength for the custom skin, 0-1.
var glow := 0.6
var sound_on := true
## Master volume, 0-1 (applied to the Master audio bus).
var volume := 0.8
## action -> physical keycode of its primary key.
var bindings := DEFAULT_KEYS.duplicate()

## Not saved: what "play" means right now.
var mode := MODE_STORY
var random_seed := 1
var randoms_cleared := 0
## Randomizer mazes beaten in total (saved); unlocks the rainbow skin.
var randoms_won := 0
## Set by debug flags so a test session never overwrites the real save.
var saving_enabled := true


func _ready() -> void:
	load_progress()
	apply_bindings()
	apply_volume()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			current_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levels.COUNT)
		elif arg == "--unlock-all":
			saving_enabled = false
			levels_cleared = Levels.COUNT
			highest_unlocked = Levels.COUNT
			randoms_won = maxi(randoms_won, Skins.RAINBOW_RANDOMS)
		elif arg == "--random":
			start_random()
		elif arg.begins_with("--skin="):
			saving_enabled = false
			selected_skin = arg.trim_prefix("--skin=")


func load_progress() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	levels_cleared = clampi(file.get_value("progress", "levels_cleared", 0), 0, Levels.COUNT)
	highest_unlocked = clampi(file.get_value("progress", "highest_unlocked", 1), 1, Levels.COUNT)
	current_level = clampi(file.get_value("progress", "current_level", 1), 1, highest_unlocked)
	randoms_won = maxi(file.get_value("progress", "randoms_won", 0), 0)
	selected_skin = file.get_value("skin", "selected", Skins.DEFAULT)
	custom_color = file.get_value("skin", "custom_color", custom_color)
	glow = clampf(file.get_value("skin", "glow", glow), 0.0, 1.0)
	sound_on = file.get_value("settings", "sound_on", true)
	volume = clampf(file.get_value("settings", "volume", volume), 0.0, 1.0)
	for action: String in DEFAULT_KEYS:
		bindings[action] = int(file.get_value("controls", action, DEFAULT_KEYS[action]))


func save_progress() -> void:
	if not saving_enabled:
		return
	var file := ConfigFile.new()
	file.set_value("progress", "levels_cleared", levels_cleared)
	file.set_value("progress", "highest_unlocked", highest_unlocked)
	file.set_value("progress", "current_level", current_level)
	file.set_value("progress", "randoms_won", randoms_won)
	file.set_value("skin", "selected", selected_skin)
	file.set_value("skin", "custom_color", custom_color)
	file.set_value("skin", "glow", glow)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "volume", volume)
	for action: String in bindings:
		file.set_value("controls", action, bindings[action])
	file.save(save_path)


## Records a story win and picks the next level (back to 1 after beating the last one).
func complete_level(level: int) -> void:
	levels_cleared = maxi(levels_cleared, level)
	highest_unlocked = maxi(highest_unlocked, mini(level + 1, Levels.COUNT))
	current_level = level + 1 if level < Levels.COUNT else 1
	save_progress()


func start_story(level: int) -> void:
	mode = MODE_STORY
	current_level = clampi(level, 1, highest_unlocked)


## Records a randomizer win (saved) and lines up a fresh maze.
func complete_random() -> void:
	randoms_cleared += 1
	randoms_won += 1
	save_progress()
	new_random_maze()


func start_random() -> void:
	mode = MODE_RANDOM
	new_random_maze()


func new_random_maze() -> void:
	random_seed = randi_range(1, 2_000_000_000)


# ---------------------------------------------------------------- skins

func is_skin_unlocked(id: String) -> bool:
	return Skins.is_unlocked(id, levels_cleared, randoms_won)


## True when the rainbow skin is selected (and unlocked).
func is_rainbow() -> bool:
	return selected_skin == Skins.RAINBOW and is_skin_unlocked(Skins.RAINBOW)


func skin_color() -> Color:
	if not is_skin_unlocked(selected_skin):
		return Skins.get_preset(Skins.DEFAULT).color
	if selected_skin == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if selected_skin == Skins.CUSTOM:
		return custom_color
	return Skins.get_preset(selected_skin).color


## Glow strength in play: only the custom skin glows, and only once the game is beaten.
func glow_amount() -> float:
	if selected_skin == Skins.CUSTOM and is_skin_unlocked(Skins.CUSTOM):
		return glow
	return 0.0


func select_skin(id: String) -> void:
	if is_skin_unlocked(id):
		selected_skin = id
		save_progress()


# ---------------------------------------------------------------- sound

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_progress()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


# ---------------------------------------------------------------- controls

## Binds `keycode` as the primary key for `action`. If another action used that key, the two
## swap keys so no key is ever bound twice.
func set_binding(action: String, keycode: int) -> void:
	for other: String in bindings:
		if other != action and bindings[other] == keycode:
			bindings[other] = bindings[action]
	bindings[action] = keycode
	apply_bindings()
	save_progress()


func reset_bindings() -> void:
	bindings = DEFAULT_KEYS.duplicate()
	apply_bindings()
	save_progress()


func apply_bindings() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _key_event(bindings[action]))
		var secondary: int = SECONDARY_KEYS.get(action, 0)
		if secondary != 0 and secondary != bindings[action]:
			InputMap.action_add_event(action, _key_event(secondary))


static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode).to_upper()


static func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event
