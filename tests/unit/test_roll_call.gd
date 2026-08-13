extends GutTest

## Muster attendance and the penalty for skipping it.

const SCHEDULE_PATH := "res://data/schedule/daily.json"
const MUSTER_ZONE := &"muster_deck"

var clock: GameClock
var suspicion: Suspicion
var roll_call: RollCall
var player_zone: StringName


func before_each() -> void:
	var schedule := Schedule.load_from(SCHEDULE_PATH)
	clock = GameClock.new(schedule, Session.START_MINUTE_OF_DAY)
	suspicion = Suspicion.new()
	roll_call = RollCall.new(clock, suspicion)
	player_zone = &""
	roll_call.bind_player_locator(func() -> StringName: return player_zone)


func _advance_to_first_muster_deadline() -> void:
	clock.advance_to_minute_of_day(8 * 60 + 30)


func test_muster_opens_and_announces_its_deadline() -> void:
	var announced := []
	roll_call.started.connect(
		func(event: Schedule.Event, deadline: int) -> void:
			announced.append([String(event.id), deadline])
	)
	clock.advance_to_minute_of_day(8 * 60)
	assert_eq(announced, [["morning_muster", 8 * 60 + 30]])
	assert_true(roll_call.is_active())


func test_standing_on_the_muster_deck_passes_and_costs_nothing() -> void:
	var attended := []
	roll_call.attended.connect(
		func(event: Schedule.Event) -> void: attended.append(String(event.id))
	)
	player_zone = MUSTER_ZONE
	_advance_to_first_muster_deadline()

	assert_eq(attended, ["morning_muster"])
	assert_eq(suspicion.value, 0)
	assert_false(roll_call.is_active())


func test_missing_the_muster_adds_exactly_twenty_five_suspicion() -> void:
	var missed := []
	roll_call.missed.connect(
		func(event: Schedule.Event, penalty: int) -> void:
			missed.append([String(event.id), penalty])
	)
	player_zone = &"galley"
	_advance_to_first_muster_deadline()

	assert_eq(missed, [["morning_muster", 25]])
	assert_eq(suspicion.value, 25)


func test_arriving_before_the_deadline_still_counts() -> void:
	player_zone = &"workshop"
	clock.advance_to_minute_of_day(8 * 60)
	clock.advance_minutes(20)
	assert_eq(suspicion.value, 0, "judged too early")

	player_zone = MUSTER_ZONE
	clock.advance_minutes(10)
	assert_eq(suspicion.value, 0, "on the deck by the deadline should pass")


func test_leaving_before_the_deadline_fails() -> void:
	player_zone = MUSTER_ZONE
	clock.advance_to_minute_of_day(8 * 60)
	clock.advance_minutes(20)
	player_zone = &"corridor"
	clock.advance_minutes(10)
	assert_eq(suspicion.value, 25)


func test_both_musters_are_judged_across_a_full_day() -> void:
	player_zone = &"galley"
	clock.advance_minutes(Schedule.MINUTES_PER_DAY)
	assert_eq(suspicion.value, 50, "two missed musters at 25 each")


func test_non_muster_events_are_never_judged() -> void:
	player_zone = &"hangar"
	clock.advance_to_minute_of_day(7 * 60)
	clock.advance_minutes(59)
	assert_eq(suspicion.value, 0, "breakfast is not a roll call")
	assert_false(roll_call.is_active())


func test_suspicion_is_clamped_and_reports_a_level() -> void:
	assert_eq(suspicion.level(), &"calm")
	suspicion.add(Suspicion.MISSED_ROLL_CALL)
	assert_eq(suspicion.level(), &"watched")
	suspicion.add(100)
	assert_eq(suspicion.value, 100)
	assert_eq(suspicion.level(), &"hunted")
	assert_true(suspicion.is_at_maximum())
	suspicion.reduce(1000)
	assert_eq(suspicion.value, 0)


func test_suspicion_decays_while_behaving() -> void:
	suspicion.add(50)
	suspicion.decay_for_hours(4.0)
	assert_eq(suspicion.value, 42, "2 per hour for four hours")
