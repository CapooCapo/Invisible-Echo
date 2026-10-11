extends Node2D

const VIEW := Vector2(960, 540)
const CAMERA_ORDER := [0, 1, 2]
const VALID_PAIRS := [Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 5)]
const CONCLUSIONS := [
	"Bài thi và camera cho thấy An đến trường trong đêm.",
	"Bản ghi xác nhận có sự cố, nhưng không xác định ai gây ra.",
	"Bài đăng và tin nhắn không đủ bằng chứng quy kết tác giả.",
]

enum Beat { COMPUTER, CAMERA, POST, DEDUCTION, DONE }
var beat: Beat = Beat.COMPUTER
var code_input := ""
var camera_clips: Array[int] = [2, 0, 1]
var camera_selection := 0
var camera_held := -1
var camera_solved := false
var camera_photo_collected := false
var post_step := 0
var post_choice := ""
var thanks_collected := false
var selected_evidence := 0
var held_evidence := -1
var linked_pairs: Array[Vector2i] = []
var sketch_collected := false
var objective: Label
var instructions: Label
var status: Label
var keys_label: Label

func _ready() -> void:
	AudioDirector.set_ambience("computer_room")
	_build_hud()
	for item_id in ["math_test", "chess_medal", "knight_keychain"]:
		if not GameState.inventory.has(item_id):
			status.text = "Có vẻ em đang thiếu một kỷ vật từ hành lang trường học. Tiếp tục điều tra phần camera."
	_restore_checkpoint()
	_show_beat()
	if not GameState.inventory.has("math_test") or not GameState.inventory.has("chess_medal") or not GameState.inventory.has("knight_keychain"):
		status.text = "Thiếu kỷ vật từ hành lang; hồ sơ điều tra vẫn mở nhưng tiến trình lưu chưa hoàn chỉnh."

func _restore_checkpoint() -> void:
	match GameState.scene_id:
		"scene_09":
			beat = Beat.COMPUTER
			if GameState.checkpoint_id in ["camera_recovery", "photo_reward"]:
				beat = Beat.CAMERA
				code_input = "1804"
				camera_solved = GameState.checkpoint_id == "photo_reward" or GameState.inventory.has("mother_photo")
				camera_photo_collected = GameState.inventory.has("mother_photo")
		"scene_10":
			beat = Beat.POST
			post_step = 3
			post_choice = str(GameState.choices.get("minh_post", ""))
			thanks_collected = GameState.inventory.has("minh_thanks")
		"scene_11":
			beat = Beat.DEDUCTION
			if GameState.checkpoint_id == "deduction_complete":
				linked_pairs = VALID_PAIRS.duplicate()
				sketch_collected = GameState.inventory.has("chess_club_sketch")
		_:
			beat = Beat.COMPUTER

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match beat:
		Beat.COMPUTER:
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				code_input += str(event.keycode - KEY_0)
				code_input = code_input.substr(maxi(0, code_input.length() - 4))
				keys_label.text = "MÃ TRUY CẬP  ·  " + code_input.pad_zeros(4)
			elif event.keycode == KEY_BACKSPACE:
				code_input = code_input.left(maxi(0, code_input.length() - 1))
				keys_label.text = "MÃ TRUY CẬP  ·  " + code_input.pad_zeros(4)
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				if code_input == "1804":
					GameState.set_evidence("computer_access", "1804")
					beat = Beat.CAMERA
					GameState.set_checkpoint("scene_09", "camera_recovery")
					_show_beat()
				else:
					code_input = ""
					keys_label.text = "SAI MÃ  ·  "
					status.text = "Mã không đúng. Tấm ảnh trên bảng tin có ngày 18/04 — thử 1804."
		Beat.CAMERA:
			if event.keycode == KEY_LEFT:
				camera_selection = posmod(camera_selection - 1, 3)
			elif event.keycode == KEY_RIGHT:
				camera_selection = posmod(camera_selection + 1, 3)
			elif event.keycode == KEY_R:
				camera_clips = [2, 0, 1]
				camera_held = -1
				camera_solved = false
				status.text = "Thứ tự clip được đặt lại."
			elif event.keycode == KEY_E:
				if camera_solved:
					if not camera_photo_collected:
						camera_photo_collected = GameState.add_item_once("mother_photo") or GameState.inventory.has("mother_photo")
						GameState.set_flag("memory_4_seen")
						AudioDirector.play_sfx("keepsake")
						GameState.set_checkpoint("scene_09", "photo_reward")
						status.text = "Kỷ vật 4/6: ẢNH CHỤP CÙNG MẸ. Em gái An nhắc về buổi đi chơi đã hứa."
					else:
						beat = Beat.POST
						post_step = 0
						_show_beat()
				elif camera_held < 0:
					camera_held = camera_selection
					status.text = "Đã chọn clip %d — chọn vị trí khác rồi E để đổi." % (camera_held + 1)
				else:
					var temp := camera_clips[camera_selection]
					camera_clips[camera_selection] = camera_clips[camera_held]
					camera_clips[camera_held] = temp
					camera_held = -1
					camera_solved = camera_clips == CAMERA_ORDER
					status.text = "Thứ tự khôi phục đúng: hành lang → phòng máy → cầu thang. Bản ghi chỉ cho thấy An rời khung hình." if camera_solved else "Clip đã đổi chỗ; vẫn có thể sửa hoặc nhấn R để bắt đầu lại."
		Beat.POST:
			if event.keycode == KEY_E and post_step < 3:
				post_step += 1
				if post_step == 1:
					status.text = "Bản nháp ẩn danh đăng sau khi camera mất tín hiệu; tài khoản không để lại tên thật."
				elif post_step == 2:
					status.text = "Tin nhắn Minh xin đừng phát tán lời đồn khi chưa biết chuyện gì đã xảy ra."
				elif post_step == 3:
					status.text = "Chọn A để đăng nguyên văn, hoặc B để kiểm chứng và cảnh báo Minh."
			elif (event.keycode == KEY_A or event.keycode == KEY_B) and post_step >= 3 and post_choice.is_empty():
				var selected := "publish_raw" if event.keycode == KEY_A else "verify_warn"
				if GameState.set_choice("minh_post", selected):
					post_choice = selected
					GameState.set_flag("rumor_published" if selected == "publish_raw" else "rumor_limited")
					GameState.set_flag("threat_remains")
					GameState.set_checkpoint("scene_10", "choice_recorded")
					status.text = "Đã lưu lựa chọn: %s. Kỷ vật 5/6: LỜI CẢM ƠN CỦA MINH." % ("đăng nguyên văn" if selected == "publish_raw" else "kiểm chứng và cảnh báo")
					thanks_collected = GameState.add_item_once("minh_thanks") or GameState.inventory.has("minh_thanks")
					GameState.set_flag("memory_5_seen")
					AudioDirector.play_sfx("keepsake")
				else:
					post_choice = str(GameState.choices.get("minh_post", ""))
					status.text = "Lựa chọn đã ghi trước đó: " + post_choice
			elif event.keycode == KEY_E and not post_choice.is_empty():
				beat = Beat.DEDUCTION
				_show_beat()
		Beat.DEDUCTION:
			if event.keycode == KEY_LEFT:
				selected_evidence = posmod(selected_evidence - 1, 6)
			elif event.keycode == KEY_RIGHT:
				selected_evidence = posmod(selected_evidence + 1, 6)
			elif event.keycode == KEY_E:
				if linked_pairs.size() == 3:
					if not sketch_collected:
						sketch_collected = GameState.add_item_once("chess_club_sketch") or GameState.inventory.has("chess_club_sketch")
						GameState.set_flag("memory_6_seen")
						AudioDirector.play_sfx("keepsake")
						GameState.set_checkpoint("scene_11", "deduction_complete")
						status.text = "Kỷ vật 6/6: BỨC PHÁC THẢO CÂU LẠC BỘ CỜ. Bằng chứng không cho phép kết luận ai gây ra sự cố."
					else:
						beat = Beat.DONE
						_show_beat()
				elif held_evidence < 0:
					held_evidence = selected_evidence
					status.text = "Đã chọn chứng cứ %d. Chọn thẻ liên kết rồi E." % (held_evidence + 1)
				else:
					var pair := Vector2i(mini(held_evidence, selected_evidence), maxi(held_evidence, selected_evidence))
					held_evidence = -1
					if pair in VALID_PAIRS:
						if not linked_pairs.has(pair): linked_pairs.append(pair)
						status.text = CONCLUSIONS[linked_pairs.size() - 1]
					else:
						status.text = "Liên kết này chưa được chứng cứ hỗ trợ. Thử ghép cặp khác; kết luận phải giữ nguyên điều chưa biết."
					if linked_pairs.size() == 3:
						status.text += "  ·  Nhấn E nhận kỷ vật cuối."
		Beat.DONE:
			GameState.set_checkpoint("scene_12", "return_memories")
			get_tree().change_scene_to_file("res://scenes/12_phong_cau_vua.tscn")
	queue_redraw()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	objective = Label.new()
	objective.position = Vector2(24, 18)
	objective.add_theme_color_override("font_color", Color("#eee5d7"))
	objective.add_theme_font_size_override("font_size", 18)
	layer.add_child(objective)
	instructions = Label.new()
	instructions.position = Vector2(24, 475)
	instructions.add_theme_color_override("font_color", Color("#c8bdac"))
	instructions.add_theme_font_size_override("font_size", 15)
	layer.add_child(instructions)
	status = Label.new()
	status.position = Vector2(24, 420)
	status.size = Vector2(912, 48)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#e4c58d"))
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	keys_label = Label.new()
	keys_label.position = Vector2(340, 234)
	keys_label.size = Vector2(280, 58)
	keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keys_label.add_theme_color_override("font_color", Color("#f5dfa9"))
	keys_label.add_theme_font_size_override("font_size", 25)
	layer.add_child(keys_label)

func _show_beat() -> void:
	match beat:
		Beat.COMPUTER:
			objective.text = "09 · MÁY TÍNH DUY NHẤT  —  Khôi phục camera bằng mã 1804"
			instructions.text = "Gõ số · Backspace xóa · Enter xác nhận"
			status.text = "Phòng máy tối om. Màn hình yêu cầu mã ngày-tháng trên mặt sau ảnh của An."
			keys_label.text = "MÃ TRUY CẬP  ·  ____"
		Beat.CAMERA:
			objective.text = "09 · PHỤC HỒI CAMERA  —  Xếp clip theo thời gian"
			instructions.text = "← / → chọn clip · E chọn/đổi chỗ · R đặt lại · E nhận ảnh khi đúng"
			status.text = "Ba đoạn ghi hình đã bị xáo trộn; sắp theo diễn biến, không suy đoán ai đứng ngoài khung hình."
			keys_label.text = "CAMERA ARCHIVE"
		Beat.POST:
			objective.text = "10 · BÀI ĐĂNG  —  Đối chiếu chứng cứ với lời Minh"
			instructions.text = "E đọc từng tài liệu · A đăng nguyên văn · B kiểm chứng và cảnh báo"
			status.text = "Không tài liệu nào xác nhận ai đã đăng bài hoặc gây ra tai nạn."
			keys_label.text = "BẢN NHÁP  /  TIN NHẮN"
		Beat.DEDUCTION:
			objective.text = "11 · BẢNG SUY LUẬN  —  Nối ba cặp chứng cứ"
			instructions.text = "← / → chọn thẻ · E chọn/liên kết · E nhận phác thảo khi đủ 3 kết luận"
			status.text = "Liên kết điều có bằng chứng; giữ nguyên phần sự thật chưa thể biết."
			keys_label.text = "BẢNG CHỨNG CỨ"
		Beat.DONE:
			objective.text = "11 · ĐIỀU TRA HOÀN TẤT"
			instructions.text = "E: sang câu lạc bộ cờ vua (Sprint 05)"
			status.text = "Sáu kỷ vật đã được ghi nhận."
			keys_label.text = "HỒ SƠ ĐƯỢC LƯU"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#0f151a"))
	draw_rect(Rect2(55, 74, 850, 360), Color("#2e3739"))
	match beat:
		Beat.COMPUTER: _draw_computer()
		Beat.CAMERA: _draw_camera()
		Beat.POST: _draw_posts()
		Beat.DEDUCTION: _draw_deduction()
		Beat.DONE: _draw_done()
	draw_string(ThemeDB.fallback_font, Vector2(24, 522), "AN  ·  PHÒNG TIN HỌC", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#aaa196"))

func _draw_computer() -> void:
	draw_rect(Rect2(205, 111, 550, 300), Color("#20282c"))
	draw_rect(Rect2(238, 139, 484, 226), Color("#111a1d"))
	draw_rect(Rect2(270, 166, 420, 174), Color("#24383b"))
	draw_rect(Rect2(388, 365, 184, 18), Color("#59605d"))
	draw_rect(Rect2(423, 382, 114, 30), Color("#464b49"))
	for y in [202, 224, 246]:
		draw_line(Vector2(300, y), Vector2(660, y), Color(0.47, 0.64, 0.59, 0.16), 2)
	draw_string(ThemeDB.fallback_font, Vector2(314, 292), "CAMERA ARCHIVE  ·  ACCESS REQUIRED", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a4c7ae"))

func _draw_camera() -> void:
	var captions := ["22:14  ·  hành lang", "22:16  ·  phòng máy", "22:17  ·  cầu thang"]
	for slot in range(3):
		var rect := Rect2(102 + slot * 254, 165, 238, 164)
		draw_rect(rect, Color("#20282a"))
		draw_rect(rect.grow(-9), Color("#3a4441"))
		draw_rect(rect, Color("#d2b77d") if slot == camera_selection else Color("#79827a"), false, 3)
		if camera_held == slot: draw_rect(rect.grow(5), Color("#d4a764"), false, 4)
		var clip_id: int = camera_clips[slot]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 25), "CLIP %d" % (clip_id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#e3d8c3"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 145), captions[clip_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c4bcaa"))
		draw_line(rect.position + Vector2(25, 68), rect.position + Vector2(212, 68), Color("#aab7a5"), 2)
		draw_circle(rect.position + Vector2(84 + clip_id * 24, 66), 8, Color("#d8c38d"))

func _draw_posts() -> void:
	draw_rect(Rect2(124, 132, 336, 232), Color("#2a3133"))
	draw_rect(Rect2(500, 132, 336, 232), Color("#2a3133"))
	draw_string(ThemeDB.fallback_font, Vector2(150, 170), "BÀI ĐĂNG ẨN DANH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e2c996"))
	draw_string(ThemeDB.fallback_font, Vector2(526, 170), "TIN NHẮN MINH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a9c1ba"))
	var post_lines := ["Có chuyện đã xảy ra tối qua.", "Không có tên tài khoản thật.", "Thời điểm đăng: sau khi camera tắt."]
	var minh_lines := ["Đừng vội chia sẻ bài viết.", "Mình chưa biết ai đã ở đó.", "Xin hãy giúp mình tìm sự thật."]
	var line_index: int = clampi(post_step, 0, 2)
	draw_string(ThemeDB.fallback_font, Vector2(150, 222), post_lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d4d0c6"))
	draw_string(ThemeDB.fallback_font, Vector2(526, 222), minh_lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d4d0c6"))
	if not post_choice.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(360, 398), "LỰA CHỌN: " + post_choice, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#e0bf83"))

func _draw_deduction() -> void:
	var labels := ["Bài thi 100", "Ngày 18/04", "Camera", "Biên bản", "Bài ẩn danh", "Tin Minh"]
	for index in range(6):
		var col := index % 3
		var row := index / 3
		var rect := Rect2(142 + col * 234, 154 + row * 102, 210, 72)
		draw_rect(rect, Color("#45403a"))
		draw_rect(rect, Color("#ddbd7d") if index == selected_evidence else Color("#8e8576"), false, 3)
		if held_evidence == index: draw_rect(rect.grow(4), Color("#d59d5c"), false, 3)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(13, 43), labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e7ddca"))
	for pair in linked_pairs:
		var origin := Vector2(247 + (pair.x % 3) * 234, 190 + (pair.x / 3) * 102)
		var destination := Vector2(247 + (pair.y % 3) * 234, 190 + (pair.y / 3) * 102)
		draw_line(origin, destination, Color("#b2c79f"), 3)

func _draw_done() -> void:
	draw_rect(Rect2(195, 122, 570, 280), Color("#1b2626"))
	draw_string(ThemeDB.fallback_font, Vector2(260, 218), "BẰNG CHỨNG KHÔNG PHẢI LỜI KẾT TỘI", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#e0d0ac"))
	draw_string(ThemeDB.fallback_font, Vector2(270, 274), "Có điều đã xảy ra — người gây ra vẫn chưa rõ.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#b8c2b3"))
