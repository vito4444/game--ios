extends Control

## Title screen. Deliberately thin: it exists so the game boots into something
## other than a level, and so the App Store screenshot has a title card.

const GAME_SCENE := "res://scenes/game.tscn"

@onready var _title: Label = $Layout/Title
@onready var _subtitle: Label = $Layout/Subtitle
@onready var _play: Button = $Layout/Play


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "Deep Contract")
	_subtitle.text = "1,800 m below. Contract auto-renewing."
	_play.pressed.connect(_start)
	_play.grab_focus()


func _start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
