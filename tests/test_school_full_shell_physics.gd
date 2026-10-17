extends SceneTree

## Full mapped-room shell and physics roster. Run:
## godot --headless --path . --script res://tests/test_school_full_shell_physics.gd
const SCENE := "res://scenes/visual/school_environment_3d.tscn"
var checks := 0
var failures: Array[String] = []
var school: Node3D
var actor: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	school = load(SCENE).instantiate() as Node3D
	root.add_child(school)
	current_scene = school
	await physics_frame
	await process_frame
	actor = school.get("player") as CharacterBody3D
	_check(actor != null, "real player capsule exists")
	if actor == null:
		_finish(0)
		return
	var roster: Array[Dictionary] = [
		# Ground: 9 named rooms.
		_r(0,"PHÒNG HIỆU TRƯỞNG",-16,-18,4,6,"west","office"),
		_r(0,"PHÒNG ĐOÀN",-18.75,-8,10.5,6,"west","office"),
		_r(0,"BẢNG TIN",-17,-27,5,7,"north","office"),
		_r(0,"LỚP HỌC 3",-11,-27,7,7,"north","class"),
		_r(0,"PHÒNG GIÁO VIÊN",-5,-27,5,7,"north","office"),
		_r(0,"LỚP HỌC 4",6.5,-27,7,7,"north","class"),
		_r(0,"WC TẦNG 1",14,-27,6,7,"north","restroom"),
		_r(0,"LỚP HỌC 1",16,-17,4,6,"east","class"),
		_r(0,"LỚP HỌC 2",19,-7,10,6,"east","class"),
		# Level 2: 9 named rooms.
		_r(1,"PHÒNG CLB 1",-18.75,-15,10.5,6,"west","club"),
		_r(1,"PHÒNG CLB 2",-18.75,-8,10.5,6,"west","club"),
		_r(1,"WC GIÁO VIÊN",-17,-27,5,7,"north","restroom"),
		_r(1,"THƯ VIỆN",-10,-27,8,7,"north","library"),
		_r(1,"CLB CỜ VUA",-4,-27,4,7,"north","chess"),
		_r(1,"THỰC HÀNH HÓA",6,-27,7,7,"north","lab"),
		_r(1,"NHÀ KHO",14,-27,6,7,"north","storage"),
		_r(1,"PHÒNG THỰC HÀNH",16,-17,4,6,"east","lab"),
		_r(1,"PHÒNG TIN HỌC",19,-7,10,6,"east","computer"),
		# Level 3: 10 named rooms, including the east-wing Nam WC.
		_r(2,"PHÒNG HỌC NGHỀ 1",-16,-18,4,6,"west","vocational"),
		_r(2,"PHÒNG HỌC NGHỀ 2",-18.75,-8,10.5,6,"west","vocational"),
		_r(2,"BẢNG TIN TẦNG 3",-17,-27,5,7,"north","office"),
		_r(2,"LỚP HỌC 3",-11,-27,7,7,"north","class"),
		_r(2,"PHÒNG HỌC",-5,-27,5,7,"north","class"),
		_r(2,"LỚP HỌC 4",6.5,-27,7,7,"north","class"),
		_r(2,"PHÒNG HỌC 5",14,-27,6,7,"north","class"),
		_r(2,"LỚP HỌC 1",16,-17,4,6,"east","class"),
		_r(2,"LỚP HỌC 2",19,-7,10,6,"east","class"),
		_r(2,"WC NAM",19,1,10,6,"east","restroom"),
	]
	_check(roster.size() == 28, "explicit roster has 28 named rooms")
	for room in roster:
		await _check_room(room)
	_check_fence()
	_finish(roster.size())

func _r(level: int, title: String, cx: float, cz: float, width: float, depth: float, side: String, kind: String) -> Dictionary:
	return {"level":level,"title":title,"cx":cx,"cz":cz,"width":width,"depth":depth,"side":side,"kind":kind}

func _check_room(room: Dictionary) -> void:
	var title: String = room.title
	var level: int = room.level
	var floor_name: String = ["Ground","Level2","Level3"][level]
	var parent := school.get_node(floor_name) as Node3D
	var y: float = level * 3.2
	var cx: float = room.cx
	var cz: float = room.cz
	var width: float = room.width
	var depth: float = room.depth
	var side: String = room.side
	var prefix := "%s/%s" % [floor_name,title]
	var floor_mesh := parent.get_node_or_null(title+" floor") as MeshInstance3D
	var floor_box := floor_mesh.mesh as BoxMesh if floor_mesh != null else null
	_check(floor_box != null and Vector2(floor_mesh.position.x,floor_mesh.position.z).distance_to(Vector2(cx,cz)) < .65
		and absf(floor_box.size.x-width) < .75 and absf(floor_box.size.z-depth) < .75,
		prefix+" floor footprint matches the approximate mapped room bay")
	_check(_body(parent,title+" floorBody"), prefix+" floor is solid")
	_check(_body(parent,title+" ceilingBody"), prefix+" ceiling is solid")
	_check(_body(parent,title+" outer wall wall below windowsBody")
		and _body(parent,title+" outer wall wall above windowsBody"), prefix+" exterior window wall has solid sill and lintel")
	if side == "north":
		_check(_body(parent,title+" west wallBody") and _body(parent,title+" east wallBody"), prefix+" west/east partition sides are solid")
		_check(_body(parent,title+" inner wall westBody") and _body(parent,title+" inner wall eastBody"), prefix+" corridor side has solid door flanks")
	else:
		_check(_body(parent,title+" end wall northBody") and _body(parent,title+" end wall southBody"), prefix+" north/south partition sides are solid")
		_check(_body(parent,title+" corridor wall northBody") and _body(parent,title+" corridor wall southBody"), prefix+" corridor side has solid door flanks")
	_check_door_rays(room,y,prefix)
	_check_furniture(room,y,prefix)
	await _check_local_capsule_entry(room,y,prefix)

func _body(parent: Node3D, label: String) -> bool:
	var body := parent.get_node_or_null(label) as StaticBody3D
	return body != null and body.get_child_count() > 0 and body.get_child(0) is CollisionShape3D

func _check_door_rays(room: Dictionary, y: float, prefix: String) -> void:
	var cx: float = room.cx
	var cz: float = room.cz
	var side: String = room.side
	var opening_clear := false
	var opening_hit: Dictionary = {}
	var flank_a := false
	var flank_b := false
	if side == "north":
		var wall_z: float = cz + float(room.depth)*.5
		opening_hit = _ray(Vector3(cx,y+1.25,wall_z+.5),Vector3(cx,y+1.25,wall_z-.5))
		opening_clear = opening_hit.is_empty()
		flank_a = not _ray(Vector3(cx-1.1,y+1.25,wall_z+.5),Vector3(cx-1.1,y+1.25,wall_z-.5)).is_empty()
		flank_b = not _ray(Vector3(cx+1.1,y+1.25,wall_z+.5),Vector3(cx+1.1,y+1.25,wall_z-.5)).is_empty()
	else:
		var inner_sign := -1.0 if side == "east" else 1.0
		var wall_x: float = cx + inner_sign*float(room.width)*.5
		var corridor_sign := inner_sign
		var door_z: float = cz+.85 if room.title == "LỚP HỌC 1" and room.level == 0 else cz
		opening_hit = _ray(Vector3(wall_x+corridor_sign*.5,y+1.25,door_z),Vector3(wall_x-corridor_sign*.5,y+1.25,door_z))
		opening_clear = opening_hit.is_empty()
		flank_a = not _ray(Vector3(wall_x+corridor_sign*.5,y+1.25,door_z-1.1),Vector3(wall_x-corridor_sign*.5,y+1.25,door_z-1.1)).is_empty()
		flank_b = not _ray(Vector3(wall_x+corridor_sign*.5,y+1.25,door_z+1.1),Vector3(wall_x-corridor_sign*.5,y+1.25,door_z+1.1)).is_empty()
	_check(opening_clear, prefix+" doorway center is physically open; hit="+str(opening_hit.collider.get_path() if not opening_hit.is_empty() else "none")+" at "+str(opening_hit.position if not opening_hit.is_empty() else "none"))
	_check(flank_a and flank_b, prefix+" both door flanks physically block passage")

func _check_furniture(room: Dictionary, y: float, prefix: String) -> void:
	if room.title == "PHÒNG THỰC HÀNH" or room.title == "PHÒNG TIN HỌC":
		_check_named_worktop_rays(room, prefix)
		return
	var cx: float = room.cx
	var cz: float = room.cz
	var width: float = room.width
	var depth: float = room.depth
	var side: String = room.side
	var kind: String = room.kind
	var fx := cx
	var fz := cz
	if side == "north":
		match kind:
			"class": fz = cz-depth*.5+1.25
			"library": fx = cx-1.4
			"chess": fx = cx-1.35
			"lab": fz = cz+1.0
			"restroom":
				fx = cx-width*.28
				fz = cz+depth*.32
	else:
		var outer_sign := 1.0 if side == "east" else -1.0
		var inner_sign := -outer_sign
		match kind:
			"class":
				fx = cx+outer_sign*(width*.5-1.0)
				if room.title == "LỚP HỌC 1" and room.level == 0:
					fx = cx+1.08
			"vocational": fx = cx+inner_sign*.65
			"computer": fx = cx+inner_sign
			"restroom": fx = cx+outer_sign*width*.28
	var hit := _ray(Vector3(fx,y+2.6,fz),Vector3(fx,y+.2,fz))
	if hit.is_empty():
		var floor_name: String = ["Ground","Level2","Level3"][int(room.level)]
		var near_bodies: Array[String] = []
		for child in school.get_node(floor_name).get_children():
			if child is StaticBody3D and String(child.name).begins_with(room.title) and Vector2(child.position.x,child.position.z).distance_to(Vector2(fx,fz)) < .8:
				near_bodies.append("%s@%s" % [child.name,child.position])
		print("SCHOOL_FURNITURE_DIAGNOSTIC %s target=%s nearby=%s" % [prefix,Vector3(fx,y,fz),near_bodies])
	_check(not hit.is_empty() and float(hit.position.y) > y+.36,
		prefix+" substantial %s furniture has collision at (%.2f, %.2f, %.2f); hit=%s" % [kind,fx,y,fz,hit.position if not hit.is_empty() else "none"])

func _check_named_worktop_rays(room: Dictionary, prefix: String) -> void:
	var floor_name: String = ["Ground","Level2","Level3"][int(room.level)]
	var floor := school.get_node(floor_name) as Node3D
	var fragment := "practice workstation top" if room.title == "PHÒNG THỰC HÀNH" else "computer desk top"
	var worktop_prefix: String = room.title + " " + fragment
	var worktops: Array[MeshInstance3D] = []
	for child in floor.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(worktop_prefix):
			worktops.append(child as MeshInstance3D)
	_check(not worktops.is_empty(), prefix+" has semantic worktop meshes matching '"+worktop_prefix+"'")
	for worktop in worktops:
		var box := worktop.mesh as BoxMesh
		if box == null:
			_check(false, prefix+" "+String(worktop.name)+" has box-shaped worktop geometry")
			continue
		# The CRT occupies the computer desk center, so sample a clear strip of
		# that worktop. The location comes from the mesh transform and dimensions.
		var sample_offset := Vector3(box.size.x*.36,0,0) if room.title == "PHÒNG TIN HỌC" else Vector3.ZERO
		var sample := worktop.global_position + sample_offset
		var top_y := worktop.global_position.y + box.size.y*.5
		var hit := _ray(Vector3(sample.x,top_y+.35,sample.z),Vector3(sample.x,top_y-.18,sample.z))
		_check(not hit.is_empty() and hit.collider is StaticBody3D and absf(float(hit.position.y)-top_y) < .08,
			prefix+" semantic worktop "+String(worktop.name)+" has a tabletop collider at "+str(sample)+"; hit="+str(hit.collider.get_path() if not hit.is_empty() else "none"))

func _check_local_capsule_entry(room: Dictionary, y: float, prefix: String) -> void:
	var cx: float = room.cx
	var cz: float = room.cz
	var side: String = room.side
	var action: StringName
	var threshold: float
	if side == "north":
		threshold = cz+float(room.depth)*.5
		actor.teleport_to(Vector3(cx,y+.12,threshold+.9))
		action = "move_up"
	else:
		var inner_sign := -1.0 if side == "east" else 1.0
		threshold = cx+inner_sign*float(room.width)*.5
		var door_z: float = cz+.85 if room.title == "LỚP HỌC 1" and room.level == 0 else cz
		actor.teleport_to(Vector3(threshold+inner_sign*.9,y+.12,door_z))
		action = "move_right" if side == "east" else "move_left"
	for _frame in 4:
		await physics_frame
	Input.action_press(action)
	for _frame in 33:
		await physics_frame
	Input.action_release(action)
	await physics_frame
	var entered := actor.global_position.z < threshold-.32 if side == "north" else (actor.global_position.x > threshold+.32 if side == "east" else actor.global_position.x < threshold-.32)
	_check(entered and absf(actor.global_position.y-(y+.12)) < .35,
		prefix+" local corridor-to-room capsule crossing; stopped at "+str(actor.global_position))

func _check_fence() -> void:
	var missed: Array[int] = []
	var sampled := 0
	for x in range(-26,-3):
		sampled += 1
		if _ray(Vector3(x,1.1,35),Vector3(x,1.1,33)).is_empty():
			missed.append(x)
	for x in range(4,27):
		sampled += 1
		if _ray(Vector3(x,1.1,35),Vector3(x,1.1,33)).is_empty():
			missed.append(x)
	_check(missed.is_empty(), "south perimeter fence physically continuous outside gate: %d samples, missing X=%s at Y=1.1 Z=34" % [sampled,missed])

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query)

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _finish(room_count: int) -> void:
	for failure in failures:
		print("SCHOOL_FULL_SHELL_FAIL: "+failure)
	print("SCHOOL_FULL_SHELL_SUMMARY rooms=%d checks=%d failures=%d" % [room_count,checks,failures.size()])
	quit(1 if not failures.is_empty() else 0)
