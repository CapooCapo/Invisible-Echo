extends Node2D

## Scenes 05–08. Drawn locally to keep the original prototype dependency-free.
const VIEW := Vector2(960, 540)
const SPEED := 220.0
const HIDE_ZONE := Rect2(560, 350, 145, 105)
const BOX_ZONE := Rect2(760, 280, 94, 112)
const OCCLUDERS := [Rect2(330, 225, 138, 74), Rect2(708, 342, 152, 82)]
const U := 1
const R := 2
const D := 4
const L := 8

enum Beat { BOARD, DIARY, CIRCUIT, PATROL, CHASE, DONE }
enum GuardState { PATROL, SUSPICIOUS, CHASE, SEARCH }

var beat: Beat = Beat.BOARD
var player := Vector2(125, 410)
var objective: Label
var instructions: Label
var status: Label
var board_step := 0
var identity_known := false
var locker_clue := false
var fragments: Array[int] = [2, 0, 4, 1, 5, 3]
var selected_fragment := 0
var held_fragment := -1
var diary_solved := false
var math_test_collected := false
var circuit_base: Array[int] = []
var circuit_scramble: Array[int] = []
var circuit_turns: Array[int] = []
var selected_tile := Vector2i.ZERO
var circuit_attempts := 0
var circuit_solved := false
var chess_medal_collected := false
var guard_position := Vector2(500, 245)
var guard_direction := 1.0
var guard_state := GuardState.PATROL
var suspicion := 0.0
var search_timer := 0.0
var distraction_timer := 0.0
var distracted_position := Vector2.ZERO
var player_hidden := false
var keychain_collected := false
var chase_progress := 0.0
var chase_checkpoint := 0.0
var chase_attempts := 0
var chase_lane := 1
var chase_obstacles: Array[Dictionary] = [
	{"at": 18.0, "lane": 0, "passed": false},
	{"at": 36.0, "lane": 1, "passed": false},
	{"at": 54.0, "lane": 0, "passed": false},
	{"at": 73.0, "lane": 1, "passed": false},
]

func _ready() -> void:
	AudioDirector.set_ambience("school_night")
	_setup_input()
	_build_hud()
	_setup_circuit()
	var saved_diary: Variant = GameState.evidence.get("diary_fragments", [])
	if saved_diary is Array and saved_diary.size() == 6:
		fragments.clear()
		for value in saved_diary: fragments.append(int(value))
	var saved_circuit: Variant = GameState.evidence.get("circuit_turns", [])
	if saved_circuit is Array and saved_circuit.size() == 16:
		circuit_turns.clear()
		for value in saved_circuit: circuit_turns.append(int(value))
	identity_known = GameState.flags.get("an_identity_known", false)
	locker_clue = str(GameState.evidence.get("locker_clue", "")) == "A-17"
	math_test_collected = GameState.inventory.has("math_test")
	chess_medal_collected = GameState.inventory.has("chess_medal")
	keychain_collected = GameState.inventory.has("knight_keychain")
	_restore_checkpoint()
	_show_beat()

func _restore_checkpoint() -> void:
	match GameState.scene_id:
		"scene_05":
			beat = Beat.BOARD
			if GameState.checkpoint_id in ["board_identity", "board_reverse"]:
				board_step = 2
		"scene_06":
			beat = Beat.DIARY
			board_step = 2
			locker_clue = str(GameState.evidence.get("locker_clue", "")) == "A-17"
			math_test_collected = GameState.inventory.has("math_test")
			diary_solved = bool(GameState.flags.get("diary_solved", false)) or GameState.checkpoint_id == "diary_reward"
		"scene_07":
			beat = Beat.CIRCUIT
			circuit_solved = bool(GameState.flags.get("circuit_solved", false)) or GameState.inventory.has("chess_medal")
			chess_medal_collected = circuit_solved
		"scene_08":
			beat = Beat.CHASE if GameState.checkpoint_id == "chase_start" else Beat.PATROL
			keychain_collected = GameState.inventory.has("knight_keychain")
		_:
			beat = Beat.BOARD

func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var key := InputEventKey.new()
			key.keycode = keycode
			if not InputMap.action_has_event(action, key):
				InputMap.action_add_event(action, key)

func _process(delta: float) -> void:
	match beat:
		Beat.BOARD, Beat.PATROL:
			_update_player(delta)
			if beat == Beat.PATROL:
				_update_guard(delta)
			queue_redraw()
		Beat.CHASE:
			_update_chase(delta)
			queue_redraw()

func _update_player(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player += movement * SPEED * delta
	player.x = clampf(player.x, 65.0, 895.0)
	player.y = clampf(player.y, 120.0, 465.0)
	if beat == Beat.PATROL:
		player_hidden = HIDE_ZONE.has_point(player) and Input.is_key_pressed(KEY_SPACE)

func _update_guard(delta: float) -> void:
	if distraction_timer > 0.0:
		distraction_timer -= delta
		guard_position = guard_position.move_toward(distracted_position, 110.0 * delta)
		guard_state = GuardState.SEARCH
		search_timer = 1.0
		if distraction_timer <= 0.0:
			distraction_timer = 0.0
		return
	if guard_state == GuardState.PATROL:
		guard_position.x += guard_direction * 74.0 * delta
		if guard_position.x > 795.0 or guard_position.x < 240.0:
			guard_direction *= -1.0
	var to_player := player - guard_position
	var distance := to_player.length()
	var facing := Vector2(guard_direction, 0.0)
	if guard_state == GuardState.CHASE:
		if player_hidden or distance > 280.0 or not _has_clear_sight(guard_position, player):
			guard_state = GuardState.SEARCH
			search_timer = 1.5
		else:
			facing = to_player.normalized()
			guard_position = guard_position.move_toward(player, 145.0 * delta)
			if distance < 42.0:
				guard_state = GuardState.SEARCH
				search_timer = 1.8
				player = Vector2(120, 390)
				player_hidden = false
				status.text = "Bảo vệ chặn đường bạn — trở về checkpoint hành lang."
	elif guard_state == GuardState.SEARCH:
		search_timer -= delta
		if search_timer <= 0.0:
			guard_state = GuardState.PATROL
			suspicion = 0.0
			guard_direction *= -1.0
	else:
		var can_see := not player_hidden and distance < 150.0 and facing.dot(to_player.normalized()) > 0.25 and _has_clear_sight(guard_position, player)
		if can_see:
			guard_state = GuardState.SUSPICIOUS
			suspicion += delta * (1.0 + (150.0 - distance) / 100.0)
			if suspicion >= 1.45:
				guard_state = GuardState.CHASE
				AudioDirector.play_sfx("chase_heartbeat")
		elif guard_state == GuardState.SUSPICIOUS:
			suspicion = maxf(0.0, suspicion - delta * 0.7)
			if suspicion <= 0.0:
				guard_state = GuardState.SEARCH
				search_timer = 0.8
		status.text = "Bảo vệ: %s%s" % [_guard_state_name(), "  ·  nghi ngờ %.0f%%" % (100.0 * suspicion / 1.45) if guard_state == GuardState.SUSPICIOUS else ""]

func _update_chase(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.y < -0.2:
		chase_lane = 0
	elif movement.y > 0.2:
		chase_lane = 1
	chase_progress = minf(100.0, chase_progress + maxf(movement.x, 0.0) * delta * 45.0)
	for obstacle in chase_obstacles:
		if not obstacle.passed and chase_progress >= float(obstacle.at):
			obstacle.passed = true
			if chase_lane == int(obstacle.lane):
				chase_attempts += 1
				chase_progress = chase_checkpoint
				status.text = "Vấp phải chướng ngại — thử lại từ mốc an toàn (%d)." % chase_attempts
				for later in chase_obstacles:
					if float(later.at) > chase_checkpoint:
						later.passed = false
				break
			else:
				chase_checkpoint = chase_progress
	if chase_progress >= 100.0:
		beat = Beat.DONE
		_show_beat()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_E:
			_interact()
		KEY_R:
			if beat == Beat.DIARY:
				_reset_diary()
			elif beat == Beat.CIRCUIT:
				_reset_circuit()
		KEY_H:
			if beat == Beat.CIRCUIT and circuit_attempts >= 3:
				status.text = "Gợi ý: nguồn ở góc trên trái; lần theo dây sáng đến ổ khóa bên phải dưới."
		KEY_SPACE:
			if beat == Beat.PATROL and HIDE_ZONE.has_point(player):
				player_hidden = not player_hidden
		KEY_F:
			if beat == Beat.PATROL:
				distracted_position = player + Vector2(-240.0 if player.x > 480.0 else 240.0, -70.0)
				distraction_timer = 1.7
				suspicion = 0.0
				status.text = "Tiếng động đánh lạc hướng bảo vệ. Hãy tận dụng khoảng trống."
			else:
				_move_selection(1)
		KEY_A, KEY_LEFT:
			_move_selection(-1)
		KEY_RIGHT:
			_move_selection(1)
		KEY_UP:
			_move_selection(-4 if beat == Beat.CIRCUIT else -3)
		KEY_DOWN:
			_move_selection(4 if beat == Beat.CIRCUIT else 3)
	queue_redraw()

func _move_selection(amount: int) -> void:
	if beat == Beat.DIARY:
		selected_fragment = posmod(selected_fragment + amount, 6)
	elif beat == Beat.CIRCUIT:
		var flat := selected_tile.y * 4 + selected_tile.x
		flat = posmod(flat + amount, 16)
		selected_tile = Vector2i(flat % 4, flat / 4)
	else:
		player.x = clampf(player.x + float(amount) * 12.0, 65.0, 895.0)

func _interact() -> void:
	match beat:
		Beat.BOARD:
			if player.distance_to(Vector2(790, 218)) < 150.0:
				if board_step == 0:
					board_step = 1
					GameState.set_checkpoint("scene_05", "board_portrait")
					status.text = "Tấm ảnh bị rạch mất khuôn mặt. Nhấn E để lật mặt sau."
				elif board_step == 1:
					identity_known = true
					board_step = 2
					status.text = "NGUYỄN NGỌC AN — giải nhất cờ vua. Nhấn E để lật mặt sau bức ảnh."
					GameState.set_flag("an_identity_known")
					GameState.set_checkpoint("scene_05", "board_reverse")
				else:
					locker_clue = true
					GameState.set_flag("an_identity_known")
					GameState.set_evidence("locker_clue", "A-17")
					beat = Beat.DIARY
					GameState.set_checkpoint("scene_06", "locker_a17")
					_show_beat()
			else:
				status.text = "Bảng tin ở cuối hành lang bên phải."
		Beat.DIARY:
			if diary_solved:
				if not math_test_collected:
					math_test_collected = GameState.add_item_once("math_test") or GameState.inventory.has("math_test")
					GameState.set_flag("memory_1_seen")
					AudioDirector.play_sfx("keepsake")
					GameState.set_checkpoint("scene_06", "diary_reward")
					status.text = "Kỷ vật 1/6: BÀI KIỂM TRA 100 ĐIỂM. Một thoáng ký ức về mẹ trở lại."
				else:
					beat = Beat.CIRCUIT
					GameState.set_checkpoint("scene_07", "circuit_start")
					_show_beat()
			elif held_fragment < 0:
				held_fragment = selected_fragment
				status.text = "Đã chọn mảnh %d. Chọn ô đích rồi nhấn E lần nữa." % (held_fragment + 1)
			else:
				var swap_value := fragments[selected_fragment]
				fragments[selected_fragment] = fragments[held_fragment]
				fragments[held_fragment] = swap_value
				held_fragment = -1
				if _diary_is_solved():
					diary_solved = true
					GameState.set_flag("diary_solved")
					AudioDirector.play_sfx("puzzle_solved")
					status.text = "Nhật ký hé lộ: bài thi Toán 100 điểm; lời vu oan quay cóp; An xin xem camera nhưng không được lắng nghe. Nhấn E nhận kỷ vật."
				else:
					status.text = "Mảnh đã đổi chỗ. Sai thứ tự vẫn có thể sửa — R để xếp lại từ đầu."
				GameState.set_evidence("diary_fragments", fragments)
		Beat.CIRCUIT:
			if circuit_solved:
				if not chess_medal_collected:
					chess_medal_collected = GameState.add_item_once("chess_medal") or GameState.inventory.has("chess_medal")
					GameState.set_flag("memory_2_seen")
					AudioDirector.play_sfx("keepsake")
					GameState.set_checkpoint("scene_07", "circuit_reward")
					status.text = "Kỷ vật 2/6: HUY CHƯƠNG CỜ VUA. Ánh đèn sân khấu và tiếng vỗ tay thoáng hiện."
				else:
					beat = Beat.PATROL
					player = Vector2(120, 390)
					GameState.set_checkpoint("scene_08", "patrol_start")
					_show_beat()
			else:
				circuit_turns[selected_tile.y * 4 + selected_tile.x] = posmod(circuit_turns[selected_tile.y * 4 + selected_tile.x] + 1, 4)
				GameState.set_evidence("circuit_turns", circuit_turns)
				circuit_attempts += 1
				if _circuit_connected():
					circuit_solved = true
					GameState.set_flag("circuit_solved")
					AudioDirector.play_sfx("puzzle_solved")
					status.text = "Mạch khép kín! Khóa cầu thang bật sáng. Nhấn E lấy huy chương."
				else:
					status.text = "Dây xoay 90°. Chưa nối được nguồn với ổ khóa. R để đặt lại; H mở gợi ý sau vài lần thử."
		Beat.PATROL:
			if BOX_ZONE.has_point(player) and guard_state != GuardState.CHASE:
				if not keychain_collected:
					keychain_collected = GameState.add_item_once("knight_keychain") or GameState.inventory.has("knight_keychain")
					GameState.set_flag("memory_3_seen")
					GameState.set_checkpoint("scene_08", "chase_start")
					status.text = "An chỉ về chiếc hộp. Kỷ vật 3/6: MÓC KHÓA QUÂN MÃ — món quà em từng tặng."
					beat = Beat.CHASE
					chase_progress = 0.0
					chase_checkpoint = 0.0
					_show_beat()
			else:
				status.text = "Bảo vệ đang %s. Núp trong góc tối (Space) hoặc tạo tiếng động đánh lạc hướng (F)." % _guard_state_name()
		Beat.CHASE:
			status.text = "Chạy đến phòng tin học — né chướng ngại bằng cách đổi làn."
		Beat.DONE:
			get_tree().change_scene_to_file("res://scenes/09_phong_tin_hoc.tscn")

func _diary_is_solved() -> bool:
	for index in range(6):
		if fragments[index] != index:
			return false
	return true

func _reset_diary() -> void:
	fragments = [2, 0, 4, 1, 5, 3]
	GameState.set_evidence("diary_fragments", fragments)
	selected_fragment = 0
	held_fragment = -1
	diary_solved = false
	status.text = "Nhật ký được xếp lại; hãy thử ghép ngày theo trình tự."

func _setup_circuit() -> void:
	circuit_base.resize(16)
	circuit_base.fill(0)
	# Correct path: source (left) → down column 0 → across row 2 → target (right).
	circuit_base[0] = L | D
	circuit_base[4] = U | D
	circuit_base[8] = U | R
	circuit_base[9] = L | R
	circuit_base[10] = L | D
	circuit_base[14] = U | R
	circuit_base[15] = L | R
	circuit_scramble = [1, 0, 0, 0, 2, 0, 0, 0, 1, 3, 1, 0, 0, 0, 2, 1]
	circuit_turns.resize(16)
	circuit_turns.fill(0)

func _rotate_mask(mask: int, turns: int) -> int:
	var rotated := mask
	for _turn in range(posmod(turns, 4)):
		var next_mask := 0
		if rotated & U: next_mask |= R
		if rotated & R: next_mask |= D
		if rotated & D: next_mask |= L
		if rotated & L: next_mask |= U
		rotated = next_mask
	return rotated

func _ports_at(index: int) -> int:
	return _rotate_mask(circuit_base[index], circuit_scramble[index] + circuit_turns[index])

func _circuit_connected() -> bool:
	if (_ports_at(0) & L) == 0 or (_ports_at(15) & R) == 0:
		return false
	var visited: Dictionary = {0: true}
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var current: int = pending.pop_front()
		if current == 15 and (_ports_at(current) & R) != 0:
			return true
		var x: int = current % 4
		var y: int = current / 4
		var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var bits := [U, R, D, L]
		var opposites := [D, L, U, R]
		for direction_index in range(4):
			if (_ports_at(current) & bits[direction_index]) == 0:
				continue
			var next_cell: Vector2i = Vector2i(x, y) + directions[direction_index]
			if next_cell.x < 0 or next_cell.x >= 4 or next_cell.y < 0 or next_cell.y >= 4:
				continue
			var next_index: int = next_cell.y * 4 + next_cell.x
			if (_ports_at(next_index) & opposites[direction_index]) != 0 and not visited.has(next_index):
				visited[next_index] = true
				pending.append(next_index)
	return false

func _reset_circuit() -> void:
	circuit_turns.fill(0)
	GameState.set_evidence("circuit_turns", circuit_turns)
	GameState.set_flag("circuit_solved", false)
	circuit_attempts = 0
	circuit_solved = false
	selected_tile = Vector2i.ZERO
	status.text = "Mạch đã được đặt lại."

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	objective = Label.new()
	objective.position = Vector2(22, 14)
	objective.add_theme_color_override("font_color", Color("#f0e6d4"))
	objective.add_theme_font_size_override("font_size", 18)
	layer.add_child(objective)
	instructions = Label.new()
	instructions.position = Vector2(22, 474)
	instructions.add_theme_color_override("font_color", Color("#c7baaa"))
	instructions.add_theme_font_size_override("font_size", 15)
	layer.add_child(instructions)
	status = Label.new()
	status.position = Vector2(22, 420)
	status.size = Vector2(916, 48)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#f1ce9a"))
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)

func _show_beat() -> void:
	match beat:
		Beat.BOARD:
			objective.text = "05 · BẢNG TIN  —  Tìm ảnh bị rạch ở cuối hành lang"
			instructions.text = "WASD / mũi tên di chuyển · E xem/lật ảnh"
			status.text = "Thông báo cũ phủ kín bảng tin. Một tấm ảnh bị cào xước ánh lên ở góc phải."
		Beat.DIARY:
			objective.text = "06 · TỦ A-17  —  Ghép sáu mảnh nhật ký theo ngày"
			instructions.text = "Mũi tên chọn mảnh · E chọn/đổi với ô khác · R xếp lại · E nhận kỷ vật khi hoàn tất"
			status.text = "Clue 18/04 dẫn đến tủ A-17. Các mảnh ghi ngày 03/09, 12/09 và 18/09."
		Beat.CIRCUIT:
			objective.text = "07 · PHÒNG ĐIỆN  —  Nối nguồn với khóa cầu thang"
			instructions.text = "Mũi tên chọn dây · E xoay 90° · R đặt lại · H gợi ý sau 3 lượt · E lấy huy chương"
			status.text = "Mạch điện 4×4 đã bị đảo. Hãy tạo đường dây liên tục, không đoán hình mẫu."
		Beat.PATROL:
			objective.text = "08 · HÀNH LANG  —  Theo dấu An, tìm hộp đồ và trốn bảo vệ"
			instructions.text = "WASD / mũi tên di chuyển · Space núp trong bóng · D tạo tiếng động · E tương tác"
			status.text = "Quan sát tầm nhìn và trạng thái nghi ngờ của bảo vệ trước khi băng qua."
		Beat.CHASE:
			objective.text = "08 · RƯỢT ĐUỔI  —  Chạy đến phòng tin học"
			instructions.text = "Giữ D / → để chạy · W/S đổi làn, né vật cản báo trước"
			status.text = "An ra hiệu về phía trước. Đường chạy có vật cản báo trước theo từng làn."
		Beat.DONE:
			objective.text = "08 · ĐÃ THOÁT  —  Kỷ vật 1–3 đã được ghi nhận"
			instructions.text = "E: sang phòng tin học (Sprint 04)"
			status.text = "Bạn đã đến cửa phòng tin học."
	queue_redraw()

func _guard_state_name() -> String:
	match guard_state:
		GuardState.PATROL: return "tuần tra"
		GuardState.SUSPICIOUS: return "nghi ngờ"
		GuardState.CHASE: return "truy đuổi"
		GuardState.SEARCH: return "lùng sục"
	return "tuần tra"

func _has_clear_sight(from: Vector2, to: Vector2) -> bool:
	for occluder: Rect2 in OCCLUDERS:
		if occluder.has_point(to):
			return false
		for step in range(1, 33):
			if occluder.has_point(from.lerp(to, float(step) / 33.0)):
				return false
	return true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#101317"))
	draw_rect(Rect2(48, 68, 864, 390), Color("#353b3a"))
	draw_rect(Rect2(62, 82, 836, 360), Color("#414747"))
	for x in range(74, 890, 52):
		draw_line(Vector2(x, 86), Vector2(x, 438), Color(0.29, 0.33, 0.32), 1)
	match beat:
		Beat.BOARD: _draw_board()
		Beat.DIARY: _draw_diary()
		Beat.CIRCUIT: _draw_circuit()
		Beat.PATROL: _draw_patrol()
		Beat.CHASE: _draw_chase()
		Beat.DONE: _draw_done()
	draw_string(ThemeDB.fallback_font, Vector2(24, 522), "AN  ·  ĐÊM 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#aaa196"))

func _draw_board() -> void:
	draw_rect(Rect2(690, 130, 186, 182), Color("#25282a"))
	draw_rect(Rect2(702, 143, 162, 156), Color("#756a59"))
	for index in range(5):
		draw_line(Vector2(712, 158 + index * 26), Vector2(851, 158 + index * 26), Color("#b8a68b"), 2)
	draw_rect(Rect2(744, 176, 75, 98), Color("#dfd4bc"))
	if board_step < 2:
		draw_circle(Vector2(781, 198), 13, Color("#877a72"))
		draw_rect(Rect2(763, 213, 36, 38), Color("#9b8578"))
		if board_step == 0:
			draw_line(Vector2(766, 202), Vector2(790, 227), Color("#30292a"), 4)
			draw_line(Vector2(793, 202), Vector2(771, 233), Color("#30292a"), 3)
		else:
			draw_string(ThemeDB.fallback_font, Vector2(725, 287), "NGUYỄN NGỌC AN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#3d3935"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(781, 184), Vector2(819, 211), Vector2(781, 253), Vector2(744, 211)]), Color("#f0e5ce"))
		draw_string(ThemeDB.fallback_font, Vector2(753, 210), "18/04", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#3d3935"))
		draw_string(ThemeDB.fallback_font, Vector2(758, 232), "A-17", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8b3830"))
	_draw_player()

func _draw_diary() -> void:
	draw_rect(Rect2(112, 112, 736, 290), Color("#252a2c"))
	draw_string(ThemeDB.fallback_font, Vector2(148, 148), "TỦ A-17  ·  NHẬT KÝ BỊ XÉ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e1d7c5"))
	for index in range(6):
		var col := index % 3
		var row := index / 3
		var rect := Rect2(150 + col * 224, 174 + row * 98, 204, 78)
		draw_rect(rect, Color("#b9a785"))
		draw_rect(rect, Color("#e4d7b7"), false, 2 if index == selected_fragment else 1)
		if held_fragment == index:
			draw_rect(rect.grow(4), Color("#d09e66"), false, 3)
		var fragment_id: int = fragments[index]
		var displayed_date: String = ["03/09", "03/09", "12/09", "12/09", "18/09", "18/09"][fragment_id]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 26), displayed_date, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#332f2b"))
		var diary_text: String = ["100/100 — mẹ sẽ đến xem.", "Mẹ chờ con ở cổng trường.", "Cô vu oan con quay cóp.", "Con xin cô xem camera.", "Mẹ bệnh, con xin nghỉ.", "Cô không cho con gọi mẹ."][fragment_id]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 53), diary_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#4b443b"))

func _draw_circuit() -> void:
	draw_rect(Rect2(220, 92, 520, 342), Color("#202629"))
	for index in range(16):
		var x := index % 4
		var y := index / 4
		var rect := Rect2(266 + x * 108, 120 + y * 75, 88, 60)
		draw_rect(rect, Color("#303c3e"))
		draw_rect(rect, Color("#6d7770") if Vector2i(x, y) == selected_tile else Color("#596362"), false, 2)
		var mask := _ports_at(index)
		var center := rect.get_center()
		for bit in [U, R, D, L]:
			if (mask & bit) == 0: continue
			var port_delta: Vector2 = {U: Vector2(0, -25), R: Vector2(37, 0), D: Vector2(0, 25), L: Vector2(-37, 0)}[bit]
			draw_line(center, center + port_delta, Color("#e2be76"), 6)
			draw_circle(center + port_delta, 4, Color("#f2dca1"))
	draw_circle(Vector2(235, 150), 12, Color("#7dc78f"))
	draw_string(ThemeDB.fallback_font, Vector2(193, 180), "NGUỒN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c4cfbd"))
	draw_rect(Rect2(744, 337, 30, 22), Color("#c0aa79"))
	draw_string(ThemeDB.fallback_font, Vector2(781, 354), "KHÓA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d4c8ac"))
	if circuit_solved:
		draw_rect(Rect2(762, 327, 18, 42), Color("#8bdba1"))

func _draw_patrol() -> void:
	draw_rect(Rect2(HIDE_ZONE.position, HIDE_ZONE.size), Color(0.12, 0.15, 0.14, 0.9))
	draw_string(ThemeDB.fallback_font, HIDE_ZONE.position + Vector2(8, 24), "BÓNG TỐI / SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b6c3ae"))
	for blocker: Rect2 in OCCLUDERS:
		draw_rect(blocker, Color("#343430"))
		draw_rect(blocker.grow(-5), Color("#48463e"))
	draw_rect(BOX_ZONE, Color("#715b45"))
	draw_rect(BOX_ZONE.grow(-8), Color("#89745b"))
	draw_string(ThemeDB.fallback_font, BOX_ZONE.position + Vector2(8, 58), "HỘP ĐỒ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#eee0c9"))
	var cone_color := Color(0.85, 0.65, 0.29, 0.12) if guard_state != GuardState.CHASE else Color(0.83, 0.20, 0.16, 0.18)
	var forward := Vector2(guard_direction, 0.0) if guard_state != GuardState.CHASE else (player - guard_position).normalized()
	var side := Vector2(-forward.y, forward.x) * 82.0
	draw_colored_polygon(PackedVector2Array([guard_position, guard_position + forward * 145.0 + side, guard_position + forward * 145.0 - side]), cone_color)
	draw_rect(Rect2(guard_position.x - 13, guard_position.y - 28, 26, 55), Color("#8a3632") if guard_state == GuardState.CHASE else Color("#65696a"))
	draw_circle(guard_position + Vector2(0, -36), 13, Color("#b1a291"))
	if guard_state == GuardState.SUSPICIOUS:
		draw_arc(guard_position + Vector2(0, -46), 18, 3.2, 6.2, 20, Color("#e6bf62"), 3)
	_draw_player()
	if player_hidden:
		draw_string(ThemeDB.fallback_font, player + Vector2(-26, -24), "ĐANG NÚP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b5d2af"))
	if keychain_collected:
		draw_circle(Vector2(812, 302), 14, Color("#d8bc70"))

func _draw_chase() -> void:
	draw_rect(Rect2(60, 125, 840, 300), Color("#242a30"))
	draw_line(Vector2(60, 275), Vector2(900, 275), Color("#c1b49b"), 3)
	draw_rect(Rect2(100 + chase_progress * 6.8, 215 + chase_lane * 100, 28, 45), Color("#d6c7ae"))
	draw_circle(Vector2(133 + chase_progress * 6.8, 208 + chase_lane * 100), 12, Color("#b6a18d"))
	for obstacle in chase_obstacles:
		if not obstacle.passed:
			var x := 100 + float(obstacle.at) * 6.8 - chase_progress * 6.8
			if x > 80 and x < 890:
				draw_rect(Rect2(x, 170 + int(obstacle.lane) * 100, 50, 64), Color("#8a5944"))
	var ratio := chase_progress / 100.0
	draw_rect(Rect2(185, 145, 590 * ratio, 9), Color("#d3aa6a"))
	draw_rect(Rect2(185, 145, 590, 9), Color("#e3d5bc"), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(730, 465), "Làn %d" % (chase_lane + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e0d2ba"))

func _draw_done() -> void:
	draw_rect(Rect2(194, 120, 572, 310), Color("#18211e"))
	draw_string(ThemeDB.fallback_font, Vector2(300, 235), "PHÒNG TIN HỌC", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#d9ccb4"))
	draw_string(ThemeDB.fallback_font, Vector2(300, 282), "An đã ở đây. Cánh cửa khép lại phía sau.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c4bcab"))

func _draw_player() -> void:
	draw_circle(player + Vector2(0, 13), 11, Color(0, 0, 0, 0.3))
	draw_circle(player, 10, Color("#cbbda8") if not player_hidden else Color(0.79, 0.73, 0.64, 0.17))
	draw_circle(player + Vector2(0, -3), 6, Color("#342e2c"))
