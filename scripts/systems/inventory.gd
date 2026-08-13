class_name Inventory
extends RefCounted

## What the player is carrying.
##
## Capacity is counted in slots rather than item count, so a drive housing
## costs three times what a ration tin does. Carrying an escape route's worth of
## parts therefore means walking past a search with almost no room to spare.

signal changed()
signal confiscated(ids: Array)

const DEFAULT_CAPACITY := 10

var capacity: int
var _catalog: ItemCatalog
var _ids: Array[StringName] = []


func _init(catalog: ItemCatalog, slots: int = DEFAULT_CAPACITY) -> void:
	_catalog = catalog
	capacity = slots


func ids() -> Array[StringName]:
	return _ids.duplicate()


func count() -> int:
	return _ids.size()


func used_slots() -> int:
	var used := 0
	for id in _ids:
		used += _catalog.size_of(id)
	return used


func free_slots() -> int:
	return capacity - used_slots()


func size_of_item(id: StringName) -> int:
	return _catalog.size_of(id)


func can_add(id: StringName) -> bool:
	return _catalog.has(id) and _catalog.size_of(id) <= free_slots()


func add(id: StringName) -> bool:
	if not can_add(id):
		return false
	_ids.append(id)
	changed.emit()
	return true


func remove(id: StringName) -> bool:
	var index := _ids.find(id)
	if index < 0:
		return false
	_ids.remove_at(index)
	changed.emit()
	return true


func has(id: StringName) -> bool:
	return _ids.has(id)


func count_of(id: StringName) -> int:
	return _ids.count(id)


func clear() -> void:
	if _ids.is_empty():
		return
	_ids.clear()
	changed.emit()


func contraband() -> Array[StringName]:
	var found: Array[StringName] = []
	for id in _ids:
		if _catalog.is_contraband(id):
			found.append(id)
	return found


func contraband_count() -> int:
	return contraband().size()


func is_carrying_contraband() -> bool:
	return contraband_count() > 0


## Removes every contraband item and returns what was taken.
func confiscate_contraband() -> Array[StringName]:
	var taken := contraband()
	if taken.is_empty():
		return taken
	var kept: Array[StringName] = []
	for id in _ids:
		if not _catalog.is_contraband(id):
			kept.append(id)
	_ids = kept
	confiscated.emit(taken)
	changed.emit()
	return taken
