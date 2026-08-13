class_name SelfTest
extends RefCounted

## Boots the game's data from inside an exported build and reports what loaded.
##
## The unit tests run against the source tree, where every file is present by
## definition. An export only packs what the export filter matches, and a file
## it silently drops does not fail anything until the game is on a device with
## an empty map. This runs inside the packaged game, so it sees exactly what
## shipped.
##
##   DEEPCONTRACT_SELFTEST=1 build/linux/DeepContract.x86_64 --headless

const ENABLE_ENV := "DEEPCONTRACT_SELFTEST"

## Sanity floors, not exact counts: this is checking that data arrived, not
## re-testing the rules.
const MINIMUM_MAP_CELLS := 1000
const MINIMUM_ITEMS := 10
const MINIMUM_RECIPES := 3
const MINIMUM_JOBS := 3
const MINIMUM_ROUTES := 2
const MINIMUM_SCHEDULE_EVENTS := 10
const MINIMUM_SOUNDS := 10


static func requested() -> bool:
	return OS.get_environment(ENABLE_ENV) == "1"


## Returns the list of failures; empty means everything shipped.
static func run() -> PackedStringArray:
	var failures := PackedStringArray()

	var map := RigMap.load_from(RigWorld.DEFAULT_MAP)
	if not map.is_valid():
		failures.append("map did not load: %s" % " ".join(map.errors))
		# Everything else depends on the map, so stop here.
		_report(failures)
		return failures

	var cells := map.width * map.height
	if cells < MINIMUM_MAP_CELLS:
		failures.append("map has only %d cells" % cells)
	print("[selftest] map            %s %dx%d" % [map.map_name, map.width, map.height])

	var session := Session.new(map)
	if not session.errors.is_empty():
		failures.append("session errors: %s" % " ".join(session.errors))

	_expect(failures, "items", session.items.items.size(), MINIMUM_ITEMS)
	_expect(failures, "recipes", session.recipes.size(), MINIMUM_RECIPES)
	_expect(failures, "jobs", session.jobs.jobs.size(), MINIMUM_JOBS)
	_expect(failures, "routes", session.escape_routes.routes.size(), MINIMUM_ROUTES)
	_expect(failures, "schedule", session.schedule.size(), MINIMUM_SCHEDULE_EVENTS)
	_expect(failures, "patrols", map.patrols.size(), 1)
	_expect(failures, "stashes", session.stashes.size(), 1)
	_expect(failures, "loose items", map.loose_items.size(), 1)

	# Translations are packed as generated .translation files rather than the
	# source CSV, which is exactly the kind of thing an export can drop.
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("zh")
	var translated := TranslationServer.translate("MENU_START")
	TranslationServer.set_locale(previous)
	if translated == "MENU_START":
		failures.append("Chinese translations are missing from the build")
	print("[selftest] translation    MENU_START -> %s" % translated)

	var textures := [
		TileCatalog.TERRAIN_TEXTURE,
		TileCatalog.PROPS_TEXTURE,
		"res://assets/generated/actors/player.png",
	]
	for path in textures:
		if not ResourceLoader.exists(path):
			failures.append("missing texture: %s" % path)

	# Asked for by path rather than by listing the directory: an exported build
	# stores an imported WAV as a .remap pointing at a .sample, so the original
	# filename is not there to be found.
	var expected_sounds: Array[StringName] = [
		Audio.AMBIENCE,
		&"ui_click",
		&"door_open",
		&"door_close",
		&"pick_up",
		&"craft_done",
		&"alarm",
		&"blackout",
		&"power_restored",
		&"bubble",
		&"out_of_air",
		&"caught",
		&"escaped",
	]
	var sounds := 0
	for id in expected_sounds:
		if ResourceLoader.exists("%s/%s.wav" % [Audio.DIRECTORY, id]):
			sounds += 1
		else:
			failures.append("missing sound: %s" % id)
	_expect(failures, "sounds", sounds, MINIMUM_SOUNDS)

	_report(failures)
	return failures


static func _expect(failures: PackedStringArray, label: String, actual: int, minimum: int) -> void:
	print("[selftest] %-14s %d" % [label, actual])
	if actual < minimum:
		failures.append("%s: %d, expected at least %d" % [label, actual, minimum])


static func _report(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("[selftest] PASS - the exported build has its data")
		return
	printerr("[selftest] FAIL")
	for failure in failures:
		printerr("[selftest]   %s" % failure)
