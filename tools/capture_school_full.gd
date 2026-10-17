extends SceneTree

## GUI-only visual inventory of every mapped room and the main exterior views.
## DISPLAY=:0 godot --path . --script res://tools/capture_school_full.gd
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
const ROOM_COUNT := 28

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.save_writes_suppressed = true
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	var game: Node = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	var school: Node = game.get("night_school_visual")
	var campus := school.get_node_or_null("NightSchoolViewport/NightSchool/MappedSchoolEnvironment") as Node3D if school != null else null
	if campus == null or campus.get_node_or_null("Ground") == null:
		push_error("FULL_SCHOOL_CAPTURE_FAILED: F5 mapped school missing or not built")
		quit(1)
		return
	var actor: Node3D = school.get("actor")
	var view: SubViewport = school.get("viewport")
	var output_dir := ProjectSettings.globalize_path("res://builds/visual-qa/full-school")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var manifest: Array[Dictionary] = []
	var room_index := 0
	for floor_name in ["Ground", "Level2", "Level3"]:
		var floor_root := campus.get_node(floor_name)
		for child in floor_root.get_children():
			if not child is MeshInstance3D or not String(child.name).ends_with(" floor"):
				continue
			var box := (child as MeshInstance3D).mesh as BoxMesh
			if box == null:
				continue
			room_index += 1
			var center: Vector3 = (child as Node3D).global_position
			var camera_at := Vector3(center.x,center.y-.06,center.z)
			var yaw := 0.0
			if center.z > -23.0:
				if center.x < 0.0:
					camera_at.x += box.size.x*.5-1.1
					yaw = PI*.5
				else:
					camera_at.x -= box.size.x*.5-1.1
					yaw = -PI*.5
			else:
				camera_at.z += box.size.z*.5-1.1
			var image_name := "%02d_%s.png" % [room_index,floor_name.to_lower()]
			if not await _shot(actor,view,camera_at,yaw,output_dir.path_join(image_name)):
				quit(1)
				return
			manifest.append({"file": image_name, "room": String(child.name).trim_suffix(" floor"), "level": floor_name, "center": str(center), "dimensions": str(box.size)})
	if room_index != ROOM_COUNT:
		push_error("FULL_SCHOOL_CAPTURE_FAILED: expected %d room interiors, found %d" % [ROOM_COUNT,room_index])
		quit(1)
		return
	var outside := [
		["south_gate",Vector3(0,0,42),0.0],
		["courtyard",Vector3(0,0,29),0.0],
		["stage",Vector3(0,0,-2),0.0],
		["west_facade",Vector3(-31,0,-8),-PI*.5],
		["east_facade",Vector3(31,0,-8),PI*.5],
		["north_facade",Vector3(0,0,-38),PI],
		["west_gallery",Vector3(-11.4,0,-8),PI*.5],
		["east_gallery",Vector3(11.4,0,-8),-PI*.5],
		["stair_A_ground",Vector3(-21,0,-18.5),0.0],
		["stair_B_ground",Vector3(0,0,-18.5),0.0],
		["stair_C_ground",Vector3(21,0,-18.5),0.0],
		["stair_A_level2",Vector3(-21,3.2,-26),PI],
		["stair_B_level2",Vector3(0,3.2,-26),PI],
		["stair_C_level2",Vector3(21,3.2,-26),PI],
		["stair_A_level3",Vector3(-21,6.4,-18.5),0.0],
		["stair_B_level3",Vector3(0,6.4,-18.5),0.0],
		["stair_C_level3",Vector3(21,6.4,-18.5),0.0],
		["stair_A_side",Vector3(-16.5,0,-22.5),PI*.5],
		["stair_B_side",Vector3(4.5,0,-22.5),PI*.5],
		["stair_C_side",Vector3(16.5,0,-22.5),-PI*.5],
		["roof",Vector3(0,9.72,-22),0.0],
	]
	for view_data in outside:
		var file_name: String = "outside_%s.png" % view_data[0]
		if not await _shot(actor,view,view_data[1],view_data[2],output_dir.path_join(file_name)):
			quit(1)
			return
		manifest.append({"file": file_name, "view": view_data[0], "camera_at": str(view_data[1])})
	var manifest_file := FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE)
	if manifest_file == null:
		push_error("FULL_SCHOOL_CAPTURE_FAILED: manifest write")
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(manifest,"  "))
	manifest_file.close()
	print("FULL_SCHOOL_CAPTURE_OK rooms=%d outside=%d dir=%s" % [room_index,outside.size(),output_dir])
	quit()

func _shot(actor: Node3D, view: SubViewport, where: Vector3, yaw: float, path: String) -> bool:
	actor.call("teleport_to",where)
	actor.set("camera_yaw",yaw)
	actor.call("_apply_camera_rotation")
	await create_timer(.3).timeout
	var pixels := view.get_texture().get_image()
	if pixels.is_empty() or pixels.save_png(path) != OK:
		push_error("FULL_SCHOOL_CAPTURE_FAILED: " + path)
		return false
	return true
