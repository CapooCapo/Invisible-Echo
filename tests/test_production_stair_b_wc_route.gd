extends SceneTree

## End-to-end regression for the configured story scene, not the isolated
## school harness. Starts from the normal night-school yard checkpoint and
## moves the real HoangController3D only through InputMap actions.
## Run: godot --headless --path . --script res://tests/test_production_stair_b_wc_route.gd
const MAIN := "res://scenes/01_hanh_lang.tscn"
const YARD_START := Vector3(0, 0, 29)
const WC_DOOR := Vector3(14, 6.4, 1)
const WALK_SPEED := 3.35
const EVIDENCE_DIR := "/home/giahoang/dev/invisible-echo/builds/visual-qa/environment-recovery-20261015"

var game: Node
var night: Node
var actor: CharacterBody3D
var rail_contact := ""
var landing_contact := ""
var south_guard_contact := ""
var frame_contacts := "none"
var last_drive_tracks_level_3 := false
var last_drive_floor_ok := true
var last_drive_min_y := 0.0
var last_drive_ungrounded_frames := 0
var last_drive_first_bad_frame := "none"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node_or_null("GameState")
	if state == null:
		push_error("PRODUCTION_STAIR_B_WC_FAIL missing GameState autoload")
		quit(1)
		return
	state.persistence_enabled = false
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	game = load(MAIN).instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	await process_frame
	night = game.get("night_school_visual")
	actor = night.get("actor") as CharacterBody3D if night != null else null
	if actor == null or night.get("world") == null:
		push_error("PRODUCTION_STAIR_B_WC_FAIL production scene did not create Hoang and NightSchool world")
		quit(1)
		return
	var world: Node3D = night.get("world")
	var mapped := world.get_node_or_null("MappedSchoolEnvironment")
	if mapped == null or world.get_node_or_null("StoryRestroomGameplayOverlay") == null:
		push_error("PRODUCTION_STAIR_B_WC_FAIL expected mapped architecture and story overlay in configured main scene")
		quit(1)
		return
	var story_overlay := world.get_node("StoryRestroomGameplayOverlay") as Node3D
	var story_door := night.get("restroom_door") as Node3D
	var story_blocker := night.get("restroom_door_blocker") as Node3D
	var mapped_wc_hinge := mapped.get_node_or_null("Level3/WC NAM door hinge pivot") as Node3D
	var reflection_view := night.get("mirror_viewport") as SubViewport
	var reflection_world := night.get("mirror_world") as Node3D
	var reflection_hoang := night.get("mirror_player") as Node3D
	var reflection_camera := night.get("mirror_camera") as Camera3D
	var mirror_an := night.get("apparition") as Node3D
	if story_door == null or story_blocker == null or mapped_wc_hinge == null:
		push_error("PRODUCTION_STAIR_B_WC_FAIL could not resolve both actual WC door nodes")
		quit(1)
		return
	if reflection_view == null or reflection_world == null or reflection_hoang == null or reflection_camera == null or mirror_an == null:
		push_error("PRODUCTION_STAIR_B_WC_FAIL mirror runtime references missing: viewport=%s world=%s hoang_copy=%s camera=%s An=%s" % [reflection_view, reflection_world, reflection_hoang, reflection_camera, mirror_an])
		quit(1)
		return
	var mirror_surface := world.find_child("Mirror glass", true, false) as MeshInstance3D
	var mirror_material := mirror_surface.material_override as StandardMaterial3D if mirror_surface != null else null
	if mirror_surface == null or mirror_material == null or mirror_material.albedo_texture != reflection_view.get_texture():
		push_error("PRODUCTION_STAIR_B_WC_FAIL live mirror surface is not bound to MirrorReflectionViewport texture")
		quit(1)
		return
	print("PRODUCTION_STAIR_B_WC_TARGET overlay=%s origin=%s yaw=%.3f story_door=%s local=%s world=%s blocker=%s world=%s mapped_hinge=%s world=%s trigger=%s" % [
		story_overlay.get_path(), story_overlay.global_position, story_overlay.global_rotation.y,
		story_door.get_path(), story_door.position, story_door.global_position,
		story_blocker.get_path(), story_blocker.global_position,
		mapped_wc_hinge.get_path(), mapped_wc_hinge.global_position, WC_DOOR
	])
	print("PRODUCTION_MIRROR_SETUP viewport=%s size=%s world=%s own_world=%s camera=%s current=%s Hoang_copy=%s copy_visible=%s copy_meshes_visible=%d An=%s An_initial_visible=%s surface=%s texture_bound=true" % [
		reflection_view.get_path(), reflection_view.size, reflection_world.get_path(), reflection_view.own_world_3d,
		reflection_camera.get_path(), reflection_camera.current, reflection_hoang.get_path(),
		reflection_hoang.is_visible_in_tree(), _visible_mesh_count(reflection_hoang), mirror_an.get_path(),
		mirror_an.visible, mirror_surface.get_path()
	])
	if not reflection_view.own_world_3d or not reflection_camera.current or not reflection_hoang.is_visible_in_tree() or _visible_mesh_count(reflection_hoang) == 0 or mirror_an.visible:
		push_error("PRODUCTION_STAIR_B_WC_FAIL mirror viewport/camera/copy visibility setup is invalid")
		quit(1)
		return
	if actor.global_position.distance_to(YARD_START) > .1:
		push_error("PRODUCTION_STAIR_B_WC_FAIL checkpoint spawn=%s expected=%s" % [actor.global_position, YARD_START])
		quit(1)
		return
	print("PRODUCTION_STAIR_B_WC_TRACE start checkpoint=night_school_yard scene=%s pos=%s" % [MAIN, actor.global_position])

	# The yard's fountain, bench, and central stage block a straight line to
	# Stair B. Walk along the clear east verge, pass north of the stage, then
	# return to the actual school entry; no transforms are written.
	await _drive("move_right", 2.80)
	_trace("yard_east_verge")
	await _drive("move_up", 13.43)
	_trace("yard_north_of_stage")
	await _drive("move_left", 2.80)
	_trace("school_entry_alignment")
	await _drive("move_up", 1.20)
	_trace("entry_north_south_alignment")
	# The controller has already arrived at the mapped entry. A further left
	# input moves about 9 m away from Stair B and outside the interaction range.
	_trace("school_entry_approach")
	if not bool(night.call("near_main_entry")):
		_fail("could not reach the mapped main entry from yard input")
		return
	if str(game.get("night_phase")) != "ground_hall" or str(night.get("story_zone")) != "ground_hall":
		_fail("crossing the mapped main entry did not advance yard to ground_hall")
		return
	var objective := game.get("objective") as Label
	var prompt := game.get("prompt") as Label
	if objective == null or not objective.text.contains("Cầu thang") or prompt == null \
		or prompt.text != "E  ·  Vào cầu thang" or not prompt.is_visible_in_tree():
		_fail("ground-hall entry did not replace the yard objective/prompt with the Stair B interaction")
		return
	_press_key(KEY_E)
	await process_frame
	if str(game.get("night_phase")) != "stairs" or str(night.get("story_zone")) != "stairs":
		_fail("stairwell interaction did not enter stairs phase")
		return
	if objective.text != "Tầng 3 · Đi lên cầu thang" or prompt.text != "WASD di chuyển · Lên ba tầng":
		_fail("stairwell E did not update the objective and movement prompt")
		return

	# B's first ramp rises north on its west lane, then the second rises south
	# on the east lane. Re-center on the south side of the ramp toe using input:
	# the yard approach naturally arrives just past the toe, beneath the ramp.
	await _drive("move_down", .42)
	await _drive("move_left", .36)
	_trace("stair_b_base_reposition")
	await _drive("move_up", 2.60)
	_trace("stair_b_level_2_landing")
	if actor.global_position.y < 2.8:
		_fail("Hoang did not reach the level-2 Stair B landing")
		return
	await _drive("move_up", .20)
	_trace("stair_b_level_2_transfer_pad")
	await _drive("move_right", .72)
	_trace("stair_b_level_2_transfer")
	await _drive("move_down", 2.35)
	_trace("stair_b_level_3_landing")
	if actor.global_position.y < 5.8 or not actor.is_on_floor():
		_fail("Hoang did not reach a stable level-3 Stair B landing (y>=5.8 and on floor)")
		return
	# The supported connector passes south of the sloped handrail tip before
	# turning east, then follows the guarded rim north onto the level-3 gallery.
	await _drive("move_down", .20)
	_trace("stair_b_level_3_south_transfer_pad")
	if not _grounded_level_3():
		_fail("level-3 landing south transfer pad lost floor support")
		return
	await _drive("move_down", .10)
	_trace("stair_b_level_3_south_of_handrail_tip")
	if not _grounded_level_3():
		_fail("south-side handrail clearance lost level-3 floor support")
		return
	await _drive("move_right", .56)
	_trace("stair_b_level_3_east_edge_connector")
	if not _grounded_level_3():
		_fail("Stair B connector east transfer lost level-3 support; current_contacts=%s" % frame_contacts)
		return
	# Probe the connector's exposed south edge using the real controller. The
	# guard should stop this input before Hoang can leave the connector floor.
	await _drive("move_down", .55)
	_trace("south_edge_guard_probe")
	if not _grounded_level_3() or actor.global_position.z > -18.08 or south_guard_contact.is_empty():
		_fail("south-edge safety probe did not remain grounded behind the connector guard; z=%.3f guard_contact=%s current_contacts=%s" % [actor.global_position.z, south_guard_contact, frame_contacts])
		return
	# Return to the landing pad and re-enter the connector to prove that the
	# guarded edge did not close the intended landing transfer portal.
	await _drive("move_left", .56)
	_trace("connector_return_to_landing")
	if not _grounded_level_3() or actor.global_position.x > 2.4:
		_fail("connector-to-landing transfer was blocked after the guard probe")
		return
	await _drive("move_right", .56)
	_trace("landing_transfer_path_reentered")
	if not _grounded_level_3() or actor.global_position.x < 2.5:
		_fail("landing-to-connector transfer portal is not open after the guard probe")
		return
	await _drive("move_up", .72)
	_trace("level_3_north_gallery_join")
	if not _grounded_level_3() or actor.global_position.x < 2.5 or actor.global_position.z > -20.8:
		_fail("transition=Stair B connector->north gallery failed (expected on-floor x>=2.5,z<=-20.8); current_contacts=%s" % frame_contacts)
		return
	await _wait_frames(3)
	if str(game.get("night_phase")) != "upper_hall":
		_fail("gameplay did not enter upper_hall after grounded level-3 arrival")
		return
	if objective.text != "TẦNG 3 · WC NAM  →  BÊN PHẢI" or prompt.text != "Rẽ phải theo hành lang · Tìm biển WC NAM":
		_fail("level-3 arrival did not update the restroom objective and corridor prompt")
		return
	# Clear the endpoint baluster at the courtyard guardrail before turning east.
	await _drive("move_up", .20)
	_trace("north_gallery_clear_of_connector_guardrail")
	if not _grounded_level_3() or actor.global_position.z > -21.3:
		_fail("north-gallery route did not clear the connector guardrail endpoint")
		return
	var east_time := maxf((11.3 - actor.global_position.x) / WALK_SPEED, 0.0)
	await _drive("move_right", east_time)
	_trace("level_3_east_gallery")
	if not _grounded_level_3() or actor.global_position.x < 10.8:
		_fail("east gallery traversal lost floor support or failed to clear the atrium rail; current_contacts=%s" % frame_contacts)
		return
	var south_time := maxf((WC_DOOR.z - actor.global_position.z) / WALK_SPEED, 0.0)
	await _drive("move_down", south_time)
	_trace("east_wing_wc_approach_lane")
	if not _grounded_level_3() or absf(actor.global_position.z - WC_DOOR.z) > .45:
		_fail("east-wing southbound route lost floor support or missed the WC Nam doorway lane; current_contacts=%s" % frame_contacts)
		return
	var door_approach_x := WC_DOOR.x - 1.7
	var door_approach_time := maxf((door_approach_x - actor.global_position.x) / WALK_SPEED, 0.0)
	await _drive("move_right", door_approach_time)
	_trace("wc_nam_actual_door_approach")
	if not _grounded_level_3() or not bool(night.call("near_restroom_door")):
		_fail("could not reach the production WC Nam entrance interaction range; current_contacts=%s" % frame_contacts)
		return
	if prompt.text != "E  ·  Mở cửa" or not prompt.is_visible_in_tree():
		_fail("WC Nam approach does not show the visible E · Mở cửa prompt")
		return
	_press_key(KEY_E)
	await process_frame
	if str(game.get("night_phase")) != "entering_restroom" or not bool(night.get("restroom_entry_open")):
		_fail("actual WC Nam door interaction did not open the production entrance")
		return
	await _wait_frames(24) # allow the live hinge tween to finish before evaluating clearance
	if not story_blocker.disabled:
		_fail("story restroom entrance interaction did not disable its production door blocker")
		return
	var door_leaf := story_door.get_node_or_null("ThirdFloorRestroomDoor") as MeshInstance3D
	var threshold_point := Vector3(14.0, 6.52, 1.0)
	var leaf_local_threshold := door_leaf.global_transform.affine_inverse() * threshold_point if door_leaf != null else Vector3.ZERO
	if door_leaf == null or not door_leaf.is_visible_in_tree() or story_door.rotation.y < .9 or absf(leaf_local_threshold.z) < .20:
		_fail("hinged WC door did not visibly swing clear of the threshold; leaf=%s angle=%.3f threshold_in_leaf=%s" % [door_leaf, story_door.rotation.y, leaf_local_threshold])
		return
	print("PRODUCTION_STAIR_B_WC_DOOR_OPEN hinge=%s angle_y=%.3f leaf=%s visible=%s threshold_local=%s blocker=%s disabled=%s" % [
		story_door.get_path(), story_door.rotation.y, door_leaf.get_path(), door_leaf.is_visible_in_tree(),
		leaf_local_threshold, story_blocker.get_path(), story_blocker.disabled
	])
	_capture_subviewport(night.get("viewport") as SubViewport, "production_wc_door_open_after.png")
	await _drive("move_right", 1.10)
	await _wait_frames(5)
	_trace("crossed_into_wc_nam")
	var inside_room := actor.global_position.x > 14.8 and actor.global_position.x < 24.0 and actor.global_position.z > -2.0 and actor.global_position.z < 4.0
	if not _grounded_level_3() or not inside_room or str(night.get("story_zone")) != "restroom":
		_fail("WC threshold was not crossed into the actual restroom; inside_bounds=%s story_zone=%s current_contacts=%s" % [inside_room, night.get("story_zone"), frame_contacts])
		return
	print("PRODUCTION_STAIR_B_WC_INTERIOR bounds=WC_NAM_x14..24_z-2..4 player=%s story_zone=%s controls_enabled=%s" % [actor.global_position, night.get("story_zone"), actor.get("controls_enabled")])
	# Continue the production story through the normal dialogue, survival event,
	# and mirror interactions so this checks live triggers rather than test-only
	# calls to set the player at the mirror.
	await _interaction_frame_chain(["friend_lan_line", "gang_search_before_red"])
	game.call("_interact_night_school") # advance into the timed red-warning beat
	await _wait_for_night_phase("warning_line", 50)
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "find_stall":
		_fail("normal dialogue did not enter the WC hide event")
		return
	print("PRODUCTION_MIRROR_TRACE step=survival_start player=%s phase=%s" % [actor.global_position, game.get("night_phase")])
	var stall_target := Vector3(16.8, actor.global_position.y, -1.1)
	await _walk_to_xy(stall_target.x, stall_target.z)
	_trace("restroom_stall_door_approach")
	if not bool(night.call("near_stall_door")):
		_fail("real input route did not reach the production stall-door interaction trigger")
		return
	game.call("_interact_night_school")
	if not bool(night.get("stall_open")):
		_fail("normal stall-door interaction did not open the hiding stall")
		return
	# The production hide trigger is inside the first mapped cubicle, not at the
	# east-side restroom aisle coordinate used by the earlier route harness.
	var hide_target := Vector3(15.75, actor.global_position.y, -1.5)
	await _walk_to_xy(hide_target.x, hide_target.z)
	_trace("restroom_stall_interior_approach")
	if not bool(night.call("inside_stall")):
		_fail("grounded input movement did not reach the actual stall hiding trigger")
		return
	if frame_contacts.to_lower().contains("toilet") or frame_contacts.to_lower().contains("partition") or frame_contacts.to_lower().contains("basin") or frame_contacts.to_lower().contains("vanity"):
		_fail("hiding trigger is occupied but overlaps a restroom fixture collider; contacts=%s" % frame_contacts)
		return
	print("PRODUCTION_WC_STALL_REACHED door_open=%s trigger_inside=true grounded=%s player=%s sampled_contacts=%s" % [night.get("stall_open"), actor.is_on_floor(), actor.global_position, frame_contacts])
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "gang_arrival" or not bool(night.get("player_hidden")):
		_fail("normal stall hide interaction did not enter the survival event")
		return
	await _wait_for_night_phase("bell_line", 360)
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "wait_exit":
		_fail("survival event did not reach its normal exit interaction")
		return
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "exit_hiding" or bool(night.get("player_hidden")):
		_fail("normal hiding-stall exit interaction did not restore player controls")
		return
	# Pass north of the mapped west-side cubicle toilets before returning through
	# the west doorway; the straight z=-0.3 line intersects the second toilet.
	await _walk_to_xy(19.8, 1.0)
	_trace("restroom_exit_clearance_lane")
	await _walk_to_xy(12.9, 1.0)
	_trace("restroom_exit_hallway_trigger")
	if str(game.get("night_phase")) != "after_stall_line":
		_fail("leaving the restroom via grounded movement did not trigger the after-stall story beat")
		return
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "friend_bao":
		_fail("normal after-stall interaction did not reveal the mirror message")
		return
	await _wait_frames(35) # allow the condensation writing reveal tween to reach its visible state
	var mirror_writing := night.get("mirror_text") as Label3D
	var mirror_mist := night.get("mirror_condensation") as MeshInstance3D
	if mirror_writing == null or mirror_mist == null or not mirror_writing.visible or not mirror_mist.visible:
		_fail("mirror writing/condensation did not become visible after the production story interaction")
		return
	await _interaction_frame_chain(["friend_huan", "friend_lan", "mirror_search"])
	if str(game.get("night_phase")) != "mirror_search":
		_fail("friend dialogue did not activate the normal mirror-search trigger")
		return
	var mirror_route_target: Vector3 = night.call("_map_old_story_point", Vector3(6.0, 4.8, -30.2))
	await _walk_to_xy(mirror_route_target.x, mirror_route_target.z)
	_trace("live_mirror_trigger_approach")
	if not bool(night.call("near_mirror")):
		_fail("normal grounded route did not enter the live mirror interaction radius")
		return
	_capture_subviewport(reflection_view, "mirror_view_at_live_trigger.png")
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "mirror_ghost" or not mirror_an.visible or not mirror_an.is_visible_in_tree():
		_fail("live E interaction at mirror trigger did not show An in the reflection world")
		return
	print("PRODUCTION_MIRROR_TRACE step=apparition_visible pos=%s phase=%s An=%s visible=%s copy_visible=%s" % [actor.global_position, game.get("night_phase"), mirror_an.get_path(), mirror_an.is_visible_in_tree(), reflection_hoang.is_visible_in_tree()])
	_capture_subviewport(reflection_view, "mirror_view_with_live_apparition.png")
	game.call("_interact_night_school")
	if str(game.get("night_phase")) != "mirror_empty" or mirror_an.visible:
		_fail("normal turn-from-mirror interaction did not hide the live reflection apparition")
		return
	game.call("_interact_night_school")
	var hallway_an := night.get("hallway_apparition") as Node3D
	if str(game.get("night_phase")) != "hallway_apparition" or hallway_an == null or not hallway_an.is_visible_in_tree():
		_fail("normal mirror follow-up interaction did not show An in the hallway apparition node")
		return
	print("PRODUCTION_MIRROR_TRACE step=hallway_apparition_visible player=%s phase=%s hallway_An=%s visible=%s" % [actor.global_position, game.get("night_phase"), hallway_an.get_path(), hallway_an.is_visible_in_tree()])
	await _wait_for_night_phase("mirror_reveal", 180)
	if mirror_an.visible or hallway_an.visible or str(night.get("story_zone")) != "mirror":
		_fail("mirror apparition cleanup or transition to the notice-board stage failed")
		return
	print("PRODUCTION_MIRROR_PASS viewport_bound=true Hoang_copy_visible=true mirror_trigger=true An_show_hide=true hallway_apparition_cleanup=true final_phase=%s story_zone=%s" % [game.get("night_phase"), night.get("story_zone")])
	print("PRODUCTION_STAIR_B_WC_PASS grounded=true door_open=true crossed_threshold=true story_zone=%s player=%s floor_contact=%s north_rail_contact=%s" % [night.get("story_zone"), actor.global_position, frame_contacts, rail_contact if not rail_contact.is_empty() else "none"])
	quit(0)

func _drive(action: StringName, seconds: float) -> void:
	await _drive_actions([action], seconds)

func _drive_actions(actions: Array[StringName], seconds: float) -> void:
	last_drive_tracks_level_3 = actor != null and actor.global_position.y >= 5.8
	last_drive_floor_ok = true
	last_drive_min_y = actor.global_position.y if actor != null else 0.0
	last_drive_ungrounded_frames = 0
	last_drive_first_bad_frame = "none"
	for action in actions:
		Input.action_press(action)
	var frame_count := ceili(seconds * 60.0)
	for _frame in frame_count:
		await physics_frame
		_capture_contacts()
		_sample_drive_floor()
	for action in actions:
		Input.action_release(action)
	await physics_frame
	_capture_contacts()
	_sample_drive_floor()

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game.call("_unhandled_input", event)

func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		_capture_contacts()

func _interaction_frame_chain(expected_phases: Array[String]) -> void:
	for expected in expected_phases:
		game.call("_interact_night_school")
		await process_frame
		if str(game.get("night_phase")) != expected:
			_fail("normal E dialogue chain expected phase=%s actual=%s" % [expected, game.get("night_phase")])
			return

func _wait_for_night_phase(expected: String, max_frames: int) -> void:
	for _frame in max_frames:
		if str(game.get("night_phase")) == expected:
			return
		await process_frame
		await physics_frame
		_capture_contacts()
	if str(game.get("night_phase")) != expected:
		_fail("timed production story phase did not reach %s; actual=%s" % [expected, game.get("night_phase")])

func _walk_to_xy(target_x: float, target_z: float) -> void:
	if absf(target_x - actor.global_position.x) > .08:
		var x_delta := target_x - actor.global_position.x
		await _drive_world_axis(Vector3(signf(x_delta), 0.0, 0.0), absf(x_delta) / WALK_SPEED)
	if absf(target_z - actor.global_position.z) > .08:
		var z_delta := target_z - actor.global_position.z
		await _drive_world_axis(Vector3(0.0, 0.0, signf(z_delta)), absf(z_delta) / WALK_SPEED)

func _drive_world_axis(world_direction: Vector3, seconds: float) -> void:
	# Scene 03 turns the camera toward the stall opening before hiding. Translate
	# the intended world-space route into the player's current camera-relative
	# controls so this harness continues to use real InputMap actions after that
	# production camera turn.
	var local_direction := world_direction.rotated(Vector3.UP, -actor.camera_yaw).normalized()
	var actions: Array[StringName] = []
	if absf(local_direction.x) > .01:
		actions.append("move_right" if local_direction.x > 0.0 else "move_left")
	if absf(local_direction.z) > .01:
		actions.append("move_down" if local_direction.z > 0.0 else "move_up")
	await _drive_actions(actions, seconds)

func _capture_subviewport(view: SubViewport, filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var path := EVIDENCE_DIR.path_join(filename)
	if DisplayServer.get_name() == "headless":
		print("PRODUCTION_VISUAL_CAPTURE_UNAVAILABLE path=%s reason=headless_display_server" % path)
		return
	var image := view.get_texture().get_image()
	if image == null:
		print("PRODUCTION_VISUAL_CAPTURE_UNAVAILABLE path=%s reason=renderer_has_no_texture_readback" % path)
		return
	var error := image.save_png(path)
	print("PRODUCTION_VISUAL_CAPTURE path=%s size=%s result=%s" % [path, image.get_size(), error_string(error)])
	if error != OK:
		push_warning("Could not save production SubViewport capture: %s (%s)" % [path, error_string(error)])

func _visible_mesh_count(root_node: Node) -> int:
	var count := 1 if root_node is MeshInstance3D and root_node.is_visible_in_tree() else 0
	for child in root_node.get_children():
		count += _visible_mesh_count(child)
	return count

func _grounded_level_3() -> bool:
	return actor != null and actor.is_on_floor() and actor.global_position.y >= 5.8 and (not last_drive_tracks_level_3 or last_drive_floor_ok)

func _sample_drive_floor() -> void:
	if not last_drive_tracks_level_3 or actor == null:
		return
	last_drive_min_y = minf(last_drive_min_y, actor.global_position.y)
	if not actor.is_on_floor() or actor.global_position.y < 5.8:
		last_drive_floor_ok = false
		last_drive_ungrounded_frames += 1
		if last_drive_first_bad_frame == "none":
			last_drive_first_bad_frame = "pos=%s on_floor=%s contacts=%s" % [actor.global_position, actor.is_on_floor(), frame_contacts]

func _capture_contacts() -> void:
	if actor == null:
		return
	var contacts: Array[String] = []
	for index in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider == null:
			continue
		var path := str(collider.get_path())
		var detail := "player=%s contact=%s normal=%s" % [
			actor.global_position, collision.get_position(), collision.get_normal()
		]
		contacts.append("%s %s" % [path, detail])
		if rail_contact.is_empty() and str(collider.name).contains("North Atrium Rail"):
			rail_contact = "%s %s" % [path, detail]
		if landing_contact.is_empty() and str(collider.name).contains("Stair B upper landing L1"):
			landing_contact = "%s %s" % [path, detail]
		if south_guard_contact.is_empty() and str(collider.name).contains("east-edge connector south guardrail"):
			south_guard_contact = "%s %s" % [path, detail]
	frame_contacts = "; ".join(contacts) if not contacts.is_empty() else "none"

func _trace(label: String) -> void:
	print("PRODUCTION_STAIR_B_WC_TRACE step=%s pos=%s y=%.3f on_floor=%s rail_contact=%s landing_contact=%s" % [
		label, actor.global_position, actor.global_position.y,
		actor.is_on_floor(), rail_contact if not rail_contact.is_empty() else "none",
		landing_contact if not landing_contact.is_empty() else "none"
	])
	if south_guard_contact != "":
		print("PRODUCTION_STAIR_B_WC_GUARD_CONTACT step=%s %s" % [label, south_guard_contact])
	if last_drive_tracks_level_3:
		print("PRODUCTION_STAIR_B_WC_FLOOR step=%s continuous=%s min_y=%.3f ungrounded_frames=%d first_bad=%s" % [
			label, last_drive_floor_ok, last_drive_min_y, last_drive_ungrounded_frames, last_drive_first_bad_frame
		])
	if frame_contacts != "none":
		print("PRODUCTION_STAIR_B_WC_CONTACT step=%s %s" % [label, frame_contacts])

func _fail(reason: String) -> void:
	push_error("PRODUCTION_STAIR_B_WC_FAIL reason=%s player=%s on_floor=%s rail_contact=%s landing_contact=%s" % [
		reason, actor.global_position,
		actor.is_on_floor(), rail_contact if not rail_contact.is_empty() else "none",
		landing_contact if not landing_contact.is_empty() else "none"
	])
	if last_drive_tracks_level_3:
		push_error("PRODUCTION_STAIR_B_WC_FLOOR continuous=%s min_y=%.3f ungrounded_frames=%d first_bad=%s" % [
			last_drive_floor_ok, last_drive_min_y, last_drive_ungrounded_frames, last_drive_first_bad_frame
		])
	quit(1)
