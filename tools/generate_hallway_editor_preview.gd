extends SceneTree

## Rebuild the serialized editor preview from the hallway's runtime geometry.
## Run: godot --headless --path . --script res://tools/generate_hallway_editor_preview.gd
const HALLWAY_SCENE := preload("res://scenes/visual/hallway_3d.tscn")
const OUTPUT_PATH := "res://scenes/visual/hallway_editor_preview.tscn"


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var hallway := HALLWAY_SCENE.instantiate() as SubViewportContainer
	root.add_child(hallway)
	var world := hallway.get("world") as Node3D
	if world == null:
		push_error("Hallway runtime did not build SchoolHallway")
		quit(1)
		return
	var actor := hallway.get("actor") as Node3D
	if actor != null:
		world.remove_child(actor)
		actor.free()
	# Collision bodies and shapes are runtime-only; preview stores only visible
	# geometry, lighting, labels, and environment.
	for child in world.get_children():
		if child is CollisionObject3D:
			world.remove_child(child)
			child.free()
	hallway.viewport.remove_child(world)
	var preview := Node3D.new()
	preview.name = "EditorPreview3D"
	preview.add_child(world)
	_set_owner_recursive(world, preview)
	var scene := PackedScene.new()
	var packed := scene.pack(preview)
	if packed != OK:
		push_error("Failed to pack hallway editor preview: %d" % packed)
		quit(1)
		return
	var saved := ResourceSaver.save(scene, OUTPUT_PATH)
	if saved != OK:
		push_error("Failed to save hallway editor preview: %d" % saved)
		quit(1)
		return
	print("Saved hallway editor preview: ", OUTPUT_PATH)
	quit()


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
