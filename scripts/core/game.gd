extends Node

## Composition root for a play session: the rig plus its overlays.

@onready var rig: RigWorld = $Rig
@onready var hud: CanvasLayer = $Hud
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var interaction_panel: CanvasLayer = $InteractionPanel
@onready var outcome_screen: CanvasLayer = $OutcomeScreen


func _ready() -> void:
	hud.bind(rig)
	interaction_panel.bind(rig)
	outcome_screen.bind(rig)


func _unhandled_input(event: InputEvent) -> void:
	# The panel consumes the same action to close itself, so it gets first refusal.
	if event.is_action_pressed("ui_pause") and not interaction_panel.is_open():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
