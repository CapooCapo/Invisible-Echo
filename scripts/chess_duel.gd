extends Node2D

const ChessRules = preload("res://scripts/chess/chess_rules.gd")
const BOARD_ORIGIN := Vector2(274, 86)
const CELL := 58.0
enum Result { PLAYING, WON, RESIGNED }

var chess
var cursor := 0
var source_square := -1
var attempts := 0
var result := Result.PLAYING
var status: Label
var title: Label

func _ready() -> void:
	AudioDirector.set_ambience("school_night")
	_build_ui()
	_reset_puzzle()
	if GameState.scene_id == "scene_13" and GameState.checkpoint_id == "checkmate_won":
		result = Result.WON
		status.text = "Ván cờ đã khép lại. Nhấn E để đón bình minh."
	elif GameState.scene_id == "scene_13" and GameState.checkpoint_id == "chess_resigned":
		result = Result.RESIGNED
		status.text = "An đã khép bàn cờ. Nhấn R để thử lại hoặc E để rời phòng."
	else:
		GameState.set_checkpoint("scene_13", "chess_challenge")

func _reset_puzzle() -> void:
	chess = ChessRules.new()
	chess.set_position({"f6": "wK", "g6": "wQ", "h8": "bK"}, "w")
	cursor = chess.square_from_name("g6")
	source_square = -1
	result = Result.PLAYING
	_refresh()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif result == Result.WON or result == Result.RESIGNED:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			GameState.set_checkpoint("scene_14", "morning_confrontation")
			get_tree().change_scene_to_file("res://scenes/14_binh_minh.tscn")
		elif event.keycode == KEY_R and result == Result.RESIGNED:
			attempts += 1
			GameState.set_flag("chess_resigned", false)
			GameState.set_checkpoint("scene_13", "chess_challenge")
			_reset_puzzle()
		return
	match event.keycode:
		KEY_LEFT: _move_cursor(0, -1)
		KEY_RIGHT: _move_cursor(0, 1)
		KEY_UP: _move_cursor(-1, 0)
		KEY_DOWN: _move_cursor(1, 0)
		KEY_E, KEY_ENTER: _activate_square(cursor)
		KEY_R:
			attempts += 1
			_reset_puzzle()
			status.text = "Thế cờ đã được dựng lại. Nước chiếu hết chỉ cần đi một quân."
		KEY_X: _resign()
	queue_redraw()

func _move_cursor(row_delta: int, file_delta: int) -> void:
	var row: int = cursor / 8
	var file: int = cursor % 8
	row = clampi(row + row_delta, 0, 7)
	file = clampi(file + file_delta, 0, 7)
	cursor = row * 8 + file

func _activate_square(target: int) -> void:
	if result != Result.PLAYING: return
	if source_square < 0:
		if chess.board[target].begins_with("w"):
			source_square = target
			status.text = "Quân %s được chọn. Dẫn con hậu đến ô g7." % chess.board[target].right(1)
		else:
			status.text = "Chọn quân Trắng; vua Đen đang ở h8."
	else:
		var source := source_square
		source_square = -1
		if not chess.make_move(source, target):
			status.text = "Nước đi không hợp lệ theo luật cờ. Thử lại; R dựng lại thế cờ."
			return
		if chess.is_checkmate("b"):
			result = Result.WON
			AudioDirector.play_sfx("puzzle_solved")
			GameState.set_flag("chess_boss_defeated")
			GameState.set_flag("chess_resigned", false)
			GameState.set_checkpoint("scene_13", "checkmate_won")
			status.text = "CHIẾU HẾT. Bóng người sau bàn cờ cúi đầu — An đã được nhìn nhận. Nhấn E để đón bình minh."
		else:
			attempts += 1
			status.text = "Nước hợp lệ, nhưng chưa phải chiếu hết. Thử lại từ thế cờ ban đầu (R)."
			_reset_puzzle()
	queue_redraw()

func _resign() -> void:
	result = Result.RESIGNED
	GameState.set_flag("chess_resigned")
	GameState.set_flag("chess_boss_defeated", false)
	GameState.set_checkpoint("scene_13", "chess_resigned")
	status.text = "An khép bàn cờ. Có thể thử lại bằng R, hoặc rời phòng bằng E."
	_refresh()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(34, 26)
	title.size = Vector2(870, 35)
	title.add_theme_color_override("font_color", Color("#f0e4d0"))
	title.add_theme_font_size_override("font_size", 24)
	layer.add_child(title)
	status = Label.new()
	status.position = Vector2(34, 486)
	status.size = Vector2(900, 42)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#e6c98f"))
	status.add_theme_font_size_override("font_size", 15)
	layer.add_child(status)

func _refresh() -> void:
	if title == null: return
	title.text = "13 — ĐỐI ĐẦU TRÊN BÀN CỜ  ·  LẦN THỬ %d" % (attempts + 1)
	if result == Result.PLAYING:
		status.text = "Thử thách chiếu hết một nước: Trắng đi. Mũi tên di chuyển · E chọn/đi quân · R dựng lại · X xin dừng"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color("#11151b"))
	draw_rect(Rect2(78, 72, 804, 404), Color("#252b31"))
	for row in range(8):
		for file in range(8):
			var square := row * 8 + file
			var rect := Rect2(BOARD_ORIGIN + Vector2(file * CELL, row * CELL), Vector2(CELL, CELL))
			var light := Color("#d6c7a7") if (row + file) % 2 == 0 else Color("#61574b")
			draw_rect(rect, light)
			if square == cursor:
				draw_rect(rect, Color("#e4b34d"), false, 3.0)
			if square == source_square:
				draw_rect(rect.grow(-4), Color("#73b887"), false, 3.0)
			var piece: String = chess.board[square]
			if not piece.is_empty():
				var glyph := piece.right(1)
				var ink := Color("#f7f1df") if piece.begins_with("w") else Color("#1b2026")
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(19, 40), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, ink)
	for file in range(8):
		draw_string(ThemeDB.fallback_font, BOARD_ORIGIN + Vector2(file * CELL + 23, 8 * CELL + 18), String.chr(97 + file), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d4c7b2"))
	draw_string(ThemeDB.fallback_font, Vector2(112, 108), "a8", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c3b9aa"))
	draw_string(ThemeDB.fallback_font, Vector2(112, 442), "a1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c3b9aa"))
	draw_string(ThemeDB.fallback_font, Vector2(250, 70), "TRẮNG  ·  CHIẾU HẾT TRONG MỘT NƯỚC", HORIZONTAL_ALIGNMENT_LEFT, 430, 13, Color("#e2c99f"))
