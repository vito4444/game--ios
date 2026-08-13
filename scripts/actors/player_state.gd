class_name PlayerState
extends RefCounted

## What the rig currently has the player doing, independent of where they are.
##
## Held separately from the Player node so systems that run without a scene
## tree - arrests, the schedule, saves - can read and change it.

signal changed(state: StringName)
signal arrested(reason: String)
signal released()
signal escaped()

const FREE := &"free"
const PURSUED := &"pursued"
const ESCORTED := &"escorted"
const SOLITARY := &"solitary"
const UNCONSCIOUS := &"unconscious"
const ESCAPE_SUCCESS := &"escape_success"

## How long a stint in the solitary cell lasts, in game minutes.
const SOLITARY_MINUTES := 240

var state: StringName = FREE:
	set(value):
		if value == state:
			return
		state = value
		changed.emit(state)

var solitary_minutes_remaining: int = 0


func is_free() -> bool:
	return state == FREE


func is_detained() -> bool:
	return state == ESCORTED or state == SOLITARY


func begin_pursuit() -> void:
	if state == FREE:
		state = PURSUED


func end_pursuit() -> void:
	if state == PURSUED:
		state = FREE


func begin_escort() -> void:
	state = ESCORTED


func send_to_solitary(reason: String) -> void:
	state = SOLITARY
	solitary_minutes_remaining = SOLITARY_MINUTES
	arrested.emit(reason)


func serve_time(minutes: int) -> void:
	if state != SOLITARY:
		return
	solitary_minutes_remaining = maxi(0, solitary_minutes_remaining - minutes)
	if solitary_minutes_remaining == 0:
		state = FREE
		released.emit()


func escape() -> void:
	state = ESCAPE_SUCCESS
	escaped.emit()


func has_escaped() -> bool:
	return state == ESCAPE_SUCCESS


func knock_out() -> void:
	state = UNCONSCIOUS


func revive() -> void:
	if state == UNCONSCIOUS:
		state = FREE
