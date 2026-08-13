extends GutTest

## Shift work, wages, the trader, and what the three stats actually do.

const ITEMS_PATH := "res://data/items/items.json"
const JOBS_PATH := "res://data/jobs/jobs.json"
const MAP_PATH := "res://data/maps/abyss9.map"

## job id, zone, station, full pay, units, stat trained
const EXPECTED_JOBS := [
	["welding", "workshop", "workbench", 60, 6, "technical"],
	["sludge", "moon_pool", "crate", 48, 6, "conditioning"],
	["galley", "galley", "table", 30, 6, "conditioning"],
]

var catalog: ItemCatalog
var inventory: Inventory
var wallet: Wallet
var stats: Stats
var board: JobBoard


func before_each() -> void:
	catalog = ItemCatalog.load_from(ITEMS_PATH)
	inventory = Inventory.new(catalog, 40)
	wallet = Wallet.new()
	stats = Stats.new()
	board = JobBoard.load_from(JOBS_PATH, wallet, inventory, stats, 12345)


# ---------------------------------------------------------------- jobs


func test_the_job_board_loads_cleanly() -> void:
	assert_eq(board.errors, PackedStringArray())


func test_the_three_assignments_match_the_specified_pay_and_posts() -> void:
	assert_eq(board.jobs.size(), EXPECTED_JOBS.size())
	for expected in EXPECTED_JOBS:
		var job := board.by_id(StringName(expected[0]))
		assert_not_null(job, "missing job %s" % expected[0])
		assert_eq(String(job.zone), expected[1], "%s zone" % expected[0])
		assert_eq(String(job.station), expected[2], "%s station" % expected[0])
		assert_eq(job.pay, expected[3], "%s pay" % expected[0])
		assert_eq(job.units, expected[4], "%s units" % expected[0])
		assert_eq(String(job.stat), expected[5], "%s stat" % expected[0])


func test_a_full_welding_shift_pays_exactly_sixty() -> void:
	board.assign(&"welding")
	board.begin_shift()
	for _unit in range(6):
		assert_true(board.work(&"workshop", &"workbench"))

	assert_true(board.is_shift_complete())
	assert_eq(board.settle(), 60)
	assert_eq(wallet.balance, 60)


func test_half_a_shift_pays_half() -> void:
	board.assign(&"welding")
	board.begin_shift()
	for _unit in range(3):
		board.work(&"workshop", &"workbench")

	assert_eq(board.settle(), 30)
	assert_eq(wallet.balance, 30)


func test_turning_up_to_nothing_pays_nothing() -> void:
	board.assign(&"welding")
	board.begin_shift()
	assert_eq(board.settle(), 0)
	assert_eq(wallet.balance, 0)


func test_working_past_the_end_of_the_shift_earns_no_more() -> void:
	board.assign(&"welding")
	board.begin_shift()
	for _unit in range(6):
		board.work(&"workshop", &"workbench")

	assert_false(board.work(&"workshop", &"workbench"), "a seventh unit should be refused")
	assert_eq(board.settle(), 60)


func test_working_somebody_elses_post_does_not_count() -> void:
	board.assign(&"welding")
	board.begin_shift()
	assert_false(board.work(&"galley", &"table"))
	assert_false(board.work(&"workshop", &"crate"), "right room, wrong station")
	assert_eq(board.units_done, 0)


func test_no_work_counts_outside_a_shift() -> void:
	board.assign(&"welding")
	assert_false(board.work(&"workshop", &"workbench"))
	assert_eq(board.settle(), 0)


func test_a_completed_shift_trains_the_stat_it_uses() -> void:
	board.assign(&"welding")
	board.begin_shift()
	for _unit in range(6):
		board.work(&"workshop", &"workbench")
	board.settle()
	assert_eq(stats.progress(Stats.TECHNICAL), 1)


func test_working_turns_up_salvage_sometimes_and_not_always() -> void:
	board.assign(&"welding")
	var salvaged := 0
	for _shift in range(20):
		board.begin_shift()
		for _unit in range(6):
			board.work(&"workshop", &"workbench")
			if inventory.has(&"scrap_metal"):
				salvaged += inventory.count_of(&"scrap_metal")
				while inventory.remove(&"scrap_metal"):
					pass
		board.settle()
	assert_gt(salvaged, 0, "120 units of welding produced no scrap at all")
	assert_lt(salvaged, 120, "every single unit produced scrap")


# ---------------------------------------------------------------- market


func test_the_trader_sells_above_value_and_buys_below_it() -> void:
	var market := Market.new(catalog, inventory, wallet)
	# A ration tin is worth 4.
	assert_eq(market.buy_price(&"ration"), 6)
	assert_eq(market.sell_price(&"ration"), 2)


func test_buying_moves_credits_out_and_an_item_in() -> void:
	var market := Market.new(catalog, inventory, wallet)
	wallet.credit(100)
	var price := market.buy_price(&"torch_fuel")

	assert_true(market.buy(&"torch_fuel"))
	assert_eq(wallet.balance, 100 - price)
	assert_true(inventory.has(&"torch_fuel"))


func test_buying_fails_when_short_of_credits() -> void:
	var market := Market.new(catalog, inventory, wallet)
	wallet.credit(1)
	assert_false(market.buy(&"torch_fuel"))
	assert_eq(wallet.balance, 1)
	assert_false(inventory.has(&"torch_fuel"))


func test_the_trader_does_not_stock_escape_parts() -> void:
	var market := Market.new(catalog, inventory, wallet)
	for id in [&"drive_core", &"cutting_torch", &"forged_docket", &"officer_uniform"]:
		assert_false(market.stock().has(id), "%s should not be purchasable" % id)
		assert_false(market.can_buy(id))


func test_selling_returns_credits_and_removes_the_item() -> void:
	var market := Market.new(catalog, inventory, wallet)
	inventory.add(&"nav_module")
	var price := market.sell_price(&"nav_module")

	assert_true(market.sell(&"nav_module"))
	assert_eq(wallet.balance, price)
	assert_false(inventory.has(&"nav_module"))


func test_selling_something_you_do_not_have_fails() -> void:
	var market := Market.new(catalog, inventory, wallet)
	assert_false(market.sell(&"drive_core"))
	assert_eq(wallet.balance, 0)


# ---------------------------------------------------------------- stats


func test_five_training_sessions_land_on_the_expected_level() -> void:
	# Three sessions take level 1 to 2; the next six would be needed for 3, so
	# five sessions leaves conditioning at 2 with two sessions banked.
	for _session in range(5):
		stats.train(Stats.CONDITIONING)
	assert_eq(stats.level(Stats.CONDITIONING), 2)
	assert_eq(stats.progress(Stats.CONDITIONING), 2)
	assert_eq(stats.sessions_to_next_level(Stats.CONDITIONING), 4)


func test_conditioning_makes_the_player_faster_by_a_fixed_step() -> void:
	assert_almost_eq(stats.speed_multiplier(), 1.0, 0.0001)
	stats.set_level(Stats.CONDITIONING, 2)
	assert_almost_eq(stats.speed_multiplier(), 1.06, 0.0001)
	stats.set_level(Stats.CONDITIONING, 5)
	assert_almost_eq(stats.speed_multiplier(), 1.24, 0.0001)


func test_pressure_tolerance_extends_a_bottle_of_air() -> void:
	assert_almost_eq(stats.oxygen_seconds(), 40.0, 0.001)
	stats.set_level(Stats.PRESSURE, 2)
	assert_almost_eq(stats.oxygen_seconds(), 50.0, 0.001)
	stats.set_level(Stats.PRESSURE, 5)
	assert_almost_eq(stats.oxygen_seconds(), 80.0, 0.001)


func test_stats_are_clamped_at_both_ends() -> void:
	stats.set_level(Stats.TECHNICAL, 99)
	assert_eq(stats.level(Stats.TECHNICAL), Stats.MAXIMUM)
	assert_false(stats.train(Stats.TECHNICAL), "a maxed stat cannot be trained further")

	stats.set_level(Stats.TECHNICAL, -5)
	assert_eq(stats.level(Stats.TECHNICAL), Stats.MINIMUM)


# ---------------------------------------------------------------- session


func test_the_session_starts_the_player_on_the_welding_assignment() -> void:
	var session := Session.new(RigMap.load_from(MAP_PATH))
	assert_eq(session.errors, PackedStringArray())
	assert_eq(session.jobs.assigned.id, Session.STARTING_JOB)
	assert_eq(session.wallet.balance, 0)


func test_the_shift_starts_and_settles_with_the_schedule() -> void:
	var session := Session.new(RigMap.load_from(MAP_PATH))
	assert_false(session.jobs.on_shift)

	session.clock.advance_to_minute_of_day(8 * 60 + 30)
	assert_true(session.jobs.on_shift, "the shift should open at 08:30")

	for _unit in range(6):
		session.jobs.work(&"workshop", &"workbench")
	session.clock.advance_to_minute_of_day(12 * 60)

	assert_false(session.jobs.on_shift, "lunch should close the shift")
	assert_eq(session.wallet.balance, 60)


func test_every_job_post_exists_somewhere_in_its_own_zone_on_the_map() -> void:
	var map := RigMap.load_from(MAP_PATH)
	for job in board.jobs:
		var zone := map.zone_by_id(job.zone)
		assert_not_null(zone, "%s names zone %s, which the map does not have" % [job.id, job.zone])

		var found := false
		for y in range(zone.rect.position.y, zone.rect.end.y):
			for x in range(zone.rect.position.x, zone.rect.end.x):
				var prop: StringName = TileCatalog.prop_entry(
					map.prop_symbol(Vector2i(x, y))
				).get("tile", &"")
				if prop == job.station:
					found = true
		assert_true(found, "%s has no %s anywhere in %s" % [job.id, job.station, job.zone])
