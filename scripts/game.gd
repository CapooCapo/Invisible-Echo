extends Node2D

## First playable slice: narrative beats 01–04, played in physical 3D rooms.
signal dialogue_finished(dialogue_id: StringName)

class Scene56DiaryPieceButton extends Button:
	var slot_index := -1
	var drop_action: Callable

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = text
		preview.add_theme_color_override("font_color", Color("#edc77e"))
		preview.add_theme_font_size_override("font_size", 16)
		set_drag_preview(preview)
		return slot_index

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is int and int(data) != slot_index

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if drop_action.is_valid():
			drop_action.call(int(data), slot_index)

const VIEW := Vector2(960, 540)
const PLAYER_SPEED := 205.0
const LETTER_REVEAL_DURATION := 0.72
const HIDE_SECONDS := 3.0
const HIDE_STAGING_SECONDS := 1.4
const HIDE_SPOT := Rect2(80, 286, 210, 170)
const MIRROR_RECT := Rect2(790, 128, 96, 165)

enum Beat { HALLWAY, LETTER, CLASSROOM, TOILET, DEAD, MIRROR, REFLECTION, GHOST, NIGHT_SCHOOL }
var beat: Beat = Beat.HALLWAY
var player := Vector2(480, 405)
var letter_found := false
var is_hidden := false
var hide_time := HIDE_SECONDS
var hide_staging_remaining := 0.0
var letter_reveal_remaining := 0.0
var letter_close_reveal_remaining := 0.0
var message: Label
var prompt: Label
var dialogue_prompt_column: VBoxContainer
var prompt_hud: PanelContainer
var objective: Label
var overlay: ColorRect
var panel: PanelContainer
var retry_button: Button
var hallway_visual: SubViewportContainer
var restroom_visual: SubViewportContainer
var classroom_visual: SubViewportContainer
var night_school_visual: SubViewportContainer
var active_room := ""
var last_projected_player := Vector2.INF
var classroom_read := false
var classroom_intro_dismissed := false
var opening_phase := ""
var opening_line_index := 0
var opening_timer := 0.0
var monologue_completion_timer: Timer
var opening_reveal_index := 0
var opening_preview_launch := false
var night_school_preview_launch := false
var opening_card: PanelContainer
var opening_speaker: Label
var opening_subtitle: Label
var opening_hint: Label
var opening_letter_card: PanelContainer
var opening_letter_contents: Label
var cinematic_black: ColorRect
var chapter_card: Label
var clock_label: Label
var inventory_bar: PanelContainer
var inventory_hint: Label
var inventory_slots: Array[PanelContainer] = []
var inventory_slot_labels: Array[Label] = []
var selected_inventory_slot := 0
var afternoon_exit_available := false
var exit_transition_pending := false
var night_phase := ""
var night_timer := 0.0
var night_red_overlay: ColorRect
var night_death_overlay: ColorRect
var night_hide_timer := 3.0
var night_line_timer := 0.0
var night_is_dead := false
var night_bell_remaining := 0
var night_door_sfx: AudioStreamPlayer
var night_stick_sfx: AudioStreamPlayer
var school_bell_sfx: AudioStreamPlayer
var scene56_mode := ""
var scene56_panel: PanelContainer
var scene56_dimmer: ColorRect
var scene56_case_file_button: Button
var scene56_panel_title: Label
var scene56_panel_text: RichTextLabel
var scene56_controls: HBoxContainer
var scene56_diary_grid: GridContainer
var scene56_selected_board_item := 2
var scene56_photo_front_revealed := false
var scene56_photo_back_revealed := false
var scene56_diary_piece_order: Array[int] = [3, 1, 4, 0, 5, 2]
var scene56_selected_piece_slot := -1
var scene56_memory_overlay: ColorRect
var scene56_memory_timer: Timer
var scene56_reward_collected := false
var scene56_case_file_mouse_mode := Input.MOUSE_MODE_VISIBLE

const SCENE56_DIARY_FRAGMENTS := [
	"Ngày 03/09: \"Hôm nay mình được",
	"100 điểm Toán. Mẹ vui lắm!\"",
	"Ngày 12/09: \"Họ nói mình",
	"gian lận. Mình không làm vậy.\"",
	"Ngày 18/09: \"Mình đã cầu cứu...",
	"nhưng chẳng ai nghe.\"",
]

const STORY_TIMES := {
	"scene_01": "17:10",
	"scene_02": "07:15",
	"after_school": "17:00",
	# Configured placeholder: canon states “night before 23:00” but does not
	# specify the exact courtyard minute.
	"night_arrival": "22:55",
	"restroom": "23:00",
	"scene_05": "23:08",
}

const SCENE_01_MONOLOGUE := [
	"Chúng ta sống trong một thế giới nơi cá lớn nuốt cá bé.",
	"Nơi con người giẫm lên nhau chỉ để được sống.",
	"Tôi từng nghĩ... chỉ cần không liên quan đến mình là đủ.",
]
const SCENE_01_DIALOGUE := [
	["Bảo", "Ê, về thôi!"],
	["Hoàng", "Đợi chút. Cái gì kia?"],
]
const SCENE_01_LETTER_DIALOGUE := [
	["Bảo", "Thư tình à?"],
	["Hoàng", "Không ghi tên."],
	["Huân", "Không liên quan thì bỏ đi."],
	["Lân", "Về thôi, trễ rồi."],
]
const SCENE_01_FRONT_COMMENT := ["Hoàng", "Lần sau viết SOS nhé."]
const SCENE_02_DIALOGUE := [
	["Bảo", "Nghe nói tháng trước có một học sinh chết ở trường này."],
	["Hoàng", "Thật à?"],
	["Huân", "Tin đồn thôi."],
]

func _ready() -> void:
	AudioDirector.set_ambience("school_night")
	_setup_input()
	_build_hallway_visual()
	_build_restroom_visual()
	_build_classroom_visual()
	_build_night_school_visual()
	_build_ui()
	monologue_completion_timer = Timer.new()
	monologue_completion_timer.one_shot = true
	monologue_completion_timer.timeout.connect(func(): dialogue_finished.emit(&"classroom_black_monologue"))
	add_child(monologue_completion_timer)
	dialogue_finished.connect(_on_dialogue_finished)
	var launched_from_title_menu := GameState.consume_title_menu_route()
	opening_preview_launch = _prepare_editor_opening_preview(launched_from_title_menu)
	_restore_checkpoint()
	_show_beat()
	if opening_preview_launch or GameState.scene_id == "scene_01":
		_start_opening_sequence()
	elif GameState.scene_id == "scene_02":
		if GameState.checkpoint_id in ["afternoon_exit", "night_school_transition"]:
			beat = Beat.HALLWAY
			GameState.set_story_time(STORY_TIMES.after_school)
			letter_found = true
			afternoon_exit_available = true
			_show_beat()
			objective.text = "Tan học · Đi tới cửa thoát trường"
			prompt.text = "WASD di chuyển · E mở cửa thoát"
		else:
			GameState.set_story_time(STORY_TIMES.scene_02)
			classroom_intro_dismissed = true
			panel.visible = false
			opening_phase = "classroom_establish"
			classroom_visual.call("set_opening_state", "message")
			var establish_tween: Tween = classroom_visual.call("play_establishing_shot")
			if establish_tween != null:
				establish_tween.finished.connect(_on_classroom_establish_finished, CONNECT_ONE_SHOT)
			else:
				push_warning("Classroom establish camera was unavailable; continuing to dialogue safely.")
				call_deferred("_on_classroom_establish_finished")
	if GameState.scene_id in ["scene_05", "scene_06"]:
		call_deferred("_resume_scene56_stage")
	elif GameState.scene_id in ["scene_07", "scene_08"]:
		call_deferred("_resume_scene", "res://scenes/05_bang_tin.tscn")
	elif GameState.scene_id in ["scene_09", "scene_10", "scene_11"]:
		call_deferred("_resume_scene", "res://scenes/09_phong_tin_hoc.tscn")
	elif GameState.scene_id in ["scene_12", "scene_13", "scene_14", "scene_15"]:
		call_deferred("_resume_scene", "res://scenes/%s" % {
			"scene_12": "12_phong_cau_vua.tscn",
			"scene_13": "13_ban_co_boss.tscn",
			"scene_14": "14_binh_minh.tscn",
			"scene_15": "15_ending.tscn",
		}[GameState.scene_id])


func _prepare_editor_opening_preview(skip_automatic_editor_preview: bool = false) -> bool:
	var user_args := OS.get_cmdline_user_args()
	var force_preview := user_args.has("--opening-preview")
	var force_night_school_preview := user_args.has("--night-school-preview")
	var launched_from_editor := OS.has_feature("editor") and EngineDebugger.is_active() and not skip_automatic_editor_preview
	if not force_preview and not force_night_school_preview and not launched_from_editor:
		return false
	# Editor F5 opens the integrated night-school level so environment work is
	# immediately inspectable. Exported builds keep the normal story entrypoint.
	GameState.persistence_enabled = false
	GameState.save_writes_suppressed = true
	GameState.chapter = "night_1"
	GameState.inventory.clear()
	GameState.evidence.clear()
	GameState.flags.clear()
	GameState.choices.clear()
	GameState.ending = "none"
	if force_preview:
		GameState.scene_id = "scene_01"
		GameState.checkpoint_id = "scene_01_start"
		return true
	night_school_preview_launch = true
	GameState.scene_id = "scene_03"
	GameState.checkpoint_id = "night_school_yard"
	return false

func _restore_checkpoint() -> void:
	match GameState.scene_id:
		"scene_01":
			beat = Beat.HALLWAY
			GameState.set_checkpoint("scene_01", "hallway_letter")
		"scene_02":
			beat = Beat.CLASSROOM
			letter_found = true
			player = Vector2(480, 405)
			classroom_read = false
			classroom_intro_dismissed = false
		"scene_03":
			letter_found = true
			if GameState.checkpoint_id in ["night_school_yard", "night_school_ground_hall", "restroom_approach", "restroom_threat"]:
				beat = Beat.NIGHT_SCHOOL
				var at_yard := GameState.checkpoint_id == "night_school_yard"
				var at_ground_hall := GameState.checkpoint_id == "night_school_ground_hall"
				GameState.set_story_time(STORY_TIMES.night_arrival if at_yard or at_ground_hall else STORY_TIMES.restroom)
				if at_yard:
					night_phase = "yard"
				elif at_ground_hall:
					night_phase = "ground_hall"
				elif GameState.checkpoint_id == "restroom_approach":
					night_phase = "friend_bao_line"
				else:
					night_phase = "find_stall"
				night_hide_timer = 3.0
				if at_ground_hall:
					night_school_visual.call("restore_ground_hall")
				elif GameState.checkpoint_id == "restroom_threat":
					call_deferred("_resume_restroom_threat")
				elif GameState.checkpoint_id == "restroom_approach":
					call_deferred("_resume_restroom_approach")
			else:
				beat = Beat.TOILET
				GameState.set_story_time(STORY_TIMES.restroom)
				player = Vector2(360, 417)
				is_hidden = false
				hide_time = HIDE_SECONDS
		"scene_04":
			if GameState.checkpoint_id in ["mirror", "mirror_search", "notice_board"]:
				beat = Beat.NIGHT_SCHOOL
				GameState.set_story_time(STORY_TIMES.restroom)
				night_phase = "mirror_reveal" if GameState.checkpoint_id == "notice_board" else "mirror_search"
				letter_found = true
				call_deferred("_resume_notice_board_stage" if night_phase == "mirror_reveal" else "_resume_mirror_stage")
			else:
				beat = Beat.MIRROR
				letter_found = true
				player = Vector2(480, 405)
		"scene_05", "scene_06":
			beat = Beat.NIGHT_SCHOOL
			GameState.set_story_time(STORY_TIMES.scene_05)
			letter_found = true
			night_phase = "scene56_explore"
			call_deferred("_resume_scene56_stage")
		_:
			beat = Beat.HALLWAY

func _resume_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _resume_restroom_threat() -> void:
	if beat != Beat.NIGHT_SCHOOL or night_school_visual == null:
		return
	night_school_visual.call("resume_restroom_threat")
	night_school_visual.call("set_red_realm", true)
	night_red_overlay.visible = true
	night_red_overlay.color.a = .30
	objective.text = "SURVIVAL EVENT 01  ·  3.0 GIÂY"
	prompt.text = "Trốn trong một buồng vệ sinh!"

func _resume_restroom_approach() -> void:
	if beat != Beat.NIGHT_SCHOOL or night_school_visual == null:
		return
	night_school_visual.call("resume_restroom_approach")
	_show_night_line("Bảo", "Tối thật đấy...", "E  ·  Tiếp tục")

func _resume_notice_board_stage() -> void:
	if beat != Beat.NIGHT_SCHOOL or night_school_visual == null:
		return
	night_school_visual.call("resume_notice_board_stage")
	night_school_visual.call("reveal_mirror_writing")
	GameState.mark_mirror_message_seen()
	GameState.mark_ghost_revealed()
	GameState.unlock_notice_board_objective()
	GameState.set_story_time(STORY_TIMES.scene_05)
	GameState.set_checkpoint("scene_05", "notice_board")
	GameState.set_objective("FIND_MYSTERIOUS_GIRL")
	night_phase = "scene56_explore"
	objective.text = "MỤC TIÊU  ·  Tìm hiểu cô gái bí ẩn."
	prompt.text = "WASD di chuyển · Đi tới bảng tin cuối hành lang"

func _resume_scene56_stage() -> void:
	if beat != Beat.NIGHT_SCHOOL or night_school_visual == null:
		return
	GameState.set_story_time(STORY_TIMES.scene_05)
	night_phase = "scene56_explore"
	night_school_visual.call("resume_notice_board_stage")
	if GameState.scene_id == "scene_06" and bool(GameState.flags.get("a17_locker_open", false)):
		night_school_visual.call("open_locker_a17")
	if bool(GameState.flags.get("diary_solved", false)) and not GameState.inventory.has("math_test"):
		night_school_visual.call("set_math_test_visible", true)
	_scene56_update_quest_objective()

func _scene56_update_quest_objective() -> void:
	if GameState.inventory.has("math_test"):
		GameState.set_objective("COLLECT_FIRST_KEEPSAKE")
		objective.text = "KỶ VẬT 1/6  ·  Bài kiểm tra Toán 100/100 đã được lưu."
	elif bool(GameState.flags.get("diary_solved", false)):
		GameState.set_objective("COLLECT_FIRST_KEEPSAKE")
		objective.text = "MỤC TIÊU  ·  Nhặt bài kiểm tra Toán 100/100."
	elif bool(GameState.flags.get("a17_locker_open", false)):
		GameState.set_objective("REASSEMBLE_DIARY")
		objective.text = "MỤC TIÊU  ·  Ghép sáu mảnh nhật ký bị xé."
	elif _scene56_has_evidence("an_locker_code_a17"):
		GameState.set_objective("FIND_LOCKER_A17")
		objective.text = "MỤC TIÊU  ·  Tìm tủ đồ A-17."
	elif _scene56_has_evidence("an_name_nguyen_ngoc_an"):
		GameState.set_objective("IDENTIFY_AN")
		objective.text = "MỤC TIÊU  ·  Xác định nữ sinh trong bức ảnh."
	elif GameState.current_objective == "INSPECT_BULLETIN_BOARD":
		objective.text = "MỤC TIÊU  ·  Xem kỹ các giấy tờ trên bảng tin."
	else:
		GameState.set_objective("FIND_MYSTERIOUS_GIRL")
		objective.text = "MỤC TIÊU  ·  Tìm hiểu cô gái bí ẩn."
	if GameState.inventory.has("math_test"):
		prompt.text = "Kỷ vật đã được lưu vào hồ sơ An."
	elif GameState.scene_id == "scene_06" and bool(GameState.flags.get("diary_solved", false)):
		prompt.text = "E  ·  Nhặt bài kiểm tra Toán 100/100"
	elif GameState.scene_id == "scene_06" and bool(GameState.flags.get("a17_locker_open", false)):
		prompt.text = "E  ·  Xem sáu mảnh nhật ký"
	elif GameState.scene_id == "scene_06":
		prompt.text = "WASD di chuyển · Tìm tủ đồ A-17"
	else:
		prompt.text = "WASD di chuyển · [E] Xem bảng tin"

func _scene56_has_evidence(clue_id: String) -> bool:
	var clue: Variant = GameState.evidence.get(clue_id, false)
	if clue is Dictionary:
		return clue.get("discovered", false) == true
	return clue == true

func _resume_mirror_stage() -> void:
	if beat != Beat.NIGHT_SCHOOL or night_school_visual == null:
		return
	night_school_visual.call("resume_mirror_stage")
	night_school_visual.call("reveal_mirror_writing")
	night_school_visual.call("set_controls_enabled", true)
	objective.text = "Dòng chữ đỏ trên gương: CỨU TÔI"
	prompt.text = "WASD di chuyển · E khi đứng gần gương"

func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"run": [KEY_SHIFT],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var key := InputEventKey.new()
			key.keycode = keycode
			InputMap.action_add_event(action, key)

func _process(delta: float) -> void:
	# Compatibility projection is never the movement authority. Explicit
	# assignments (checkpoint restore and older harnesses) are one-way warps.
	_sync_external_player()
	if active_room == "hallway" and hallway_visual != null:
		player = hallway_visual.call("get_projected_position") as Vector2
	elif active_room == "restroom" and restroom_visual != null:
		player = restroom_visual.call("get_projected_position") as Vector2
	elif active_room == "classroom" and classroom_visual != null:
		player = classroom_visual.call("get_projected_position") as Vector2
	last_projected_player = player
	if clock_label != null:
		clock_label.text = "◷  " + GameState.story_time
	_process_opening_sequence(delta)
	_process_night_school(delta)
	_sync_prompt_presentation()
	if beat == Beat.CLASSROOM and classroom_read and hallway_visual.get("restroom_door_open"):
		var hallway_position: Vector3 = hallway_visual.call("get_player_position")
		if hallway_position.z < -13.55:
			_enter_restroom()
	if beat == Beat.HALLWAY and exit_transition_pending and hallway_visual.get("restroom_door_open"):
		var exit_position: Vector3 = hallway_visual.call("get_player_position")
		if exit_position.z < -13.55:
			_start_night_school()
	if beat == Beat.TOILET and not is_hidden:
		hide_time -= delta
		objective.text = "NÚP! Còn %.1f giây  ·  Buồng phát sáng bên trái" % maxf(hide_time, 0.0)
		if hide_time <= 0.0:
			beat = Beat.DEAD
			AudioDirector.play_sfx("death_hit")
			GameState.set_checkpoint("scene_03", "toilet_retry")
			_show_beat()
	elif beat == Beat.TOILET and is_hidden:
		hide_staging_remaining -= delta
		if hide_staging_remaining <= 0.0:
			is_hidden = false
			beat = Beat.MIRROR
			_show_beat()
	if beat == Beat.LETTER and letter_reveal_remaining > 0.0:
		letter_reveal_remaining = maxf(letter_reveal_remaining - delta, 0.0)
		if letter_reveal_remaining == 0.0:
			_show_beat()
	if beat == Beat.LETTER and letter_close_reveal_remaining > 0.0:
		letter_close_reveal_remaining = maxf(letter_close_reveal_remaining - delta, 0.0)
		if letter_close_reveal_remaining == 0.0:
			beat = Beat.CLASSROOM
			classroom_read = false
			GameState.set_checkpoint("scene_02", "classroom_letters")
			_show_beat()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if active_room == "hallway":
			hallway_visual.call("orbit_mouse", event.relative)
		elif active_room == "restroom":
			restroom_visual.call("orbit_mouse", event.relative)
		elif active_room == "classroom":
			classroom_visual.call("orbit_mouse", event.relative)
		elif active_room == "night_school":
			night_school_visual.call("orbit_mouse", event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not scene56_mode.is_empty():
				_close_scene56_panel()
			elif opening_phase == "scene01_letter_inspect":
				_close_scene01_letter_inspection()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_interact()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			if scene56_mode == "diary":
				_diary_choose_slot(int(event.keycode - KEY_1))
			else:
				selected_inventory_slot = int(event.keycode - KEY_1)
				_refresh_inventory_bar()
		elif event.keycode == KEY_F and scene56_mode == "board":
			_scene56_flip_photo()
		elif event.keycode in [KEY_LEFT, KEY_A] and scene56_mode == "board":
			_scene56_select_board_item(-1)
		elif event.keycode in [KEY_RIGHT, KEY_D] and scene56_mode == "board":
			_scene56_select_board_item(1)
		elif event.keycode == KEY_F and beat in [Beat.HALLWAY, Beat.CLASSROOM, Beat.TOILET, Beat.MIRROR, Beat.NIGHT_SCHOOL]:
			if selected_inventory_slot != 0:
				return
			if active_room == "hallway":
				hallway_visual.call("toggle_flashlight")
			elif active_room == "restroom":
				restroom_visual.call("toggle_flashlight")
			elif active_room == "classroom":
				classroom_visual.call("toggle_flashlight")
			elif active_room == "night_school":
				night_school_visual.call("toggle_flashlight")
	elif event is InputEventMouseButton and event.pressed and beat == Beat.DEAD:
		if retry_button.get_global_rect().has_point(event.position):
			_retry()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.visible and (scene56_panel == null or not scene56_panel.visible) and (scene56_memory_overlay == null or not scene56_memory_overlay.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _interact() -> void:
	_sync_external_player()
	if beat == Beat.NIGHT_SCHOOL:
		if night_is_dead:
			return
		_interact_night_school()
		return
	if not opening_phase.is_empty():
		_advance_opening_sequence()
		return
	if beat == Beat.TOILET and is_hidden:
		return
	if beat != Beat.DEAD and active_room == "hallway" and hallway_visual.call("is_interacting"):
		return
	if beat != Beat.DEAD and active_room == "restroom" and restroom_visual.call("is_interacting"):
		return
	match beat:
		Beat.HALLWAY:
			if not letter_found and hallway_visual.call("near_letter"):
				_begin_scene01_letter_inspection()
			elif afternoon_exit_available and hallway_visual.call("near_restroom_door"):
				hallway_visual.call("play_interaction")
				hallway_visual.call("open_restroom_door")
				afternoon_exit_available = false
				exit_transition_pending = true
				GameState.set_flag("afternoon_exit_opened")
				objective.text = "Cửa thoát đã mở · bước ra ngoài"
				prompt.text = "WASD di chuyển"
		Beat.LETTER:
			if letter_reveal_remaining > 0.0 or letter_close_reveal_remaining > 0.0:
				return
			# Legacy letter state no longer reveals the letter in the corridor.
			beat = Beat.CLASSROOM
			opening_phase = "classroom_establish"
			opening_timer = 1.5
			_show_beat()
		Beat.CLASSROOM:
			if not classroom_read and panel.visible:
				panel.visible = false
				classroom_intro_dismissed = true
				classroom_visual.call("set_controls_enabled", true)
				_show_beat()
			elif not classroom_read and classroom_visual.call("near_desk"):
				classroom_visual.call("play_interaction")
				classroom_read = true
				player = Vector2(480, 405)
				_show_beat()
			elif classroom_read and hallway_visual.call("near_restroom_door"):
				hallway_visual.call("play_interaction")
				hallway_visual.call("open_restroom_door")
				objective.text = "Cửa đã mở · bước qua ngưỡng cửa"
		Beat.TOILET:
			if restroom_visual.call("near_stall_door") and not restroom_visual.get("stall_door_open"):
				restroom_visual.call("play_interaction")
				restroom_visual.call("open_hide_stall")
			elif restroom_visual.call("inside_hide_stall"):
				is_hidden = true
				hide_staging_remaining = HIDE_STAGING_SECONDS
				GameState.set_flag("survived_toilet_event")
				GameState.set_checkpoint("scene_04", "mirror_search")
				_show_beat()
		Beat.MIRROR:
			if restroom_visual.call("near_mirror"):
				restroom_visual.call("play_interaction")
				beat = Beat.REFLECTION
				AudioDirector.play_sfx("mirror_sting")
				_show_beat()
		Beat.REFLECTION:
			beat = Beat.GHOST
			_show_beat()
		Beat.GHOST:
			GameState.set_checkpoint("scene_05", "notice_board")
			GameState.save_game()
			get_tree().change_scene_to_file("res://scenes/05_bang_tin.tscn")
		Beat.DEAD:
			_retry()

func _interact_night_school() -> void:
	_sync_night_school_upper_hall_from_position()
	if not scene56_mode.is_empty() or night_phase == "scene56_explore":
		_interact_scene56()
		return
	if night_phase == "friend_bao_line":
		_dismiss_night_line()
		night_phase = "friend_lan_line"
		_show_night_line("Lân", "Tao thấy không ổn.", "E  ·  Tiếp tục")
	elif night_phase == "friend_lan_line":
		_dismiss_night_line()
		night_phase = "gang_search_before_red"
		night_school_visual.call("play_stick_scrape")
		_show_night_line("Đầu gấu", "Nó chạy đâu rồi?", "E  ·  Tiếp tục")
	elif night_phase == "gang_search_before_red":
		_dismiss_night_line()
		night_phase = "red_warning"
		night_timer = .45
		night_school_visual.call("set_red_realm", true)
		night_school_visual.call("hide_friends")
		night_red_overlay.visible = true
		night_red_overlay.color.a = .30
	elif night_phase == "warning_line":
		_dismiss_night_line()
		night_phase = "find_stall"
		night_hide_timer = HIDE_SECONDS
		GameState.set_checkpoint("scene_03", "restroom_threat")
		night_school_visual.call("set_controls_enabled", true)
		objective.text = "Trốn vào một buồng vệ sinh ngay!"
		prompt.text = "E  ·  Mở cửa buồng rồi E để nấp"
	elif night_phase == "yard" and night_school_visual.call("near_main_entry"):
		_enter_night_school_ground_hall()
	elif night_phase == "ground_hall" and night_school_visual.call("near_stairwell"):
		night_school_visual.call("enter_stairs")
		night_phase = "stairs"
		objective.text = "Tầng 3 · Đi lên cầu thang"
		prompt.text = "WASD di chuyển · Lên ba tầng"
	elif night_phase == "upper_hall" and night_school_visual.call("near_restroom_door"):
		night_school_visual.call("open_restroom_entry")
		night_phase = "entering_restroom"
		prompt.text = "Cửa mở · bước vào nhà vệ sinh"
	elif night_phase == "find_stall" and night_school_visual.call("inside_stall"):
		night_school_visual.call("set_hidden", true)
		night_phase = "gang_arrival"
		night_timer = .65
		objective.text = "Nín thở. Có người đang phá cửa vào."
		prompt.text = ""

	elif night_phase == "find_stall" and night_school_visual.call("near_stall_door"):
		night_school_visual.call("open_stall")
		objective.text = "Buồng đã mở · đi vào trong rồi nhấn E để trốn"
		prompt.text = "E  ·  Trốn trong buồng"
	elif night_phase == "bell_line":
		_dismiss_night_line()
		night_phase = "wait_exit"
		objective.text = "Tiếng bước chân đang xa dần · E rời khỏi buồng"
		prompt.text = "E  ·  Mở cửa buồng"
	elif night_phase == "wait_exit":
		night_school_visual.call("open_stall")
		night_school_visual.call("set_hidden", false)
		night_phase = "exit_hiding"
		objective.text = "Ra khỏi buồng vệ sinh"
		prompt.text = "WASD  ·  Bước ra ngoài"
	elif night_phase == "after_stall_line":
		_dismiss_night_line()
		var red_fade := create_tween()
		red_fade.tween_property(night_red_overlay, "color:a", 0.0, .65)
		red_fade.tween_callback(func(): night_red_overlay.visible = false)
		night_school_visual.call("fade_red_realm", .65)
		night_school_visual.call("reveal_mirror_writing")
		night_school_visual.call("set_controls_enabled", true)
		GameState.mark_mirror_message_seen()
		night_school_visual.call("reveal_friend", 0)
		night_phase = "friend_bao"
		_show_night_line("Bảo", "Vừa rồi là cái quái gì?", "E  ·  Tiếp tục")
	elif night_phase == "friend_bao":
		night_school_visual.call("reveal_friend", 1)
		night_phase = "friend_huan"
		_show_night_line("Huân", "Không biết. Nhưng phải cẩn thận.", "E  ·  Tiếp tục")
	elif night_phase == "friend_huan":
		night_school_visual.call("reveal_friend", 2)
		night_phase = "friend_lan"
		_show_night_line("Lân", "Nhìn kìa...", "E  ·  Nhìn vào gương")
	elif night_phase == "friend_lan":
		_dismiss_night_line()
		night_phase = "mirror_search"
		objective.text = "Lân chỉ về phía gương"
		prompt.text = "WASD di chuyển · E khi đứng gần gương"
	elif night_phase == "mirror_search" and night_school_visual.call("near_mirror"):
		night_school_visual.call("show_mirror_apparition")
		night_school_visual.call("set_controls_enabled", false)
		night_phase = "mirror_ghost"
		_show_night_line("", "Trong gương, một nữ sinh đứng ngay sau Hoàng.", "E  ·  Quay lại")
	elif night_phase == "mirror_ghost":
		night_school_visual.call("turn_from_mirror")
		night_school_visual.call("hide_apparition")
		night_phase = "mirror_empty"
		_show_night_line("Hoàng", "Không có ai.", "E  ·  Tiếp tục")
	elif night_phase == "mirror_empty":
		_dismiss_night_line()
		night_school_visual.call("show_hallway_apparition")
		night_school_visual.call("focus_scene56_board")
		night_phase = "hallway_apparition"
		night_timer = 1.5
		night_school_visual.call("set_controls_enabled", false)
		_show_night_line("", "Ở cuối hành lang, nữ sinh nhìn về phía bảng tin rồi biến mất.", "")
	elif night_phase == "mirror_reveal":
		if night_school_visual.call("near_notice_board"):
			GameState.set_checkpoint("scene_05", "notice_board")
			_resume_notice_board_stage()

func _enter_night_school_ground_hall() -> void:
	if night_phase != "yard":
		return
	night_school_visual.call("enter_school")
	night_phase = "ground_hall"
	GameState.set_checkpoint("scene_03", "night_school_ground_hall")
	objective.text = "Tìm cầu thang lên tầng 3"
	prompt.text = "WASD di chuyển · Theo hành lang bên trái"

func _sync_night_school_upper_hall_from_position() -> void:
	if beat != Beat.NIGHT_SCHOOL or night_school_visual == null:
		return
	if night_phase not in ["yard", "ground_hall", "stairs"]:
		return
	if night_school_visual.get_player_position().y < 6.0:
		return
	night_school_visual.call("enter_upper_hall")
	night_phase = "upper_hall"
	objective.text = "TẦNG 3 · WC NAM  →  BÊN PHẢI"
	prompt.text = "Rẽ phải theo hành lang · Tìm biển WC NAM"

func _show_night_line(speaker: String, line: String, hint: String) -> void:
	opening_speaker.text = speaker
	opening_speaker.visible = not speaker.is_empty()
	opening_subtitle.text = line
	opening_hint.text = hint
	opening_card.visible = true

func _dismiss_night_line() -> void:
	opening_card.visible = false
	opening_speaker.visible = true

func _process_night_school(delta: float) -> void:
	if beat != Beat.NIGHT_SCHOOL:
		return
	if night_phase == "scene56_explore":
		_process_scene56_stage()
		return
	_sync_night_school_upper_hall_from_position()
	if night_phase == "yard" and night_school_visual.call("inside_mapped_school_from_yard"):
		_enter_night_school_ground_hall()
	if night_phase == "entering_restroom" and night_school_visual.call("crossed_restroom_threshold"):
		GameState.set_story_time(STORY_TIMES.restroom)
		night_school_visual.call("enter_restroom")
		night_school_visual.call("bring_friends_to_third_floor")
		night_phase = "friend_bao_line"
		night_timer = .65
		night_school_visual.call("set_controls_enabled", false)
		GameState.set_checkpoint("scene_03", "restroom_approach")
		_show_night_line("Bảo", "Tối thật đấy...", "E  ·  Tiếp tục")
	if night_phase == "exit_hiding" and night_school_visual.get_player_position().x < 13.2:
		night_phase = "after_stall_line"
		_show_night_line("Hoàng", "May quá, mà sao giờ con người ở trường", "E  ·  Tiếp tục")
	if night_phase == "ground_hall" and night_school_visual.call("near_stairwell"):
		objective.text = "Cầu thang lên tầng 3 ở bên trái"
		prompt.text = "E  ·  Vào cầu thang"
	if night_phase == "upper_hall" and night_school_visual.call("near_restroom_door"):
		objective.text = "Cửa nhà vệ sinh tầng 3"
		prompt.text = "E  ·  Mở cửa"
	if night_phase == "yard" and night_school_visual.call("near_main_entry"):
		objective.text = "Nhóm bạn đứng chờ trong sân trường"
		prompt.text = "E  ·  Vào trường"
	if night_phase == "red_warning":
		night_timer -= delta
		if night_timer <= 0.0:
			night_phase = "warning_line"
			night_school_visual.call("set_controls_enabled", false)
			_show_night_line("An", "Trốn đi... bọn chúng tới rồi", "E  ·  Trốn ngay")
	if night_phase == "find_stall":
		night_hide_timer -= delta
		objective.text = "SURVIVAL EVENT 01  ·  %.1f GIÂY" % maxf(night_hide_timer, 0.0)
		prompt.text = "E  ·  Mở cửa buồng rồi E để nấp"
		if night_hide_timer <= 0.0:
			night_is_dead = true
			night_school_visual.call("set_controls_enabled", false)
			night_death_overlay.visible = true
			inventory_bar.visible = false
			inventory_hint.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
	if night_phase == "mirror_search" and night_school_visual.call("near_mirror"):
		objective.text = "Dòng chữ đỏ trên gương: CỨU TÔI"
		prompt.text = "E  ·  Nhìn vào gương"
	if night_phase == "mirror_reveal" and night_school_visual.call("near_notice_board"):
		objective.text = "Bảng tin cuối hành lang"
		prompt.text = "E  ·  Tiếp tục"
	if night_phase == "hallway_apparition":
		night_timer -= delta
		if night_timer <= 0.0:
			night_school_visual.call("hide_apparition")
			_dismiss_night_line()
			night_phase = "mirror_reveal"
			night_school_visual.call("set_third_person", true)
			night_school_visual.call("set_controls_enabled", true)
			GameState.mark_ghost_revealed()
			GameState.unlock_notice_board_objective()
			GameState.set_checkpoint("scene_04", "notice_board")
			objective.text = "Theo hướng nữ sinh vừa chỉ · Bảng tin ở cuối hành lang"
			prompt.text = "WASD  ·  Đi về phía bảng tin"
	if night_phase == "gang_arrival":
		night_timer -= delta
		if night_timer <= 0.0:
			night_school_visual.call("play_bathroom_door_breach")
			night_school_visual.call("gang_enters")
			night_phase = "bully_line"
			night_timer = 1.05
			_show_night_line("Đầu gấu", "Mẹ con chó, mày đầu đâu rồi", "")
			prompt.text = ""
		return
	if night_phase == "bully_line":
		night_timer -= delta
		if night_timer <= 0.0:
			night_phase = "first_bang"
			night_school_visual.call("play_stall_impact_sound")
			night_school_visual.call("impact_stall_door", 1)
			_show_night_line("", "RẦM!", "")
			night_timer = .55
		return
	if night_phase == "first_bang" or night_phase == "second_bang":
		night_timer -= delta
		if night_timer <= 0.0 and night_phase == "first_bang":
			night_phase = "second_bang"
			night_school_visual.call("play_stall_impact_sound")
			night_school_visual.call("impact_stall_door", 2)
			_show_night_line("", "RẦM!", "")
			night_timer = .52
		elif night_timer <= 0.0:
			night_phase = "bell_chime"
			night_bell_remaining = 3
			night_timer = 0.0
		return
	if night_phase == "bell_chime":
		night_timer -= delta
		if night_timer <= 0.0:
			night_school_visual.call("play_school_bell")
			night_bell_remaining -= 1
			if night_bell_remaining <= 0:
				night_phase = "bell_line"
				_show_night_line("Đầu gấu", "Mày may đó con chó", "E  ·  Tiếp tục")
			else:
				night_timer = .34
		return


func _enter_restroom() -> void:
	GameState.set_story_time(STORY_TIMES.restroom)
	player = Vector2(360, 417)
	beat = Beat.TOILET
	is_hidden = false
	hide_time = HIDE_SECONDS
	GameState.set_checkpoint("scene_03", "toilet_hide")
	_show_beat()

func _start_night_school() -> void:
	if not exit_transition_pending:
		return
	exit_transition_pending = false
	hallway_visual.call("set_controls_enabled", false)
	cinematic_black.visible = true
	cinematic_black.color.a = 0.0
	var fade_out := create_tween()
	fade_out.tween_property(cinematic_black, "color:a", 1.0, .35)
	fade_out.tween_callback(_finish_night_school_transition)

func _finish_night_school_transition() -> void:
	beat = Beat.NIGHT_SCHOOL
	GameState.set_story_time(STORY_TIMES.night_arrival)
	letter_found = true
	is_hidden = false
	night_phase = "yard"
	night_timer = 0.0
	GameState.set_flag("afternoon_exit_opened")
	GameState.set_checkpoint("scene_03", "night_school_yard")
	AudioDirector.set_ambience("school_night")
	_show_beat()
	objective.text = "%s · Sân trường · Nhóm bạn đang chờ" % GameState.story_time
	prompt.text = "WASD di chuyển · E vào trường"
	night_school_visual.call("set_controls_enabled", false)
	var fade_in := create_tween()
	fade_in.tween_property(cinematic_black, "color:a", 0.0, .45)
	fade_in.tween_callback(func():
		cinematic_black.visible = false
		night_school_visual.call("set_controls_enabled", true)
	)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.68)
	overlay.visible = false
	layer.add_child(overlay)

	panel = PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_top = 0.12
	panel.anchor_right = 0.88
	panel.anchor_bottom = 0.88
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.visible = false
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	dialogue_prompt_column = column

	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color("#e9e2d5"))
	message.add_theme_font_size_override("font_size", 22)
	column.add_child(message)

	prompt = Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color("#d4ad7a"))
	prompt.add_theme_font_size_override("font_size", 17)
	column.add_child(prompt)
	prompt_hud = PanelContainer.new()
	prompt_hud.name = "GameplayPromptHUD"
	prompt_hud.anchor_left = .08
	prompt_hud.anchor_top = 1.0
	prompt_hud.anchor_right = .92
	prompt_hud.anchor_bottom = 1.0
	prompt_hud.offset_top = -132
	prompt_hud.offset_bottom = -92
	prompt_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prompt_hud_style := StyleBoxFlat.new()
	prompt_hud_style.bg_color = Color(0.045, 0.047, 0.061, 0.9)
	prompt_hud_style.border_color = Color(0.39, 0.32, 0.26, 0.8)
	prompt_hud_style.set_border_width_all(1)
	prompt_hud_style.set_corner_radius_all(5)
	prompt_hud_style.content_margin_left = 12
	prompt_hud_style.content_margin_right = 12
	prompt_hud_style.content_margin_top = 4
	prompt_hud_style.content_margin_bottom = 4
	prompt_hud.add_theme_stylebox_override("panel", prompt_hud_style)
	prompt_hud.visible = false
	layer.add_child(prompt_hud)

	objective = Label.new()
	objective.position = Vector2(22, 42)
	objective.add_theme_color_override("font_color", Color("#dfd7c9"))
	objective.add_theme_font_size_override("font_size", 16)
	layer.add_child(objective)
	night_red_overlay = ColorRect.new()
	night_red_overlay.name = "NightmareRedOverlay"
	night_red_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_red_overlay.color = Color(0.72, 0.015, 0.025, 0.0)
	night_red_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_red_overlay.visible = false
	night_red_overlay.z_index = 8
	layer.add_child(night_red_overlay)
	night_death_overlay = ColorRect.new()
	night_death_overlay.name = "NightSchoolRetryOverlay"
	night_death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_death_overlay.color = Color(0,0,0,.96)
	night_death_overlay.visible = false
	night_death_overlay.z_index = 14
	layer.add_child(night_death_overlay)
	var death_text := Label.new()
	death_text.text = "YOU DIED\n\nHoàng không kịp trốn."
	death_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	death_text.position = Vector2(-250, 170)
	death_text.size = Vector2(500, 130)
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_text.add_theme_font_size_override("font_size", 34)
	death_text.add_theme_color_override("font_color", Color("#e9e2d5"))
	night_death_overlay.add_child(death_text)
	var death_retry := Button.new()
	death_retry.text = "THỬ LẠI TỪ CỬA NHÀ VỆ SINH"
	death_retry.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	death_retry.position = Vector2(-155, 330)
	death_retry.size = Vector2(310, 56)
	death_retry.pressed.connect(_retry)
	night_death_overlay.add_child(death_retry)
	# These two short WAVs are original synthesized foley from the user's local
	# NEH School project (assets/audio/door.wav and school_bell.wav).
	night_door_sfx = AudioStreamPlayer.new()
	night_door_sfx.stream = load("res://assets/audio/sfx/night_door_thud.wav") as AudioStream
	night_door_sfx.volume_db = -4.0
	layer.add_child(night_door_sfx)
	# Original locally synthesized metal-on-tile scrape and two rod taps.
	night_stick_sfx = AudioStreamPlayer.new()
	night_stick_sfx.stream = load("res://assets/audio/sfx/night_stick_scrape.wav") as AudioStream
	night_stick_sfx.volume_db = -5.0
	layer.add_child(night_stick_sfx)
	school_bell_sfx = AudioStreamPlayer.new()
	school_bell_sfx.stream = load("res://assets/audio/sfx/school_bell.wav") as AudioStream
	school_bell_sfx.volume_db = -8.0
	layer.add_child(school_bell_sfx)
	clock_label = Label.new()
	clock_label.name = "InGameClock"
	clock_label.position = Vector2(22, 12)
	clock_label.text = "◷  " + GameState.story_time
	clock_label.add_theme_color_override("font_color", Color("#e6d7bd"))
	clock_label.add_theme_font_size_override("font_size", 18)
	clock_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .9))
	clock_label.add_theme_constant_override("shadow_offset_x", 1)
	clock_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(clock_label)
	_build_inventory_bar(layer)
	_build_scene56_ui(layer)

	retry_button = Button.new()
	retry_button.text = "THỬ LẠI"
	retry_button.custom_minimum_size = Vector2(190, 54)
	retry_button.size = retry_button.custom_minimum_size
	retry_button.anchor_left = 0.5
	retry_button.anchor_right = 0.5
	retry_button.anchor_top = 0.73
	retry_button.anchor_bottom = 0.73
	retry_button.offset_left = -95
	retry_button.offset_right = 95
	retry_button.offset_top = -27
	retry_button.offset_bottom = 27
	retry_button.pressed.connect(_retry)
	layer.add_child(retry_button)
	opening_card = PanelContainer.new()
	opening_card.name = "CinematicDialogueCard"
	opening_card.z_index = 11
	opening_card.anchor_left = .12
	opening_card.anchor_right = .88
	opening_card.anchor_top = .72
	opening_card.anchor_bottom = .96
	opening_card.add_theme_stylebox_override("panel", _panel_style())
	opening_card.visible = false
	layer.add_child(opening_card)
	var dialogue_column := VBoxContainer.new()
	dialogue_column.add_theme_constant_override("separation", 6)
	opening_card.add_child(dialogue_column)
	opening_speaker = Label.new()
	opening_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_speaker.add_theme_color_override("font_color", Color("#d4ad7a"))
	opening_speaker.add_theme_font_size_override("font_size", 17)
	dialogue_column.add_child(opening_speaker)
	opening_subtitle = Label.new()
	opening_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opening_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opening_subtitle.add_theme_color_override("font_color", Color("#f4eee3"))
	opening_subtitle.add_theme_font_size_override("font_size", 22)
	dialogue_column.add_child(opening_subtitle)
	opening_hint = Label.new()
	opening_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_hint.add_theme_color_override("font_color", Color("#b9a994"))
	opening_hint.add_theme_font_size_override("font_size", 14)
	dialogue_column.add_child(opening_hint)
	opening_letter_card = PanelContainer.new()
	opening_letter_card.name = "Scene01LetterInspection"
	opening_letter_card.z_index = 11
	opening_letter_card.anchor_left = .24
	opening_letter_card.anchor_right = .76
	opening_letter_card.anchor_top = .22
	opening_letter_card.anchor_bottom = .78
	opening_letter_card.add_theme_stylebox_override("panel", _panel_style())
	opening_letter_card.visible = false
	layer.add_child(opening_letter_card)
	var letter_column := VBoxContainer.new()
	letter_column.alignment = BoxContainer.ALIGNMENT_CENTER
	letter_column.add_theme_constant_override("separation", 18)
	opening_letter_card.add_child(letter_column)
	var letter_heading := Label.new()
	letter_heading.text = "MẶT TRƯỚC PHONG BÌ"
	letter_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_heading.add_theme_color_override("font_color", Color("#cdb89c"))
	letter_heading.add_theme_font_size_override("font_size", 16)
	letter_column.add_child(letter_heading)
	opening_letter_contents = Label.new()
	opening_letter_contents.text = "CỨU TÔI"
	opening_letter_contents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_letter_contents.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opening_letter_contents.add_theme_color_override("font_color", Color("#f4eee3"))
	opening_letter_contents.add_theme_font_size_override("font_size", 42)
	letter_column.add_child(opening_letter_contents)
	var letter_close_hint := Label.new()
	letter_close_hint.text = "Esc  ·  Đóng lá thư"
	letter_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_close_hint.add_theme_color_override("font_color", Color("#b9a994"))
	letter_close_hint.add_theme_font_size_override("font_size", 15)
	letter_column.add_child(letter_close_hint)
	cinematic_black = ColorRect.new()
	cinematic_black.name = "CinematicFade"
	cinematic_black.z_index = 10
	cinematic_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic_black.color = Color.BLACK
	cinematic_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_black.visible = false
	layer.add_child(cinematic_black)
	# Keep the fade beneath subtitle/letter cards in CanvasLayer draw order.
	layer.move_child(cinematic_black, opening_card.get_index())
	chapter_card = Label.new()
	chapter_card.name = "ChapterHandoffCard"
	chapter_card.z_index = 12
	chapter_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_card.add_theme_color_override("font_color", Color("#eee3d3"))
	chapter_card.add_theme_font_size_override("font_size", 30)
	chapter_card.text = "CHAPTER 01 — TIẾNG GẬY TRONG ĐÊM"
	chapter_card.visible = false
	layer.add_child(chapter_card)

func _build_scene56_ui(layer: CanvasLayer) -> void:
	scene56_case_file_button = Button.new()
	scene56_case_file_button.name = "AnCaseFileButton"
	scene56_case_file_button.text = "HỒ SƠ AN"
	scene56_case_file_button.position = Vector2(814, 12)
	scene56_case_file_button.size = Vector2(128, 36)
	scene56_case_file_button.add_theme_font_size_override("font_size", 13)
	scene56_case_file_button.pressed.connect(_open_an_case_file)
	scene56_case_file_button.visible = false
	layer.add_child(scene56_case_file_button)

	scene56_dimmer = ColorRect.new()
	scene56_dimmer.name = "Scene56InspectionDimmer"
	scene56_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene56_dimmer.color = Color(0.015, 0.02, 0.025, .68)
	scene56_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	scene56_dimmer.visible = false
	scene56_dimmer.z_index = 18
	layer.add_child(scene56_dimmer)

	scene56_panel = PanelContainer.new()
	scene56_panel.name = "Scene56InspectionPanel"
	scene56_panel.anchor_left = .09
	scene56_panel.anchor_top = .10
	scene56_panel.anchor_right = .91
	scene56_panel.anchor_bottom = .90
	scene56_panel.add_theme_stylebox_override("panel", _panel_style())
	scene56_panel.visible = false
	scene56_panel.z_index = 19
	layer.add_child(scene56_panel)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 14)
	scene56_panel.add_child(root_column)
	scene56_panel_title = Label.new()
	scene56_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene56_panel_title.add_theme_color_override("font_color", Color("#d4ad7a"))
	scene56_panel_title.add_theme_font_size_override("font_size", 23)
	root_column.add_child(scene56_panel_title)
	scene56_panel_text = RichTextLabel.new()
	scene56_panel_text.bbcode_enabled = false
	scene56_panel_text.fit_content = true
	scene56_panel_text.scroll_active = false
	scene56_panel_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene56_panel_text.add_theme_color_override("default_color", Color("#e9e2d5"))
	scene56_panel_text.add_theme_font_size_override("normal_font_size", 18)
	root_column.add_child(scene56_panel_text)
	scene56_diary_grid = GridContainer.new()
	scene56_diary_grid.columns = 2
	scene56_diary_grid.add_theme_constant_override("h_separation", 12)
	scene56_diary_grid.add_theme_constant_override("v_separation", 10)
	root_column.add_child(scene56_diary_grid)
	scene56_controls = HBoxContainer.new()
	scene56_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	scene56_controls.add_theme_constant_override("separation", 10)
	root_column.add_child(scene56_controls)
	var hint := Label.new()
	hint.text = "Chuột để chọn · E xem kỹ · F lật ảnh · Esc đóng"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#b9a994"))
	hint.add_theme_font_size_override("font_size", 13)
	root_column.add_child(hint)

	scene56_memory_overlay = ColorRect.new()
	scene56_memory_overlay.name = "FirstKeepsakeMemoryWarmth"
	scene56_memory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene56_memory_overlay.color = Color(.40, .20, .08, .46)
	scene56_memory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene56_memory_overlay.visible = false
	scene56_memory_overlay.z_index = 17
	layer.add_child(scene56_memory_overlay)
	var memory_caption := PanelContainer.new()
	memory_caption.anchor_left = .18
	memory_caption.anchor_right = .82
	memory_caption.anchor_top = .74
	memory_caption.anchor_bottom = .94
	memory_caption.add_theme_stylebox_override("panel", _panel_style())
	memory_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene56_memory_overlay.add_child(memory_caption)
	var memory_text := Label.new()
	memory_text.name = "FirstKeepsakeMemoryCaption"
	memory_text.text = "HỒI ỨC\nAn vui mừng khoe bài kiểm tra Toán 100/100 với mẹ."
	memory_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memory_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	memory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_text.add_theme_color_override("font_color", Color("#f6e5c9"))
	memory_text.add_theme_font_size_override("font_size", 20)
	memory_caption.add_child(memory_text)

func _scene56_add_button(label: String, callback: Callable, minimum := Vector2(130, 42)) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = minimum
	button.pressed.connect(callback)
	scene56_controls.add_child(button)
	return button

func _scene56_clear_controls() -> void:
	for child in scene56_controls.get_children():
		scene56_controls.remove_child(child)
		child.queue_free()
	for child in scene56_diary_grid.get_children():
		scene56_diary_grid.remove_child(child)
		child.queue_free()

func _scene56_show_panel(title: String, body: String) -> void:
	scene56_panel_title.text = title
	scene56_panel_text.text = body
	scene56_panel.visible = true
	scene56_dimmer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _scene56_record_clue(clue_id: String, name: String, description: String, source: String) -> void:
	if GameState.evidence.has(clue_id):
		return
	GameState.set_evidence(clue_id, {
		"name": name,
		"description": description,
		"discovered": true,
		"source": source,
	})

func _scene56_open_board() -> void:
	if not scene56_mode.is_empty():
		return
	scene56_mode = "board"
	night_school_visual.call("begin_scene56_inspection", "board")
	GameState.set_objective("INSPECT_BULLETIN_BOARD")
	_scene56_refresh_board_panel()
	prompt.text = "A/D chọn · E xem kỹ · F lật ảnh · Esc đóng"

func _scene56_board_item_summary() -> String:
	match scene56_selected_board_item:
		0:
			return "Giấy khen học sinh cũ. Phần tên đã nhòe; đây là tư liệu thông thường."
		1:
			return "Ảnh hoạt động của trường. Không có chi tiết liên quan đến cô gái bí ẩn."
		2:
			if scene56_photo_back_revealed:
				return "Mặt sau ảnh: A-17.\n\nBảo: \"An... là người đã mất tháng trước.\"\nHoàng: \"Đi tìm tủ đồ của cậu ấy.\""
			if scene56_photo_front_revealed:
				return "NGUYỄN NGỌC AN\nGIẢI NHẤT CỜ VUA\n18/04\n\nBảo: \"An... là người đã mất tháng trước.\"\nHoàng: \"Đi tìm tủ đồ của cậu ấy.\"\n\nNhấn F hoặc Lật ảnh để xem mặt sau."
			return "Một bức ảnh trao giải cờ vua. Khuôn mặt nữ sinh bị gạch đen.\n\nChọn “Xem kỹ” để đọc phần còn lại."
		3:
			return "Thông báo câu lạc bộ cờ vua, ghim bằng đinh đồng đã cũ."
		4:
			return "Danh sách thành tích của học sinh trong trường."
		_:
			return "Thông báo sinh hoạt của trường."

func _scene56_refresh_board_panel() -> void:
	_scene56_clear_controls()
	var item_names := ["Giấy khen", "Ảnh hoạt động", "Ảnh bị bôi đen", "Thông báo CLB", "Danh sách thành tích", "Thông báo trường"]
	_scene56_show_panel("BẢNG TIN TẦNG 3 · XEM BẢNG TIN", "%s\n\nMục %d/6 · %s" % [_scene56_board_item_summary(), scene56_selected_board_item + 1, item_names[scene56_selected_board_item]])
	_scene56_add_button("‹ Trước", Callable(self, "_scene56_select_board_item").bind(-1))
	_scene56_add_button("Xem kỹ", _scene56_inspect_board_item)
	_scene56_add_button("Lật ảnh", _scene56_flip_photo)
	_scene56_add_button("Sau ›", Callable(self, "_scene56_select_board_item").bind(1))
	_scene56_add_button("Đóng", _close_scene56_panel)

func _scene56_select_board_item(step: int) -> void:
	if scene56_mode != "board":
		return
	scene56_selected_board_item = wrapi(scene56_selected_board_item + step, 0, 6)
	_scene56_refresh_board_panel()

func _scene56_inspect_board_item() -> void:
	if scene56_selected_board_item != 2:
		_scene56_refresh_board_panel()
		return
	if not scene56_photo_front_revealed:
		scene56_photo_front_revealed = true
		_scene56_record_clue("an_name_nguyen_ngoc_an", "Nguyễn Ngọc An", "Tên trên bức ảnh bị bôi đen.", "Bảng tin tầng 3 · mặt trước ảnh")
		_scene56_record_clue("an_chess_first_prize", "Giải nhất cờ vua", "Dòng chữ trên bức ảnh ghi giải nhất cờ vua.", "Bảng tin tầng 3 · mặt trước ảnh")
		_scene56_record_clue("an_photo_date_18_04", "Ngày 18/04", "Ngày in trên bức ảnh: 18/04.", "Bảng tin tầng 3 · mặt trước ảnh")
		GameState.set_checkpoint("scene_05", "board_portrait")
		GameState.set_objective("IDENTIFY_AN")
	_scene56_refresh_board_panel()

func _scene56_flip_photo() -> void:
	if scene56_mode != "board" or scene56_selected_board_item != 2:
		return
	if not scene56_photo_front_revealed:
		_scene56_show_panel("BỨC ẢNH", "Hãy xem kỹ mặt trước trước khi lật ảnh.")
		_scene56_add_button("Xem kỹ", _scene56_inspect_board_item)
		_scene56_add_button("Đóng", _close_scene56_panel)
		return
	if not scene56_photo_back_revealed:
		scene56_photo_back_revealed = true
		_scene56_record_clue("an_locker_code_a17", "Mã tủ A-17", "Mặt sau ảnh ghi mã tủ đồ A-17.", "Bảng tin tầng 3 · mặt sau ảnh")
		GameState.set_checkpoint("scene_05", "board_reverse")
		GameState.set_objective("FIND_LOCKER_A17")
	_scene56_refresh_board_panel()

func _open_an_case_file() -> void:
	if beat != Beat.NIGHT_SCHOOL or scene56_dimmer.visible:
		return
	scene56_mode = "journal"
	scene56_case_file_mouse_mode = Input.mouse_mode
	night_school_visual.call("set_controls_enabled", false)
	var entries: Array[String] = []
	var evidence_order := [
		"an_name_nguyen_ngoc_an", "an_chess_first_prize", "an_photo_date_18_04", "an_locker_code_a17",
		"diary_03_09", "diary_12_09", "diary_18_09",
	]
	for clue_id in evidence_order:
		if not GameState.evidence.has(clue_id):
			continue
		var clue: Variant = GameState.evidence[clue_id]
		if _scene56_has_evidence(clue_id):
			var clue_name := str(clue_id).replace("_", " ").capitalize()
			var clue_description := "Manh mối này đã được phát hiện trong hồ sơ cũ."
			if clue is Dictionary:
				clue_name = str(clue.get("name", clue_name))
				clue_description = str(clue.get("description", clue_description))
			entries.append("• %s\n  %s" % [clue_name, clue_description])
	var body := "Chưa có manh mối nào được phát hiện." if entries.is_empty() else "\n\n".join(PackedStringArray(entries))
	_scene56_clear_controls()
	_scene56_show_panel("HỒ SƠ AN", body)
	_scene56_add_button("Đóng", _close_scene56_panel)

func _open_diary_puzzle() -> void:
	if not scene56_mode.is_empty():
		return
	scene56_mode = "diary"
	night_school_visual.call("begin_scene56_inspection", "locker")
	GameState.set_objective("REASSEMBLE_DIARY")
	_scene56_refresh_diary_panel()

func _scene56_refresh_diary_panel() -> void:
	_scene56_clear_controls()
	scene56_diary_grid.visible = not bool(GameState.flags.get("diary_solved", false))
	if bool(GameState.flags.get("diary_solved", false)):
		_scene56_show_panel("NHẬT KÝ ĐÃ GHÉP", "Ngày 03/09: \"Hôm nay mình được 100 điểm Toán. Mẹ vui lắm!\"\n\nNgày 12/09: \"Họ nói mình gian lận. Mình không làm vậy.\"\n\nNgày 18/09: \"Mình đã cầu cứu... nhưng chẳng ai nghe.\"\n\nHoàng: \"Cậu ấy từng rất hạnh phúc...\"\n\nMột tờ bài kiểm tra Toán 100/100 đang ở trong ngăn tủ. Hãy đóng trang này rồi nhặt nó.")
		scene56_controls.visible = true
		_scene56_add_button("Đóng · Esc", _close_scene56_panel)
		return
	scene56_panel_title.text = "NHẬT KÝ BỊ XÉ · GHÉP SÁU MẢNH"
	scene56_panel_text.text = "Ghép sáu mảnh theo thứ tự đọc từ trên xuống dưới. Kéo một mảnh lên mảnh khác để đổi chỗ, hoặc chọn hai mảnh bằng chuột/phím 1–6.\n\nNhấn Esc hoặc Đóng để dừng; vị trí hiện tại sẽ được giữ. Ghép sai không hoàn thành puzzle."
	scene56_panel.visible = true
	scene56_dimmer.visible = true
	scene56_controls.visible = true
	for slot in range(scene56_diary_piece_order.size()):
		var piece_id := scene56_diary_piece_order[slot]
		var piece_button := Scene56DiaryPieceButton.new()
		piece_button.slot_index = slot
		piece_button.drop_action = Callable(self, "_diary_drop_slots")
		piece_button.custom_minimum_size = Vector2(340, 56)
		piece_button.text = "%d  ·  Mảnh %d\n%s" % [slot + 1, piece_id + 1, SCENE56_DIARY_FRAGMENTS[piece_id]]
		piece_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if slot == scene56_selected_piece_slot:
			piece_button.modulate = Color("#edc77e")
		piece_button.pressed.connect(_diary_choose_slot.bind(slot))
		scene56_diary_grid.add_child(piece_button)
	if scene56_selected_piece_slot >= 0:
		scene56_panel_text.text += "\n\nĐã chọn vị trí %d. Chọn vị trí khác để đổi chỗ." % (scene56_selected_piece_slot + 1)
	_scene56_add_button("Hủy chọn", _diary_cancel_selection)
	_scene56_add_button("Đóng · Esc", _close_scene56_panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _diary_choose_slot(slot: int) -> void:
	if slot < 0 or slot >= scene56_diary_piece_order.size() or bool(GameState.flags.get("diary_solved", false)):
		return
	if scene56_selected_piece_slot < 0:
		scene56_selected_piece_slot = slot
		_scene56_refresh_diary_panel()
		return
	if scene56_selected_piece_slot == slot:
		scene56_selected_piece_slot = -1
		_scene56_refresh_diary_panel()
		return
	var from_slot := scene56_selected_piece_slot
	scene56_selected_piece_slot = -1
	_diary_drop_slots(from_slot, slot)

func _diary_drop_slots(from_slot: int, to_slot: int) -> void:
	if from_slot < 0 or from_slot >= scene56_diary_piece_order.size():
		return
	if to_slot < 0 or to_slot >= scene56_diary_piece_order.size() or from_slot == to_slot:
		return
	if bool(GameState.flags.get("diary_solved", false)):
		return
	var first_id := scene56_diary_piece_order[from_slot]
	scene56_diary_piece_order[from_slot] = scene56_diary_piece_order[to_slot]
	scene56_diary_piece_order[to_slot] = first_id
	scene56_selected_piece_slot = -1
	if scene56_diary_piece_order == [0, 1, 2, 3, 4, 5]:
		_scene56_complete_diary()
	else:
		_scene56_refresh_diary_panel()

func _diary_cancel_selection() -> void:
	scene56_selected_piece_slot = -1
	_scene56_refresh_diary_panel()

func _scene56_complete_diary() -> void:
	GameState.set_flag("diary_solved", true)
	_scene56_record_clue("diary_03_09", "Nhật ký · 03/09", "Hôm nay mình được 100 điểm Toán. Mẹ vui lắm!", "Nhật ký bị xé · trang đã ghép")
	_scene56_record_clue("diary_12_09", "Nhật ký · 12/09", "Họ nói mình gian lận. Mình không làm vậy.", "Nhật ký bị xé · trang đã ghép")
	_scene56_record_clue("diary_18_09", "Nhật ký · 18/09", "Mình đã cầu cứu... nhưng chẳng ai nghe.", "Nhật ký bị xé · trang đã ghép")
	GameState.set_objective("COLLECT_FIRST_KEEPSAKE")
	GameState.set_checkpoint("scene_06", "diary_reward")
	night_school_visual.call("set_math_test_visible", true)
	_scene56_refresh_diary_panel()

func _close_scene56_panel() -> void:
	if scene56_mode.is_empty():
		return
	var was_journal := scene56_mode == "journal"
	scene56_mode = ""
	scene56_panel.visible = false
	scene56_dimmer.visible = false
	scene56_diary_grid.visible = false
	if was_journal:
		night_school_visual.call("set_controls_enabled", true)
		Input.mouse_mode = scene56_case_file_mouse_mode
	else:
		night_school_visual.call("end_scene56_inspection")
	if night_phase == "scene56_explore":
		_process_scene56_stage()

func _interact_scene56() -> void:
	if scene56_mode == "board":
		_scene56_inspect_board_item()
		return
	if scene56_mode == "diary" or scene56_mode == "journal":
		return
	if bool(GameState.flags.get("diary_solved", false)) and not GameState.inventory.has("math_test") and night_school_visual.call("near_math_test"):
		_collect_first_keepsake()
		return
	if _scene56_has_evidence("an_locker_code_a17") and night_school_visual.call("near_locker_a17"):
		_scene56_interact_identified_locker()
		return
	if GameState.scene_id != "scene_06" and night_school_visual.call("near_notice_board"):
		_scene56_open_board()
		return
	if night_school_visual.call("near_locker_a17"):
		prompt.text = "Chiếc tủ cũ chưa có mã xác định. Xem ảnh ở bảng tin trước."

func _scene56_interact_identified_locker() -> void:
	if not bool(GameState.flags.get("a17_locker_open", false)):
		night_school_visual.call("open_locker_a17")
		GameState.set_flag("a17_locker_open", true)
		GameState.set_checkpoint("scene_06", "locker_a17")
		GameState.set_objective("REASSEMBLE_DIARY")
		objective.text = "MỤC TIÊU  ·  Ghép sáu mảnh nhật ký bị xé."
		prompt.text = "Ngăn A-17 mở · E xem sáu mảnh giấy"
	else:
		_open_diary_puzzle()

func _collect_first_keepsake() -> void:
	if GameState.inventory.has("math_test"):
		return
	night_school_visual.call("play_interaction")
	GameState.add_item_once("math_test")
	GameState.set_flag("KEEPSAKE_01_ACQUIRED", true)
	GameState.set_checkpoint("scene_06", "diary_reward")
	GameState.set_objective("COLLECT_FIRST_KEEPSAKE")
	night_school_visual.call("set_math_test_visible", false)
	_refresh_inventory_bar()
	objective.text = "KỶ VẬT 1/6  ·  Bài kiểm tra Toán 100/100"
	prompt.text = "Kỷ vật đã được lưu vào hồ sơ An."
	_play_scene56_keepsake_memory()

func _play_scene56_keepsake_memory() -> void:
	var old_mouse_mode := Input.mouse_mode
	night_school_visual.call("begin_keepsake_memory")
	scene56_memory_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(3.0).timeout
	scene56_memory_overlay.visible = false
	night_school_visual.call("end_keepsake_memory")
	Input.mouse_mode = old_mouse_mode
	_scene56_update_quest_objective()

func _process_scene56_stage() -> void:
	scene56_case_file_button.visible = true
	if scene56_mode != "":
		return
	_scene56_update_quest_objective()
	if GameState.inventory.has("math_test"):
		prompt.text = "Kỷ vật đã được lưu vào hồ sơ An."
	elif bool(GameState.flags.get("diary_solved", false)) and night_school_visual.call("near_math_test"):
		prompt.text = "[E] Nhặt bài kiểm tra Toán 100/100"
	elif night_school_visual.call("near_locker_a17") and _scene56_has_evidence("an_locker_code_a17"):
		prompt.text = "[E] Xem sáu mảnh nhật ký" if bool(GameState.flags.get("a17_locker_open", false)) else "[E] Kiểm tra tủ A-17"
	elif GameState.scene_id != "scene_06" and night_school_visual.call("near_notice_board"):
		prompt.text = "[E] Xem bảng tin"
	elif GameState.scene_id == "scene_06" and night_school_visual.call("near_locker_a17"):
		prompt.text = "Chiếc tủ cũ chưa có mã xác định. Xem ảnh ở bảng tin trước."
	else:
		prompt.text = "WASD di chuyển · Tìm bảng tin" if GameState.scene_id != "scene_06" else "WASD di chuyển · Tìm tủ đồ A-17"

func _build_inventory_bar(layer: CanvasLayer) -> void:
	inventory_bar = PanelContainer.new()
	inventory_bar.name = "SixSlotInventory"
	inventory_bar.anchor_left = .5
	inventory_bar.anchor_right = .5
	inventory_bar.anchor_top = 1.0
	inventory_bar.anchor_bottom = 1.0
	inventory_bar.offset_left = -188
	inventory_bar.offset_top = -68
	inventory_bar.offset_right = 188
	inventory_bar.offset_bottom = -8
	inventory_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025, 0.03, 0.04, .82)
	frame.border_color = Color("#5c5042")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(6)
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_top = 4
	frame.content_margin_bottom = 4
	inventory_bar.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	inventory_bar.add_child(row)
	for index in range(6):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(52, 50)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("#e6ddce"))
		label.text = "%d\n%s" % [index + 1, "ĐÈN PIN" if index == 0 else "—"]
		slot.add_child(label)
		row.add_child(slot)
		inventory_slots.append(slot)
		inventory_slot_labels.append(label)
	layer.add_child(inventory_bar)
	inventory_hint = Label.new()
	inventory_hint.name = "InventoryControlsHint"
	inventory_hint.anchor_left = .5
	inventory_hint.anchor_right = .5
	inventory_hint.anchor_top = 1.0
	inventory_hint.anchor_bottom = 1.0
	inventory_hint.offset_left = -170
	inventory_hint.offset_top = -85
	inventory_hint.offset_right = 170
	inventory_hint.offset_bottom = -68
	inventory_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_hint.text = "1–6  ·  CHỌN VẬT PHẨM     F  ·  BẬT/TẮT ĐÈN PIN"
	inventory_hint.add_theme_font_size_override("font_size", 10)
	inventory_hint.add_theme_color_override("font_color", Color("#c9bda9"))
	inventory_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(inventory_hint)
	_refresh_inventory_bar()

func _refresh_inventory_bar() -> void:
	for index in inventory_slots.size():
		var style := StyleBoxFlat.new()
		var selected := index == selected_inventory_slot
		style.bg_color = Color("#4a3a27", .96) if selected else Color("#17191d", .88)
		style.border_color = Color("#e4b66f") if selected else Color("#57524b")
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(4)
		inventory_slots[index].add_theme_stylebox_override("panel", style)
		inventory_slot_labels[index].add_theme_color_override("font_color", Color("#fff0d2") if selected else Color("#c6c0b6"))
	if inventory_slot_labels.size() > 1:
		inventory_slot_labels[1].text = "2\nBÀI KT\n100/100" if GameState.inventory.has("math_test") else "2\n—"


func _start_opening_sequence() -> void:
	GameState.set_story_time(STORY_TIMES.scene_01)
	opening_phase = "scene01_monologue"
	opening_line_index = 0
	cinematic_black.visible = true
	cinematic_black.color.a = 1.0
	opening_card.visible = true
	_show_opening_line(SCENE_01_MONOLOGUE, true)
	hallway_visual.call("set_controls_enabled", false)


func _show_opening_line(lines: Array, monologue := false) -> void:
	if opening_line_index < 0 or opening_line_index >= lines.size():
		return
	var line: Variant = lines[opening_line_index]
	if monologue:
		opening_speaker.text = "Hoàng · độc thoại"
		opening_subtitle.text = str(line)
	else:
		opening_speaker.text = str(line[0])
		opening_subtitle.text = str(line[1])
		if beat == Beat.HALLWAY and str(line[0]) in ["Bảo", "Huân", "Lân"]:
			hallway_visual.call("play_friend_animation", str(line[0]), "Interact")
		elif beat == Beat.CLASSROOM and str(line[0]) in ["Bảo", "Huân", "Lân"]:
			classroom_visual.call("play_classmate_animation", str(line[0]), "Interact")
		elif str(line[0]) == "Hoàng" and beat == Beat.HALLWAY:
			hallway_visual.call("play_player_interaction")
		elif str(line[0]) == "Hoàng" and beat == Beat.CLASSROOM:
			classroom_visual.call("play_player_interaction")
	opening_hint.text = "E  ·  Tiếp tục"
	opening_card.visible = true


func _begin_scene01_letter_inspection() -> void:
	hallway_visual.call("play_pickup_camera")
	hallway_visual.call("play_pickup")
	letter_found = true
	GameState.record_letter_collected()
	GameState.set_evidence("mysterious_letter", "front_read")
	AudioDirector.play_sfx("letter")
	opening_phase = "scene01_letter_inspect"
	opening_speaker.text = ""
	opening_subtitle.text = "CỨU TÔI"
	opening_subtitle.add_theme_font_size_override("font_size", 42)
	opening_hint.text = "Esc  ·  Đóng lá thư"
	opening_card.modulate.a = 0.0
	opening_card.visible = true
	opening_letter_contents.text = "CỨU TÔI"
	opening_letter_card.visible = true


func _close_scene01_letter_inspection() -> void:
	opening_letter_card.visible = false
	hallway_visual.call("end_pickup_camera")
	opening_phase = "scene01_after_front_comment"
	opening_card.modulate.a = 1.0
	opening_speaker.text = str(SCENE_01_FRONT_COMMENT[0])
	opening_subtitle.text = str(SCENE_01_FRONT_COMMENT[1])
	opening_subtitle.add_theme_font_size_override("font_size", 22)
	opening_hint.text = "E  ·  Tiếp tục"
	opening_card.visible = true
	hallway_visual.call("play_friend_animation", "Bao", "Interact")


func _advance_opening_sequence() -> void:
	match opening_phase:
		"scene01_find_letter":
			if not letter_found and hallway_visual.call("near_letter"):
				_begin_scene01_letter_inspection()
		"scene01_monologue":
			opening_line_index += 1
			if opening_line_index < SCENE_01_MONOLOGUE.size():
				_show_opening_line(SCENE_01_MONOLOGUE, true)
			else:
				opening_phase = "scene01_pre_dialogue"
				opening_line_index = 0
				hallway_visual.call("play_establishing_camera")
				var fade_in := create_tween()
				fade_in.tween_property(cinematic_black, "color:a", 0.0, .9)
				fade_in.tween_callback(func(): cinematic_black.visible = false)
				_show_opening_line(SCENE_01_DIALOGUE)
		"scene01_pre_dialogue":
			opening_line_index += 1
			if opening_line_index < SCENE_01_DIALOGUE.size():
				_show_opening_line(SCENE_01_DIALOGUE)
			else:
				opening_phase = "scene01_find_letter"
				opening_card.visible = false
				hallway_visual.call("use_gameplay_camera")
				hallway_visual.call("set_controls_enabled", true)
				objective.text = "Tiến tới phong bì dưới chân tủ"
				prompt.text = "WASD di chuyển · E nhặt thư khi đứng gần"
		"scene01_after_front_comment":
			opening_phase = "scene01_letter_dialogue"
			opening_line_index = 0
			_show_opening_line(SCENE_01_LETTER_DIALOGUE)
		"scene01_letter_dialogue":
			opening_line_index += 1
			if opening_line_index < SCENE_01_LETTER_DIALOGUE.size():
				_show_opening_line(SCENE_01_LETTER_DIALOGUE)
			else:
				_start_scene01_pocket()
		"scene01_keep_letter":
			_start_scene01_pocket()
		"classroom_dialogue":
			opening_line_index += 1
			if opening_line_index < SCENE_02_DIALOGUE.size():
				_show_opening_line(SCENE_02_DIALOGUE)
			else:
				opening_phase = "classroom_remember"
				opening_timer = .8
				classroom_visual.call("set_opening_state", "remember")
				opening_card.visible = false
		"classroom_letter_contents":
			opening_phase = "classroom_lan_react"
			classroom_visual.call("return_to_group_view")
			opening_speaker.text = "Lân"
			opening_subtitle.text = "Tối nay... thật sao?"
			opening_hint.text = "E  ·  Tiếp tục"
		"classroom_lan_react":
			opening_phase = "classroom_hoang_decision"
			classroom_visual.call("set_opening_state", "hoang_decision")
			opening_speaker.text = "Hoàng"
			opening_subtitle.text = "Tao muốn biết ai gửi thư."
			opening_hint.text = "E  ·  Tiếp tục"
		"classroom_hoang_decision":
			opening_phase = "classroom_black_thought"
			opening_card.visible = false
			cinematic_black.visible = true
			cinematic_black.color.a = 1.0
			opening_speaker.text = "Hoàng · độc thoại"
			opening_subtitle.text = "Tôi không thể ngừng nghĩ về nó."
			clock_label.visible = false
			opening_hint.text = ""
			opening_card.visible = true
			monologue_completion_timer.start(_subtitle_read_duration(opening_subtitle.text))
		"classroom_black_thought":
			return


func _show_chapter_handoff() -> void:
	opening_phase = "chapter_handoff"
	cinematic_black.visible = true
	cinematic_black.color.a = 1.0
	chapter_card.visible = true
	opening_timer = 2.2


func _subtitle_read_duration(text: String) -> float:
	# No voice track is present yet, so finish this subtitle after a readable,
	# content-derived interval and use the dialogue_finished signal for handoff.
	var words := text.strip_edges().split(" ", false).size()
	return maxf(2.5, float(words) / 2.8 + 0.8)


func _on_dialogue_finished(dialogue_id: StringName) -> void:
	if dialogue_id != &"classroom_black_monologue" or opening_phase != "classroom_black_thought":
		return
	_complete_classroom_black_thought()


func _complete_classroom_black_thought() -> void:
	GameState.set_flag_once("scene_02_completed")
	GameState.set_flag("chapter_01_unlocked")
	GameState.set_evidence("invitation_location", "restroom_floor_3")
	GameState.set_evidence("invitation_time", "23_00")
	GameState.set_checkpoint("scene_02", "afternoon_exit")
	GameState.set_story_time(STORY_TIMES.after_school)
	clock_label.visible = true
	beat = Beat.HALLWAY
	letter_found = true
	classroom_read = false
	classroom_visual.visible = false
	active_room = ""
	opening_card.visible = false
	cinematic_black.color.a = 1.0
	cinematic_black.visible = true
	opening_phase = "afternoon_fade_in"
	var fade := create_tween()
	fade.tween_property(cinematic_black, "color:a", 0.0, .75)
	fade.tween_callback(func(): cinematic_black.visible = false)
	_sync_hallway_visual()
	hallway_visual.call("use_gameplay_camera")
	hallway_visual.call("set_controls_enabled", true)
	opening_phase = ""
	afternoon_exit_available = true
	objective.text = "Tan học · Đi tới cửa thoát trường"
	prompt.text = "WASD di chuyển · E mở cửa thoát"


func _process_opening_sequence(delta: float) -> void:
	if opening_phase.is_empty():
		return
	if opening_phase == "scene01_find_letter":
		if hallway_visual.call("near_letter"):
			objective.text = "Phong bì không ghi tên nằm dưới chân tủ"
			prompt.text = "E  ·  Nhặt thư"
		else:
			objective.text = "Tiến tới phong bì dưới chân tủ"
			prompt.text = "WASD di chuyển · E nhặt thư khi đứng gần"
		return
	if opening_phase == "scene01_pocket_wait":
		return
	if opening_phase == "scene01_knock_wait" or opening_phase == "scene01_knock_reaction" or opening_phase == "scene01_empty_hall":
		opening_timer -= delta
		if opening_timer > 0.0:
			return
		match opening_phase:
			"scene01_knock_wait":
				hallway_visual.call("play_upstairs_knock")
				hallway_visual.call("react_to_knock")
				opening_phase = "scene01_knock_reaction"
				opening_timer = .42
			"scene01_knock_reaction":
				opening_phase = "scene01_empty_hall"
				opening_timer = .24
				objective.text = "Cầu thang phía trên trống không."
			"scene01_empty_hall":
				opening_phase = "scene01_fade_to_class"
				cinematic_black.visible = true
				cinematic_black.color.a = 0.0
				var fade := create_tween()
				fade.tween_property(cinematic_black, "color:a", 1.0, .48)
				fade.tween_callback(_begin_classroom_scene)
		return
	if opening_phase == "classroom_black_thought":
		return
	if opening_phase == "classroom_establish":
		return
	if opening_phase == "classroom_remember":
		opening_timer -= delta
		if opening_timer <= 0.0:
			opening_phase = "classroom_reveal_envelopes"
			opening_reveal_index = 1
			opening_timer = .55
			classroom_visual.call("set_opening_state", "reveal_%d" % opening_reveal_index)
		return
	if opening_phase == "classroom_reveal_envelopes":
		opening_timer -= delta
		if opening_timer <= 0.0:
			opening_reveal_index += 1
			classroom_visual.call("set_opening_state", "reveal_%d" % opening_reveal_index)
			if opening_reveal_index >= 3:
				opening_phase = "classroom_silence"
				opening_timer = 2.3
			else:
				opening_timer = .65
		return
	if opening_phase == "classroom_silence":
		opening_timer -= delta
		if opening_timer <= 0.0:
			opening_phase = "classroom_letter_contents"
			classroom_visual.call("set_opening_state", "read_letter")
			opening_speaker.text = ""
			opening_subtitle.text = "LÀM ƠN CỨU TÔI.\n\nNhà vệ sinh tầng 3.\n11 giờ tối nay.\nXin đừng bỏ mặc tôi."
			opening_hint.text = "E  ·  Tiếp tục"
			opening_card.visible = true
		return
	if opening_phase == "chapter_handoff":
		opening_timer -= delta
		if opening_timer <= 0.0:
			_advance_opening_sequence()


func _begin_classroom_scene() -> void:
	beat = Beat.CLASSROOM
	GameState.set_story_time(STORY_TIMES.scene_02)
	classroom_read = false
	classroom_intro_dismissed = true
	classroom_visual.call("set_controls_enabled", false)
	GameState.set_checkpoint("scene_02", "classroom_0715")
	GameState.mark_scene_01_completed()
	AudioDirector.set_ambience("school_night")
	opening_phase = "classroom_establish"
	opening_card.visible = false
	_show_beat()
	var establish_tween: Tween = classroom_visual.call("play_establishing_shot")
	if establish_tween != null:
		establish_tween.finished.connect(_on_classroom_establish_finished, CONNECT_ONE_SHOT)
	else:
		push_warning("Classroom establish camera was unavailable; continuing to dialogue safely.")
		call_deferred("_on_classroom_establish_finished")
	cinematic_black.visible = true
	cinematic_black.color.a = 1.0
	var fade_in := create_tween()
	fade_in.tween_property(cinematic_black, "color:a", 0.0, .9)
	fade_in.tween_callback(func(): cinematic_black.visible = false)

func _start_scene01_pocket() -> void:
	if opening_phase == "scene01_pocket_wait":
		return
	GameState.set_flag_once("letter_kept")
	GameState.set_evidence("mysterious_letter", "front_read")
	opening_phase = "scene01_pocket_wait"
	opening_card.visible = false
	var pocket_tween: Tween = hallway_visual.call("put_letter_away")
	if pocket_tween != null:
		pocket_tween.finished.connect(_on_scene01_pocket_finished, CONNECT_ONE_SHOT)
	else:
		_on_scene01_pocket_finished()

func _on_scene01_pocket_finished() -> void:
	if opening_phase != "scene01_pocket_wait":
		return
	opening_phase = "scene01_knock_wait"
	opening_timer = .12

func _on_classroom_establish_finished() -> void:
	if opening_phase != "classroom_establish":
		return
	opening_phase = "classroom_dialogue"
	opening_line_index = 0
	classroom_visual.call("set_opening_state", "message")
	objective.text = "Hoàng nhận thấy dòng chữ trên bàn."
	_show_opening_line(SCENE_02_DIALOGUE)

func _build_hallway_visual() -> void:
	hallway_visual = load("res://scenes/visual/hallway_3d.tscn").instantiate() as SubViewportContainer
	add_child(hallway_visual)

func _build_restroom_visual() -> void:
	restroom_visual = load("res://scenes/visual/restroom_3d.tscn").instantiate() as SubViewportContainer
	add_child(restroom_visual)

func _build_classroom_visual() -> void:
	classroom_visual = load("res://scenes/visual/classroom_3d.tscn").instantiate() as SubViewportContainer
	add_child(classroom_visual)

func _build_night_school_visual() -> void:
	night_school_visual = SubViewportContainer.new()
	night_school_visual.name = "NightSchool3D"
	night_school_visual.custom_minimum_size = VIEW
	night_school_visual.size = VIEW
	night_school_visual.stretch = true
	night_school_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_school_visual.set_script(load("res://scripts/visual/night_school_3d.gd"))
	night_school_visual.visible = false
	add_child(night_school_visual)


func _sync_external_player() -> void:
	if player == last_projected_player:
		return
	if active_room == "hallway" and hallway_visual != null:
		hallway_visual.call("set_player_from_prototype", player)
	elif active_room == "restroom" and restroom_visual != null:
		restroom_visual.call("set_state_from_prototype", player, int(beat), is_hidden)
	elif active_room == "classroom" and classroom_visual != null:
		classroom_visual.call("set_player_from_prototype", player)
	last_projected_player = player

func _sync_hallway_visual() -> void:
	if hallway_visual == null:
		return
	hallway_visual.visible = beat in [Beat.HALLWAY, Beat.LETTER] or (beat == Beat.CLASSROOM and classroom_read)
	var hall_view := hallway_visual.get_node_or_null("SpatialViewport") as SubViewport
	if hall_view != null:
		hall_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if hallway_visual.visible else SubViewport.UPDATE_DISABLED
	if hallway_visual.visible:
		if active_room != "hallway":
			active_room = "hallway"
			last_projected_player = Vector2.INF
		_sync_external_player()
		if beat == Beat.CLASSROOM and classroom_read and letter_found:
			hallway_visual.call("restore_letter_reveal")
		hallway_visual.call("set_letter_visible", not letter_found)
		hallway_visual.call("set_controls_enabled", beat == Beat.HALLWAY or (beat == Beat.CLASSROOM and classroom_read))
	_sync_classroom_visual()

func _sync_classroom_visual() -> void:
	if classroom_visual == null:
		return
	classroom_visual.visible = beat == Beat.CLASSROOM and not classroom_read
	var classroom_view := classroom_visual.get_node_or_null("ClassroomViewport") as SubViewport
	if classroom_view != null:
		classroom_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if classroom_visual.visible else SubViewport.UPDATE_DISABLED
	if classroom_visual.visible:
		if active_room != "classroom":
			active_room = "classroom"
			last_projected_player = Vector2.INF
		_sync_external_player()
		classroom_visual.call("set_controls_enabled", opening_phase.is_empty() and classroom_intro_dismissed and not classroom_read)

func _sync_restroom_visual() -> void:
	if restroom_visual == null:
		return
	restroom_visual.visible = beat in [Beat.TOILET, Beat.DEAD, Beat.MIRROR, Beat.REFLECTION, Beat.GHOST]
	var room_view := restroom_visual.get_node_or_null("RestroomViewport") as SubViewport
	var mirror_view := restroom_visual.get_node_or_null("RestroomViewport/SchoolRestroom/MirrorOnly3DRender") as SubViewport
	for view in [room_view, mirror_view]:
		if view != null:
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if restroom_visual.visible else SubViewport.UPDATE_DISABLED
	if restroom_visual.visible:
		if active_room != "restroom":
			active_room = "restroom"
			last_projected_player = Vector2.INF
		_sync_external_player()
		restroom_visual.call("update_story_state", int(beat), is_hidden)
		restroom_visual.call("set_controls_enabled", beat in [Beat.TOILET, Beat.MIRROR])

func _sync_night_school_visual() -> void:
	if night_school_visual == null:
		return
	night_school_visual.visible = beat == Beat.NIGHT_SCHOOL
	var night_view := night_school_visual.get_node_or_null("NightSchoolViewport") as SubViewport
	if night_view != null:
		night_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if night_school_visual.visible else SubViewport.UPDATE_DISABLED
	if night_school_visual.visible:
		if active_room != "night_school":
			active_room = "night_school"
			last_projected_player = Vector2.INF
		night_school_visual.call("set_controls_enabled", night_phase in ["yard", "ground_hall", "stairs", "upper_hall", "find_stall", "mirror_reveal", "scene56_explore"])

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.047, 0.061, 0.96)
	style.border_color = Color(0.39, 0.32, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style

func _show_beat() -> void:
	_sync_hallway_visual()
	_sync_restroom_visual()
	_sync_classroom_visual()
	_sync_night_school_visual()
	var has_panel := beat == Beat.DEAD or (beat == Beat.LETTER and letter_reveal_remaining == 0.0 and letter_close_reveal_remaining == 0.0) or (beat == Beat.CLASSROOM and not classroom_read and not classroom_intro_dismissed)
	panel.visible = has_panel
	inventory_bar.visible = beat != Beat.DEAD
	inventory_hint.visible = inventory_bar.visible
	overlay.visible = beat == Beat.DEAD
	retry_button.visible = beat == Beat.DEAD
	if has_panel:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	objective.visible = beat in [Beat.HALLWAY, Beat.CLASSROOM, Beat.TOILET, Beat.MIRROR, Beat.REFLECTION, Beat.GHOST, Beat.NIGHT_SCHOOL] or (beat == Beat.LETTER and letter_reveal_remaining > 0.0)
	match beat:
		Beat.HALLWAY:
			objective.text = "MỤC TIÊU  ·  Tìm lá thư rơi giữa hành lang"
			prompt.text = "WASD: đi  ·  Shift: chạy  ·  Chuột: nhìn  ·  F: đèn pin  ·  E: tương tác"
			message.text = ""
		Beat.LETTER:
			objective.text = "Hoàng nhặt lá thư lên..."
			message.text = "01 — LÁ THƯ BÍ ẨN · 17:10\n\nTrong phong bì có một lá thư viết vội. Mực đã nhòe, nhưng dòng cuối vẫn đọc được: “Cứu tôi.” Trên giấy còn hằn ba vết móng tay.\n\nTừ tầng trên vọng xuống một tiếng gõ cửa. Hành lang vẫn trống không."
			prompt.text = "Nhấn E để gấp thư lại"
		Beat.CLASSROOM:
			message.text = "02 — CỨU TÔI · 07:15\n\nSáng hôm sau, trong lớp học, bốn lá thư giống hệt nhau nằm trên bàn trực. Nét chữ run rẩy lặp lại cùng một lời cầu cứu. Mặt sau lá cuối ghi: “23:00 — nhà vệ sinh cuối hành lang.”\n\nNgoài cửa lớp vang lên tiếng gõ. Hành lang tối sầm; tiếng trống báo hiệu đêm thứ nhất bắt đầu."
			objective.text = "Đến cánh cửa cuối hành lang rồi nhấn E" if classroom_read else ("02 · Đọc bốn lá thư trên bàn trực" if classroom_intro_dismissed else "02 · Lớp học · Bốn lá thư")
			prompt.text = "WASD + chuột tới cửa cuối hành lang · E mở cửa" if classroom_read else ("Tiến tới bàn trực · E đọc bốn lá thư" if classroom_intro_dismissed else "Nhấn E để bước vào lớp học")
		Beat.TOILET:
			objective.text = "Đã nấp · tiếng bước chân đi qua ngoài cửa" if is_hidden else "NÚP! Còn %.1f giây  ·  Buồng phát sáng bên trái" % maxf(hide_time, 0.0)
			prompt.text = "Giữ yên trong buồng..." if is_hidden else "E mở cửa buồng đầu bên trái · Chạy vào trong · E trốn"
		Beat.DEAD:
			message.text = "YOU DIED\n\nTiếng gõ dừng ngay sau lưng bạn. Cánh cửa buồng tự mở."
			prompt.text = "Bạn đã không kịp trốn."
		Beat.MIRROR:
			objective.text = "MỤC TIÊU  ·  Tiến đến chiếc gương cuối phòng"
			prompt.text = "WASD tới gương · E khi đứng gần gương"
		Beat.REFLECTION:
			objective.text = "Trong gương, cô gái đứng sau An. Nhấn E để ngoảnh lại."
			prompt.text = "Nhấn E để ngoảnh lại"
		Beat.GHOST:
			objective.text = "An ngoảnh lại — căn phòng trống. Hãy theo cô đến bảng tin (cảnh 05)."
			prompt.text = "Phòng rửa trống không. Hãy theo cô đến bảng tin (cảnh 05)."
		Beat.NIGHT_SCHOOL:
			if night_school_preview_launch and night_phase == "yard":
				objective.text = "XEM THỬ TRONG EDITOR · Sân trường ban đêm"
				prompt.text = "WASD di chuyển · Chuột nhìn · E vào trường"
			elif night_phase == "yard":
				objective.text = "%s · Sân trường · Nhóm bạn đang chờ" % GameState.story_time
				prompt.text = "WASD di chuyển · E vào trường"
			elif night_phase == "ground_hall":
				var near_stairs: bool = bool(night_school_visual.call("near_stairwell"))
				objective.text = "Cầu thang lên tầng 3 ở bên trái" if near_stairs else "Tìm cầu thang lên tầng 3"
				prompt.text = "E  ·  Vào cầu thang" if near_stairs else "WASD di chuyển · Theo hành lang bên trái"
			elif night_phase == "stairs":
				objective.text = "Tầng 3 · Đi lên cầu thang"
				prompt.text = "WASD di chuyển · Lên ba tầng"
			elif night_phase == "upper_hall":
				var near_restroom: bool = bool(night_school_visual.call("near_restroom_door"))
				objective.text = "Cửa nhà vệ sinh tầng 3" if near_restroom else "TẦNG 3 · WC NAM  →  BÊN PHẢI"
				prompt.text = "E  ·  Mở cửa" if near_restroom else "Rẽ phải theo hành lang · Tìm biển WC NAM"
			elif night_phase == "entering_restroom":
				objective.text = "Cửa mở · bước vào nhà vệ sinh"
				prompt.text = "WASD di chuyển · Bước qua ngưỡng cửa"
			else:
				objective.text = "23:00 · Sân trường"
				prompt.text = "WASD di chuyển · Chuột nhìn · E tương tác"
	_sync_prompt_presentation()
	queue_redraw()

func _sync_prompt_presentation() -> void:
	if prompt == null or dialogue_prompt_column == null or prompt_hud == null or panel == null:
		return
	var destination: Control = dialogue_prompt_column if panel.visible else prompt_hud
	if prompt.get_parent() != destination:
		prompt.reparent(destination, false)
	prompt_hud.visible = not panel.visible and not _has_story_overlay() and not prompt.text.is_empty()

func _has_story_overlay() -> bool:
	return (opening_card != null and opening_card.visible) \
		or (opening_letter_card != null and opening_letter_card.visible) \
		or (cinematic_black != null and cinematic_black.visible) \
		or (chapter_card != null and chapter_card.visible) \
		or (overlay != null and overlay.visible) \
		or (night_death_overlay != null and night_death_overlay.visible)

func _retry() -> void:
	if night_is_dead and night_school_visual != null:
		night_is_dead = false
		night_death_overlay.visible = false
		inventory_bar.visible = true
		inventory_hint.visible = true
		night_phase = "find_stall"
		night_hide_timer = 3.0
		night_school_visual.call("reset_restroom_event")
		night_red_overlay.visible = true
		night_red_overlay.color.a = .30
		night_school_visual.call("set_red_realm", true)
		night_school_visual.call("set_controls_enabled", true)
		objective.text = "SURVIVAL EVENT 01  ·  3.0 GIÂY"
		prompt.text = "Trốn trong một buồng vệ sinh!"
		return
	beat = Beat.TOILET
	player = Vector2(360, 417)
	letter_found = true
	is_hidden = false
	hide_time = HIDE_SECONDS
	hide_staging_remaining = 0.0
	if restroom_visual != null:
		restroom_visual.call("reset_hide_stall")
	GameState.set_checkpoint("scene_03", "toilet_retry")
	_show_beat()

func _draw() -> void:
	if beat == Beat.NIGHT_SCHOOL:
		return
	if beat in [Beat.HALLWAY, Beat.LETTER, Beat.CLASSROOM] and hallway_visual != null:
		return
	if beat in [Beat.TOILET, Beat.DEAD, Beat.MIRROR, Beat.REFLECTION, Beat.GHOST] and restroom_visual != null:
		return
	if beat in [Beat.HALLWAY, Beat.LETTER, Beat.CLASSROOM]:
		_draw_hallway()
	elif beat == Beat.TOILET or beat == Beat.DEAD:
		_draw_toilet()
	else:
		_draw_mirror()
	if beat in [Beat.HALLWAY, Beat.TOILET, Beat.MIRROR, Beat.REFLECTION, Beat.GHOST]:
		_draw_player()

func _draw_hallway() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#101319"))
	draw_rect(Rect2(74, 76, 812, 388), Color("#34343a"))
	draw_rect(Rect2(94, 96, 772, 348), Color("#49464a"))
	for x in range(108, 866, 68):
		draw_line(Vector2(x, 98), Vector2(x, 442), Color(0.23, 0.22, 0.23), 2)
	draw_rect(Rect2(0, 0, 960, 76), Color("#17191e"))
	draw_rect(Rect2(0, 464, 960, 76), Color("#17191e"))
	for y in [76, 464]:
		draw_line(Vector2(0, y), Vector2(960, y), Color("#716963"), 5)
	# Class doors and a dim exit sign.
	for x in [170, 340, 650, 790]:
		draw_rect(Rect2(x, 79, 94, 72), Color("#252327"))
		draw_rect(Rect2(x + 5, 83, 84, 64), Color("#51433a"))
		draw_circle(Vector2(x + 75, 116), 3, Color("#c6a875"))
	draw_rect(Rect2(444, 142, 100, 202), Color("#211f23"))
	draw_rect(Rect2(452, 149, 84, 190), Color("#5c4940"))
	draw_circle(Vector2(520, 252), 4, Color("#d2b183"))
	draw_rect(Rect2(448, 110, 92, 21), Color("#7b302b"))
	draw_string(ThemeDB.fallback_font, Vector2(462, 125), "NHÀ VỆ SINH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff0e4"))
	if not letter_found:
		# Folded paper with a faint spotlight.
		draw_circle(Vector2(492, 291), 36, Color(0.82, 0.72, 0.53, 0.10))
		draw_colored_polygon(PackedVector2Array([Vector2(478, 281), Vector2(507, 279), Vector2(510, 302), Vector2(481, 305)]), Color("#d8cfb9"))
		draw_line(Vector2(484, 288), Vector2(503, 286), Color("#827969"), 1)
	draw_string(ThemeDB.fallback_font, Vector2(24, 518), "01  ·  HÀNH LANG", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b2a79a"))

func _draw_toilet() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#0c1115"))
	draw_rect(Rect2(60, 74, 840, 400), Color("#333d3f"))
	draw_rect(Rect2(75, 90, 810, 368), Color("#4a5350"))
	for y in range(100, 455, 46):
		draw_line(Vector2(76, y), Vector2(884, y), Color(0.31, 0.35, 0.33), 2)
	# Stall partitions and doors.
	for x in [175, 360, 545, 730]:
		draw_rect(Rect2(x, 160, 14, 260), Color("#222b2d"))
		draw_rect(Rect2(x + 18, 172, 148, 228), Color("#394245"))
		draw_rect(Rect2(x + 32, 172, 125, 208), Color("#56605d"))
		draw_circle(Vector2(x + 140, 280), 3, Color("#c0a878"))
	# Final stall is a slightly highlighted hiding zone.
	draw_rect(HIDE_SPOT, Color(0.83, 0.81, 0.69, 0.12))
	draw_rect(Rect2(0, 0, 960, 64), Color("#14191d"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 518), "03  ·  NHÀ VỆ SINH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b2a79a"))
	if beat == Beat.DEAD:
		draw_circle(Vector2(470, 278), 34, Color(0.75, 0.83, 0.81, 0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(443, 401), Vector2(456, 297), Vector2(470, 276), Vector2(488, 300), Vector2(503, 401)]), Color(0.76, 0.82, 0.78, 0.32))

func _draw_mirror() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#101419"))
	draw_rect(Rect2(60, 65, 840, 410), Color("#334044"))
	draw_rect(Rect2(78, 83, 804, 374), Color("#3b4849"))
	for x in range(100, 870, 56):
		for y in range(110, 447, 46):
			draw_rect(Rect2(x, y, 54, 44), Color(0.77, 0.81, 0.76, 0.035), false, 1)
	draw_rect(Rect2(0, 0, 960, 64), Color("#14191d"))
	# Sink and tall tarnished mirror.
	draw_rect(Rect2(770, 130, 116, 190), Color("#221f21"))
	draw_rect(MIRROR_RECT, Color("#8b9690"))
	draw_rect(MIRROR_RECT.grow(-8), Color("#263338"))
	draw_line(Vector2(798, 143), Vector2(842, 305), Color(0.68, 0.77, 0.74, 0.25), 4)
	draw_rect(Rect2(754, 317, 150, 20), Color("#6c6b65"))
	draw_rect(Rect2(790, 347, 76, 15), Color("#858177"))
	if beat == Beat.REFLECTION:
		# The apparition appears inside the reflective surface while An faces the mirror.
		draw_circle(Vector2(838, 190), 13, Color(0.80, 0.88, 0.84, 0.72))
		draw_colored_polygon(PackedVector2Array([Vector2(818, 274), Vector2(822, 214), Vector2(838, 204), Vector2(854, 214), Vector2(858, 274)]), Color(0.78, 0.85, 0.80, 0.58))
		draw_line(Vector2(830, 190), Vector2(846, 190), Color("#d8e4dd"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(24, 518), "04  ·  PHÒNG RỬA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b2a79a"))

func _draw_player() -> void:
	var color := Color("#c4b7a3")
	if beat == Beat.TOILET and is_hidden:
		color.a = 0.12
	draw_circle(player + Vector2(0, 13), 11, Color(0, 0, 0, 0.35))
	draw_circle(player, 10, color)
	draw_circle(player + Vector2(0, -3), 6, Color("#302d30"))
