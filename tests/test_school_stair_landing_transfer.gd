extends SceneTree

## Regression: a real CharacterBody3D must be able to change lanes on a
## switchback landing without stepping across an unsupported collider gap.
## Run: godot --headless --path . --script res://tests/test_school_stair_landing_transfer.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var school := load(SCENE).instantiate() as Node3D
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	var actor := school.get("player") as CharacterBody3D
	if actor == null:
		push_error("STAIR_TRANSFER_FAIL player missing")
		quit(1)
		return
	# Drive from the scene's actual south-gate spawn using Input actions only.
	await _drive(actor, "move_up", 3.0)
	await _drive(actor, "move_right", 3.75)
	await _drive(actor, "move_up", 12.0)
	await _drive(actor, "move_right", 2.3)
	await _drive(actor, "move_down", 0.45)
	await _drive(actor, "move_right", 0.34)
	await _drive(actor, "move_up", 2.0)
	await _drive(actor, "move_up", 0.25)
	# Clear the sloped flight's handrail end and enter the full-depth transfer pad.
	await _drive(actor, "move_up", 0.35)
	var before_transfer := actor.global_position
	await _drive(actor, "move_right", 0.72)
	var after_transfer := actor.global_position
	print("STAIR_TRANSFER C L0 before=%s after=%s" % [before_transfer, after_transfer])
	if before_transfer.y < 3.0 or after_transfer.x < 21.0 or after_transfer.y < 3.0:
		failures += 1
		for i in actor.get_slide_collision_count():
			var collision := actor.get_slide_collision(i)
			var collider := collision.get_collider() as Node
			print("STAIR_CONTACT path=%s player=%s contact=%s normal=%s" % [
				collider.get_path() if collider != null else "<null>",
				after_transfer,
				collision.get_position(),
				collision.get_normal(),
			])
	if failures == 0:
		print("STAIR_TRANSFER_PASS")
	else:
		push_error("STAIR_TRANSFER_FAIL failures=%d" % failures)
	quit(1 if failures else 0)

func _drive(actor: CharacterBody3D, action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for _frame in ceili(seconds * 60.0):
		await physics_frame
	Input.action_release(action)
	await physics_frame
