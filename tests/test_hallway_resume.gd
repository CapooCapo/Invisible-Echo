extends SceneTree

## Reloading the current Scene 02 checkpoint must restore the classroom
## message and its configured first-person gameplay rig.
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	state.flags.clear()
	state.evidence.clear()
	state.scene_id = "scene_02"
	state.checkpoint_id = "classroom_letters"
	var game: Node = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await create_timer(0.46).timeout

	var hall: Node = game.hallway_visual
	var classroom: Node = game.classroom_visual
	var actor := classroom.get("actor") as CharacterBody3D
	var arm := actor.get("spring_arm") as SpringArm3D
	var pivot := actor.get("pivot") as Node3D
	var message := classroom.get("desk_message") as Label3D
	var cinematic_camera := classroom.get("cinematic_camera") as Camera3D
	_check(game.beat == game.Beat.CLASSROOM and game.letter_found,
		"scene_02 reload restores the classroom beat after the letter")
	_check(not hall.visible,
		"scene_02 reload does not show the inactive hallway and its already-collected letter")
	_check(classroom.visible and message != null and message.visible and message.text == "CỨU TÔI",
		"scene_02 reload restores the visible classroom plea")
	_check(is_zero_approx(arm.spring_length) and is_equal_approx(pivot.position.y, 1.42)
		and cinematic_camera != null and cinematic_camera.current,
		"scene_02 reload keeps the first-person gameplay rig configured during the opening shot")
	if failures == 0:
		print("HALLWAY_RESUME_PASS checks=%d" % checks)
		quit()
	else:
		push_error("HALLWAY_RESUME_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
