class_name TouchActionButton
extends Control

## Round context button for the right thumb.
##
## Drawn rather than textured so it can be recoloured per state without another
## atlas, and sized to Apple's 44pt minimum touch target at the smallest
## supported screen.

signal pressed

const RADIUS := 34.0

@export var label: String = "E"

var _touch_index: int = -1
var _held: bool = false
var _enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2.ONE * RADIUS * 2.0
	set_process_unhandled_input(true)


func set_enabled(value: bool) -> void:
	if _enabled == value:
		return
	_enabled = value
	if not _enabled:
		_held = false
		_touch_index = -1
	queue_redraw()


func is_enabled() -> bool:
	return _enabled


func _centre() -> Vector2:
	return global_position + size * 0.5


func _hits(position: Vector2) -> bool:
	return position.distance_to(_centre()) <= RADIUS


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		_handle(event.index, event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle(-2, event.position, event.pressed)


func _handle(index: int, position: Vector2, is_pressed: bool) -> void:
	if is_pressed:
		if _held or not _hits(position):
			return
		_touch_index = index
		_held = true
		queue_redraw()
		pressed.emit()
		GameInput.press_interact()
	elif index == _touch_index:
		_touch_index = -1
		_held = false
		queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var fill := Palette.HULL if _enabled else Palette.HULL_SHADOW
	var alpha := 0.85 if _held else 0.55
	draw_circle(centre, RADIUS, Color(fill, alpha))
	draw_arc(centre, RADIUS, 0.0, TAU, 32, Color(Palette.HULL_HIGHLIGHT, 0.8), 2.0)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(
		font,
		centre - Vector2(text_size.x * 0.5, -7.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		20,
		Color(Palette.BONE) if _enabled else Color(Palette.STEEL)
	)
