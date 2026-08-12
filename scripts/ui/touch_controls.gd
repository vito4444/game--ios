extends CanvasLayer

## Positions the on-screen controls inside the display's safe area.
##
## iPhones put a home indicator across the bottom and a notch or island at the
## top; anything drawn under either is both hard to hit and, in Apple's review
## guidelines, a reason to reject. The insets are read at runtime because they
## differ per device and per orientation.

const MARGIN := 26.0

@onready var _joystick: TouchJoystick = $Root/Joystick
@onready var _action: TouchActionButton = $Root/Action


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func action_button() -> TouchActionButton:
	return _action


func joystick() -> TouchJoystick:
	return _joystick


func _apply_safe_area() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var inset := _safe_area_inset()

	var stick_size := Vector2.ONE * TouchJoystick.RADIUS * 2.5
	_joystick.size = stick_size
	_joystick.position = Vector2(
		inset.position.x + MARGIN, viewport.y - inset.size.y - stick_size.y - MARGIN
	)

	var button_size := Vector2.ONE * TouchActionButton.RADIUS * 2.0
	_action.size = button_size
	_action.position = Vector2(
		viewport.x - inset.size.x - button_size.x - MARGIN,
		viewport.y - inset.size.y - button_size.y - MARGIN
	)


func _safe_area_inset() -> Rect2:
	## Returned as left/top in `position` and right/bottom in `size`, both in
	## viewport units rather than the physical pixels DisplayServer reports.
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.window_get_size()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return Rect2()

	var viewport := get_viewport().get_visible_rect().size
	var scale := Vector2(viewport.x / float(screen.x), viewport.y / float(screen.y))
	return Rect2(
		Vector2(safe.position) * scale,
		Vector2(screen - safe.position - safe.size) * scale
	)
