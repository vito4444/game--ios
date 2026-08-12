extends GutTest

## Hiding places and the searches that find them.
##
## Every roll comes from one seeded generator, so these assert on the actual
## outcome of a specific seed rather than on a probability.

const ITEMS_PATH := "res://data/items/items.json"
const MAP_PATH := "res://data/maps/abyss9.map"
const SEED := 20250812

var catalog: ItemCatalog
var inventory: Inventory
var suspicion: Suspicion
var stash: Stash


func before_each() -> void:
	catalog = ItemCatalog.load_from(ITEMS_PATH)
	inventory = Inventory.new(catalog)
	suspicion = Suspicion.new()
	stash = Stash.new(catalog, Vector2i(2, 1))


func _shakedown(stashes: Dictionary = {}, seed_value: int = SEED) -> Shakedown:
	return Shakedown.new(inventory, suspicion, stashes, seed_value)


# ---------------------------------------------------------------- stash


func test_a_locker_holds_items_on_the_shelf_and_in_the_hidden_compartment() -> void:
	assert_true(stash.store(&"ration"))
	assert_true(stash.store(&"cutting_torch", true))
	assert_eq(stash.contents().size(), 2)
	assert_true(stash.has(&"cutting_torch"))


func test_the_hidden_compartment_is_smaller_than_the_shelf() -> void:
	assert_eq(Stash.HIDDEN_SLOTS, 3)
	assert_eq(Stash.SHELF_SLOTS, 6)
	assert_true(stash.store(&"drive_core", true), "a 3-slot part fills the compartment")
	assert_eq(stash.free_hidden_slots(), 0)
	assert_false(stash.store(&"ration", true), "nothing else fits behind the panel")


func test_taking_an_item_back_out_works_from_either_place() -> void:
	stash.store(&"wrench")
	stash.store(&"pry_bar", true)
	assert_true(stash.take(&"wrench"))
	assert_true(stash.take(&"pry_bar"))
	assert_true(stash.is_empty())
	assert_false(stash.take(&"wrench"), "taking from an empty locker fails")


func test_a_search_always_takes_contraband_off_the_open_shelf() -> void:
	stash.store(&"cutting_torch")
	stash.store(&"ration")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var seized := stash.search(rng)
	assert_eq(seized, [&"cutting_torch"] as Array[StringName])
	assert_true(stash.has(&"ration"), "legal items are left alone")


func test_a_search_leaves_legal_items_in_the_hidden_compartment() -> void:
	stash.store(&"ration", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	assert_eq(stash.search(rng).size(), 0)
	assert_true(stash.has(&"ration"))


func test_the_hidden_compartment_survives_some_searches_and_not_others() -> void:
	# The same locker and the same contents, searched under two seeds: one
	# finds the torch, the other misses it. If both ever agree, the hidden
	# compartment has stopped being a gamble.
	var found_at_least_once := false
	var missed_at_least_once := false
	for seed_value in range(40):
		var probe := Stash.new(catalog, Vector2i.ZERO)
		probe.store(&"cutting_torch", true)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if probe.search(rng).is_empty():
			missed_at_least_once = true
		else:
			found_at_least_once = true
	assert_true(found_at_least_once, "no seed ever found the hidden torch")
	assert_true(missed_at_least_once, "every seed found the hidden torch")


func test_a_thorough_search_is_more_likely_to_find_the_compartment() -> void:
	var casual := 0
	var thorough := 0
	for seed_value in range(60):
		var a := Stash.new(catalog, Vector2i.ZERO)
		a.store(&"cutting_torch", true)
		var rng_a := RandomNumberGenerator.new()
		rng_a.seed = seed_value
		casual += a.search(rng_a, 1.0).size()

		var b := Stash.new(catalog, Vector2i.ZERO)
		b.store(&"cutting_torch", true)
		var rng_b := RandomNumberGenerator.new()
		rng_b.seed = seed_value
		thorough += b.search(rng_b, 2.0).size()
	assert_gt(thorough, casual)


# ---------------------------------------------------------------- pat-downs


func test_the_pat_down_chance_rises_with_suspicion() -> void:
	var searches := _shakedown()
	assert_almost_eq(searches.pat_down_chance(), 0.20, 0.001)
	suspicion.value = 100
	assert_almost_eq(searches.pat_down_chance(), 0.75, 0.001)


func test_the_same_seed_produces_the_same_run_of_pat_downs() -> void:
	var first: Array[bool] = []
	var second: Array[bool] = []
	for run in [first, second]:
		inventory = Inventory.new(catalog)
		suspicion = Suspicion.new()
		var searches := _shakedown()
		for _attempt in range(12):
			inventory.add(&"pry_bar")
			run.append(not searches.attempt_pat_down().is_empty())
			inventory.clear()
	assert_eq(first, second, "a fixed seed must replay identically")
	assert_true(first.has(true), "twelve attempts and never once searched")
	assert_true(first.has(false), "twelve attempts and searched every time")


func test_a_pat_down_takes_contraband_and_raises_suspicion() -> void:
	var searches := _shakedown()
	# Guarantee the roll succeeds by pinning suspicion at maximum first.
	suspicion.value = 100
	inventory.add(&"ration")
	inventory.add(&"cutting_torch")

	var seized: Array[StringName] = []
	for _attempt in range(20):
		seized = searches.attempt_pat_down()
		if not seized.is_empty():
			break
		inventory.add(&"cutting_torch")

	assert_eq(seized, [&"cutting_torch"] as Array[StringName])
	assert_true(inventory.has(&"ration"))
	assert_eq(suspicion.value, 100, "already at maximum, and clamped there")


func test_a_clean_player_loses_nothing_to_a_pat_down() -> void:
	var searches := _shakedown()
	suspicion.value = 100
	inventory.add(&"ration")
	for _attempt in range(10):
		assert_eq(searches.attempt_pat_down().size(), 0)
	assert_true(inventory.has(&"ration"))


# ---------------------------------------------------------------- sweeps


func test_a_locker_sweep_finds_contraband_in_some_lockers() -> void:
	var stashes := {}
	for index in range(12):
		var cell := Vector2i(index, 0)
		var locker := Stash.new(catalog, cell)
		locker.store(&"pry_bar")
		stashes[cell] = locker

	var searches := _shakedown(stashes)
	var results := searches.sweep_lockers()

	assert_gt(results.size(), 0, "a sweep of twelve stocked lockers found nothing")
	assert_lt(results.size(), 12, "a sweep opened every single locker")
	for cell in results:
		assert_false(stashes[cell].has(&"pry_bar"), "%s was searched but kept its bar" % cell)


func test_a_sweep_is_reproducible_for_a_given_seed() -> void:
	var runs := []
	for _run in range(2):
		var stashes := {}
		for index in range(12):
			var cell := Vector2i(index, 0)
			var locker := Stash.new(catalog, cell)
			locker.store(&"pry_bar")
			stashes[cell] = locker
		var keys: Array = _shakedown(stashes).sweep_lockers().keys()
		keys.sort()
		runs.append(keys)
	assert_eq(runs[0], runs[1])


func test_the_session_gives_every_locker_on_the_map_a_stash() -> void:
	var session := Session.new(RigMap.load_from(MAP_PATH))
	assert_gt(session.stashes.size(), 0)
	for cell in session.stashes:
		assert_eq(
			TileCatalog.prop_entry(session.map.prop_symbol(cell))["tile"],
			&"locker",
			"%s is not a locker" % cell
		)
