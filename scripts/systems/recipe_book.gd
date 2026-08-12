class_name RecipeBook
extends RefCounted

## Crafting recipes, loaded from data/recipes/recipes.json.
##
## A recipe is gated on three things at once: the inputs, the station, and the
## player's Technical stat. Gating on all three is what makes the workshop
## worth walking to and training worth doing.

const DEFAULT_PATH := "res://data/recipes/recipes.json"


class Recipe:
	var id: StringName
	var output: StringName
	var inputs: Array[StringName]
	var station: StringName
	var technical: int
	var minutes: int

	func _init(data: Dictionary) -> void:
		id = StringName(data.get("id", ""))
		output = StringName(data.get("output", ""))
		inputs = []
		for entry in data.get("inputs", []) as Array:
			inputs.append(StringName(entry))
		station = StringName(data.get("station", ""))
		technical = int(data.get("technical", 0))
		minutes = int(data.get("minutes", 0))

	## Inputs collapsed to id -> count, which is how availability is checked.
	func required_counts() -> Dictionary:
		var counts := {}
		for id_ in inputs:
			counts[id_] = int(counts.get(id_, 0)) + 1
		return counts


var recipes: Array[Recipe] = []
var errors: PackedStringArray = PackedStringArray()


static func load_from(path: String = DEFAULT_PATH, catalog: ItemCatalog = null) -> RecipeBook:
	var book := RecipeBook.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		book.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return book

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		book.errors.append("%s is not a JSON object" % path)
		return book

	for entry in (parsed as Dictionary).get("recipes", []) as Array:
		book.recipes.append(Recipe.new(entry as Dictionary))
	book._validate(catalog)
	return book


func is_valid() -> bool:
	return errors.is_empty()


func size() -> int:
	return recipes.size()


func by_id(id: StringName) -> Recipe:
	for recipe in recipes:
		if recipe.id == id:
			return recipe
	return null


func at_station(station: StringName) -> Array[Recipe]:
	var found: Array[Recipe] = []
	for recipe in recipes:
		if recipe.station == station:
			found.append(recipe)
	return found


func stations() -> Array[StringName]:
	var found: Array[StringName] = []
	for recipe in recipes:
		if not found.has(recipe.station):
			found.append(recipe.station)
	return found


func _validate(catalog: ItemCatalog) -> void:
	if recipes.is_empty():
		errors.append("no recipes defined")

	var seen := {}
	for recipe in recipes:
		if seen.has(recipe.id):
			errors.append("duplicate recipe id: %s" % recipe.id)
		seen[recipe.id] = true

		if recipe.inputs.is_empty():
			errors.append("%s has no inputs" % recipe.id)
		if recipe.minutes <= 0:
			errors.append("%s must take time to make" % recipe.id)
		if recipe.station == &"":
			errors.append("%s names no station" % recipe.id)
		elif not TileCatalog.PROPS_ORDER.has(recipe.station):
			errors.append("%s names station '%s', which is not a prop" % [recipe.id, recipe.station])

		if catalog == null:
			continue
		if not catalog.has(recipe.output):
			errors.append("%s produces unknown item '%s'" % [recipe.id, recipe.output])
		for input_id in recipe.inputs:
			if not catalog.has(input_id):
				errors.append("%s consumes unknown item '%s'" % [recipe.id, input_id])
