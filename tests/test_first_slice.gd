extends SceneTree

const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.persistence_enabled = false
	game_state.inventory.clear()
	game_state.flags.clear()
	game_state.evidence.clear()
	game_state.scene_id = "scene_01"
	game_state.checkpoint_id = "scene_01_start"
	game = load(MAIN_SCENE).instantiate()
	if game == null or game.get_script() == null:
		push_error("Main scene failed to load its game script.")
		quit(1)
		return
	root.add_child(game)
	current_scene = game
	await process_frame
	_check(game.beat == game.Beat.HALLWAY, "main scene starts in hallway")
	_check(game.objective.text.contains("lá thư"), "Vietnamese hallway objective appears")

	var start_position: Vector2 = game.player
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	_check(game.player.x > start_position.x, "right movement advances player")

	game.player = Vector2(492, 291)
	_press_key(KEY_E)
	_check(game.beat == game.Beat.LETTER and game.letter_found, "letter interaction opens letter")
	_check(game.message.text.contains("Cứu tôi"), "letter content includes Vietnamese story text")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.CLASSROOM, "letter advances to classroom")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.TOILET, "classroom advances to timed toilet scene")

	await create_timer(3.15).timeout
	_check(game.beat == game.Beat.DEAD, "missed three-second timer reaches YOU DIED")
	_check(game.retry_button.visible, "retry control is visible after failure")
	game.retry_button.pressed.emit()
	_check(game.beat == game.Beat.TOILET and game.letter_found, "retry returns directly to the toilet checkpoint")

	game.beat = game.Beat.CLASSROOM
	game.player = Vector2(360, 372)
	_press_key(KEY_E)
	Input.action_press("move_right")
	await create_timer(1.75).timeout
	Input.action_release("move_right")
	_check(game.beat == game.Beat.TOILET and game.player.x >= game.HIDE_SPOT.position.x, "player can reach the highlighted stall before timeout")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.MIRROR, "interacting in stall survives the event")
	game.player = Vector2(820, 205)
	_press_key(KEY_E)
	_check(game.beat == game.Beat.REFLECTION, "mirror interaction reveals reflection apparition")
	_check(game.objective.text.contains("Trong gương"), "reflection objective is shown in Vietnamese")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.GHOST, "turning around advances the mirror beat")
	_press_key(KEY_E)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "SchoolChapter", "mirror objective enters scenes 05–08")

	if failures == 0:
		print("FIRST_SLICE_PASS checks=%d" % checks)
		quit()
	else:
		push_error("FIRST_SLICE_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
