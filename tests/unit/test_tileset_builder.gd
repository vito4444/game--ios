extends GutTest

## The TileSet is assembled in code from TileCatalog, so these assertions are
## what stands between a renamed tile and a silently blank map.

var tile_set: TileSet


func before_all() -> void:
	tile_set = TileSetBuilder.build()


func test_tile_size_matches_the_art() -> void:
	assert_eq(tile_set.tile_size, Vector2i(32, 32))


func test_both_atlas_sources_are_registered() -> void:
	assert_eq(tile_set.get_source_count(), 2)
	assert_true(tile_set.has_source(TileCatalog.SOURCE_TERRAIN))
	assert_true(tile_set.has_source(TileCatalog.SOURCE_PROPS))


func test_every_catalogued_tile_exists_in_its_source() -> void:
	for order in [
		[TileCatalog.SOURCE_TERRAIN, TileCatalog.TERRAIN_ORDER],
		[TileCatalog.SOURCE_PROPS, TileCatalog.PROPS_ORDER],
	]:
		var source := tile_set.get_source(order[0]) as TileSetAtlasSource
		var names: Array = order[1]
		assert_eq(source.get_tiles_count(), names.size())
		for index in names.size():
			var coords := Vector2i(
				index % TileCatalog.ATLAS_COLUMNS, index / TileCatalog.ATLAS_COLUMNS
			)
			assert_true(source.has_tile(coords), "%s missing at %s" % [names[index], coords])


func test_catalogued_tiles_fit_inside_the_generated_atlas() -> void:
	# Guards against tools/gen_art.py and TileCatalog drifting out of order.
	for order in [
		[TileCatalog.SOURCE_TERRAIN, TileCatalog.TERRAIN_ORDER],
		[TileCatalog.SOURCE_PROPS, TileCatalog.PROPS_ORDER],
	]:
		var source := tile_set.get_source(order[0]) as TileSetAtlasSource
		var grid := source.get_atlas_grid_size()
		var names: Array = order[1]
		for index in names.size():
			var coords := Vector2i(
				index % TileCatalog.ATLAS_COLUMNS, index / TileCatalog.ATLAS_COLUMNS
			)
			assert_true(
				coords.x < grid.x and coords.y < grid.y,
				"%s at %s falls outside the %s atlas" % [names[index], coords, grid]
			)


func test_every_map_symbol_resolves_to_a_tile_in_its_own_atlas() -> void:
	# A ground symbol pointing at a prop tile (or vice versa) still passes every
	# other check here and only shows up as an error at map-paint time.
	for symbol in TileCatalog.GROUND_SYMBOLS:
		var tile: StringName = TileCatalog.GROUND_SYMBOLS[symbol]["tile"]
		assert_true(
			TileCatalog.TERRAIN_ORDER.has(tile),
			"ground symbol '%s' names '%s', which is not a terrain tile" % [symbol, tile]
		)
	for symbol in TileCatalog.PROP_SYMBOLS:
		var tile: StringName = TileCatalog.PROP_SYMBOLS[symbol]["tile"]
		assert_true(
			TileCatalog.PROPS_ORDER.has(tile),
			"prop symbol '%s' names '%s', which is not a prop tile" % [symbol, tile]
		)


func test_tile_names_are_unique_within_each_atlas() -> void:
	for order in [TileCatalog.TERRAIN_ORDER, TileCatalog.PROPS_ORDER]:
		var seen := {}
		for tile in order:
			assert_false(seen.has(tile), "duplicate tile name: %s" % tile)
			seen[tile] = true


func test_walls_collide_and_floors_do_not() -> void:
	var source := tile_set.get_source(TileCatalog.SOURCE_TERRAIN) as TileSetAtlasSource
	var wall := source.get_tile_data(TileCatalog.terrain_coords(&"wall_hull"), 0)
	var floor_tile := source.get_tile_data(TileCatalog.terrain_coords(&"floor_grate"), 0)
	assert_eq(wall.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER), 1)
	assert_eq(floor_tile.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER), 0)


func test_closed_doors_and_hatches_collide() -> void:
	var source := tile_set.get_source(TileCatalog.SOURCE_TERRAIN) as TileSetAtlasSource
	for tile in [&"door_closed", &"hatch_closed"]:
		var data := source.get_tile_data(TileCatalog.terrain_coords(tile), 0)
		assert_eq(
			data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER),
			1,
			"%s should block the player" % tile
		)


func test_props_sort_from_their_base() -> void:
	var source := tile_set.get_source(TileCatalog.SOURCE_PROPS) as TileSetAtlasSource
	var bunk := source.get_tile_data(TileCatalog.prop_coords(&"bunk"), 0)
	assert_eq(bunk.y_sort_origin, TileSetBuilder.Y_SORT_ORIGIN)


func test_collision_box_is_inset_from_the_tile_edge() -> void:
	var source := tile_set.get_source(TileCatalog.SOURCE_TERRAIN) as TileSetAtlasSource
	var wall := source.get_tile_data(TileCatalog.terrain_coords(&"wall_hull"), 0)
	var points := wall.get_collision_polygon_points(TileSetBuilder.PHYSICS_LAYER, 0)
	assert_eq(points.size(), 4)
	assert_eq(points[0], Vector2(-15, -15))
	assert_eq(points[2], Vector2(15, 15))
