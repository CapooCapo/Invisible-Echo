extends SceneTree

## First-slice spatial regression: movement and story transitions use the
## CharacterBody3D's physical position, not assignments to the 2D projection.
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
var checks := 0
var failures := 0
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	state.flags.clear()
	state.evidence.clear()
	state.scene_id = "scene_01"
	state.checkpoint_id = "scene_01_start"
	game = load(MAIN_SCENE).instantiate()
	if game == null:
		push_error("Main scene failed to instantiate.")
		quit(1)
		return
	root.add_child(game)
	current_scene = game
	await physics_frame
	await process_frame
	for i in 3:
		game.call("_advance_opening_sequence")
	_check(hallway_external_camera_is_active(game), "opening uses an external establishing camera")
	for i in 2:
		game.call("_advance_opening_sequence")

	var hall: Node = game.hallway_visual
	var actor := hall.get("actor") as CharacterBody3D
	_check(actor != null, "hallway has a CharacterBody3D player")
	if actor == null:
		_finish()
		return
	_check(actor.get_node_or_null("HoangCollision") is CollisionShape3D,
		"player has a physical capsule collider")
	_check(actor.get_node_or_null("CameraPivot/CameraSpringArm") is SpringArm3D,
		"player camera is mounted on a SpringArm3D")
	_check(_hallway_is_narrow_and_enclosed(hall),
		"hallway is a narrow, physically enclosed corridor rather than an open-sided walkway")
	_check(_hallway_has_warm_evening_lighting(hall),
		"hallway has warm, non-red sunset lighting")
	var animation_player := actor.get("animation_player") as AnimationPlayer
	_check(animation_player != null, "imported Hoang rig has an AnimationPlayer")
	if animation_player != null:
		var looped_clips := 0
		for candidate in animation_player.get_animation_list():
			var clip_name := candidate.get_slice("/", candidate.get_slice_count("/") - 1)
			if clip_name in ["Idle", "Walk", "Run"]:
				looped_clips += 1
				_check(animation_player.get_animation(candidate).loop_mode == Animation.LOOP_LINEAR,
					"%s loops beyond its imported clip duration" % clip_name)
		_check(looped_clips == 3, "Idle, Walk, and Run clips are all present")
		await create_timer(2.1).timeout
		_check(animation_player.is_playing() and animation_player.current_animation.ends_with("Idle"),
			"Idle remains animated after two seconds")
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/GameplayCamera") as Camera3D
	_check(camera != null and camera.current and _camera_is_first_person(actor),
		"first-person gameplay camera is active after controls return")
	var light := actor.get_node_or_null("CameraPivot/CameraSpringArm/GameplayCamera/Flashlight") as SpotLight3D
	_check(light != null and not light.visible, "flashlight starts off")
	_press_key(KEY_F)
	_check(light != null and light.visible, "F turns on the real 3D spotlight")
	_press_key(KEY_F)
	_check(light != null and not light.visible, "F turns the spotlight off")
	var yaw_before: float = actor.get("camera_yaw")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(120, -20)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		game._unhandled_input(mouse)
	else:
		# Display-server-less runs cannot capture the pointer. The same room
		# forwarding path remains testable; GUI event capture needs visual QA.
		print("REAL_3D_NOTE headless_pointer_capture_unavailable")
		hall.call("orbit_mouse", mouse.relative)
	_check(absf(float(actor.get("camera_yaw")) - yaw_before) > 0.1,
		"captured mouse motion orbits the first-person view")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	actor.set("camera_yaw", 0.0)
	actor.call("_apply_camera_rotation")

	# The classroom wall must stop motion; then restore a safe start for the
	# manual letter approach.
	await _drive("move_right", 0.9, true)
	_check(actor.position.x < 3.0 and actor.position.x > 1.0,
		"CharacterBody3D moves and collides with the hallway wall")
	Input.action_press("run")
	Input.action_press("move_up")
	for i in 128:
		await physics_frame
	_check(animation_player.is_playing() and animation_player.current_animation.ends_with("Run"),
		"Run remains animated during first-person hallway movement")
	Input.action_release("move_up")
	Input.action_release("run")
	var letter := hall.get("letter") as Node3D
	actor.call("teleport_to", letter.position + Vector3(0, 0, .7))
	await physics_frame
	_check(bool(hall.call("near_letter")), "walking reaches the letter in world space")
	_press_key(KEY_E)
	_check(str(game.get("opening_phase")) == "scene01_letter_inspect"
		and game.get("opening_letter_contents").text == "CỨU TÔI",
		"E opens only the short letter-front message")
	_check(_count_red_reveal_labels(hall) == 0,
		"pickup does not add red wall text or transition the corridor")
	await create_timer(.6).timeout
	_press_key(KEY_ESCAPE)
	_check(game.get("opening_speaker").text == "Hoàng"
		and game.get("opening_subtitle").text == "Lần sau viết SOS nhé.",
		"Esc closes the letter and shows Hoang's exact SOS remark")
	_press_key(KEY_E)
	for i in 4:
		_press_key(KEY_E)
	_press_key(KEY_E)
	await create_timer(.8).timeout
	game.call("_process_opening_sequence", 1.0)
	game.call("_process_opening_sequence", .6)
	game.call("_process_opening_sequence", 1.2)
	game.call("_process_opening_sequence", 3.0)
	await create_timer(1.05).timeout
	_check(str(game.get("opening_phase")) == "classroom_establish", "Scene 01 transitions into Scene 02")
	game.call("_process_opening_sequence", 3.0)
	_check(game.classroom_visual.get("actor").get("controls_enabled") == false,
		"classroom player controls remain disabled during the cinematic")
	# This suite focuses on physical controls and chapter traversal; the dialogue
	# contract is covered by test_opening_cinematic.gd. Complete its authorized
	# handoff through the production callback rather than simulating stale beats.
	game.call("_complete_classroom_black_thought")
	await process_frame
	_check(game.beat == game.Beat.HALLWAY and str(state.scene_id) == "scene_02"
		and str(state.checkpoint_id) == "afternoon_exit",
		"classroom completion opens the after-school exit checkpoint")
	_check(_camera_is_first_person(actor) and actor.controls_enabled,
		"gameplay returns to first-person controls at the afternoon exit")

	actor.teleport_to(Vector3(0, 0, -12.45))
	_check(bool(hall.call("near_restroom_door")), "the after-school exit is reachable")
	game.call("_interact")
	_check(bool(hall.get("restroom_door_open")) and bool(game.get("exit_transition_pending")),
		"E opens the after-school exit")
	actor.teleport_to(Vector3(0, 0, -13.8))
	game.call("_process", .01)
	await create_timer(.9).timeout
	var night_school: Node = game.get("night_school_visual")
	var night_actor := night_school.get("actor") as CharacterBody3D
	_check(game.beat == game.Beat.NIGHT_SCHOOL and str(game.get("night_phase")) == "yard"
		and str(state.checkpoint_id) == "night_school_yard",
		"crossing the exit transitions into the night-school yard")

	night_actor.teleport_to(Vector3(0, 0, -7.4))
	game.call("_interact")
	_check(str(game.get("night_phase")) == "ground_hall", "E enters the school from the yard")
	night_actor.teleport_to(Vector3(-7, 0, -11.5))
	game.call("_interact")
	_check(str(game.get("night_phase")) == "stairs", "E enters the stairwell")
	night_actor.teleport_to(Vector3(-7, 4.6, -24.3))
	game.call("_process_night_school", .01)
	night_school.call("_process", .01)
	_check(str(game.get("night_phase")) == "upper_hall", "reaching floor three unlocks the upper corridor")
	night_actor.teleport_to(Vector3(5, 4.8, -26))
	_check(bool(night_school.call("near_restroom_door")), "the restroom door is reachable at the end of the corridor")
	game.call("_interact")
	_check(str(game.get("night_phase")) == "entering_restroom", "E opens the third-floor restroom door")
	night_actor.teleport_to(Vector3(5, 4.8, -28.3))
	game.call("_process_night_school", .01)
	_check(str(night_school.get("story_zone")) == "restroom"
		and str(game.get("night_phase")) == "friend_bao_line",
		"crossing the restroom threshold enters the restroom sequence")
	_check(str(state.checkpoint_id) == "restroom_approach" and str(state.story_time) == "23:00",
		"restroom entry checkpoints the 23:00 route")

	game.call("_interact")
	game.call("_interact")
	game.call("_interact")
	game.call("_process_night_school", .5)
	_check(str(game.get("night_phase")) == "warning_line", "the restroom threat warning is staged")
	game.call("_interact")
	_check(str(game.get("night_phase")) == "find_stall", "the warning releases player control to find a stall")
	night_actor.teleport_to(Vector3(2.9, 4.8, -29.8))
	_check(bool(night_school.call("near_stall_door")), "the restroom has a nearby hide-stall interaction")
	game.call("_interact")
	_check(bool(night_school.get("stall_open")), "E opens the restroom hide stall")
	await physics_frame
	var stall_blocker := night_school.get("stall_door_blocker") as CollisionShape3D
	_check(stall_blocker != null and stall_blocker.disabled,
		"opening the stall removes its physical obstruction")
	night_actor.teleport_to(Vector3(3.7, 4.8, -32.8))
	game.call("_interact")
	_check(bool(night_school.get("player_hidden"))
		and str(game.get("night_phase")) == "gang_arrival",
		"E inside the stall starts the night-school hiding event")
	_finish()


func _hallway_is_narrow_and_enclosed(hall: Node) -> bool:
	var world: Node3D = hall.get("world") as Node3D
	if world == null:
		return false
	var floor := world.get_node_or_null("FloorSlab") as MeshInstance3D
	if floor == null or not floor.mesh is BoxMesh:
		return false
	var width := (floor.mesh as BoxMesh).size.x
	var left_enclosure := world.get_node_or_null("ExteriorWallCollision") as StaticBody3D
	if left_enclosure == null:
		left_enclosure = world.get_node_or_null("ExteriorParapet_Collision") as StaticBody3D
	if left_enclosure == null:
		return false
	var collision := left_enclosure.get_child(0) as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D:
		return false
	var wall_height := (collision.shape as BoxShape3D).size.y
	return width <= 5.0 and wall_height >= 2.7


func _hallway_has_warm_evening_lighting(hall: Node) -> bool:
	var world: Node3D = hall.get("world") as Node3D
	if world == null:
		return false
	var world_env := _find_world_environment(world)
	if world_env == null or world_env.environment == null:
		return false
	var env := world_env.environment
	var sunset := world.get_node_or_null("LateSunset") as DirectionalLight3D
	return env.ambient_light_energy > 0.24 and sunset != null \
		and sunset.light_color.r > sunset.light_color.g \
		and sunset.light_energy > 0.0


func _camera_is_first_person(actor: CharacterBody3D) -> bool:
	var pivot := actor.get_node_or_null("CameraPivot") as Node3D
	var spring_arm := actor.get_node_or_null("CameraPivot/CameraSpringArm") as SpringArm3D
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/GameplayCamera") as Camera3D
	if pivot == null or spring_arm == null or camera == null:
		return false
	var at_eye_position := camera.global_position.distance_to(actor.global_position + Vector3.UP * 1.42) <= 0.12
	return at_eye_position and is_zero_approx(spring_arm.spring_length) and is_equal_approx(pivot.position.y, 1.42)



func hallway_external_camera_is_active(game_node: Node) -> bool:
	var hall: Node = game_node.get("hallway_visual")
	var cinematic := hall.get("cinematic_camera") as Camera3D
	var actor := hall.get("actor") as CharacterBody3D
	return cinematic != null and cinematic.current and actor != null and not actor.camera.current


func _count_red_reveal_labels(hall: Node) -> int:
	var world: Node3D = hall.get("world") as Node3D
	if world == null:
		return 0
	var found := 0
	for child in world.get_children():
		if child is Label3D and (child as Label3D).text.strip_edges().to_upper() == "CỨU TÔI":
			found += 1
	return found


func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found != null:
			return found
	return null


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _is_blood_red(color: Color) -> bool:
	return color.r >= 0.45 and color.g <= 0.12 and color.b <= 0.12


func _drive(action: StringName, seconds: float, running: bool) -> void:
	if running:
		Input.action_press("run")
	Input.action_press(action)
	var frames := ceili(seconds * 60.0)
	for i in frames:
		await physics_frame
	Input.action_release(action)
	Input.action_release("run")
	await physics_frame


func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)


func _finish() -> void:
	if failures == 0:
		print("REAL_3D_PLAYABLE_PASS checks=%d" % checks)
		quit()
	else:
		push_error("REAL_3D_PLAYABLE_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)
