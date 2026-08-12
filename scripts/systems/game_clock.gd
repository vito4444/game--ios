class_name GameClock
extends RefCounted

## Rig time, advanced in game-minutes.
##
## Deliberately not a Node: tests skip a whole day with advance(1440) instead of
## waiting on frames, and the caller decides whether real time drives it.

signal minute_passed(minute_of_day: int, day: int)
signal event_started(event: Schedule.Event)
signal day_started(day: int)

## A full day takes twelve real minutes, which is roughly the pace The
## Escapists runs at: long enough to plan around, short enough that waiting for
## a specific hour is not dead time.
const MINUTES_PER_SECOND := 2.0

const MINUTES_PER_DAY := Schedule.MINUTES_PER_DAY

var schedule: Schedule

var _total_minutes: float = 0.0
var _last_whole_minute: int = 0


func _init(clock_schedule: Schedule, start_minute_of_day: int = 6 * 60) -> void:
	schedule = clock_schedule
	_total_minutes = float(start_minute_of_day)
	_last_whole_minute = start_minute_of_day


func total_minutes() -> int:
	return int(_total_minutes)


func minute_of_day() -> int:
	return total_minutes() % MINUTES_PER_DAY


func day() -> int:
	return total_minutes() / MINUTES_PER_DAY


func hour() -> int:
	return minute_of_day() / Schedule.MINUTES_PER_HOUR


func clock_text() -> String:
	return "%02d:%02d" % [hour(), minute_of_day() % Schedule.MINUTES_PER_HOUR]


func current_event() -> Schedule.Event:
	return schedule.active_at(minute_of_day())


## Advance by real seconds.
func tick(delta_seconds: float) -> void:
	advance_minutes(delta_seconds * MINUTES_PER_SECOND)


## Advance by game minutes, emitting every event crossed on the way.
func advance_minutes(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var previous_day := day()
	_total_minutes += minutes
	var now := total_minutes()
	if now == _last_whole_minute:
		return

	# Minute by minute, events first. Emitting every event in the span before
	# any minute would let one jump start two roll calls before either was
	# judged, and the first would be silently dropped.
	for minute in range(_last_whole_minute + 1, now + 1):
		var minute_of_the_day := minute % MINUTES_PER_DAY
		for event in schedule.events_at(minute_of_the_day):
			event_started.emit(event)
		minute_passed.emit(minute_of_the_day, minute / MINUTES_PER_DAY)
	_last_whole_minute = now

	if day() != previous_day:
		day_started.emit(day())


## Jump forward to the next occurrence of a time of day, firing everything in
## between. Used by tests and by the "sleep until morning" action.
func advance_to_minute_of_day(target: int) -> void:
	var delta := target - minute_of_day()
	if delta <= 0:
		delta += MINUTES_PER_DAY
	advance_minutes(float(delta))
