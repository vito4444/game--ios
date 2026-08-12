class_name Oxygen
extends RefCounted

## Breathing where there is nothing to breathe.
##
## The hangar sits outside the pressure hull. Entering it starts a countdown
## that only a bottle can hold off, and running it down is what makes the
## submersible route a race rather than a shopping list. How long a bottle
## lasts is a function of Pressure tolerance, so training has a visible payoff.

signal entered_unpressurised()
signal left_unpressurised()
signal changed(seconds_left: float, capacity: float)
signal bottle_spent(remaining_bottles: int)
signal blacked_out()

const BOTTLE_ITEM := &"oxygen_bottle"
const REBREATHER_ITEM := &"rebreather"
const UNPRESSURISED_FLAG := &"unpressurised"

## A rebreather is worth this many bottles' worth of air.
const REBREATHER_MULTIPLIER := 2.5

## Air comes back this many times faster than it goes.
const RECOVERY_RATE := 3.0

var seconds_left: float = 0.0
var capacity: float = 0.0
var exposed: bool = false

var _stats: Stats
var _inventory: Inventory


func _init(stats: Stats, inventory: Inventory) -> void:
	_stats = stats
	_inventory = inventory
	capacity = _capacity_now()
	seconds_left = capacity


## Air available if the player steps outside right now.
func _capacity_now() -> float:
	var base := _stats.oxygen_seconds()
	if _inventory.has(REBREATHER_ITEM):
		return base * REBREATHER_MULTIPLIER
	return base


func fraction() -> float:
	return 0.0 if capacity <= 0.0 else clampf(seconds_left / capacity, 0.0, 1.0)


func has_air() -> bool:
	return seconds_left > 0.0


func bottles() -> int:
	return _inventory.count_of(BOTTLE_ITEM)


## Whether the player may enter unpressurised space at all.
func can_breathe_outside() -> bool:
	return seconds_left > 0.0 or bottles() > 0 or _inventory.has(REBREATHER_ITEM)


func refill() -> void:
	capacity = _capacity_now()
	seconds_left = capacity
	changed.emit(seconds_left, capacity)


## Advances the countdown. `in_unpressurised` comes from the player's zone.
func tick(delta: float, in_unpressurised: bool) -> void:
	if in_unpressurised != exposed:
		exposed = in_unpressurised
		if exposed:
			capacity = _capacity_now()
			entered_unpressurised.emit()
		else:
			left_unpressurised.emit()

	if not exposed:
		if seconds_left < capacity:
			seconds_left = minf(capacity, seconds_left + delta * RECOVERY_RATE)
			changed.emit(seconds_left, capacity)
		return

	seconds_left = maxf(0.0, seconds_left - delta)
	changed.emit(seconds_left, capacity)

	if seconds_left > 0.0:
		return

	# Out of air: crack a fresh bottle if there is one, otherwise pass out.
	if _inventory.remove(BOTTLE_ITEM):
		capacity = _capacity_now()
		seconds_left = capacity
		bottle_spent.emit(bottles())
		changed.emit(seconds_left, capacity)
		return

	blacked_out.emit()
