class_name EscapeRoutes
extends RefCounted

## The ways off Abyss-9.
##
## Each route is checked the same way - place, kit, and sometimes a time window
## - so adding a third is a data change rather than a code change. The failure
## reasons are distinct because being told "not yet" without being told why is
## the difference between a puzzle and a wall.

signal escaped(route: Route)
signal attempt_failed(route: Route, result: Result)

const DEFAULT_PATH := "res://data/routes/routes.json"

enum Result { OK, WRONG_PLACE, MISSING_KIT, OUTSIDE_WINDOW, DETAINED }

const REASONS := {
	Result.OK: "Gone.",
	Result.WRONG_PLACE: "Nothing to board here.",
	Result.MISSING_KIT: "Not everything you need.",
	Result.OUTSIDE_WINDOW: "Nothing is due at this hour.",
	Result.DETAINED: "Not from in here.",
}


class Route:
	var id: StringName
	var name: String
	var summary: String
	var zone: StringName
	var prop: StringName
	var requires: Array[StringName]
	var consumes: Array[StringName]
	var window_from: int
	var window_to: int

	func _init(data: Dictionary) -> void:
		id = StringName(data.get("id", ""))
		name = data.get("name", "")
		summary = data.get("summary", "")
		zone = StringName(data.get("zone", ""))
		prop = StringName(data.get("prop", ""))
		requires = []
		for entry in data.get("requires", []) as Array:
			requires.append(StringName(entry))
		consumes = []
		for entry in data.get("consumes", []) as Array:
			consumes.append(StringName(entry))
		window_from = int(data.get("window_from", -1))
		window_to = int(data.get("window_to", -1))

	func has_window() -> bool:
		return window_from >= 0 and window_to >= 0

	func window_contains(minute_of_day: int) -> bool:
		if not has_window():
			return true
		if window_from <= window_to:
			return minute_of_day >= window_from and minute_of_day < window_to
		# A window that runs past midnight.
		return minute_of_day >= window_from or minute_of_day < window_to

	func window_text() -> String:
		if not has_window():
			return "any time"
		return "%02d:%02d-%02d:%02d" % [
			window_from / 60, window_from % 60, window_to / 60, window_to % 60
		]


var routes: Array[Route] = []
var errors: PackedStringArray = PackedStringArray()

var _inventory: Inventory
var _player_state: PlayerState


static func load_from(
	path: String, inventory: Inventory, player_state: PlayerState, catalog: ItemCatalog = null
) -> EscapeRoutes:
	var escape := EscapeRoutes.new()
	escape._inventory = inventory
	escape._player_state = player_state

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		escape.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return escape

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		escape.errors.append("%s is not a JSON object" % path)
		return escape

	for entry in (parsed as Dictionary).get("routes", []) as Array:
		escape.routes.append(Route.new(entry as Dictionary))
	escape._validate(catalog)
	return escape


static func reason_for(result: Result) -> String:
	return REASONS.get(result, "")


func is_valid() -> bool:
	return errors.is_empty()


func by_id(id: StringName) -> Route:
	for route in routes:
		if route.id == id:
			return route
	return null


func route_at(zone: StringName, prop: StringName) -> Route:
	for route in routes:
		if route.zone == zone and route.prop == prop:
			return route
	return null


## What is still missing for a route, for the interface to list.
func missing_for(route: Route) -> Array[StringName]:
	var missing: Array[StringName] = []
	var needed := {}
	for id in route.requires:
		needed[id] = int(needed.get(id, 0)) + 1
	for id in needed:
		if _inventory.count_of(id) < int(needed[id]):
			missing.append(id)
	return missing


func check(route: Route, zone: StringName, prop: StringName, minute_of_day: int) -> Result:
	if route == null or route.zone != zone or route.prop != prop:
		return Result.WRONG_PLACE
	if _player_state.is_detained():
		return Result.DETAINED
	if not route.window_contains(minute_of_day):
		return Result.OUTSIDE_WINDOW
	if not missing_for(route).is_empty():
		return Result.MISSING_KIT
	return Result.OK


## Tries to leave. On success the player state becomes ESCAPE_SUCCESS and the
## route's consumables are spent.
func attempt(zone: StringName, prop: StringName, minute_of_day: int) -> Result:
	var route := route_at(zone, prop)
	var result := check(route, zone, prop, minute_of_day)
	if result != Result.OK:
		if route != null:
			attempt_failed.emit(route, result)
		return result

	for id in route.consumes:
		_inventory.remove(id)
	_player_state.escape()
	escaped.emit(route)
	return Result.OK


func _validate(catalog: ItemCatalog) -> void:
	if routes.is_empty():
		errors.append("no escape routes defined")

	var seen := {}
	for route in routes:
		if seen.has(route.id):
			errors.append("duplicate route id: %s" % route.id)
		seen[route.id] = true

		if route.requires.is_empty():
			errors.append("%s can be walked onto with nothing" % route.id)
		if not TileCatalog.PROPS_ORDER.has(route.prop):
			errors.append("%s is boarded at '%s', which is not a prop" % [route.id, route.prop])
		for id in route.consumes:
			if not route.requires.has(id):
				errors.append("%s consumes '%s' without requiring it" % [route.id, id])
		if route.has_window() and route.window_from == route.window_to:
			errors.append("%s has an empty time window" % route.id)

		if catalog == null:
			continue
		for id in route.requires:
			if not catalog.has(id):
				errors.append("%s requires unknown item '%s'" % [route.id, id])
