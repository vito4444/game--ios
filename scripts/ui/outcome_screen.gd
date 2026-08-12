extends CanvasLayer

## Shown once the player is off the rig.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var _title: Label = $Root/Frame/Layout/Title
@onready var _route: Label = $Root/Frame/Layout/Route
@onready var _summary: Label = $Root/Frame/Layout/Summary
@onready var _stats: VBoxContainer = $Root/Frame/Layout/Stats
@onready var _menu_button: Button = $Root/Frame/Layout/Menu

var _session: Session


func _ready() -> void:
	visible = false
	_menu_button.pressed.connect(_to_menu)


func bind(world: RigWorld) -> void:
	if world.session != null:
		_attach(world.session)
	else:
		world.session_started.connect(_attach)


func _attach(session: Session) -> void:
	_session = session
	session.escape_routes.escaped.connect(_show)


func _show(route: EscapeRoutes.Route) -> void:
	visible = true
	GameInput.movement_locked = true

	_title.text = tr("OUTCOME_TITLE")
	var route_key := "ROUTE_%s" % String(route.id).to_upper()
	var translated := TranslationServer.translate(route_key)
	_route.text = route.name if translated == route_key else translated
	var summary_key := "%s_SUMMARY" % route_key
	var summary := TranslationServer.translate(summary_key)
	_summary.text = route.summary if summary == summary_key else summary

	for child in _stats.get_children():
		child.queue_free()

	var days := _session.clock.day() + 1
	_add(tr("OUTCOME_DAYS"), str(days))
	_add(tr("OUTCOME_DEPARTURE"), _session.clock.clock_text())
	_add(tr("OUTCOME_DETAINED"), str(_session.times_detained))
	_add(tr("OUTCOME_SEARCHED"), str(_session.times_searched))
	_add(tr("OUTCOME_SUSPICION"), "%d%%" % _session.suspicion.value)
	_add(tr("OUTCOME_CREDITS"), str(_session.wallet.balance))
	_add(
		tr("OUTCOME_STATS"),
		"%d / %d / %d" % [
			_session.stats.level(Stats.TECHNICAL),
			_session.stats.level(Stats.CONDITIONING),
			_session.stats.level(Stats.PRESSURE),
		]
	)


func _add(label: String, value: String) -> void:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Palette.STEEL_LIGHT)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Palette.BONE)
	row.add_child(value_label)

	_stats.add_child(row)


func _to_menu() -> void:
	GameInput.movement_locked = false
	get_tree().change_scene_to_file(MAIN_MENU)
