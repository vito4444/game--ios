extends GutTest

## What security will arrest the player for, and what an arrest costs them.

const MAP_PATH := "res://data/maps/abyss9.map"

var session: Session
var map: RigMap


func before_each() -> void:
	map = RigMap.load_from(MAP_PATH)
	session = Session.new(map)


func _cell_in(zone_id: StringName) -> Vector2i:
	var zone := map.zone_by_id(zone_id)
	assert_not_null(zone, "map has no zone %s" % zone_id)
	return zone.rect.position + Vector2i(1, 1)


func test_session_builds_without_errors() -> void:
	assert_eq(session.errors, PackedStringArray())
	assert_true(session.is_valid())


func test_standing_in_a_corridor_during_the_day_is_not_an_infraction() -> void:
	var report := Infractions.evaluate(
		map, Vector2i(20, 11), session.schedule.by_id(&"free_period")
	)
	assert_false(report.is_violation())
	assert_eq(report.suspicion_cost(), 0)


func test_the_security_office_is_a_restricted_area() -> void:
	var report := Infractions.evaluate(
		map, _cell_in(&"security_office"), session.schedule.by_id(&"free_period")
	)
	assert_eq(report.kind, Infractions.Kind.RESTRICTED_AREA)
	assert_eq(report.suspicion_cost(), 20)


func test_the_hangar_is_a_restricted_area() -> void:
	var report := Infractions.evaluate(
		map, _cell_in(&"hangar"), session.schedule.by_id(&"free_period")
	)
	assert_eq(report.kind, Infractions.Kind.RESTRICTED_AREA)


func test_being_out_of_the_bunks_after_lights_out_is_an_infraction() -> void:
	var lights_out := session.schedule.by_id(&"lights_out")
	var in_galley := Infractions.evaluate(map, _cell_in(&"galley"), lights_out)
	assert_eq(in_galley.kind, Infractions.Kind.OUT_AFTER_LIGHTS_OUT)
	assert_eq(in_galley.suspicion_cost(), 15)

	var in_bunk := Infractions.evaluate(map, _cell_in(&"bunk_pods"), lights_out)
	assert_false(in_bunk.is_violation(), "the bunk pods are where you are meant to be")


func test_the_same_spot_is_fine_earlier_in_the_day() -> void:
	var report := Infractions.evaluate(
		map, _cell_in(&"galley"), session.schedule.by_id(&"dinner")
	)
	assert_false(report.is_violation())


func test_carrying_contraband_is_an_infraction_anywhere() -> void:
	var report := Infractions.evaluate(
		map, _cell_in(&"galley"), session.schedule.by_id(&"lunch"), true
	)
	assert_eq(report.kind, Infractions.Kind.CARRYING_CONTRABAND)
	assert_eq(report.suspicion_cost(), 30)


func test_arrest_confiscates_contraband_and_sends_the_player_to_solitary() -> void:
	session.inventory.add(&"ration")
	session.inventory.add(&"cutting_torch")
	session.inventory.add(&"nav_module")
	assert_eq(session.inventory.contraband_count(), 2)

	var taken := session.detain_player("caught in the hangar")

	assert_eq(session.player_state.state, PlayerState.SOLITARY)
	assert_eq(session.inventory.contraband_count(), 0)
	assert_eq(taken.size(), 2)
	assert_true(session.inventory.has(&"ration"), "legal items are not taken")


func test_arrest_emits_what_was_confiscated() -> void:
	var events := []
	session.player_detained.connect(
		func(reason: String, confiscated: Array) -> void: events.append([reason, confiscated.size()])
	)
	session.inventory.add(&"pry_bar")
	session.detain_player("out after lights out")
	assert_eq(events, [["out after lights out", 1]])


func test_the_sentence_runs_down_with_the_clock_and_then_releases() -> void:
	var released := [0]
	session.player_released.connect(func() -> void: released[0] += 1)
	session.detain_player("caught")

	session.clock.advance_minutes(PlayerState.SOLITARY_MINUTES - 1)
	assert_eq(session.player_state.state, PlayerState.SOLITARY, "released early")

	session.clock.advance_minutes(1)
	assert_eq(session.player_state.state, PlayerState.FREE)
	assert_eq(released[0], 1)


func test_the_solitary_cell_is_a_real_walkable_place_on_the_map() -> void:
	var cell := session.solitary_cell()
	assert_not_null(map.zone_by_id(&"solitary"))
	assert_false(map.is_solid(cell), "solitary cell %s is inside geometry" % cell)
	assert_eq(map.zone_at(cell).id, &"solitary")


func test_inventory_capacity_is_counted_in_slots_not_items() -> void:
	# Three drive parts are 3 + 2 + 3 = 8 of 10 slots.
	assert_true(session.inventory.add(&"drive_housing"))
	assert_true(session.inventory.add(&"drive_impeller"))
	assert_true(session.inventory.add(&"drive_core"))
	assert_eq(session.inventory.used_slots(), 8)
	assert_eq(session.inventory.free_slots(), 2)

	assert_true(session.inventory.add(&"cutting_torch"), "a 2-slot torch fits in 2 free slots")
	assert_eq(session.inventory.used_slots(), 10)

	assert_false(session.inventory.add(&"ration"), "nothing fits in a full pack")
	assert_eq(session.inventory.count(), 4)
