extends SceneTree

var checks := 0
var failures := 0
var level: Node
var state: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	state.evidence.clear()
	state.flags.clear()
	state.choices.clear()
	state.scene_id = "scene_09"
	state.checkpoint_id = "computer_room"
	level = load("res://scenes/09_phong_tin_hoc.tscn").instantiate()
	if level == null or level.get_script() == null:
		push_error("Digital mystery scene failed to load its script.")
		quit(1)
		return
	root.add_child(level)
	current_scene = level
	await process_frame
	_check(level.beat == level.Beat.COMPUTER, "scene 09 starts at the locked computer")
	for keycode in [KEY_1, KEY_2, KEY_3, KEY_4]: _press(keycode)
	_press(KEY_ENTER)
	_check(level.beat == level.Beat.COMPUTER, "wrong access code is rejected")
	for keycode in [KEY_1, KEY_8, KEY_0, KEY_4]: _press(keycode)
	_press(KEY_ENTER)
	_check(level.beat == level.Beat.CAMERA, "1804 opens camera recovery")
	_check(state.evidence.get("computer_access") == "1804", "access clue is recorded")
	for target in range(3):
		while level.camera_clips[target] != target:
			var source: int = level.camera_clips.find(target)
			_select_camera(target)
			_press(KEY_E)
			_select_camera(source)
			_press(KEY_E)
	_check(level.camera_solved, "camera clip order puzzle accepts correct timeline")
	_press(KEY_E)
	_check(state.inventory.has("mother_photo") and level.camera_photo_collected, "camera reward grants keepsake four once")
	_press(KEY_E)
	_check(level.beat == level.Beat.POST, "photo reward advances to anonymous post investigation")
	_press(KEY_E)
	_press(KEY_E)
	_press(KEY_E)
	_check(level.post_step == 3, "three post/message evidence panels can be inspected")
	_press(KEY_B)
	_check(state.choices.get("minh_post") == "verify_warn", "choice B is recorded")
	_check(state.inventory.has("minh_thanks"), "choice grants Minh's thank-you keepsake once")
	_press(KEY_A)
	_check(state.choices.get("minh_post") == "verify_warn", "recorded branch choice is immutable")
	_press(KEY_E)
	_check(level.beat == level.Beat.DEDUCTION, "choice unlocks evidence board")
	_link(0, 1)
	_check(level.linked_pairs.is_empty(), "unsupported evidence pair does not count")
	_link(0, 2)
	_link(1, 3)
	_link(4, 5)
	_check(level.linked_pairs.size() == 3, "three supported conclusions unlock deduction")
	_press(KEY_E)
	_check(state.inventory.has("chess_club_sketch"), "deduction grants final keepsake once")
	_check(state.inventory.size() == 3, "digital chapter grants exactly three unique keepsakes")
	if failures == 0:
		print("DIGITAL_MYSTERY_PASS checks=%d" % checks)
		quit()
	else:
		push_error("DIGITAL_MYSTERY_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	level._unhandled_input(event)

func _select_camera(target: int) -> void:
	while level.camera_selection != target:
		_press(KEY_RIGHT)

func _select_evidence(target: int) -> void:
	while level.selected_evidence != target:
		_press(KEY_RIGHT)

func _link(first: int, second: int) -> void:
	_select_evidence(first)
	_press(KEY_E)
	_select_evidence(second)
	_press(KEY_E)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
