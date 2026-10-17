extends SceneTree

## Regression for the two mapped west-wing offices in the playable F5 school.
## Run: godot --headless --path . --script res://tests/test_west_offices_access_physics.gd
const MAIN := "res://scenes/01_hanh_lang.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("GameState")
	state.persistence_enabled = false
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	var game: Node = load(MAIN).instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	await process_frame
	var night: Node = game.get("night_school_visual")
	var world: Node3D = night.get("world")
	var school := world.get_node_or_null("MappedSchoolEnvironment") as Node3D
	var actor := night.get("actor") as CharacterBody3D
	_check(school != null and actor != null, "F5 checkpoint has mapped school and real controller")
	if school == null or actor == null:
		quit(1)
		return
	# Begin at the production checkpoint, with no teleport. The west wing's
	# gallery transition must connect the courtyard to the office entrances.
	await _drive("move_up", 3.0)
	await _drive("move_left", 3.75)
	print("WEST_OFFICE_ROUTE courtyard_west=%s" % actor.global_position)
	await _drive("move_up", 8.0)
	print("WEST_OFFICE_ROUTE doan_gallery=%s" % actor.global_position)
	_check(actor.global_position.z < -7.0 and actor.global_position.y > -.1,
		"courtyard-to-west-gallery path reaches Đoàn office elevation")
	await _drive("move_left", 1.0)
	print("WEST_OFFICE_ROUTE doan_from_gate=%s" % actor.global_position)
	_check(actor.global_position.x < -13.85 and absf(actor.global_position.z + 8.0) < 1.0,
		"from south gate, controller enters Đoàn office")
	await _drive("move_right", 1.35)
	await _drive("move_up", 3.0)
	print("WEST_OFFICE_ROUTE principal_gallery=%s" % actor.global_position)
	_check(actor.global_position.z < -17.0 and actor.global_position.y > -.1,
		"west gallery stays connected past Đoàn toward principal's office")
	await _drive("move_left", 1.2)
	print("WEST_OFFICE_ROUTE principal_from_gate=%s" % actor.global_position)
	_check(actor.global_position.x < -14.35 and absf(actor.global_position.z + 18.0) < 1.0,
		"from south gate, controller enters principal's office")
	for room in [
		{"name": "PHÒNG HIỆU TRƯỞNG", "z": -18.0, "door_x": -14.0},
		{"name": "PHÒNG ĐOÀN", "z": -8.0, "door_x": -13.5},
	]:
		var title: String = room.name
		var z: float = room.z
		var door_x: float = room.door_x
		actor.teleport_to(Vector3(-12.0, .12, z))
		await _settle()
		var approach := actor.global_position
		await _drive("move_left", 1.0)
		print("WEST_OFFICE_ROUTE %s approach=%s entered=%s" % [title, approach, actor.global_position])
		_check(actor.global_position.x < door_x - .35 and absf(actor.global_position.z - z) < .4,
			"%s: player-sized controller crosses the corridor doorway" % title)
		var desk: MeshInstance3D = school.get_node_or_null("Ground/%s work table" % title)
		_check(desk != null, "%s: work table exists" % title)
		if desk != null:
			var desk_center := desk.global_position
			var query := PhysicsRayQueryParameters3D.create(desk_center+Vector3(0,1.0,0), desk_center-Vector3(0,1.1,0))
			query.collision_mask = 1
			query.exclude = [actor.get_rid()]
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
			print("WEST_OFFICE_DESK %s center=%s visual_top=%.3f hit=%s" % [title, desk_center, desk.global_position.y + (desk.mesh as BoxMesh).size.y * .5, hit])
			_check(not hit.is_empty() and float(hit.position.y) > .80,
				"%s: visible work table has a physical tabletop" % title)
	if failures == 0:
		print("WEST_OFFICES_ACCESS_PHYSICS_PASS checks=%d" % checks)
	else:
		push_error("WEST_OFFICES_ACCESS_PHYSICS_FAIL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _settle() -> void:
	for _frame in 12:
		await physics_frame

func _drive(action: StringName, seconds: float) -> void:
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
