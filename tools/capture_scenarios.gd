extends SceneTree

## Renders a set of staged gameplay moments to PNGs.
##
## Used to review visuals from a pull request, and later to produce the App
## Store screenshots, which is why the framing is set up per scenario rather
## than grabbing whatever the game happens to be showing.
##
##   xvfb-run -a .tools/godot --path . --resolution 1280x720 \
##       -s tools/capture_scenarios.gd -- /tmp/shots [locale]
##
## Run once per locale to produce the App Store screenshot sets.

const GAME_SCENE := "res://scenes/game.tscn"
const WARMUP_FRAMES := 30

## name, spawn cell, time of day in minutes, extra suspicion
const SCENARIOS := [
	{"name": "bunk_pods", "cell": Vector2i(3, 3), "minute": 6 * 60, "suspicion": 0},
	{"name": "muster_deck", "cell": Vector2i(21, 18), "minute": 8 * 60 + 5, "suspicion": 25},
	{"name": "galley", "cell": Vector2i(20, 4), "minute": 12 * 60 + 10, "suspicion": 10},
	{"name": "corridor_patrol", "cell": Vector2i(8, 11), "minute": 14 * 60, "suspicion": 40},
	{"name": "moon_pool", "cell": Vector2i(24, 27), "minute": 16 * 60, "suspicion": 60},
	{
		"name": "hangar_no_air",
		"cell": Vector2i(8, 29),
		"minute": 22 * 60 + 30,
		"suspicion": 85,
		"drain_air": 26.0,
	},
	{
		"name": "blackout",
		"cell": Vector2i(20, 11),
		"minute": 13 * 60 + 59,
		"suspicion": 45,
		"blackout": true,
	},
	{
		"name": "locker_panel",
		"cell": Vector2i(2, 2),
		"minute": 14 * 60 + 30,
		"suspicion": 30,
		"give": ["cutting_torch", "ration", "scrap_metal"],
		"interact": true,
	},
	{
		"name": "workbench_panel",
		"cell": Vector2i(32, 29),
		"face": Vector2(0, -1),
		"minute": 15 * 60,
		"suspicion": 20,
		"give": ["scrap_metal", "scrap_metal", "wrench", "keycard", "torch_fuel"],
		"interact": true,
	},
	{
		"name": "outcome",
		"cell": Vector2i(16, 29),
		"face": Vector2(1, 0),
		"minute": 2 * 60 + 30,
		"suspicion": 70,
		"give": ["drive_housing", "drive_impeller", "drive_core", "cutting_torch"],
		"interact": true,
	},
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run(output_dir, args[1] if args.size() > 1 else "")


func _run(output_dir: String, locale: String) -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		printerr("cannot load %s" % GAME_SCENE)
		quit(1)
		return

	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	# After the first frame: the Settings autoload applies its own locale in
	# _ready and would otherwise overwrite this.
	if not locale.is_empty():
		TranslationServer.set_locale(locale)
	await process_frame

	# Untyped on purpose: a `-s` script is compiled before autoloads are
	# registered, so naming RigWorld here would drag Player and its GameInput
	# reference into a compile that cannot yet resolve it.
	var rig := game.get_node("Rig")
	if rig.session == null:
		printerr("rig has no session")
		quit(1)
		return

	var panel := game.get_node("InteractionPanel")
	var hud := game.get_node("Hud")
	for scenario in SCENARIOS:
		panel.close()
		_stage(rig, scenario)
		# Alerts from the time that was skipped over are not part of the moment.
		hud.clear_notice()
		for _frame in WARMUP_FRAMES:
			await process_frame
		if scenario.get("interact", false):
			# Fetched by path rather than named: see the note on `rig` above.
			root.get_node("/root/GameInput").press_interact()
			for _frame in 4:
				await process_frame
		await process_frame

		var path: String = "%s/%s.png" % [output_dir, scenario["name"]]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			printerr("failed to write %s (error %d)" % [path, error])
			quit(1)
			return
		print("wrote %s" % path)

	quit(0)


func _stage(rig: Node, scenario: Dictionary) -> void:
	rig.player.global_position = rig.map.cell_centre(scenario["cell"])
	rig.session.clock.advance_to_minute_of_day(scenario["minute"])
	rig.session.suspicion.value = scenario["suspicion"]
	if scenario.has("face"):
		rig.player.face(scenario["face"])
	rig.session.inventory.clear()
	rig.session.oxygen.refill()
	if scenario.has("drain_air"):
		rig.session.oxygen.tick(scenario["drain_air"], true)
	if scenario.get("blackout", false):
		rig.session.blackout.begin()
	else:
		# Skipping to a time of day crosses 02:00 and 14:00, so a scenario that
		# did not ask for a blackout would otherwise inherit one and render
		# every later capture dimmed.
		rig.session.blackout.tick(Blackout.DURATION_SECONDS + 1.0)
	for item in scenario.get("give", []):
		rig.session.inventory.add(StringName(item))
