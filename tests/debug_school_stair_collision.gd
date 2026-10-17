extends SceneTree

## Short-lived tester diagnostic for the Stair-C L0 ascent collision.
## Run: godot --headless --path . --script res://tests/debug_school_stair_collision.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var school := load("res://scenes/visual/school_environment_3d.tscn").instantiate() as Node3D
	root.add_child(school)
	current_scene = school
	await physics_frame
	var actor := school.get("player") as CharacterBody3D
	if actor == null:
		push_error("player missing")
		quit(1)
		return
	# The gate/gallery-to-portal route is independently established by the main tester harness.
	# Start at its observed ramp-entry point to isolate what blocks the upward flight.
	actor.global_position = Vector3(20.462, .161, -19.551)
	actor.velocity = Vector3.ZERO
	await physics_frame
	Input.action_press("move_up")
	var stalled_frames := 0
	var previous := actor.global_position
	for _frame in 300:
		await physics_frame
		var current := actor.global_position
		if current.z < -21.5 and absf(current.z - previous.z) < .0001:
			stalled_frames += 1
		else:
			stalled_frames = 0
		if stalled_frames == 4:
			print("STAIR_STALL position=%s velocity=%s on_floor=%s" % [current, actor.velocity, actor.is_on_floor()])
			for i in actor.get_slide_collision_count():
				var collision := actor.get_slide_collision(i)
				var collider := collision.get_collider() as Node
				var shape_node := collider.get_node_or_null("CollisionShape3D") as CollisionShape3D if collider else null
				var box := shape_node.shape as BoxShape3D if shape_node else null
				print("STAIR_COLLISION %s parent=%s global=%s shape_size=%s normal=%s depth=%s" % [collider.get_path() if collider else "<null>", collider.get_parent().name if collider else "<null>", collider.global_position if collider is Node3D else Vector3.ZERO, box.size if box else Vector3.ZERO, collision.get_normal(), collision.get_depth()])
				print("STAIR_CONTACT position=%s local=%s" % [collision.get_position(), collider.to_local(collision.get_position()) if collider else Vector3.ZERO])
			print("STAIR_STATE final-collider-count=%d" % actor.get_slide_collision_count())
			break
		previous = current
	Input.action_release("move_up")
	quit(0)
