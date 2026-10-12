"""Generate seven original school NPC variants from the project's Hoang rig.

Run: blender -b --factory-startup --python tools/generate_npcs.py
The generated meshes are editable Blender geometry; the preview is a Blender
asset-review render, not evidence of a Godot runtime scene.
"""

from pathlib import Path
import math

import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/hoang/hoang.glb"
OUT = ROOT / "assets/characters/npcs"
OUT.mkdir(parents=True, exist_ok=True)

# These are restrained visual variants, not claims about narrative personality.
# front, trousers, hair, skin, shoes, width, height, bag, detail
PROFILES = [
    ("Bao",  (.50,.53,.53), (.027,.037,.063), (.012,.013,.018), (.37,.26,.19), (.50,.52,.51), .96, 1.00, True,  "open_collar"),
    ("Huan", (.48,.50,.51), (.020,.030,.055), (.025,.023,.024), (.39,.28,.20), (.43,.44,.43), 1.02, .97, False, "sweater_vest"),
    ("Lan",  (.56,.56,.54), (.024,.028,.050), (.012,.014,.020), (.34,.235,.175),(.60,.59,.55), .91, 1.03, False, "rolled_cuffs"),
    ("Minh", (.47,.50,.53), (.017,.024,.046), (.018,.019,.022), (.40,.29,.215),(.52,.54,.53), .98, .99, True,  "dark_tie"),
    ("Bully_01", (.43,.45,.46), (.018,.023,.040), (.010,.010,.012),(.39,.275,.205),(.25,.26,.28),1.15, 1.04, False, "open_jacket"),
    ("Bully_02", (.46,.47,.46), (.025,.030,.046), (.023,.020,.018),(.35,.245,.18), (.35,.36,.36),1.11, .96, False, "dark_vest"),
    ("Bully_03", (.47,.48,.49), (.019,.027,.045), (.012,.013,.015),(.42,.30,.22), (.27,.28,.30),1.06, 1.08, False, "rolled_cuffs"),
]


def rgba(rgb):
    return (*rgb, 1.0)


def recolor(mat, rgb):
    mat.diffuse_color = rgba(rgb)
    if mat.use_nodes:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = rgba(rgb)


def new_mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    recolor(m, rgb)
    m.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = .88
    return m


def attach(obj, bone, arm, mat):
    obj.data.materials.append(mat)
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1, "REPLACE")
    obj.parent = arm
    obj.modifiers.new("NPC_skin", "ARMATURE").object = arm
    return obj


def block(name, center, size, bone, arm, mat, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new("Facet", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return attach(o, bone, arm, mat)


def cap(name, center, scale, bone, arm, mat, detail=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1, location=center)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return attach(o, bone, arm, mat)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # Blender's factory scene objects should never leak into exports.


def make_variant(profile):
    name, shirt, trouser, hair, skin, shoe, width, height, bag, style = profile
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    figure = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    figure.name = f"{name}_LowPoly"
    arm.name = f"{name}_Rig"

    # Remove backpack faces from unbagged variants, including the straps.
    if not bag:
        bag_indices = {i for i, m in enumerate(figure.data.materials)
                       if "Backpack" in m.name}
        bm = bmesh.new()
        bm.from_mesh(figure.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces
                                   if f.material_index in bag_indices], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces],
                         context="VERTS")
        bm.to_mesh(figure.data)
        bm.free()

    # Imported materials are per-import copies. Give every variant its own named
    # palette so a change to one character cannot recolor another one.
    for m in figure.data.materials:
        old = m.name
        m.name = old.replace("M_Hoang_", f"M_{name}_")
        if "Shirt_White" in old:
            recolor(m, shirt)
        elif "Shirt_Shadow" in old:
            recolor(m, tuple(v*.76 for v in shirt))
        elif "Trousers_Navy" in old:
            recolor(m, trouser)
        elif "Trousers_Fold" in old:
            recolor(m, tuple(v*.75 for v in trouser))
        elif "Hair_Black" in old:
            recolor(m, hair)
        elif "Hair_Facet" in old:
            recolor(m, tuple(min(v*1.7,.15) for v in hair))
        elif old.endswith("_Skin"):
            recolor(m, skin)
        elif "Sneaker_White" in old:
            recolor(m, shoe)
        elif "Sneaker_Sole" in old:
            recolor(m, tuple(v*.72 for v in shoe))

    accent = new_mat(f"M_{name}_Uniform_Accent", tuple(v*.60 for v in shirt))
    dark = new_mat(f"M_{name}_Dark_Cloth", (.045,.051,.062))
    hair_mat = new_mat(f"M_{name}_Hair_Additional", hair)
    skin_mat = new_mat(f"M_{name}_Skin_Additional", skin)

    # Base proportions stay close to the Hoang/An school-character scale. Their
    # armature node is scaled with the mesh, preserving inherited animations.
    arm.scale = (width, width, height)

    # Each silhouette gets additional, real skinned geometry: custom top hair,
    # fringe placement and clothing detail. The base face remains restrained.
    if name == "Bao":
        cap("Bao_side_part", (-.045,-.015,1.735), (.137,.151,.078), "head", arm, hair_mat, 2)
        for i in range(3):
            cap(f"Bao_fringe_{i}", (-.12+i*.046,-.145,1.690-i*.018),
                (.042,.052,.051), "head", arm, hair_mat)
        block("Bao_open_collar", (.09,-.174,1.37), (.05,.018,.07), "spine", arm, accent)
    elif name == "Huan":
        cap("Huan_short_crown", (0,0,1.745), (.155,.15,.066), "head", arm, hair_mat, 2)
        block("Huan_sweater_vest", (0,-.006,1.165), (.355,.238,.37), "spine", arm, dark, .025)
        block("Huan_vest_neck", (0,-.137,1.363), (.19,.018,.022), "spine", arm, accent)
    elif name == "Lan":
        cap("Lan_tousled_crown", (.018,0,1.76), (.17,.149,.09), "head", arm, hair_mat, 2)
        for i in range(4):
            cap(f"Lan_asymmetric_fringe_{i}", (-.115+i*.059,-.142,1.685+math.sin(i)*.032),
                (.037,.043,.056), "head", arm, hair_mat)
    elif name == "Minh":
        cap("Minh_flat_crown", (0,0,1.765), (.151,.145,.055), "head", arm, hair_mat, 2)
        block("Minh_tie", (0,-.164,1.307), (.028,.018,.21), "spine", arm, dark)
        block("Minh_tie_knot", (0,-.166,1.419), (.046,.026,.038), "spine", arm, dark)
    elif name == "Bully_01":
        cap("Bully01_high_crown", (0,0,1.774), (.17,.158,.085), "head", arm, hair_mat, 2)
        block("Bully01_open_jacket", (0,.003,1.151), (.40,.269,.46), "spine", arm, dark, .028)
        block("Bully01_jacket_front_L", (-.147,-.145,1.155), (.085,.018,.40), "spine", arm, accent)
        block("Bully01_jacket_front_R", (.147,-.145,1.155), (.085,.018,.40), "spine", arm, accent)
    elif name == "Bully_02":
        cap("Bully02_cropped_crown", (0,0,1.722), (.16,.145,.051), "head", arm, hair_mat, 2)
        block("Bully02_vest", (0,0,1.16), (.39,.251,.39), "spine", arm, dark, .019)
        block("Bully02_vest_band", (0,-.138,1.00), (.37,.015,.034), "spine", arm, accent)
    elif name == "Bully_03":
        cap("Bully03_long_crown", (0,.012,1.754), (.169,.155,.078), "head", arm, hair_mat, 2)
        for s in (-1,1):
            cap(f"Bully03_side_hair_{s}", (s*.128,-.018,1.63),
                (.043,.088,.113), "head", arm, hair_mat)

    if style == "rolled_cuffs":
        for s, side in ((-1,"L"),(1,"R")):
            block(f"{name}_{side}_rolled_cuff", (s*.275,0,1.19),
                  (.155,.17,.049), f"{side}_upper_arm", arm, accent, .009)

    # A little angular nose/ear variation changes the actual profile mesh.
    if name in {"Huan", "Bully_02"}:
        for s in (-1,1):
            cap(f"{name}_ear_{s}", (s*.148,-.012,1.606),
                (.032,.026,.039), "head", arm, skin_mat)

    additions = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != figure]
    bpy.ops.object.select_all(action="DESELECT")
    for o in additions:
        o.select_set(True)
    figure.select_set(True)
    bpy.context.view_layer.objects.active = figure
    bpy.ops.object.join()
    figure.data.validate(clean_customdata=True)

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    figure.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = OUT / f"{name.lower()}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
        use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS",
        export_nla_strips=True, export_skins=True, export_yup=True)
    print("NPC_EXPORT_OK", name, path, "vertices", len(figure.data.vertices))


def render_contact_sheet():
    clear_scene()
    for idx, profile in enumerate(PROFILES):
        name = profile[0]
        bpy.ops.import_scene.gltf(filepath=str(OUT / f"{name.lower()}.glb"))
        rig = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE")
        rig.location.x = (idx-3)*1.14
        if rig.animation_data:
            for track in rig.animation_data.nla_tracks:
                track.mute = True
        bpy.ops.object.text_add(location=((idx-3)*1.14,-.12,-.22), rotation=(math.pi/2,0,0))
        label = bpy.context.object
        label.data.body = name.replace("Bully_", "Bully ")
        label.data.size = .115
        label.data.align_x = "CENTER"
    bpy.ops.object.camera_add(location=(0,-12.5,3.5))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0,0,.85))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 9.1
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type='AREA', location=(-3,-4,5))
    bpy.context.object.data.energy = 1400
    bpy.context.object.data.shape = 'DISK'
    bpy.context.object.data.size = 7
    bpy.context.scene.world.color = (.22,.22,.25)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 2100
    scene.render.resolution_y = 680
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    preview_dir = ROOT / "docs/qa/blender_previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(preview_dir / "npc_contact_sheet_blender.png")
    scene.render.film_transparent = False
    bpy.ops.render.render(write_still=True)
    print("NPC_PREVIEW_OK", scene.render.filepath)


for npc in PROFILES:
    make_variant(npc)
render_contact_sheet()
