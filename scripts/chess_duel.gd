extends Node2D

const ChessRules = preload("res://scripts/chess/chess_rules.gd")
const BOARD_ORIGIN := Vector2(296, 94)
const CELL := 46.0
const SEARCH_DEPTH := 1
const MATE_SCORE := 100000.0
const SEARCH_INFINITY := 1000000.0
const PIECE_VALUES := {"P": 100.0, "N": 320.0, "B": 330.0, "R": 500.0, "Q": 900.0, "K": 0.0}

enum Mode { STORY, NORMAL, CHALLENGE }
enum Result { PLAYING, WON, LOST, DRAW, RESIGNED }

var chess
var mode := Mode.STORY
var selecting_mode := true
var selected_mode_index := 0
var cursor := 0
var source_square := -1
var promotion_pending := false
var promotion_source := -1
var promotion_target := -1
var attempts := 0
var result := Result.PLAYING
var status: Label
var title: Label
var rng := RandomNumberGenerator.new()
var position_counts: Dictionary = {}

func _ready() -> void:
	AudioDirector.set_ambience("school_night")
	rng.randomize()
	_build_ui()
	if GameState.scene_id == "scene_13" and GameState.checkpoint_id == "checkmate_won":
		selecting_mode = false
		mode = Mode.STORY
		_reset_puzzle()
		result = Result.WON
		status.text = "Ván cờ đã khép lại. Nhấn E để đón bình minh."
	elif GameState.scene_id == "scene_13" and GameState.checkpoint_id == "chess_resigned":
		selecting_mode = false
		mode = Mode.STORY
		_reset_puzzle()
		result = Result.RESIGNED
		status.text = "An đã khép bàn cờ. Nhấn R để thử lại hoặc E để rời phòng."
	else:
		GameState.set_checkpoint("scene_13", "chess_challenge")
		_show_mode_selector()
	_refresh()
	queue_redraw()

func _show_mode_selector() -> void:
	selecting_mode = true
	result = Result.PLAYING
	selected_mode_index = clampi(selected_mode_index, 0, 2)
	chess = ChessRules.new()
	source_square = -1
	promotion_pending = false
	promotion_source = -1
	promotion_target = -1
	position_counts.clear()
	_refresh()
	queue_redraw()

func _start_mode(selected_mode: int) -> void:
	mode = clampi(selected_mode, Mode.STORY, Mode.CHALLENGE)
	selecting_mode = false
	result = Result.PLAYING
	GameState.set_flag("chess_resigned", false)
	GameState.set_flag("chess_boss_defeated", false)
	GameState.set_checkpoint("scene_13", "chess_challenge")
	if mode == Mode.STORY:
		_reset_puzzle()
	else:
		_reset_full_game()
	_refresh()
	queue_redraw()

func _reset_puzzle() -> void:
	chess = ChessRules.new()
	chess.set_position({"f6": "wK", "g6": "wQ", "h8": "bK"}, "w")
	cursor = chess.square_from_name("g6")
	source_square = -1
	promotion_pending = false
	promotion_source = -1
	promotion_target = -1
	result = Result.PLAYING
	position_counts.clear()
	_refresh()
	queue_redraw()

func _reset_full_game() -> void:
	chess = ChessRules.new()
	cursor = chess.square_from_name("e2")
	source_square = -1
	promotion_pending = false
	promotion_source = -1
	promotion_target = -1
	result = Result.PLAYING
	position_counts.clear()
	_record_current_position()
	_refresh()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	if promotion_pending:
		_handle_promotion_input(event.keycode)
		return
	if selecting_mode:
		_handle_mode_input(event.keycode)
		return
	if result == Result.WON:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			_leave_for_morning()
		return
	if result == Result.RESIGNED:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			_leave_to_bad_ending()
		elif event.keycode == KEY_R:
			attempts += 1
			GameState.set_flag("chess_resigned", false)
			GameState.set_checkpoint("scene_13", "chess_challenge")
			_start_mode(mode)
		return
	if result == Result.LOST or result == Result.DRAW:
		if event.keycode == KEY_R:
			attempts += 1
			_start_mode(mode)
		elif event.keycode == KEY_M:
			_show_mode_selector()
		return
	match event.keycode:
		KEY_LEFT: _move_cursor(0, -1)
		KEY_RIGHT: _move_cursor(0, 1)
		KEY_UP: _move_cursor(-1, 0)
		KEY_DOWN: _move_cursor(1, 0)
		KEY_E, KEY_ENTER: _activate_square(cursor)
		KEY_R:
			attempts += 1
			if mode == Mode.STORY:
				_reset_puzzle()
				status.text = "Thế cờ đã dựng lại. Chiếu hết chỉ cần một nước."
			else:
				_start_mode(mode)
		KEY_X: _resign()
	queue_redraw()

func _handle_mode_input(keycode: Key) -> void:
	if keycode == KEY_1:
		_start_mode(Mode.STORY)
	elif keycode == KEY_2:
		_start_mode(Mode.NORMAL)
	elif keycode == KEY_3:
		_start_mode(Mode.CHALLENGE)
	elif keycode == KEY_UP or keycode == KEY_LEFT:
		selected_mode_index = posmod(selected_mode_index - 1, 3)
		_refresh()
		queue_redraw()
	elif keycode == KEY_DOWN or keycode == KEY_RIGHT:
		selected_mode_index = posmod(selected_mode_index + 1, 3)
		_refresh()
		queue_redraw()
	elif keycode == KEY_E or keycode == KEY_ENTER:
		_start_mode(selected_mode_index)

func _leave_for_morning() -> void:
	GameState.set_checkpoint("scene_14", "morning_confrontation")
	get_tree().change_scene_to_file("res://scenes/14_binh_minh.tscn")

func _leave_to_bad_ending() -> void:
	GameState.set_checkpoint("scene_15", "ending")
	get_tree().change_scene_to_file("res://scenes/15_ending.tscn")

func _move_cursor(row_delta: int, file_delta: int) -> void:
	var row: int = cursor / 8
	var file: int = cursor % 8
	row = clampi(row + row_delta, 0, 7)
	file = clampi(file + file_delta, 0, 7)
	cursor = row * 8 + file

func _activate_square(target: int) -> void:
	if selecting_mode or result != Result.PLAYING:
		return
	if source_square < 0:
		if chess.board[target].begins_with("w"):
			source_square = target
			if mode == Mode.STORY:
				status.text = "Quân %s được chọn. Dẫn hậu đến g7." % chess.board[target].right(1)
			else:
				status.text = "Quân %s được chọn · E chọn ô đến." % chess.board[target].right(1)
		else:
			status.text = "Hoàng cầm quân Trắng. Chọn một quân Trắng."
		return
	var source := source_square
	source_square = -1
	if mode == Mode.STORY:
		if not chess.make_move(source, target):
			status.text = "Nước đi chưa hợp lệ. Hãy chọn lại quân và ô đến."
			return
		_handle_story_move()
	else:
		if _is_promotion_move(source, target):
			promotion_pending = true
			promotion_source = source
			promotion_target = target
			status.text = "Phong cấp: 1 Hậu · 2 Xe · 3 Tượng · 4 Mã"
			queue_redraw()
			return
		_play_full_game_move(source, target, "Q")
	queue_redraw()

func _is_promotion_move(source: int, target: int) -> bool:
	if chess.board[source] != "wP" or target / 8 != 0:
		return false
	for move in chess.legal_moves_from(source):
		if int(move.to) == target and bool(move.get("promotion", false)):
			return true
	return false

func _handle_promotion_input(keycode: Key) -> void:
	var promotion_piece := ""
	match keycode:
		KEY_1, KEY_Q: promotion_piece = "Q"
		KEY_2, KEY_R: promotion_piece = "R"
		KEY_3, KEY_B: promotion_piece = "B"
		KEY_4, KEY_N: promotion_piece = "N"
		KEY_X:
			promotion_pending = false
			_resign()
			return
	if promotion_piece.is_empty():
		status.text = "Chọn 1 Hậu · 2 Xe · 3 Tượng · 4 Mã"
		return
	promotion_pending = false
	_play_full_game_move(promotion_source, promotion_target, promotion_piece)

func _play_full_game_move(source: int, target: int, promotion_piece: String) -> void:
	if not chess.make_move(source, target, promotion_piece):
		status.text = "Nước đi chưa hợp lệ. Hãy chọn lại quân và ô đến."
		return
	_record_current_position()
	if _resolve_full_game_result():
		queue_redraw()
		return
	_make_ai_move()

func _handle_story_move() -> void:
	if chess.is_checkmate("b"):
		_finish_win()
	else:
		attempts += 1
		status.text = "Chưa chiếu hết. Thử lại từ thế cờ ban đầu bằng R."
		_reset_puzzle()

func _resolve_full_game_result() -> bool:
	var legal_moves: Array[Dictionary] = chess.all_legal_moves()
	if legal_moves.is_empty():
		if chess.is_in_check(chess.turn):
			if chess.turn == "b":
				_finish_win()
			else:
				_finish_loss()
		else:
			_finish_draw("Hòa cờ do hết nước đi.")
		return true
	if chess.halfmove_clock >= 100:
		_finish_draw("Hòa cờ theo luật 50 nước.")
		return true
	if _current_position_count() >= 3:
		_finish_draw("Hòa cờ do lặp lại vị trí ba lần.")
		return true
	if _has_insufficient_material():
		_finish_draw("Hòa cờ do không đủ quân chiếu hết.")
		return true
	return false

func _finish_win() -> void:
	result = Result.WON
	AudioDirector.play_sfx("puzzle_solved")
	GameState.set_flag("chess_boss_defeated")
	GameState.set_flag("chess_resigned", false)
	GameState.set_checkpoint("scene_13", "checkmate_won")
	status.text = "CHIẾU HẾT. An khẽ mỉm cười. Nhấn E để đón bình minh."
	_refresh()

func _finish_loss() -> void:
	result = Result.LOST
	GameState.set_flag("chess_boss_defeated", false)
	status.text = "An chiếu hết. Nhấn R để đấu lại hoặc M chọn chế độ."
	_refresh()

func _finish_draw(reason: String) -> void:
	result = Result.DRAW
	GameState.set_flag("chess_boss_defeated", false)
	status.text = "%s Nhấn R đấu lại hoặc M chọn chế độ." % reason
	_refresh()

func _resign() -> void:
	selecting_mode = false
	result = Result.RESIGNED
	GameState.set_flag("chess_resigned")
	GameState.set_flag("chess_boss_defeated", false)
	GameState.set_checkpoint("scene_13", "chess_resigned")
	status.text = "An khép bàn cờ. R thử lại · E rời phòng."
	_refresh()

func _make_ai_move() -> void:
	var legal_moves: Array[Dictionary] = chess.all_legal_moves()
	if legal_moves.is_empty():
		_resolve_full_game_result()
		return
	var selected_move: Dictionary
	if mode == Mode.NORMAL:
		selected_move = legal_moves[rng.randi_range(0, legal_moves.size() - 1)]
	else:
		selected_move = _choose_challenge_move(legal_moves)
	if selected_move.is_empty() or not chess.make_move(int(selected_move.from), int(selected_move.to)):
		push_error("Chess AI failed to make a generated legal move.")
		return
	_record_current_position()
	if not _resolve_full_game_result():
		if chess.is_in_check("w"):
			status.text = "An đi. Vua Hoàng đang bị chiếu · lượt Hoàng."
		else:
			status.text = "An đã đi. Lượt Hoàng."

func _choose_challenge_move(legal_moves: Array[Dictionary]) -> Dictionary:
	var best_move: Dictionary = {}
	var best_score := SEARCH_INFINITY
	for move in legal_moves:
		var snapshot := _capture_position()
		if chess.make_move(int(move.from), int(move.to)):
			var score := _minimax(SEARCH_DEPTH, -SEARCH_INFINITY, best_score, 1)
			if score < best_score:
				best_score = score
				best_move = move.duplicate()
		_restore_position(snapshot)
	return best_move if not best_move.is_empty() else legal_moves[0]

func _minimax(depth: int, alpha: float, beta: float, ply: int) -> float:
	var legal_moves: Array[Dictionary] = chess.all_legal_moves()
	if legal_moves.is_empty():
		if not chess.is_in_check(chess.turn):
			return 0.0
		return MATE_SCORE - ply if chess.turn == "b" else -MATE_SCORE + ply
	if chess.halfmove_clock >= 100 or _has_insufficient_material():
		return 0.0
	if depth <= 0:
		return _evaluate_position()
	var maximizing: bool = chess.turn == "w"
	var best_score := -SEARCH_INFINITY if maximizing else SEARCH_INFINITY
	for move in legal_moves:
		var snapshot := _capture_position()
		if chess.make_move(int(move.from), int(move.to)):
			var score := _minimax(depth - 1, alpha, beta, ply + 1)
			if maximizing:
				best_score = maxf(best_score, score)
				alpha = maxf(alpha, best_score)
			else:
				best_score = minf(best_score, score)
				beta = minf(beta, best_score)
		_restore_position(snapshot)
		if beta <= alpha:
			break
	return best_score

func _evaluate_position() -> float:
	var score := 0.0
	for square in range(64):
		var piece: String = chess.board[square]
		if piece.is_empty():
			continue
		var value: float = PIECE_VALUES[piece.right(1)]
		var row: int = square / 8
		var file: int = square % 8
		var center_bonus := 3.5 - (absf(float(file) - 3.5) + absf(float(row) - 3.5)) * 0.5
		value += center_bonus if piece.right(1) != "K" else 0.0
		score += value if piece.begins_with("w") else -value
	if chess.is_in_check("w"):
		score -= 35.0
	if chess.is_in_check("b"):
		score += 35.0
	return score

func _capture_position() -> Dictionary:
	return {
		"board": chess.board.duplicate(),
		"turn": chess.turn,
		"castling_rights": chess.castling_rights.duplicate(),
		"en_passant_square": chess.en_passant_square,
		"halfmove_clock": chess.halfmove_clock,
		"fullmove_number": chess.fullmove_number,
	}

func _restore_position(snapshot: Dictionary) -> void:
	chess.board = snapshot.board.duplicate()
	chess.turn = str(snapshot.turn)
	chess.castling_rights = snapshot.castling_rights.duplicate()
	chess.en_passant_square = int(snapshot.en_passant_square)
	chess.halfmove_clock = int(snapshot.halfmove_clock)
	chess.fullmove_number = int(snapshot.fullmove_number)

func _record_current_position() -> void:
	var key := _position_key()
	position_counts[key] = int(position_counts.get(key, 0)) + 1

func _current_position_count() -> int:
	return int(position_counts.get(_position_key(), 0))

func _position_key() -> String:
	var board_key := ""
	for piece in chess.board:
		board_key += piece + ","
	var rights_key := ""
	for right in ["wK", "wQ", "bK", "bQ"]:
		if bool(chess.castling_rights.get(right, false)):
			rights_key += right
	return "%s|%s|%s|%d" % [board_key, chess.turn, rights_key, chess.en_passant_square]

func _has_insufficient_material() -> bool:
	var minor_pieces: Array[Dictionary] = []
	for square in range(64):
		var piece: String = chess.board[square]
		if piece.is_empty() or piece.right(1) == "K":
			continue
		var kind := piece.right(1)
		if kind == "P" or kind == "R" or kind == "Q":
			return false
		minor_pieces.append({"kind": kind, "square": square})
	if minor_pieces.size() <= 1:
		return true
	var bishops_only := true
	var bishop_color := -1
	for minor in minor_pieces:
		if minor.kind != "B":
			bishops_only = false
			break
		var square: int = minor.square
		var square_color := ((square / 8) + (square % 8)) % 2
		if bishop_color < 0:
			bishop_color = square_color
		elif bishop_color != square_color:
			return false
	return bishops_only

func _mode_name(selected_mode: int) -> String:
	match selected_mode:
		Mode.STORY: return "Cốt truyện"
		Mode.NORMAL: return "Bình thường"
		Mode.CHALLENGE: return "Thử thách"
	return "Cờ vua"

func _refresh() -> void:
	if title == null or status == null:
		return
	if selecting_mode:
		title.text = "13 — VÁN CỜ CUỐI CÙNG"
		status.text = "Chọn chế độ · ↑↓ rồi E · hoặc nhấn 1 / 2 / 3"
		return
	title.text = "13 — %s  ·  LẦN THỬ %d" % [_mode_name(mode).to_upper(), attempts + 1]
	if result == Result.PLAYING:
		if mode == Mode.STORY:
			status.text = "Chiếu hết một nước: Trắng đi · mũi tên di chuyển · E chọn · R dựng lại · X dừng"
		else:
			status.text = "Hoàng cầm Trắng · mũi tên di chuyển · E chọn/đi · R chơi lại · X dừng"

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(34, 26)
	title.size = Vector2(900, 35)
	title.add_theme_color_override("font_color", Color("#f0e4d0"))
	title.add_theme_font_size_override("font_size", 24)
	layer.add_child(title)
	status = Label.new()
	status.position = Vector2(34, 491)
	status.size = Vector2(900, 42)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#e6c98f"))
	status.add_theme_font_size_override("font_size", 15)
	layer.add_child(status)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color("#11151b"))
	if selecting_mode:
		_draw_mode_selector()
		return
	draw_rect(Rect2(266, 82, 428, 406), Color("#252b31"))
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
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 33), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, ink)
	for file in range(8):
		draw_string(ThemeDB.fallback_font, BOARD_ORIGIN + Vector2(file * CELL + 19, 8 * CELL + 14), String.chr(97 + file), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d4c7b2"))
	draw_string(ThemeDB.fallback_font, BOARD_ORIGIN + Vector2(-22, 27), "a8", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c3b9aa"))
	draw_string(ThemeDB.fallback_font, BOARD_ORIGIN + Vector2(-22, 7 * CELL + 30), "a1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c3b9aa"))
	var board_heading := "TRẮNG · CHIẾU HẾT TRONG MỘT NƯỚC" if mode == Mode.STORY else "HOÀNG · TRẮNG     %s · ĐEN" % ("AN" if mode == Mode.NORMAL else "AN · THỬ THÁCH")
	draw_string(ThemeDB.fallback_font, Vector2(250, 70), board_heading, HORIZONTAL_ALIGNMENT_LEFT, 460, 13, Color("#e2c99f"))

func _draw_mode_selector() -> void:
	draw_rect(Rect2(Vector2(180, 92), Vector2(600, 360)), Color("#252b31"))
	draw_string(ThemeDB.fallback_font, Vector2(270, 148), "CHỌN CÁCH ĐẤU", HORIZONTAL_ALIGNMENT_LEFT, 420, 25, Color("#f0e4d0"))
	var labels := ["Cốt truyện  ·  giải thế chiếu hết", "Bình thường  ·  ván đầy đủ, An dễ", "Thử thách  ·  ván đầy đủ, An mạnh"]
	for index in range(labels.size()):
		var color := Color("#e4b34d") if index == selected_mode_index else Color("#d6c7a7")
		var prefix := "▶ " if index == selected_mode_index else "  "
		draw_string(ThemeDB.fallback_font, Vector2(250, 220 + index * 54), "%s%d. %s" % [prefix, index + 1, labels[index]], HORIZONTAL_ALIGNMENT_LEFT, 500, 19, color)
	draw_string(ThemeDB.fallback_font, Vector2(250, 407), "Bình thường: An đi ngẫu nhiên · Thử thách: tính nước đáp trả của Hoàng", HORIZONTAL_ALIGNMENT_LEFT, 500, 13, Color("#aeb4b7"))
