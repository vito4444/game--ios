extends Node

## Single place the game asks "where does the player want to go".
##
## Touch and keyboard both feed this, so gameplay code never branches on input
## device, and tests can drive a character by writing to `stick` directly
## instead of synthesising input events.

signal interact_pressed

## Written by the on-screen joystick; zero when nothing is touching it.
var stick: Vector2 = Vector2.ZERO

## Set by tests and cutscenes to freeze the player without touching the scene.
var movement_locked: bool = false


func movement() -> Vector2:
	if movement_locked:
		return Vector2.ZERO
	if stick.length_squared() > 0.0:
		return stick.limit_length(1.0)
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func press_interact() -> void:
	interact_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		press_interact()
