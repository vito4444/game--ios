class_name SecurityOfficer
extends CharacterBody2D

## A member of the rig's security detail.
##
## Walks an assigned route, notices infractions inside its vision cone, gives
## chase, and marches the player to the solitary cell. Sight is resolved on the
## tile grid by Vision rather than by physics rays, so what a guard can see is
## the same in a headless test as it is on screen.

signal spotted_player(report: Infractions.Report)
signal lost_player()
signal caught_player()

enum State { IDLE, PATROL, INVESTIGATE, CHASE, ESCORT }

const SHEET := "res://assets/generated/actors/officer.png"

const PATROL_SPEED := 52.0
const CHASE_SPEED := 84.0
const ESCORT_SPEED := 58.0

## Close enough to grab. Comfortably wider than a body so the grab lands rather
## than hovering a pixel outside it; characters pass through each other, but a
## guard still slows as it closes.
const CATCH_DISTANCE := 22.0

## How near a waypoint counts as reaching it.
const ARRIVE_DISTANCE := 4.0

## Sight is re-evaluated on a timer rather than every frame: it is the same
## answer four frames running, and the delay is the player's reaction window.
const LOOK_INTERVAL := 0.2

## How long a guard pokes around the player's last known position.
const INVESTIGATE_SECONDS := 6.0

## Pause at each end of a patrol route.
const TURNAROUND_SECONDS := 1.5

@onready var _sprite: CharacterSprite = $Sprite

var state: State = State.IDLE
var cone: Vision.Cone = Vision.Cone.new()

var _session: Session
var _navigation: RigNavigation
var _player: Node2D
var _patrol: RigMap.Patrol

var _route: Array[Vector2i] = []
var _route_index: int = 0
var _route_reversed: bool = false

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0

var _look_timer: float = 0.0
var _wait_timer: float = 0.0
var _last_seen_cell: Vector2i = Vector2i(-1, -1)
var _facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	_sprite.set_sheet(SHEET)


func setup(
	session: Session, navigation: RigNavigation, player: Node2D, patrol: RigMap.Patrol
) -> void:
	_session = session
	_navigation = navigation
	_player = player
	_patrol = patrol
	_route = patrol.waypoints.duplicate()
	_route_index = 0
	global_position = session.map.cell_centre(patrol.start())
	_enter_patrol()


func cell() -> Vector2i:
	return Vector2i((global_position / Vector2(TileCatalog.TILE_SIZE)).floor())


func can_see_cell(target: Vector2i) -> bool:
	return Vision.can_see(_session.map, cell(), _facing, target, cone)


func facing() -> Vector2:
	return _facing


func _physics_process(delta: float) -> void:
	if _session == null:
		return

	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = LOOK_INTERVAL
		_look()

	match state:
		State.PATROL:
			_tick_patrol(delta)
		State.CHASE:
			_tick_chase(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.ESCORT:
			_tick_escort(delta)
		State.IDLE:
			_halt()

	_sprite.update_animation(velocity, delta)


# ---------------------------------------------------------------- perception


func _look() -> void:
	if state == State.ESCORT or _player == null:
		return
	if _session.player_state.is_detained():
		return

	var player_cell := Vector2i((_player.global_position / Vector2(TileCatalog.TILE_SIZE)).floor())
	if not can_see_cell(player_cell):
		if state == State.CHASE:
			_enter_investigate(_last_seen_cell)
		return

	var report := Infractions.evaluate(
		_session.map,
		player_cell,
		_session.clock.current_event(),
		_session.inventory.is_carrying_contraband()
	)
	if not report.is_violation():
		return

	_last_seen_cell = player_cell
	if state != State.CHASE:
		spotted_player.emit(report)
		Audio.play(&"alarm")
		_session.suspicion.add(report.suspicion_cost())
		_session.player_state.begin_pursuit()
		state = State.CHASE
		_path.clear()


# ---------------------------------------------------------------- states


func _enter_patrol() -> void:
	state = State.PATROL
	_wait_timer = 0.0
	_repath_to(_route[_route_index])


func _tick_patrol(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_halt()
		return

	if _advance_along_path(delta, PATROL_SPEED):
		_advance_route()


func _advance_route() -> void:
	if _route.is_empty():
		state = State.IDLE
		return

	# Walk the list, then back along it, so a route does not need to loop.
	if _route_reversed:
		_route_index -= 1
		if _route_index < 0:
			_route_index = mini(1, _route.size() - 1)
			_route_reversed = false
			_wait_timer = TURNAROUND_SECONDS
	else:
		_route_index += 1
		if _route_index >= _route.size():
			_route_index = maxi(_route.size() - 2, 0)
			_route_reversed = true
			_wait_timer = TURNAROUND_SECONDS

	_repath_to(_route[_route_index])


func _tick_chase(delta: float) -> void:
	if _player == null or _session.player_state.is_detained():
		_enter_patrol()
		return

	var player_cell := Vector2i((_player.global_position / Vector2(TileCatalog.TILE_SIZE)).floor())
	if player_cell != _last_seen_cell and can_see_cell(player_cell):
		_last_seen_cell = player_cell

	if global_position.distance_to(_player.global_position) <= CATCH_DISTANCE:
		_begin_escort()
		return

	if _path.is_empty() or _path_index >= _path.size():
		_repath_to(_last_seen_cell)
	if _advance_along_path(delta, CHASE_SPEED):
		_enter_investigate(_last_seen_cell)


func _enter_investigate(target_cell: Vector2i) -> void:
	state = State.INVESTIGATE
	_wait_timer = INVESTIGATE_SECONDS
	_session.player_state.end_pursuit()
	lost_player.emit()
	if target_cell.x >= 0:
		_repath_to(target_cell)


func _tick_investigate(delta: float) -> void:
	if not _advance_along_path(delta, PATROL_SPEED):
		return
	_halt()
	# Sweep the facing around while standing still, so hiding next to the last
	# known position is not automatically safe.
	_facing = _facing.rotated(TAU * 0.25 * delta).round()
	_wait_timer -= delta
	if _wait_timer <= 0.0:
		_enter_patrol()


func _begin_escort() -> void:
	state = State.ESCORT
	_session.player_state.begin_escort()
	GameInput.movement_locked = true
	caught_player.emit()
	_repath_to(_session.solitary_cell())


func _tick_escort(delta: float) -> void:
	var arrived := _advance_along_path(delta, ESCORT_SPEED)
	if _player != null:
		# The player is marched along a step behind.
		var behind := global_position - _facing * 14.0
		_player.global_position = _player.global_position.lerp(behind, minf(delta * 8.0, 1.0))

	if not arrived:
		return

	_halt()
	GameInput.movement_locked = false
	_session.detain_player("Escorted to solitary")
	_enter_patrol()


# ---------------------------------------------------------------- movement


func _repath_to(target_cell: Vector2i) -> void:
	_path = PackedVector2Array()
	_path_index = 0
	if _navigation == null:
		return
	var from := _navigation.nearest_walkable(cell())
	var to := _navigation.nearest_walkable(target_cell)
	_path = _navigation.world_path_between(from, to)
	# get_id_path includes the starting cell; skipping it stops a guard from
	# stepping backwards to the centre of the tile it is already on.
	if _path.size() > 1:
		_path_index = 1


## Returns true once the end of the path is reached.
func _advance_along_path(delta: float, speed: float) -> bool:
	if _path_index >= _path.size():
		_halt()
		return true

	var target := _path[_path_index]
	var offset := target - global_position
	if offset.length() <= ARRIVE_DISTANCE:
		_path_index += 1
		if _path_index >= _path.size():
			_halt()
			return true
		target = _path[_path_index]
		offset = target - global_position

	velocity = offset.normalized() * speed
	_facing = Vision.facing_from(velocity)
	move_and_slide()
	return false


func _halt() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
