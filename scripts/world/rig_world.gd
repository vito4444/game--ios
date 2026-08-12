class_name RigWorld
extends Node2D

## Builds the playable rig from a text map and keeps the camera on the player.

const DEFAULT_MAP := "res://data/maps/abyss9.map"
const PLAYER_SCENE := "res://scenes/actors/player.tscn"
const OFFICER_SCENE := "res://scenes/actors/security_officer.tscn"

signal map_loaded(map: RigMap)
signal session_started(session: Session)

@onready var _ground: TileMapLayer = $Ground
@onready var _props: TileMapLayer = $YSort/Props
@onready var _actors: Node2D = $YSort/Actors
@onready var _camera: Camera2D = $Camera

var map: RigMap
var session: Session
var player: Player
var officers: Array[SecurityOfficer] = []


func _ready() -> void:
	load_map(DEFAULT_MAP)


func load_map(path: String) -> bool:
	map = RigMap.load_from(path)
	if not map.is_valid():
		for error in map.errors:
			push_error("%s: %s" % [path, error])
		return false

	var tile_set := TileSetBuilder.build()
	_ground.tile_set = tile_set
	_props.tile_set = tile_set
	_paint()
	_spawn_player()
	_configure_camera()
	_start_session()
	map_loaded.emit(map)
	return true


func _start_session() -> void:
	session = Session.new(map)
	for error in session.errors:
		push_error("session: %s" % error)
	session.bind_player_locator(player_zone)
	session.player_detained.connect(_on_player_detained)
	session.player_released.connect(_on_player_released)
	session.doors.door_opened.connect(_repaint_door)
	session.doors.door_closed.connect(_repaint_door)
	_spawn_officers()
	session_started.emit(session)


func _repaint_door(cell: Vector2i) -> void:
	var kind := session.doors.kind_at(cell)
	if kind == &"":
		kind = map.door_kind(cell)
	var tile: StringName = (
		TileCatalog.open_tile_for(kind)
		if session.doors.is_open(cell)
		else TileCatalog.ground_entry(map.ground_symbol(cell))["tile"]
	)
	_ground.set_cell(cell, TileCatalog.SOURCE_TERRAIN, TileCatalog.terrain_coords(tile))


func _update_doors() -> void:
	var approaches: Array[Dictionary] = []
	if player != null and session.player_state.state != PlayerState.SOLITARY:
		approaches.append({"cell": Vector2(player.cell()), "staff": false})
	for officer in officers:
		approaches.append({"cell": Vector2(officer.cell()), "staff": true})
	session.doors.update(approaches)


func _spawn_officers() -> void:
	for officer in officers:
		officer.queue_free()
	officers.clear()

	var scene := load(OFFICER_SCENE) as PackedScene
	for patrol in map.patrols:
		var officer := scene.instantiate() as SecurityOfficer
		_actors.add_child(officer)
		officer.setup(session, session.navigation, player, patrol)
		officers.append(officer)


func _on_player_detained(_reason: String, _confiscated: Array) -> void:
	player.global_position = map.cell_centre(session.solitary_cell())


func _on_player_released() -> void:
	player.global_position = map.cell_centre(session.quarters_cell())


func player_zone() -> StringName:
	if player == null or session == null:
		return &""
	return session.zone_at_position(player.global_position)


func _paint() -> void:
	_ground.clear()
	_props.clear()
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)

			var ground_entry := TileCatalog.ground_entry(map.ground_symbol(cell))
			if not ground_entry.is_empty():
				_ground.set_cell(
					cell,
					TileCatalog.SOURCE_TERRAIN,
					TileCatalog.terrain_coords(ground_entry["tile"])
				)

			var prop_entry := TileCatalog.prop_entry(map.prop_symbol(cell))
			if not prop_entry.is_empty():
				_props.set_cell(
					cell, TileCatalog.SOURCE_PROPS, TileCatalog.prop_coords(prop_entry["tile"])
				)


func _spawn_player() -> void:
	if player == null:
		player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
		_actors.add_child(player)
	player.global_position = map.cell_centre(map.spawn)


func _configure_camera() -> void:
	var extent := map.pixel_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = extent.x
	_camera.limit_bottom = extent.y
	_camera.make_current()
	_follow_player()


func _process(delta: float) -> void:
	if session != null:
		session.tick(delta)
		_update_doors()
	_follow_player()


func _follow_player() -> void:
	if player != null:
		_camera.global_position = player.global_position


func camera() -> Camera2D:
	return _camera
