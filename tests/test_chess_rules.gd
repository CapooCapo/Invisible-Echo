extends SceneTree

const ChessRules = preload("res://scripts/chess/chess_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chess = ChessRules.new()
	_check(chess.all_legal_moves().size() == 20, "standard opening generates 20 legal white moves")
	var e2 := chess.square_from_name("e2")
	var e4 := chess.square_from_name("e4")
	_check(chess.make_move(e2, e4), "e2-e4 is a legal pawn double-step")
	_check(chess.turn == "b" and chess.board[e4] == "wP" and chess.en_passant_square == chess.square_from_name("e3"), "pawn move updates side and en-passant target")
	_check(not chess.make_move(e4, chess.square_from_name("e5")), "side-to-move cannot move the opponent's pawn")
	_check(chess.make_move(chess.square_from_name("g8"), chess.square_from_name("f6")), "black knight can make a legal reply")
	_check(chess.fullmove_number == 2, "fullmove number advances after black reply")

	chess.set_position({"f6": "wK", "g6": "wQ", "h8": "bK"})
	var queen := chess.square_from_name("g6")
	var mate_square := chess.square_from_name("g7")
	var mate_legal := false
	for move in chess.legal_moves_from(queen):
		if int(move.to) == mate_square: mate_legal = true
	_check(mate_legal, "queen can legally move to the forced-mate square")
	_check(chess.make_move(queen, mate_square), "forced-mate queen move is accepted")
	_check(chess.is_in_check("b") and chess.is_checkmate("b"), "forced-mate position is recognized as checkmate")
	_check(not chess.make_move(chess.square_from_name("a1"), chess.square_from_name("a2")), "illegal move returns false without mutating the board")

	chess.set_position({"e1": "wK", "a1": "wR", "h1": "wR", "e8": "bK"})
	chess.castling_rights = {"wK": true, "wQ": true, "bK": false, "bQ": false}
	var king := chess.square_from_name("e1")
	var castle_moves := chess.legal_moves_from(king)
	var can_castle_kingside := false
	var can_castle_queenside := false
	for move in castle_moves:
		if int(move.to) == chess.square_from_name("g1"): can_castle_kingside = true
		if int(move.to) == chess.square_from_name("c1"): can_castle_queenside = true
	_check(can_castle_kingside and can_castle_queenside, "clear, unattacked king and rooks can castle on either side")
	_check(chess.make_move(king, chess.square_from_name("g1")), "kingside castling is accepted")
	_check(chess.board[chess.square_from_name("g1")] == "wK" and chess.board[chess.square_from_name("f1")] == "wR" and chess.board[chess.square_from_name("h1")].is_empty(), "castling moves both king and rook")

	chess.set_position({"a1": "wK", "h8": "bK", "e5": "wP", "d5": "bP"})
	chess.en_passant_square = chess.square_from_name("d6")
	_check(chess.make_move(chess.square_from_name("e5"), chess.square_from_name("d6")), "en-passant capture is legal when the target is available")
	_check(chess.board[chess.square_from_name("d6")] == "wP" and chess.board[chess.square_from_name("d5")].is_empty(), "en passant removes the bypassed pawn")

	chess.set_position({"h1": "wK", "h8": "bK", "a7": "wP"})
	_check(chess.make_move(chess.square_from_name("a7"), chess.square_from_name("a8"), "N"), "pawn promotion accepts a chosen piece")
	_check(chess.board[chess.square_from_name("a8")] == "wN", "promotion replaces the pawn with the requested knight")

	chess.set_position({"e1": "wK", "h8": "bK", "e2": "wN", "e8": "bR"})
	var pinned_moves := chess.legal_moves_from(chess.square_from_name("e2"))
	var exposes_king := false
	for move in pinned_moves:
		if int(move.to) == chess.square_from_name("c3"): exposes_king = true
	_check(not exposes_king, "a pinned knight cannot expose its king to a rook")

	if failures == 0:
		print("CHESS_RULES_PASS checks=%d" % checks)
		quit()
	else:
		push_error("CHESS_RULES_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
