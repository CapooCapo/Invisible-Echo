extends SceneTree

## The playable hallway lives inside a SubViewportContainer. Godot's 3D scene
## editor cannot preview geometry created by its runtime-only _ready() method,
## so this view-only scene must contain serialized, inspectable 3D geometry.
const PREVIEW_SCENE := "res://scenes/visual/hallway_editor_preview.tscn"
const PLAY_SCENE := "res://scenes/visual/hallway_3d.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	if not ResourceLoader.exists(PREVIEW_SCENE):
		push_error("Hallway editor preview scene is missing: " + PREVIEW_SCENE)
		quit(1)
		return

	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		push_error("Hallway editor preview is not a PackedScene")
		quit(1)
		return

	var scene_state := packed.get_state()
	if scene_state.get_node_count() == 0 or scene_state.get_node_type(0) != &"Node3D":
		push_error("Hallway editor preview must have a Node3D root")
		failures += 1

	var meshes := 0
	for node_index in scene_state.get_node_count():
		if scene_state.get_node_type(node_index) != &"MeshInstance3D":
			continue
		for property_index in scene_state.get_node_property_count(node_index):
			var property_name := scene_state.get_node_property_name(node_index, property_index)
			var property_value: Variant = scene_state.get_node_property_value(node_index, property_index)
			if property_name == &"mesh" and property_value is Mesh:
				meshes += 1
				break
	if meshes < 3:
		push_error("Hallway editor preview needs serialized floor/wall meshes; found %d" % meshes)
		failures += 1

	var hallway_scene := load(PLAY_SCENE) as PackedScene
	var hallway := hallway_scene.instantiate()
	var preview := hallway.get_node_or_null("EditorPreview3D") as Node3D
	if preview == null or preview.get_parent() != hallway or not preview.visible:
		push_error("Playable hallway must expose a visible 3D preview directly under its root")
		failures += 1
	elif preview.find_children("*", "MeshInstance3D", true, false).size() < 3:
		push_error("Playable hallway preview contains no inspectable corridor geometry")
		failures += 1

	root.add_child(hallway)
	if hallway.get_node_or_null("EditorPreview3D") != null:
		push_error("Playable hallway must remove editor preview before runtime rendering")
		failures += 1
	var runtime_viewport := hallway.get_node_or_null("SpatialViewport") as SubViewport
	if runtime_viewport == null:
		push_error("Playable hallway did not create its runtime SubViewport")
		failures += 1
	hallway.free()

	if failures == 0:
		print("HALLWAY_EDITOR_PREVIEW_PASS serialized_meshes=%d editor_and_runtime_layout=ok" % meshes)
	quit(1 if failures else 0)
