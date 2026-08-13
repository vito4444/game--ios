extends GutTest

## Both ways off the rig, walked end to end in the live scene, plus every
## prerequisite removed one at a time to prove none of them is decorative.

const RIG_SCENE := "res://scenes/world/rig.tscn"

const SUBMERSIBLE_KIT: Array[StringName] = [
	&"drive_housing", &"drive_impeller", &"drive_core", &"cutting_torch"
]
const SUPPLY_SUB_KIT: Array[StringName] = [&"officer_uniform", &"forged_docket"]

## The supply sub ties up between 02:00 and 03:00.
const SUPPLY_WINDOW_MINUTE := 2 * 60 + 30
const OUTSIDE_WINDOW_MINUTE := 14 * 60

var rig: RigWorld


func before_each() -> void:
	GameInput.stick = Vector2.ZERO
	GameInput.movement_locked = false
	rig = add_child_autofree((load(RIG_SCENE) as PackedScene).instantiate()) as RigWorld
	await wait_physics_frames(2)
	# Escapes are about kit and timing, not about outrunning a guard.
	for officer in rig.officers:
		officer.queue_free()
	rig.officers.clear()
	await wait_physics_frames(1)


func _prop_cell(tile: StringName) -> Vector2i:
	for y in rig.map.height:
		for x in rig.map.width:
			var cell := Vector2i(x, y)
			if TileCatalog.prop_entry(rig.map.prop_symbol(cell)).get("tile", &"") == tile:
				return cell
	return Vector2i(-1, -1)


## Stands next to a prop and turns to face it, so the action button picks that
## prop rather than whatever else happens to be within reach.
func _stand_facing(cell: Vector2i) -> void:
	var offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for offset in offsets:
		if rig.map.is_solid(cell + offset):
			continue
		rig.player.global_position = rig.map.cell_centre(cell + offset)
		rig.player.face(Vector2(-offset))
		await wait_physics_frames(1)
		return
	fail_test("nowhere to stand beside %s" % cell)


func _carry(kit: Array[StringName]) -> void:
	rig.session.inventory.capacity = 40
	for id in kit:
		assert_true(rig.session.inventory.add(id), "could not carry %s" % id)


func _at_time(minute_of_day: int) -> void:
	rig.session.clock.advance_to_minute_of_day(minute_of_day)


func test_the_map_offers_both_routes() -> void:
	assert_eq(rig.session.escape_routes.errors, PackedStringArray())
	assert_eq(rig.session.escape_routes.routes.size(), 2)
	assert_ne(_prop_cell(&"hangar_door"), Vector2i(-1, -1))
	assert_ne(_prop_cell(&"sub_dock"), Vector2i(-1, -1))


# ---------------------------------------------------------------- submersible


func test_the_submersible_route_ends_in_escape_success() -> void:
	_carry(SUBMERSIBLE_KIT)
	await _stand_facing(_prop_cell(&"hangar_door"))
	assert_eq(rig.current_interaction().kind, Interaction.Kind.ESCAPE)

	GameInput.press_interact()

	assert_eq(rig.session.player_state.state, PlayerState.ESCAPE_SUCCESS)
	assert_true(rig.session.player_state.has_escaped())


func test_the_submersible_consumes_the_torch_but_not_the_drive_parts() -> void:
	_carry(SUBMERSIBLE_KIT)
	await _stand_facing(_prop_cell(&"hangar_door"))
	GameInput.press_interact()

	assert_false(rig.session.inventory.has(&"cutting_torch"))
	assert_true(rig.session.inventory.has(&"drive_core"))


func test_every_part_of_the_submersible_kit_is_required() -> void:
	for omitted in SUBMERSIBLE_KIT:
		var partial: Array[StringName] = []
		for id in SUBMERSIBLE_KIT:
			if id != omitted:
				partial.append(id)

		var fresh := add_child_autofree(
			(load(RIG_SCENE) as PackedScene).instantiate()
		) as RigWorld
		await wait_physics_frames(2)
		fresh.session.inventory.capacity = 40
		for id in partial:
			fresh.session.inventory.add(id)

		var result := fresh.session.attempt_escape(&"hangar", &"hangar_door")
		assert_eq(
			result,
			EscapeRoutes.Result.MISSING_KIT,
			"the sub launched without a %s" % omitted
		)
		assert_ne(fresh.session.player_state.state, PlayerState.ESCAPE_SUCCESS)
		fresh.queue_free()
		await wait_physics_frames(1)


func test_the_submersible_has_no_time_window() -> void:
	_carry(SUBMERSIBLE_KIT)
	_at_time(OUTSIDE_WINDOW_MINUTE)
	assert_eq(
		rig.session.attempt_escape(&"hangar", &"hangar_door"), EscapeRoutes.Result.OK
	)


# ---------------------------------------------------------------- supply sub


func test_the_supply_sub_route_ends_in_escape_success_inside_its_window() -> void:
	_carry(SUPPLY_SUB_KIT)
	_at_time(SUPPLY_WINDOW_MINUTE)
	await _stand_facing(_prop_cell(&"sub_dock"))
	assert_eq(rig.current_interaction().kind, Interaction.Kind.ESCAPE)

	GameInput.press_interact()

	assert_eq(rig.session.player_state.state, PlayerState.ESCAPE_SUCCESS)


func test_the_supply_sub_refuses_outside_its_window() -> void:
	_carry(SUPPLY_SUB_KIT)
	_at_time(OUTSIDE_WINDOW_MINUTE)

	assert_eq(
		rig.session.attempt_escape(&"moon_pool", &"sub_dock"),
		EscapeRoutes.Result.OUTSIDE_WINDOW
	)
	assert_ne(rig.session.player_state.state, PlayerState.ESCAPE_SUCCESS)


func test_every_part_of_the_supply_sub_kit_is_required() -> void:
	for omitted in SUPPLY_SUB_KIT:
		var fresh := add_child_autofree(
			(load(RIG_SCENE) as PackedScene).instantiate()
		) as RigWorld
		await wait_physics_frames(2)
		fresh.session.inventory.capacity = 40
		for id in SUPPLY_SUB_KIT:
			if id != omitted:
				fresh.session.inventory.add(id)
		fresh.session.clock.advance_to_minute_of_day(SUPPLY_WINDOW_MINUTE)

		assert_eq(
			fresh.session.attempt_escape(&"moon_pool", &"sub_dock"),
			EscapeRoutes.Result.MISSING_KIT,
			"boarded the sub without a %s" % omitted
		)
		fresh.queue_free()
		await wait_physics_frames(1)


func test_the_docket_is_handed_over_and_the_uniform_is_kept() -> void:
	_carry(SUPPLY_SUB_KIT)
	_at_time(SUPPLY_WINDOW_MINUTE)
	rig.session.attempt_escape(&"moon_pool", &"sub_dock")

	assert_false(rig.session.inventory.has(&"forged_docket"))
	assert_true(rig.session.inventory.has(&"officer_uniform"))


# ---------------------------------------------------------------- refusals


func test_a_route_cannot_be_boarded_from_the_wrong_place() -> void:
	_carry(SUBMERSIBLE_KIT)
	assert_eq(
		rig.session.attempt_escape(&"galley", &"hangar_door"), EscapeRoutes.Result.WRONG_PLACE
	)
	assert_eq(
		rig.session.attempt_escape(&"hangar", &"sub_dock"), EscapeRoutes.Result.WRONG_PLACE
	)


func test_a_detained_player_cannot_leave() -> void:
	_carry(SUBMERSIBLE_KIT)
	rig.session.player_state.begin_escort()
	assert_eq(
		rig.session.attempt_escape(&"hangar", &"hangar_door"), EscapeRoutes.Result.DETAINED
	)


func test_the_security_office_starts_with_a_uniform_worth_stealing() -> void:
	var office := rig.map.zone_by_id(&"security_office")
	var found := false
	for cell in rig.session.stashes:
		if office.contains(cell) and (rig.session.stashes[cell] as Stash).has(&"officer_uniform"):
			found = true
	assert_true(found, "the supply-sub route has no uniform to start from")
