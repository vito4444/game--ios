class_name CharacterSprite
extends Sprite2D

## Drives a 4x4 walk sheet produced by tools/gen_art.py.
##
## Rows are ordered down, left, right, up to match the DIRECTIONS tuple in the
## generator. Frames run 0-1-2-3, where 0 and 2 are the neutral pose, so a
## stopped character can rest on frame 0 without a visible snap.

const FRAME_SIZE := Vector2i(32, 48)
const FRAMES_PER_ROW := 4
const ANIMATION_FPS := 8.0

## Feet sit 45px down a 48px frame; this lifts the sprite so the node origin is
## on the floor, which is what depth sorting and collision both assume.
const FOOT_OFFSET := Vector2(0, -21)

enum Facing { DOWN, LEFT, RIGHT, UP }

var facing: Facing = Facing.DOWN
var _frame_index: int = 0
var _time: float = 0.0


func _ready() -> void:
	centered = true
	offset = FOOT_OFFSET
	region_enabled = true
	_apply_region()


func set_sheet(path: String) -> void:
	texture = load(path)
	_apply_region()


func update_animation(velocity: Vector2, delta: float) -> void:
	if velocity.length_squared() > 0.0:
		facing = facing_for(velocity)
		_time += delta * ANIMATION_FPS
		_frame_index = int(_time) % FRAMES_PER_ROW
	else:
		_time = 0.0
		_frame_index = 0
	_apply_region()


static func facing_for(direction: Vector2) -> Facing:
	## Vertical wins ties so that walking diagonally into a wall keeps the
	## sprite pointing the way the player is still moving.
	if absf(direction.y) >= absf(direction.x):
		return Facing.DOWN if direction.y > 0.0 else Facing.UP
	return Facing.RIGHT if direction.x > 0.0 else Facing.LEFT


func _apply_region() -> void:
	region_rect = Rect2(
		Vector2(_frame_index * FRAME_SIZE.x, int(facing) * FRAME_SIZE.y), Vector2(FRAME_SIZE)
	)
