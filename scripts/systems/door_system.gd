class_name DoorSystem
extends RefCounted

## Powered doors that slide open for whoever is standing next to them.
##
## The rig is automated, so doors open on approach rather than on a button
## press - which also means the player never fumbles a door with a guard behind
## them. Pressure hatches are the exception: they answer to security only, and
## are the reason the hangar and the solitary cell are not simply walked into.

signal door_opened(cell: Vector2i)
signal door_closed(cell: Vector2i)

## How close, in tiles, someone has to be for a door to notice them.
const TRIGGER_RADIUS := 1.6


class Door:
	var cell: Vector2i
	var kind: StringName
	var open: bool = false

	func _init(door_cell: Vector2i, door_kind: StringName) -> void:
		cell = door_cell
		kind = door_kind

	func opens_for_staff_only() -> bool:
		return kind == TileCatalog.PRESSURE_HATCH


var _map: RigMap
var _doors: Dictionary = {}


func _init(map: RigMap) -> void:
	_map = map
	for cell in map.door_cells():
		_doors[cell] = Door.new(cell, map.door_kind(cell))


func cells() -> Array:
	return _doors.keys()


func count() -> int:
	return _doors.size()


func is_open(cell: Vector2i) -> bool:
	var door: Door = _doors.get(cell)
	return door != null and door.open


func is_door(cell: Vector2i) -> bool:
	return _doors.has(cell)


func kind_at(cell: Vector2i) -> StringName:
	var door: Door = _doors.get(cell)
	return door.kind if door != null else &""


## `approaches` maps a tile position to whether that person is security.
## Returns the doors whose state changed.
func update(approaches: Array[Dictionary]) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for cell in _doors:
		var door: Door = _doors[cell]
		var should_open := false
		for approach in approaches:
			var position: Vector2 = approach["cell"]
			if position.distance_to(Vector2(cell)) > TRIGGER_RADIUS:
				continue
			if door.opens_for_staff_only() and not bool(approach.get("staff", false)):
				continue
			should_open = true
			break

		if should_open == door.open:
			continue
		_set_open(door, should_open)
		changed.append(cell)
	return changed


## Forces a door open permanently, for a hatch that has been cut through.
func force_open(cell: Vector2i) -> void:
	var door: Door = _doors.get(cell)
	if door == null:
		return
	_set_open(door, true)
	_doors.erase(cell)


func _set_open(door: Door, open: bool) -> void:
	door.open = open
	_map.set_cell_opened(door.cell, open)
	if open:
		door_opened.emit(door.cell)
	else:
		door_closed.emit(door.cell)
