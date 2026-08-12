class_name Player
extends CharacterBody2D

## The technician. Movement only, at this stage.

const SHEET := "res://assets/generated/actors/player.png"

## Roughly two tiles a second. Slow enough that crossing the rig during a
## 45-second blackout is a real decision rather than a formality.
const BASE_SPEED := 68.0

## Raised by Conditioning. Set by the world when the stat changes.
var speed_multiplier: float = 1.0

@onready var _sprite: CharacterSprite = $Sprite


func _ready() -> void:
	_sprite.set_sheet(SHEET)


func speed() -> float:
	return BASE_SPEED * speed_multiplier


func _physics_process(delta: float) -> void:
	var direction := GameInput.movement()
	velocity = direction * speed()
	move_and_slide()
	_sprite.update_animation(velocity, delta)


func facing() -> CharacterSprite.Facing:
	return _sprite.facing


func facing_direction() -> Vector2:
	return CharacterSprite.direction_of(_sprite.facing)


## Turns on the spot. Used after a teleport, and by staged scenes, so the
## player is not left facing the wall they arrived through.
func face(direction: Vector2) -> void:
	_sprite.facing = CharacterSprite.facing_for(direction)


func cell() -> Vector2i:
	return Vector2i((global_position / Vector2(TileCatalog.TILE_SIZE)).floor())
