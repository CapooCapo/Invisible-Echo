extends SceneTree

## Scene 09's code puzzle must be reached through physical third-person play.
const MAIN_SCENE := "res://scenes/09_phong_tin_hoc.tscn"
var checks := 0
var failures := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	state.evidence.clear()
	state.flags.clear()
	state.choices.clear()
	state.scene_id = "scene_09"
	state.checkpoint_id = "computer_room"
	level = load(MAIN_SCENE).instantiate()
	if level == null:
		push_error("Computer lab scene failed to instantiate.")
		quit(1)
		return
	root.add_child(level)
	current_scene = level
	await physics_frame
	await process_frame

	var lab: Node = level.lab_visual
	_check(lab != null, "scene 09 contains a navigable 3D laboratory")
	if lab == null:
		_finish()
		return
	var actor := lab.get("actor") as CharacterBody3D
	_check(actor != null, "Hoang is a physical CharacterBody3D in the lab")
	if actor == null:
		_finish()
		return
	_check(actor.get_node_or_null("HoangCollision") is CollisionShape3D,
		"Hoang has a capsule collision body")
	_check(actor.get_node_or_null("CameraPivot/CameraSpringArm") is SpringArm3D,
		"the lab camera uses a collision-aware spring arm")
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/OverShoulderCamera") as Camera3D
	_check(camera != null and camera.current, "the over-shoulder camera is active")
	_check(bool(actor.get("controls_enabled")), "movement starts enabled at the lab entrance")
	_check(not bool(lab.call("near_main_computer")), "spawn is outside main CRT reach")

	# Neither the keyboard shortcut nor E from the doorway may bypass the CRT.
	_press(KEY_E)
	_check(not bool(level.get("computer_engaged")), "E at spawn cannot open the terminal")
	for keycode in [KEY_1, KEY_8, KEY_0, KEY_4]:
		_press(keycode)
	_press(KEY_ENTER)
	_check(level.beat == level.Beat.COMPUTER and level.code_input.is_empty(),
		"1804 entered away from the CRT is ignored")
	_check(state.checkpoint_id == "computer_room" and not state.evidence.has("computer_access"),
		"bypassing the terminal cannot change checkpoint or evidence")

	# Traverse the central aisle, then approach the CRT from its walkable side.
	var spawn: Vector3 = actor.global_position
	await _drive("move_up", 0.52)
	_check(actor.global_position.z < spawn.z - 1.0,
		"W moves Hoang physically along the lab aisle")
	await _drive("move_right", 0.50)
	_check(actor.global_position.x > spawn.x + 0.45,
		"D moves Hoang toward the main CRT")
	_check(actor.global_position.x < 1.35,
		"the desk collider prevents crossing into the main CRT furniture")
	_check(bool(lab.call("near_main_computer")),
		"the main CRT becomes interactable after a physical approach")

	_press(KEY_E)
	_check(bool(level.get("computer_engaged")), "E at the CRT opens the terminal")
	_check(level.beat == level.Beat.COMPUTER and state.checkpoint_id == "computer_room",
		"opening the CRT does not skip the access puzzle")
	for keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		_press(keycode)
	_press(KEY_ENTER)
	_check(level.beat == level.Beat.COMPUTER and level.code_input.is_empty(),
		"a wrong code is rejected without granting access")
	_check(not state.evidence.has("computer_access"),
		"a wrong code does not create the access clue")
	for keycode in [KEY_1, KEY_8, KEY_0, KEY_4]:
		_press(keycode)
	_press(KEY_ENTER)
	_check(level.beat == level.Beat.CAMERA, "1804 advances to camera recovery")
	_check(state.evidence.get("computer_access") == "1804",
		"the successful code is recorded as evidence")
	_check(state.scene_id == "scene_09" and state.checkpoint_id == "camera_recovery",
		"the camera-recovery checkpoint is preserved")
	_check(state.inventory.is_empty(), "access alone does not grant later keepsakes")
	_finish()


func _drive(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for i in ceili(seconds * 60.0):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	level._unhandled_input(event)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)


func _finish() -> void:
	if failures == 0:
		print("LAB_3D_PLAYABLE_PASS checks=%d" % checks)
		quit()
	else:
		push_error("LAB_3D_PLAYABLE_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)
