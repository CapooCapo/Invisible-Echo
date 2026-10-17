extends SceneTree

## GUI renderer evidence from the real main scene. Do not run with --headless.
## DISPLAY=:0 godot --path . --script res://tests/visual_school_runtime_capture.gd
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var state := root.get_node("GameState")
	state.persistence_enabled = false
	state.save_writes_suppressed = true
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	var game: Node = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	var school: Node = game.get("night_school_visual")
	if school == null or school.get_node_or_null("NightSchoolViewport/NightSchool/MappedSchoolEnvironment") == null:
		push_error("SCHOOL_RUNTIME_CAPTURE_FAILED: mapped school missing from main-game viewport")
		quit(1)
		return
	var actor: Node3D = school.get("actor")
	var view: SubViewport = school.get("viewport")
	var output_dir := ProjectSettings.globalize_path("res://builds/visual-qa")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var shots := [
		["school_yard", Vector3(0,0,29), 0.0],
		["school_gate", Vector3(0,0,40), 0.0],
		["school_stage", Vector3(0,0,-2), 0.0],
		["courtyard_tree", Vector3(17,0,18), 0.0],
		["classroom_1", Vector3(14.7,0,-14.8), -1.1],
		["classroom_3", Vector3(-11,0,-24.3), 0.0],
		["north_gallery", Vector3(0,0,-21.5), -PI*.5],
	]
	for shot in shots:
		actor.call("teleport_to",shot[1])
		actor.set("camera_yaw",shot[2])
		actor.call("_apply_camera_rotation")
		await create_timer(.45).timeout
		var image := view.get_texture().get_image()
		var output := output_dir.path_join(shot[0] + "_main_runtime.png")
		if image.is_empty() or image.save_png(output) != OK:
			push_error("SCHOOL_RUNTIME_CAPTURE_FAILED " + shot[0])
			quit(1)
			return
		print("SCHOOL_RUNTIME_CAPTURE_OK ",shot[0]," ",image.get_width(),"x",image.get_height()," ",output)
	quit()
