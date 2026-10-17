extends SceneTree

## Structural support and collision regression for the rooms/stair flights
## identified by the whole-school visual audit.
## Run: godot --headless --path . --script res://tests/test_school_structural_furniture_regression.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var school := load(SCENE).instantiate() as Node3D
	_check(school != null, "standalone mapped school scene instantiates")
	if school == null:
		quit(1)
		return
	school.set("standalone_player_enabled", true)
	root.add_child(school)
	current_scene = school
	await physics_frame
	await physics_frame
	var level2 := school.get_node("Level2") as Node3D
	for target in [
		{"room":"PHÒNG CLB 1", "fixture":"club activity table top", "legs":"club activity table leg", "seats":"club stool", "minimum_tables":2, "minimum_legs":8},
		{"room":"THỰC HÀNH HÓA", "fixture":"lab bench top", "legs":"lab bench leg", "seats":"lab stool", "minimum_tables":3, "minimum_legs":12},
		{"room":"PHÒNG THỰC HÀNH", "fixture":"practice workstation top", "legs":"practice workstation leg", "seats":"practice stool", "minimum_tables":2, "minimum_legs":8},
		{"room":"PHÒNG TIN HỌC", "fixture":"computer desk top", "legs":"computer desk leg", "seats":"computer chair", "minimum_tables":6, "minimum_legs":24},
	]:
		_check_room_fixture(level2, target)
	_check_stairs(school)
	if failures == 0:
		print("SCHOOL_STRUCTURAL_FURNITURE_PASS checks=%d" % checks)
	else:
		push_error("SCHOOL_STRUCTURAL_FURNITURE_FAIL checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func _check_room_fixture(floor: Node3D, target: Dictionary) -> void:
	var room: String = target.room
	var fixtures := _matching_meshes(floor, room+" "+str(target.fixture))
	var legs := _matching_meshes(floor, room+" "+str(target.legs))
	var seats := _matching_meshes(floor, room+" "+str(target.seats))
	print("STRUCTURE %s fixtures=%s legs=%s seats=%s all=%s" % [room,_names(fixtures),_names(legs),_names(seats),_matching_names_containing(floor,room+" "+str(target.fixture))])
	_check(fixtures.size() >= int(target.minimum_tables), "%s has at least %d discrete work surfaces (found %d)" % [room,target.minimum_tables,fixtures.size()])
	_check(legs.size() >= int(target.minimum_legs), "%s has visible support legs beneath substantial work surfaces (found %d)" % [room,legs.size()])
	_check(seats.size() >= int(target.minimum_tables), "%s has seating/support stations for the work surfaces (found %d)" % [room,seats.size()])
	for leg in legs:
		_check(_has_body(floor,String(leg.name)), "%s support %s has matching physics" % [room,leg.name])
	for fixture in fixtures:
		_check(_tabletop_ray_hits(floor,fixture), "%s surface %s has a physical tabletop" % [room,fixture.name])

func _check_stairs(school: Node3D) -> void:
	var found := 0
	for floor_name in ["Ground","Level2","Level3"]:
		var floor := school.get_node(floor_name) as Node3D
		for core in ["A","B","C"]:
			var stair := floor.get_node_or_null("StairCore"+core) as Node3D
			_check(stair != null, "%s stair core exists on %s" % [core,floor_name])
			if stair == null:
				continue
			var flight := 0 if floor_name == "Ground" else (1 if floor_name == "Level2" else 2)
			var ramp_name: String = "ContinuousWalkRamp "+core+" L%d" % flight
			var ramp := stair.get_node_or_null(ramp_name) as StaticBody3D
			_check(ramp != null and ramp.get_child_count() > 0 and ramp.get_child(0) is CollisionShape3D,
				"%s floor %d stair flight has a continuous collision ramp" % [core,flight])
			var soffits := _matching_meshes(stair,"Stair "+core+" structural soffit L%d" % flight)
			_check(soffits.size() == 1, "%s floor %d stair flight has a visible underflight support/soffit (found %d)" % [core,flight,soffits.size()])
			found += soffits.size()
	_check(found == 9, "all nine visible stair flights have structural soffits")

func _matching_meshes(parent: Node, prefix: String) -> Array[MeshInstance3D]:
	var matches: Array[MeshInstance3D] = []
	for node in parent.get_children():
		var mesh := node as MeshInstance3D
		if mesh != null and String(mesh.name).begins_with(prefix):
			matches.append(mesh)
	return matches

func _names(nodes: Array[MeshInstance3D]) -> String:
	var result: Array[String] = []
	for node in nodes:
		result.append(String(node.name))
	return str(result)

func _matching_names_containing(parent: Node, phrase: String) -> String:
	var result: Array[String] = []
	for node in parent.get_children():
		if String(node.name).contains(phrase):
			result.append("%s:%s" % [node.name,node.get_class()])
	return str(result)

func _has_body(parent: Node, mesh_name: String) -> bool:
	for node in parent.get_children():
		var body := node as StaticBody3D
		if body != null and String(body.name).begins_with(mesh_name+"Body") and body.get_child_count() > 0 and body.get_child(0) is CollisionShape3D:
			return true
	return false

func _tabletop_ray_hits(floor: Node3D, tabletop: MeshInstance3D) -> bool:
	var school := floor.get_parent() as Node3D
	if school == null:
		return false
	var actor := school.get("player") as CharacterBody3D
	if actor == null:
		return false
	var center := tabletop.global_position
	var query := PhysicsRayQueryParameters3D.create(center+Vector3(0,.9,0),center-Vector3(0,.9,0))
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or float(hit.position.y) <= center.y:
		var collider_name := String((hit.get("collider") as Node).name) if not hit.is_empty() else "<none>"
		print("STRUCTURE_RAY_BAD_HIT %s hit=%s at=%s from=%s to=%s" % [tabletop.name,collider_name,hit.get("position"),query.from,query.to])
	return not hit.is_empty() and float(hit.position.y) > center.y

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHECK FAILED: "+description)
