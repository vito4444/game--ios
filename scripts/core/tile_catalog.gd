class_name TileCatalog
extends RefCounted

## Maps the characters used in data/maps/*.map onto atlas coordinates and
## collision behaviour.
##
## The atlas order here must match the TERRAIN_TILES and PROP_TILES tuples in
## tools/gen_art.py. tests/unit/test_tile_catalog.gd checks the two agree by
## asserting every catalogued coordinate lands inside the generated texture.

const TERRAIN_TEXTURE := "res://assets/generated/tiles/terrain_atlas.png"
const PROPS_TEXTURE := "res://assets/generated/tiles/props_atlas.png"

const SOURCE_TERRAIN := 0
const SOURCE_PROPS := 1

const TILE_SIZE := Vector2i(32, 32)
const ATLAS_COLUMNS := 8

const EMPTY_SYMBOL := "."

## Order matches tools/gen_art.py TERRAIN_TILES.
const TERRAIN_ORDER: Array[StringName] = [
	&"floor_grate",
	&"floor_tile",
	&"floor_concrete",
	&"floor_wet",
	&"floor_restricted",
	&"wall_hull",
	&"wall_hull_top",
	&"wall_window",
	&"wall_alarm",
	&"door_closed",
	&"door_open",
	&"hatch_closed",
	&"hatch_open",
	&"vent",
	&"moonpool",
]

## Order matches tools/gen_art.py PROP_TILES.
const PROPS_ORDER: Array[StringName] = [
	&"bunk",
	&"locker",
	&"workbench",
	&"console",
	&"crate",
	&"table",
	&"chair",
	&"lamp",
	&"conditioning_rig",
	&"technical_terminal",
	&"pressure_chamber",
	&"market_crate",
	&"drive_component",
	&"hangar_door",
	&"pipe_horizontal",
	&"pipe_vertical",
]

## Ground characters. `solid` blocks movement.
const GROUND_SYMBOLS := {
	"#": {"tile": &"wall_hull", "solid": true},
	"W": {"tile": &"wall_window", "solid": true},
	"A": {"tile": &"wall_alarm", "solid": true},
	"V": {"tile": &"vent", "solid": true},
	".": {"tile": &"floor_grate", "solid": false},
	",": {"tile": &"floor_tile", "solid": false},
	":": {"tile": &"floor_concrete", "solid": false},
	"~": {"tile": &"floor_wet", "solid": false},
	"!": {"tile": &"floor_restricted", "solid": false},
	"o": {"tile": &"moonpool", "solid": true},
	"D": {"tile": &"door_closed", "solid": true},
	"H": {"tile": &"hatch_closed", "solid": true},
}

## Prop characters. Lamps hang from the ceiling and pipes run along the deck,
## so neither blocks the player.
const PROP_SYMBOLS := {
	"b": {"tile": &"bunk", "solid": true},
	"l": {"tile": &"locker", "solid": true},
	"t": {"tile": &"workbench", "solid": true},
	"c": {"tile": &"console", "solid": true},
	"x": {"tile": &"crate", "solid": true},
	"T": {"tile": &"table", "solid": true},
	"h": {"tile": &"chair", "solid": true},
	"L": {"tile": &"lamp", "solid": false},
	"g": {"tile": &"conditioning_rig", "solid": true},
	"e": {"tile": &"technical_terminal", "solid": true},
	"p": {"tile": &"pressure_chamber", "solid": true},
	"m": {"tile": &"market_crate", "solid": true},
	"d": {"tile": &"drive_component", "solid": false},
	"G": {"tile": &"hangar_door", "solid": true},
	"=": {"tile": &"pipe_horizontal", "solid": false},
	"|": {"tile": &"pipe_vertical", "solid": false},
}


static func atlas_coords(order: Array[StringName], tile: StringName) -> Vector2i:
	var index := order.find(tile)
	if index < 0:
		push_error("unknown tile: %s" % tile)
		return Vector2i.ZERO
	return Vector2i(index % ATLAS_COLUMNS, index / ATLAS_COLUMNS)


static func terrain_coords(tile: StringName) -> Vector2i:
	return atlas_coords(TERRAIN_ORDER, tile)


static func prop_coords(tile: StringName) -> Vector2i:
	return atlas_coords(PROPS_ORDER, tile)


static func ground_entry(symbol: String) -> Dictionary:
	return GROUND_SYMBOLS.get(symbol, {})


static func prop_entry(symbol: String) -> Dictionary:
	return PROP_SYMBOLS.get(symbol, {})
