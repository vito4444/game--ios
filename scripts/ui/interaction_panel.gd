extends CanvasLayer

## The panel behind the action button: a locker's contents, or what can be made
## at a workbench.
##
## Rows are sized to Apple's 44pt minimum touch target at the smallest screen
## this ships to, which at a 640-wide viewport works out at 34 units.

signal closed()

const ROW_HEIGHT := 34
const CARRIED_TITLE := "%s  %d/%d"

var _session: Session
var _world: RigWorld
var _target: Interaction.Target = Interaction.none()

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Frame/Layout/Header/Title
@onready var _subtitle: Label = $Root/Frame/Layout/Header/Subtitle
@onready var _left_title: Label = $Root/Frame/Layout/Columns/Left/Title
@onready var _left_list: VBoxContainer = $Root/Frame/Layout/Columns/Left/Scroll/Items
@onready var _right_title: Label = $Root/Frame/Layout/Columns/Right/Title
@onready var _right_list: VBoxContainer = $Root/Frame/Layout/Columns/Right/Scroll/Items
@onready var _close_button: Button = $Root/Frame/Layout/Header/Close


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)


func bind(world: RigWorld) -> void:
	_world = world
	world.interaction_requested.connect(open)
	if world.session != null:
		_session = world.session
	else:
		world.session_started.connect(func(session: Session) -> void: _session = session)


func is_open() -> bool:
	return visible


func open(target: Interaction.Target) -> void:
	if _session == null or not target.is_valid():
		return
	_target = target
	visible = true
	# The player should not be walking away while reading their own pockets.
	GameInput.movement_locked = true
	_refresh()


func close() -> void:
	visible = false
	GameInput.movement_locked = false
	_target = Interaction.none()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_pause"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	match _target.kind:
		Interaction.Kind.STASH:
			_show_stash()
		Interaction.Kind.CRAFT:
			_show_crafting()
		Interaction.Kind.TRADE:
			_show_market()
		_:
			close()


# ---------------------------------------------------------------- stash


func _show_stash() -> void:
	var stash := _session.stash_at(_target.cell)
	if stash == null:
		close()
		return

	_title.text = tr("PANEL_LOCKER")
	_subtitle.text = tr("PANEL_LOCKER_HINT")
	_left_title.text = CARRIED_TITLE % [
		tr("PANEL_CARRYING"), _session.inventory.used_slots(), _session.inventory.capacity
	]
	_right_title.text = "%s  %s" % [
		tr("PANEL_LOCKER"),
		tr("PANEL_LOCKER_SPACE") % [stash.free_shelf_slots(), stash.free_hidden_slots()],
	]

	_clear(_left_list)
	for id in _session.inventory.ids():
		_add_row(
			_left_list,
			_label_for(id),
			[
				[tr("PANEL_SHELF"), func() -> void: _store(stash, id, false)],
				[tr("PANEL_HIDE"), func() -> void: _store(stash, id, true)],
			]
		)

	_clear(_right_list)
	for id in stash.shelf:
		_add_row(_right_list, _label_for(id), [[tr("PANEL_TAKE"), func() -> void: _take(stash, id)]])
	for id in stash.hidden:
		_add_row(
			_right_list, "%s  (hidden)" % _label_for(id), [[tr("PANEL_TAKE"), func() -> void: _take(stash, id)]]
		)


func _store(stash: Stash, id: StringName, hide: bool) -> void:
	if not stash.store(id, hide):
		return
	_session.inventory.remove(id)
	_refresh()


func _take(stash: Stash, id: StringName) -> void:
	if not _session.inventory.can_add(id):
		return
	stash.take(id)
	_session.inventory.add(id)
	_refresh()


# ---------------------------------------------------------------- crafting


func _show_crafting() -> void:
	var station := Interaction.station_for(_target.prop)
	_title.text = tr("STATION_%s" % String(station).to_upper())
	_subtitle.text = tr("PANEL_TECHNICAL") % _session.stats.level(Stats.TECHNICAL)
	_left_title.text = CARRIED_TITLE % [
		tr("PANEL_CARRYING"), _session.inventory.used_slots(), _session.inventory.capacity
	]
	_right_title.text = tr("PANEL_CAN_MAKE")

	_clear(_left_list)
	for id in _session.inventory.ids():
		_add_row(_left_list, _label_for(id), [])

	_clear(_right_list)
	var recipes := _session.recipes.at_station(station)
	if recipes.is_empty():
		_add_row(_right_list, tr("PANEL_NO_RECIPES"), [])
	for recipe in recipes:
		var result := _session.crafting.check(recipe.id, station)
		var name := _session.items.display_name(recipe.output)
		if result == Crafting.Result.OK:
			_add_row(
				_right_list,
				name,
				[[tr("PANEL_MAKE"), func() -> void: _craft(recipe.id, station)]],
				tr("PANEL_MINUTES") % recipe.minutes
			)
		else:
			_add_row(_right_list, name, [], _shortfall_text(recipe, result))


func _craft(recipe_id: StringName, station: StringName) -> void:
	if _session.crafting.craft(recipe_id, station) != Crafting.Result.OK:
		return
	var recipe := _session.recipes.by_id(recipe_id)
	_session.clock.advance_minutes(recipe.minutes)
	Audio.play(&"craft_done")
	_refresh()


## Says what is actually stopping this recipe, rather than listing everything.
func _shortfall_text(recipe: RecipeBook.Recipe, result: Crafting.Result) -> String:
	if result == Crafting.Result.NOT_SKILLED_ENOUGH:
		return tr("PANEL_NEEDS_TECHNICAL") % recipe.technical
	if result != Crafting.Result.MISSING_INPUTS:
		return Crafting.reason_for(result).to_lower()

	var missing: PackedStringArray = PackedStringArray()
	for id in recipe.required_counts():
		var short: int = int(recipe.required_counts()[id]) - _session.inventory.count_of(id)
		if short > 0:
			missing.append("%d x %s" % [short, _session.items.display_name(id)])
	return tr("PANEL_NEEDS") % ", ".join(missing)


# ---------------------------------------------------------------- market


func _show_market() -> void:
	_title.text = tr("PANEL_TRADER")
	_subtitle.text = tr("PANEL_CREDITS") % _session.wallet.balance
	_left_title.text = tr("PANEL_SELL")
	_right_title.text = tr("PANEL_BUY")

	_clear(_left_list)
	if _session.inventory.count() == 0:
		_add_row(_left_list, tr("PANEL_NOTHING_TO_SELL"), [])
	for id in _session.inventory.ids():
		var price := _session.market.sell_price(id)
		_add_row(
			_left_list,
			_label_for(id),
			[["%d" % price, func() -> void: _sell(id)]],
			tr("PANEL_HE_PAYS") % price
		)

	_clear(_right_list)
	for id in _session.market.stock():
		var cost := _session.market.buy_price(id)
		if _session.market.can_buy(id):
			_add_row(
				_right_list,
				_session.items.display_name(id),
				[["%d" % cost, func() -> void: _buy(id)]],
				tr("PANEL_COSTS") % cost
			)
		else:
			var reason := (
				tr("PANEL_NO_ROOM") if not _session.inventory.can_add(id) else tr("PANEL_CANNOT_AFFORD") % cost
			)
			_add_row(_right_list, _session.items.display_name(id), [], reason)


func _buy(id: StringName) -> void:
	if _session.market.buy(id):
		_refresh()


func _sell(id: StringName) -> void:
	if _session.market.sell(id):
		_refresh()


# ---------------------------------------------------------------- rows


func _label_for(id: StringName) -> String:
	var item := _session.items.get_item(id)
	if item == null:
		return String(id)
	return "%s%s" % [
		_session.items.display_name(id), "  *" if item.contraband else ""
	]


func _clear(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()


func _add_row(list: VBoxContainer, text: String, actions: Array, subtitle: String = "") -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 0)
	row.add_child(text_column)

	text_column.add_child(_row_label(text, 13, Palette.BONE))
	if not subtitle.is_empty():
		text_column.add_child(_row_label(subtitle, 11, Palette.STEEL_LIGHT))

	for action in actions:
		var button := Button.new()
		button.text = action[0]
		button.custom_minimum_size = Vector2(58, ROW_HEIGHT)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func() -> void: Audio.play(&"ui_click"))
		button.pressed.connect(action[1])
		row.add_child(button)

	list.add_child(row)


func _row_label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	# Without clipping, one long recipe name widens the whole column and pushes
	# the other half of the panel off screen.
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
