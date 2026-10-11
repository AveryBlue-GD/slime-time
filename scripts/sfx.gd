extends Node

## Autoload "Sfx": plays the generated sound effects in assets/sounds/ (see tools/make_sounds.py).
## Each sound gets a few players so quick repeats overlap instead of cutting each other off.
## Muted when Progress.sound_on is false.

const SOUNDS: Array[String] = ["squish", "charge", "jump", "land", "splat", "chalice", "unlock", "dry", "click", "pause", "coin", "crumble", "jingle"]
const VOICES := 3

var _players := {}


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


func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var progress := get_node_or_null("/root/Progress")
	if progress and not progress.sound_on:
		return
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
