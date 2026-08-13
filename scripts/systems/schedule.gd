class_name Schedule
extends RefCounted

## The rig's daily timetable, loaded from data/schedule/*.json.
##
## Times are stored as minutes past midnight so comparisons and wrap-around
## arithmetic stay integer maths.

const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 1440


class Event:
	var id: StringName
	var label: String
	var minute_of_day: int
	var zone: StringName
	var roll_call: bool
	var duration_minutes: int

	func _init(data: Dictionary) -> void:
		id = StringName(data.get("id", ""))
		label = data.get("label", "")
		minute_of_day = (
			int(data.get("hour", 0)) * Schedule.MINUTES_PER_HOUR + int(data.get("minute", 0))
		)
		zone = StringName(data.get("zone", ""))
		roll_call = bool(data.get("roll_call", false))
		duration_minutes = int(data.get("duration_minutes", 0))

	func hour() -> int:
		return minute_of_day / Schedule.MINUTES_PER_HOUR

	func minute() -> int:
		return minute_of_day % Schedule.MINUTES_PER_HOUR

	func clock_text() -> String:
		return "%02d:%02d" % [hour(), minute()]

	## When the roll call for this event is judged.
	func deadline_minute_of_day() -> int:
		return (minute_of_day + duration_minutes) % Schedule.MINUTES_PER_DAY


var events: Array[Event] = []
var errors: PackedStringArray = PackedStringArray()


static func load_from(path: String) -> Schedule:
	var schedule := Schedule.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		schedule.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return schedule

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		schedule.errors.append("%s is not a JSON object" % path)
		return schedule

	var raw_events: Variant = (parsed as Dictionary).get("events", [])
	if typeof(raw_events) != TYPE_ARRAY:
		schedule.errors.append("%s has no events array" % path)
		return schedule

	for entry in raw_events as Array:
		schedule.events.append(Event.new(entry as Dictionary))
	schedule._validate()
	return schedule


func is_valid() -> bool:
	return errors.is_empty()


func size() -> int:
	return events.size()


func by_id(id: StringName) -> Event:
	for event in events:
		if event.id == id:
			return event
	return null


func roll_calls() -> Array[Event]:
	var found: Array[Event] = []
	for event in events:
		if event.roll_call:
			found.append(event)
	return found


## Events that begin exactly at this time of day.
func events_at(minute_of_day: int) -> Array[Event]:
	var found: Array[Event] = []
	for event in events:
		if event.minute_of_day == minute_of_day:
			found.append(event)
	return found


## Events whose start minute falls in (from_minute, to_minute], in order.
## Both bounds are absolute minutes since the game began, so a range spanning
## midnight or several days returns each day's occurrence.
func events_in_range(from_minute: int, to_minute: int) -> Array[Event]:
	var found: Array[Event] = []
	for minute in range(from_minute + 1, to_minute + 1):
		var minute_of_day := ((minute % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
		found.append_array(events_at(minute_of_day))
	return found


## The event in force at a given time, which is the latest one to have started.
func active_at(minute_of_day: int) -> Event:
	var current: Event = null
	var best := -1
	for event in events:
		if event.minute_of_day <= minute_of_day and event.minute_of_day > best:
			best = event.minute_of_day
			current = event
	if current == null and not events.is_empty():
		# Before the first event of the day the previous night's block still runs.
		current = events[events.size() - 1]
	return current


func _validate() -> void:
	if events.is_empty():
		errors.append("schedule has no events")
		return

	var seen := {}
	var previous := -1
	for event in events:
		if event.id == &"":
			errors.append("event at %s has no id" % event.clock_text())
		if seen.has(event.id):
			errors.append("duplicate event id: %s" % event.id)
		seen[event.id] = true

		if event.minute_of_day < 0 or event.minute_of_day >= MINUTES_PER_DAY:
			errors.append("%s is outside a 24-hour day" % event.id)
		if event.minute_of_day <= previous:
			errors.append("%s is out of chronological order" % event.id)
		previous = event.minute_of_day

		if event.duration_minutes <= 0:
			errors.append("%s needs a positive duration" % event.id)
		if event.roll_call and event.zone == &"":
			errors.append("%s is a roll call but names no zone" % event.id)
