class_name Player
extends CharacterBody2D

## The technician. Movement only, at this stage.

const SHEET := "res://assets/generated/actors/player.png"

## Roughly two tiles a second. Slow enough that crossing the rig during a
## 45-second blackout is a real decision rather than a formality.
const BASE_SPEED := 68.0

@onready var _sprite: CharacterSprite = $Sprite


func _ready() -> void:
	_sprite.set_sheet(SHEET)


func _physics_process(delta: float) -> void:
	var direction := GameInput.movement()
	velocity = direction * BASE_SPEED
	move_and_slide()
	_sprite.update_animation(velocity, delta)


func facing() -> CharacterSprite.Facing:
	return _sprite.facing


func cell() -> Vector2i:
	return Vector2i((global_position / Vector2(TileCatalog.TILE_SIZE)).floor())
