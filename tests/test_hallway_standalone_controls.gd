extends SceneTree

## F6 runs the hallway scene by itself, without game.gd. Its own scene must
## install the same movement bindings and enable Hoang's physical controls.
const HALLWAY_SCENE := "res://scenes/visual/hallway_3d.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var error := change_scene_to_file(HALLWAY_SCENE)
	_check(error == OK, "F6 can open the standalone hallway scene")
	if error != OK:
		_finish()
		return
	await process_frame
	await physics_frame
	var hall := current_scene
	_check(hall != null and hall.scene_file_path == HALLWAY_SCENE,
		"F6 makes the hallway the current scene")
	if hall == null:
		_finish()
		return
	var actor := hall.get("actor") as CharacterBody3D
	_check(actor != null, "standalone hallway creates Hoang's physical player")
	if actor == null:
		_finish()
		return

	for binding in [
		["move_up", KEY_W, KEY_UP],
		["move_down", KEY_S, KEY_DOWN],
		["move_left", KEY_A, KEY_LEFT],
		["move_right", KEY_D, KEY_RIGHT],
	]:
		_check(_has_key(binding[0], binding[1]) and _has_key(binding[0], binding[2]),
			"%s supports both WASD and arrow keys in standalone mode" % binding[0])
	_check(_has_key("run", KEY_SHIFT), "Shift is bound to run in standalone mode")
	_check(bool(actor.get("controls_enabled")), "Hoang's controls start enabled in standalone mode")

	var spawn: Vector3 = actor.global_position
	_send_key(KEY_W, true)
	for i in 32:
		await physics_frame
	_send_key(KEY_W, false)
	await physics_frame
	_check(actor.global_position.z < spawn.z - 0.65,
		"W moves Hoang forward in the standalone hallway")
	var before_right: Vector3 = actor.global_position
	_send_key(KEY_D, true)
	for i in 18:
		await physics_frame
	_send_key(KEY_D, false)
	await physics_frame
	_check(actor.global_position.x > before_right.x + 0.35,
		"D moves Hoang right in the standalone hallway")
	var flashlight := actor.get_node_or_null("CameraPivot/CameraSpringArm/GameplayCamera/Flashlight") as SpotLight3D
	_check(flashlight != null and not flashlight.visible, "standalone flashlight starts off")
	_send_key(KEY_F, true)
	await process_frame
	_send_key(KEY_F, false)
	await process_frame
	_check(flashlight != null and flashlight.visible, "F toggles the standalone flashlight")

	# In headless runs Godot cannot capture the pointer, so real mouse-orbit
	# delivery must be checked in a GUI session rather than faked here.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("HALLWAY_STANDALONE_NOTE headless_pointer_capture_unavailable")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.scene_id = "scene_01"
	state.checkpoint_id = "scene_01_start"
	var main_error := change_scene_to_file("res://scenes/01_hanh_lang.tscn")
	_check(main_error == OK, "F5 can open the integrated hallway game")
	if main_error == OK:
		await process_frame
		await physics_frame
		var game := current_scene
		var embedded: Node = game.get("hallway_visual") if game != null else null
		_check(embedded != null and not bool(embedded.get("standalone_mode")),
			"game.gd keeps its embedded hallway out of standalone mode")
	_finish()


func _has_key(action: StringName, code: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.keycode == code or event.physical_keycode == code):
			return true
	return false


func _send_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HALLWAY_STANDALONE_FAIL " + description)


func _finish() -> void:
	print("HALLWAY_STANDALONE %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
