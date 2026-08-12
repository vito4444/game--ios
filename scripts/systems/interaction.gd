class_name Interaction
extends RefCounted

## Works out what the action button would do from where the player is standing.
##
## The tile in front is checked first, then the four neighbours, so facing a
## workbench picks the workbench even when a locker is also within reach.

enum Kind { NONE, STASH, CRAFT, SLEEP, PICK_UP, TRADE, TRAIN }

## Which prop offers which interaction.
const PROP_INTERACTIONS := {
	&"locker": Kind.STASH,
	&"workbench": Kind.CRAFT,
	&"technical_terminal": Kind.CRAFT,
	&"bunk": Kind.SLEEP,
	&"drive_component": Kind.PICK_UP,
	&"market_crate": Kind.TRADE,
	&"conditioning_rig": Kind.TRAIN,
	&"pressure_chamber": Kind.TRAIN,
}

## Which stat a training prop raises.
const TRAINING_STATS := {
	&"conditioning_rig": Stats.CONDITIONING,
	&"technical_terminal": Stats.TECHNICAL,
	&"pressure_chamber": Stats.PRESSURE,
}

const PROMPTS := {
	Kind.STASH: "Open locker",
	Kind.CRAFT: "Work here",
	Kind.SLEEP: "Sleep until morning",
	Kind.PICK_UP: "Pick up",
	Kind.TRADE: "Trade",
	Kind.TRAIN: "Train",
}


class Target:
	var kind: Kind = Kind.NONE
	var cell: Vector2i = Vector2i.ZERO
	var prop: StringName = &""

	func _init(target_kind: Kind, target_cell: Vector2i, target_prop: StringName) -> void:
		kind = target_kind
		cell = target_cell
		prop = target_prop

	func is_valid() -> bool:
		return kind != Kind.NONE

	func prompt() -> String:
		return Interaction.PROMPTS.get(kind, "")

	func trains() -> StringName:
		return Interaction.TRAINING_STATS.get(prop, &"")


static func none() -> Target:
	return Target.new(Kind.NONE, Vector2i.ZERO, &"")


static func find(map: RigMap, player_cell: Vector2i, facing: Vector2) -> Target:
	var ahead := player_cell + Vector2i(facing.round())
	var candidates: Array[Vector2i] = [ahead]
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in offsets:
		var neighbour := player_cell + offset
		if not candidates.has(neighbour):
			candidates.append(neighbour)
	candidates.append(player_cell)

	for cell in candidates:
		var target := _at(map, cell)
		if target.is_valid():
			return target
	return none()


static func _at(map: RigMap, cell: Vector2i) -> Target:
	if not map.in_bounds(cell):
		return none()
	var prop: StringName = TileCatalog.prop_entry(map.prop_symbol(cell)).get("tile", &"")
	if prop == &"":
		return none()
	var kind: Kind = PROP_INTERACTIONS.get(prop, Kind.NONE)
	if kind == Kind.NONE:
		return none()
	return Target.new(kind, cell, prop)


## The crafting station id a prop stands for, or &"" if it is not one.
static func station_for(prop: StringName) -> StringName:
	return prop if PROP_INTERACTIONS.get(prop, Kind.NONE) == Kind.CRAFT else &""
