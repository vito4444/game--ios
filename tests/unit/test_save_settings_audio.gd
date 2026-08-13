extends GutTest

## Saving, localisation and the generated sound effects.

const MAP_PATH := "res://data/maps/abyss9.map"
const LOCALE_CSV := "res://data/locale/ui.csv"

var session: Session


func before_each() -> void:
	SaveGame.delete()
	session = Session.new(RigMap.load_from(MAP_PATH))


func after_all() -> void:
	SaveGame.delete()


# ---------------------------------------------------------------- saving


func _play_a_while() -> Vector2:
	session.clock.advance_minutes(7 * 60 + 23)
	session.inventory.add(&"wrench")
	session.inventory.add(&"scrap_metal")
	session.inventory.add(&"cutting_torch")
	session.stats.set_level(Stats.TECHNICAL, 4)
	session.stats.train(Stats.CONDITIONING)
	session.suspicion.add(35)
	session.wallet.credit(120)
	return Vector2(1234.5, 678.25)


func test_a_round_trip_preserves_position_time_inventory_stats_and_suspicion() -> void:
	var position := _play_a_while()
	assert_eq(SaveGame.write(session, position), OK)

	var restored := Session.new(RigMap.load_from(MAP_PATH))
	var loaded_position := SaveGame.apply(restored, SaveGame.read())

	assert_eq(loaded_position, position, "player position")
	assert_eq(restored.clock.total_minutes(), session.clock.total_minutes(), "clock")
	assert_eq(restored.inventory.ids(), session.inventory.ids(), "inventory")
	for stat in Stats.ALL:
		assert_eq(restored.stats.level(stat), session.stats.level(stat), "%s level" % stat)
		assert_eq(
			restored.stats.progress(stat), session.stats.progress(stat), "%s progress" % stat
		)
	assert_eq(restored.suspicion.value, session.suspicion.value, "suspicion")


func test_a_round_trip_preserves_credits_job_progress_and_counters() -> void:
	session.jobs.begin_shift()
	session.jobs.work(&"workshop", &"workbench")
	session.jobs.work(&"workshop", &"workbench")
	session.wallet.credit(75)
	session.detain_player("test")

	SaveGame.write(session, Vector2.ZERO)
	var restored := Session.new(RigMap.load_from(MAP_PATH))
	SaveGame.apply(restored, SaveGame.read())

	assert_eq(restored.wallet.balance, session.wallet.balance)
	assert_eq(restored.jobs.units_done, 2)
	assert_true(restored.jobs.on_shift)
	assert_eq(restored.times_detained, 1)
	assert_eq(restored.player_state.state, PlayerState.SOLITARY)


func test_a_round_trip_preserves_what_is_in_the_lockers() -> void:
	var cell: Vector2i = session.stashes.keys()[0]
	var stash: Stash = session.stashes[cell]
	stash.store(&"ration")
	stash.store(&"pry_bar", true)

	SaveGame.write(session, Vector2.ZERO)
	var restored := Session.new(RigMap.load_from(MAP_PATH))
	SaveGame.apply(restored, SaveGame.read())

	var reloaded: Stash = restored.stashes[cell]
	assert_eq(reloaded.shelf, [&"ration"] as Array[StringName])
	assert_eq(reloaded.hidden, [&"pry_bar"] as Array[StringName])


func test_items_picked_up_before_saving_stay_picked_up() -> void:
	var cell: Vector2i = session.map.loose_items.keys()[0]
	session.map.take_loose_item(cell)

	SaveGame.write(session, Vector2.ZERO)
	var restored := Session.new(RigMap.load_from(MAP_PATH))
	SaveGame.apply(restored, SaveGame.read())

	assert_eq(restored.map.loose_item_at(cell), &"", "the part came back")
	assert_eq(restored.map.prop_symbol(cell), ".")


func test_loading_a_save_does_not_replay_the_days_events() -> void:
	# set_total_minutes must not fire every muster between midnight and now.
	session.clock.advance_to_minute_of_day(21 * 60)
	SaveGame.write(session, Vector2.ZERO)

	var restored := Session.new(RigMap.load_from(MAP_PATH))
	var fired := [0]
	restored.clock.event_started.connect(func(_event: Schedule.Event) -> void: fired[0] += 1)
	SaveGame.apply(restored, SaveGame.read())

	assert_eq(fired[0], 0)
	assert_eq(restored.clock.clock_text(), "21:00")


func test_there_is_no_save_until_one_is_written() -> void:
	assert_false(SaveGame.exists())
	SaveGame.write(session, Vector2.ZERO)
	assert_true(SaveGame.exists())
	SaveGame.delete()
	assert_false(SaveGame.exists())


# ---------------------------------------------------------------- localisation


func test_the_locale_file_ships_english_and_chinese() -> void:
	var file := FileAccess.open(LOCALE_CSV, FileAccess.READ)
	assert_not_null(file)
	assert_eq(file.get_csv_line()[0], "keys")
	assert_eq(file.get_csv_line()[0], "MENU_TITLE")


func test_every_row_has_both_translations() -> void:
	var file := FileAccess.open(LOCALE_CSV, FileAccess.READ)
	var header := file.get_csv_line()
	assert_eq(header, PackedStringArray(["keys", "en", "zh"]))

	var rows := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		rows += 1
		assert_eq(row.size(), 3, "row %s is not three columns" % row[0])
		assert_false(row[1].is_empty(), "%s has no English" % row[0])
		assert_false(row[2].is_empty(), "%s has no Chinese" % row[0])
	assert_gt(rows, 30, "the locale file looks suspiciously short")


func test_switching_language_changes_the_three_menu_buttons() -> void:
	var previous := TranslationServer.get_locale()

	TranslationServer.set_locale("en")
	var english := [tr("MENU_START"), tr("MENU_CONTINUE"), tr("MENU_SETTINGS")]
	assert_eq(english, ["Start a new contract", "Continue", "Settings"])

	TranslationServer.set_locale("zh")
	var chinese := [tr("MENU_START"), tr("MENU_CONTINUE"), tr("MENU_SETTINGS")]
	assert_eq(chinese, ["开始新合同", "继续", "设置"])

	for index in english.size():
		assert_ne(english[index], chinese[index], "button %d did not change" % index)

	TranslationServer.set_locale(previous)


func test_the_settings_singleton_offers_both_languages() -> void:
	assert_eq(Settings.LANGUAGES.keys(), ["en", "zh"])
	assert_ne(Settings.next_language(), Settings.language)


# ---------------------------------------------------------------- audio


func test_every_generated_sound_is_a_loadable_wav() -> void:
	var directory := DirAccess.open(Audio.DIRECTORY)
	assert_not_null(directory, "no generated audio directory")

	var count := 0
	for name in directory.get_files():
		if not name.ends_with(".wav"):
			continue
		count += 1
		var stream := load("%s/%s" % [Audio.DIRECTORY, name])
		assert_not_null(stream, "%s did not load" % name)
		assert_true(stream is AudioStreamWAV, "%s is not a WAV stream" % name)
		assert_gt((stream as AudioStreamWAV).data.size(), 0, "%s is empty" % name)
	assert_gt(count, 10, "expected the full set of effects")


func test_the_sounds_the_game_asks_for_all_exist() -> void:
	var required: Array[StringName] = [
		Audio.AMBIENCE,
		&"ui_click",
		&"door_open",
		&"door_close",
		&"pick_up",
		&"craft_done",
		&"alarm",
		&"blackout",
		&"power_restored",
		&"bubble",
		&"out_of_air",
		&"caught",
		&"escaped",
	]
	for id in required:
		assert_true(Audio.has_sound(id), "missing sound: %s" % id)


func test_the_audio_buses_the_settings_control_exist() -> void:
	assert_gt(AudioServer.get_bus_index(Settings.MUSIC_BUS), 0)
	assert_gt(AudioServer.get_bus_index(Settings.EFFECTS_BUS), 0)


func test_the_music_slider_has_something_to_control() -> void:
	# The rig ambience is what the Music bus carries; without it the slider in
	# the settings screen would do nothing.
	var stream := load("%s/%s.wav" % [Audio.DIRECTORY, Audio.AMBIENCE]) as AudioStreamWAV
	assert_not_null(stream)
	assert_gt(stream.get_length(), 10.0, "the loop is too short to sit under a shift")
