extends Control

## Title screen. Deliberately thin: it exists so the game boots into something
## other than a level, and so the App Store screenshot has a title card.

const GAME_SCENE := "res://scenes/game.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_screen.tscn"

@onready var _play: Button = $Layout/Play
@onready var _continue: Button = $Layout/Continue
@onready var _settings: Button = $Layout/Settings


func _ready() -> void:
	Audio.start_ambience()
	_play.pressed.connect(_start_new)
	_continue.pressed.connect(_resume)
	_settings.pressed.connect(_open_settings)

	_continue.disabled = not SaveGame.exists()
	(_continue if not _continue.disabled else _play).grab_focus()


func _start_new() -> void:
	SaveGame.delete()
	get_tree().change_scene_to_file(GAME_SCENE)


func _resume() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _open_settings() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)
