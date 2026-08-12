extends GutTest

## Drives the real scene through the physics server rather than calling
## movement maths directly, so collision shapes and the tile collision layer
## are covered too.

const RIG_SCENE := "res://scenes/world/rig.tscn"
const PHYSICS_FPS := 60.0

## Written out rather than derived from Player.BASE_SPEED: deriving it would
## make the assertion follow the code it is supposed to pin down.
const EXPECTED_SPEED := 68.0
const HALF_SECOND_TRAVEL := 34.0
const TOLERANCE := 3.0

var rig: RigWorld


func before_each() -> void:
	GameInput.stick = Vector2.ZERO
	GameInput.movement_locked = false
	rig = add_child_autofree((load(RIG_SCENE) as PackedScene).instantiate()) as RigWorld
	await wait_physics_frames(2)


func after_each() -> void:
	GameInput.stick = Vector2.ZERO


func _place_player_at(cell: Vector2i) -> void:
	rig.player.global_position = rig.map.cell_centre(cell)
	await wait_physics_frames(1)


func test_rig_loads_its_map_and_spawns_the_player() -> void:
	assert_true(rig.map.is_valid())
	assert_not_null(rig.player)
	assert_eq(rig.player.global_position, rig.map.cell_centre(rig.map.spawn))


func test_walk_speed_is_the_documented_value() -> void:
	# If this fails, the distance assertions below need their literals updating
	# rather than deleting.
	assert_eq(Player.BASE_SPEED, EXPECTED_SPEED)


func test_walking_right_for_half_a_second_covers_the_expected_distance() -> void:
	# Corridor cell with clear space to the right.
	await _place_player_at(Vector2i(3, 11))
	var start := rig.player.global_position

	GameInput.stick = Vector2.RIGHT
	await wait_physics_frames(int(PHYSICS_FPS * 0.5))
	GameInput.stick = Vector2.ZERO

	var travelled := rig.player.global_position.x - start.x
	assert_between(travelled, HALF_SECOND_TRAVEL - TOLERANCE, HALF_SECOND_TRAVEL + TOLERANCE)
	assert_almost_eq(rig.player.global_position.y, start.y, 0.5)


func test_diagonal_input_does_not_move_faster_than_straight_input() -> void:
	await _place_player_at(Vector2i(3, 11))
	var start := rig.player.global_position

	GameInput.stick = Vector2(1.0, -1.0).normalized()
	await wait_physics_frames(int(PHYSICS_FPS * 0.5))
	GameInput.stick = Vector2.ZERO

	var travelled := start.distance_to(rig.player.global_position)
	assert_between(travelled, HALF_SECOND_TRAVEL - TOLERANCE, HALF_SECOND_TRAVEL + TOLERANCE)


func test_the_hull_stops_the_player() -> void:
	await _place_player_at(Vector2i(1, 11))
	var start := rig.player.global_position

	GameInput.stick = Vector2.LEFT
	await wait_physics_frames(int(PHYSICS_FPS))
	GameInput.stick = Vector2.ZERO

	assert_gt(rig.player.global_position.x, start.x - 16.0, "player walked into the hull")


func test_locking_movement_stops_the_player() -> void:
	await _place_player_at(Vector2i(3, 11))
	var start := rig.player.global_position

	GameInput.movement_locked = true
	GameInput.stick = Vector2.RIGHT
	await wait_physics_frames(int(PHYSICS_FPS * 0.5))
	GameInput.movement_locked = false
	GameInput.stick = Vector2.ZERO

	assert_almost_eq(rig.player.global_position.x, start.x, 0.01)


func test_sprite_faces_the_direction_of_travel() -> void:
	assert_eq(CharacterSprite.facing_for(Vector2.RIGHT), CharacterSprite.Facing.RIGHT)
	assert_eq(CharacterSprite.facing_for(Vector2.LEFT), CharacterSprite.Facing.LEFT)
	assert_eq(CharacterSprite.facing_for(Vector2.DOWN), CharacterSprite.Facing.DOWN)
	assert_eq(CharacterSprite.facing_for(Vector2.UP), CharacterSprite.Facing.UP)
	# Vertical wins ties so a diagonal into a wall keeps facing the free axis.
	assert_eq(CharacterSprite.facing_for(Vector2(1, 1)), CharacterSprite.Facing.DOWN)


func test_camera_never_shows_outside_the_map() -> void:
	var camera := rig.camera()
	var half := camera.get_viewport_rect().size * 0.5 / camera.zoom
	var extent := Vector2(rig.map.pixel_size())
	var corners := [
		Vector2i(1, 1),
		Vector2i(rig.map.width - 2, 1),
		Vector2i(1, rig.map.height - 2),
		Vector2i(rig.map.width - 2, rig.map.height - 2),
	]
	for corner in corners:
		await _place_player_at(corner)
		await wait_process_frames(2)
		var centre := camera.get_screen_center_position()
		assert_between(centre.x, half.x, extent.x - half.x, "camera x at %s" % corner)
		assert_between(centre.y, half.y, extent.y - half.y, "camera y at %s" % corner)


func test_camera_limits_match_the_map_extent() -> void:
	var extent := rig.map.pixel_size()
	assert_eq(rig.camera().limit_left, 0)
	assert_eq(rig.camera().limit_top, 0)
	assert_eq(rig.camera().limit_right, extent.x)
	assert_eq(rig.camera().limit_bottom, extent.y)
