"""Create authored Vietnamese classroom furniture and export one reusable GLB."""

import os
import sys
import math

import bpy


def output_directory() -> str:
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	return os.path.abspath(args[0] if args else "assets/props/school")


def material(name: str, color: tuple[float, float, float], roughness: float = 0.86):
	mat = bpy.data.materials.new(name)
	mat.diffuse_color = (*color, 1.0)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	return mat


def rounded_box(name: str, dimensions, location, mat, bevel: float = 0.018):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
	obj = bpy.context.object
	obj.name = name
	obj.dimensions = dimensions
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	obj.data.materials.append(mat)
	if bevel > 0:
		modifier = obj.modifiers.new("Soft worn edges", "BEVEL")
		modifier.width = bevel
		modifier.segments = 2
		modifier.profile = 0.5
		normals = obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
		normals.keep_sharp = True
	return obj


def move_to_parent(obj, parent):
	obj.parent = parent
	return obj


def build_furniture():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	wood = material("Worn lacquered school wood", (0.20, 0.12, 0.075), 0.88)
	wood_edge = material("Dark stained desk edges", (0.105, 0.067, 0.044), 0.9)
	steel = material("Desaturated painted steel", (0.12, 0.16, 0.17), 0.72)
	steel_highlight = material("Worn metal highlights", (0.24, 0.28, 0.28), 0.68)
	enamel = material("Old grey-green enamel", (0.22, 0.28, 0.27), 0.82)
	root = bpy.data.objects.new("Classroom1Furnishings", None)
	bpy.context.collection.objects.link(root)
	root.empty_display_type = "PLAIN_AXES"
	root.empty_display_size = 0.25

	# Three Vietnamese two-seat desk/bench rows facing the east-wall board.
	row_z = [-1.75, -0.03, 1.69]
	for row, z in enumerate(row_z, start=1):
		desk_x = -0.36
		move_to_parent(rounded_box(f"Student Desk {row} tabletop", (.78, .11, 1.0),
			(desk_x, .78, z), wood, .025), root)
		move_to_parent(rounded_box(f"Student Desk {row} dark edge band", (.80, .035, 1.02),
			(desk_x, .835, z), wood_edge, .012), root)
		move_to_parent(rounded_box(f"Student Desk {row} front retaining rail", (.73, .045, .055),
			(desk_x, .69, z + .45), steel_highlight, .018), root)
		for leg_x in [-.68, -.04]:
			for leg_z in [z - .42, z + .42]:
				move_to_parent(rounded_box(f"Student Desk {row} tubular leg", (.045, .72, .045),
					(leg_x, .38, leg_z), steel, .012), root)
		for leg_z in [z - .38, z + .38]:
			move_to_parent(rounded_box(f"Student Desk {row} lower stretcher", (.66, .04, .04),
				(desk_x, .18, leg_z), steel_highlight, .012), root)
		bench_x = -1.12
		move_to_parent(rounded_box(f"Shared Bench {row} seat", (.46, .09, .88),
			(bench_x, .48, z), wood, .025), root)
		move_to_parent(rounded_box(f"Shared Bench {row} seat rim", (.48, .035, .90),
			(bench_x, .525, z), wood_edge, .012), root)
		move_to_parent(rounded_box(f"Shared Bench {row} backrest", (.075, .58, .88),
			(bench_x - .19, .83, z), wood, .025), root)
		for leg_z in [z - .34, z + .34]:
			move_to_parent(rounded_box(f"Shared Bench {row} metal leg", (.045, .48, .045),
				(bench_x, .24, leg_z), steel, .012), root)
		move_to_parent(rounded_box(f"Shared Bench {row} crossbar", (.045, .04, .68),
			(bench_x, .20, z), steel_highlight, .012), root)

	# Teacher's station: drawers, apron, feet, and a matching straight-backed chair.
	tx = 1.08
	move_to_parent(rounded_box("Teacher Desk tabletop", (.85, .12, 1.05),
		(tx, .82, 0.0), wood, .03), root)
	move_to_parent(rounded_box("Teacher Desk dark perimeter", (.88, .035, 1.08),
		(tx, .88, 0.0), wood_edge, .014), root)
	move_to_parent(rounded_box("Teacher Desk modesty apron", (.72, .54, .075),
		(tx, .47, .39), wood, .022), root)
	move_to_parent(rounded_box("Teacher Desk drawer bank", (.54, .20, .39),
		(tx, .65, -.30), wood, .022), root)
	for leg_x in [tx - .34, tx + .34]:
		for leg_z in [-.43, .43]:
			move_to_parent(rounded_box("Teacher Desk metal leg", (.055, .76, .055),
				(leg_x, .40, leg_z), steel, .015), root)
	move_to_parent(rounded_box("Teacher Desk drawer pull", (.16, .025, .025),
		(tx, .66, -.095), steel_highlight, .01), root)
	chair_x = .28
	chair_z = .02
	move_to_parent(rounded_box("Teacher Chair padded seat", (.52, .09, .54),
		(chair_x, .49, chair_z), enamel, .035), root)
	move_to_parent(rounded_box("Teacher Chair back", (.075, .62, .54),
		(chair_x - .22, .84, chair_z), enamel, .035), root)
	for leg_x in [chair_x - .20, chair_x + .20]:
		for leg_z in [chair_z - .20, chair_z + .20]:
			move_to_parent(rounded_box("Teacher Chair steel leg", (.04, .48, .04),
				(leg_x, .24, leg_z), steel, .012), root)

	# A practical two-door class cupboard with trim, shelves, and metal pulls.
	cx, cz = 1.35, -2.48
	move_to_parent(rounded_box("Class Cabinet carcass", (.76, 1.76, .52),
		(cx, .88, cz), wood, .028), root)
	move_to_parent(rounded_box("Class Cabinet left door", (.34, 1.62, .035),
		(cx - .18, .90, cz + .282), enamel, .018), root)
	move_to_parent(rounded_box("Class Cabinet right door", (.34, 1.62, .035),
		(cx + .18, .90, cz + .282), enamel, .018), root)
	move_to_parent(rounded_box("Class Cabinet center stile", (.035, 1.65, .045),
		(cx, .90, cz + .30), steel, .01), root)
	for shelf_y in [.48, 1.03, 1.57]:
		move_to_parent(rounded_box("Class Cabinet shelf", (.68, .035, .44),
			(cx, shelf_y, cz), wood_edge, .01), root)
	for handle_x in [cx - .08, cx + .08]:
		move_to_parent(rounded_box("Class Cabinet metal pull", (.035, .19, .035),
			(handle_x, .91, cz + .33), steel_highlight, .012), root)

	# Three-blade ceiling fan; its rotor node is animated by the Godot room script.
	fan = bpy.data.objects.new("Classroom1CeilingFanRotor", None)
	bpy.context.collection.objects.link(fan)
	fan.location = (-.75, 2.73, -.4)
	fan.parent = root
	fan.empty_display_type = "CIRCLE"
	fan.empty_display_size = .16
	move_to_parent(rounded_box("Ceiling Fan motor", (.23, .18, .23), (0.0, 0.0, 0.0), enamel, .055), fan)
	move_to_parent(rounded_box("Ceiling Fan downrod", (.035, .24, .035), (0.0, .17, 0.0), steel, .012), fan)
	for blade in range(3):
		angle = 2.0 * math.pi * blade / 3.0
		obj = rounded_box("Ceiling Fan blade %d" % (blade + 1), (.15, .035, .90),
			(0.0, 0.0, -.48), wood, .025)
		obj.rotation_euler[1] = angle
		move_to_parent(obj, fan)
		trim = rounded_box("Ceiling Fan blade trim %d" % (blade + 1), (.045, .012, .74),
			(0.0, .025, -.48), steel_highlight, .006)
		trim.rotation_euler[1] = angle
		move_to_parent(trim, fan)

	return root


def export_asset(root, directory: str):
	os.makedirs(directory, exist_ok=True)
	blend_path = os.path.join(directory, "classroom1_furniture_source.blend")
	glb_path = os.path.join(directory, "classroom1_furniture.glb")
	bpy.ops.wm.save_as_mainfile(filepath=blend_path)
	bpy.ops.object.select_all(action="DESELECT")
	for obj in bpy.context.scene.objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = root
	bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True,
		export_apply=True, export_yup=True, export_materials="EXPORT", export_animations=False)
	print("Wrote", blend_path)
	print("Wrote", glb_path)


if __name__ == "__main__":
	root_dir = output_directory()
	root = build_furniture()
	export_asset(root, root_dir)
