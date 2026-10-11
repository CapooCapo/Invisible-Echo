extends SceneTree

var checks := 0
var failures := 0
var school: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.persistence_enabled = false
	game_state.inventory.clear()
	game_state.evidence.clear()
	game_state.flags.clear()
	game_state.scene_id = "scene_05"
	game_state.checkpoint_id = "notice_board"
	school = load("res://scenes/05_bang_tin.tscn").instantiate()
	if school == null or school.get_script() == null:
		push_error("School chapter scene failed to load its script.")
		quit(1)
		return
	root.add_child(school)
	await process_frame
	_check(school.beat == school.Beat.BOARD, "scene 05 starts on the notice board")
	school.player = Vector2(790, 218)
	_press_key(KEY_E)
	_check(school.board_step == 1, "first board inspection reveals the defaced photo")
	_press_key(KEY_E)
	_check(school.identity_known, "photo reverse reveals An's identity")
	_press_key(KEY_E)
	_check(school.locker_clue and school.beat == school.Beat.DIARY, "18/04 clue unlocks A-17 diary")

	for index in range(6):
		while school.fragments[index] != index:
			var source: int = school.fragments.find(index)
			_select_diary_slot(index)
			_press_key(KEY_E)
			_select_diary_slot(source)
			_press_key(KEY_E)
	_check(school.diary_solved, "six-piece diary accepts correct dated order")
	_check(not school.math_test_collected, "diary solve alone does not duplicate/grant the reward")
	_press_key(KEY_E)
	_check(school.math_test_collected and game_state.inventory.has("math_test"), "diary completion grants the 100-point keepsake once")
	_press_key(KEY_E)
	_check(school.beat == school.Beat.CIRCUIT, "keepsake claim unlocks electrical room")
	_check(not school._circuit_connected(), "scrambled circuit is initially disconnected")
	_press_key(KEY_R)
	_check(not school._circuit_connected(), "circuit reset restores disconnected puzzle")
	for index in range(16):
		var turns: int = posmod(-school.circuit_scramble[index], 4)
		for _turn in range(turns):
			_select_circuit_tile(index)
			_press_key(KEY_E)
	_check(school.circuit_solved, "4x4 circuit BFS accepts a connected source-to-lock route")
	_press_key(KEY_E)
	_check(school.chess_medal_collected and game_state.inventory.has("chess_medal"), "circuit success grants the chess medal once")
	_press_key(KEY_E)
	_check(school.beat == school.Beat.PATROL, "medal claim unlocks patrol scene")

	school.player = school.guard_position + Vector2(-25, 0)
	school.guard_direction = -1.0
	school.player_hidden = false
	school.guard_state = school.GuardState.PATROL
	school.suspicion = 0.0
	school._update_guard(0.05)
	_check(school.guard_state == school.GuardState.SUSPICIOUS, "guard enters suspicion when player is inside detection range")
	school._update_guard(1.0)
	_check(school.guard_state == school.GuardState.CHASE, "suspicion escalates into chase")
	school.guard_position = Vector2(280, 250)
	school.player = Vector2(500, 250)
	school.guard_state = school.GuardState.CHASE
	school._update_guard(0.01)
	_check(school.guard_state == school.GuardState.SEARCH, "occluder breaks active chase line of sight")
	school._update_guard(2.0)
	_check(school.guard_state == school.GuardState.PATROL, "search timer returns guard to patrol")
	school.player = school.HIDE_ZONE.get_center()
	school.player_hidden = true
	school.guard_state = school.GuardState.PATROL
	school.suspicion = 0.0
	school._update_guard(0.3)
	_check(school.guard_state == school.GuardState.PATROL and is_zero_approx(school.suspicion), "hiding blocks suspicion gain")
	_check(not school._has_clear_sight(Vector2(280, 250), Vector2(500, 250)), "cabinet occludes guard sight")
	_check(school._has_clear_sight(Vector2(500, 170), Vector2(500, 250)), "clear corridor permits guard sight")
	_press_key(KEY_F)
	_check(school.distraction_timer > 0.0, "F triggers a timed sound distraction without hijacking movement")
	game_state.evidence["locker_clue"] = "A-17"
	game_state.scene_id = "scene_06"
	game_state.checkpoint_id = "diary_reward"
	school._restore_checkpoint()
	_check(school.locker_clue and school.beat == school.Beat.DIARY and school.diary_solved, "saved A-17 clue reloads as a valid diary checkpoint")
	var restored_diary = load("res://scenes/05_bang_tin.tscn").instantiate()
	root.add_child(restored_diary)
	await process_frame
	_check(restored_diary.locker_clue and restored_diary.diary_solved and restored_diary.fragments == school.fragments, "fresh scene instance restores the saved diary state without type errors")
	restored_diary.queue_free()
	school.beat = school.Beat.PATROL
	game_state.scene_id = "scene_08"

	school.player = school.BOX_ZONE.get_center()
	school.guard_state = school.GuardState.PATROL
	_press_key(KEY_E)
	_check(school.keychain_collected and game_state.inventory.has("knight_keychain") and school.beat == school.Beat.CHASE, "box interaction grants the knight keychain and starts chase")
	school.chase_lane = 0
	school.chase_progress = 0.0
	school.chase_checkpoint = 0.0
	for obstacle in school.chase_obstacles: obstacle.passed = false
	Input.action_press("move_right")
	school._update_chase(0.5)
	Input.action_release("move_right")
	_check(school.chase_attempts == 1 and school.chase_progress == 0.0, "wrong chase lane resets to safe checkpoint")
	for obstacle in school.chase_obstacles: obstacle.passed = false
	school.chase_progress = 0.0
	school.chase_checkpoint = 0.0
	var safe_lanes: Array[int] = [1, 0, 1, 0]
	var thresholds: Array[float] = [18.0, 36.0, 54.0, 73.0]
	Input.action_press("move_right")
	for obstacle_index in range(4):
		var lane_action := "move_up" if safe_lanes[obstacle_index] == 0 else "move_down"
		Input.action_press(lane_action)
		school._update_chase(0.01)
		Input.action_release(lane_action)
		while school.chase_progress < thresholds[obstacle_index]:
			school._update_chase(0.01)
	while school.chase_progress < 100.0:
		school._update_chase(0.01)
	Input.action_release("move_right")
	_check(school.beat == school.Beat.DONE, "correct lane changes complete the chase")
	_press_key(KEY_E)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "DigitalMystery", "successful chase enters scene 09")

	if failures == 0:
		print("SCHOOL_CHAPTER_PASS checks=%d" % checks)
		quit()
	else:
		push_error("SCHOOL_CHAPTER_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _press_key(keycode: Key) -> void:
	school._unhandled_input(_key(keycode))

func _select_diary_slot(target: int) -> void:
	while school.selected_fragment != target:
		_press_key(KEY_RIGHT)

func _select_circuit_tile(target: int) -> void:
	var target_position := Vector2i(target % 4, target / 4)
	while school.selected_tile != target_position:
		_press_key(KEY_RIGHT)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
