extends GutTest

## Oxygen, blackouts, and the hatch that keeps the player out of the hangar.

const MAP_PATH := "res://data/maps/abyss9.map"

var session: Session
var map: RigMap


func before_each() -> void:
	map = RigMap.load_from(MAP_PATH)
	session = Session.new(map)


func _cell_in(zone_id: StringName) -> Vector2i:
	var zone := map.zone_by_id(zone_id)
	return zone.rect.position + Vector2i(1, 1)


# ---------------------------------------------------------------- oxygen


func test_the_hangar_is_the_unpressurised_part_of_the_rig() -> void:
	var flagged := []
	for zone in map.zones_with_flag(Oxygen.UNPRESSURISED_FLAG):
		flagged.append(String(zone.id))
	assert_eq(flagged, ["hangar"])
	assert_true(map.cell_has_flag(_cell_in(&"hangar"), Oxygen.UNPRESSURISED_FLAG))
	assert_false(map.cell_has_flag(_cell_in(&"galley"), Oxygen.UNPRESSURISED_FLAG))


func test_a_bottle_lasts_forty_seconds_at_base_pressure_tolerance() -> void:
	assert_almost_eq(session.oxygen.capacity, 40.0, 0.001)


func test_air_drains_one_second_per_second_outside_the_hull() -> void:
	session.oxygen.tick(1.0, true)
	assert_almost_eq(session.oxygen.seconds_left, 39.0, 0.001)
	session.oxygen.tick(4.0, true)
	assert_almost_eq(session.oxygen.seconds_left, 35.0, 0.001)


func test_air_does_not_drain_inside_the_hull() -> void:
	session.oxygen.tick(10.0, false)
	assert_almost_eq(session.oxygen.seconds_left, 40.0, 0.001)


func test_air_comes_back_faster_than_it_goes() -> void:
	session.oxygen.tick(20.0, true)
	assert_almost_eq(session.oxygen.seconds_left, 20.0, 0.001)

	session.oxygen.tick(1.0, false)
	assert_almost_eq(session.oxygen.seconds_left, 23.0, 0.001)


func test_pressure_tolerance_buys_more_time_outside() -> void:
	session.stats.set_level(Stats.PRESSURE, 3)
	session.oxygen.refill()
	assert_almost_eq(session.oxygen.capacity, 60.0, 0.001)

	session.oxygen.tick(50.0, true)
	assert_almost_eq(session.oxygen.seconds_left, 10.0, 0.001)
	assert_true(session.oxygen.has_air(), "a trained diver should still be conscious")


func test_running_out_swaps_in_a_spare_bottle_before_passing_out() -> void:
	session.inventory.add(&"oxygen_bottle")
	session.oxygen.tick(40.0, true)

	assert_almost_eq(session.oxygen.seconds_left, 40.0, 0.001)
	assert_false(session.inventory.has(&"oxygen_bottle"), "the spare should be used up")
	assert_eq(session.player_state.state, PlayerState.FREE)


func test_a_rebreather_multiplies_the_air_available() -> void:
	session.inventory.add(&"rebreather")
	session.oxygen.refill()
	assert_almost_eq(session.oxygen.capacity, 100.0, 0.001)


func test_running_out_with_no_spare_knocks_the_player_out_in_the_infirmary() -> void:
	session.inventory.add(&"cutting_torch")
	var woke_at: Array[Vector2i] = []
	session.player_blacked_out.connect(func(cell: Vector2i) -> void: woke_at.append(cell))

	session.oxygen.tick(41.0, true)

	assert_eq(session.player_state.state, PlayerState.UNCONSCIOUS)
	assert_eq(woke_at.size(), 1)
	assert_eq(map.zone_at(woke_at[0]).id, &"infirmary", "should wake in the infirmary")
	assert_eq(session.inventory.contraband_count(), 0, "contraband is logged and taken")
	assert_eq(session.times_blacked_out, 1)


func test_the_player_comes_round_after_ninety_minutes() -> void:
	session.oxygen.tick(41.0, true)
	assert_eq(session.player_state.state, PlayerState.UNCONSCIOUS)

	session.clock.advance_minutes(Session.INFIRMARY_MINUTES - 1)
	assert_eq(session.player_state.state, PlayerState.UNCONSCIOUS, "woke up early")

	session.clock.advance_minutes(1)
	assert_eq(session.player_state.state, PlayerState.FREE)
	assert_almost_eq(session.oxygen.seconds_left, session.oxygen.capacity, 0.001)


func test_oxygen_only_ticks_while_the_player_is_up_and_about() -> void:
	session.player_state.send_to_solitary("test")
	session.tick_oxygen(10.0, _cell_in(&"hangar"))
	assert_almost_eq(session.oxygen.seconds_left, 40.0, 0.001)


func test_the_session_ticks_oxygen_from_the_players_cell() -> void:
	session.tick_oxygen(5.0, _cell_in(&"hangar"))
	assert_almost_eq(session.oxygen.seconds_left, 35.0, 0.001)

	session.tick_oxygen(1.0, _cell_in(&"galley"))
	assert_gt(session.oxygen.seconds_left, 35.0, "air should recover indoors")


# ---------------------------------------------------------------- blackouts


func test_the_power_dips_twice_a_day_at_the_specified_times() -> void:
	assert_eq(Blackout.TIMES, [120, 840] as Array[int])
	assert_almost_eq(Blackout.DURATION_SECONDS, 45.0, 0.001)


func test_a_blackout_starts_when_the_clock_reaches_its_time() -> void:
	var events := [0]
	session.blackout.started.connect(func() -> void: events[0] += 1)

	session.clock.advance_to_minute_of_day(14 * 60)
	assert_true(session.blackout.active)
	assert_eq(events[0], 1)


func test_a_blackout_ends_after_forty_five_real_seconds() -> void:
	session.clock.advance_to_minute_of_day(14 * 60)
	assert_true(session.blackout.active)

	session.blackout.tick(44.0)
	assert_true(session.blackout.active, "ended early")

	session.blackout.tick(1.0)
	assert_false(session.blackout.active)


func test_officer_sight_is_cut_to_the_configured_fraction() -> void:
	assert_almost_eq(session.blackout.vision_scale(), 1.0, 0.001)
	session.blackout.begin()
	assert_almost_eq(session.blackout.vision_scale(), 0.35, 0.001)

	var normal := Vision.Cone.new()
	var dimmed := normal.scaled(session.blackout.vision_scale())
	assert_almost_eq(dimmed.range_tiles, Vision.DEFAULT_RANGE_TILES * 0.35, 0.001)
	assert_almost_eq(
		dimmed.half_angle_degrees, normal.half_angle_degrees, 0.001, "only range shrinks"
	)


func test_the_countdown_to_the_next_blackout_wraps_around_the_day() -> void:
	assert_eq(session.blackout.minutes_until_next(0), 120)
	assert_eq(session.blackout.minutes_until_next(120), 0)
	assert_eq(session.blackout.minutes_until_next(121), 719)
	assert_eq(session.blackout.minutes_until_next(900), 660)


func test_the_two_oclock_blackout_lines_up_with_the_supply_sub_window() -> void:
	var supply := session.escape_routes.by_id(&"supply_sub")
	assert_true(
		supply.window_contains(Blackout.TIMES[0]),
		"the timed route should be reachable under cover of the power dip"
	)


# ---------------------------------------------------------------- hatches


func test_the_hangar_hatch_stays_shut_for_an_empty_handed_player() -> void:
	var hatch := _hangar_hatch()
	session.doors.update([{"cell": Vector2(hatch), "staff": false}])
	assert_false(session.doors.is_open(hatch))


func test_a_door_shim_opens_the_hangar_hatch() -> void:
	var hatch := _hangar_hatch()
	session.inventory.add(&"door_shim")
	session.doors.update(
		[{"cell": Vector2(hatch), "staff": session.inventory.has(DoorSystem.OVERRIDE_ITEM)}]
	)
	assert_true(session.doors.is_open(hatch))


func _hangar_hatch() -> Vector2i:
	## The hatch on the corridor wall above the hangar.
	for cell in map.door_cells():
		if map.door_kind(cell) == TileCatalog.PRESSURE_HATCH and cell.y > 20:
			return cell
	return Vector2i(-1, -1)
