class_name DevLog
extends RefCounted
## DEV-ONLY diagnostics: when dev mode is on (Progress.dev_tools, i.e. --unlock-all / tools/play.sh --dev)
## one line per event is appended to a text file in user://. Inert otherwise (and always on the web):
## no file is made, nothing is saved, gameplay is untouched. The file is truncated at each launch
## (the first write of the process) and stops growing at MAX_BYTES.
## Path: `user://dev_attempts.log` for the owner's play.sh --dev launch; any test / headless / movie /
## screenshot run writes `user://dev_attempts_<pid>.log` instead, so it never clobbers a running game's log.
## macOS: ~/Library/Application Support/SlimeTime_R1/dev_attempts.log (the release user dir, project.godot)

const MAX_BYTES := 200_000
const PLAIN_PATH := "user://dev_attempts.log"

## The restart route last taken, shown on the next "maze built" line (then cleared).
static var last_route := ""
## Tests set these (path "" = pick automatically; dev null = ask Progress).
static var path_override := ""
static var _started := false
static var _bytes := 0


## Appends "<ms> <event> | <state> | <extra>" if dev mode is on. `game` (a Game node) may be null.
static func log_event(tree: SceneTree, event: String, game: Node = null, extra := "") -> void:
	if OS.has_feature("web") or tree == null:
		return
	var progress := tree.root.get_node_or_null("Progress")
	if progress == null or not progress.dev_tools:
		return
	var line := "%d %s | %s" % [Time.get_ticks_msec(), event, _state(game, progress)]
	if extra != "":
		line += " | " + extra
	_append(line + "\n")


## Remembers the route taken (reported by the next maze built) and logs it.
static func route(tree: SceneTree, name: String, game: Node = null) -> void:
	last_route = name
	log_event(tree, "restart: " + name, game)


static func log_path() -> String:
	if path_override != "":
		return path_override
	return PLAIN_PATH if _is_owner_launch() else "user://dev_attempts_%d.log" % OS.get_process_id()


## True for a hand-played launch (windowed, no test / tool / movie arguments).
static func _is_owner_launch() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg in ["-s", "--script", "--headless", "--write-movie", "--quit", "--quit-after", "--fixed-fps",
				"--import", "--check-only", "--doctor"] or arg.begins_with("--write-movie=") \
				or arg.begins_with("--script=") or arg.begins_with("res://tests/") \
				or arg.begins_with("res://tools/") or arg.ends_with(".gd"):
			return false
	return true


static func _state(game: Node, progress: Node) -> String:
	if game == null:
		return "no game"
	var random: bool = game.has_method("is_random") and game.is_random()
	if not random:
		return "story level=%s" % str(game.get("level"))
	var pay: Dictionary = game.payout()
	var hud: Object = game.get("hud")
	var pod: String = hud.attempt_label.text.replace("\n", " / ") if hud and hud.get("attempt_label") else "-"
	return "random seed=%s attempt=%s offer=%s table=%s cap=%s pod=[%s] dev_toggled=%s assisted=%s fresh=%s" % [
		Levels.seed_code(game.random_seed, game.seed_level), game.attempt, pay.tickets, pay.table,
		pay.cap if pay.cap != "" else "none", pod, game.dev_toggled, game.assisted, progress.random_seed_fresh]


static func _append(text: String) -> void:
	var path := log_path()
	var mode := FileAccess.READ_WRITE
	if not _started:
		_started = true
		_bytes = 0
		mode = FileAccess.WRITE  # truncate at the first write of this launch
		_remove_stale()
	elif _bytes >= MAX_BYTES:
		return
	var file := FileAccess.open(path, mode)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return
	file.seek_end()
	file.store_string(text)
	_bytes += text.length()


## Per-process logs of test runs older than 6 hours are deleted (never the plain log).
static func _remove_stale() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var now := Time.get_unix_time_from_system()
	for file in dir.get_files():
		if file.begins_with("dev_attempts_") and file.ends_with(".log") \
				and now - FileAccess.get_modified_time("user://" + file) > 6 * 3600:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file))
