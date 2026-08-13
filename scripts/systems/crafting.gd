class_name Crafting
extends RefCounted

## Turns recipes plus an inventory into items.
##
## Every failure has a distinct reason so the interface can say why a recipe is
## greyed out instead of just refusing.

signal crafted(recipe: RecipeBook.Recipe)

enum Result {
	OK,
	UNKNOWN_RECIPE,
	WRONG_STATION,
	NOT_SKILLED_ENOUGH,
	MISSING_INPUTS,
	NO_ROOM,
}

const REASONS := {
	Result.OK: "Done",
	Result.UNKNOWN_RECIPE: "No such recipe",
	Result.WRONG_STATION: "Needs a different station",
	Result.NOT_SKILLED_ENOUGH: "Not technical enough",
	Result.MISSING_INPUTS: "Missing parts",
	Result.NO_ROOM: "No room to carry it",
}

var _book: RecipeBook
var _inventory: Inventory
var _stats: Stats


func _init(book: RecipeBook, inventory: Inventory, stats: Stats) -> void:
	_book = book
	_inventory = inventory
	_stats = stats


static func reason_for(result: Result) -> String:
	return REASONS.get(result, "")


## Why this recipe cannot be made right now, or Result.OK.
func check(recipe_id: StringName, station: StringName) -> Result:
	var recipe := _book.by_id(recipe_id)
	if recipe == null:
		return Result.UNKNOWN_RECIPE
	if recipe.station != station:
		return Result.WRONG_STATION
	if not _stats.meets(Stats.TECHNICAL, recipe.technical):
		return Result.NOT_SKILLED_ENOUGH

	for input_id in recipe.required_counts():
		if _inventory.count_of(input_id) < int(recipe.required_counts()[input_id]):
			return Result.MISSING_INPUTS

	if not _would_fit(recipe):
		return Result.NO_ROOM
	return Result.OK


func craft(recipe_id: StringName, station: StringName) -> Result:
	var result := check(recipe_id, station)
	if result != Result.OK:
		return result

	var recipe := _book.by_id(recipe_id)
	for input_id in recipe.inputs:
		_inventory.remove(input_id)
	_inventory.add(recipe.output)
	crafted.emit(recipe)
	return Result.OK


## Recipes the player could make at this station right now.
func available_at(station: StringName) -> Array[RecipeBook.Recipe]:
	var found: Array[RecipeBook.Recipe] = []
	for recipe in _book.at_station(station):
		if check(recipe.id, station) == Result.OK:
			found.append(recipe)
	return found


func _would_fit(recipe: RecipeBook.Recipe) -> bool:
	## The inputs come out of the pack before the output goes in, so a recipe
	## that trades three small parts for one large one still works when full.
	var freed := 0
	for input_id in recipe.inputs:
		freed += _inventory.size_of_item(input_id)
	return _inventory.size_of_item(recipe.output) <= _inventory.free_slots() + freed
