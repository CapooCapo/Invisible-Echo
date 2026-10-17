extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	for item_id in ["math_test", "chess_medal", "knight_keychain", "mother_photo", "minh_thanks", "chess_club_sketch"]:
		state.inventory.append(item_id)
	state.flags.clear()
	state.choices = {"minh_post": "verify_warn"}
	state.scene_id = "scene_12"
	state.checkpoint_id = "return_memories"
	var return_scene = load("res://scenes/12_phong_cau_vua.tscn").instantiate()
	root.add_child(return_scene)
	current_scene = return_scene
	await process_frame
	for index in range(6):
		while return_scene.selected != index:
			_press(return_scene, KEY_RIGHT)
		_press(return_scene, KEY_E)
	_check(return_scene._all_placed(), "all six owned memories can be returned to the board")
	_press(return_scene, KEY_E)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "ChessBoss", "complete return ritual enters chess boss")
	var duel = current_scene
	_check(duel.selecting_mode and duel.selected_mode_index == 0, "chess boss opens the three-mode selector with Story highlighted")
	_press(duel, KEY_1)
	_check(not duel.selecting_mode and duel.mode == duel.Mode.STORY, "Story mode can be selected before the legacy checkmate puzzle")
	duel._activate_square(duel.chess.square_from_name("g6"))
	duel._activate_square(duel.chess.square_from_name("g7"))
	_check(duel.result == duel.Result.WON and state.flags.get("chess_boss_defeated"), "legal Qg7 move defeats the boss by checkmate")
	_press(duel, KEY_E)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "MorningConfrontation", "checkmate advances to branch-specific dawn")
	_press(current_scene, KEY_E)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "Ending", "dawn closes on the ending scene")
	_check(state.ending == "ending_dawn" and state.flags.get("night_2_unlocked"), "truthful resolution plus checkmate unlocks Night 2")
	state.scene_id = "scene_09"
	state.checkpoint_id = "camera_recovery"
	state.evidence["computer_access"] = "1804"
	var boot_scene = load("res://scenes/01_hanh_lang.tscn").instantiate()
	root.add_child(boot_scene)
	current_scene = boot_scene
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "DigitalMystery" and current_scene.beat == current_scene.Beat.CAMERA, "boot router resumes the persisted camera-recovery checkpoint")
	state.choices["minh_post"] = "publish_raw"
	state.flags["chess_boss_defeated"] = false
	var darker_ending = load("res://scenes/15_ending.tscn").instantiate()
	root.add_child(darker_ending)
	current_scene = darker_ending
	await process_frame
	_check(state.ending == "ending_echo" and state.flags.get("night_2_unlocked"), "rumor or unfinished chess produces the second ending and still unlocks Night 2")

	state.scene_id = "scene_13"
	state.checkpoint_id = "chess_challenge"
	var rules_scene = load("res://scenes/13_ban_co_boss.tscn").instantiate()
	root.add_child(rules_scene)
	current_scene = rules_scene
	await process_frame
	_press(rules_scene, KEY_1)
	_press(rules_scene, KEY_X)
	_check(rules_scene.result == rules_scene.Result.RESIGNED and state.flags.get("chess_resigned") and state.checkpoint_id == "chess_resigned", "chess boss supports explicit resignation")
	_press(rules_scene, KEY_R)
	_check(rules_scene.result == rules_scene.Result.PLAYING and rules_scene.mode == rules_scene.Mode.STORY and rules_scene.chess.board.count("") == 61 and state.checkpoint_id == "chess_challenge" and not state.flags.get("chess_resigned"), "R retries the Story puzzle and clears the resignation checkpoint")
	_press(rules_scene, KEY_X)
	_press(rules_scene, KEY_E)
	await process_frame
	await process_frame
	var routed_scene_name: String = str(current_scene.name) if current_scene != null else "<null>"
	_check(current_scene != null and state.scene_id == "scene_15" and state.checkpoint_id == "ending", "E after Story resignation routes directly to the bad-ending checkpoint; root=%s" % routed_scene_name)
	var ending_heading: Label = current_scene.get("heading") as Label if current_scene != null else null
	var ending_story: Label = current_scene.get("story") as Label if current_scene != null else null
	var ending_unlock: Label = current_scene.get("unlock") as Label if current_scene != null else null
	_check(ending_heading != null and ending_heading.text == "BAD ENDING  ·  NGƯỜI ĐÃ QUAY LƯNG", "resignation ending has the distinct Bad Ending title")
	_check(ending_story != null and ending_story.text.contains("Lần này... mình tưởng sẽ khác") and ending_story.text.contains("KÉÉÉÉT"), "resignation ending preserves An's story and the final stick sound")
	_check(ending_unlock != null and ending_unlock.text.contains("ĐÊM THỨ HAI") and state.ending == "ending_echo" and state.flags.get("chess_resigned"), "Bad Ending records the expected ending state and Night 2 unlock")
	if failures == 0:
		print("RESOLUTION_PASS checks=%d" % checks)
		quit()
	else:
		push_error("RESOLUTION_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _press(node: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	node._unhandled_input(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
