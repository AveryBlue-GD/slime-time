extends Node

## Autoload "Sfx": plays the generated sound effects in assets/sounds/ (see tools/make_sounds.py).
## Each sound gets a few players so quick repeats overlap instead of cutting each other off.
## Muted when Progress.sound_on is false.

const SOUNDS: Array[String] = ["squish", "charge", "jump", "land", "splat", "chalice", "unlock", "dry", "click", "pause", "coin", "crumble", "jingle", "upgrade", "heartbeat", "lowwarn", "whoosh", "crack", "clank", "sunrise", "huh", "grumble", "goo_shot", "goo_lob", "goo_burst", "kaze", "bounce"]
const VOICES := 3

## Sounds that vary a little each time (+/- this share of pitch, and +/- VARY_DB in volume), so
## quick repeats don't sound machine-gunned. Others (charge, chalice...) always play as asked.
const VARY := {land = 0.05, splat = 0.04, click = 0.03, coin = 0.04, jump = 0.03, pause = 0.02, crumble = 0.04, unlock = 0.02, clank = 0.06, goo_shot = 0.05, goo_burst = 0.04, bounce = 0.04}
const VARY_DB := 1.5

var _players := {}
var _last_frame := {}
var _unlocked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var stream: AudioStream = load("res://assets/sounds/%s.wav" % sound_name)
		var voices: Array[AudioStreamPlayer] = []
		for i in VOICES:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			add_child(player)
			voices.append(player)
		_players[sound_name] = voices


## Browsers keep audio locked until the first click, tap or key press: on the web, the first
## one plays an inaudible blip so the audio output starts on that gesture, not on the first
## real sound (which could then be swallowed).
func _input(event: InputEvent) -> void:
	if _unlocked or not Platform.has_js():
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		_unlocked = true
		var player: AudioStreamPlayer = _players["click"][0]
		player.volume_db = -80.0
		player.play()


func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var progress := get_node_or_null("/root/Progress")
	if progress and not progress.sound_on:
		return
	var frame := Engine.get_process_frames()
	if VARY.has(sound_name):
		if _last_frame.get(sound_name, -1) == frame:
			return  # the same sound twice in one frame is one sound
		_last_frame[sound_name] = frame
		pitch *= randf_range(1.0 - VARY[sound_name], 1.0 + VARY[sound_name])
		volume_db += randf_range(-VARY_DB, VARY_DB)
	var voices: Array[AudioStreamPlayer] = _players[sound_name]
	var player := voices[0]
	for voice in voices:
		if not voice.playing:
			player = voice
			break
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func stop(sound_name: String) -> void:
	for voice: AudioStreamPlayer in _players[sound_name]:
		voice.stop()


func has_sound(sound_name: String) -> bool:
	return _players.has(sound_name) and _players[sound_name][0].stream != null
