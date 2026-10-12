extends Node2D

## First playable slice: narrative beats 01–04, played in physical 3D rooms.
const VIEW := Vector2(960, 540)
const PLAYER_SPEED := 205.0
const HIDE_SECONDS := 3.0
const HIDE_STAGING_SECONDS := 1.4
const HIDE_SPOT := Rect2(80, 286, 210, 170)
const MIRROR_RECT := Rect2(790, 128, 96, 165)

enum Beat { HALLWAY, LETTER, CLASSROOM, TOILET, DEAD, MIRROR, REFLECTION, GHOST }
var beat: Beat = Beat.HALLWAY
var player := Vector2(480, 405)
var letter_found := false
var is_hidden := false
var hide_time := HIDE_SECONDS
var hide_staging_remaining := 0.0
var letter_reveal_remaining := 0.0
var message: Label
var prompt: Label
var objective: Label
var overlay: ColorRect
var panel: PanelContainer
var retry_button: Button
var hallway_visual: SubViewportContainer
var restroom_visual: SubViewportContainer
var active_room := ""
var last_projected_player := Vector2.INF
var classroom_read := false

func _ready() -> void:
	AudioDirector.set_ambience("school_night")
	_setup_input()
	_build_hallway_visual()
	_build_restroom_visual()
	_build_ui()
	_restore_checkpoint()
	_show_beat()
	if GameState.scene_id in ["scene_05", "scene_06", "scene_07", "scene_08"]:
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

func _restore_checkpoint() -> void:
	match GameState.scene_id:
		"scene_01":
			beat = Beat.HALLWAY
			GameState.set_checkpoint("scene_01", "hallway_letter")
		"scene_02":
			beat = Beat.CLASSROOM
			letter_found = true
			player = Vector2(480, 405)
		"scene_03":
			beat = Beat.TOILET
			letter_found = true
			player = Vector2(360, 417)
			is_hidden = false
			hide_time = HIDE_SECONDS
		"scene_04":
			beat = Beat.MIRROR
			letter_found = true
			player = Vector2(480, 405)
		_:
			beat = Beat.HALLWAY

func _resume_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

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
	last_projected_player = player
	if beat == Beat.CLASSROOM and classroom_read and hallway_visual.get("restroom_door_open"):
		var hallway_position: Vector3 = hallway_visual.call("get_player_position")
		if hallway_position.z < -13.55:
			_enter_restroom()
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if active_room == "hallway":
			hallway_visual.call("orbit_mouse", event.relative)
		elif active_room == "restroom":
			restroom_visual.call("orbit_mouse", event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_F and beat in [Beat.HALLWAY, Beat.CLASSROOM, Beat.TOILET, Beat.MIRROR]:
			if active_room == "hallway":
				hallway_visual.call("toggle_flashlight")
			elif active_room == "restroom":
				restroom_visual.call("toggle_flashlight")
	elif event is InputEventMouseButton and event.pressed and beat == Beat.DEAD:
		if retry_button.get_global_rect().has_point(event.position):
			_retry()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _interact() -> void:
	_sync_external_player()
	if beat == Beat.TOILET and is_hidden:
		return
	if beat != Beat.DEAD and active_room == "hallway" and hallway_visual.call("is_interacting"):
		return
	if beat != Beat.DEAD and active_room == "restroom" and restroom_visual.call("is_interacting"):
		return
	match beat:
		Beat.HALLWAY:
			if not letter_found and hallway_visual.call("near_letter"):
				hallway_visual.call("play_interaction")
				hallway_visual.call("play_letter_reveal")
				letter_found = true
				GameState.set_evidence("mysterious_letter", "read")
				AudioDirector.play_sfx("letter")
				GameState.set_flag("letter_read")
				letter_reveal_remaining = 0.65
				beat = Beat.LETTER
				_show_beat()
		Beat.LETTER:
			beat = Beat.CLASSROOM
			classroom_read = false
			GameState.set_checkpoint("scene_02", "classroom_letters")
			_show_beat()
		Beat.CLASSROOM:
			if not classroom_read:
				classroom_read = true
				_show_beat()
			elif hallway_visual.call("near_restroom_door"):
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
				GameState.set_checkpoint("scene_04", "mirror")
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


func _enter_restroom() -> void:
	player = Vector2(360, 417)
	beat = Beat.TOILET
	is_hidden = false
	hide_time = HIDE_SECONDS
	GameState.set_checkpoint("scene_03", "toilet_hide")
	_show_beat()

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

	objective = Label.new()
	objective.position = Vector2(22, 18)
	objective.add_theme_color_override("font_color", Color("#dfd7c9"))
	objective.add_theme_font_size_override("font_size", 16)
	layer.add_child(objective)

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

func _build_hallway_visual() -> void:
	hallway_visual = load("res://scenes/visual/hallway_3d.tscn").instantiate() as SubViewportContainer
	add_child(hallway_visual)

func _build_restroom_visual() -> void:
	restroom_visual = load("res://scenes/visual/restroom_3d.tscn").instantiate() as SubViewportContainer
	add_child(restroom_visual)


func _sync_external_player() -> void:
	if player == last_projected_player:
		return
	if active_room == "hallway" and hallway_visual != null:
		hallway_visual.call("set_player_from_prototype", player)
	elif active_room == "restroom" and restroom_visual != null:
		restroom_visual.call("set_state_from_prototype", player, int(beat), is_hidden)
	last_projected_player = player

func _sync_hallway_visual() -> void:
	if hallway_visual == null:
		return
	hallway_visual.visible = beat in [Beat.HALLWAY, Beat.LETTER, Beat.CLASSROOM]
	var hall_view := hallway_visual.get_node_or_null("SpatialViewport") as SubViewport
	if hall_view != null:
		hall_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if hallway_visual.visible else SubViewport.UPDATE_DISABLED
	if hallway_visual.visible:
		if active_room != "hallway":
			active_room = "hallway"
			last_projected_player = Vector2.INF
		_sync_external_player()
		if beat == Beat.CLASSROOM and letter_found:
			hallway_visual.call("restore_letter_reveal")
		hallway_visual.call("set_letter_visible", not letter_found)
		hallway_visual.call("set_controls_enabled", beat == Beat.HALLWAY or (beat == Beat.CLASSROOM and classroom_read))

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
	var has_panel := beat == Beat.DEAD or (beat == Beat.LETTER and letter_reveal_remaining == 0.0) or (beat == Beat.CLASSROOM and not classroom_read)
	panel.visible = has_panel
	overlay.visible = beat == Beat.DEAD
	retry_button.visible = beat == Beat.DEAD
	if has_panel:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	objective.visible = beat in [Beat.HALLWAY, Beat.CLASSROOM, Beat.TOILET, Beat.MIRROR, Beat.REFLECTION, Beat.GHOST] or (beat == Beat.LETTER and letter_reveal_remaining > 0.0)
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
			objective.text = "Đến cánh cửa cuối hành lang rồi nhấn E" if classroom_read else "02 · Đọc bốn lá thư"
			prompt.text = "Nhấn E để rời trang thư" if not classroom_read else "WASD + chuột tới cửa cuối hành lang · E mở cửa"
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
	queue_redraw()

func _retry() -> void:
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
