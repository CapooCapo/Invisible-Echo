extends SceneTree

## Bounded scene-level regression for Scene 13's selectable chess modes.
## Uses the real scene and keyboard handler; state is isolated by the runner's XDG profile.
var checks := 0
var failures := 0
const RESULT_PLAYING := 0
const RESULT_WON := 1
const RESULT_RESIGNED := 4

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.flags.clear()
	state.inventory.clear()
	state.choices.clear()
	state.evidence.clear()
	state.scene_id = "scene_13"
	state.checkpoint_id = "chess_challenge"

	var story = _new_duel(state)
	await process_frame
	_check(story.selecting_mode and story.selected_mode_index == 0, "fresh Scene 13 shows the mode selector with Story highlighted")
	_check("Chọn chế độ" in story.status.text, "mode selector gives keyboard instructions")
	_press(story, KEY_1)
	_check(not story.selecting_mode and story.mode == story.Mode.STORY, "Story is selectable from the mode menu")
	_check(story.chess.board.count("") == 61 and story.chess.turn == "w", "Story loads the existing three-piece forced-mate puzzle")
	story.queue_free()
	await process_frame

	var normal = _new_duel(state)
	await process_frame
	_press(normal, KEY_RIGHT)
	_check(normal.selected_mode_index == 1, "selector moves to Normal with the right-arrow key")
	_press(normal, KEY_E)
	_check(not normal.selecting_mode and normal.mode == normal.Mode.NORMAL, "Normal is selectable with the menu confirmation key")
	_check(_piece_count(normal.chess) == 32 and normal.chess.turn == "w", "Normal starts with a full standard board and White to move")
	var normal_started := Time.get_ticks_msec()
	_press(normal, KEY_E)
	_press(normal, KEY_UP)
	_press(normal, KEY_UP)
	_press(normal, KEY_E)
	var normal_elapsed := Time.get_ticks_msec() - normal_started
	_check(normal.chess.board[normal.chess.square_from_name("e4")] == "wP", "Normal accepts the legal e2-e4 player move")
	_check(normal.chess.turn == "w" and normal.chess.fullmove_number == 2, "Normal AI makes a legal Black reply and returns the turn to White")
	_check(_piece_count(normal.chess) == 32 and _black_piece_count(normal.chess) == 16, "Normal AI reply preserves the legal piece count")
	_check(normal_elapsed < 3000, "Normal response completes within the 3-second bound")
	_press(normal, KEY_R)
	_check(normal.mode == normal.Mode.NORMAL and normal.result == normal.Result.PLAYING and _piece_count(normal.chess) == 32 and normal.chess.turn == "w", "R retries the full Normal game without switching modes")
	_press(normal, KEY_X)
	_check(normal.result == normal.Result.RESIGNED and state.flags.get("chess_resigned") and state.checkpoint_id == "chess_resigned", "X resignation records the intended result and legacy checkpoint")
	_press(normal, KEY_R)
	_check(normal.result == normal.Result.PLAYING and normal.mode == normal.Mode.NORMAL and not state.flags.get("chess_resigned"), "R after resignation clears the flag and retries the same mode")
	normal.queue_free()
	await process_frame

	var challenge = _new_duel(state)
	await process_frame
	_press(challenge, KEY_DOWN)
	_press(challenge, KEY_DOWN)
	_check(challenge.selected_mode_index == 2, "selector moves to Challenge with the down-arrow key")
	_press(challenge, KEY_ENTER)
	_check(not challenge.selecting_mode and challenge.mode == challenge.Mode.CHALLENGE, "Challenge is selectable with Enter")
	_check(_piece_count(challenge.chess) == 32 and challenge.chess.turn == "w", "Challenge starts with the full standard board and White to move")
	_press(challenge, KEY_E)
	_press(challenge, KEY_UP)
	_press(challenge, KEY_UP)
	_press(challenge, KEY_E)
	_check(challenge.chess.turn == "w" and challenge.chess.fullmove_number == 2, "Challenge AI makes a legal Black reply after e2-e4")

	# Tactical position: the only material-winning move is the black rook's capture of White's queen.
	challenge.chess.set_position({"a1": "wK", "h1": "wQ", "h8": "bK", "h2": "bR"}, "b")
	challenge.position_counts.clear()
	var challenge_started := Time.get_ticks_msec()
	challenge._make_ai_move()
	var challenge_elapsed := Time.get_ticks_msec() - challenge_started
	_check(challenge.chess.board[challenge.chess.square_from_name("h1")] == "bR" and challenge.chess.board[challenge.chess.square_from_name("h2")].is_empty(), "Challenge chooses the tactical rook capture instead of a quiet legal move")
	_check(challenge.chess.board.count("wQ") == 0 and challenge.chess.turn == "w", "Challenge's stronger choice is applied as a legal reply")
	_check(challenge_elapsed < 3000, "Challenge tactical search completes within the 3-second bound")
	_press(challenge, KEY_R)
	_check(challenge.mode == challenge.Mode.CHALLENGE and challenge.result == challenge.Result.PLAYING and _piece_count(challenge.chess) == 32, "R retries Challenge from a full board without switching modes")

	# White is checkmated; R must restart the selected mode after a loss.
	challenge.chess.set_position({"h8": "wK", "f6": "bK", "g7": "bQ"}, "w")
	_check(challenge._resolve_full_game_result() and challenge.result == challenge.Result.LOST, "full-game checkmate is reported as a player loss")
	_press(challenge, KEY_R)
	_check(challenge.mode == challenge.Mode.CHALLENGE and challenge.result == challenge.Result.PLAYING and _piece_count(challenge.chess) == 32, "R retries after loss in the same mode")

	# Black king h8 is stalemated by White king f7 and queen g6 (not in check).
	challenge.chess.set_position({"f7": "wK", "g6": "wQ", "h8": "bK"}, "b")
	_check(challenge._resolve_full_game_result() and challenge.result == challenge.Result.DRAW, "stalemate is reported as a draw")
	_press(challenge, KEY_R)
	_check(challenge.mode == challenge.Mode.CHALLENGE and challenge.result == challenge.Result.PLAYING and _piece_count(challenge.chess) == 32, "R retries after draw in the same mode")
	challenge.queue_free()
	await process_frame

	await _check_legacy_checkpoint(state, "chess_challenge", true, RESULT_PLAYING)
	await _check_legacy_checkpoint(state, "checkmate_won", false, RESULT_WON)
	await _check_legacy_checkpoint(state, "chess_resigned", false, RESULT_RESIGNED)

	if failures == 0:
		print("CHESS_MODES_RUNTIME_PASS checks=%d" % checks)
		quit()
	else:
		push_error("CHESS_MODES_RUNTIME_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _new_duel(state: Node) -> Node:
	state.set_checkpoint("scene_13", "chess_challenge")
	var duel = load("res://scenes/13_ban_co_boss.tscn").instantiate()
	root.add_child(duel)
	return duel

func _check_legacy_checkpoint(state: Node, checkpoint: String, expect_selector: bool, expected_result: int) -> void:
	state.set_checkpoint("scene_13", checkpoint)
	state.set_flag("chess_boss_defeated", checkpoint == "checkmate_won")
	state.set_flag("chess_resigned", checkpoint == "chess_resigned")
	var duel = load("res://scenes/13_ban_co_boss.tscn").instantiate()
	root.add_child(duel)
	await process_frame
	_check(state._is_valid_saved_route({"scene_id": "scene_13", "checkpoint_id": checkpoint}), "GameState still validates legacy checkpoint %s" % checkpoint)
	_check(duel.selecting_mode == expect_selector and duel.result == expected_result, "legacy checkpoint %s resumes its expected selector/result" % checkpoint)
	duel.queue_free()
	await process_frame

func _press(node: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	node._unhandled_input(event)

func _piece_count(chess) -> int:
	var count := 0
	for piece in chess.board:
		if not piece.is_empty():
			count += 1
	return count

func _black_piece_count(chess) -> int:
	var count := 0
	for piece in chess.board:
		if piece.begins_with("b"):
			count += 1
	return count

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
