extends Node

## Plays the generated sound effects.
##
## A small pool of players is reused rather than spawning a node per sound,
## because on a phone the allocation churn is more expensive than the audio.

const DIRECTORY := "res://assets/generated/audio"
const EFFECTS_BUS := &"Effects"
const VOICES := 8

## Sounds that would stack into a mess if the same one fired twice in a frame.
const RATE_LIMITED: Array[StringName] = [&"bubble", &"ui_click"]
const RATE_LIMIT_SECONDS := 0.08

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = EFFECTS_BUS
		add_child(player)
		_players.append(player)


func play(id: StringName) -> void:
	if RATE_LIMITED.has(id):
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(_last_played.get(id, -99.0)) < RATE_LIMIT_SECONDS:
			return
		_last_played[id] = now

	var stream := _stream_for(id)
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.play()


func has_sound(id: StringName) -> bool:
	return _stream_for(id) != null


func _stream_for(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := "%s/%s.wav" % [DIRECTORY, id]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("no such sound: %s" % id)
	_streams[id] = stream
	return stream
