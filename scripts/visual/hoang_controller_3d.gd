extends CharacterBody3D
class_name HoangController3D

## The collision body, not a screen-space coordinate, owns Hoang's position.
const WALK_SPEED := 3.35
const RUN_SPEED := 5.7
const GRAVITY := 18.0
const MOUSE_SENSITIVITY := 0.0025
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
var reveal_shake_remaining := 0.0
var reveal_shake_elapsed := 0.0


func _ready() -> void:
	name = "HoangPlayer"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.65
	var collision := CollisionShape3D.new()
	collision.name = "HoangCollision"
	collision.position.y = 0.83
	collision.shape = capsule
	add_child(collision)
	model = HOANG.instantiate() as Node3D
	model.name = "HoangVisual"
	model.rotation.y = PI
	add_child(model)
	animation_player = _find_animation_player(model)
	_configure_animation_loops()
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0.2, 1.52, 0)
	add_child(pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraSpringArm"
	spring_arm.spring_length = 2.55
	spring_arm.collision_mask = 1
	pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.name = "OverShoulderCamera"
	camera.fov = 58.0
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
	_apply_camera_rotation()
	_play_animation("Idle")


func _physics_process(delta: float) -> void:
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
	move_and_slide()
	if performing_interaction:
		_play_animation("Interact")
	elif direction.length_squared() > 0.01:
		model.rotation.y = PI + atan2(-direction.x, -direction.z)
		_play_animation("Run" if speed == RUN_SPEED else "Walk")
	else:
		_play_animation("Hide" if hidden else "Idle")


func _process(delta: float) -> void:
	if reveal_shake_remaining <= 0.0:
		if camera != null and reveal_shake_elapsed > 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
		return
	reveal_shake_elapsed += delta
	reveal_shake_remaining = maxf(reveal_shake_remaining - delta, 0.0)
	if camera != null:
		var strength := reveal_shake_remaining / .72
		camera.h_offset = sin(reveal_shake_elapsed * 61.0) * .045 * strength
		camera.v_offset = cos(reveal_shake_elapsed * 47.0) * .035 * strength


func play_interaction(duration: float = 0.65) -> void:
	interaction_time_remaining = maxf(duration, 0.01)
	velocity.x = 0.0
	velocity.z = 0.0
	_play_animation("Interact")


func play_letter_reveal() -> void:
	# First-person framing persists through the hallway's letter/classroom beat;
	# the next physical room owns its own player camera when the story transitions.
	controls_enabled = false
	if model != null:
		model.visible = false
	if camera != null:
		camera.fov = 72.0
	if spring_arm != null and pivot != null:
		# Snap the camera behind the eyes immediately; only the pivot recenters
		# over the short reveal beat so pickup checks and framing agree at once.
		spring_arm.spring_length = 0.0
		if camera != null:
			camera.global_position = global_position + Vector3.UP * 1.52
		var transition := create_tween()
		transition.set_parallel(true)
		transition.tween_property(pivot, "position", Vector3(0, 1.62, 0), .42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	reveal_shake_elapsed = 0.0
	reveal_shake_remaining = .72


func restore_letter_reveal() -> void:
	# Restored checkpoints start in the settled eye view without replaying pickup.
	if model != null:
		model.visible = false
	if camera != null:
		camera.fov = 72.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	if spring_arm != null:
		spring_arm.spring_length = 0.0
	if pivot != null:
		pivot.position = Vector3(0, 1.62, 0)
	reveal_shake_elapsed = 0.0
	reveal_shake_remaining = 0.0


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
