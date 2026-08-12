class_name Suspicion
extends RefCounted

## How closely security is watching the player, 0 to 100.
##
## Feeds patrol density and shakedown frequency in later phases; for now it is
## the consequence of missing a muster.

signal changed(value: int)
signal threshold_crossed(level: StringName)

const MAXIMUM := 100

## Missing a muster is the single most expensive routine mistake available.
const MISSED_ROLL_CALL := 25

## Passive decay per game hour of behaving normally.
const HOURLY_DECAY := 2

const CALM_BELOW := 25
const WATCHED_BELOW := 60
const HUNTED_AT := 100

var value: int = 0:
	set(new_value):
		var clamped := clampi(new_value, 0, MAXIMUM)
		if clamped == value:
			return
		var previous_level := level()
		value = clamped
		changed.emit(value)
		if level() != previous_level:
			threshold_crossed.emit(level())


func add(amount: int) -> void:
	value = value + amount


func reduce(amount: int) -> void:
	value = value - amount


func decay_for_hours(hours: float) -> void:
	value = value - int(floorf(hours * HOURLY_DECAY))


func level() -> StringName:
	if value >= HUNTED_AT:
		return &"hunted"
	if value >= WATCHED_BELOW:
		return &"searched"
	if value >= CALM_BELOW:
		return &"watched"
	return &"calm"


func is_at_maximum() -> bool:
	return value >= MAXIMUM
