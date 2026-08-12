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
var inventory: Inventory
var player_state: PlayerState
var errors: PackedStringArray = PackedStringArray()


func _init(
	session_map: RigMap,
	schedule_path: String = SCHEDULE_PATH,
	items_path: String = ITEMS_PATH
) -> void:
	map = session_map
	navigation = RigNavigation.new(map)
	doors = DoorSystem.new(map)

	schedule = Schedule.load_from(schedule_path)
	errors.append_array(schedule.errors)

	items = ItemCatalog.load_from(items_path)
	errors.append_array(items.errors)

	clock = GameClock.new(schedule, START_MINUTE_OF_DAY)
	suspicion = Suspicion.new()
	roll_call = RollCall.new(clock, suspicion)
	inventory = Inventory.new(items)
	player_state = PlayerState.new()

	clock.minute_passed.connect(_on_minute_passed)


func is_valid() -> bool:
	return errors.is_empty() and map != null and map.is_valid()


func bind_player_locator(locator: Callable) -> void:
	roll_call.bind_player_locator(locator)


func tick(delta_seconds: float) -> void:
	clock.tick(delta_seconds)


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
	player_detained.emit(reason, taken)
	return taken


func _on_minute_passed(_minute_of_day: int, _day: int) -> void:
	if player_state.state != PlayerState.SOLITARY:
		return
	player_state.serve_time(1)
	if player_state.is_free():
		player_released.emit()
