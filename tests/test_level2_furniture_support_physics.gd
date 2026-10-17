extends SceneTree

## Focused regression for substantial furniture in the reported level-2 rooms
## and the visibly unsupported Stair A flight.
## Run: godot --headless --path . --script res://tests/test_level2_furniture_support_physics.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"

var checks := 0
var failures: Array[String] = []
var school: Node3D
var actor: CharacterBody3D
var level2: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	school = load(SCENE).instantiate() as Node3D
	if school == null:
		_check(false, "production school scene instantiates")
		_finish()
		return
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	actor = school.get("player") as CharacterBody3D
	level2 = school.get_node_or_null("Level2") as Node3D
	_check(level2 != null, "production Level2 exists")
	if level2 == null:
		_finish()
		return

	_check_named_fixture("PHÒNG CLB 1", "club noticeboard")
	_check_named_fixture("PHÒNG CLB 1", "club storage cupboard")
	_check_box_instances("PHÒNG CLB 1 club stools", [
		Vector3(-19.1, 3.66, -16.45), Vector3(-19.1, 3.66, -13.55),
	], Vector3(.43, .12, .43))
	_check_supported_table("PHÒNG CLB 1 club activity table", Vector3(-20.55, 3.99, -16.45), Vector3(1.35, .13, .76), Vector3.ZERO, 2)
	_check_supported_table("PHÒNG CLB 1 club activity table", Vector3(-20.55, 3.99, -13.55), Vector3(1.35, .13, .76), Vector3.ZERO, 2)

	_check_named_fixture("THỰC HÀNH HÓA", "sink")
	_check_named_fixture("THỰC HÀNH HÓA", "chemical cabinet")
	_check_named_fixture("THỰC HÀNH HÓA", "reagent wall chart")
	var chemistry_benches: Array[Vector3] = [Vector3(4.65, 4.1, -26), Vector3(6, 4.1, -26), Vector3(7.35, 4.1, -26)]
	for bench in chemistry_benches:
		_check_supported_table("THỰC HÀNH HÓA lab bench", bench, Vector3(.8, .18, 2.2), Vector3.ZERO, 1)
	for bench_x in [4.65, 6.0, 7.35]:
		for vessel_z in [-26.7, -25.6]:
			_check_box_instance("THỰC HÀNH HÓA glass vessel", Vector3(bench_x, 4.36, vessel_z), Vector3(.15, .36, .15))

	_check_named_fixture("PHÒNG THỰC HÀNH", "porcelain wash sink")
	_check_named_fixture("PHÒNG THỰC HÀNH", "equipment cabinet")
	_check_named_fixture("PHÒNG THỰC HÀNH", "safety chart")
	_check_box_instances("PHÒNG THỰC HÀNH stools", [
		Vector3(17.2, 3.68, -17.72), Vector3(17.2, 3.68, -16.96), Vector3(17.2, 3.68, -16.2),
	], Vector3(.38, .1, .38))
	_check_supported_table("PHÒNG THỰC HÀNH work bench", Vector3(16, 4.1, -17), Vector3(1.6, .18, 2.2), Vector3(-.55, 0, -.8), 2)

	for desk_z in [-8.1, -7.0, -5.9]:
		_check_named_fixture_at("PHÒNG TIN HỌC CRT", Vector3(18, 4.45, desk_z), Vector3(.45, .48, .28))
		_check_supported_table("PHÒNG TIN HỌC computer desk", Vector3(18, 4.02, desk_z), Vector3(1.1, .12, .7), Vector3(.4, 0, 0), 2)

	_check_stair_a_supports()
	_finish()

func _check_named_fixture(title: String, fixture_name: String) -> void:
	var prefix := title + " " + fixture_name
	var found := 0
	for child in level2.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(prefix):
			found += 1
	_check(found > 0, "%s: named fixture exists" % prefix)

func _check_named_fixture_at(label: String, center: Vector3, size: Vector3) -> void:
	_check_box_instance(label, center, size)

func _check_box_instances(label: String, centers: Array[Vector3], size: Vector3) -> void:
	for center in centers:
		_check_box_instance(label, center, size)

func _check_box_instance(label: String, center: Vector3, size: Vector3) -> void:
	var found := _box_mesh_at(center, size)
	_check(found != null, "%s: expected box fixture at %s with dimensions %s" % [label, center, size])

func _check_supported_table(label: String, center: Vector3, size: Vector3, sample_offset: Vector3, minimum_supports: int) -> void:
	var tabletop := _box_mesh_at(center, size)
	_check(tabletop != null, "%s: substantial tabletop exists at %s" % [label, center])
	if tabletop == null:
		return
	var expected_top := tabletop.global_position.y + size.y * .5
	var sample := tabletop.global_position + sample_offset
	var hit := _ray(sample + Vector3(0, size.y * .5 + .45, 0), sample + Vector3(0, size.y * .5 - .18, 0))
	_check(not hit.is_empty() and hit.collider is StaticBody3D and absf(float(hit.position.y) - expected_top) < .08,
		"%s: standing-height ray hits its physical tabletop at y=%.3f (hit=%s, point=%s)" % [label, expected_top, hit.collider.name if not hit.is_empty() else "none", hit.position if not hit.is_empty() else "none"])
	var supports := _support_meshes_beneath(tabletop, size)
	_check(supports.size() >= minimum_supports, "%s: at least %d substantial support/leg meshes sit beneath the top; got %d" % [label, minimum_supports, supports.size()])
	for support in supports:
		var support_hit := _ray_through_narrow_support(support)
		_check(not support_hit.is_empty() and support_hit.collider is StaticBody3D,
			"%s: support at %s is physical; ray hit=%s" % [label, support.global_position, support_hit.collider.name if not support_hit.is_empty() else "none"])

func _support_meshes_beneath(tabletop: MeshInstance3D, top_size: Vector3) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var top_bottom := tabletop.global_position.y - top_size.y * .5
	var floor_top := 3.32
	for child in level2.get_children():
		if not child is MeshInstance3D:
			continue
		var candidate := child as MeshInstance3D
		var box := candidate.mesh as BoxMesh
		if box == null or box.size.y < .30:
			continue
		var p := candidate.global_position
		if p.y + box.size.y * .5 > top_bottom + .08 or p.y - box.size.y * .5 < floor_top - .12:
			continue
		if absf(p.x - tabletop.global_position.x) > top_size.x * .5 + box.size.x * .5 + .06:
			continue
		if absf(p.z - tabletop.global_position.z) > top_size.z * .5 + box.size.z * .5 + .06:
			continue
		result.append(candidate)
	return result

func _ray_through_narrow_support(support: MeshInstance3D) -> Dictionary:
	var box := support.mesh as BoxMesh
	var across_x := box.size.x <= box.size.z
	var direction := Vector3.RIGHT if across_x else Vector3.FORWARD
	var extent := (box.size.x if across_x else box.size.z) * .5 + .25
	var center := support.global_position
	return _ray(center - direction * extent, center + direction * extent)

func _box_mesh_at(center: Vector3, size: Vector3) -> MeshInstance3D:
	for child in level2.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		var box := mesh.mesh as BoxMesh
		if box == null:
			continue
		if mesh.global_position.distance_to(center) < .02 and box.size.is_equal_approx(size):
			return mesh
	return null

func _check_stair_a_supports() -> void:
	var stair := school.get_node_or_null("Ground/StairCoreA") as Node3D
	_check(stair != null, "ground-floor Stair A flight exists")
	if stair == null:
		return
	var ramp := stair.get_node_or_null("ContinuousWalkRamp A L0") as StaticBody3D
	_check(_has_collision_shape(ramp), "Stair A's visible flight has a continuous physical ramp")
	var stringer_meshes := 0
	var stringer_bodies := 0
	for child in stair.get_children():
		var node_name := String(child.name).to_lower()
		if not (node_name.contains("stringer") or node_name.contains("underflight support")):
			continue
		if child is MeshInstance3D:
			var member := child as MeshInstance3D
			if member.global_position.y >= 3.2 or absf(member.global_position.x + 22.2) > 1.5:
				continue
			stringer_meshes += 1
		elif child is StaticBody3D and _has_collision_shape(child):
			stringer_bodies += 1
	_check(stringer_meshes >= 2, "Stair A flight has two structural stringers/underflight members beneath the visible treads; got %d" % stringer_meshes)
	_check(stringer_bodies >= 2, "Stair A's two structural supports have physics bodies; got %d" % stringer_bodies)

func _has_collision_shape(node: Node) -> bool:
	if node == null:
		return false
	for child in node.get_children():
		if child is CollisionShape3D and child.shape != null:
			return true
	return false

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	if actor != null:
		query.exclude = [actor.get_rid()]
	return school.get_world_3d().direct_space_state.intersect_ray(query)

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _finish() -> void:
	for failure in failures:
		print("LEVEL2_FURNITURE_SUPPORT_FAIL: " + failure)
	print("LEVEL2_FURNITURE_SUPPORT_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
