extends Node

## Composition root for a play session: the rig plus its overlays.
##
## Also owns saving. The game writes on leaving and on losing focus rather than
## offering a save button, because on a phone the app can be backgrounded at any
## moment and a lost run is not a fair punishment for taking a call.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var rig: RigWorld = $Rig
@onready var hud: CanvasLayer = $Hud
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var interaction_panel: CanvasLayer = $InteractionPanel
@onready var outcome_screen: CanvasLayer = $OutcomeScreen


func _ready() -> void:
	hud.bind(rig)
	interaction_panel.bind(rig)
	outcome_screen.bind(rig)
	_restore()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


func save() -> void:
	if rig.session == null or rig.session.player_state.has_escaped():
		return
	SaveGame.write(rig.session, rig.player.global_position)


func _restore() -> void:
	if not SaveGame.exists():
		return
	var data := SaveGame.read()
	if data.is_empty():
		return
	rig.player.global_position = SaveGame.apply(rig.session, data)


func _unhandled_input(event: InputEvent) -> void:
	# The panel consumes the same action to close itself, so it gets first refusal.
	if event.is_action_pressed("ui_pause") and not interaction_panel.is_open():
		save()
		get_tree().change_scene_to_file(MAIN_MENU)
