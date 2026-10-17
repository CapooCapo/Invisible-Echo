extends CharacterBody3D
class_name HoangController3D

## The collision body, not a screen-space coordinate, owns Hoang's position.
const WALK_SPEED := 3.35
const RUN_SPEED := 5.7
const GRAVITY := 18.0
const MOUSE_SENSITIVITY := 0.0025
const THIRD_PERSON_DISTANCE := 3.0
# Approximate knee-height limit for grounded step-up assistance. This is not
# derived from a skeletal knee bone; it is deliberately conservative for the
# 1.55 m collision capsule and never makes taller geometry traversable.
const MAX_STEP_RISE := 0.42
const STEP_CLEARANCE_INCREMENT := 0.04
const STEP_RISE_CLEARANCE := 0.003
const STEP_SUPPORT_EXTRA := 0.05
const MAX_STEP_LANDING_DROP := 0.06
const STEP_SUPPORT_SAMPLE_SPACING := 0.01
const STEP_SUPPORT_LEAD_RADIUS := 0.23
const STEP_SAFE_LANDING_OFFSET := STEP_SUPPORT_LEAD_RADIUS * 2.0 + 0.06
const HOANG: PackedScene = preload("res://assets/characters/hoang/hoang.glb")

var controls_enabled := false
var hidden := false
var interaction_time_remaining := 0.0
var camera_yaw := 0.0
var camera_pitch := -0.13
var model: Node3D
var animation_player: AnimationPlayer
var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var flashlight: SpotLight3D
var audio_listener: AudioListener3D
var interaction_animation_name := "Interact"
var idle_animation_override := ""


func _ready() -> void:
	name = "HoangPlayer"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.55
	var collision := CollisionShape3D.new()
	collision.name = "HoangCollision"
	collision.position.y = 0.775
	collision.shape = capsule
	add_child(collision)
	model = HOANG.instantiate() as Node3D
	model.name = "HoangVisual"
	model.rotation.y = PI
	model.scale = Vector3.ONE * 0.9
	add_child(model)
	# The game is first-person during gameplay. Cinematic/examine shots opt in
	# to the visible character through set_third_person(true).
	model.visible = false
	animation_player = _find_animation_player(model)
	_configure_animation_loops()
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0, 1.42, 0)
	add_child(pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraSpringArm"
	spring_arm.spring_length = 0.0
	spring_arm.collision_mask = 1
	pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.fov = 76.0
	camera.near = 0.08
	camera.far = 50.0
	camera.current = true
	spring_arm.add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color("#d8e7e5")
	flashlight.light_energy = 2.0
	flashlight.spot_range = 12.0
	flashlight.spot_angle = 31.0
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.32, -0.28, -0.2)
	flashlight.visible = false
	camera.add_child(flashlight)
	audio_listener = AudioListener3D.new()
	audio_listener.name = "GameplayAudioListener"
	camera.add_child(audio_listener)
	audio_listener.make_current()
	_apply_camera_rotation()
	_play_animation("Idle")


func _physics_process(delta: float) -> void:
	var grounded_at_tick_start := is_on_floor()
	var performing_interaction := interaction_time_remaining > 0.0
	interaction_time_remaining = maxf(interaction_time_remaining - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var direction := Vector3.ZERO
	if controls_enabled and not hidden and not performing_interaction:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		direction = Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera_yaw).normalized()
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if grounded_at_tick_start and direction.length_squared() > 0.01:
		if _try_grounded_step(Vector3(velocity.x, 0.0, velocity.z) * delta):
			# The clearance margin lifts just above the tread. A small downward
			# velocity lets this same move_and_slide land on it immediately rather
			# than spending several airborne ticks between connected stair treads.
			velocity.y = -GRAVITY * delta
	move_and_slide()
	if performing_interaction:
		_play_animation(interaction_animation_name)
	elif direction.length_squared() > 0.01:
		model.rotation.y = PI + atan2(-direction.x, -direction.z)
		_play_animation("Run" if speed == RUN_SPEED else "Walk")
	else:
		_play_animation("Hide" if hidden else (idle_animation_override if not idle_animation_override.is_empty() else "Idle"))


func _try_grounded_step(horizontal_motion: Vector3) -> bool:
	# Step assistance is only for blocked, grounded horizontal movement.
	if horizontal_motion.length_squared() <= 0.000001 or not is_on_floor():
		return false
	var direction := horizontal_motion.normalized()
	var obstruction := KinematicCollision3D.new()
	if not test_move(global_transform, horizontal_motion, obstruction):
		return false
	# A walkable slope is ordinary floor, not an obstacle to step over.
	if obstruction.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		return false
	# For a box edge, the kinematic contact point is the observed top surface.
	# Seed the lift from that measured height instead of accepting the first
	# tiny offset that happens not to collide during a short frame displacement.
	var contact_rise := obstruction.get_position().y - global_position.y + STEP_RISE_CLEARANCE
	if contact_rise > MAX_STEP_RISE:
		return false

	var rise := maxf(STEP_CLEARANCE_INCREMENT, contact_rise)
	while rise <= MAX_STEP_RISE + 0.0001:
		var lift_collision := KinematicCollision3D.new()
		if test_move(global_transform, Vector3.UP * rise, lift_collision):
			# Any overhead obstruction makes every taller candidate impossible.
			return false

		var raised_transform := global_transform.translated(Vector3.UP * rise)
		var across_collision := KinematicCollision3D.new()
		# This is exactly the horizontal displacement move_and_slide is about to
		# commit, not a longer hypothetical traversal beyond the user's input.
		if test_move(raised_transform, horizontal_motion, across_collision):
			if rise >= MAX_STEP_RISE:
				return false
			rise = minf(rise + STEP_CLEARANCE_INCREMENT, MAX_STEP_RISE)
			continue

		# Check walkable support along the whole committed segment at 1 cm
		# intervals. A support hit only at a point beyond this segment could let
		# the step assist bridge a gap or carry Hoang off an edge.
		var sample_count := maxi(1, ceili(horizontal_motion.length() / STEP_SUPPORT_SAMPLE_SPACING))
		var highest_support_rise := 0.0
		var unsupported_segment := false
		var space_state := get_world_3d().direct_space_state
		for sample_index in range(sample_count + 1):
			var fraction := float(sample_index) / float(sample_count)
			var segment_position := global_position + horizontal_motion * fraction
			# Check both beneath the capsule center and its leading footprint. The
			# latter prevents assistance from lifting Hoang over a low barrier at
			# the lip of a drop while his body center is still on the near floor.
			var support_offsets: Array[Vector3] = [Vector3.ZERO, direction * STEP_SUPPORT_LEAD_RADIUS]
			for support_offset in support_offsets:
				var sample_position := segment_position + support_offset
				var ray_start := sample_position + Vector3.UP * (MAX_STEP_RISE + STEP_SUPPORT_EXTRA)
				var ray_end := sample_position - Vector3.UP * (MAX_STEP_LANDING_DROP + 0.01)
				var support_query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_mask, [get_rid()])
				var support_hit := space_state.intersect_ray(support_query)
				if support_hit.is_empty():
					unsupported_segment = true
					break
				var support_normal: Vector3 = support_hit["normal"]
				if support_normal.dot(Vector3.UP) < cos(floor_max_angle):
					unsupported_segment = true
					break
				var support_point: Vector3 = support_hit["position"]
				var support_rise := support_point.y - global_position.y
				if support_rise < -MAX_STEP_LANDING_DROP or support_rise > MAX_STEP_RISE:
					unsupported_segment = true
					break
				highest_support_rise = maxf(highest_support_rise, support_rise)
			if unsupported_segment:
				break

		if unsupported_segment:
			return false
		# A supported segment alone is insufficient at a lip: it may be supported
		# only by the narrow blocker itself before dropping into a gap. Also prove
		# a continuous walkable route from the blocker face to a capsule-sized
		# landing footprint beyond it. This is a safety query only; it is not
		# extra movement, and the committed displacement remains horizontal_motion.
		var landing_support := _query_safe_step_landing(obstruction.get_position(), direction)
		if not landing_support["supported"]:
			return false
		# If the supporting surface itself rises higher than this clearance
		# candidate, repeat every collision/support probe at that actual elevation.
		if highest_support_rise > rise + 0.001:
			rise = highest_support_rise
			continue

		# Apply only the rise that was collision-tested; the normal move_and_slide
		# below commits the same horizontal segment that was tested above.
		global_position.y += maxf(rise, highest_support_rise)
		return true
	return false


func _query_step_support(point: Vector3, reference_y: float, allowed_drop: float) -> Dictionary:
	# Cast from the previous supported surface, not the actor's original height.
	# The remote landing corridor can therefore cross a sequence of individually
	# knee-bounded stair risers without treating their cumulative climb as one step.
	var ray_start := Vector3(point.x, reference_y + MAX_STEP_RISE + STEP_SUPPORT_EXTRA, point.z)
	var ray_end := Vector3(point.x, reference_y - allowed_drop - 0.01, point.z)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"supported": false, "height": reference_y}
	var normal: Vector3 = hit["normal"]
	if normal.dot(Vector3.UP) < cos(floor_max_angle):
		return {"supported": false, "height": reference_y}
	var hit_point: Vector3 = hit["position"]
	var support_delta := hit_point.y - reference_y
	if support_delta < -allowed_drop - 0.001 or support_delta > MAX_STEP_RISE + 0.001:
		return {"supported": false, "height": reference_y}
	return {"supported": true, "height": hit_point.y}


func _query_safe_step_landing(obstruction_point: Vector3, direction: Vector3) -> Dictionary:
	var contact := Vector3(obstruction_point.x, global_position.y, obstruction_point.z)
	var side_direction := Vector3(-direction.z, 0.0, direction.x)
	var landing_center := contact + direction * STEP_SAFE_LANDING_OFFSET
	var path_samples := maxi(1, ceili(STEP_SAFE_LANDING_OFFSET / STEP_SUPPORT_SAMPLE_SPACING))
	var previous_support_y := global_position.y
	# Sample continuously beyond the contact face so a guard lip followed by a
	# gap cannot count as a landing merely because the guard top is walkable.
	# Each adjacent support sample may differ by at most one knee-bounded riser;
	# the path's cumulative elevation never contributes to this frame's lift.
	for sample_index in range(path_samples + 1):
		var fraction := float(sample_index) / float(path_samples)
		var path_point := contact.lerp(landing_center, fraction)
		var path_support := _query_step_support(path_point, previous_support_y, MAX_STEP_RISE)
		if not path_support["supported"]:
			return {"supported": false}
		previous_support_y = float(path_support["height"])

	# Verify the full forward/back/side footprint at the safe landing center.
	# This prevents a narrow same-collider guard top from serving as the only
	# nominal support for the character capsule. Heights are checked against the
	# last path support, independently of the actor's current elevation.
	var footprint_offsets: Array[Vector3] = [
		Vector3.ZERO,
		direction * STEP_SUPPORT_LEAD_RADIUS,
		-direction * STEP_SUPPORT_LEAD_RADIUS,
		side_direction * STEP_SUPPORT_LEAD_RADIUS,
		-side_direction * STEP_SUPPORT_LEAD_RADIUS,
	]
	var footprint_min_y := INF
	var footprint_max_y := -INF
	for footprint_offset in footprint_offsets:
		var footprint_support := _query_step_support(landing_center + footprint_offset, previous_support_y, MAX_STEP_RISE)
		if not footprint_support["supported"]:
			return {"supported": false}
		var support_y := float(footprint_support["height"])
		footprint_min_y = minf(footprint_min_y, support_y)
		footprint_max_y = maxf(footprint_max_y, support_y)
	# A footprint spanning surfaces more than one individual knee-height apart is
	# too steep/discontinuous to count as a safe landing, even if each ray alone
	# is within range of the landing-center reference.
	if footprint_max_y - footprint_min_y > MAX_STEP_RISE + 0.001:
		return {"supported": false}
	return {"supported": true}


func play_interaction(duration: float = 0.65) -> void:
	interaction_time_remaining = maxf(duration, 0.01)
	interaction_animation_name = "Interact"
	velocity.x = 0.0
	velocity.z = 0.0
	_play_animation("Interact")


func play_pickup() -> void:
	interaction_time_remaining = 0.9
	interaction_animation_name = "Pick_Up"
	velocity.x = 0.0
	velocity.z = 0.0
	_play_animation("Pick_Up")


func play_look_behind() -> void:
	_play_animation("Look_Behind")
	var target_yaw := camera_yaw + 0.55
	var turn := create_tween()
	turn.tween_property(self, "camera_yaw", target_yaw, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_callback(_apply_camera_rotation)


func set_third_person(enabled: bool) -> void:
	if model != null:
		model.visible = enabled
	if spring_arm != null:
		spring_arm.spring_length = THIRD_PERSON_DISTANCE if enabled else 0.0
	if camera != null:
		camera.current = true
	if pivot != null:
		pivot.position = Vector3(0, 1.42, 0)


func set_idle_pose(animation_name: String) -> void:
	idle_animation_override = animation_name
	_play_animation(animation_name)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled


func play_letter_reveal() -> void:
	# Legacy compatibility hook: preserve the current camera mode without a reveal effect.
	if model != null:
		model.visible = spring_arm != null and spring_arm.spring_length > 0.0


func restore_letter_reveal() -> void:
	# Restored checkpoints return to the normal first-person gameplay view.
	set_third_person(false)


func is_interacting() -> bool:
	return interaction_time_remaining > 0.0


func orbit_mouse(relative: Vector2) -> void:
	camera_yaw -= relative.x * MOUSE_SENSITIVITY
	camera_pitch = clampf(camera_pitch - relative.y * MOUSE_SENSITIVITY, -0.75, 0.35)
	_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	if pivot != null:
		pivot.rotation.y = camera_yaw
	if spring_arm != null:
		spring_arm.rotation.x = camera_pitch


func set_flashlight_on(on: bool) -> void:
	if flashlight != null:
		flashlight.visible = on


func toggle_flashlight() -> void:
	if flashlight != null:
		flashlight.visible = not flashlight.visible


func teleport_to(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _configure_animation_loops() -> void:
	if animation_player == null:
		return
	# Imported GLB clips are one-shot. Repeating locomotion must loop even when
	# the state does not change; Hide deliberately holds its final pose.
	for candidate in animation_player.get_animation_list():
		var clip_name := candidate.get_slice("/", candidate.get_slice_count("/") - 1)
		if clip_name in ["Idle", "Walk", "Run"]:
			animation_player.get_animation(candidate).loop_mode = Animation.LOOP_LINEAR


func _play_animation(animation_name: String) -> void:
	if animation_player == null:
		return
	for candidate in animation_player.get_animation_list():
		if candidate == animation_name or candidate.ends_with("/" + animation_name):
			if animation_player.current_animation != candidate:
				animation_player.play(candidate)
			return
