class_name Shakedown
extends RefCounted

## Searches. Both the pat-down at muster and the sweep of the bunk pods.
##
## Every roll of the dice comes from one seeded generator, so a run can be
## replayed exactly and a test can assert on specific outcomes rather than on
## "something was probably found".

signal player_searched(seized: Array)
signal stash_searched(cell: Vector2i, seized: Array)
signal search_avoided()

## Chance of being pulled aside at a muster while behaving normally.
const BASE_PAT_DOWN_CHANCE := 0.20

## Extra chance at maximum suspicion, added on top of the base.
const SUSPICION_PAT_DOWN_BONUS := 0.55

## Chance any given locker is opened during a sweep.
const LOCKER_SWEEP_CHANCE := 0.35

## Sweeps happen while everyone is at the evening muster.
const SWEEP_EVENT := &"evening_muster"

var rng: RandomNumberGenerator

var _inventory: Inventory
var _suspicion: Suspicion
var _stashes: Dictionary


func _init(inventory: Inventory, suspicion: Suspicion, stashes: Dictionary, seed_value: int = 0):
	_inventory = inventory
	_suspicion = suspicion
	_stashes = stashes
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value


func pat_down_chance() -> float:
	var scale := float(_suspicion.value) / float(Suspicion.MAXIMUM)
	return BASE_PAT_DOWN_CHANCE + SUSPICION_PAT_DOWN_BONUS * scale


## Rolls for a pat-down at a muster. Returns what was taken, empty if the player
## was waved through or was clean.
func attempt_pat_down() -> Array[StringName]:
	if rng.randf() >= pat_down_chance():
		search_avoided.emit()
		return []

	var seized := _inventory.confiscate_contraband()
	player_searched.emit(seized)
	if not seized.is_empty():
		_suspicion.add(Infractions.SUSPICION_COST[Infractions.Kind.CARRYING_CONTRABAND])
	return seized


## Sweeps the lockers. Thoroughness rises with suspicion, so a watched player's
## hiding places stop being reliable.
func sweep_lockers() -> Dictionary:
	var thoroughness := 1.0 + float(_suspicion.value) / float(Suspicion.MAXIMUM)
	var results := {}
	for cell in _stashes:
		if rng.randf() >= LOCKER_SWEEP_CHANCE:
			continue
		var stash: Stash = _stashes[cell]
		var seized := stash.search(rng, thoroughness)
		if seized.is_empty():
			continue
		results[cell] = seized
		stash_searched.emit(cell, seized)
	return results
