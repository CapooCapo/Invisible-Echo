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
	_check(_hallway_starts_dark(hall),
		"hallway starts in a dark, low-ambient-light state")
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
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/OverShoulderCamera") as Camera3D
	_check(camera != null and camera.current, "over-shoulder Camera3D is active")
	var light := actor.get_node_or_null("CameraPivot/CameraSpringArm/OverShoulderCamera/Flashlight") as SpotLight3D
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
		"captured mouse motion orbits the shoulder camera")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	actor.set("camera_yaw", 0.0)
	actor.call("_apply_camera_rotation")

	# The classroom wall must stop motion; then restore a safe start for the
	# unwarped narrative route below.
	await _drive("move_right", 0.9, true)
	_check(actor.position.x < 3.0 and actor.position.x > 1.0,
		"CharacterBody3D moves and collides with the hallway wall")
	actor.call("teleport_to", Vector3(0, 0, 3.25))
	await physics_frame
	await _drive("move_up", 0.75, false)
	_check(bool(hall.call("near_letter")), "walking reaches the letter in world space")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.LETTER, "letter interaction advances the story")
	_check(_letter_reveal_has_both_red_wall_messages(hall),
		"picking the letter abruptly reveals blood-red CỨU TÔI on both hallway walls")
	_check(_hallway_world_is_blood_red(hall),
		"letter pickup turns the hallway world blood-red")
	_check(await _camera_shakes_during_reveal(actor),
		"letter reveal shakes the first-person camera through projection offsets")
	# The camera snaps into the eye position immediately, but its pivot takes
	# 0.42s to recenter. Assert the stable end state rather than the tween start.
	await create_timer(0.46).timeout
	_check(_camera_is_first_person(actor),
		"letter reveal completes its transition to the first-person camera end state")
	_check(bool(hall.call("is_interacting")) and animation_player.current_animation.ends_with("Interact"),
		"letter E plays the rigged Interact animation")
	_check(not game.panel.visible, "letter panel waits for Hoang's pickup animation")
	await create_timer(0.72).timeout
	_check(game.panel.visible and not bool(hall.call("is_interacting")),
		"letter panel opens after the interaction stage")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.CLASSROOM, "letter closes to the classroom beat")
	_press_key(KEY_E)
	_check(bool(game.classroom_read), "classroom text can be closed before moving")
	Input.action_press("run")
	Input.action_press("move_up")
	for i in 128:
		await physics_frame
	if animation_player != null:
		_check(animation_player.is_playing() and animation_player.current_animation.ends_with("Run"),
			"Run remains animated after more than two seconds of movement")
	Input.action_release("move_up")
	Input.action_release("run")
	await physics_frame
	_check(bool(hall.call("near_restroom_door")), "running reaches the restroom door")
	_check(not bool(hall.get("restroom_door_open")), "restroom door starts closed")
	_press_key(KEY_E)
	_check(bool(hall.get("restroom_door_open")), "E opens the physical restroom door")
	_check(bool(hall.call("is_interacting")) and animation_player.current_animation.ends_with("Interact"),
		"door E plays Interact before traversal")
	await physics_frame
	var door_shape := hall.get_node_or_null("SpatialViewport/SchoolHallway/RestroomDoorCollision/DoorCollisionShape") as CollisionShape3D
	_check(door_shape != null and door_shape.disabled, "opened door disables blocking collision")
	await create_timer(0.7).timeout
	await _drive("move_up", 0.65, true)
	_check(game.beat == game.Beat.TOILET and game.active_room == "restroom",
		"walking through the threshold enters the restroom checkpoint")
	_check(state.scene_id == "scene_03", "restroom checkpoint is recorded")

	var room: Node = game.restroom_visual
	var restroom_actor := room.get("actor") as CharacterBody3D
	_check(restroom_actor != null and restroom_actor.controls_enabled,
		"restroom has an enabled physical player")
	_check(bool(room.call("near_stall_door")), "restroom spawn is near the first stall")
	_press_key(KEY_E)
	_check(bool(room.get("stall_door_open")), "E opens the first stall")
	_check(bool(room.call("is_interacting")), "stall door E starts Interact staging")
	await physics_frame
	var stall_doors: Array = room.get("stall_doors")
	var stall_shape := (stall_doors[0] as StaticBody3D).get_child(0) as CollisionShape3D
	_check(stall_shape != null and stall_shape.disabled, "stall opening removes its physical obstruction")
	await create_timer(0.7).timeout
	await _drive("move_left", 0.34, true)
	_check(bool(room.call("inside_hide_stall")), "movement reaches the actual stall interior")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.TOILET and game.is_hidden,
		"E inside the stall begins a visible hide stage")
	_check(state.scene_id == "scene_04", "mirror checkpoint is recorded")
	_check(bool(state.flags.get("survived_toilet_event", false)), "survival flag is saved at hide entry")
	await physics_frame
	var restroom_animation := restroom_actor.get("animation_player") as AnimationPlayer
	_check(restroom_actor.hidden and room.visible and restroom_animation != null
		and restroom_animation.current_animation.ends_with("Hide"),
		"Hoang remains visible in the restroom while rigged Hide plays")
	var frozen_hide_time: float = game.hide_time
	_press_key(KEY_E)
	_check(game.beat == game.Beat.TOILET and game.is_hidden,
		"repeated E cannot skip hide staging")
	await create_timer(0.75).timeout
	_check(game.beat == game.Beat.TOILET and is_equal_approx(game.hide_time, frozen_hide_time),
		"hide remains staged and the death countdown is frozen")
	await create_timer(0.8).timeout
	_check(game.beat == game.Beat.MIRROR and not game.is_hidden,
		"mirror beat begins automatically after the hide animation stage")

	# Exit the stall, then approach the sink wall via collision-aware movement.
	await _drive("move_right", 0.52, true)
	await _drive("move_up", 1.55, true)
	_check(bool(room.call("near_mirror")), "walking reaches the mirror in world space")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.REFLECTION, "mirror interaction triggers the apparition")
	var ghost := room.get("ghost") as Node3D
	_check(ghost != null and ghost.visible, "An is visible only in the mirror viewport")
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


func _hallway_starts_dark(hall: Node) -> bool:
	var world: Node3D = hall.get("world") as Node3D
	if world == null:
		return false
	var world_env := _find_world_environment(world)
	if world_env == null or world_env.environment == null:
		return false
	var env := world_env.environment
	return env.ambient_light_energy <= 0.24 and _luminance(env.background_color) <= 0.035


func _letter_reveal_has_both_red_wall_messages(hall: Node) -> bool:
	var world: Node3D = hall.get("world") as Node3D
	if world == null:
		return false
	var found := 0
	for child in world.get_children():
		if child is Label3D:
			var label := child as Label3D
			if label.text.strip_edges().to_upper() == "CỨU TÔI" and _is_blood_red(label.modulate):
				found += 1
	return found >= 2


func _hallway_world_is_blood_red(hall: Node) -> bool:
	var world: Node3D = hall.get("world") as Node3D
	if world == null:
		return false
	var world_env := _find_world_environment(world)
	if world_env == null or world_env.environment == null:
		return false
	var env := world_env.environment
	return env.ambient_light_color.r >= env.ambient_light_color.g * 1.8 \
		and env.ambient_light_color.r >= env.ambient_light_color.b * 1.8


func _camera_is_first_person(actor: CharacterBody3D) -> bool:
	var pivot := actor.get_node_or_null("CameraPivot") as Node3D
	var spring_arm := actor.get_node_or_null("CameraPivot/CameraSpringArm") as SpringArm3D
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/OverShoulderCamera") as Camera3D
	if pivot == null or spring_arm == null or camera == null:
		return false
	var at_eye_position := camera.global_position.distance_to(actor.global_position + Vector3.UP * 1.62) <= 0.12
	return at_eye_position and is_zero_approx(spring_arm.spring_length) and is_equal_approx(pivot.position.y, 1.62)


func _camera_shakes_during_reveal(actor: CharacterBody3D) -> bool:
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/OverShoulderCamera") as Camera3D
	if camera == null:
		return false
	var previous := Vector2(camera.h_offset, camera.v_offset)
	var peak_offset := previous.length()
	var largest_step := 0.0
	for i in 12:
		await process_frame
		var offset := Vector2(camera.h_offset, camera.v_offset)
		peak_offset = maxf(peak_offset, offset.length())
		largest_step = maxf(largest_step, offset.distance_to(previous))
		previous = offset
	return peak_offset >= 0.012 and largest_step >= 0.01


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
