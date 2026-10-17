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
	await _complete_opening_to_scene03()
	_check(game.beat == game.Beat.TOILET and game.active_room == "restroom",
		"opening cinematic hands off to the Scene 03 restroom beat")
	_check(game_state.scene_id == "scene_03", "Chapter 01 handoff records Scene 03")

	var hallway_actor := game.hallway_visual.get("actor") as CharacterBody3D
	_check(hallway_actor != null, "hallway player rig remains available after opening handoff")

	await create_timer(3.15).timeout
	_check(game.beat == game.Beat.DEAD, "missed three-second timer reaches YOU DIED")
	_check(game.retry_button.visible, "retry control is visible after failure")
	game.retry_button.pressed.emit()
	_check(game.beat == game.Beat.TOILET and game.letter_found, "retry returns directly to the toilet checkpoint")

	await process_frame
	_press_key(KEY_E)
	_check(bool(game.restroom_visual.get("stall_door_open")), "E opens the hide stall")
	await create_timer(0.7).timeout
	Input.action_press("move_left")
	await create_timer(0.55).timeout
	Input.action_release("move_left")
	_check(game.beat == game.Beat.TOILET and bool(game.restroom_visual.call("inside_hide_stall")) and game.hide_time > 0.0, "left movement reaches the open stall before the three-second timeout")
	_press_key(KEY_E)
	_check(game.beat == game.Beat.TOILET and game.is_hidden, "interacting in stall begins the hide stage")
	await create_timer(1.5).timeout
	_check(game.beat == game.Beat.MIRROR, "surviving the hide stage reveals the mirror objective")
	game.player = Vector2(820, 205)
	_press_key(KEY_E)
	_check(game.beat == game.Beat.REFLECTION, "mirror interaction reveals reflection apparition")
	_check(game.objective.text.contains("Trong gương"), "reflection objective is shown in Vietnamese")
	await create_timer(0.7).timeout
	_press_key(KEY_E)
	_check(game.beat == game.Beat.GHOST, "turning around advances the mirror beat")
	_press_key(KEY_E)
	await process_frame
	await process_frame
	_check(current_scene == game and int(game.get("beat")) == int(game.get("Beat").get("NIGHT_SCHOOL"))
		and bool(game.get("night_school_visual").visible), "mirror objective hands off to the production 3D Scene 05 stage")

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


func _complete_opening_to_scene03() -> void:
	for i in 3:
		game.call("_advance_opening_sequence")
	for i in 2:
		game.call("_advance_opening_sequence")
	_check(str(game.get("opening_phase")) == "scene01_find_letter", "opening gives control for the physical letter pickup")
	var hall: Node = game.get("hallway_visual")
	var letter := hall.get("letter") as Node3D
	var actor := hall.get("actor") as CharacterBody3D
	actor.call("teleport_to", letter.position + Vector3(0, 0, .7))
	game.call("_interact")
	_check(game.get("opening_letter_card").visible, "E reveals the short envelope-front message")
	_check(game.get("opening_letter_contents").text == "CỨU TÔI", "only CỨU TÔI is revealed in Scene 01")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game.call("_unhandled_input", escape)
	_check(game.get("opening_speaker").text == "Hoàng"
		and game.get("opening_subtitle").text == "Lần sau viết SOS nhé.", "Hoang's SOS remark follows Esc")
	game.call("_advance_opening_sequence")
	for i in 4:
		game.call("_advance_opening_sequence")
	game.call("_advance_opening_sequence")
	await create_timer(.8).timeout
	game.call("_process_opening_sequence", 1.0)
	game.call("_process_opening_sequence", .6)
	game.call("_process_opening_sequence", 1.2)
	game.call("_process_opening_sequence", 3.0)
	await create_timer(1.05).timeout
	_check(str(game.get("opening_phase")) == "classroom_establish", "Scene 01 fades to the morning classroom")
	game.call("_process_opening_sequence", 3.0)
	for i in 3:
		game.call("_advance_opening_sequence")
	for i in 3:
		game.call("_process_opening_sequence", 1.0)
	game.call("_process_opening_sequence", 3.0)
	game.call("_advance_opening_sequence")
	game.call("_advance_opening_sequence")
	game.call("_advance_opening_sequence")
	await create_timer(1.05).timeout
	game.call("_process_opening_sequence", 3.0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
