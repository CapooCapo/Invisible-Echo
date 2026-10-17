extends SceneTree

## Verifies the F5-equivalent opening preview override without touching the
## user's save file. Run with: godot --headless --path . --script
## tests/test_opening_preview.gd -- --opening-preview
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
const SAVE_PATH := "user://an_tieng_gay_trong_dem_save.json"
const SEED_SAVE_PATH := "user://opening_preview_seed_save_test.json"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var before_save := _read_save_snapshot()
	var seed_file := FileAccess.open(SEED_SAVE_PATH, FileAccess.WRITE)
	_check(seed_file != null, "test can create a separate seeded save fixture")
	if seed_file != null:
		seed_file.store_string("{\"checkpoint_id\":\"seeded_checkpoint\",\"sentinel\":\"unchanged\"}")
		seed_file.close()
	var before_seed_save := _read_snapshot(SEED_SAVE_PATH)
	_check(OS.get_cmdline_user_args().has("--opening-preview"),
		"test launched with the F5-equivalent opening preview argument")

	# Seed only in-memory state. The test never writes to the real save path.
	state.persistence_enabled = true
	state.chapter = "chapter_seeded"
	state.scene_id = "scene_12"
	state.checkpoint_id = "return_memories"
	var seeded_inventory: Array[String] = ["seed_item"]
	state.inventory = seeded_inventory
	state.evidence = {"seed_evidence": "kept"}
	state.flags = {"seed_flag": true}
	state.choices = {"seed_choice": "kept"}
	state.ending = "seed_ending"

	var game: Node = load(MAIN_SCENE).instantiate()
	_check(game != null, "main game scene instantiates in opening preview mode")
	if game == null:
		_finish(before_save, before_seed_save)
		return
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame

	_check(bool(game.get("opening_preview_launch")),
		"preview launch is recognized and routes into the opening")
	_check(str(game.get("opening_phase")) == "scene01_monologue",
		"F5-equivalent launch starts at Scene 01's opening monologue")
	var inventory_slots: Array = game.get("inventory_slots")
	var inventory_labels: Array = game.get("inventory_slot_labels")
	_check(inventory_slots.size() == 6 and inventory_labels.size() == 6,
		"hotbar contains exactly six item slots")
	_check(not inventory_labels.is_empty()
		and (inventory_labels[0] as Label).text == "1\nĐÈN PIN"
		and int(game.get("selected_inventory_slot")) == 0,
		"flashlight occupies the selected first slot by default")
	var flashlight_gameplay: Node = (game.get("hallway_visual") as Node).get("actor")
	var flashlight := flashlight_gameplay.get("flashlight") as SpotLight3D
	_check(flashlight != null and not flashlight.visible, "gameplay flashlight starts off")
	_press_key(game, KEY_6)
	_check(int(game.get("selected_inventory_slot")) == 5, "number key 6 selects the sixth slot")
	_press_key(game, KEY_F)
	_check(flashlight != null and not flashlight.visible,
		"F does not use the flashlight while a different slot is selected")
	_press_key(game, KEY_1)
	_press_key(game, KEY_F)
	_check(flashlight != null and flashlight.visible,
		"selecting slot 1 lets F toggle the flashlight on")
	_press_key(game, KEY_F)
	_check(flashlight != null and not flashlight.visible,
		"F toggles the flashlight back off")
	var hallway: Node = game.get("hallway_visual")
	var hallway_actor := hallway.get("actor") as CharacterBody3D if hallway != null else null
	var first_person_arm := hallway_actor.get("spring_arm") as SpringArm3D if hallway_actor != null else null
	_check(hallway_actor != null and not bool(hallway_actor.get("model").visible)
		and first_person_arm != null and is_zero_approx(first_person_arm.spring_length),
		"gameplay camera starts in first-person")
	if hallway != null:
		hallway.call("play_pickup_camera")
	var reading_arm := hallway_actor.get("spring_arm") as SpringArm3D if hallway_actor != null else null
	_check(reading_arm != null and is_equal_approx(reading_arm.spring_length, 3.0)
		and bool(hallway_actor.get("model").visible),
		"letter examination temporarily shows Hoang in third-person")
	if hallway != null:
		hallway.call("end_pickup_camera")
	_check(hallway_actor != null and not bool(hallway_actor.get("model").visible)
		and first_person_arm != null and is_zero_approx(first_person_arm.spring_length),
		"closing letter examination restores first-person immediately")
	var night_school: Node = game.get("night_school_visual")
	var night_world := night_school.get_node_or_null("NightSchoolViewport/NightSchool") if night_school != null else null
	var imported_campus := night_school.get_node_or_null(
		"NightSchoolViewport/NightSchool/TestNEHSchoolCampus") if night_school != null else null
	_check(imported_campus != null and not imported_campus.visible,
		"night-school retains the imported campus as an inactive comparison scene")
	_check(imported_campus != null and imported_campus.get_node_or_null("RuntimeGeometry") != null
		and imported_campus.get_node_or_null("Player") == null,
		"the imported campus geometry is present without the source game's player")
	var imported_bodies := imported_campus.find_children("*", "StaticBody3D", true, false) if imported_campus != null else []
	var imported_body := imported_bodies[0] as CollisionObject3D if not imported_bodies.is_empty() else null
	var night_actor := night_school.get("actor") as CharacterBody3D if night_school != null else null
	var mapped_environment := night_world.get_node_or_null("MappedSchoolEnvironment") if night_world != null else null
	_check(imported_body != null and imported_body.collision_layer == 0
		and imported_body.collision_mask == 0 and night_actor != null
		and mapped_environment != null and mapped_environment.visible,
		"the mapped campus is active while the retained import has no active collision")
	var level3 := mapped_environment.get_node_or_null("Level3") if mapped_environment != null else null
	var upper_corridor := level3.get_node_or_null("East gallery") as MeshInstance3D if level3 != null else null
	var restroom_floor := level3.find_child("WC NAM floor", true, false) as MeshInstance3D if level3 != null else null
	var restroom_hinge := night_world.find_child("ThirdFloorRestroomDoorHinge", true, false) as Node3D if night_world != null else null
	var restroom_door := restroom_hinge.get_node_or_null("ThirdFloorRestroomDoor") as MeshInstance3D if restroom_hinge != null else null
	var restroom_sign := night_world.find_child("RestroomWayfindingSign", true, false) as Label3D if night_world != null else null
	_check(upper_corridor != null and upper_corridor.visible
		and restroom_floor != null and restroom_floor.visible
		and restroom_door != null and restroom_door.visible
		and restroom_sign != null and restroom_sign.visible,
		"mapped third-floor WC and its interactive, signed entrance are visible off the east gallery")
	_check(upper_corridor != null and restroom_hinge != null
		and restroom_hinge.global_position.is_equal_approx(Vector3(14.0, 6.52, 0.225)),
		"interactive restroom entrance is aligned to the mapped Level 3 WC approach")
	if night_school != null and night_actor != null:
		night_school.set("story_zone", "upper_hall")
		night_actor.teleport_to(Vector3(14.0, 6.52, 1.0))
		_check(bool(night_school.call("near_restroom_door")),
			"Hoang can reach the restroom entrance from the upper corridor")
		night_school.call("open_restroom_entry")
		await create_timer(0.35).timeout
		var restroom_blocker := night_school.get("restroom_door_blocker") as CollisionShape3D
		_check(restroom_hinge != null and is_equal_approx(restroom_hinge.rotation.y, PI * 0.5)
			and restroom_blocker != null and restroom_blocker.disabled,
			"opening the WC entrance rotates its leaf and disables the closed-door blocker")
		night_actor.teleport_to(Vector3(15.2, 6.52, 1.0))
		_check(bool(night_school.call("crossed_restroom_threshold")),
			"opening the restroom door allows entry across its threshold")
	_check(not bool(state.persistence_enabled),
		"preview disables persistence before changing checkpoint state")
	_check(str(state.scene_id) == "scene_01"
		and str(state.checkpoint_id) == "hallway_letter",
		"preview starts at the Scene 01 hallway checkpoint in memory")
	_check(state.inventory.is_empty() and state.evidence.is_empty()
		and state.flags.is_empty() and state.choices.is_empty(),
		"preview clears only the in-memory run state")
	_check(_read_save_snapshot() == before_save,
		"launching the preview leaves the existing save file byte-for-byte unchanged")
	state.call("save_game", SEED_SAVE_PATH)
	_check(_read_snapshot(SEED_SAVE_PATH) == before_seed_save,
		"direct public save_game calls cannot overwrite a seeded save during preview")

	_finish(before_save, before_seed_save)


func _read_save_snapshot() -> Dictionary:
	return _read_snapshot(SAVE_PATH)


func _read_snapshot(path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	if not exists:
		return {"exists": false, "contents": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "contents": "<unreadable>"}
	return {"exists": true, "contents": file.get_as_text()}


func _press_key(game: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game.call("_unhandled_input", event)


func _finish(before_save: Dictionary, before_seed_save: Dictionary = {}) -> void:
	_check(_read_save_snapshot() == before_save,
		"opening preview test itself did not alter the real save file")
	if not before_seed_save.is_empty():
		_check(_read_snapshot(SEED_SAVE_PATH) == before_seed_save,
			"opening preview test preserved its seeded save fixture")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SEED_SAVE_PATH))
	if failures == 0:
		print("OPENING_PREVIEW_PASS checks=%d" % checks)
		quit()
	else:
		push_error("OPENING_PREVIEW_FAIL failures=%d" % failures)
		quit(1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + description)
