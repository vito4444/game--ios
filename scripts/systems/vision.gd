class_name Vision
extends RefCounted

## Line of sight for security officers, computed on the tile grid.
##
## Grid-based rather than physics-based on purpose: it is deterministic,
## testable without a scene tree, and it lets a locker block sight while a bunk
## does not, which the collision shapes cannot express.

## Roughly six tiles of corridor. Long enough to be dangerous to cross in the
## open, short enough that the rig still has dark corners.
const DEFAULT_RANGE_TILES := 6.0

## A 90-degree cone. Wider makes sneaking past impossible, narrower makes
## guards feel oblivious.
const DEFAULT_HALF_ANGLE_DEGREES := 45.0

## Anything this close is noticed regardless of facing: you cannot stand at a
## guard's shoulder unseen.
const AWARENESS_RADIUS_TILES := 1.5


class Cone:
	var range_tiles: float
	var half_angle_degrees: float
	var awareness_radius_tiles: float

	func _init(
		cone_range: float = Vision.DEFAULT_RANGE_TILES,
		half_angle: float = Vision.DEFAULT_HALF_ANGLE_DEGREES,
		awareness: float = Vision.AWARENESS_RADIUS_TILES
	) -> void:
		range_tiles = cone_range
		half_angle_degrees = half_angle
		awareness_radius_tiles = awareness

	func scaled(factor: float) -> Cone:
		## Used by the blackout system to shrink every cone at once.
		return Cone.new(range_tiles * factor, half_angle_degrees, awareness_radius_tiles)


static func can_see(
	map: RigMap, from_cell: Vector2i, facing: Vector2, target_cell: Vector2i, cone: Cone
) -> bool:
	if from_cell == target_cell:
		return true

	var offset := Vector2(target_cell - from_cell)
	var distance := offset.length()
	if distance > cone.range_tiles:
		return false

	if distance > cone.awareness_radius_tiles and not _within_cone(offset, facing, cone):
		return false

	return has_clear_line(map, from_cell, target_cell)


static func _within_cone(offset: Vector2, facing: Vector2, cone: Cone) -> bool:
	if facing.is_zero_approx():
		return true
	return absf(rad_to_deg(facing.normalized().angle_to(offset.normalized()))) \
		<= cone.half_angle_degrees


## Bresenham walk between two cells, ignoring the endpoints. The target's own
## tile is excluded so standing behind a crate hides the player while standing
## on one does not make them invisible.
static func has_clear_line(map: RigMap, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	for cell in line_between(from_cell, to_cell):
		if map.blocks_sight(cell):
			return false
	return true


static func line_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	# Walked in a canonical direction and reversed if needed. Bresenham picks a
	# different diagonal step depending on which end it starts from, and an
	# asymmetric line means a guard could see the player from a tile the player
	# could not see the guard from.
	var flipped := (
		to_cell.x < from_cell.x or (to_cell.x == from_cell.x and to_cell.y < from_cell.y)
	)
	if flipped:
		var cells := _walk(to_cell, from_cell)
		cells.reverse()
		return cells
	return _walk(from_cell, to_cell)


static func _walk(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := Vector2i(absi(to_cell.x - from_cell.x), -absi(to_cell.y - from_cell.y))
	var step := Vector2i(
		1 if from_cell.x < to_cell.x else -1, 1 if from_cell.y < to_cell.y else -1
	)
	var error := delta.x + delta.y
	var cursor := from_cell

	while cursor != to_cell:
		var doubled := error * 2
		if doubled >= delta.y and cursor.x != to_cell.x:
			error += delta.y
			cursor.x += step.x
		if doubled <= delta.x and cursor.y != to_cell.y:
			error += delta.x
			cursor.y += step.y
		if cursor == to_cell:
			break
		cells.append(cursor)
	return cells


static func facing_from(direction: Vector2) -> Vector2:
	## Guards look along one of the four cardinals, matching their sprite.
	if direction.is_zero_approx():
		return Vector2.DOWN
	if absf(direction.y) >= absf(direction.x):
		return Vector2.DOWN if direction.y > 0.0 else Vector2.UP
	return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
