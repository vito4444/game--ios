class_name Stash
extends RefCounted

## A locker, with a compartment behind the panel.
##
## Anything on the open shelf is found the moment a locker is searched. The
## hidden compartment is only found some of the time, which is what makes
## deciding where to leave a half-built torch overnight interesting.

signal changed()

const SHELF_SLOTS := 6
const HIDDEN_SLOTS := 3

## Chance per item that a search turns over the hidden compartment. Scaled up by
## how thorough the search is.
const BASE_DISCOVERY_CHANCE := 0.25

var cell: Vector2i
var shelf: Array[StringName] = []
var hidden: Array[StringName] = []

var _catalog: ItemCatalog


func _init(catalog: ItemCatalog, stash_cell: Vector2i) -> void:
	_catalog = catalog
	cell = stash_cell


func store(id: StringName, hide: bool = false) -> bool:
	var target := hidden if hide else shelf
	var limit := HIDDEN_SLOTS if hide else SHELF_SLOTS
	if _slots_used(target) + _catalog.size_of(id) > limit:
		return false
	target.append(id)
	changed.emit()
	return true


func take(id: StringName) -> bool:
	for target in [shelf, hidden]:
		var index: int = target.find(id)
		if index >= 0:
			target.remove_at(index)
			changed.emit()
			return true
	return false


func contents() -> Array[StringName]:
	var all: Array[StringName] = []
	all.append_array(shelf)
	all.append_array(hidden)
	return all


func has(id: StringName) -> bool:
	return shelf.has(id) or hidden.has(id)


func is_empty() -> bool:
	return shelf.is_empty() and hidden.is_empty()


func free_shelf_slots() -> int:
	return SHELF_SLOTS - _slots_used(shelf)


func free_hidden_slots() -> int:
	return HIDDEN_SLOTS - _slots_used(hidden)


## Removes what a search would find. `thoroughness` scales the chance of the
## hidden compartment being opened at all.
func search(rng: RandomNumberGenerator, thoroughness: float = 1.0) -> Array[StringName]:
	var seized: Array[StringName] = []

	for id in shelf.duplicate():
		if not _catalog.is_contraband(id):
			continue
		shelf.erase(id)
		seized.append(id)

	for id in hidden.duplicate():
		if not _catalog.is_contraband(id):
			continue
		if rng.randf() >= BASE_DISCOVERY_CHANCE * thoroughness:
			continue
		hidden.erase(id)
		seized.append(id)

	if not seized.is_empty():
		changed.emit()
	return seized


func to_dictionary() -> Dictionary:
	return {"cell": [cell.x, cell.y], "shelf": shelf.duplicate(), "hidden": hidden.duplicate()}


func _slots_used(target: Array[StringName]) -> int:
	var used := 0
	for id in target:
		used += _catalog.size_of(id)
	return used
