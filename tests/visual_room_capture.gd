extends SceneTree

## GUI renderer capture for standalone spatial rooms; use isolated XDG paths.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var room := "lab"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room = arg.trim_prefix("--room=")
	var path := "res://scenes/visual/computer_lab_3d.tscn" if room == "lab" else "res://scenes/visual/chess_club_3d.tscn"
	var scene = load(path)
	if scene == null:
		push_error("VISUAL_ROOM_LOAD_FAILED " + path)
		quit(1)
		return
	var instance = scene.instantiate()
	root.add_child(instance)
	current_scene = instance
	if room == "lab":
		instance.call("set_beat", 0)
	else:
		instance.call("set_returned_count", 6)
	await create_timer(.85).timeout
	var view: SubViewport = null
	for child in instance.get_children():
		if child is SubViewport:
			view = child
			break
	if view == null:
		push_error("VISUAL_ROOM_VIEWPORT_MISSING " + room)
		quit(1)
		return
	var image := view.get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://builds/visual-qa/" + room + "_3d_runtime.png")
	if image.is_empty() or image.save_png(out) != OK:
		push_error("VISUAL_ROOM_CAPTURE_FAILED " + room)
		quit(1)
		return
	print("VISUAL_ROOM_CAPTURE_OK ", room, " ", image.get_width(), "x", image.get_height(), " ", out)
	quit()
