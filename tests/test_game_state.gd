extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	state.flags.clear()
	state.evidence.clear()
	state.choices.clear()
	_check(state.add_item_once("math_test"), "first reward is accepted")
	_check(not state.add_item_once("math_test"), "duplicate reward is rejected")
	_check(state.inventory.size() == 1, "inventory keeps a unique item")
	state.set_checkpoint("scene_07", "circuit_reward")
	state.set_flag("memory_2_seen")
	_check(state.set_choice("minh_post", "verify_warn"), "first persistent choice is accepted")
	_check(not state.set_choice("minh_post", "publish_raw"), "recorded choice cannot be overwritten")
	var encoded := JSON.stringify(state.to_dictionary())
	var decoded: Variant = JSON.parse_string(encoded)
	_check(decoded is Dictionary and decoded.get("checkpoint_id") == "circuit_reward", "save payload round-trips through JSON")
	_check(decoded.get("inventory").has("math_test") and decoded.get("flags").get("memory_2_seen"), "save payload includes rewards and memory flags")
	var test_save := "user://an_game_state_test.json"
	_check(state.save_game(test_save), "save writes a versioned checkpoint to disk")
	state.inventory.clear()
	state.scene_id = "scene_01"
	_check(state.load_game(test_save), "load accepts the saved checkpoint")
	_check(state.scene_id == "scene_07" and state.inventory.has("math_test") and state.choices.get("minh_post") == "verify_warn", "disk load restores scene, inventory and immutable choice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	if failures == 0:
		print("GAME_STATE_PASS checks=%d" % (7 + 3))
		quit()
	else:
		push_error("GAME_STATE_FAIL failures=%d" % failures)
		quit(1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
