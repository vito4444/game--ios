class_name TileSetBuilder
extends RefCounted

## Builds the TileSet in code rather than storing a .tres.
##
## The tile atlases are generated, so a checked-in .tres would be a second copy
## of the same facts, free to drift from tools/gen_art.py without anything
## noticing. Building from TileCatalog keeps one source of truth.

const PHYSICS_LAYER := 0

## Collision shrunk in from the tile edge. Full-tile boxes make diagonal
## movement through doorways catch on corners.
const COLLISION_INSET := 1.0

## Props sort by their base rather than their centre, so a character standing
## below a bunk draws in front of it and above it draws behind.
const Y_SORT_ORIGIN := 16


static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TileCatalog.TILE_SIZE
	tile_set.add_physics_layer(PHYSICS_LAYER)

	# Tile data can only take a collision polygon once its source belongs to a
	# TileSet that has the physics layer, so creation and configuration are two
	# separate passes.
	var terrain := _create_source(TileCatalog.TERRAIN_TEXTURE, TileCatalog.TERRAIN_ORDER)
	var props := _create_source(TileCatalog.PROPS_TEXTURE, TileCatalog.PROPS_ORDER)
	tile_set.add_source(terrain, TileCatalog.SOURCE_TERRAIN)
	tile_set.add_source(props, TileCatalog.SOURCE_PROPS)

	_configure_tiles(
		terrain, TileCatalog.TERRAIN_ORDER, _solid_tiles(TileCatalog.GROUND_SYMBOLS), 0
	)
	_configure_tiles(
		props, TileCatalog.PROPS_ORDER, _solid_tiles(TileCatalog.PROP_SYMBOLS), Y_SORT_ORIGIN
	)
	return tile_set


static func _solid_tiles(symbols: Dictionary) -> Dictionary:
	var solid := {}
	for symbol in symbols:
		var entry: Dictionary = symbols[symbol]
		if entry.get("solid", false):
			solid[entry["tile"]] = true
	return solid


static func _create_source(texture_path: String, order: Array[StringName]) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = TileCatalog.TILE_SIZE
	for index in order.size():
		source.create_tile(_coords_for(index))
	return source


static func _configure_tiles(
	source: TileSetAtlasSource, order: Array[StringName], solid: Dictionary, y_sort_origin: int
) -> void:
	for index in order.size():
		var data := source.get_tile_data(_coords_for(index), 0)
		data.y_sort_origin = y_sort_origin
		if not solid.has(order[index]):
			continue
		data.add_collision_polygon(PHYSICS_LAYER)
		data.set_collision_polygon_points(PHYSICS_LAYER, 0, _collision_box())


static func _coords_for(index: int) -> Vector2i:
	return Vector2i(index % TileCatalog.ATLAS_COLUMNS, index / TileCatalog.ATLAS_COLUMNS)


static func _collision_box() -> PackedVector2Array:
	var half := Vector2(TileCatalog.TILE_SIZE) * 0.5 - Vector2.ONE * COLLISION_INSET
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
