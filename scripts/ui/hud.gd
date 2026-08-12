extends CanvasLayer

## Status bar: rig time, the block of the day currently in force, where the
## player is standing, and how closely security is watching.

const ROLL_CALL_PROMPT := "MUSTER — report to %s by %02d:%02d"

@onready var _clock_label: Label = $Bar/Margin/Row/Clock
@onready var _activity_label: Label = $Bar/Margin/Row/Activity
@onready var _zone_label: Label = $Bar/Margin/Row/Zone
@onready var _suspicion_bar: ProgressBar = $Bar/Margin/Row/Suspicion
@onready var _alert: Label = $Alert

var _session: Session
var _world: RigWorld


func bind(world: RigWorld) -> void:
	_world = world
	if world.session != null:
		_attach(world.session)
	else:
		world.session_started.connect(_attach)


func _attach(session: Session) -> void:
	_session = session
	session.suspicion.changed.connect(_on_suspicion_changed)
	session.roll_call.started.connect(_on_roll_call_started)
	session.roll_call.attended.connect(_on_roll_call_resolved.bind(true))
	session.roll_call.missed.connect(_on_roll_call_missed)
	_on_suspicion_changed(session.suspicion.value)
	_alert.visible = false


func _process(_delta: float) -> void:
	if _session == null:
		return
	_clock_label.text = "Day %d  %s" % [_session.clock.day() + 1, _session.clock.clock_text()]
	var event := _session.clock.current_event()
	_activity_label.text = event.label if event != null else ""
	var zone := _world.player_zone() if _world != null else &""
	_zone_label.text = _humanise(zone)


func _humanise(zone: StringName) -> String:
	if zone == &"":
		return "Corridor"
	return String(zone).replace("_", " ").capitalize()


func _on_suspicion_changed(value: int) -> void:
	_suspicion_bar.value = value
	_suspicion_bar.tooltip_text = "Suspicion %d%%" % value


func _on_roll_call_started(event: Schedule.Event, deadline_minute: int) -> void:
	_alert.text = ROLL_CALL_PROMPT % [
		_humanise(event.zone), deadline_minute / 60, deadline_minute % 60
	]
	_alert.visible = true


func _on_roll_call_resolved(_event: Schedule.Event, _attended: bool) -> void:
	_alert.visible = false


func _on_roll_call_missed(_event: Schedule.Event, penalty: int) -> void:
	_alert.text = "Marked absent. Suspicion +%d" % penalty
	_alert.visible = true
	await get_tree().create_timer(4.0).timeout
	_alert.visible = false
