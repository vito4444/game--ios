extends GutTest

## Line of sight on a purpose-built map, so the geometry under test is visible
## in the test rather than buried in the real rig layout.
##
##   0123456
## 0 #######
## 1 #.....#
## 2 #..#..#
## 3 #.....#
## 4 #..x..#     x = crate, blocks sight
## 5 #..b..#     b = bunk, does not block sight
## 6 #######

const LAYOUT := """width = 7
height = 7
[ground]
#######
#.....#
#..#..#
#.....#
#.....#
#.....#
#######
[props]
.......
.......
.......
.......
...x...
...b...
.......
[spawn]
player = 1,1
"""

var map: RigMap
var cone: Vision.Cone


func before_each() -> void:
	map = RigMap.new()
	map._parse(LAYOUT)
	cone = Vision.Cone.new()


func test_the_fixture_map_is_valid() -> void:
	assert_eq(map.errors, PackedStringArray())


func test_a_target_straight_ahead_in_the_open_is_seen() -> void:
	assert_true(Vision.can_see(map, Vector2i(1, 3), Vector2.RIGHT, Vector2i(5, 3), cone))


func test_a_target_behind_the_officer_is_not_seen() -> void:
	assert_false(Vision.can_see(map, Vector2i(5, 3), Vector2.RIGHT, Vector2i(1, 3), cone))


func test_a_target_outside_the_cone_angle_is_not_seen() -> void:
	# Directly above, while looking right: 90 degrees off, cone is 45.
	assert_false(Vision.can_see(map, Vector2i(3, 5), Vector2.RIGHT, Vector2i(3, 1), cone))


func test_a_target_beyond_the_range_is_not_seen() -> void:
	var short_sighted := Vision.Cone.new(2.0)
	assert_false(Vision.can_see(map, Vector2i(1, 3), Vector2.RIGHT, Vector2i(5, 3), short_sighted))
	assert_true(Vision.can_see(map, Vector2i(1, 3), Vector2.RIGHT, Vector2i(3, 3), short_sighted))


func test_a_wall_between_them_blocks_sight() -> void:
	assert_false(Vision.can_see(map, Vector2i(1, 2), Vector2.RIGHT, Vector2i(5, 2), cone))


func test_a_crate_blocks_sight_but_a_bunk_does_not() -> void:
	assert_false(
		Vision.can_see(map, Vector2i(3, 2), Vector2.DOWN, Vector2i(3, 5), cone),
		"the crate at 3,4 should hide the cell behind it"
	)
	assert_true(
		Vision.can_see(map, Vector2i(3, 3), Vector2.DOWN, Vector2i(3, 4), cone),
		"standing on the crate's own tile is still visible"
	)


func test_someone_at_the_officers_shoulder_is_noticed_regardless_of_facing() -> void:
	assert_true(
		Vision.can_see(map, Vector2i(3, 3), Vector2.RIGHT, Vector2i(3, 4), cone),
		"an adjacent target should be noticed even when looking away"
	)


func test_the_officers_own_tile_always_counts_as_seen() -> void:
	assert_true(Vision.can_see(map, Vector2i(2, 2), Vector2.UP, Vector2i(2, 2), cone))


func test_line_between_excludes_both_endpoints() -> void:
	var cells := Vision.line_between(Vector2i(1, 3), Vector2i(4, 3))
	assert_eq(cells, [Vector2i(2, 3), Vector2i(3, 3)] as Array[Vector2i])
	assert_eq(Vision.line_between(Vector2i(1, 1), Vector2i(2, 1)).size(), 0)


func test_line_between_is_symmetric() -> void:
	var forward := Vision.line_between(Vector2i(1, 1), Vector2i(5, 4))
	var backward := Vision.line_between(Vector2i(5, 4), Vector2i(1, 1))
	backward.reverse()
	assert_eq(forward, backward)


func test_a_shrunken_cone_sees_less_far() -> void:
	var dimmed := cone.scaled(0.25)
	assert_eq(dimmed.range_tiles, Vision.DEFAULT_RANGE_TILES * 0.25)
	assert_true(Vision.can_see(map, Vector2i(1, 3), Vector2.RIGHT, Vector2i(5, 3), cone))
	assert_false(Vision.can_see(map, Vector2i(1, 3), Vector2.RIGHT, Vector2i(5, 3), dimmed))


func test_facing_snaps_to_a_cardinal_direction() -> void:
	assert_eq(Vision.facing_from(Vector2(3, 1)), Vector2.RIGHT)
	assert_eq(Vision.facing_from(Vector2(-3, 1)), Vector2.LEFT)
	assert_eq(Vision.facing_from(Vector2(1, 3)), Vector2.DOWN)
	assert_eq(Vision.facing_from(Vector2(1, -3)), Vector2.UP)
	assert_eq(Vision.facing_from(Vector2.ZERO), Vector2.DOWN)
