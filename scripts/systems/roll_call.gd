class_name RollCall
extends RefCounted

## Judges muster attendance.
##
## Attendance is checked once, when the muster window closes, rather than
## continuously. Turning up late but before the deadline counts, which is what
## makes "can I make it back in time" a decision worth taking a risk over.

signal started(event: Schedule.Event, deadline_minute: int)
signal attended(event: Schedule.Event)
signal missed(event: Schedule.Event, penalty: int)

var _clock: GameClock
var _suspicion: Suspicion
var _locate_player: Callable

var _pending: Schedule.Event = null
var _deadline_minute: int = -1


func _init(clock: GameClock, suspicion: Suspicion) -> void:
	_clock = clock
	_suspicion = suspicion
	_clock.event_started.connect(_on_event_started)
	_clock.minute_passed.connect(_on_minute_passed)


## `locator` returns the zone id the player is standing in, or &"" for none.
func bind_player_locator(locator: Callable) -> void:
	_locate_player = locator


func is_active() -> bool:
	return _pending != null


func pending_event() -> Schedule.Event:
	return _pending


func deadline_minute() -> int:
	return _deadline_minute


func _on_event_started(event: Schedule.Event) -> void:
	if not event.roll_call:
		return
	_pending = event
	_deadline_minute = event.deadline_minute_of_day()
	started.emit(event, _deadline_minute)


func _on_minute_passed(minute_of_day: int, _day: int) -> void:
	if _pending == null or minute_of_day != _deadline_minute:
		return

	var event := _pending
	_pending = null
	_deadline_minute = -1

	if _player_zone() == event.zone:
		attended.emit(event)
		return
	_suspicion.add(Suspicion.MISSED_ROLL_CALL)
	missed.emit(event, Suspicion.MISSED_ROLL_CALL)


func _player_zone() -> StringName:
	if not _locate_player.is_valid():
		return &""
	return _locate_player.call()
