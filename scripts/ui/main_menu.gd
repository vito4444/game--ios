extends Control

## Title screen. Deliberately thin: it exists so the game boots into something
## other than a level, and so the App Store screenshot has a title card.

const GAME_SCENE := "res://scenes/game.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_screen.tscn"

## Launch flag that skips the title screen. The simulator job uses it because
## simctl cannot tap anything, and it is the only way an automated capture gets
## past the menu into the game itself.
const AUTOSTART_FLAG := "--autostart"

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

	if OS.get_cmdline_user_args().has(AUTOSTART_FLAG):
		call_deferred("_start_new")


func _start_new() -> void:
	SaveGame.delete()
	get_tree().change_scene_to_file(GAME_SCENE)


func _resume() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _open_settings() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)
