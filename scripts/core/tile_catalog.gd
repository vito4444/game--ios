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

## Ground characters. `solid` blocks movement, `blocks_sight` breaks a guard's
## line of sight. Doors block both while shut; a porthole blocks movement but
## not the view through it.
const GROUND_SYMBOLS := {
	"#": {"tile": &"wall_hull", "solid": true, "blocks_sight": true},
	"W": {"tile": &"wall_window", "solid": true, "blocks_sight": true},
	"A": {"tile": &"wall_alarm", "solid": true, "blocks_sight": true},
	"V": {"tile": &"vent", "solid": true, "blocks_sight": true},
	".": {"tile": &"floor_grate", "solid": false, "blocks_sight": false},
	",": {"tile": &"floor_tile", "solid": false, "blocks_sight": false},
	":": {"tile": &"floor_concrete", "solid": false, "blocks_sight": false},
	"~": {"tile": &"floor_wet", "solid": false, "blocks_sight": false},
	"!": {"tile": &"floor_restricted", "solid": false, "blocks_sight": false},
	"o": {"tile": &"moonpool", "solid": true, "blocks_sight": false},
	"D": {"tile": &"door_closed", "solid": true, "blocks_sight": true, "door": POWERED_DOOR},
	"H": {"tile": &"hatch_closed", "solid": true, "blocks_sight": true, "door": PRESSURE_HATCH},
}

## Doors slide open when someone who can open them stands next to them. Powered
## doors answer to anyone; pressure hatches only to security, until the player
## finds another way through.
const POWERED_DOOR := &"powered"
const PRESSURE_HATCH := &"pressure"

const DOOR_OPEN_TILE := {
	POWERED_DOOR: &"door_open",
	PRESSURE_HATCH: &"hatch_open",
}

## Prop characters. Height decides sight: a locker or a stacked crate hides the
## player, a bunk or a table does not. Lamps hang from the ceiling and pipes run
## along the deck, so neither blocks anything.
const PROP_SYMBOLS := {
	"b": {"tile": &"bunk", "solid": true, "blocks_sight": false},
	"l": {"tile": &"locker", "solid": true, "blocks_sight": true},
	"t": {"tile": &"workbench", "solid": true, "blocks_sight": false},
	"c": {"tile": &"console", "solid": true, "blocks_sight": false},
	"x": {"tile": &"crate", "solid": true, "blocks_sight": true},
	"T": {"tile": &"table", "solid": true, "blocks_sight": false},
	"h": {"tile": &"chair", "solid": true, "blocks_sight": false},
	"L": {"tile": &"lamp", "solid": false, "blocks_sight": false},
	"g": {"tile": &"conditioning_rig", "solid": true, "blocks_sight": true},
	"e": {"tile": &"technical_terminal", "solid": true, "blocks_sight": false},
	"p": {"tile": &"pressure_chamber", "solid": true, "blocks_sight": true},
	"m": {"tile": &"market_crate", "solid": true, "blocks_sight": true},
	"d": {"tile": &"drive_component", "solid": false, "blocks_sight": false},
	"G": {"tile": &"hangar_door", "solid": true, "blocks_sight": true},
	"=": {"tile": &"pipe_horizontal", "solid": false, "blocks_sight": false},
	"|": {"tile": &"pipe_vertical", "solid": false, "blocks_sight": false},
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


## &"" when the symbol is not a door.
static func door_kind(symbol: String) -> StringName:
	return ground_entry(symbol).get("door", &"")


static func open_tile_for(kind: StringName) -> StringName:
	return DOOR_OPEN_TILE.get(kind, &"door_open")
