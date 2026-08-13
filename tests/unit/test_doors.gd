extends GutTest

## Powered doors and pressure hatches.

const MAP_PATH := "res://data/maps/abyss9.map"

var map: RigMap
var doors: DoorSystem
var powered_cell: Vector2i
var hatch_cell: Vector2i


func before_each() -> void:
	map = RigMap.load_from(MAP_PATH)
	doors = DoorSystem.new(map)
	powered_cell = _first_of(TileCatalog.POWERED_DOOR)
	hatch_cell = _first_of(TileCatalog.PRESSURE_HATCH)


func _first_of(kind: StringName) -> Vector2i:
	for cell in map.door_cells():
		if map.door_kind(cell) == kind:
			return cell
	return Vector2i(-1, -1)


func _approach(cell: Vector2i, staff: bool) -> Array[Dictionary]:
	return [{"cell": Vector2(cell), "staff": staff}]


func test_the_map_has_doors_of_both_kinds() -> void:
	assert_gt(doors.count(), 0)
	assert_ne(powered_cell, Vector2i(-1, -1), "no powered door on the map")
	assert_ne(hatch_cell, Vector2i(-1, -1), "no pressure hatch on the map")


func test_doors_start_shut_and_solid() -> void:
	assert_false(doors.is_open(powered_cell))
	assert_true(map.is_solid(powered_cell))
	assert_true(map.blocks_sight(powered_cell))


func test_a_powered_door_opens_for_anyone_who_walks_up_to_it() -> void:
	doors.update(_approach(powered_cell + Vector2i(1, 0), false))
	assert_true(doors.is_open(powered_cell))
	assert_false(map.is_solid(powered_cell), "an open door must be walkable")
	assert_false(map.blocks_sight(powered_cell), "an open door must be see-through")


func test_a_powered_door_shuts_again_once_nobody_is_near() -> void:
	doors.update(_approach(powered_cell, false))
	assert_true(doors.is_open(powered_cell))

	doors.update(_approach(powered_cell + Vector2i(6, 0), false))
	assert_false(doors.is_open(powered_cell))
	assert_true(map.is_solid(powered_cell))


func test_a_pressure_hatch_ignores_the_player() -> void:
	doors.update(_approach(hatch_cell + Vector2i(1, 0), false))
	assert_false(doors.is_open(hatch_cell), "the player has no business opening a hatch")
	assert_true(map.is_solid(hatch_cell))


func test_a_pressure_hatch_opens_for_security() -> void:
	doors.update(_approach(hatch_cell + Vector2i(1, 0), true))
	assert_true(doors.is_open(hatch_cell))
	assert_false(map.is_solid(hatch_cell))


func test_a_door_across_the_room_is_not_triggered() -> void:
	doors.update(_approach(powered_cell + Vector2i(0, 4), false))
	assert_false(doors.is_open(powered_cell))


func test_a_forced_hatch_stays_open_afterwards() -> void:
	doors.force_open(hatch_cell)
	assert_true(map.is_cell_opened(hatch_cell))
	assert_false(map.is_solid(hatch_cell))

	# Nobody nearby, and it must not swing shut again.
	doors.update([])
	assert_false(map.is_solid(hatch_cell), "a cut hatch does not repair itself")


func test_pathfinding_treats_shut_doors_as_passable() -> void:
	# Otherwise the rig is a set of sealed rooms and no patrol can leave one.
	var navigation := RigNavigation.new(map)
	assert_true(navigation.is_walkable(powered_cell))
	assert_true(navigation.is_walkable(hatch_cell))


func test_every_room_is_reachable_from_the_player_spawn() -> void:
	var navigation := RigNavigation.new(map)
	for zone in map.zones:
		var target := navigation.nearest_walkable(zone.rect.position + zone.rect.size / 2)
		var path := navigation.path_between(map.spawn, target)
		assert_gt(path.size(), 0, "no route from spawn to %s" % zone.id)
