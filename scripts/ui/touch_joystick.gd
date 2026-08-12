class_name TouchJoystick
extends Control

## Floating on-screen stick for the left thumb.
##
## The stick appears wherever the thumb lands inside its region rather than at
## a fixed spot, because a fixed stick forces the player to look at the screen
## edge to find it. Touches are tracked by index so the action button on the
## other side keeps working at the same time.

const RADIUS := 46.0
const KNOB_RADIUS := 20.0
const DEADZONE := 0.18

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Desktop path, so the touch layout can be exercised without a device.
		_handle_touch(-2, event.position, event.pressed)
	elif event is InputEventMouseMotion and _touch_index == -2:
		_handle_drag(-2, event.position)


func _handle_touch(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		if _active or not get_global_rect().has_point(position):
			return
		_touch_index = index
		_origin = position
		_knob = position
		_active = true
		_publish()
		queue_redraw()
	elif index == _touch_index:
		_release()


func _handle_drag(index: int, position: Vector2) -> void:
	if index != _touch_index or not _active:
		return
	_knob = _origin + (position - _origin).limit_length(RADIUS)
	_publish()
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_active = false
	_knob = _origin
	GameInput.stick = Vector2.ZERO
	queue_redraw()


func _publish() -> void:
	var offset := (_knob - _origin) / RADIUS
	GameInput.stick = Vector2.ZERO if offset.length() < DEADZONE else offset


func _notification(what: int) -> void:
	# Losing focus mid-drag would otherwise leave the player walking forever.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _active:
		_release()


func _draw() -> void:
	if not _active:
		return
	var base := _origin - global_position
	draw_circle(base, RADIUS, Color(Palette.ABYSS, 0.35))
	draw_arc(base, RADIUS, 0.0, TAU, 32, Color(Palette.HULL_LIGHT, 0.55), 2.0)
	draw_circle(_knob - global_position, KNOB_RADIUS, Color(Palette.HULL_LIGHT, 0.45))
	draw_arc(_knob - global_position, KNOB_RADIUS, 0.0, TAU, 24, Color(Palette.BONE, 0.8), 2.0)
