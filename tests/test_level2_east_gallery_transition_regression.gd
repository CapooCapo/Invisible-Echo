extends SceneTree

## Input-driven regression for the Level2 north-gallery/east-gallery crossing.
## Run: godot --headless --path . --script res://tests/test_level2_east_gallery_transition_regression.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
const START := Vector3(11.3, 3.32, -20.5)
const TRANSITION_Z := -17.9

var school: Node3D
var actor: CharacterBody3D
var contacts := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	school = load(SCENE).instantiate() as Node3D
	if school == null:
		push_error("LEVEL2_EAST_GALLERY_FAIL production school scene did not instantiate")
		quit(1)
		return
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	actor = school.get("player") as CharacterBody3D
	if actor == null:
		push_error("LEVEL2_EAST_GALLERY_FAIL standalone school player is missing")
		quit(1)
		return

	actor.teleport_to(START)
	actor.controls_enabled = true
	for _frame in 3:
		await physics_frame
	print("LEVEL2_EAST_GALLERY_START pos=%s on_floor=%s" % [actor.global_position, actor.is_on_floor()])
	if not actor.is_on_floor() or absf(actor.global_position.y - START.y) > .15:
		push_error("LEVEL2_EAST_GALLERY_FAIL invalid start support at north/east gallery join: pos=%s on_floor=%s" % [actor.global_position, actor.is_on_floor()])
		quit(1)
		return

	await _drive("move_down", 1.0)
	var final_position := actor.global_position
	var collision_names := contacts.keys()
	collision_names.sort()
	var support_hit := _level2_support_hit(final_position)
	var has_level2_support := not support_hit.is_empty() and support_hit.collider is Node \
		and (school.get_node("Level2") as Node).is_ancestor_of(support_hit.collider as Node)
	var rail_contacts: Array[String] = []
	for collider_name in collision_names:
		if String(collider_name).begins_with("North Atrium Rail"):
			rail_contacts.append(String(collider_name))
	print("LEVEL2_EAST_GALLERY_TRACE start=%s target=z>%.2f final=%s on_floor=%s level2_height_ok=%s level2_support=%s contacts=%s" % [START, TRANSITION_Z, final_position, actor.is_on_floor(), absf(final_position.y - START.y) <= .15, support_hit.collider.get_path() if not support_hit.is_empty() else "none", collision_names])

	if final_position.z > TRANSITION_Z and actor.is_on_floor() \
		and absf(final_position.y - START.y) <= .15 and has_level2_support:
		print("LEVEL2_EAST_GALLERY_PASS final=%s" % final_position)
		quit(0)
		return
	if not rail_contacts.is_empty():
		push_error("LEVEL2_EAST_GALLERY_FAIL Level2 north/east gallery route is blocked by the transverse atrium railing: reached z=%.3f (required z>%.2f), rail_colliders=%s" % [final_position.z, TRANSITION_Z, rail_contacts])
	else:
		push_error("LEVEL2_EAST_GALLERY_FAIL route did not cross z=%.2f, but no North Atrium Rail collision was recorded: reached %s contacts=%s" % [TRANSITION_Z, final_position, collision_names])
	quit(1)

func _level2_support_hit(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .18, point - Vector3.UP * .18)
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	return school.get_world_3d().direct_space_state.intersect_ray(query)

func _drive(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for _frame in ceili(seconds * 60.0):
		await physics_frame
		for index in actor.get_slide_collision_count():
			var collider := actor.get_slide_collision(index).get_collider() as Node
			if collider != null:
				contacts[String(collider.name)] = true
	Input.action_release(action)
	await physics_frame
