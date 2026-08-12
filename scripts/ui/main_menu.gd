extends Control

## Entry point scene. Wiring to the world scene lands in a later phase; for now
## this only proves the project boots and the render pipeline is configured.

@onready var _title: Label = $Layout/Title
@onready var _subtitle: Label = $Layout/Subtitle


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "Deep Contract")
	_subtitle.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
