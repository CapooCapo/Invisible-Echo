extends Node2D

## First playable slice: narrative beats 01–04.
const VIEW := Vector2(960, 540)
const PLAYER_SPEED := 205.0
const HIDE_SECONDS := 3.0
const HIDE_SPOT := Rect2(700, 286, 198, 170)
const MIRROR_RECT := Rect2(790, 128, 96, 165)

enum Beat { HALLWAY, LETTER, CLASSROOM, TOILET, DEAD, MIRROR, REFLECTION, GHOST }
var beat: Beat = Beat.HALLWAY
var player := Vector2(480, 405)
var letter_found := false
var is_hidden := false
var hide_time := HIDE_SECONDS
var message: Label
var prompt: Label
var objective: Label
var overlay: ColorRect
var panel: PanelContainer
var retry_button: Button

func _ready() -> void:
	_setup_input()
	_build_ui()
	_show_beat()

func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
	}
	for action in bindings:
		InputMap.add_action(action)
		for keycode in bindings[action]:
			var key := InputEventKey.new()
			key.keycode = keycode
			InputMap.action_add_event(action, key)

func _process(delta: float) -> void:
	if beat == Beat.HALLWAY:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		player += move * PLAYER_SPEED * delta
		player.x = clampf(player.x, 90.0, 870.0)
		player.y = clampf(player.y, 104.0, 455.0)
		queue_redraw()
	elif beat == Beat.TOILET:
		if not is_hidden:
			var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			player += move * PLAYER_SPEED * delta
			player.x = clampf(player.x, 90.0, 870.0)
			player.y = clampf(player.y, 130.0, 460.0)
			hide_time -= delta
			objective.text = "NÚP! Còn %.1f giây  ·  Buồng cuối phát sáng bên phải" % maxf(hide_time, 0.0)
			if hide_time <= 0.0:
				beat = Beat.DEAD
				_show_beat()
		queue_redraw()
	elif beat == Beat.MIRROR:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		player += move * PLAYER_SPEED * delta
		player.x = clampf(player.x, 90.0, 870.0)
		player.y = clampf(player.y, 104.0, 455.0)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and beat != Beat.DEAD:
			get_tree().quit()
		elif event.keycode == KEY_E:
			_interact()
	elif event is InputEventMouseButton and event.pressed and beat == Beat.DEAD:
		if retry_button.get_global_rect().has_point(event.position):
			_retry()

func _interact() -> void:
	match beat:
		Beat.HALLWAY:
			if not letter_found and player.distance_to(Vector2(492, 291)) < 105.0:
				letter_found = true
				beat = Beat.LETTER
				_show_beat()
		Beat.LETTER:
			beat = Beat.CLASSROOM
			_show_beat()
		Beat.CLASSROOM:
			player = Vector2(360, 372)
			beat = Beat.TOILET
			is_hidden = false
			hide_time = HIDE_SECONDS
			_show_beat()
		Beat.TOILET:
			if HIDE_SPOT.has_point(player):
				is_hidden = true
				beat = Beat.MIRROR
				_show_beat()
		Beat.MIRROR:
			if MIRROR_RECT.grow(50).has_point(player):
				beat = Beat.REFLECTION
				_show_beat()
		Beat.REFLECTION:
			beat = Beat.GHOST
			_show_beat()
		Beat.DEAD:
			_retry()

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
	var has_panel := beat in [Beat.LETTER, Beat.CLASSROOM, Beat.DEAD]
	panel.visible = has_panel
	overlay.visible = beat == Beat.DEAD
	retry_button.visible = beat == Beat.DEAD
	objective.visible = beat in [Beat.HALLWAY, Beat.TOILET, Beat.MIRROR, Beat.REFLECTION, Beat.GHOST]
	match beat:
		Beat.HALLWAY:
			objective.text = "MỤC TIÊU  ·  Tìm lá thư rơi giữa hành lang"
			prompt.text = "WASD / phím mũi tên: di chuyển     ·     E: tương tác"
			message.text = ""
		Beat.LETTER:
			message.text = "01 — LÁ THƯ BÍ ẨN · 17:10\n\nTrong phong bì có một lá thư viết vội. Mực đã nhòe, nhưng dòng cuối vẫn đọc được: “Cứu tôi.” Trên giấy còn hằn ba vết móng tay.\n\nTừ tầng trên vọng xuống một tiếng gõ cửa. Hành lang vẫn trống không."
			prompt.text = "Nhấn E để gấp thư lại"
		Beat.CLASSROOM:
			message.text = "02 — CỨU TÔI · 07:15\n\nSáng hôm sau, trong lớp học, bốn lá thư giống hệt nhau nằm trên bàn trực. Nét chữ run rẩy lặp lại cùng một lời cầu cứu. Mặt sau lá cuối ghi: “23:00 — nhà vệ sinh cuối hành lang.”\n\nNgoài cửa lớp vang lên tiếng gõ. Hành lang tối sầm; tiếng trống báo hiệu đêm thứ nhất bắt đầu."
			prompt.text = "Nhấn E để tới hành lang nhà vệ sinh"
		Beat.TOILET:
			objective.text = "NÚP! Còn %.1f giây  ·  Buồng cuối phát sáng bên phải" % maxf(hide_time, 0.0)
			prompt.text = "Chạy vào vùng sáng và nhấn E để trốn  ·  WASD / phím mũi tên"
		Beat.DEAD:
			message.text = "YOU DIED\n\nTiếng gõ dừng ngay sau lưng bạn. Cánh cửa buồng tự mở."
			prompt.text = "Bạn đã không kịp trốn."
		Beat.MIRROR:
			objective.text = "MỤC TIÊU  ·  Tiến đến chiếc gương cuối phòng"
			prompt.text = "Nhấn E khi đứng trước gương"
		Beat.REFLECTION:
			objective.text = "Trong gương, cô gái đứng sau An. Nhấn E để ngoảnh lại."
			prompt.text = "Nhấn E để ngoảnh lại"
		Beat.GHOST:
			objective.text = "An ngoảnh lại — căn phòng trống. Hãy theo cô đến bảng tin (cảnh 05)."
			prompt.text = "Phòng rửa trống không. Hãy theo cô đến bảng tin (cảnh 05)."
	queue_redraw()

func _retry() -> void:
	beat = Beat.HALLWAY
	player = Vector2(480, 405)
	letter_found = false
	is_hidden = false
	hide_time = HIDE_SECONDS
	_show_beat()

func _draw() -> void:
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
