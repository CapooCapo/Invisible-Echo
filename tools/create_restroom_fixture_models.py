"""Create self-authored low-poly restroom fixtures and export reusable GLBs."""

import math
import os
import sys

import bpy


def output_directory() -> str:
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	return os.path.abspath(args[0] if args else "assets/props/school")


def material(name: str, color: tuple[float, float, float], roughness: float = 0.82):
	mat = bpy.data.materials.new(name)
	mat.diffuse_color = (*color, 1.0)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	return mat


def rounded_box(name, dimensions, location, mat, bevel=0.025):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
	obj = bpy.context.object
	obj.name = name
	obj.dimensions = dimensions
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	obj.data.materials.append(mat)
	if bevel:
		modifier = obj.modifiers.new("Soft ceramic corners", "BEVEL")
		modifier.width = bevel
		modifier.segments = 2
		obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
	return obj


def cylinder_between(name, start, end, radius, mat, vertices=8):
	direction = (end[0] - start[0], end[1] - start[1], end[2] - start[2])
	length = math.sqrt(sum(value * value for value in direction))
	middle = tuple((start[i] + end[i]) * 0.5 for i in range(3))
	bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=middle)
	obj = bpy.context.object
	obj.name = name
	obj.data.materials.append(mat)
	obj.rotation_euler = (0.0, 0.0, 0.0)
	obj.rotation_mode = "QUATERNION"
	obj.rotation_quaternion = (0.0, 0.0, 1.0).to_track_quat("Z", "Y") if length == 0 else __import__("mathutils").Vector(direction).to_track_quat("Z", "Y")
	return obj


def ring_bowl(name, center, rings, mat, segments=16):
	"""Make a tapered hollow vessel with elliptical X/Z cross sections."""
	verts = []
	for y, radius_x, radius_z in rings:
		for index in range(segments):
			angle = (2.0 * math.pi * index) / segments
			verts.append((center[0] + math.cos(angle) * radius_x, center[1] + y, center[2] + math.sin(angle) * radius_z))

	faces = []
	for ring in range(len(rings) - 1):
		for index in range(segments):
			a = ring * segments + index
			b = ring * segments + (index + 1) % segments
			c = (ring + 1) * segments + (index + 1) % segments
			d = (ring + 1) * segments + index
			faces.append((a, b, c, d))
	mesh = bpy.data.meshes.new(name + "Mesh")
	mesh.from_pydata(verts, [], faces)
	mesh.materials.append(mat)
	mesh.update()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.collection.objects.link(obj)
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	return obj


def parent_to_root(obj, root):
	obj.parent = root
	return obj


def make_root(name):
	root = bpy.data.objects.new(name, None)
	bpy.context.collection.objects.link(root)
	# The geometry helpers intentionally author in the game's Y-up coordinates
	# (height on Y, room depth on Z). Blender is Z-up; this parent rotation turns
	# those local axes into Blender-native orientation before the glTF Y-up export
	# conversion, so the imported Godot meshes remain upright instead of lying on
	# their side along the wall.
	root.rotation_euler.x = math.pi / 2.0
	root.empty_display_type = "PLAIN_AXES"
	root.empty_display_size = 0.12
	return root


def build_toilet(porcelain, seat_mat, metal):
	root = make_root("RestroomToiletCistern")
	# Compact floor-mounted cistern with a rounded porcelain tank and visible lid.
	parent_to_root(rounded_box("Cistern body", (.39, .62, .23), (0, .67, -.265), porcelain, .055), root)
	parent_to_root(rounded_box("Cistern lid", (.43, .07, .27), (0, 1.015, -.265), porcelain, .035), root)
	parent_to_root(rounded_box("Flush button", (.105, .018, .07), (0, 1.055, -.24), metal, .009), root)
	# The bowl is a continuous low-poly oval shell, wider and taller at its rim.
	ring_bowl("Porcelain bowl shell", (0, 0, .105), [
		(.065, .155, .17),
		(.12, .205, .255),
		(.26, .235, .305),
		(.40, .245, .315),
		(.47, .245, .315),
	], porcelain, 18)
	parent_to_root(bpy.data.objects["Porcelain bowl shell"], root)
	parent_to_root(rounded_box("Bowl foot pedestal", (.31, .43, .36), (0, .255, .13), porcelain, .075), root)
	# A dark inset and raised enamel seat make the open top readable at game scale.
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(0, .435, .115))
	water = bpy.context.object
	water.name = "Bowl dark interior"
	water.scale = (.177, .018, .235)
	water.data.materials.append(seat_mat)
	parent_to_root(water, root)
	bpy.ops.mesh.primitive_torus_add(major_radius=.238, minor_radius=.026, major_segments=18, minor_segments=6,
		location=(0, .48, .115), rotation=(math.pi / 2.0, 0.0, 0.0))
	seat = bpy.context.object
	seat.name = "Enamel toilet seat"
	seat.scale.z = 1.24
	seat.data.materials.append(seat_mat)
	parent_to_root(seat, root)
	return root


def build_basin(porcelain, inset, metal):
	root = make_root("RestroomWallBasinFaucet")
	# Wall fixing plate, ceramic pedestal, and an open oval bowl with sloped walls.
	parent_to_root(rounded_box("Wall mounting plate", (.58, .42, .07), (0, .82, -.25), metal, .035), root)
	ring_bowl("Oval basin shell", (0, 0, 0), [
		(.67, .265, .17),
		(.73, .345, .225),
		(.82, .395, .265),
		(.87, .395, .265),
	], porcelain, 20)
	parent_to_root(bpy.data.objects["Oval basin shell"], root)
	# Inset dark bowl floor remains visible over the rim from the doorway.
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(0, .735, .015))
	basin = bpy.context.object
	basin.name = "Basin shadow interior"
	basin.scale = (.27, .025, .16)
	basin.data.materials.append(inset)
	parent_to_root(basin, root)
	# Low-poly gooseneck faucet: vertical riser, arch, outlet and two handles.
	parent_to_root(rounded_box("Faucet escutcheon", (.20, .025, .14), (0, .889, -.195), metal, .012), root)
	parent_to_root(cylinder_between("Faucet riser", (0, .895, -.205), (0, 1.075, -.205), .027, metal, 8), root)
	parent_to_root(cylinder_between("Faucet arch", (0, 1.065, -.205), (0, 1.11, -.10), .027, metal, 8), root)
	parent_to_root(cylinder_between("Faucet spout", (0, 1.11, -.10), (0, 1.025, .005), .027, metal, 8), root)
	for side in [-1.0, 1.0]:
		parent_to_root(cylinder_between("Faucet handle stem", (side * .14, .88, -.20), (side * .14, .96, -.20), .018, metal, 8), root)
		parent_to_root(rounded_box("Faucet cross handle", (.11, .025, .035), (side * .14, .97, -.20), metal, .01), root)
	return root


def build_urinal(porcelain, inset, metal):
	root = make_root("RestroomWallUrinal")
	parent_to_root(rounded_box("Urinal backplate", (.42, .64, .08), (0, 1.03, -.21), porcelain, .075), root)
	ring_bowl("Urinal basin shell", (0, 0, -.015), [
		(.47, .13, .10),
		(.55, .19, .15),
		(.73, .225, .19),
		(.82, .225, .19),
	], porcelain, 16)
	parent_to_root(bpy.data.objects["Urinal basin shell"], root)
	bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=(0, .70, .01))
	interior = bpy.context.object
	interior.name = "Urinal dark bowl interior"
	interior.scale = (.105, .016, .085)
	interior.data.materials.append(inset)
	parent_to_root(interior, root)
	parent_to_root(cylinder_between("Urinal flush pipe", (0, 1.31, -.25), (0, 1.53, -.25), .024, metal, 8), root)
	parent_to_root(rounded_box("Urinal flush valve", (.13, .08, .10), (0, 1.48, -.19), metal, .02), root)
	return root


def export_asset(root, directory, filename):
	path = os.path.join(directory, filename)
	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	for obj in root.children_recursive:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = root
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
		export_apply=True, export_yup=True, export_materials="EXPORT", export_animations=False)
	print("Wrote", path)


def save_source(root, directory, filename):
	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	for obj in root.children_recursive:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = root
	path = os.path.join(directory, filename)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("Saved source", path)


def main():
	directory = output_directory()
	os.makedirs(directory, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	porcelain = material("Aged sanitary porcelain", (.69, .73, .68), .32)
	seat = material("Dark enamel seat", (.17, .21, .20), .44)
	inset = material("Basin shadow and dark water", (.095, .13, .13), .27)
	metal = material("Worn chrome and enamel metal", (.29, .34, .34), .38)

	toilet = build_toilet(porcelain, seat, metal)
	save_source(toilet, directory, "restroom_toilet_cistern_source.blend")
	export_asset(toilet, directory, "restroom_toilet_cistern.glb")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	porcelain = material("Aged sanitary porcelain", (.69, .73, .68), .32)
	inset = material("Basin shadow and dark water", (.095, .13, .13), .27)
	metal = material("Worn chrome and enamel metal", (.29, .34, .34), .38)
	basin = build_basin(porcelain, inset, metal)
	save_source(basin, directory, "restroom_wall_basin_faucet_source.blend")
	export_asset(basin, directory, "restroom_wall_basin_faucet.glb")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	porcelain = material("Aged sanitary porcelain", (.69, .73, .68), .32)
	inset = material("Basin shadow and dark water", (.095, .13, .13), .27)
	metal = material("Worn chrome and enamel metal", (.29, .34, .34), .38)
	urinal = build_urinal(porcelain, inset, metal)
	save_source(urinal, directory, "restroom_wall_urinal_source.blend")
	export_asset(urinal, directory, "restroom_wall_urinal.glb")


if __name__ == "__main__":
	main()
