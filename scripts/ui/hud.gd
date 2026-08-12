extends CanvasLayer

## Status bar: rig time, the block of the day currently in force, where the
## player is standing, and how closely security is watching.

const ROLL_CALL_PROMPT := "MUSTER — report to %s by %02d:%02d"

@onready var _clock_label: Label = $Bar/Margin/Row/Clock
@onready var _activity_label: Label = $Bar/Margin/Row/Activity
@onready var _zone_label: Label = $Bar/Margin/Row/Zone
@onready var _carrying_label: Label = $Bar/Margin/Row/Carrying
@onready var _credits_label: Label = $Bar/Margin/Row/Credits
@onready var _suspicion_bar: ProgressBar = $Bar/Margin/Row/Suspicion
@onready var _alert: Label = $Alert
@onready var _prompt: Label = $Prompt

var _session: Session
var _world: RigWorld
var _notice_until: float = 0.0


func bind(world: RigWorld) -> void:
	_world = world
	world.notice.connect(_show_notice)
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
	session.shakedown.player_searched.connect(_on_searched)
	session.player_detained.connect(_on_detained)
	_on_suspicion_changed(session.suspicion.value)
	_alert.visible = false
	_prompt.visible = false


func _process(_delta: float) -> void:
	if _session == null:
		return
	_clock_label.text = "Day %d  %s" % [_session.clock.day() + 1, _session.clock.clock_text()]
	var event := _session.clock.current_event()
	_activity_label.text = event.label if event != null else ""
	var zone := _world.player_zone() if _world != null else &""
	_zone_label.text = _humanise(zone)
	_carrying_label.text = "%d/%d" % [
		_session.inventory.used_slots(), _session.inventory.capacity
	]
	_credits_label.text = "%dc" % _session.wallet.balance
	_update_prompt()

	if _notice_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _notice_until:
		_notice_until = 0.0
		_alert.visible = false


func _update_prompt() -> void:
	if _world == null:
		return
	var target := _world.current_interaction()
	_prompt.visible = target.is_valid() and _session.player_state.is_free()
	if _prompt.visible:
		_prompt.text = target.prompt()


func _show_notice(text: String) -> void:
	_alert.text = text
	_alert.visible = true
	_notice_until = Time.get_ticks_msec() / 1000.0 + 3.0


func _on_searched(seized: Array) -> void:
	if seized.is_empty():
		return
	_show_notice("Searched at muster. %d item(s) taken." % seized.size())


func _on_detained(reason: String, seized: Array) -> void:
	_show_notice("%s. %d item(s) confiscated." % [reason, seized.size()])


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
	_show_notice("Marked absent. Suspicion +%d" % penalty)
