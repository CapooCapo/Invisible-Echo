extends SceneTree

## Controller-driven ascent/descent coverage for each aligned school stair core.
## Run: godot --headless --path . --script res://tests/test_school_stairs_physics.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for core in ["A", "B", "C"]:
		await _test_core(core)
	if failures == 0:
		print("SCHOOL_STAIRS_PHYSICS_PASS checks=%d" % checks)
	else:
		push_error("SCHOOL_STAIRS_PHYSICS_FAIL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_core(core: String) -> void:
	var school := load(SCENE).instantiate() as Node3D
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	var actor := school.get("player") as CharacterBody3D
	if actor == null:
		_check(false, "%s player exists" % core)
		school.queue_free()
		await process_frame
		return
	# Reach each entrance from the scene's actual south-gate spawn using the
	# controller's InputMap. No position/transform writes are used in this test.
	await _drive(actor, "move_up", 3.0)
	if core == "A":
		await _drive(actor, "move_left", 3.75)
	else:
		await _drive(actor, "move_right", 3.75)
	await _drive(actor, "move_up", 12.0)
	match core:
		"A":
			await _drive(actor, "move_left", 2.3)
			await _drive(actor, "move_down", 0.6)
			await _drive(actor, "move_left", 0.63)
		"B":
			await _drive(actor, "move_left", 3.75)
			await _drive(actor, "move_down", 0.6)
			await _drive(actor, "move_left", 0.36)
		"C":
			await _drive(actor, "move_right", 2.3)
			await _drive(actor, "move_down", 0.45)
			await _drive(actor, "move_right", 0.34)
	_check(actor.global_position.y < 0.5, "%s entrance reached from ground floor" % core)
	print("STAIR_ROUTE %s entrance=%s" % [core, actor.global_position])

	# Ascend L0, transfer laterally on the full walkable landing, ascend L1,
	# transfer back, then ascend L2 to the roof.
	await _drive(actor, "move_up", 2.0)
	await _drive(actor, "move_up", 0.25)
	await _drive(actor, "move_up", 0.35)
	_check(actor.global_position.y > 2.8, "%s first flight reaches level 2" % core)
	await _drive(actor, "move_right", 0.72)
	await _drive(actor, "move_down", 2.0)
	await _drive(actor, "move_down", 0.9)
	_check(actor.global_position.y > 5.8, "%s second flight reaches level 3" % core)
	await _drive(actor, "move_left", 0.72)
	await _drive(actor, "move_up", 2.0)
	await _drive(actor, "move_up", 0.25)
	await _drive(actor, "move_up", 0.35)
	_check(actor.global_position.y > 9.0, "%s third flight reaches roof" % core)
	print("STAIR_ROUTE %s roof=%s" % [core, actor.global_position])

	# Reverse the same landings/flights with controller input. The west/east
	# landing position varies slightly with the approach; recenter within the
	# walkable level-3 transfer pad when necessary, without changing transforms.
	await _drive(actor, "move_down", 0.35)
	await _drive(actor, "move_down", 2.0)
	if actor.global_position.z > -18.0:
		await _drive(actor, "move_up", 0.35)
	await _drive(actor, "move_right", 0.72)
	await _drive(actor, "move_up", 2.6)
	_check(actor.global_position.y > 2.8 and actor.global_position.y < 3.7,
		"%s descends to level 2" % core)
	await _drive(actor, "move_left", 0.72)
	await _drive(actor, "move_down", 2.6)
	_check(actor.global_position.y < 0.5, "%s descends to ground floor" % core)
	print("STAIR_ROUTE %s ground_return=%s" % [core, actor.global_position])
	school.queue_free()
	await process_frame

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
