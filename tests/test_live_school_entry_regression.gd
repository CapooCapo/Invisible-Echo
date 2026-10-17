extends SceneTree

## Production-scene geometry and real controller access to stair B.
## Run: godot --headless --path . --script res://tests/test_live_school_entry_regression.gd
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
	var actor := night.get("actor") as CharacterBody3D
	_check(actor != null and world.get_node_or_null("MappedSchoolEnvironment/Ground/StairCoreB") != null,
		"production checkpoint loads mapped school and physical player")
	if actor == null:
		quit(1)
		return
	_check(world.get_node_or_null("MainEntranceDoorBlocker") == null,
		"hidden legacy entrance has no invisible collider")
	_check(world.get_node_or_null("WalkableThreeFloorStairRamp") == null,
		"hidden legacy stair ramp has no invisible collider")
	var ground := world.get_node("MappedSchoolEnvironment/Ground") as Node3D
	for title in ["BẢNG TIN", "LỚP HỌC 3", "PHÒNG GIÁO VIÊN", "LỚP HỌC 4", "WC TẦNG 1"]:
		var west := ground.get_node_or_null(title + " inner wall west") as MeshInstance3D
		var east := ground.get_node_or_null(title + " inner wall east") as MeshInstance3D
		var jamb := ground.get_node_or_null(title + " door west jamb") as MeshInstance3D
		_check(west != null and east != null and jamb != null, title + " has a corridor-facing wall and framed door")
		if west != null and east != null:
			var west_end: float = west.position.x + (west.mesh as BoxMesh).size.x * .5
			var east_start: float = east.position.x - (east.mesh as BoxMesh).size.x * .5
			_check(absf(east_start - west_end - 1.5) < .03, title + " door opening is 1.5 m without wall protrusion")
	# Audit every named ground-floor room against the mapped plan and shell.
	var rooms := {
		"PHÒNG HIỆU TRƯỞNG": Vector2(-16,-18),
		"PHÒNG ĐOÀN": Vector2(-18.75,-8),
		"BẢNG TIN": Vector2(-17,-27),
		"LỚP HỌC 3": Vector2(-11,-27),
		"PHÒNG GIÁO VIÊN": Vector2(-5,-27),
		"LỚP HỌC 4": Vector2(6.5,-27),
		"WC TẦNG 1": Vector2(14,-27),
		"LỚP HỌC 1": Vector2(16,-17),
		"LỚP HỌC 2": Vector2(19,-7),
	}
	for title in rooms:
		var room_floor := ground.get_node_or_null(title + " floor") as MeshInstance3D
		var ceiling := ground.get_node_or_null(title + " ceiling") as MeshInstance3D
		var door := ground.get_node_or_null(title + " wooden door leaf") as MeshInstance3D
		_check(room_floor != null and ceiling != null and door != null, title + " floor, ceiling, and entrance are built")
		if room_floor != null and ceiling != null:
			_check(Vector2(room_floor.position.x,room_floor.position.z).distance_to(rooms[title]) < .01
				and absf(ceiling.position.y - 3.08) < .01, title + " position and storey height match plan")
	var outer_wall := ground.get_node_or_null("LỚP HỌC 1 outer wall wall below windows") as MeshInstance3D
	_check(outer_wall != null and ground.get_node_or_null("LỚP HỌC 1 exterior window second") != null,
		"classroom 1 has an enclosed exterior with two window bays")
	# Reproduce the blocked flank approach at the same yard-side elevation as the report.
	actor.teleport_to(Vector3(4.65, -.4, -19.5))
	await _settle()
	await _drive(actor, "move_left", 1.0)
	_check(actor.global_position.x < 2.25 and actor.global_position.y > -.08,
		"real controller enters stair B landing from east foundation")
	_check(bool(night.call("near_main_entry")), "school-entry interaction is reachable at stair B")
	var camera := actor.get_node_or_null("CameraPivot/CameraSpringArm/GameplayCamera") as Camera3D
	_check(camera != null and camera.global_position.y > actor.global_position.y + 1.2,
		"first-person camera remains above player on entry")
	if camera != null:
		var point := PhysicsPointQueryParameters3D.new()
		point.position = camera.global_position
		point.collision_mask = 1
		point.exclude = [actor.get_rid()]
		_check(actor.get_world_3d().direct_space_state.intersect_point(point).is_empty(),
			"camera eye is not embedded in a wall at stair B entry")
	actor.teleport_to(Vector3(-4.65,-.4,-19.5))
	await _settle()
	await _drive(actor, "move_right", 1.0)
	_check(actor.global_position.x > -2.25 and actor.global_position.y > -.08,
		"real controller enters stair B landing from west foundation")
	actor.teleport_to(Vector3(0,-.4,-15.8))
	await _settle()
	await _drive(actor, "move_up", 1.2)
	_check(actor.global_position.z < -18.2 and actor.global_position.y > -.08,
		"real controller enters stair B landing from south foundation")
	# Entering the mapped threshold advances yard -> ground_hall automatically;
	# the actor is already at the stair base when the first E is pressed.
	_check(str(game.get("night_phase")) == "ground_hall"
		and str(night.get("story_zone")) == "ground_hall",
		"crossing the mapped school threshold enters the ground hall")
	game.call("_interact_night_school")
	_check(str(game.get("night_phase")) == "stairs"
		and str(night.get("story_zone")) == "stairs", "E activates the mapped stair route")
	# Align with the north-going first flight and climb from the real landing.
	actor.teleport_to(Vector3(-1.18,.12,-19.1))
	await _settle()
	await _drive(actor, "move_up", 2.6)
	print("LIVE_STAIR_B_FIRST_FLIGHT position=%s" % actor.global_position)
	_check(actor.global_position.y > 2.8, "stair B first flight reaches level 2 in production")
	await _drive(actor, "move_right", .72)
	await _drive(actor, "move_down", 2.9)
	_check(actor.global_position.y > 5.8, "stair B second flight reaches level 3 in production")
	game.call("_process_night_school", .01)
	_check(str(game.get("night_phase")) == "upper_hall", "level 3 unlocks restroom objective")
	actor.teleport_to(Vector3(14.0,6.52,1.0))
	await _settle()
	_check(bool(night.call("near_restroom_door")), "mapped third-floor restroom door is reachable")
	game.call("_interact_night_school")
	_check(str(game.get("night_phase")) == "entering_restroom", "E opens mapped restroom")
	actor.teleport_to(Vector3(15.2,6.52,1.0))
	game.call("_process_night_school", .01)
	_check(str(game.get("night_phase")) == "friend_bao_line"
		and str(state.checkpoint_id) == "restroom_approach",
		"crossing mapped WC threshold preserves story and checkpoint")
	if failures == 0:
		print("LIVE_SCHOOL_ENTRY_PASS checks=%d" % checks)
	else:
		push_error("LIVE_SCHOOL_ENTRY_FAIL checks=%d failures=%d position=%s" % [checks, failures, actor.global_position])
	quit(1 if failures else 0)

func _settle() -> void:
	for i in 12:
		await physics_frame

func _drive(_actor: CharacterBody3D, action: StringName, seconds: float) -> void:
	Input.action_press(action)
	for i in ceili(seconds * 60.0):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + description)
