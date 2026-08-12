class_name Stats
extends RefCounted

## The three things a technician can get better at.
##
## Conditioning moves you faster, Technical unlocks recipes, and Pressure
## tolerance decides how long you last outside a pressurised compartment. Each
## escape route leans on a different one, so there is no single right order to
## train in.

signal changed(stat: StringName, value: int)
signal levelled_up(stat: StringName, value: int)

const CONDITIONING := &"conditioning"
const TECHNICAL := &"technical"
const PRESSURE := &"pressure"

const ALL: Array[StringName] = [CONDITIONING, TECHNICAL, PRESSURE]

const MINIMUM := 1
const MAXIMUM := 10

## Training sessions needed to gain a level, and it gets harder as you climb.
const SESSIONS_PER_LEVEL := 3

## Movement gained per level of Conditioning, as a fraction of base speed.
const CONDITIONING_SPEED_BONUS := 0.06

## Seconds of air in a bottle at Pressure 1, and the fraction added per level.
const BASE_OXYGEN_SECONDS := 40.0
const PRESSURE_OXYGEN_BONUS := 0.25

var _levels: Dictionary = {}
var _progress: Dictionary = {}


func _init(starting_level: int = MINIMUM) -> void:
	for stat in ALL:
		_levels[stat] = clampi(starting_level, MINIMUM, MAXIMUM)
		_progress[stat] = 0


func level(stat: StringName) -> int:
	return int(_levels.get(stat, MINIMUM))


func progress(stat: StringName) -> int:
	return int(_progress.get(stat, 0))


func sessions_to_next_level(stat: StringName) -> int:
	return SESSIONS_PER_LEVEL * level(stat) - progress(stat)


func set_level(stat: StringName, value: int) -> void:
	if not _levels.has(stat):
		return
	var clamped := clampi(value, MINIMUM, MAXIMUM)
	if clamped == _levels[stat]:
		return
	_levels[stat] = clamped
	_progress[stat] = 0
	changed.emit(stat, clamped)


## One training session. Returns true when it pushed the stat up a level.
func train(stat: StringName) -> bool:
	if not _levels.has(stat) or level(stat) >= MAXIMUM:
		return false

	_progress[stat] = progress(stat) + 1
	if progress(stat) < SESSIONS_PER_LEVEL * level(stat):
		changed.emit(stat, level(stat))
		return false

	_progress[stat] = 0
	_levels[stat] = level(stat) + 1
	changed.emit(stat, level(stat))
	levelled_up.emit(stat, level(stat))
	return true


func meets(stat: StringName, required: int) -> bool:
	return level(stat) >= required


func speed_multiplier() -> float:
	return 1.0 + CONDITIONING_SPEED_BONUS * (level(CONDITIONING) - 1)


## How long one bottle lasts outside a pressurised compartment.
func oxygen_seconds() -> float:
	return BASE_OXYGEN_SECONDS * (1.0 + PRESSURE_OXYGEN_BONUS * (level(PRESSURE) - 1))


func to_dictionary() -> Dictionary:
	return {"levels": _levels.duplicate(), "progress": _progress.duplicate()}


func from_dictionary(data: Dictionary) -> void:
	for stat in ALL:
		var levels: Dictionary = data.get("levels", {})
		var progresses: Dictionary = data.get("progress", {})
		_levels[stat] = clampi(int(levels.get(stat, MINIMUM)), MINIMUM, MAXIMUM)
		_progress[stat] = int(progresses.get(stat, 0))
