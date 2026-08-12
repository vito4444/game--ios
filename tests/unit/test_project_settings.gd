extends GutTest

## Guards the project settings that the iOS export depends on. Flipping any of
## these back to the Godot default silently breaks the App Store build long
## after the change is made, so they are asserted here instead.


func test_project_name_matches_bundle_display_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Deep Contract")


func test_renderer_is_mobile() -> void:
	assert_eq(ProjectSettings.get_setting("renderer/rendering_method"), null,
		"rendering method must live under rendering/renderer/, not the root")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")


func test_etc2_astc_import_enabled() -> void:
	assert_true(
		ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"),
		"iOS export refuses to run without ETC2/ASTC import enabled"
	)


func test_texture_filter_is_nearest_for_pixel_art() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_viewport_is_640x360_landscape() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)


func test_stretch_mode_supports_varied_phone_aspects() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_handheld_orientation_is_sensor_landscape() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4)


func test_main_scene_exists() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(main_scene), "main scene missing: %s" % main_scene)
