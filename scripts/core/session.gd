class_name Session
extends RefCounted

## One run of the game: the map plus every system that has state worth saving.
##
## Systems are plain RefCounted objects rather than nodes so a test can build a
## whole session, skip three days, and assert on the result without a scene
## tree.

const SCHEDULE_PATH := "res://data/schedule/daily.json"

## Rig time when a new contract starts: woken for the first shift.
const START_MINUTE_OF_DAY := 6 * 60

var map: RigMap
var schedule: Schedule
var clock: GameClock
var suspicion: Suspicion
var roll_call: RollCall
var errors: PackedStringArray = PackedStringArray()


func _init(session_map: RigMap, schedule_path: String = SCHEDULE_PATH) -> void:
	map = session_map
	schedule = Schedule.load_from(schedule_path)
	errors.append_array(schedule.errors)

	clock = GameClock.new(schedule, START_MINUTE_OF_DAY)
	suspicion = Suspicion.new()
	roll_call = RollCall.new(clock, suspicion)


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
