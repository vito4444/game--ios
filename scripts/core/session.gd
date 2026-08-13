class_name Session
extends RefCounted

## One run of the game: the map plus every system that has state worth saving.
##
## Systems are plain RefCounted objects rather than nodes so a test can build a
## whole session, skip three days, and assert on the result without a scene
## tree.

signal player_detained(reason: String, confiscated: Array)
signal player_released()

const SCHEDULE_PATH := "res://data/schedule/daily.json"
const ITEMS_PATH := "res://data/items/items.json"
const RECIPES_PATH := "res://data/recipes/recipes.json"
const JOBS_PATH := "res://data/jobs/jobs.json"
const ROUTES_PATH := "res://data/routes/routes.json"

## The assignment a new contract starts on.
const STARTING_JOB := &"welding"

## Security keep a spare uniform in their own locker room. Stealing it is the
## first step of the supply-sub route, and the reason to risk the office at all.
const SEEDED_UNIFORM_ZONE := &"security_office"

## Rig time when a new contract starts: woken for the first shift.
const START_MINUTE_OF_DAY := 6 * 60

const SOLITARY_ZONE := &"solitary"
const QUARTERS_KIND := &"quarters"

var map: RigMap
var navigation: RigNavigation
var doors: DoorSystem
var schedule: Schedule
var clock: GameClock
var suspicion: Suspicion
var roll_call: RollCall
var items: ItemCatalog
var recipes: RecipeBook
var inventory: Inventory
var stats: Stats
var crafting: Crafting
var shakedown: Shakedown
var wallet: Wallet
var jobs: JobBoard
var market: Market
var escape_routes: EscapeRoutes
var oxygen: Oxygen
var blackout: Blackout

## Counters the outcome screen reports on.
var times_detained: int = 0
var times_searched: int = 0
var times_blacked_out: int = 0

var _infirmary_minutes_left: int = 0
var player_state: PlayerState
var stashes: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


func _init(
	session_map: RigMap,
	schedule_path: String = SCHEDULE_PATH,
	items_path: String = ITEMS_PATH,
	recipes_path: String = RECIPES_PATH,
	search_seed: int = 0
) -> void:
	map = session_map
	navigation = RigNavigation.new(map)
	doors = DoorSystem.new(map)

	schedule = Schedule.load_from(schedule_path)
	errors.append_array(schedule.errors)

	items = ItemCatalog.load_from(items_path)
	errors.append_array(items.errors)

	recipes = RecipeBook.load_from(recipes_path, items)
	errors.append_array(recipes.errors)

	clock = GameClock.new(schedule, START_MINUTE_OF_DAY)
	suspicion = Suspicion.new()
	roll_call = RollCall.new(clock, suspicion)
	inventory = Inventory.new(items)
	stats = Stats.new()
	crafting = Crafting.new(recipes, inventory, stats)
	player_state = PlayerState.new()
	wallet = Wallet.new()

	jobs = JobBoard.load_from(JOBS_PATH, wallet, inventory, stats, search_seed)
	errors.append_array(jobs.errors)
	jobs.assign(STARTING_JOB)

	market = Market.new(items, inventory, wallet)

	escape_routes = EscapeRoutes.load_from(ROUTES_PATH, inventory, player_state, items)
	errors.append_array(escape_routes.errors)

	oxygen = Oxygen.new(stats, inventory)
	oxygen.blacked_out.connect(_on_blacked_out)
	blackout = Blackout.new(clock)

	_build_stashes()
	_seed_security_uniform()
	shakedown = Shakedown.new(inventory, suspicion, stashes, search_seed)
	shakedown.player_searched.connect(_on_player_searched)

	clock.minute_passed.connect(_on_minute_passed)
	roll_call.attended.connect(_on_muster_attended)
	clock.event_started.connect(_on_event_started)


func _build_stashes() -> void:
	## Every locker on the map is a stash the player can use.
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if TileCatalog.prop_entry(map.prop_symbol(cell)).get("tile", &"") == &"locker":
				stashes[cell] = Stash.new(items, cell)


func _seed_security_uniform() -> void:
	var office := map.zone_by_id(SEEDED_UNIFORM_ZONE)
	if office == null:
		return
	for cell in stashes:
		if office.contains(cell):
			(stashes[cell] as Stash).store(&"officer_uniform")
			return


func stash_at(cell: Vector2i) -> Stash:
	return stashes.get(cell)


## Attempts to leave the rig from where the player is standing.
func attempt_escape(zone: StringName, prop: StringName) -> EscapeRoutes.Result:
	return escape_routes.attempt(zone, prop, clock.minute_of_day())


func is_valid() -> bool:
	return errors.is_empty() and map != null and map.is_valid()


func bind_player_locator(locator: Callable) -> void:
	roll_call.bind_player_locator(locator)


signal player_blacked_out(cell: Vector2i)

## How much of a sentence is served while unconscious in the infirmary.
const INFIRMARY_MINUTES := 90


func tick(delta_seconds: float) -> void:
	clock.tick(delta_seconds)
	blackout.tick(delta_seconds)


## Advances oxygen for a player standing at `cell`.
func tick_oxygen(delta_seconds: float, cell: Vector2i) -> void:
	if not player_state.is_free() and player_state.state != PlayerState.PURSUED:
		return
	oxygen.tick(delta_seconds, map.cell_has_flag(cell, Oxygen.UNPRESSURISED_FLAG))


func infirmary_cell() -> Vector2i:
	var infirmary := map.zone_by_id(&"infirmary")
	if infirmary == null:
		return map.spawn
	return infirmary.rect.position + infirmary.rect.size / 2


func _on_blacked_out() -> void:
	if player_state.state == PlayerState.UNCONSCIOUS:
		return
	player_state.knock_out()
	# Waking up in the infirmary costs time, and anything that was not yours
	# has been logged and taken by the time you come round.
	inventory.confiscate_contraband()
	_infirmary_minutes_left = INFIRMARY_MINUTES
	times_blacked_out += 1
	player_blacked_out.emit(infirmary_cell())


## The zone a world position falls in, or &"" outside every room.
func zone_at_position(position: Vector2) -> StringName:
	var cell := Vector2i((position / Vector2(TileCatalog.TILE_SIZE)).floor())
	var zone := map.zone_at(cell)
	return zone.id if zone != null else &""


func solitary_cell() -> Vector2i:
	var zone := map.zone_by_id(SOLITARY_ZONE)
	if zone == null:
		return map.spawn
	return zone.rect.position + zone.rect.size / 2


func quarters_cell() -> Vector2i:
	var quarters := map.zones_of_kind(QUARTERS_KIND)
	if quarters.is_empty():
		return map.spawn
	return map.spawn


## Locks the player up: contraband is taken and the sentence starts running.
func detain_player(reason: String) -> Array[StringName]:
	var taken := inventory.confiscate_contraband()
	player_state.send_to_solitary(reason)
	times_detained += 1
	player_detained.emit(reason, taken)
	return taken


func _on_player_searched(_seized: Array) -> void:
	times_searched += 1


func _on_minute_passed(_minute_of_day: int, _day: int) -> void:
	if player_state.state == PlayerState.UNCONSCIOUS:
		_infirmary_minutes_left -= 1
		if _infirmary_minutes_left <= 0:
			oxygen.refill()
			player_state.revive()
			player_released.emit()
		return

	if player_state.state != PlayerState.SOLITARY:
		return
	player_state.serve_time(1)
	if player_state.is_free():
		player_released.emit()


func _on_muster_attended(_event: Schedule.Event) -> void:
	## Turning up is also when security gets a free look at your pockets.
	shakedown.attempt_pat_down()


func _on_event_started(event: Schedule.Event) -> void:
	if event.id == Shakedown.SWEEP_EVENT:
		shakedown.sweep_lockers()
	if event.id == JobBoard.SHIFT_EVENT:
		jobs.begin_shift()
	elif event.id == JobBoard.SHIFT_END_EVENT:
		jobs.settle()
