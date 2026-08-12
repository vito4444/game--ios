extends Node

## Composition root for a play session: the rig plus its overlays.

@onready var rig: RigWorld = $Rig
@onready var hud: CanvasLayer = $Hud
@onready var touch_controls: CanvasLayer = $TouchControls


func _ready() -> void:
	hud.bind(rig)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
