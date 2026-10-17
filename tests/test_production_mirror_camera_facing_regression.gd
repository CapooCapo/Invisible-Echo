extends SceneTree

## Focused camera-facing regression for the production mirror interaction.
## This intentionally teleports Hoang to the real mirror trigger to isolate
## interaction/camera state; it is NOT a navigation or route test.
## Run from the repo root with a display server (captured mouse mode is not
## available under Godot's headless DisplayServer):
## godot --path . --script res://tests/test_production_mirror_camera_facing_regression.gd
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
const REQUIRED_FACING_DOT := 0.90 # within ~26 degrees of the mirror center direction

var game: Node
var night: Node
var actor: CharacterBody3D
var camera: Camera3D
var mirror_surface: MeshInstance3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node_or_null("GameState")
	if state == null:
		_fail("production GameState autoload is missing")
		return
	state.persistence_enabled = false
	state.save_writes_suppressed = true
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	game = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await _wait_frames(3)

	night = game.get("night_school_visual") as Node
	actor = night.get("actor") as CharacterBody3D if night != null else null
	var world := night.get("world") as Node3D if night != null else null
	mirror_surface = world.find_child("Mirror glass", true, false) as MeshInstance3D if world != null else null
	camera = actor.get("camera") as Camera3D if actor != null else null
	if night == null or actor == null or camera == null or mirror_surface == null:
		_fail("production scene missing NightSchool, Hoang, camera, or physical Mirror glass")
		return

	# Isolate the actual gameplay interaction without claiming to test how Hoang
	# navigates to it. The trigger coordinate comes from the production method.
	var trigger := night.call("_map_old_story_point", Vector3(6.0, 4.8, -30.2)) as Vector3
	actor.call("teleport_to", trigger)
	actor.set("camera_yaw", 0.0) # observed production spawn orientation: away from glass
	actor.call("_apply_camera_rotation")
	actor.call("set_controls_enabled", true)
	game.set("night_phase", "mirror_search")
	await _wait_frames(3)
	if not bool(night.call("near_mirror")):
		_fail("teleported production actor is not inside the real mirror interaction radius")
		return

	var before_dot := _mirror_facing_dot()
	print("MIRROR_CAMERA_SETUP trigger=%s actor=%s mirror_surface=%s mirror=%s camera=%s yaw=%.4f forward=%s facing_dot=%.4f navigation_test=false" % [
		trigger, actor.global_position, mirror_surface.get_path(), mirror_surface.global_position,
		camera.global_position, float(actor.get("camera_yaw")), -camera.global_basis.z.normalized(), before_dot
	])

	# Exercise the production input route (Input -> Game._unhandled_input -> _interact).
	await _press_e_and_wait()
	var first_phase := str(game.get("night_phase"))
	var apparition := night.get("apparition") as Node3D
	var apparition_shown := first_phase == "mirror_ghost" and apparition != null and apparition.visible and apparition.is_visible_in_tree()
	var first_dot := _mirror_facing_dot()
	print("MIRROR_CAMERA_FIRST_E phase=%s apparition_shown=%s yaw=%.4f forward=%s facing_dot=%.4f expected_dot>=%.2f" % [
		first_phase, apparition_shown, float(actor.get("camera_yaw")), -camera.global_basis.z.normalized(), first_dot, REQUIRED_FACING_DOT
	])
	if not apparition_shown:
		_fail("real KEY_E did not enter mirror_ghost and show the production apparition")
	if first_dot < REQUIRED_FACING_DOT:
		_fail("first real KEY_E shows the apparition but camera forward is not aimed at the physical Mirror glass")

	# Mouse look remains routed through Game._unhandled_input while the dialogue
	# is visible. Move the captured camera by one radian to ensure turn-back does
	# not merely add PI to an assumed, untouched first-E orientation.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse_capture_active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var yaw_before_mouse := float(actor.get("camera_yaw"))
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(400.0, 0.0) # 400 px * 0.0025 sensitivity = 1 radian
	motion_mouse_through_production_handler(mouse_motion)
	var yaw_after_mouse := float(actor.get("camera_yaw"))
	var dialogue_card := game.get("opening_card") as Control
	var dialogue_visible := dialogue_card != null and dialogue_card.visible
	print("MIRROR_CAMERA_DIALOGUE_MOUSE phase=%s dialogue_visible=%s mouse_capture_active=%s mouse_mode=%s relative=%s yaw_before=%.4f yaw_after=%.4f delta=%.4f" % [
		str(game.get("night_phase")), dialogue_visible, mouse_capture_active, str(Input.mouse_mode),
		mouse_motion.relative, yaw_before_mouse, yaw_after_mouse, yaw_after_mouse - yaw_before_mouse
	])
	if not dialogue_visible:
		_fail("mirror_ghost dialogue is not visible during synthetic mouse-look")
	if not mouse_capture_active:
		_fail("runtime does not support captured mouse mode; cannot exercise production mouse-look branch")
	if absf(yaw_after_mouse - yaw_before_mouse) < 0.90:
		_fail("captured mouse motion through Game._unhandled_input did not rotate the camera by at least 0.90 radians during mirror dialogue")

	# The follow-up production E is the story's "turn back" interaction, now
	# after real camera drift while the apparition dialogue is on screen.
	await _press_e_and_wait()
	var second_phase := str(game.get("night_phase"))
	var away_dot := _mirror_facing_dot()
	print("MIRROR_CAMERA_SECOND_E_AFTER_DIALOGUE_MOUSE phase=%s yaw=%.4f forward=%s facing_dot=%.4f expected_dot<=-%.2f" % [
		second_phase, float(actor.get("camera_yaw")), -camera.global_basis.z.normalized(), away_dot, REQUIRED_FACING_DOT
	])
	if second_phase != "mirror_empty":
		_fail("second real KEY_E did not advance from mirror_ghost to mirror_empty")
	if away_dot > -REQUIRED_FACING_DOT:
		_fail("second real KEY_E after dialogue mouse-look did not orient the camera away from the physical Mirror glass")

	if failures.is_empty():
		print("PRODUCTION_MIRROR_CAMERA_PASS")
	else:
		for failure in failures:
			push_error("PRODUCTION_MIRROR_CAMERA_FAIL " + failure)
		print("PRODUCTION_MIRROR_CAMERA_FAIL_COUNT=%d" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _mirror_facing_dot() -> float:
	var to_glass := (mirror_surface.global_position - camera.global_position).normalized()
	var camera_forward := -camera.global_basis.z.normalized()
	return camera_forward.dot(to_glass)

func _press_e_and_wait() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.physical_keycode = KEY_E
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await physics_frame

func motion_mouse_through_production_handler(event: InputEventMouseMotion) -> void:
	# Call the production unhandled-input entry point directly so this test
	# isolates handler behavior rather than relying on a window system to route
	# synthetic pointer motion in headless mode.
	game.call("_unhandled_input", event)

func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame

func _fail(reason: String) -> void:
	failures.append(reason)
