class_name Blackout
extends RefCounted

## The rig's scheduled power dips.
##
## Twice a day the lights and cameras drop for three quarters of a minute.
## Officers can still see, but not far, which turns a corridor that is
## impassable at noon into the only way across the rig. Both routes are built
## around being somewhere specific when this happens.

signal started()
signal ended()

## Minutes past midnight. 02:00 lines up with the supply sub's window, so the
## one route that depends on timing has a reason to care about both.
const TIMES: Array[int] = [120, 840]

## Real seconds, not game minutes: the point is to be a scramble.
const DURATION_SECONDS := 45.0

## Officer sight range is multiplied by this while the power is down.
const VISION_SCALE := 0.35

var active: bool = false
var seconds_remaining: float = 0.0


func _init(clock: GameClock) -> void:
	clock.minute_passed.connect(_on_minute_passed)


func vision_scale() -> float:
	return VISION_SCALE if active else 1.0


func begin() -> void:
	if active:
		return
	active = true
	seconds_remaining = DURATION_SECONDS
	started.emit()


func tick(delta: float) -> void:
	if not active:
		return
	seconds_remaining -= delta
	if seconds_remaining > 0.0:
		return
	seconds_remaining = 0.0
	active = false
	ended.emit()


## Next blackout as minutes from now, for the interface to count down to.
func minutes_until_next(minute_of_day: int) -> int:
	var best := Schedule.MINUTES_PER_DAY
	for time in TIMES:
		var delta := time - minute_of_day
		if delta < 0:
			delta += Schedule.MINUTES_PER_DAY
		best = mini(best, delta)
	return best


func _on_minute_passed(minute_of_day: int, _day: int) -> void:
	if TIMES.has(minute_of_day):
		begin()
