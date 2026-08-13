extends SceneTree

## Renders a scene to a PNG so gameplay visuals can be reviewed without a
## device. Needs a display; run it under xvfb-run on a headless machine.
##
##   xvfb-run -a .tools/godot --path . -s tools/screenshot.gd -- \
##       res://scenes/game.tscn /tmp/shot.png 60

const DEFAULT_SCENE := "res://scenes/game.tscn"
const DEFAULT_OUTPUT := "user://screenshot.png"
const DEFAULT_WARMUP_FRAMES := 45


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	var output: String = args[1] if args.size() > 1 else DEFAULT_OUTPUT
	var warmup: int = int(args[2]) if args.size() > 2 else DEFAULT_WARMUP_FRAMES

	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("cannot load scene: %s" % scene_path)
		quit(1)
		return

	root.add_child(packed.instantiate())
	_capture_after(warmup, output)


func _capture_after(frames: int, output: String) -> void:
	for i in frames:
		await process_frame

	# The viewport texture is only valid once the frame it belongs to has been
	# fully drawn.
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output)
	if error != OK:
		printerr("failed to write %s (error %d)" % [output, error])
		quit(1)
		return
	print("wrote %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	quit(0)
