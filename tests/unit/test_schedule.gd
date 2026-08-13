extends GutTest

## The shipped timetable, and the parser's willingness to reject a broken one.

const SCHEDULE_PATH := "res://data/schedule/daily.json"

## The full day, written out. If the JSON changes, this list is the thing that
## has to agree with it.
const EXPECTED := [
	["wake", 6, 0, "", false],
	["breakfast", 7, 0, "galley", false],
	["morning_muster", 8, 0, "muster_deck", true],
	["shift_start", 8, 30, "", false],
	["lunch", 12, 0, "galley", false],
	["free_period", 14, 0, "", false],
	["training_window", 16, 0, "", false],
	["dinner", 18, 0, "galley", false],
	["evening_muster", 20, 0, "muster_deck", true],
	["lights_out", 22, 0, "bunk_pods", false],
]

var schedule: Schedule


func before_each() -> void:
	schedule = Schedule.load_from(SCHEDULE_PATH)


func test_schedule_loads_without_errors() -> void:
	assert_eq(schedule.errors, PackedStringArray())
	assert_true(schedule.is_valid())


func test_day_has_exactly_ten_events() -> void:
	assert_eq(schedule.size(), 10)


func test_every_event_matches_the_specified_time_zone_and_kind() -> void:
	for index in EXPECTED.size():
		var expected: Array = EXPECTED[index]
		var event: Schedule.Event = schedule.events[index]
		assert_eq(String(event.id), expected[0], "event %d id" % index)
		assert_eq(event.hour(), expected[1], "%s hour" % expected[0])
		assert_eq(event.minute(), expected[2], "%s minute" % expected[0])
		assert_eq(String(event.zone), expected[3], "%s zone" % expected[0])
		assert_eq(event.roll_call, expected[4], "%s roll_call" % expected[0])


func test_the_two_musters_are_the_only_roll_calls() -> void:
	var ids := []
	for event in schedule.roll_calls():
		ids.append(String(event.id))
	assert_eq(ids, ["morning_muster", "evening_muster"])


func test_muster_deadline_is_thirty_minutes_after_it_opens() -> void:
	var muster := schedule.by_id(&"morning_muster")
	assert_eq(muster.minute_of_day, 8 * 60)
	assert_eq(muster.deadline_minute_of_day(), 8 * 60 + 30)


func test_active_event_is_the_most_recent_one_to_have_started() -> void:
	assert_eq(schedule.active_at(6 * 60).id, &"wake")
	assert_eq(schedule.active_at(8 * 60 + 15).id, &"morning_muster")
	assert_eq(schedule.active_at(11 * 60).id, &"shift_start")
	assert_eq(schedule.active_at(23 * 60).id, &"lights_out")
	# Before the first event of the day, last night's block is still running.
	assert_eq(schedule.active_at(2 * 60).id, &"lights_out")


func test_events_in_range_is_exclusive_at_the_start_and_inclusive_at_the_end() -> void:
	var crossing := schedule.events_in_range(7 * 60, 8 * 60)
	assert_eq(crossing.size(), 1)
	assert_eq(crossing[0].id, &"morning_muster")

	assert_eq(schedule.events_in_range(8 * 60, 8 * 60).size(), 0)
	assert_eq(schedule.events_in_range(8 * 60 - 1, 8 * 60).size(), 1)


func test_events_in_range_wraps_past_midnight() -> void:
	var overnight := schedule.events_in_range(23 * 60, 24 * 60 + 7 * 60)
	var ids := []
	for event in overnight:
		ids.append(String(event.id))
	assert_eq(ids, ["wake", "breakfast"])


func test_parser_rejects_events_out_of_chronological_order() -> void:
	var broken := _from_events([
		{"id": "late", "hour": 9, "minute": 0, "duration_minutes": 60},
		{"id": "early", "hour": 7, "minute": 0, "duration_minutes": 60},
	])
	assert_string_contains(" ".join(broken.errors), "out of chronological order")


func test_parser_rejects_duplicate_ids() -> void:
	var broken := _from_events([
		{"id": "same", "hour": 7, "minute": 0, "duration_minutes": 60},
		{"id": "same", "hour": 9, "minute": 0, "duration_minutes": 60},
	])
	assert_string_contains(" ".join(broken.errors), "duplicate event id")


func test_parser_rejects_a_roll_call_without_a_zone() -> void:
	var broken := _from_events([
		{"id": "muster", "hour": 7, "minute": 0, "duration_minutes": 30, "roll_call": true},
	])
	assert_string_contains(" ".join(broken.errors), "names no zone")


func _from_events(events: Array) -> Schedule:
	var path := "user://test_schedule.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"events": events}))
	file.close()
	return Schedule.load_from(path)
