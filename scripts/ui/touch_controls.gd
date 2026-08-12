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


## Where the two controls belong, given the viewport and the safe-area insets.
##
## Pure so it can be tested against the awkward cases: a device with a home
## indicator, and a host that reports a safe area larger than the window, which
## is what a virtual framebuffer does and which used to push both controls off
## the bottom of the screen.
static func layout(
	viewport: Vector2, inset: Rect2, stick_size: Vector2, button_size: Vector2
) -> Dictionary:
	var left := maxf(inset.position.x, 0.0)
	var top := maxf(inset.position.y, 0.0)
	var right := maxf(inset.size.x, 0.0)
	var bottom := maxf(inset.size.y, 0.0)

	var stick := Vector2(left + MARGIN, viewport.y - bottom - stick_size.y - MARGIN)
	var button := Vector2(
		viewport.x - right - button_size.x - MARGIN,
		viewport.y - bottom - button_size.y - MARGIN
	)

	return {
		"joystick": _keep_on_screen(stick, stick_size, viewport, left, top, right, bottom),
		"action": _keep_on_screen(button, button_size, viewport, left, top, right, bottom),
	}


static func _keep_on_screen(
	desired: Vector2,
	size: Vector2,
	viewport: Vector2,
	left: float,
	top: float,
	right: float,
	bottom: float
) -> Vector2:
	var lowest := Vector2(left, top)
	var highest := viewport - size - Vector2(right, bottom)
	if highest.x < lowest.x or highest.y < lowest.y:
		# Insets that leave no room for the control are not credible, so they
		# are ignored rather than obeyed off the edge of the screen.
		lowest = Vector2.ZERO
		highest = (viewport - size).max(Vector2.ZERO)
	return desired.clamp(lowest, highest)


func _apply_safe_area() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var stick_size := Vector2.ONE * TouchJoystick.RADIUS * 2.5
	var button_size := Vector2.ONE * TouchActionButton.RADIUS * 2.0

	var places := layout(viewport, safe_area_inset(), stick_size, button_size)
	_joystick.size = stick_size
	_joystick.position = places["joystick"]
	_action.size = button_size
	_action.position = places["action"]


## Safe-area insets in viewport units: left/top in `position`, right/bottom in
## `size`. DisplayServer reports physical pixels, which are not the same thing
## once the canvas is being stretched.
func safe_area_inset() -> Rect2:
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
