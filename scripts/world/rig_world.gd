class_name RigWorld
extends Node2D

## Builds the playable rig from a text map and keeps the camera on the player.

const DEFAULT_MAP := "res://data/maps/abyss9.map"
const PLAYER_SCENE := "res://scenes/actors/player.tscn"
const OFFICER_SCENE := "res://scenes/actors/security_officer.tscn"

signal map_loaded(map: RigMap)
signal session_started(session: Session)
## Raised for interactions that need an interface; the immediate ones are
## handled here.
signal interaction_requested(target: Interaction.Target)
signal notice(text: String)

## Sleeping in a bunk skips to the wake-up call.
const WAKE_MINUTE_OF_DAY := Session.START_MINUTE_OF_DAY

## Game minutes spent on one training session.
const TRAINING_MINUTES := 45

@onready var _ground: TileMapLayer = $Ground
@onready var _props: TileMapLayer = $YSort/Props
@onready var _actors: Node2D = $YSort/Actors
@onready var _camera: Camera2D = $Camera
@onready var _darkness: CanvasModulate = $Darkness

var map: RigMap
var session: Session
var player: Player
var officers: Array[SecurityOfficer] = []


func _ready() -> void:
	GameInput.interact_pressed.connect(_on_interact)
	load_map(DEFAULT_MAP)


## What the action button would do from where the player is standing.
func current_interaction() -> Interaction.Target:
	if session == null or player == null:
		return Interaction.none()
	return Interaction.find(map, player.cell(), player.facing_direction())


func _on_interact() -> void:
	if session == null or not session.player_state.is_free():
		return

	var target := current_interaction()
	match target.kind:
		Interaction.Kind.SLEEP:
			_sleep()
		Interaction.Kind.PICK_UP:
			_pick_up(target.cell)
		Interaction.Kind.TRAIN:
			_train(target)
		Interaction.Kind.WORK:
			_work(target)
		Interaction.Kind.ESCAPE:
			_attempt_escape(target)
		Interaction.Kind.CRAFT:
			# A workbench is the welding post as well as a crafting station, so
			# during a shift the job takes precedence over private projects.
			if not _work(target):
				interaction_requested.emit(target)
		Interaction.Kind.NONE:
			pass
		_:
			interaction_requested.emit(target)


func _attempt_escape(target: Interaction.Target) -> void:
	var result := session.attempt_escape(player_zone(), target.prop)
	if result == EscapeRoutes.Result.OK:
		return

	var route := session.escape_routes.route_at(player_zone(), target.prop)
	if result == EscapeRoutes.Result.MISSING_KIT and route != null:
		var names: PackedStringArray = PackedStringArray()
		for id in session.escape_routes.missing_for(route):
			names.append(session.items.display_name(id))
		notice.emit("Still need: %s" % ", ".join(names))
		return
	if result == EscapeRoutes.Result.OUTSIDE_WINDOW and route != null:
		notice.emit("Nothing is due until %s." % route.window_text())
		return
	notice.emit(EscapeRoutes.reason_for(result))


## Returns true when this counted as a unit of the player's shift.
func _work(target: Interaction.Target) -> bool:
	var zone := player_zone()
	if not session.jobs.work(zone, target.prop):
		if target.kind == Interaction.Kind.WORK:
			notice.emit(_why_not_working(zone, target.prop))
		return false

	var job := session.jobs.assigned
	session.clock.advance_minutes(JobBoard.MINUTES_PER_UNIT)
	if session.jobs.is_shift_complete():
		notice.emit("Shift done. Report back at the next muster.")
	else:
		notice.emit("%s — %d of %d done." % [job.name, session.jobs.units_done, job.units])
	return true


func _why_not_working(zone: StringName, prop: StringName) -> String:
	if not session.jobs.on_shift:
		return "Not on shift."
	if session.jobs.is_shift_complete():
		return "Shift already finished."
	var here := session.jobs.job_at(zone, prop)
	if here == null:
		return "Nothing to do here."
	return "That is not your assignment."


func _sleep() -> void:
	session.clock.advance_to_minute_of_day(WAKE_MINUTE_OF_DAY)
	notice.emit("You sleep through to the wake-up call.")


func _pick_up(cell: Vector2i) -> void:
	var item_id := map.loose_item_at(cell)
	if item_id == &"":
		return
	if not session.inventory.can_add(item_id):
		notice.emit("No room for the %s." % session.items.display_name(item_id))
		return

	map.take_loose_item(cell)
	session.inventory.add(item_id)
	_props.erase_cell(cell)
	notice.emit("Picked up the %s." % session.items.display_name(item_id))


func _train(target: Interaction.Target) -> void:
	var stat := target.trains()
	if stat == &"":
		return
	var levelled := session.stats.train(stat)
	session.clock.advance_minutes(TRAINING_MINUTES)
	if levelled:
		notice.emit("%s is now %d." % [String(stat).capitalize(), session.stats.level(stat)])
	else:
		notice.emit("You put in a session on %s." % String(stat).capitalize())


func load_map(path: String) -> bool:
	map = RigMap.load_from(path)
	if not map.is_valid():
		for error in map.errors:
			push_error("%s: %s" % [path, error])
		return false

	var tile_set := TileSetBuilder.build()
	_ground.tile_set = tile_set
	_props.tile_set = tile_set
	_paint()
	_spawn_player()
	_configure_camera()
	_start_session()
	map_loaded.emit(map)
	return true


func _start_session() -> void:
	session = Session.new(map)
	for error in session.errors:
		push_error("session: %s" % error)
	session.bind_player_locator(player_zone)
	session.player_detained.connect(_on_player_detained)
	session.player_released.connect(_on_player_released)
	session.doors.door_opened.connect(_repaint_door)
	session.doors.door_closed.connect(_repaint_door)
	session.stats.changed.connect(_on_stat_changed)
	session.player_blacked_out.connect(_on_player_blacked_out)
	session.blackout.started.connect(_on_blackout_started)
	session.blackout.ended.connect(_on_blackout_ended)
	_apply_conditioning()
	_spawn_officers()
	session_started.emit(session)


func _on_player_blacked_out(cell: Vector2i) -> void:
	player.global_position = map.cell_centre(cell)
	notice.emit("You come round in the infirmary.")


func _on_blackout_started() -> void:
	_set_officer_vision(session.blackout.vision_scale())
	_darkness.visible = true
	notice.emit("Power dip. Lights and cameras down.")


func _on_blackout_ended() -> void:
	_set_officer_vision(1.0)
	_darkness.visible = false


func _set_officer_vision(scale: float) -> void:
	for officer in officers:
		officer.cone = Vision.Cone.new().scaled(scale)


func _on_stat_changed(stat: StringName, _value: int) -> void:
	if stat == Stats.CONDITIONING:
		_apply_conditioning()


func _apply_conditioning() -> void:
	if player != null:
		player.speed_multiplier = session.stats.speed_multiplier()


func _repaint_door(cell: Vector2i) -> void:
	var kind := session.doors.kind_at(cell)
	if kind == &"":
		kind = map.door_kind(cell)
	var tile: StringName = (
		TileCatalog.open_tile_for(kind)
		if session.doors.is_open(cell)
		else TileCatalog.ground_entry(map.ground_symbol(cell))["tile"]
	)
	_ground.set_cell(cell, TileCatalog.SOURCE_TERRAIN, TileCatalog.terrain_coords(tile))


func _update_doors() -> void:
	var approaches: Array[Dictionary] = []
	if player != null and session.player_state.state != PlayerState.SOLITARY:
		# A door shim makes a pressure hatch believe the player is authorised,
		# which is the only way into the hangar without a security escort.
		approaches.append(
			{
				"cell": Vector2(player.cell()),
				"staff": session.inventory.has(DoorSystem.OVERRIDE_ITEM),
			}
		)
	for officer in officers:
		approaches.append({"cell": Vector2(officer.cell()), "staff": true})
	session.doors.update(approaches)


func _spawn_officers() -> void:
	for officer in officers:
		officer.queue_free()
	officers.clear()

	var scene := load(OFFICER_SCENE) as PackedScene
	for patrol in map.patrols:
		var officer := scene.instantiate() as SecurityOfficer
		_actors.add_child(officer)
		officer.setup(session, session.navigation, player, patrol)
		officers.append(officer)


func _on_player_detained(_reason: String, _confiscated: Array) -> void:
	player.global_position = map.cell_centre(session.solitary_cell())


func _on_player_released() -> void:
	player.global_position = map.cell_centre(session.quarters_cell())


func player_zone() -> StringName:
	if player == null or session == null:
		return &""
	return session.zone_at_position(player.global_position)


func _paint() -> void:
	_ground.clear()
	_props.clear()
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)

			var ground_entry := TileCatalog.ground_entry(map.ground_symbol(cell))
			if not ground_entry.is_empty():
				_ground.set_cell(
					cell,
					TileCatalog.SOURCE_TERRAIN,
					TileCatalog.terrain_coords(ground_entry["tile"])
				)

			var prop_entry := TileCatalog.prop_entry(map.prop_symbol(cell))
			if not prop_entry.is_empty():
				_props.set_cell(
					cell, TileCatalog.SOURCE_PROPS, TileCatalog.prop_coords(prop_entry["tile"])
				)


func _spawn_player() -> void:
	if player == null:
		player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
		_actors.add_child(player)
	player.global_position = map.cell_centre(map.spawn)


func _configure_camera() -> void:
	var extent := map.pixel_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = extent.x
	_camera.limit_bottom = extent.y
	_camera.make_current()
	_follow_player()


func _process(delta: float) -> void:
	if session != null:
		session.tick(delta)
		session.tick_oxygen(delta, player.cell())
		_update_doors()
	_follow_player()


func _follow_player() -> void:
	if player != null:
		_camera.global_position = player.global_position


func camera() -> Camera2D:
	return _camera
