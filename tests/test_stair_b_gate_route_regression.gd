extends SceneTree

## Gate-to-B regression: the real controller crosses the gallery and climbs
## past the upper chess-club shell without teleporting or touching transforms.
## Run: godot --headless --path . --script res://tests/test_stair_b_gate_route_regression.gd
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var school := load("res://scenes/visual/school_environment_3d.tscn").instantiate() as Node3D
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	var actor := school.get("player") as CharacterBody3D
	await _drive("move_up",3.0)
	await _drive("move_right",3.75)
	await _drive("move_up",12.0)
	await _drive("move_left",3.75)
	await _drive("move_down",.6)
	await _drive("move_left",.36)
	var at_landing := actor.global_position.distance_to(Vector3(-1.2,.12,-19.5)) < .6
	await _drive("move_up",2.6)
	var at_level_two := actor.global_position.y > 2.8 and actor.global_position.z < -24.0
	if at_landing and at_level_two:
		print("STAIR_B_GATE_ROUTE_PASS landing=%s level2=%s" % [at_landing,actor.global_position])
		quit(0)
	else:
		push_error("STAIR_B_GATE_ROUTE_FAIL landing=%s level2=%s" % [at_landing,actor.global_position])
		quit(1)

func _drive(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for frame in ceili(seconds * 60.0):
		await physics_frame
	Input.action_release(action)
	await physics_frame
