extends SceneTree

const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
var checks := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load(MAIN_SCENE).instantiate()
	root.add_child(game)
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
	_check(game.beat == game.Beat.HALLWAY and not game.letter_found, "retry resets to hallway checkpoint")

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

	print("FIRST_SLICE_PASS checks=%d" % checks)
	quit()

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error("CHECK FAILED: " + description)
		quit(1)
