extends Node

## Player preferences, stored separately from the save so they survive starting
## a new contract.

const PATH := "user://settings.cfg"

const LANGUAGES := {
	"en": "English",
	"zh": "中文",
}

const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"

var language: String = "en"
var music_volume: float = 0.7
var effects_volume: float = 0.9


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		language = config.get_value("general", "language", language)
		music_volume = config.get_value("audio", "music", music_volume)
		effects_volume = config.get_value("audio", "effects", effects_volume)
	else:
		# First run: follow the device, since the game ships in both languages.
		language = "zh" if OS.get_locale().begins_with("zh") else "en"
	apply()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.save(PATH)


func apply() -> void:
	TranslationServer.set_locale(language)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(EFFECTS_BUS, effects_volume)


func set_language(value: String) -> void:
	if not LANGUAGES.has(value) or value == language:
		return
	language = value
	apply()
	save_settings()


func next_language() -> String:
	var codes := LANGUAGES.keys()
	var index := codes.find(language)
	return codes[(index + 1) % codes.size()]


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	save_settings()


func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	_apply_bus(EFFECTS_BUS, effects_volume)
	save_settings()


func _apply_bus(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
