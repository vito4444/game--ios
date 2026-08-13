extends GutTest

## Officers in the live scene: they walk their routes, notice the player where
## they are not allowed to be, and end the chase with an arrest.

const RIG_SCENE := "res://scenes/world/rig.tscn"
const PHYSICS_FPS := 60

var rig: RigWorld


func before_each() -> void:
	GameInput.stick = Vector2.ZERO
	GameInput.movement_locked = false
	rig = add_child_autofree((load(RIG_SCENE) as PackedScene).instantiate()) as RigWorld
	await wait_physics_frames(2)


func after_each() -> void:
	GameInput.stick = Vector2.ZERO
	GameInput.movement_locked = false


func _officer_on(route: StringName) -> SecurityOfficer:
	for index in rig.map.patrols.size():
		if rig.map.patrols[index].id == route:
			return rig.officers[index]
	return null


func test_one_officer_spawns_per_patrol_route() -> void:
	assert_eq(rig.map.patrols.size(), 4)
	assert_eq(rig.officers.size(), 4)


func test_officers_start_on_their_routes_and_out_of_the_walls() -> void:
	for index in rig.officers.size():
		var officer := rig.officers[index]
		var start := rig.map.patrols[index].start()
		assert_eq(officer.cell(), start, "officer %d did not start on its route" % index)
		assert_false(rig.map.is_solid(officer.cell()))


func test_an_officer_makes_progress_along_its_route() -> void:
	var officer := _officer_on(&"main_corridor")
	var start := officer.global_position
	await wait_physics_frames(PHYSICS_FPS * 2)
	assert_gt(
		officer.global_position.distance_to(start), 30.0, "officer barely moved in two seconds"
	)


func test_officers_stay_out_of_geometry_while_patrolling() -> void:
	await wait_physics_frames(PHYSICS_FPS * 3)
	for officer in rig.officers:
		assert_false(
			rig.map.is_solid(officer.cell()), "officer walked into %s" % officer.cell()
		)


func test_an_officer_ignores_the_player_standing_somewhere_legal() -> void:
	var officer := _officer_on(&"main_corridor")
	rig.player.global_position = officer.global_position + Vector2(48, 0)
	await wait_physics_frames(PHYSICS_FPS)
	assert_ne(officer.state, SecurityOfficer.State.CHASE)
	assert_eq(rig.session.suspicion.value, 0)


func test_an_officer_gives_chase_when_it_sees_a_restricted_area_breach() -> void:
	var officer := _officer_on(&"security_office")
	var breach := officer.cell() + Vector2i(4, 0)
	rig.player.global_position = rig.map.cell_centre(breach)
	# Long enough for one look, short enough that the chase has not yet landed.
	await wait_physics_frames(15)

	assert_eq(officer.state, SecurityOfficer.State.CHASE)
	assert_eq(rig.session.suspicion.value, 20, "a restricted-area sighting costs 20")
	assert_eq(rig.session.player_state.state, PlayerState.PURSUED)


func test_a_chase_ends_with_the_player_in_solitary_and_stripped_of_contraband() -> void:
	rig.session.inventory.add(&"cutting_torch")
	rig.session.inventory.add(&"ration")

	var officer := _officer_on(&"security_office")
	rig.player.global_position = officer.global_position + Vector2(24, 0)

	# The chase, the escort across the office, and the arrest at the far end.
	await _wait_for_arrest()

	assert_eq(rig.session.player_state.state, PlayerState.SOLITARY)
	assert_eq(rig.session.inventory.contraband_count(), 0)
	assert_true(rig.session.inventory.has(&"ration"), "legal items survive an arrest")
	assert_eq(rig.session.zone_at_position(rig.player.global_position), &"solitary")
	assert_false(GameInput.movement_locked, "control must be handed back after the escort")


func test_the_officer_returns_to_patrol_after_making_an_arrest() -> void:
	var officer := _officer_on(&"security_office")
	rig.player.global_position = officer.global_position + Vector2(24, 0)

	await _wait_for_arrest()
	await wait_physics_frames(4)

	assert_eq(officer.state, SecurityOfficer.State.PATROL)


func test_a_wall_between_them_keeps_the_player_unseen() -> void:
	var officer := _officer_on(&"security_office")
	# The solitary cell is walled off from the rest of the security office.
	var hidden := rig.session.solitary_cell()
	assert_false(
		officer.can_see_cell(hidden), "the solitary cell wall should block line of sight"
	)


## Polls in batches: an arrest takes a few seconds of game time, and awaiting
## one frame at a time makes the suite an order of magnitude slower.
func _wait_for_arrest(timeout_seconds: float = 12.0) -> void:
	var batches := int(timeout_seconds * PHYSICS_FPS / 10.0)
	for _batch in range(batches):
		await wait_physics_frames(10)
		if rig.session.player_state.state == PlayerState.SOLITARY:
			return
