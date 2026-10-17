extends RefCounted

## Dependency-free legal chess move generator used by the final chapter.
const KNIGHT_STEPS := [Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1)]
const KING_STEPS := [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]
const ROOK_DIRECTIONS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const BISHOP_DIRECTIONS := [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]

var board: Array[String] = []
var turn := "w"
var castling_rights := {"wK": true, "wQ": true, "bK": true, "bQ": true}
var en_passant_square := -1
var halfmove_clock := 0
var fullmove_number := 1

func _init() -> void:
	reset()

func reset() -> void:
	board.resize(64)
	board.fill("")
	var back_row := ["R", "N", "B", "Q", "K", "B", "N", "R"]
	for file in range(8):
		board[file] = "b" + back_row[file]
		board[8 + file] = "bP"
		board[48 + file] = "wP"
		board[56 + file] = "w" + back_row[file]
	turn = "w"
	castling_rights = {"wK": true, "wQ": true, "bK": true, "bQ": true}
	en_passant_square = -1
	halfmove_clock = 0
	fullmove_number = 1

func set_position(pieces: Dictionary, side_to_move := "w") -> void:
	board.resize(64)
	board.fill("")
	for square_name in pieces:
		var square := square_from_name(str(square_name))
		if square >= 0:
			board[square] = str(pieces[square_name])
	turn = side_to_move
	castling_rights = {"wK": false, "wQ": false, "bK": false, "bQ": false}
	en_passant_square = -1
	halfmove_clock = 0
	fullmove_number = 1

func square_from_name(square_name: String) -> int:
	if square_name.length() != 2:
		return -1
	var file := square_name.unicode_at(0) - 97
	var rank := square_name.unicode_at(1) - 48
	if file < 0 or file > 7 or rank < 1 or rank > 8:
		return -1
	return (8 - rank) * 8 + file

func square_name(square: int) -> String:
	if square < 0 or square >= 64:
		return ""
	return String.chr(97 + square % 8) + str(8 - square / 8)

func legal_moves_from(source: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if source < 0 or source >= 64 or board[source].is_empty() or board[source].left(1) != turn:
		return moves
	for move in _pseudo_moves_from(source):
		var saved_board := board.duplicate()
		var saved_rights: Dictionary = castling_rights.duplicate()
		var saved_ep := en_passant_square
		var saved_halfmove_clock := halfmove_clock
		_apply_unchecked(move)
		var leaves_king_safe := not is_in_check(turn)
		board = saved_board
		castling_rights = saved_rights
		en_passant_square = saved_ep
		halfmove_clock = saved_halfmove_clock
		if leaves_king_safe:
			moves.append(move)
	return moves

func all_legal_moves() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for square in range(64):
		moves.append_array(legal_moves_from(square))
	return moves

func make_move(source: int, target: int, promotion := "Q") -> bool:
	for move in legal_moves_from(source):
		if int(move.to) == target:
			var applied := move.duplicate()
			if bool(applied.get("promotion", false)):
				applied["promotion_piece"] = promotion
			_apply_unchecked(applied)
			if turn == "b":
				fullmove_number += 1
			turn = "b" if turn == "w" else "w"
			return true
	return false

func is_in_check(color: String) -> bool:
	var king_square := -1
	for square in range(64):
		if board[square] == color + "K":
			king_square = square
			break
	if king_square < 0:
		return true
	var enemy := "b" if color == "w" else "w"
	return is_square_attacked(king_square, enemy)

func is_square_attacked(target: int, by_color: String) -> bool:
	var target_pos := Vector2i(target / 8, target % 8)
	for source in range(64):
		var piece := board[source]
		if piece.is_empty() or piece.left(1) != by_color:
			continue
		var kind := piece.right(1)
		var source_pos := Vector2i(source / 8, source % 8)
		var delta := target_pos - source_pos
		if kind == "P":
			var direction := -1 if by_color == "w" else 1
			if delta.y in [-1, 1] and delta.x == direction:
				return true
		elif kind == "N":
			if delta in KNIGHT_STEPS: return true
		elif kind == "K":
			if delta in KING_STEPS: return true
		elif kind == "R" or kind == "B" or kind == "Q":
			var is_straight := delta.x == 0 or delta.y == 0
			var is_diagonal := absi(delta.x) == absi(delta.y)
			if (kind == "R" and not is_straight) or (kind == "B" and not is_diagonal) or (kind == "Q" and not (is_straight or is_diagonal)):
				continue
			var step := Vector2i(signi(delta.x), signi(delta.y))
			var cursor := source_pos + step
			var blocked := false
			while cursor != target_pos:
				if not board[cursor.x * 8 + cursor.y].is_empty():
					blocked = true
					break
				cursor += step
			if not blocked:
				return true
	return false

func is_checkmate(color := turn) -> bool:
	if not is_in_check(color): return false
	var saved_turn := turn
	turn = color
	var result := all_legal_moves().is_empty()
	turn = saved_turn
	return result

func is_stalemate(color := turn) -> bool:
	if is_in_check(color): return false
	var saved_turn := turn
	turn = color
	var result := all_legal_moves().is_empty()
	turn = saved_turn
	return result

func _pseudo_moves_from(source: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece := board[source]
	var color := piece.left(1)
	var kind := piece.right(1)
	var row: int = source / 8
	var file: int = source % 8
	if kind == "P":
		var direction := -1 if color == "w" else 1
		var next_row := row + direction
		if _inside(next_row, file) and board[next_row * 8 + file].is_empty():
			_add_pawn_move(moves, source, next_row * 8 + file, color)
			var start_row := 6 if color == "w" else 1
			var double_row := row + direction * 2
			if row == start_row and board[double_row * 8 + file].is_empty():
				moves.append({"from": source, "to": double_row * 8 + file})
		for file_delta in [-1, 1]:
			var target_row: int = row + direction
			var target_file: int = file + int(file_delta)
			if not _inside(target_row, target_file): continue
			var target: int = target_row * 8 + target_file
			if not board[target].is_empty() and board[target].left(1) != color:
				_add_pawn_move(moves, source, target, color)
			elif target == en_passant_square:
				moves.append({"from": source, "to": target, "en_passant": true})
	elif kind == "N":
		for delta in KNIGHT_STEPS:
			_add_step_move(moves, source, row + delta.x, file + delta.y, color)
	elif kind == "K":
		for delta in KING_STEPS:
			_add_step_move(moves, source, row + delta.x, file + delta.y, color)
		_add_castling_moves(moves, source, color)
	else:
		var directions: Array[Vector2i] = []
		if kind == "R" or kind == "Q": directions.append_array(ROOK_DIRECTIONS)
		if kind == "B" or kind == "Q": directions.append_array(BISHOP_DIRECTIONS)
		for direction in directions:
			var target_row := row + direction.x
			var target_file := file + direction.y
			while _inside(target_row, target_file):
				var target := target_row * 8 + target_file
				if board[target].is_empty():
					moves.append({"from": source, "to": target})
				else:
					if board[target].left(1) != color:
						moves.append({"from": source, "to": target})
					break
				target_row += direction.x
				target_file += direction.y
	return moves

func _add_step_move(moves: Array[Dictionary], source: int, row: int, file: int, color: String) -> void:
	if not _inside(row, file): return
	var target := row * 8 + file
	if board[target].is_empty() or board[target].left(1) != color:
		moves.append({"from": source, "to": target})

func _add_pawn_move(moves: Array[Dictionary], source: int, target: int, color: String) -> void:
	var promotion_row := 0 if color == "w" else 7
	if target / 8 == promotion_row:
		moves.append({"from": source, "to": target, "promotion": true})
	else:
		moves.append({"from": source, "to": target})

func _add_castling_moves(moves: Array[Dictionary], source: int, color: String) -> void:
	var row := 7 if color == "w" else 0
	var enemy := "b" if color == "w" else "w"
	if source != row * 8 + 4 or is_in_check(color): return
	if castling_rights[color + "K"] and board[row * 8 + 5].is_empty() and board[row * 8 + 6].is_empty() and board[row * 8 + 7] == color + "R":
		if not is_square_attacked(row * 8 + 5, enemy) and not is_square_attacked(row * 8 + 6, enemy):
			moves.append({"from": source, "to": row * 8 + 6, "castle": "K"})
	if castling_rights[color + "Q"] and board[row * 8 + 1].is_empty() and board[row * 8 + 2].is_empty() and board[row * 8 + 3].is_empty() and board[row * 8] == color + "R":
		if not is_square_attacked(row * 8 + 2, enemy) and not is_square_attacked(row * 8 + 3, enemy):
			moves.append({"from": source, "to": row * 8 + 2, "castle": "Q"})

func _apply_unchecked(move: Dictionary) -> void:
	var source: int = move.from
	var target: int = move.to
	var piece := board[source]
	var captured := board[target]
	if bool(move.get("en_passant", false)):
		var captured_square := target + (8 if piece.left(1) == "w" else -8)
		captured = board[captured_square]
		board[captured_square] = ""
	board[target] = piece
	board[source] = ""
	if bool(move.get("promotion", false)):
		board[target] = piece.left(1) + str(move.get("promotion_piece", "Q"))
	if move.has("castle"):
		var row := source / 8
		if move.castle == "K":
			board[row * 8 + 5] = board[row * 8 + 7]
			board[row * 8 + 7] = ""
		else:
			board[row * 8 + 3] = board[row * 8]
			board[row * 8] = ""
	if piece == "wK":
		castling_rights.wK = false
		castling_rights.wQ = false
	elif piece == "bK":
		castling_rights.bK = false
		castling_rights.bQ = false
	_adjust_rook_rights(source, piece)
	_adjust_rook_rights(target, captured)
	en_passant_square = -1
	if piece.right(1) == "P" and absi(target - source) == 16:
		en_passant_square = (target + source) / 2
	if piece.right(1) == "P" or not captured.is_empty(): halfmove_clock = 0
	else: halfmove_clock += 1

func _adjust_rook_rights(square: int, piece: String) -> void:
	if piece == "wR":
		if square == 56: castling_rights.wQ = false
		elif square == 63: castling_rights.wK = false
	elif piece == "bR":
		if square == 0: castling_rights.bQ = false
		elif square == 7: castling_rights.bK = false

func _inside(row: int, file: int) -> bool:
	return row >= 0 and row < 8 and file >= 0 and file < 8
