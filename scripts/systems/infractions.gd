class_name Infractions
extends RefCounted

## What counts as something worth arresting the player for.
##
## Separated from the officer so the rules are one readable list rather than
## conditions scattered through a state machine, and so they can be tested
## without spawning anyone.

enum Kind {
	NONE,
	RESTRICTED_AREA,  ## Standing somewhere the contract does not cover
	OUT_AFTER_LIGHTS_OUT,  ## Away from the bunk pods overnight
	CARRYING_CONTRABAND,  ## Holding something that would fail a search
}

const SUSPICION_COST := {
	Kind.RESTRICTED_AREA: 20,
	Kind.OUT_AFTER_LIGHTS_OUT: 15,
	Kind.CARRYING_CONTRABAND: 30,
}

const QUARTERS_ZONE := &"quarters"
const RESTRICTED_KIND := &"restricted"
const LIGHTS_OUT_EVENT := &"lights_out"


class Report:
	var kind: Kind
	var description: String

	func _init(infraction_kind: Kind, text: String) -> void:
		kind = infraction_kind
		description = text

	func is_violation() -> bool:
		return kind != Kind.NONE

	func suspicion_cost() -> int:
		return Infractions.SUSPICION_COST.get(kind, 0)


static func none() -> Report:
	return Report.new(Kind.NONE, "")


## Evaluates the player's current standing. `carrying_contraband` is supplied by
## the inventory once it exists; until then it is always false.
static func evaluate(
	map: RigMap,
	player_cell: Vector2i,
	current_event: Schedule.Event,
	carrying_contraband: bool = false
) -> Report:
	var zone := map.zone_at(player_cell)

	if zone != null and zone.kind == RESTRICTED_KIND:
		return Report.new(
			Kind.RESTRICTED_AREA, "In a restricted area: %s" % String(zone.id)
		)

	if carrying_contraband:
		return Report.new(Kind.CARRYING_CONTRABAND, "Carrying contraband")

	if current_event != null and current_event.id == LIGHTS_OUT_EVENT:
		if zone == null or zone.kind != QUARTERS_ZONE:
			return Report.new(Kind.OUT_AFTER_LIGHTS_OUT, "Out of the bunk pods after lights out")

	return none()
