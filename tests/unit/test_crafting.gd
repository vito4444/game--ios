extends GutTest

## Every shipped recipe, asserted input-by-input, plus the reasons a craft is
## refused.

const ITEMS_PATH := "res://data/items/items.json"
const RECIPES_PATH := "res://data/recipes/recipes.json"

## recipe id, inputs, station, technical level required, output
const EXPECTED_RECIPES := [
	["pry_bar", ["scrap_metal", "scrap_metal", "wrench"], "workbench", 1, "pry_bar"],
	["door_shim", ["scrap_metal", "keycard"], "workbench", 2, "door_shim"],
	["cutting_torch", ["torch_fuel", "wrench", "scrap_metal"], "workbench", 3, "cutting_torch"],
	["rebreather", ["oxygen_bottle", "scrap_metal", "wrench"], "workbench", 2, "rebreather"],
	[
		"forged_docket",
		["blank_docket", "keycard"],
		"technical_terminal",
		4,
		"forged_docket",
	],
]

var catalog: ItemCatalog
var book: RecipeBook
var inventory: Inventory
var stats: Stats
var crafting: Crafting


func before_each() -> void:
	catalog = ItemCatalog.load_from(ITEMS_PATH)
	book = RecipeBook.load_from(RECIPES_PATH, catalog)
	inventory = Inventory.new(catalog, 20)
	stats = Stats.new()
	crafting = Crafting.new(book, inventory, stats)


func test_catalog_and_recipe_book_load_cleanly() -> void:
	assert_eq(catalog.errors, PackedStringArray())
	assert_eq(book.errors, PackedStringArray())


func test_the_book_holds_exactly_the_expected_recipes() -> void:
	assert_eq(book.size(), EXPECTED_RECIPES.size())
	for expected in EXPECTED_RECIPES:
		assert_not_null(book.by_id(StringName(expected[0])), "missing recipe %s" % expected[0])


func test_every_recipe_turns_its_inputs_into_its_output() -> void:
	for expected in EXPECTED_RECIPES:
		var recipe_id := StringName(expected[0])
		var inputs: Array = expected[1]
		var station := StringName(expected[2])
		var technical: int = expected[3]
		var output := StringName(expected[4])

		inventory.clear()
		stats.set_level(Stats.TECHNICAL, technical)
		for input_id in inputs:
			assert_true(inventory.add(StringName(input_id)), "could not stock %s" % input_id)

		assert_eq(
			crafting.craft(recipe_id, station),
			Crafting.Result.OK,
			"%s should be craftable from %s" % [recipe_id, inputs]
		)
		assert_true(inventory.has(output), "%s did not produce %s" % [recipe_id, output])
		assert_eq(
			inventory.count(), 1, "%s left leftovers: %s" % [recipe_id, inventory.ids()]
		)


func test_every_recipe_consumes_all_of_its_inputs() -> void:
	for expected in EXPECTED_RECIPES:
		inventory.clear()
		stats.set_level(Stats.TECHNICAL, expected[3])
		for input_id in expected[1]:
			inventory.add(StringName(input_id))
		crafting.craft(StringName(expected[0]), StringName(expected[2]))

		for input_id in expected[1]:
			if StringName(input_id) == StringName(expected[4]):
				continue
			assert_false(
				inventory.has(StringName(input_id)),
				"%s did not consume %s" % [expected[0], input_id]
			)


func test_a_recipe_needing_two_of_something_is_not_satisfied_by_one() -> void:
	stats.set_level(Stats.TECHNICAL, 1)
	inventory.add(&"scrap_metal")
	inventory.add(&"wrench")
	assert_eq(crafting.check(&"pry_bar", &"workbench"), Crafting.Result.MISSING_INPUTS)

	inventory.add(&"scrap_metal")
	assert_eq(crafting.check(&"pry_bar", &"workbench"), Crafting.Result.OK)


func test_the_wrong_station_refuses_the_recipe() -> void:
	stats.set_level(Stats.TECHNICAL, 4)
	inventory.add(&"blank_docket")
	inventory.add(&"keycard")
	assert_eq(crafting.check(&"forged_docket", &"workbench"), Crafting.Result.WRONG_STATION)
	assert_eq(crafting.check(&"forged_docket", &"technical_terminal"), Crafting.Result.OK)


func test_an_untrained_technician_cannot_build_a_torch() -> void:
	inventory.add(&"torch_fuel")
	inventory.add(&"wrench")
	inventory.add(&"scrap_metal")
	assert_eq(stats.level(Stats.TECHNICAL), 1)
	assert_eq(crafting.check(&"cutting_torch", &"workbench"), Crafting.Result.NOT_SKILLED_ENOUGH)

	stats.set_level(Stats.TECHNICAL, 3)
	assert_eq(crafting.check(&"cutting_torch", &"workbench"), Crafting.Result.OK)


func test_an_unknown_recipe_is_reported_as_such() -> void:
	assert_eq(crafting.check(&"submarine", &"workbench"), Crafting.Result.UNKNOWN_RECIPE)


func test_a_failed_craft_leaves_the_inventory_untouched() -> void:
	inventory.add(&"torch_fuel")
	inventory.add(&"wrench")
	inventory.add(&"scrap_metal")
	var before := inventory.ids()

	assert_ne(crafting.craft(&"cutting_torch", &"workbench"), Crafting.Result.OK)
	assert_eq(inventory.ids(), before)


func test_a_full_pack_still_allows_a_craft_that_frees_more_than_it_uses() -> void:
	# Three inputs of 1 + 1 + 1 slots out, one 2-slot torch in.
	var tight := Inventory.new(catalog, 3)
	var tight_crafting := Crafting.new(book, tight, stats)
	stats.set_level(Stats.TECHNICAL, 3)
	tight.add(&"torch_fuel")
	tight.add(&"wrench")
	tight.add(&"scrap_metal")
	assert_eq(tight.free_slots(), 0)

	assert_eq(tight_crafting.craft(&"cutting_torch", &"workbench"), Crafting.Result.OK)
	assert_true(tight.has(&"cutting_torch"))


func test_available_at_lists_only_what_can_be_made_right_now() -> void:
	stats.set_level(Stats.TECHNICAL, 2)
	inventory.add(&"scrap_metal")
	inventory.add(&"keycard")

	var ids := []
	for recipe in crafting.available_at(&"workbench"):
		ids.append(String(recipe.id))
	assert_eq(ids, ["door_shim"])


func test_recipes_name_real_items_and_real_stations() -> void:
	for recipe in book.recipes:
		assert_true(catalog.has(recipe.output), "%s outputs an unknown item" % recipe.id)
		for input_id in recipe.inputs:
			assert_true(catalog.has(input_id), "%s consumes an unknown item" % recipe.id)
		assert_true(
			TileCatalog.PROPS_ORDER.has(recipe.station),
			"%s is made at '%s', which is not a prop on any map" % [recipe.id, recipe.station]
		)


func test_the_parser_rejects_a_recipe_with_an_unknown_output() -> void:
	var path := "user://broken_recipes.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"recipes": [
					{
						"id": "moon_rocket",
						"output": "moon_rocket",
						"inputs": ["scrap_metal"],
						"station": "workbench",
						"minutes": 5,
					}
				]
			}
		)
	)
	file.close()

	var broken := RecipeBook.load_from(path, catalog)
	assert_string_contains(" ".join(broken.errors), "unknown item 'moon_rocket'")
