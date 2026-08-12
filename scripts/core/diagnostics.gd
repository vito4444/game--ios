class_name Diagnostics
extends RefCounted

## Prints the rendering state the game depends on.
##
## Only runs when DEEPCONTRACT_AUTOSTART is set, which is the automated capture
## path. On a device the alternative to this is guessing: a screenshot shows
## that something did not draw but not why, and there is no debugger attached.

const ENABLE_ENV := "DEEPCONTRACT_AUTOSTART"

## Written as well as printed: Godot's print goes to stdout, which `simctl
## launch` does not capture unless it stays in the foreground, so the file is
## the only way the CI job gets these back off the device.
const LOG_PATH := "user://diagnostics.log"

static var _lines: PackedStringArray = PackedStringArray()


static func enabled() -> bool:
	return OS.get_environment(ENABLE_ENV) == "1"


static func report(world: RigWorld) -> void:
	if not enabled():
		return
	_lines.clear()

	var viewport := world.get_viewport()
	var camera := world.camera()
	var ground := world.get_node_or_null("Ground") as TileMapLayer

	_line("driver", "%s / %s" % [
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()
	])
	_line("rendering method", str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method")
	))
	_line("window size", str(DisplayServer.window_get_size()))
	_line("viewport rect", str(viewport.get_visible_rect()))
	_line("safe area", str(DisplayServer.get_display_safe_area()))
	_line("content scale", "%s / %s" % [
		get_window_stretch_mode(), str(viewport.get_screen_transform())
	])

	if camera != null:
		_line("camera", "pos=%s current=%s screen_centre=%s zoom=%s" % [
			camera.global_position,
			camera.is_current(),
			camera.get_screen_center_position(),
			camera.zoom,
		])
		_line("camera limits", "l=%d t=%d r=%d b=%d" % [
			camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom
		])

	if ground != null:
		var cells := ground.get_used_cells()
		_line("ground layer", "cells=%d rect=%s visible=%s modulate=%s" % [
			cells.size(), ground.get_used_rect(), ground.visible, ground.modulate
		])
		_line("ground transform", "global=%s" % ground.get_global_transform())
		if not cells.is_empty():
			var first: Vector2i = cells[0]
			_line("ground sample", "cell=%s source=%d atlas=%s" % [
				first, ground.get_cell_source_id(first), ground.get_cell_atlas_coords(first)
			])
		var tile_set := ground.tile_set
		if tile_set != null and tile_set.get_source_count() > 0:
			var source := tile_set.get_source(TileCatalog.SOURCE_TERRAIN) as TileSetAtlasSource
			var texture := source.texture if source != null else null
			_line("terrain texture", "%s size=%s" % [
				texture.resource_path if texture else "<none>",
				texture.get_size() if texture else Vector2.ZERO,
			])

	if world.player != null:
		_line("player", "pos=%s visible=%s" % [
			world.player.global_position, world.player.visible
		])

	_line(
		"clear colour",
		str(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
	)

	_flush()


## Draws the terrain atlas straight onto a CanvasLayer, bypassing the world and
## its camera entirely.
##
## If this shows and the world does not, the textures are fine and the problem
## is in the Node2D path. If neither shows, the texture never made it onto the
## device in a form the driver accepts. One capture answers which.
static func attach_texture_probe(parent: Node) -> void:
	if not enabled():
		return

	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.name = "DiagnosticProbe"
	parent.add_child(layer)

	var texture: Texture2D = load(TileCatalog.TERRAIN_TEXTURE)
	var probe := TextureRect.new()
	probe.texture = texture
	probe.position = Vector2(180, 44)
	probe.size = texture.get_size()
	layer.add_child(probe)

	var label := Label.new()
	label.text = "probe: terrain atlas %s" % texture.get_size()
	label.position = Vector2(180, 44 + texture.get_size().y + 2)
	label.add_theme_font_size_override("font_size", 10)
	layer.add_child(label)

	_line("probe", "attached %s" % texture.get_size())
	_flush()


static func get_window_stretch_mode() -> String:
	return "%s/%s" % [
		ProjectSettings.get_setting("display/window/stretch/mode"),
		ProjectSettings.get_setting("display/window/stretch/aspect"),
	]


static func _line(label: String, value: String) -> void:
	# Prefixed so the CI step can grep it out.
	var text := "[diag] %-18s %s" % [label, value]
	print(text)
	_lines.append(text)


static func _flush() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines) + "\n")
	file.close()
