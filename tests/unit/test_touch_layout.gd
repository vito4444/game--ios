extends GutTest

## Where the on-screen controls end up, including on hosts that report
## nonsense insets.

const VIEWPORT := Vector2(640, 360)
const STICK := Vector2(115, 115)
const BUTTON := Vector2(68, 68)

var TouchControls := preload("res://scripts/ui/touch_controls.gd")


func _layout(inset: Rect2) -> Dictionary:
	return TouchControls.layout(VIEWPORT, inset, STICK, BUTTON)


func _within_viewport(position: Vector2, size: Vector2) -> bool:
	return (
		position.x >= 0.0
		and position.y >= 0.0
		and position.x + size.x <= VIEWPORT.x
		and position.y + size.y <= VIEWPORT.y
	)


func test_with_no_insets_the_controls_sit_in_the_bottom_corners() -> void:
	var places := _layout(Rect2())
	assert_eq(places["joystick"], Vector2(26, 360 - 115 - 26))
	assert_eq(places["action"], Vector2(640 - 68 - 26, 360 - 68 - 26))


func test_a_home_indicator_lifts_both_controls() -> void:
	# Bottom inset of 20 units, as a phone with a home indicator reports.
	var places := _layout(Rect2(Vector2.ZERO, Vector2(0, 20)))
	assert_eq(places["joystick"].y, 360 - 20 - 115 - 26)
	assert_eq(places["action"].y, 360 - 20 - 68 - 26)


func test_a_landscape_notch_pushes_the_controls_inwards() -> void:
	# Left and right insets, as a notched phone held sideways reports.
	var places := _layout(Rect2(Vector2(44, 0), Vector2(44, 20)))
	assert_eq(places["joystick"].x, 44 + 26)
	assert_eq(places["action"].x, 640 - 44 - 68 - 26)


func test_a_safe_area_larger_than_the_window_does_not_push_them_off_screen() -> void:
	# A virtual framebuffer reports the whole virtual display rather than the
	# window, which produces negative insets. That used to place the joystick
	# at y=371 on a 360-unit-tall viewport, entirely off the bottom.
	var places := _layout(Rect2(Vector2(0, 0), Vector2(0, -304)))
	assert_true(
		_within_viewport(places["joystick"], STICK),
		"joystick at %s is off screen" % places["joystick"]
	)
	assert_true(
		_within_viewport(places["action"], BUTTON),
		"action button at %s is off screen" % places["action"]
	)


func test_absurd_insets_still_leave_the_controls_on_screen() -> void:
	for inset in [
		Rect2(Vector2(-50, -50), Vector2(-50, -50)),
		Rect2(Vector2(400, 300), Vector2(400, 300)),
		Rect2(Vector2(0, 0), Vector2(0, 900)),
	]:
		var places := _layout(inset)
		assert_true(
			_within_viewport(places["joystick"], STICK),
			"joystick off screen for inset %s: %s" % [inset, places["joystick"]]
		)
		assert_true(
			_within_viewport(places["action"], BUTTON),
			"action button off screen for inset %s: %s" % [inset, places["action"]]
		)


func test_the_two_controls_never_overlap() -> void:
	for inset in [Rect2(), Rect2(Vector2(44, 0), Vector2(44, 20))]:
		var places := _layout(inset)
		var stick_rect := Rect2(places["joystick"], STICK)
		var button_rect := Rect2(places["action"], BUTTON)
		assert_false(
			stick_rect.intersects(button_rect),
			"the stick and the button overlap at inset %s" % inset
		)


func test_the_action_button_meets_apples_minimum_touch_target() -> void:
	# 44pt at the narrowest supported screen. A 640-unit-wide viewport on a
	# 844pt-wide phone makes one unit about 1.32pt, so 44pt is ~34 units.
	assert_gte(TouchActionButton.RADIUS * 2.0, 34.0)
