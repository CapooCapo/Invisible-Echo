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

	var rules_scene = load("res://scenes/13_ban_co_boss.tscn").instantiate()
	rules_scene._ready()
	rules_scene._resign()
	_check(rules_scene.result == rules_scene.Result.RESIGNED and state.flags.get("chess_resigned"), "chess boss supports explicit resignation")
	_press(rules_scene, KEY_R)
	_check(rules_scene.result == rules_scene.Result.PLAYING and state.checkpoint_id == "chess_challenge" and not state.flags.get("chess_resigned"), "retry after resignation clears the saved resignation checkpoint")
	rules_scene.free()

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
