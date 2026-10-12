extends SceneTree

## GUI-only evidence capture: never use --headless. Uses isolated XDG paths.
## godot --path . --script res://tests/visual_spatial_capture.gd -- --beat=hallway
const MAIN_PATH := "res://scenes/01_hanh_lang.tscn"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var beat_name := "hallway"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--beat="):
			beat_name = arg.trim_prefix("--beat=")
	var state := root.get_node("GameState")
	state.persistence_enabled = false
	state.scene_id = "scene_01" if beat_name == "hallway" else ("scene_03" if beat_name == "toilet" else "scene_04")
	state.checkpoint_id = "hallway_letter" if beat_name == "hallway" else ("toilet_hide" if beat_name == "toilet" else "mirror")
	var game = load(MAIN_PATH).instantiate()
	root.add_child(game)
	current_scene = game
	if beat_name in ["mirror", "reflection"]:
		game.player = Vector2(810,262)
	if beat_name == "reflection":
		game.beat = game.Beat.REFLECTION
		game._show_beat()
	elif beat_name == "mirror":
		game._sync_restroom_visual()
	await create_timer(.85).timeout
	var container: SubViewportContainer = game.hallway_visual if beat_name == "hallway" else game.restroom_visual
	var view: SubViewport = container.get_node("SpatialViewport" if beat_name == "hallway" else "RestroomViewport")
	var image := view.get_texture().get_image()
	var directory := "res://builds/visual-qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := ProjectSettings.globalize_path(directory + "/" + beat_name + "_3d_runtime.png")
	if image.is_empty() or image.save_png(path) != OK:
		push_error("VISUAL_CAPTURE_FAILED " + beat_name)
		quit(1)
		return
	print("VISUAL_CAPTURE_OK ", beat_name, " ", image.get_width(), "x", image.get_height(), " ", path)
	quit()
