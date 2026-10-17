extends SceneTree

## Black-box regression for Scenes 05–06 on the configured production 3D route.
## It loads scenes/01_hanh_lang.tscn and interacts through gameplay input.
## Run: godot --headless --path . --script res://tests/test_production_scene05_06_regression.gd
const MAIN := "res://scenes/01_hanh_lang.tscn"
const SOLVED_ORDER := [1, 2, 3, 4, 5, 6]
const EXPECTED_DIARY := [
	"Hôm nay mình được 100 điểm Toán. Mẹ vui lắm!",
	"Họ nói mình gian lận. Mình không làm vậy.",
	"Mình đã cầu cứu... nhưng chẳng ai nghe.",
]

var behavior_failures: Array[String] = []
var game: Node
var game_state: Node
var night: Node
var actor: CharacterBody3D
var production_root: Node
var mapped_school: Node3D
var level3: Node3D
var board: Node3D
var locker_pivot: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game_state = root.get_node_or_null("GameState")
	if game_state == null:
		_engine_error("missing /root/GameState autoload")
		return
	# Persistence is disabled before instantiating the production scene. This
	# test never reads, writes, resets, or deletes the user's real save.
	game_state.persistence_enabled = false
	game_state.save_writes_suppressed = true
	game_state.chapter = "night_1"
	game_state.scene_id = "scene_04"
	game_state.checkpoint_id = "notice_board"
	game_state.story_time = "23:00"
	game_state.current_objective = ""
	game_state.inventory.clear()
	game_state.evidence.clear()
	game_state.flags.clear()
	game_state.choices.clear()
	game_state.ending = "none"

	var packed := load(MAIN) as PackedScene
	if packed == null:
		_engine_error("could not load configured production main scene")
		return
	game = packed.instantiate()
	if game == null:
		_engine_error("production main scene failed to instantiate")
		return
	root.add_child(game)
	current_scene = game
	production_root = game
	await process_frame
	await physics_frame
	await process_frame
	if not is_instance_valid(game):
		_fail("Scene 04 checkpoint did not resume in the configured production scene")
		_finish()
		return
	var beat_enum: Variant = game.get("Beat")
	if beat_enum == null:
		_engine_error("production Game script failed to initialize its Beat enum; check script parse/runtime errors above")
		return

	night = game.get("night_school_visual") as Node
	actor = night.get("actor") as CharacterBody3D if night != null else null
	var expected_beat := int(beat_enum.get("NIGHT_SCHOOL"))
	_check(current_scene == game and game.name == "Game"
		and int(game.get("beat")) == expected_beat and night != null and night.visible and actor != null,
		"scene_04/notice_board resumes in the main-scene production NightSchool3D stage")
	if night == null or actor == null:
		_finish()
		return

	var clock_label := game.get("clock_label") as Label
	var objective_label := game.get("objective") as Label
	var player_model := actor.get("model") as Node3D
	var spring_arm := actor.get("spring_arm") as SpringArm3D
	_check(str(game_state.scene_id) == "scene_05" and str(game_state.checkpoint_id) == "notice_board",
		"handoff records the Scene 05 notice_board checkpoint")
	_check(str(game_state.story_time) == "23:08" and clock_label != null and clock_label.text.contains("23:08"),
		"Scene 05 displays the scripted 23:08 story time")
	_check(objective_label != null and objective_label.text.to_lower().contains("tìm hiểu cô gái bí ẩn")
		and str(game_state.current_objective) == "FIND_MYSTERIOUS_GIRL",
		"Scene 05 presents the opening objective and quest ID")
	_check(bool(actor.get("controls_enabled")), "control is returned to Hoàng after the brief apparition handoff")
	_check(player_model != null and player_model.visible and spring_arm != null and spring_arm.spring_length > 0.0,
		"camera returns to third-person for Scene 05 exploration")
	if player_model == null or spring_arm == null:
		_finish()
		return

	mapped_school = night.find_child("MappedSchoolEnvironment", true, false) as Node3D
	level3 = mapped_school.get_node_or_null("Level3") as Node3D if mapped_school != null else null
	_check(mapped_school != null and level3 != null, "configured production scene contains mapped Level3")
	board = _find_named_mesh(level3, ["bảng tin tầng 3 framed bulletin board", "bulletin board"])
	locker_pivot = mapped_school.find_child("A17LockerDoorPivot", true, false) as Node3D if mapped_school != null else null
	_check(board != null and _has_mesh(board), "the bulletin board is a real mounted 3D object, not a floating label or trigger")
	_check(locker_pivot != null, "the production Level3 map contains the physical A-17 locker door")
	if board == null or locker_pivot == null:
		_finish()
		return

	# Test traversal using normal movement input from the resumed checkpoint.
	var entry_position := actor.global_position
	print("SCENE56_TRACE entry=%s" % str(entry_position))
	# Enter through the narrow south doorway before turning east toward A-17;
	# a direct diagonal crosses the jamb rather than the real room entrance.
	await _walk_toward(Vector3(-17.0, actor.global_position.y, -25.8), 7.0)
	print("SCENE56_TRACE doorway_waypoint=%s" % str(actor.global_position))
	await _walk_toward(Vector3(-14.7, actor.global_position.y, -27.05), 7.0)
	print("SCENE56_TRACE locker_approach=%s dist_locker=%.2f near_locker=%s near_board=%s" % [str(actor.global_position), Vector2(actor.global_position.x + 15.10, actor.global_position.z + 27.05).length(), str(night.call("near_locker_a17")), str(night.call("near_notice_board"))])
	_check(actor.global_position.distance_to(entry_position) > 1.0,
		"normal movement input moves Hoàng through the production 3D school")
	_check(bool(night.call("near_locker_a17")), "A-17 has a reachable physical interaction approach")
	_check(bool(night.call("near_notice_board")), "the physical A-17 approach is also within the adjacent board interaction radius")
	var closed_rotation := locker_pivot.rotation.y
	var inspection_origin := actor.global_transform
	var inspection_yaw := float(actor.get("camera_yaw"))
	var inspection_pitch := float(actor.get("camera_pitch"))
	var inspection_third_person := spring_arm.spring_length > 0.0
	var inspection_mouse_mode := Input.mouse_mode
	await _tap_key(KEY_E)
	var board_panel := game.get("scene56_panel") as PanelContainer
	_check(current_scene == production_root and board_panel != null and board_panel.visible,
		"E at the adjacent bulletin board opens its physical inspection")
	_check(not bool(game_state.flags.get("a17_locker_open", false))
		and is_equal_approx(locker_pivot.rotation.y, closed_rotation)
		and str(game_state.scene_id) == "scene_05",
		"A-17 stays gated and closed before its code is discovered")
	_check(not game_state.flags.has("diary_solved") and not game_state.inventory.has("math_test"),
		"the pre-clue locker interaction exposes neither puzzle completion nor reward")
	_check(bool(night.call("near_notice_board")), "Hoàng can physically reach the board's interaction range")
	await process_frame
	_check(current_scene == production_root and board_panel != null and board_panel.visible,
		"E opens the physical board inspection without leaving the production 3D route")
	_check(str(game_state.current_objective) == "INSPECT_BULLETIN_BOARD",
		"opening the board advances the quest to INSPECT_BULLETIN_BOARD")
	_check(not bool(actor.get("controls_enabled")) and spring_arm.spring_length == 0.0,
		"board inspection locks movement and enters its close-up camera mode")
	var board_camera_hit := _inspection_board_face_hit()
	print("SCENE56_TRACE board_camera origin=%s direction=%s local_face_hit=%s" % [
		str(board_camera_hit.get("origin", Vector3.ZERO)),
		str(board_camera_hit.get("direction", Vector3.ZERO)),
		str(board_camera_hit.get("local_hit", Vector3.ZERO)),
	])
	_check(bool(board_camera_hit.get("hits_face", false)),
		"the close-up camera center ray lands on the mounted board's physical front face")

	# Select the blacked-out photo by the visible semantic board control if the
	# implementation's initial selection ever changes; use E to inspect it.
	for _step in range(6):
		var board_text := _visible_text(board_panel)
		if board_text.contains("ảnh bị bôi đen"):
			break
		await _tap_key(KEY_RIGHT)
		await process_frame
	var selected_photo_text := _visible_text(board_panel)
	_check(selected_photo_text.contains("ảnh bị bôi đen"), "board inspection lets the player select the blacked-out photo")
	_check(not game_state.evidence.has("an_name_nguyen_ngoc_an"),
		"the photo facts are not recorded before the player chooses to inspect it")
	await _tap_key(KEY_E)
	await process_frame
	var front_clue_text := _visible_text(board_panel)
	_check(front_clue_text.contains("nguyễn ngọc an") and front_clue_text.contains("giải nhất cờ vua")
		and front_clue_text.contains("18/04"), "photo inspection reveals the exact front-side facts")
	_check(_clue_recorded("an_name_nguyen_ngoc_an", "nguyễn ngọc an")
		and _clue_recorded("an_chess_first_prize", "giải nhất cờ vua")
		and _clue_recorded("an_photo_date_18_04", "18/04"),
		"front-side facts are stored as discovered evidence with source metadata")
	_check(str(game_state.current_objective) == "IDENTIFY_AN"
		and str(game_state.checkpoint_id) == "board_portrait",
		"photo front updates quest ID and Scene 05 board_portrait checkpoint")
	_check(front_clue_text.contains("an... là người đã mất tháng trước.")
		and front_clue_text.contains("đi tìm tủ đồ của cậu ấy."),
		"the specified Bảo and Hoàng lines appear after the photo is inspected")
	_check(not game_state.evidence.has("an_locker_code_a17"),
		"A-17 remains undisclosed until the player flips the photo")
	await _tap_key(KEY_F)
	await process_frame
	var reverse_text := _visible_text(board_panel)
	_check(reverse_text.contains("a-17") and _clue_recorded("an_locker_code_a17", "a-17"),
		"F flips the selected photo and records the A-17 reverse-side clue")
	_check(str(game_state.current_objective) == "FIND_LOCKER_A17"
		and str(game_state.checkpoint_id) == "board_reverse",
		"photo reverse advances to FIND_LOCKER_A17 and its checkpoint")

	# Esc closes inspection and must restore camera/player state exactly.
	await _tap_key(KEY_ESCAPE)
	await process_frame
	_check(not board_panel.visible and bool(actor.get("controls_enabled"))
		and (spring_arm.spring_length > 0.0) == inspection_third_person
		and Input.mouse_mode == inspection_mouse_mode,
		"closing inspection restores its previous camera mode, control, and mouse state")
	_check(actor.global_position.distance_to(inspection_origin.origin) < 0.05
		and is_equal_approx(float(actor.get("camera_yaw")), inspection_yaw)
		and is_equal_approx(float(actor.get("camera_pitch")), inspection_pitch),
		"closing inspection restores Hoàng's prior position and camera orientation")

	# At the reachable overlap, test that the newly revealed code routes E to the
	# locker instead of reopening the board. If the board still captures E, the
	# diary is physically unreachable and later puzzle checks are not meaningful.
	_check(bool(night.call("near_locker_a17")), "after discovering A-17, Hoàng can return to the locker")
	await _tap_key(KEY_E)
	await process_frame
	if not bool(game_state.flags.get("a17_locker_open", false)):
		var blocked_locker_panel := game.get("scene56_panel") as PanelContainer
		_check(false, "after discovering A-17, E opens the physical locker and records the Scene 06 puzzle checkpoint")
		_check(blocked_locker_panel != null and blocked_locker_panel.visible
			and str(game_state.scene_id) == "scene_05",
			"the board-priority interaction captures E at the overlapping board/locker approach")
		_finish()
		return
	_check(bool(game_state.flags.get("a17_locker_open", false))
		and str(game_state.scene_id) == "scene_06"
		and str(game_state.checkpoint_id) == "locker_a17"
		and str(game_state.current_objective) == "REASSEMBLE_DIARY",
		"E opens the now-identified locker and records the Scene 06 puzzle checkpoint")
	_check(is_equal_approx(locker_pivot.rotation.y, PI * .5), "the A-17 locker door physically opens")
	_check(not game_state.flags.has("diary_solved") and not game_state.inventory.has("math_test"),
		"opening the locker does not auto-complete the diary or award its keepsake")
	await _tap_key(KEY_E)
	await process_frame
	var diary_panel := game.get("scene56_panel") as PanelContainer
	var diary_grid := game.get("scene56_diary_grid") as GridContainer
	_check(diary_panel != null and diary_panel.visible and diary_grid != null and diary_grid.visible,
		"a second interaction opens the six-piece diary puzzle")
	var initial_order := _read_diary_order(diary_grid)
	_check(initial_order.size() == 6 and _is_permutation(initial_order),
		"the deterministic diary puzzle presents six uniquely numbered fragments")
	_check(initial_order != SOLVED_ORDER, "the initial six fragments require solving")
	if initial_order.size() != 6:
		_finish()
		return

	# Exercise the actual Control drag-and-drop path for a wrong swap. Then
	# close/reopen to prove the arrangement is retained and finish the puzzle.
	var expected_wrong := initial_order.duplicate()
	var swap_value: int = expected_wrong[0]
	expected_wrong[0] = expected_wrong[1]
	expected_wrong[1] = swap_value
	await _drag_control(diary_grid.get_child(0) as Control, diary_grid.get_child(1) as Control)
	await process_frame
	var wrong_order := _read_diary_order(diary_grid)
	_check(wrong_order == expected_wrong and not bool(game_state.flags.get("diary_solved", false))
		and str(game_state.checkpoint_id) == "locker_a17"
		and not game_state.inventory.has("math_test"),
		"a real GUI drag/drop changes two slots but rejects wrong order without solving or granting the keepsake")

	await _tap_key(KEY_ESCAPE)
	await process_frame
	_check(bool(actor.get("controls_enabled")) and spring_arm.spring_length > 0.0,
		"closing the diary puzzle restores gameplay camera and movement")
	await _tap_key(KEY_E)
	await process_frame
	diary_panel = game.get("scene56_panel") as PanelContainer
	diary_grid = game.get("scene56_diary_grid") as GridContainer
	_check(diary_panel.visible and diary_grid.visible and _read_diary_order(diary_grid) == wrong_order,
		"closing/reopening the puzzle preserves its fragment order")

	for target_piece in range(6):
		var current_order := _read_diary_order(diary_grid)
		var source_slot := current_order.find(target_piece + 1)
		if source_slot != target_piece:
			await _tap_key(KEY_1 + source_slot)
			await _tap_key(KEY_1 + target_piece)
			await process_frame
	_check(bool(game_state.flags.get("diary_solved", false))
		and str(game_state.scene_id) == "scene_06"
		and str(game_state.checkpoint_id) == "diary_reward"
		and str(game_state.current_objective) == "COLLECT_FIRST_KEEPSAKE",
		"only the correct six-fragment order completes the diary and records diary_reward")
	var completed_diary_text := _visible_text(diary_panel) + " " + JSON.stringify(game_state.evidence).to_lower()
	for excerpt in EXPECTED_DIARY:
		_check(completed_diary_text.contains(excerpt.to_lower()), "completed puzzle reveals diary text: " + excerpt)
	_check(_clue_recorded("diary_03_09", "100 điểm toán")
		and _clue_recorded("diary_12_09", "gian lận")
		and _clue_recorded("diary_18_09", "cầu cứu"),
		"three diary excerpts are recorded as discovered evidence")
	_check(not game_state.inventory.has("math_test"),
		"solving the puzzle alone does not award math_test before explicit pickup")
	var reward := _find_named_mesh(mapped_school, ["a17 100 over 100 math test reward"])
	_check(reward != null and reward.visible, "the solved diary makes the physical 100/100 test collectible")
	_check(_visible_text(diary_panel).contains("cậu ấy từng rất hạnh phúc"),
		"completed diary provides Hoàng's specified reflective line")

	# Close puzzle, approach the visible test with normal movement, and collect
	# using E. The memory is asynchronous; wait for its full 3-second return.
	await _tap_key(KEY_ESCAPE)
	await process_frame
	_check(bool(actor.get("controls_enabled")) and spring_arm.spring_length > 0.0,
		"closing solved diary restores third-person gameplay before reward pickup")
	await _walk_toward(reward.global_position, 4.0)
	await _tap_key(KEY_E)
	await process_frame
	var memory_overlay := game.get("scene56_memory_overlay") as ColorRect
	_check(game_state.inventory.count("math_test") == 1
		and bool(game_state.flags.get("KEEPSAKE_01_ACQUIRED", false))
		and str(game_state.checkpoint_id) == "diary_reward",
		"explicit E pickup grants exactly one math_test keepsake and preserves diary_reward")
	_check(memory_overlay != null and memory_overlay.visible
		and not bool(actor.get("controls_enabled")) and spring_arm.spring_length == 0.0,
		"the keepsake memory temporarily takes control and camera for its short presentation")
	await create_timer(3.2).timeout
	await process_frame
	_check(memory_overlay != null and not memory_overlay.visible
		and bool(actor.get("controls_enabled")) and spring_arm.spring_length > 0.0,
		"the keepsake memory ends and restores gameplay control and camera")
	_check(current_scene == production_root and int(game.get("beat")) == expected_beat
		and str(game_state.scene_id) == "scene_06",
		"the Scene 06 reward checkpoint does not transition prematurely to Scene 07")
	var saved_snapshot: Dictionary = game_state.to_dictionary()
	_check(saved_snapshot.get("checkpoint_id") == "diary_reward"
		and saved_snapshot.get("inventory", []).count("math_test") == 1,
		"serializable save-state snapshot preserves one keepsake at diary_reward")
	await _tap_key(KEY_E)
	await process_frame
	_check(game_state.inventory.count("math_test") == 1,
		"re-interaction cannot create a duplicate math_test keepsake")
	var duplicate_interaction_panel := game.get("scene56_panel") as PanelContainer
	if duplicate_interaction_panel != null and duplicate_interaction_panel.visible:
		await _tap_key(KEY_ESCAPE)
		await process_frame

	# Narrow live C04→C05 handoff probe. Return to the mirror-side hall using
	# ordinary movement so the timer can reveal the board without immediately
	# auto-interacting at the board checkpoint.
	await _walk_toward(Vector3(-17.0, actor.global_position.y, actor.global_position.z), 4.0)
	await _walk_toward(Vector3(-17.0, actor.global_position.y, -22.4), 7.0)
	print("SCENE56_TRACE c04_staging=%s controls=%s near_board=%s phase=%s" % [str(actor.global_position), str(actor.get("controls_enabled")), str(night.call("near_notice_board")), str(game.get("night_phase"))])
	_check(not bool(night.call("near_notice_board")) and bool(actor.get("controls_enabled")),
		"Hoàng can return to the mirror-side hall before the C04 apparition handoff")
	game_state.set_checkpoint("scene_04", "mirror_search")
	game.set("night_phase", "mirror_empty")
	game.call("_interact_night_school")
	var hallway_apparition := night.get("hallway_apparition") as Node3D
	print("SCENE56_TRACE c04_trigger phase=%s controls=%s apparition=%s" % [str(game.get("night_phase")), str(actor.get("controls_enabled")), str(hallway_apparition.visible if hallway_apparition != null else null)])
	_check(str(game.get("night_phase")) == "hallway_apparition"
		and not bool(actor.get("controls_enabled"))
		and hallway_apparition != null and hallway_apparition.visible,
		"C04 mirror-empty interaction shows An at the hallway end and locks control")
	game.call("_process_night_school", 1.6)
	print("SCENE56_TRACE c04_timeout phase=%s controls=%s tp=%s checkpoint=%s scene=%s pos=%s" % [str(game.get("night_phase")), str(actor.get("controls_enabled")), str(spring_arm.spring_length), str(game_state.checkpoint_id), str(game_state.scene_id), str(actor.global_position)])
	_check(str(game.get("night_phase")) == "mirror_reveal"
		and hallway_apparition != null and not hallway_apparition.visible
		and bool(actor.get("controls_enabled")) and spring_arm.spring_length > 0.0
		and str(game_state.scene_id) == "scene_04"
		and str(game_state.checkpoint_id) == "notice_board",
		"C04 apparition ends at mirror_reveal with control restored and Scene 04 notice_board checkpoint")
	# This probe isolates the C04→C05 state handoff; the earlier route assertions
	# already prove ordinary traversal. Stage Hoàng at the reachable approach so
	# the final E tests the handoff itself rather than repeating corridor movement.
	actor.global_position = Vector3(-17.0, actor.global_position.y, -25.8)
	await physics_frame
	_check(bool(night.call("near_notice_board")), "the handoff probe stages Hoàng at the reachable board approach")
	var pre_handoff_transform := actor.global_transform
	game.call("_interact_night_school")
	_check(str(game.get("night_phase")) == "scene56_explore"
		and str(game_state.scene_id) == "scene_05"
		and str(game_state.story_time) == "23:08"
		and str(game_state.current_objective) == "FIND_MYSTERIOUS_GIRL",
		"board interaction completes the C04→C05 handoff with Scene 05 time and objective")
	_check(actor.global_transform.is_equal_approx(pre_handoff_transform),
		"the C04→C05 handoff keeps Hoàng's pre-interaction position and camera transform")

	# Case-file compatibility probe: a legacy boolean clue should receive a
	# readable ID fallback, while a structured clue should retain its authored
	# name. Evidence is changed only in this persistence-disabled test process.
	var case_file_panel := game.get("scene56_panel") as PanelContainer
	if case_file_panel != null and case_file_panel.visible:
		game.call("_close_scene56_panel")
	game_state.evidence["diary_03_09"] = true
	game_state.evidence["diary_12_09"] = {
		"name": "Authored diary clue title",
		"description": "Authored diary clue description.",
		"discovered": true,
		"source": "test-only in-memory fixture",
	}
	game.call("_open_an_case_file")
	case_file_panel = game.get("scene56_panel") as PanelContainer
	var case_file_text := _visible_text(case_file_panel)
	_check(case_file_panel != null and case_file_panel.visible,
		"the An case file opens for mixed legacy and structured clue data without aborting")
	_check(case_file_text.contains("diary 03 09")
		and case_file_text.contains("authored diary clue title")
		and case_file_text.contains("authored diary clue description"),
		"the case file sanitizes a boolean clue ID and preserves authored dictionary text")
	_finish()

func _walk_toward(target: Vector3, max_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < max_seconds and is_instance_valid(actor) and bool(actor.get("controls_enabled")):
		var offset := Vector3(target.x - actor.global_position.x, 0.0, target.z - actor.global_position.z)
		if offset.length() < 1.15:
			return
		actor.set("camera_yaw", atan2(-offset.x, -offset.z))
		Input.action_press("move_up")
		await create_timer(0.25).timeout
		Input.action_release("move_up")
		elapsed += 0.25
	Input.action_release("move_up")

func _tap_key(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	Input.parse_input_event(up)
	await process_frame

func _drag_control(source: Control, target: Control) -> void:
	if source == null or target == null:
		_fail("drag/drop source and target diary buttons exist")
		return
	var from_position := source.get_global_rect().get_center()
	var to_position := target.get_global_rect().get_center()
	print("SCENE56_TRACE diary_drag from=%s to=%s source=%s target=%s" % [
		str(from_position), str(to_position), str(source.text), str(target.text),
	])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = from_position
	press.global_position = from_position
	get_root().push_input(press, true)
	await process_frame
	var midpoint := from_position.lerp(to_position, 0.5)
	var first_motion := InputEventMouseMotion.new()
	first_motion.position = midpoint
	first_motion.global_position = midpoint
	first_motion.relative = midpoint - from_position
	first_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_root().push_input(first_motion, true)
	await process_frame
	var second_motion := InputEventMouseMotion.new()
	second_motion.position = to_position
	second_motion.global_position = to_position
	second_motion.relative = to_position - midpoint
	second_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_root().push_input(second_motion, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.button_mask = 0
	release.position = to_position
	release.global_position = to_position
	get_root().push_input(release, true)
	await process_frame

func _inspection_board_face_hit() -> Dictionary:
	var camera := actor.get("camera") as Camera3D if actor != null else null
	if camera == null or not board is MeshInstance3D:
		return {"hits_face": false}
	var board_mesh := (board as MeshInstance3D).mesh as BoxMesh
	if board_mesh == null:
		return {"hits_face": false}
	var normal: Vector3 = board.global_basis.z.normalized()
	var face_center: Vector3 = board.global_position + normal * board_mesh.size.z * 0.5
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = (-camera.global_basis.z).normalized()
	var denominator: float = direction.dot(normal)
	if denominator >= -0.0001:
		return {"hits_face": false, "origin": origin, "direction": direction}
	var distance: float = (face_center - origin).dot(normal) / denominator
	if distance <= 0.0:
		return {"hits_face": false, "origin": origin, "direction": direction}
	var hit: Vector3 = origin + direction * distance
	var local_hit: Vector3 = board.to_local(hit)
	var hits_face := absf(local_hit.x) <= board_mesh.size.x * 0.5 \
		and absf(local_hit.y) <= board_mesh.size.y * 0.5 \
		and is_equal_approx(local_hit.z, board_mesh.size.z * 0.5)
	return {
		"hits_face": hits_face,
		"origin": origin,
		"direction": direction,
		"local_hit": local_hit,
	}

func _read_diary_order(grid: GridContainer) -> Array[int]:
	var result: Array[int] = []
	if grid == null:
		return result
	var piece_number := RegEx.new()
	piece_number.compile("(?i)mảnh\\s+(\\d+)")
	for child in grid.get_children():
		if not child is Button:
			continue
		var found := piece_number.search((child as Button).text)
		if found != null:
			result.append(int(found.get_string(1)))
	return result

func _is_permutation(values: Array[int]) -> bool:
	if values.size() != 6:
		return false
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return sorted_values == SOLVED_ORDER

func _clue_recorded(clue_id: String, expected_text: String) -> bool:
	var clues: Dictionary = game_state.evidence
	if not clues.has(clue_id) or not clues[clue_id] is Dictionary:
		return false
	var clue: Dictionary = clues[clue_id]
	var metadata_text := (str(clue.get("name", "")) + " " + str(clue.get("description", ""))).to_lower()
	return bool(clue.get("discovered", false)) \
		and not str(clue.get("source", "")).is_empty() \
		and metadata_text.contains(expected_text.to_lower())

func _find_named_mesh(root_node: Node, terms: Array[String]) -> Node3D:
	if root_node == null:
		return null
	for candidate in _all_nodes(root_node):
		if not candidate is Node3D or not _contains_any(candidate.name.to_lower(), terms):
			continue
		if _has_mesh(candidate):
			return candidate as Node3D
	return null

func _has_mesh(root_node: Node) -> bool:
	for candidate in _all_nodes(root_node):
		if candidate is MeshInstance3D and candidate.visible and candidate.mesh != null:
			return true
	return false

func _visible_text(root_node: Node) -> String:
	var pieces: Array[String] = []
	for candidate in _all_nodes(root_node):
		if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
			continue
		if candidate is Node3D and not (candidate as Node3D).is_visible_in_tree():
			continue
		if candidate is Label:
			pieces.append((candidate as Label).text)
		elif candidate is Button:
			pieces.append((candidate as Button).text)
		elif candidate is RichTextLabel:
			pieces.append((candidate as RichTextLabel).text)
		elif candidate is Label3D:
			pieces.append((candidate as Label3D).text)
	return " ".join(pieces).to_lower()

func _contains_any(text: String, terms: Array[String]) -> bool:
	var normalized := text.to_lower()
	for term in terms:
		if normalized.contains(term.to_lower()):
			return true
	return false

func _all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_all_nodes(child))
	return result

func _check(condition: bool, description: String) -> void:
	if not condition:
		_fail(description)

func _fail(description: String) -> void:
	behavior_failures.append(description)
	push_error("SCENE56_BEHAVIOR_FAIL " + description)

func _engine_error(description: String) -> void:
	push_error("SCENE56_ENGINE_ERROR " + description)
	quit(2)

func _finish() -> void:
	Input.action_release("move_up")
	if behavior_failures.is_empty():
		print("SCENE56_BEHAVIOR_PASS")
		quit(0)
	else:
		print("SCENE56_BEHAVIOR_SUMMARY failures=%d" % behavior_failures.size())
		for failure in behavior_failures:
			print("SCENE56_BEHAVIOR_ITEM " + failure)
		quit(1)
