class_name SaveGame
extends RefCounted

## Reads and writes the single save slot.
##
## Stored as JSON rather than a binary resource so a broken save can be read by
## a human, and so the format is stable across engine versions.

const PATH := "user://abyss9.save.json"
const VERSION := 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func capture(session: Session, player_position: Vector2) -> Dictionary:
	var stashes := {}
	for cell in session.stashes:
		var stash: Stash = session.stashes[cell]
		if stash.is_empty():
			continue
		stashes["%d,%d" % [cell.x, cell.y]] = {
			"shelf": _to_strings(stash.shelf),
			"hidden": _to_strings(stash.hidden),
		}

	var loose := {}
	for cell in session.map.loose_items:
		loose["%d,%d" % [cell.x, cell.y]] = String(session.map.loose_items[cell])

	return {
		"version": VERSION,
		"minutes": session.clock.total_minutes(),
		"player": {
			"x": player_position.x,
			"y": player_position.y,
			"state": String(session.player_state.state),
			"solitary_minutes": session.player_state.solitary_minutes_remaining,
		},
		"inventory": _to_strings(session.inventory.ids()),
		"stats": session.stats.to_dictionary(),
		"suspicion": session.suspicion.value,
		"credits": session.wallet.balance,
		"job": {
			"assigned": String(session.jobs.assigned.id) if session.jobs.assigned else "",
			"units_done": session.jobs.units_done,
			"on_shift": session.jobs.on_shift,
		},
		"counters": {
			"detained": session.times_detained,
			"searched": session.times_searched,
			"blacked_out": session.times_blacked_out,
		},
		"stashes": stashes,
		"loose_items": loose,
	}


static func write(session: Session, player_position: Vector2) -> Error:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(capture(session, player_position), "\t"))
	file.close()
	return OK


static func read() -> Dictionary:
	if not exists():
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


## Restores a session in place. Returns the saved player position.
static func apply(session: Session, data: Dictionary) -> Vector2:
	if data.is_empty():
		return session.map.cell_centre(session.map.spawn)

	session.clock.set_total_minutes(int(data.get("minutes", 0)))

	var player: Dictionary = data.get("player", {})
	session.player_state.state = StringName(player.get("state", PlayerState.FREE))
	session.player_state.solitary_minutes_remaining = int(player.get("solitary_minutes", 0))

	session.inventory.clear()
	for id in data.get("inventory", []) as Array:
		session.inventory.add(StringName(id))

	session.stats.from_dictionary(data.get("stats", {}))
	session.suspicion.value = int(data.get("suspicion", 0))
	session.wallet.balance = int(data.get("credits", 0))

	var job: Dictionary = data.get("job", {})
	if job.get("assigned", "") != "":
		session.jobs.assign(StringName(job["assigned"]))
	session.jobs.units_done = int(job.get("units_done", 0))
	session.jobs.on_shift = bool(job.get("on_shift", false))

	var counters: Dictionary = data.get("counters", {})
	session.times_detained = int(counters.get("detained", 0))
	session.times_searched = int(counters.get("searched", 0))
	session.times_blacked_out = int(counters.get("blacked_out", 0))

	for cell in session.stashes:
		var stash: Stash = session.stashes[cell]
		stash.shelf.clear()
		stash.hidden.clear()
	var stashes: Dictionary = data.get("stashes", {})
	for key in stashes:
		var cell := _to_cell(key)
		var stash: Stash = session.stashes.get(cell)
		if stash == null:
			continue
		for id in stashes[key].get("shelf", []) as Array:
			stash.shelf.append(StringName(id))
		for id in stashes[key].get("hidden", []) as Array:
			stash.hidden.append(StringName(id))

	# Anything picked up before saving must stay picked up.
	var loose: Dictionary = data.get("loose_items", {})
	for cell in session.map.loose_items.keys():
		if not loose.has("%d,%d" % [cell.x, cell.y]):
			session.map.take_loose_item(cell)

	session.oxygen.refill()
	return Vector2(float(player.get("x", 0.0)), float(player.get("y", 0.0)))


static func _to_strings(ids: Array) -> Array:
	var out := []
	for id in ids:
		out.append(String(id))
	return out


static func _to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(parts[0].to_int(), parts[1].to_int())
