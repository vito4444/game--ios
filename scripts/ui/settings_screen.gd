extends Control

## Language and volume. Changes take effect immediately and are written out as
## they are made, so there is no save button to forget.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var _language: Button = $Layout/Language/Value
@onready var _music: HSlider = $Layout/Music/Value
@onready var _effects: HSlider = $Layout/Effects/Value
@onready var _back: Button = $Layout/Back


func _ready() -> void:
	_language.pressed.connect(_cycle_language)
	_music.value_changed.connect(func(value: float) -> void: Settings.set_music_volume(value))
	_effects.value_changed.connect(func(value: float) -> void: Settings.set_effects_volume(value))
	_back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))

	_music.value = Settings.music_volume
	_effects.value = Settings.effects_volume
	_refresh_language()
	_language.grab_focus()


func _cycle_language() -> void:
	Settings.set_language(Settings.next_language())
	_refresh_language()


func _refresh_language() -> void:
	_language.text = Settings.LANGUAGES[Settings.language]
