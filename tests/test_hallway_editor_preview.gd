extends SceneTree

## The playable hallway lives inside a SubViewportContainer. Godot's 3D scene
## editor cannot preview geometry created by its runtime-only _ready() method,
## so this separate scene must contain serialized, editable 3D geometry.
const PREVIEW_SCENE := "res://scenes/visual/hallway_editor_preview.tscn"


func _initialize() -> void:
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
			if scene_state.get_node_property_name(node_index, property_index) == &"mesh" \
					and scene_state.get_node_property_value(node_index, property_index) is Mesh:
				meshes += 1
				break
	if meshes < 3:
		push_error("Hallway editor preview needs serialized floor/wall meshes; found %d" % meshes)
		failures += 1

	if failures == 0:
		print("HALLWAY_EDITOR_PREVIEW_PASS meshes=%d" % meshes)
	quit(1 if failures else 0)
