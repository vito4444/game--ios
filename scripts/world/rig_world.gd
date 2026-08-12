class_name RigWorld
extends Node2D

## Builds the playable rig from a text map and keeps the camera on the player.

const DEFAULT_MAP := "res://data/maps/abyss9.map"
const PLAYER_SCENE := "res://scenes/actors/player.tscn"

signal map_loaded(map: RigMap)

@onready var _ground: TileMapLayer = $Ground
@onready var _props: TileMapLayer = $YSort/Props
@onready var _actors: Node2D = $YSort/Actors
@onready var _camera: Camera2D = $Camera

var map: RigMap
var player: Player


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
	map_loaded.emit(map)
	return true


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


func _process(_delta: float) -> void:
	_follow_player()


func _follow_player() -> void:
	if player != null:
		_camera.global_position = player.global_position


func camera() -> Camera2D:
	return _camera
