extends SceneTree

## Runtime-facing regression coverage for the canonical An narrative beats.
## Assertions inspect labels/state produced by instantiated scenes, never source text.

var checks := 0
var failures := 0
var state: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	state.persistence_enabled = false
	state.save_writes_suppressed = true
	await _test_scenes_09_to_11_evidence()
	await _test_scene_12_memories()
	await _test_scene_14_final_memory()
	await _test_scene_15_morning_and_choice()
	if failures == 0:
		print("AN_NARRATIVE_REGRESSION_PASS checks=%d" % checks)
		quit()
	else:
		push_error("AN_NARRATIVE_REGRESSION_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _test_scenes_09_to_11_evidence() -> void:
	_reset_state()
	state.scene_id = "scene_09"
	state.checkpoint_id = "camera_recovery"
	for item_id in ["math_test", "chess_medal", "knight_keychain"]:
		state.inventory.append(item_id)
	var packed := load("res://scenes/09_phong_tin_hoc.tscn") as PackedScene
	var level := packed.instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame

	_check(level.beat == level.Beat.CAMERA, "scene 09 restores the camera evidence interface")
	for target in range(3):
		while level.camera_clips[target] != target:
			var source: int = level.camera_clips.find(target)
			_select_camera(level, target)
			_press(level, KEY_E)
			_select_camera(level, source)
			_press(level, KEY_E)
	var camera_claim := str(level.status.text)
	_check(camera_claim.contains("truy đuổi") and camera_claim.contains("gặp nạn"),
		"restored CCTV visibly establishes that An was chased before the accident")
	_check(camera_claim.contains("báo cáo") or camera_claim.contains("biên bản"),
		"camera evidence is explicitly compared with the incident report")
	
	_press(level, KEY_E) # claim photo
	_press(level, KEY_E) # continue to Scene 10
	_check(level.beat == level.Beat.POST, "Scene 09 evidence continues into the Scene 10 post")
	_press(level, KEY_E)
	var draft_claim := str(level.status.text)
	_check(draft_claim.contains("Minh") and (draft_claim.contains("bêu xấu") or draft_claim.contains("vu cáo")),
		"Scene 10 exposes that the anonymous post defames Minh")
	_press(level, KEY_E)
	var message_claim := str(level.status.text)
	_check(message_claim.contains("cảm ơn") and message_claim.contains("An"),
		"Scene 10 presents Minh's thank-you message to An")
	_press(level, KEY_E)
	_press(level, KEY_B)
	_check(state.choices.get("minh_post") == "verify_warn" and state.inventory.has("minh_thanks"),
		"Scene 10 records the chosen branch and grants Minh's keepsake")
	_press(level, KEY_E)
	_check(level.beat == level.Beat.DEDUCTION, "Scene 10 continues to the evidence board")

	_link(level, 0, 2)
	var bullying_claim := str(level.status.text)
	_check(bullying_claim.contains("bắt nạt") and bullying_claim.contains("bôi nhọ"),
		"Scene 11 concludes that An was bullied and defamed")
	_link(level, 1, 3)
	var report_claim := str(level.status.text)
	_check((report_claim.contains("bỏ sót") or report_claim.contains("thiếu dữ kiện"))
		and (report_claim.contains("không xác định ai") or report_claim.contains("chưa xác định ai")),
		"Scene 11 identifies report omissions while leaving who caused the incident unknown")
	_link(level, 4, 5)
	var trace_claim := str(level.status.text)
	_check(trace_claim.contains("dấu vết") and trace_claim.contains("bài cũ") and trace_claim.contains("An"),
		"Scene 11 links the Minh post by trace to An's old post")
	_check(trace_claim.contains("không đủ bằng chứng quy kết tác giả")
		or trace_claim.contains("chưa xác định tác giả"),
		"Scene 11 does not claim authorship for the linked post")
	level.queue_free()
	await process_frame

func _test_scene_12_memories() -> void:
	_reset_state()
	state.scene_id = "scene_12"
	state.checkpoint_id = "return_memories"
	for item_id in ["math_test", "chess_medal", "knight_keychain", "mother_photo", "minh_thanks", "chess_club_sketch"]:
		state.inventory.append(item_id)
	var level := (load("res://scenes/12_phong_cau_vua.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var memories: Array[String] = []
	for index in range(6):
		if index > 0:
			_press(level, KEY_RIGHT)
		_press(level, KEY_E)
		var visible_memory := str(level.status.text)
		memories.append(visible_memory)
		_check(visible_memory.contains("hồi ức"),
			"returning keepsake %d presents its short memory" % (index + 1))
		_check(bool(level.placed[index]) and bool(state.flags.get("returned_" + level.ITEM_IDS[index], false)),
			"returning keepsake %d records its own return" % (index + 1))
	_check(memories.size() == 6 and memories.duplicate().size() == 6
		and _unique_count(memories) == 6,
		"the six keepsakes trigger six distinct memory responses")
	level.queue_free()
	await process_frame

func _test_scene_14_final_memory() -> void:
	_reset_state()
	state.scene_id = "scene_14"
	state.checkpoint_id = "morning_confrontation"
	state.choices["minh_post"] = "verify_warn"
	state.flags["chess_boss_defeated"] = true
	var level := (load("res://scenes/14_binh_minh.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var story := _visible_text(level)
	_check(story.contains("vu cáo") or story.contains("bôi nhọ"),
		"final memory says An was accused and defamed")
	_check(story.contains("cầu cứu") and story.contains("kịp thời"),
		"final memory says An asked for help but was not helped in time")
	_check(story.contains("truy đuổi") and story.contains("cầu thang") and story.contains("gặp nạn"),
		"final memory says An was chased to the stairs and had an accident")
	_check(story.contains("vua đen") and story.contains("Trần Nhật Minh") and story.contains("11A2"),
		"An gives Hoang the black king marked with Minh's name and class")
	_check(story.contains("cảm ơn") and story.contains("biến mất"),
		"An thanks the group and then disappears")
	var ordered_beats := [
		_first_position(story, ["vu cáo", "bôi nhọ"]),
		story.find("cầu cứu"),
		story.find("truy đuổi"),
		story.find("vua đen"),
		story.find("cảm ơn"),
		story.find("biến mất"),
	]
	var beats_are_ordered := true
	for index in range(ordered_beats.size()):
		if ordered_beats[index] < 0 or (index > 0 and ordered_beats[index] <= ordered_beats[index - 1]):
			beats_are_ordered = false
	_check(beats_are_ordered, "Scene 14 presents the final memories and farewell in canonical order")
	level.queue_free()
	await process_frame

func _test_scene_15_morning_and_choice() -> void:
	var branch_texts: Array[String] = []
	for choice in ["verify_warn", "publish_raw"]:
		_reset_state()
		state.scene_id = "scene_15"
		state.checkpoint_id = "ending"
		state.choices["minh_post"] = choice
		state.flags["chess_boss_defeated"] = true
		var level := (load("res://scenes/15_ending.tscn") as PackedScene).instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		var screen_text := _visible_text(level)
		branch_texts.append(screen_text)
		_check(state.choices.get("minh_post") == choice,
			"Scene 15 preserves the Scene 10 choice %s" % choice)
		_check(screen_text.contains("lớp học") and (screen_text.contains("tỉnh dậy") or screen_text.contains("thức dậy")),
			"Scene 15 wakes Hoang in class")
		_check(screen_text.contains("nhớ") and screen_text.contains("các bạn"),
			"Scene 15 confirms the friends remember the night")
		_check(screen_text.contains("vua đen"),
			"Scene 15 shows Hoang still has the black king")
		if choice == "verify_warn":
			_check(screen_text.contains("Minh không đăng lời đồn"),
				"Scene 15 shows the verified-warning consequence")
		else:
			_check(screen_text.contains("lựa chọn vội vàng"),
				"Scene 15 shows the raw-post consequence")
		_check(screen_text.contains("Minh") and screen_text.contains("hành lang"),
			"Scene 15 shows Minh in the hallway")
		_check(screen_text.contains("giúp được An") and screen_text.contains("người tiếp theo"),
			"Scene 15 delivers the next-person message after helping An")
		_check((screen_text.contains("11 giờ") or screen_text.contains("23:00")) and screen_text.contains("11A2"),
			"Scene 15 message specifies 11 p.m. and room 11A2")
		_check(bool(state.flags.get("night_2_unlocked", false)),
			"Scene 15 keeps Night 2 unlocked")
		level.queue_free()
		await process_frame
	_check(branch_texts.size() == 2 and branch_texts[0] != branch_texts[1],
		"Scene 15 presents distinct consequences for the two Scene 10 choices")

func _reset_state() -> void:
	state.inventory.clear()
	state.evidence.clear()
	state.flags.clear()
	state.choices.clear()
	state.ending = "none"
	state.scene_id = "scene_01"
	state.checkpoint_id = "scene_01_start"

func _press(level: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	level.call("_unhandled_input", event)

func _select_camera(level: Node, target: int) -> void:
	while int(level.camera_selection) != target:
		_press(level, KEY_RIGHT)

func _select_evidence(level: Node, target: int) -> void:
	while int(level.selected_evidence) != target:
		_press(level, KEY_RIGHT)

func _link(level: Node, first: int, second: int) -> void:
	_select_evidence(level, first)
	_press(level, KEY_E)
	_select_evidence(level, second)
	_press(level, KEY_E)

func _visible_text(node: Node) -> String:
	var texts: Array[String] = []
	_collect_visible_labels(node, texts)
	return "\n".join(texts)

func _collect_visible_labels(node: Node, texts: Array[String]) -> void:
	if node is Label and node.is_visible_in_tree():
		texts.append((node as Label).text)
	for child in node.get_children():
		_collect_visible_labels(child, texts)

func _first_position(text_value: String, options: Array[String]) -> int:
	for option in options:
		var position := text_value.find(option)
		if position >= 0:
			return position
	return -1

func _unique_count(values: Array[String]) -> int:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
