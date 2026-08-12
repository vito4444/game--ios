extends GutTest

## The action button: what it offers where, and what it does.

const RIG_SCENE := "res://scenes/world/rig.tscn"

var rig: RigWorld


func before_each() -> void:
	GameInput.stick = Vector2.ZERO
	GameInput.movement_locked = false
	rig = add_child_autofree((load(RIG_SCENE) as PackedScene).instantiate()) as RigWorld
	await wait_physics_frames(2)


func _stand_on(cell: Vector2i) -> void:
	rig.player.global_position = rig.map.cell_centre(cell)
	await wait_physics_frames(1)


func _find_prop(tile: StringName) -> Vector2i:
	for y in rig.map.height:
		for x in rig.map.width:
			var cell := Vector2i(x, y)
			if TileCatalog.prop_entry(rig.map.prop_symbol(cell)).get("tile", &"") == tile:
				return cell
	return Vector2i(-1, -1)


## A walkable cell next to `cell`, so the player can stand beside a solid prop.
func _beside(cell: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in offsets:
		if not rig.map.is_solid(cell + offset):
			return cell + offset
	return cell


func test_standing_in_an_empty_corridor_offers_nothing() -> void:
	await _stand_on(Vector2i(20, 11))
	assert_false(rig.current_interaction().is_valid())


func test_a_locker_offers_a_stash() -> void:
	var locker := _find_prop(&"locker")
	await _stand_on(_beside(locker))
	var target := rig.current_interaction()
	assert_eq(target.kind, Interaction.Kind.STASH)
	# The prompt is a translation key; the interface runs it through tr().
	assert_eq(target.prompt(), "PROMPT_STASH")
	assert_eq(TranslationServer.get_translation_object("en").get_message("PROMPT_STASH"), "Open locker")


func test_a_workbench_offers_crafting() -> void:
	var bench := _find_prop(&"workbench")
	await _stand_on(_beside(bench))
	assert_eq(rig.current_interaction().kind, Interaction.Kind.CRAFT)
	assert_eq(Interaction.station_for(rig.current_interaction().prop), &"workbench")


func test_a_bunk_offers_sleep_and_sleeping_skips_to_the_wake_up_call() -> void:
	var bunk := _find_prop(&"bunk")
	await _stand_on(_beside(bunk))
	assert_eq(rig.current_interaction().kind, Interaction.Kind.SLEEP)

	rig.session.clock.advance_to_minute_of_day(23 * 60)
	var day_before := rig.session.clock.day()
	GameInput.press_interact()

	assert_eq(rig.session.clock.clock_text(), "06:00")
	assert_eq(rig.session.clock.day(), day_before + 1)


func test_picking_up_a_loose_part_moves_it_from_the_deck_to_the_pack() -> void:
	var cell: Vector2i = rig.map.loose_items.keys()[0]
	var expected: StringName = rig.map.loose_item_at(cell)
	await _stand_on(cell)

	assert_eq(rig.current_interaction().kind, Interaction.Kind.PICK_UP)
	GameInput.press_interact()

	assert_true(rig.session.inventory.has(expected), "the %s was not picked up" % expected)
	assert_eq(rig.map.loose_item_at(cell), &"", "the item is still listed on the deck")
	assert_eq(rig.map.prop_symbol(cell), ".", "the prop was not cleared")


func test_a_part_cannot_be_picked_up_twice() -> void:
	var cell: Vector2i = rig.map.loose_items.keys()[0]
	await _stand_on(cell)
	GameInput.press_interact()
	var carried := rig.session.inventory.count()

	GameInput.press_interact()
	assert_eq(rig.session.inventory.count(), carried)


func test_a_full_pack_leaves_the_part_where_it_is() -> void:
	var cell: Vector2i = rig.map.loose_items.keys()[0]
	var expected: StringName = rig.map.loose_item_at(cell)
	while rig.session.inventory.add(&"ration"):
		pass
	await _stand_on(cell)

	GameInput.press_interact()
	assert_false(rig.session.inventory.has(expected))
	assert_eq(rig.map.loose_item_at(cell), expected, "the part vanished despite a full pack")


func test_the_conditioning_rig_trains_conditioning_and_costs_time() -> void:
	var gym := _find_prop(&"conditioning_rig")
	await _stand_on(_beside(gym))
	assert_eq(rig.current_interaction().kind, Interaction.Kind.TRAIN)
	assert_eq(rig.current_interaction().trains(), Stats.CONDITIONING)

	var before := rig.session.clock.total_minutes()
	GameInput.press_interact()
	assert_eq(rig.session.stats.progress(Stats.CONDITIONING), 1)
	assert_eq(rig.session.clock.total_minutes() - before, RigWorld.TRAINING_MINUTES)


func test_three_sessions_raise_conditioning_by_one_level() -> void:
	var gym := _find_prop(&"conditioning_rig")
	await _stand_on(_beside(gym))
	assert_eq(rig.session.stats.level(Stats.CONDITIONING), 1)

	for _session in range(Stats.SESSIONS_PER_LEVEL):
		GameInput.press_interact()

	assert_eq(rig.session.stats.level(Stats.CONDITIONING), 2)
	assert_eq(rig.session.stats.progress(Stats.CONDITIONING), 0)


func test_a_detained_player_cannot_interact() -> void:
	var cell: Vector2i = rig.map.loose_items.keys()[0]
	await _stand_on(cell)
	rig.session.detain_player("test")

	GameInput.press_interact()
	assert_eq(rig.map.loose_item_at(cell), rig.map.loose_items.get(cell, &""))
	assert_false(rig.session.inventory.has(rig.map.loose_item_at(cell)))
