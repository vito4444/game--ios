extends GutTest

## Checks the output of tools/gen_art.py against the specification the rest of
## the game assumes: tile-aligned atlases, fixed character sheet geometry, and
## a palette nothing has strayed outside of.

const TERRAIN_ATLAS := "res://assets/generated/tiles/terrain_atlas.png"
const PROPS_ATLAS := "res://assets/generated/tiles/props_atlas.png"
const APP_ICON := "res://assets/generated/icons/app_icon.png"
const ICON_SHEET := "res://assets/generated/ui/icons.png"
const CHARACTER_SHEETS := [
	"res://assets/generated/actors/player.png",
	"res://assets/generated/actors/officer.png",
	"res://assets/generated/actors/trader.png",
]

const TILE_SIZE := 32
const ACTOR_FRAME_WIDTH := 32
const ACTOR_FRAME_HEIGHT := 48
const ACTOR_COLUMNS := 4
const ACTOR_ROWS := 4


func _texture(path: String) -> Texture2D:
	assert_true(ResourceLoader.exists(path), "missing texture: %s" % path)
	return load(path) as Texture2D


func test_tile_atlases_are_tile_aligned() -> void:
	for path in [TERRAIN_ATLAS, PROPS_ATLAS]:
		var texture := _texture(path)
		assert_eq(texture.get_width() % TILE_SIZE, 0, "%s width not a multiple of 32" % path)
		assert_eq(texture.get_height() % TILE_SIZE, 0, "%s height not a multiple of 32" % path)


func test_character_sheets_are_four_by_four_frames() -> void:
	for path in CHARACTER_SHEETS:
		var texture := _texture(path)
		assert_eq(texture.get_width(), ACTOR_FRAME_WIDTH * ACTOR_COLUMNS, path)
		assert_eq(texture.get_height(), ACTOR_FRAME_HEIGHT * ACTOR_ROWS, path)


func test_app_icon_is_1024_square() -> void:
	var texture := _texture(APP_ICON)
	assert_eq(texture.get_width(), 1024, "App Store requires a 1024x1024 icon")
	assert_eq(texture.get_height(), 1024)


func test_app_icon_is_fully_opaque() -> void:
	# Apple rejects icons with an alpha channel that is not fully opaque.
	var image := _texture(APP_ICON).get_image()
	var transparent := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).a < 1.0:
				transparent += 1
	assert_eq(transparent, 0, "app icon must not contain transparent pixels")


func test_sprites_only_use_palette_colours() -> void:
	for path in [TERRAIN_ATLAS, PROPS_ATLAS, ICON_SHEET] + CHARACTER_SHEETS:
		var image := _texture(path).get_image()
		var offenders := {}
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				if not Palette.contains(pixel):
					offenders[pixel.to_html(false)] = true
		assert_eq(offenders.keys(), [], "%s uses off-palette colours" % path)


func test_sprites_have_no_partial_transparency() -> void:
	# Anything between 0 and 1 means an anti-aliased edge crept in, which breaks
	# the look the moment the camera scales the sprite up.
	for path in CHARACTER_SHEETS + [ICON_SHEET]:
		var image := _texture(path).get_image()
		var soft := 0
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				if alpha > 0.0 and alpha < 1.0:
					soft += 1
		assert_eq(soft, 0, "%s contains %d partially transparent pixels" % [path, soft])


func test_textures_import_without_compression_or_mipmaps() -> void:
	# VRAM compression turns 32x32 pixel art into mush, and mipmaps make it
	# blurry as soon as the camera is not at an integer zoom.
	for path in [TERRAIN_ATLAS, PROPS_ATLAS, ICON_SHEET, APP_ICON] + CHARACTER_SHEETS:
		var config := ConfigFile.new()
		var error := config.load(path + ".import")
		assert_eq(error, OK, "cannot read import settings for %s" % path)
		assert_eq(config.get_value("params", "compress/mode"), 0, "%s is compressed" % path)
		assert_eq(config.get_value("params", "mipmaps/generate"), false, "%s has mipmaps" % path)
		assert_eq(
			config.get_value("params", "detect_3d/compress_to"),
			0,
			"%s can still be silently VRAM-compressed by 3D detection" % path
		)
