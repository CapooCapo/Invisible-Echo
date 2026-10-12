extends SceneTree

## GUI-only visual evidence for actual controller scenes, with isolated XDG.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var room := "lab"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room = arg.trim_prefix("--room=")
	if not room in ["lab", "chess"]:
		push_error("Unknown room: " + room)
		quit(1)
		return
	var state := root.get_node("GameState")
	state.persistence_enabled = false
	state.scene_id = "scene_09" if room == "lab" else "scene_12"
	state.checkpoint_id = "computer_access" if room == "lab" else "return_memories"
	var path := "res://scenes/09_phong_tin_hoc.tscn" if room == "lab" else "res://scenes/12_phong_cau_vua.tscn"
	var scene = load(path)
	if scene == null:
		push_error("Could not load " + path)
		quit(1)
		return
	var instance = scene.instantiate()
	root.add_child(instance)
	current_scene = instance
	await create_timer(.9).timeout
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://builds/visual-qa/" + room + "_integrated_runtime.png")
	if image.is_empty() or image.save_png(output) != OK:
		push_error("Could not capture " + room)
		quit(1)
		return
	print("VISUAL_INTEGRATED_CAPTURE_OK ", room, " ", image.get_width(), "x", image.get_height())
	quit()
