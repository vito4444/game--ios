extends SceneTree

## Loads every GDScript and scene in the project and reports anything that
## fails to compile or instantiate.
##
## `godot --import` only touches importable resources, so a parse error in a
## .gd file slips through it entirely and first shows up as a wall of noise in
## the test run. This turns that into one explicit gate.

const SKIP_PREFIXES := [
	"res://addons/",  # third-party, and GUT deliberately ships uncompilable fixtures
	"res://.godot/",
]


func _initialize() -> void:
	# Not _init(): autoload singletons are registered after the SceneTree is
	# constructed, and scripts that reference them do not compile before that.
	var failures := 0
	failures += _check(_collect("res://", ".gd"), _load_script)
	failures += _check(_collect("res://", ".tscn"), _load_scene)

	if failures > 0:
		printerr("%d resource(s) failed to load" % failures)
		quit(1)
		return
	print("all scripts and scenes load cleanly")
	quit(0)


func _check(paths: PackedStringArray, loader: Callable) -> int:
	var failures := 0
	for path in paths:
		if not loader.call(path):
			printerr("FAILED %s" % path)
			failures += 1
	return failures


func _load_script(path: String) -> bool:
	var script := load(path)
	if script == null:
		return false
	return (script as GDScript).can_instantiate() or (script as GDScript).is_tool()


func _load_scene(path: String) -> bool:
	var scene := load(path)
	if scene == null:
		return false
	var instance := (scene as PackedScene).instantiate()
	if instance == null:
		return false
	instance.free()
	return true


func _collect(root: String, suffix: String) -> PackedStringArray:
	var found := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		return found
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := root.path_join(entry)
		if directory.current_is_dir():
			if not _skipped(path + "/"):
				found.append_array(_collect(path, suffix))
		elif entry.ends_with(suffix) and not _skipped(path):
			found.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return found


func _skipped(path: String) -> bool:
	for prefix in SKIP_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false
