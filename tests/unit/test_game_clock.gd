extends GutTest

## Time advancement, and that a full day fires every scheduled event once.

const SCHEDULE_PATH := "res://data/schedule/daily.json"

const EXPECTED_DAY_ORDER := [
	"breakfast",
	"morning_muster",
	"shift_start",
	"lunch",
	"free_period",
	"training_window",
	"dinner",
	"evening_muster",
	"lights_out",
	"wake",
]

var schedule: Schedule
var clock: GameClock
var fired: Array[String]


func before_each() -> void:
	schedule = Schedule.load_from(SCHEDULE_PATH)
	clock = GameClock.new(schedule, Session.START_MINUTE_OF_DAY)
	fired = []
	clock.event_started.connect(func(event: Schedule.Event) -> void: fired.append(String(event.id)))


func test_clock_starts_at_six_in_the_morning_on_day_one() -> void:
	assert_eq(clock.minute_of_day(), 6 * 60)
	assert_eq(clock.clock_text(), "06:00")
	assert_eq(clock.day(), 0)


func test_twenty_four_hours_fires_all_ten_events_in_order() -> void:
	clock.advance_minutes(Schedule.MINUTES_PER_DAY)
	assert_eq(fired, EXPECTED_DAY_ORDER)
	assert_eq(fired.size(), 10)


func test_events_do_not_repeat_within_the_same_day() -> void:
	# 06:00 to 09:00 covers breakfast, the muster and the start of the shift.
	clock.advance_minutes(60 * 3)
	assert_eq(fired, ["breakfast", "morning_muster", "shift_start"])
	clock.advance_minutes(1)
	assert_eq(
		fired, ["breakfast", "morning_muster", "shift_start"], "an extra minute re-fired an event"
	)


func test_advancing_in_small_steps_fires_the_same_events_as_one_jump() -> void:
	for _step in range(Schedule.MINUTES_PER_DAY * 4):
		clock.advance_minutes(0.25)
	assert_eq(fired, EXPECTED_DAY_ORDER)


func test_real_seconds_convert_at_the_documented_rate() -> void:
	# 2 game-minutes per real second, so a day takes 12 real minutes.
	assert_eq(GameClock.MINUTES_PER_SECOND, 2.0)
	clock.tick(30.0)
	assert_eq(clock.minute_of_day(), 6 * 60 + 60)


func test_day_counter_advances_at_midnight() -> void:
	var days: Array[int] = []
	clock.day_started.connect(func(day: int) -> void: days.append(day))
	clock.advance_minutes(Schedule.MINUTES_PER_DAY)
	assert_eq(days, [1])
	assert_eq(clock.day(), 1)
	assert_eq(clock.clock_text(), "06:00")


func test_minute_passed_fires_once_per_game_minute() -> void:
	# Boxed in an array because GDScript lambdas capture locals by value.
	var count := [0]
	clock.minute_passed.connect(func(_minute: int, _day: int) -> void: count[0] += 1)
	clock.advance_minutes(90.0)
	assert_eq(count[0], 90)


func test_advancing_to_a_time_of_day_wraps_to_tomorrow_when_needed() -> void:
	clock.advance_to_minute_of_day(20 * 60)
	assert_eq(clock.clock_text(), "20:00")
	assert_eq(clock.day(), 0)

	clock.advance_to_minute_of_day(6 * 60)
	assert_eq(clock.clock_text(), "06:00")
	assert_eq(clock.day(), 1)


func test_current_event_tracks_the_clock() -> void:
	assert_eq(clock.current_event().id, &"wake")
	clock.advance_minutes(2 * 60 + 15)
	assert_eq(clock.current_event().id, &"morning_muster")
