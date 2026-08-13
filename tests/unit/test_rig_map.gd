extends GutTest

## Parsing and collision queries for data/maps/abyss9.map.

const MAP_PATH := "res://data/maps/abyss9.map"

var map: RigMap


func before_each() -> void:
	map = RigMap.load_from(MAP_PATH)


func test_map_parses_without_errors() -> void:
	assert_eq(map.errors, PackedStringArray(), "map failed validation")
	assert_true(map.is_valid())


func test_dimensions_match_header() -> void:
	assert_eq(map.map_name, "Abyss-9")
	assert_eq(map.width, 44)
	assert_eq(map.height, 34)
	assert_eq(map.ground.size(), 34)
	assert_eq(map.props.size(), 34)


func test_outer_hull_is_solid_on_every_edge() -> void:
	for x in map.width:
		assert_true(map.is_solid(Vector2i(x, 0)), "top edge open at x=%d" % x)
		assert_true(map.is_solid(Vector2i(x, map.height - 1)), "bottom edge open at x=%d" % x)
	for y in map.height:
		assert_true(map.is_solid(Vector2i(0, y)), "left edge open at y=%d" % y)
		assert_true(map.is_solid(Vector2i(map.width - 1, y)), "right edge open at y=%d" % y)


func test_out_of_bounds_counts_as_solid() -> void:
	assert_true(map.is_solid(Vector2i(-1, 5)))
	assert_true(map.is_solid(Vector2i(5, -1)))
	assert_true(map.is_solid(Vector2i(map.width, 5)))
	assert_true(map.is_solid(Vector2i(5, map.height)))


func test_spawn_is_walkable() -> void:
	assert_true(map.in_bounds(map.spawn))
	assert_false(map.is_solid(map.spawn), "player would start inside a wall")


func test_props_block_movement_but_lamps_do_not() -> void:
	var bunk_cell := _find_prop("b")
	assert_ne(bunk_cell, Vector2i(-1, -1), "map has no bunk to test")
	assert_true(map.is_solid(bunk_cell), "bunks should block movement")

	var lamp_cell := _find_prop("L")
	assert_ne(lamp_cell, Vector2i(-1, -1), "map has no lamp to test")
	assert_false(map.is_solid(lamp_cell), "ceiling lamps should not block movement")


func test_zones_cover_the_expected_rooms() -> void:
	var ids := []
	for zone in map.zones:
		ids.append(String(zone.id))
	ids.sort()
	assert_eq(
		ids,
		[
			"bunk_pods",
			"galley",
			"hangar",
			"infirmary",
			"moon_pool",
			"muster_deck",
			"security_office",
			"solitary",
			"training_bay",
			"workshop",
		]
	)


func test_restricted_zones_are_the_security_office_and_hangar() -> void:
	var restricted := []
	for zone in map.zones_of_kind(&"restricted"):
		restricted.append(String(zone.id))
	restricted.sort()
	assert_eq(restricted, ["hangar", "security_office"])


func test_zone_lookup_by_cell() -> void:
	var muster := map.zone_by_id(&"muster_deck")
	assert_not_null(muster)
	var inside := muster.rect.position + Vector2i(1, 1)
	assert_eq(map.zone_at(inside).id, &"muster_deck")
	assert_null(map.zone_at(Vector2i(0, 0)), "the hull itself is not a zone")


func test_cell_centre_is_in_the_middle_of_the_tile() -> void:
	assert_eq(map.cell_centre(Vector2i(0, 0)), Vector2(16, 16))
	assert_eq(map.cell_centre(Vector2i(2, 3)), Vector2(80, 112))


func test_pixel_size_matches_tile_count() -> void:
	assert_eq(map.pixel_size(), Vector2i(44 * 32, 34 * 32))


func test_parser_reports_a_row_of_the_wrong_width() -> void:
	var broken := RigMap.new()
	broken._parse("width = 3\nheight = 2\n[ground]\n###\n##\n[props]\n...\n...\n[spawn]\nplayer = 1,1\n")
	assert_string_contains(broken.errors[0], "ground row 1 is 2 wide")


func test_parser_reports_an_unknown_symbol() -> void:
	var broken := RigMap.new()
	broken._parse("width = 2\nheight = 1\n[ground]\n#Z\n[props]\n..\n[spawn]\nplayer = 0,0\n")
	var joined := " ".join(broken.errors)
	assert_string_contains(joined, "unknown ground symbol 'Z'")


func test_parser_rejects_a_spawn_inside_a_wall() -> void:
	var broken := RigMap.new()
	broken._parse("width = 2\nheight = 1\n[ground]\n#.\n[props]\n..\n[spawn]\nplayer = 0,0\n")
	var joined := " ".join(broken.errors)
	assert_string_contains(joined, "inside a solid tile")


func _find_prop(symbol: String) -> Vector2i:
	for y in map.height:
		for x in map.width:
			if map.prop_symbol(Vector2i(x, y)) == symbol:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
