extends SceneTree

## Independent architecture and physical-route checks for the standalone school.
## Run: godot --headless --path . --script res://tests/test_school_environment_3d.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
var checks := 0
var failures := 0
var school: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	school = load(SCENE).instantiate() as Node3D
	_check(school != null, "standalone school scene instantiates")
	if school == null:
		quit(1)
		return
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	for floor_name in ["Ground", "Level2", "Level3", "Rooftop"]:
		_check(school.get_node_or_null(floor_name) != null, "%s floor group exists" % floor_name)
	var class1_floor := school.get_node_or_null("Ground/LỚP HỌC 1 floor") as MeshInstance3D
	var class1_box := class1_floor.mesh as BoxMesh if class1_floor != null else null
	_check(class1_floor != null and class1_box != null
		and class1_floor.position.is_equal_approx(Vector3(16.0,.06,-17.0))
		and class1_box.size.is_equal_approx(Vector3(4.0,.12,6.0)),
		"Classroom 1 remains in the mapped east wing at player-scale dimensions")
	var class1_north_wall_body := school.get_node_or_null("Ground/LỚP HỌC 1 end wall northBody") as StaticBody3D
	var class1_north_wall := class1_north_wall_body.get_child(0) as CollisionShape3D if class1_north_wall_body != null else null
	_check(class1_north_wall != null and (class1_north_wall.shape as BoxShape3D).size.is_equal_approx(Vector3(4.0,3.12,.2)),
		"Classroom 1 north wall has a matching physical shell")
	var class1_door_body := school.get_node_or_null("Ground/LỚP HỌC 1 wooden door leaf body") as StaticBody3D
	var class1_door := class1_door_body.get_child(0) as CollisionShape3D if class1_door_body != null else null
	_check(class1_door != null and (class1_door.shape as BoxShape3D).size.is_equal_approx(Vector3(.12,2.25,.82)),
		"Classroom 1 open door leaf has a real collider")
	var class1_window_count := 0
	for child in (school.get_node("Ground") as Node).get_children():
		if child is StaticBody3D and String(child.name).begins_with("LỚP HỌC 1 exterior window"):
			class1_window_count += 1
	_check(class1_window_count == 2,
		"Classroom 1 windows are backed by physical panes")
	var east_gallery := school.get_node_or_null("Ground/East gallery") as MeshInstance3D
	_check(east_gallery != null and east_gallery.position.is_equal_approx(Vector3(11.3,.04,-8.0)),
		"east corridor follows the mapped east-wing circulation")
	var courtyard := school.get_node_or_null("SharedGroundOnlyCourtyard")
	_check(courtyard != null, "one shared ground courtyard exists")
	_check(school.find_children("SharedGroundOnlyCourtyard", "Node3D", true, false).size() == 1,
		"courtyard landmarks are not duplicated on upper floors")
	var level_y := [0.0, 3.2, 6.4]
	var landing_z := [-25.5, -19.5, -25.5]
	for core in ["A", "B", "C"]:
		for level in 3:
			var stair_path := "%s/StairCore%s" % [["Ground", "Level2", "Level3"][level], core]
			var stair := school.get_node_or_null(stair_path) as Node3D
			var landing_name: String = "Stair %s upper landing L%d" % [core, level]
			var landings := stair.find_children(landing_name, "MeshInstance3D", false, false) if stair != null else []
			_check(stair != null and landings.size() == 1, "%s stair core and upper landing exist on level %d" % [core, level + 1])
			if landings.is_empty():
				continue
			var p := (landings[0] as Node3D).global_position
			_check(is_equal_approx(p.x, [-21.0, 0.0, 21.0][["A", "B", "C"].find(core)])
				and is_equal_approx(p.z, landing_z[level]), "%s landing holds aligned switchback position on level %d" % [core, level + 1])
			_check(is_equal_approx(p.y, level_y[level] + 3.26), "%s upper landing aligns with next floor %d" % [core, level + 2])
	var roof_landings: Array[Vector3] = []
	for core in ["A", "B", "C"]:
		var last_landing := school.get_node_or_null("Level3/StairCore%s/Stair %s upper landing L2" % [core, core]) as Node3D
		_check(last_landing != null, "%s stair has explicit rooftop landing" % core)
		if last_landing != null:
			roof_landings.append(last_landing.global_position)
			_check(is_equal_approx(last_landing.global_position.y, 9.66), "%s stair landing reaches rooftop floor height" % core)
	_check(roof_landings.size() == 3, "three stair landings reach the rooftop")
	_check(school.find_children("WC NAM floor", "MeshInstance3D", true, false).size() == 1,
		"level-3 men's WC is represented once")
	_check(school.find_children("Stage platform", "MeshInstance3D", true, false).size() == 1
		and school.find_children("FountainBasin", "MeshInstance3D", true, false).size() == 1
		and school.find_children("Flag pole", "MeshInstance3D", true, false).size() == 1,
		"stage, fountain and flagpole each appear once")
	_check(school.find_children("WC NAM corridor wall northBody", "StaticBody3D", true, false).size() == 1
		and school.find_children("WC NAM corridor wall southBody", "StaticBody3D", true, false).size() == 1,
		"restroom entrance opens through its own east-wing corridor wall")
	for ramp_name in ["West wing courtyard rampBody", "East wing courtyard rampBody"]:
		_check(school.find_children(ramp_name, "StaticBody3D", true, false).size() == 1,
			"ground wing entry has collision ramp: %s" % ramp_name)
	var actor := school.get("player") as CharacterBody3D
	_check(actor != null and actor.get_node_or_null("HoangCollision") is CollisionShape3D,
		"school has the real player capsule for collision traversal")
	if actor != null:
		var capsule := actor.get_node("HoangCollision") as CollisionShape3D
		var capsule_shape := capsule.shape as CapsuleShape3D
		_check(is_equal_approx(capsule_shape.radius,.23) and is_equal_approx(capsule_shape.height,1.55),
			"player collision capsule matches the architecture clearance checks")
		_check(actor.spring_arm != null and is_equal_approx(actor.spring_arm.spring_length,0.0)
			and actor.camera != null and is_equal_approx(actor.camera.fov,76.0),
			"first-person camera is not offset into classroom or corridor walls")
	if actor != null:
		await _drive(actor, "move_up", 3.0)
		print("SCHOOL_ROUTE after_gate ", actor.global_position)
		_check(actor.global_position.z < 21.0, "player physically walks through the gate into courtyard")
		await _drive(actor, "move_right", 3.75)
		print("SCHOOL_ROUTE east_gallery ", actor.global_position)
		_check(actor.global_position.x > 10.0, "player physically reaches the east gallery")
		await _drive(actor, "move_up", 12.0)
		print("SCHOOL_ROUTE north_junction ", actor.global_position)
		_check(actor.global_position.z < -18.0, "player traverses the east corridor to the north stair junction")
		await _drive(actor, "move_right", 2.3)
		print("SCHOOL_ROUTE stair_c_approach ", actor.global_position)
		_check(actor.global_position.x > 18.0, "player reaches stair C corridor approach without teleporting")
		await _drive(actor, "move_down", .45)
		print("SCHOOL_ROUTE stair_c_lower_landing ", actor.global_position)
		_print_collisions(actor, "lower_landing_south")
		await _drive(actor, "move_right", .34)
		print("SCHOOL_ROUTE stair_c_ramp_entry ", actor.global_position)
		_print_collisions(actor, "portal_east")
		_check(actor.global_position.x > 19.0 and actor.global_position.x < 20.5,
			"player reaches stair C's walkable ramp lane")
		await _drive(actor, "move_up", 2.0)
		await _drive(actor, "move_up", .25)
		await _drive(actor, "move_up", .35)
		print("SCHOOL_ROUTE stair_c_floor2 ", actor.global_position)
		_print_collisions(actor, "stair_c_ascent_L0")
		_check(actor.global_position.y > 2.6, "player climbs stair C to level 2 with collision")
		await _drive(actor, "move_right", .72)
		await _drive(actor, "move_down", 2.0)
		await _drive(actor, "move_down", .9)
		print("SCHOOL_ROUTE stair_c_floor3 ", actor.global_position)
		_check(actor.global_position.y > 5.7, "player climbs stair C to level 3 with collision")
		_check(actor.global_position.z > -20.0, "player reaches level-3 landing from stair C")
		await _drive(actor, "move_left", .72)
		await _drive(actor, "move_up", 2.0)
		await _drive(actor, "move_up", .25)
		await _drive(actor, "move_up", .35)
		print("SCHOOL_ROUTE stair_c_roof ", actor.global_position)
		_check(actor.global_position.y > 8.9, "player climbs stair C to rooftop with collision")
		await _drive(actor, "move_down", .35)
		await _drive(actor, "move_down", 2.0)
		print("SCHOOL_ROUTE stair_c_return_level3 ", actor.global_position)
		_check(actor.global_position.y > 5.7 and actor.global_position.y < 7.0,
			"player descends stair C back to level-3 landing")
		# Go around the east-side exterior of Classroom 1 and its neighboring room
		# before rejoining the east corridor. All moves remain controller input.
		await _drive(actor, "move_right", .8)
		await _drive(actor, "move_down", 1.5)
		await _drive(actor, "move_left", 2.9)
		_check(actor.global_position.x < 14.0 and actor.global_position.z > -14.0,
			"player clears the east-wing classroom shell into the corridor")
		await _drive(actor, "move_down", 4.5)
		print("SCHOOL_ROUTE restroom_corridor ", actor.global_position)
		_check(actor.global_position.z > -1.0 and actor.global_position.z < 6.0,
			"player follows corridor to WC end-wing approach")
		await _drive(actor, "move_up", .27)
		await _drive(actor, "move_right", .7)
		_check(actor.global_position.x > 14.0, "player passes the corridor doorway and enters WC")
	if failures == 0:
		print("SCHOOL_ENVIRONMENT_3D_PASS checks=%d" % checks)
	else:
		push_error("SCHOOL_ENVIRONMENT_3D_FAIL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _drive(actor: CharacterBody3D, action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for _i in ceili(seconds * 60.0):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + description)

func _print_collisions(actor: CharacterBody3D, label: String) -> void:
	for i in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(i)
		var collider := collision.get_collider() as Node
		print("SCHOOL_COLLISION %s %s normal=%s" % [label, collider.get_path() if collider != null else "<null>", collision.get_normal()])
