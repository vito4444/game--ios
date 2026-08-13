class_name Palette
extends RefCounted

## The game's entire colour vocabulary, mirroring tools/palette.py.
##
## UI code picks colours from here so that interface elements sit in the same
## 16 colours as the sprites. tests/unit/test_generated_art.gd asserts that
## every pixel of the generated art falls inside ALL, which is what keeps this
## list and the Python side from drifting apart.

const ABYSS := Color("0d1b2a")
const HULL_SHADOW := Color("132a3a")
const HULL_DARK := Color("1b3a4b")
const HULL := Color("2e6f7e")
const HULL_LIGHT := Color("4aa3a2")
const HULL_HIGHLIGHT := Color("8fd6c9")
const AMBER := Color("f2a65a")
const AMBER_DARK := Color("e0752d")
const ALARM := Color("d94f3d")
const RUST := Color("7a3b2e")
const STEEL_DARK := Color("3d3a4b")
const STEEL := Color("6b6880")
const STEEL_LIGHT := Color("a8a4b8")
const BONE := Color("e8e6df")
const INK := Color("2b2b2b")
const WHITE := Color("f7f3e8")

const ALL: Array[Color] = [
	ABYSS,
	HULL_SHADOW,
	HULL_DARK,
	HULL,
	HULL_LIGHT,
	HULL_HIGHLIGHT,
	AMBER,
	AMBER_DARK,
	ALARM,
	RUST,
	STEEL_DARK,
	STEEL,
	STEEL_LIGHT,
	BONE,
	INK,
	WHITE,
]


static func contains(colour: Color) -> bool:
	for entry in ALL:
		if is_equal_approx(entry.r, colour.r) \
				and is_equal_approx(entry.g, colour.g) \
				and is_equal_approx(entry.b, colour.b):
			return true
	return false
