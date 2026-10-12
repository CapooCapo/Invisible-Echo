extends SceneTree

## The classroom checkpoint is still in the hallway, after the letter reveal.
## Reloading it must preserve the visible reveal and first-person framing.
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
	var actor := hall.get("actor") as CharacterBody3D
	var arm := actor.get_node("CameraPivot/CameraSpringArm") as SpringArm3D
	var pivot := actor.get_node("CameraPivot") as Node3D
	var labels: Array = hall.get("reveal_labels")
	_check(game.beat == game.Beat.CLASSROOM and game.letter_found,
		"scene_02 reload restores the classroom beat after the letter")
	_check(not hall.get("letter").visible,
		"scene_02 reload keeps the collected letter hidden")
	_check(labels.size() == 2 and labels[0].visible and labels[1].visible,
		"scene_02 reload preserves both red wall messages")
	_check(hall.get("reveal_tint").visible,
		"scene_02 reload preserves the blood-red world")
	_check(is_zero_approx(arm.spring_length) and is_equal_approx(pivot.position.y, 1.62),
		"scene_02 reload preserves the first-person camera")
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
