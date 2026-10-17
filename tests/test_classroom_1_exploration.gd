extends SceneTree

## Classroom 1 structure, collisions, and player-scale exploration.
## Run: godot --headless --path . --script res://tests/test_classroom_1_exploration.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var school := load(SCENE).instantiate() as Node3D
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	# The room is assembled as named static meshes/bodies under the ground floor.
	_check(school.find_children("LỚP HỌC 1 floor", "", true, false).size() == 2,
		"Classroom 1 shells exist on ground and upper school floors")
	for required in [
		"LỚP HỌC 1 Teacher desk collision",
		"LỚP HỌC 1 Student desk 1 collision",
		"LỚP HỌC 1 Student bench 1 collision",
		"LỚP HỌC 1 Class cabinet collision",
		"Classroom 1 authored furniture",
		"Ceiling Fan motor",
		"LỚP HỌC 1 cool fluorescent fixture",
		"LỚP HỌC 1 ceilingBody",
		"LỚP HỌC 1 wooden door leaf body",
	]:
		_check(school.find_children(required, "", true, false).size() == 1,
			"required classroom feature/collider exists: %s" % required)
	_check(school.find_children("LỚP HỌC 1 chalkboard", "", true, false).size() == 2,
		"ground and upper-floor Classroom 1 each have a chalkboard")
	var actor := school.get("player") as CharacterBody3D
	_check(actor != null, "real CharacterBody3D player exists")
	if actor == null:
		quit(1)
		return
	# Travel from the real scene spawn to the corridor outside Classroom 1.
	await _drive(actor, "move_up", 3.0)
	await _drive(actor, "move_right", 3.75)
	await _drive(actor, "move_up", 10.7)
	await _drive(actor, "move_down", 0.24)
	await _drive(actor, "move_right", 1.13)
	print("CLASSROOM1_ROUTE entrance=%s" % actor.global_position)
	_check(actor.global_position.x > 16.0 and actor.global_position.z < -15.8
		and actor.global_position.z > -16.5,
		"player enters Classroom 1 through its doorway")
	await _drive(actor, "move_up", 0.75)
	print("CLASSROOM1_ROUTE north_aisle=%s" % actor.global_position)
	_check(actor.global_position.y < 0.5 and actor.global_position.z < -18.5,
		"player walks past the first and second student desk rows")
	await _drive(actor, "move_down", 1.5)
	print("CLASSROOM1_ROUTE south_aisle=%s" % actor.global_position)
	_check(actor.global_position.y < 0.5 and actor.global_position.z > -15.0,
		"player can traverse the remaining row and return through the aisle")
	if failures == 0:
		print("CLASSROOM1_EXPLORATION_PASS checks=%d" % checks)
	else:
		push_error("CLASSROOM1_EXPLORATION_FAIL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _drive(actor: CharacterBody3D, action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for _frame in ceili(seconds * 60.0):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + description)
