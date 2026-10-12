"""Create original, rigged PS2-style An; run with Blender --background --python."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import math

import bpy


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/an"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, rgb, roughness=0.9):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return m


blouse = material("M_An_Blouse_Ivory", (.55, .55, .53))
seam = material("M_An_Blouse_Shadow", (.39, .41, .43))
skin = material("M_An_Skin_Pale", (.38, .33, .31))
skin_shadow = material("M_An_Skin_Shadow", (.31, .27, .27))
hair = material("M_An_Hair_Black", (.008, .009, .015))
hair_facet = material("M_An_Hair_Facet", (.023, .025, .034))
skirt = material("M_An_Skirt_Navy", (.016, .021, .04))
skirt_fold = material("M_An_Skirt_Fold", (.026, .031, .052))
ribbon = material("M_An_Ribbon_Muted_Red", (.18, .047, .057))
sock = material("M_An_Sock_Gray", (.43, .43, .42))
shoe = material("M_An_Shoe_Black", (.025, .026, .03))
eyes = material("M_An_Eyes", (.016, .017, .022))


def mesh(name, verts, faces, mat, bone):
    d = bpy.data.meshes.new(name)
    d.from_pydata(verts, [], faces)
    d.update()
    o = bpy.data.objects.new(name, d)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    o["rigid_bone"] = bone
    return o


def box(name, center, size, mat, bone, bevel=0):
    x, y, z = center
    a, b, c = (v / 2 for v in size)
    v = [(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
         (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
    f = [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    o = mesh(name, v, f, mat, bone)
    if bevel:
        mod = o.modifiers.new("One-facet edge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def taper(name, z0, z1, lower, upper, xy, mat, bone):
    x, y = xy
    v = []
    for z, (w, d) in ((z0, lower), (z1, upper)):
        a, b, c = w/2, d/2, min(w,d)*.16
        v.extend([(x-a+c,y-b,z),(x+a-c,y-b,z),(x+a,y-b+c,z),
                  (x+a,y+b-c,z),(x+a-c,y+b,z),(x-a+c,y+b,z),
                  (x-a,y+b-c,z),(x-a,y-b+c,z)])
    f = [tuple(range(7,-1,-1)),tuple(range(8,16))]
    f += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    return mesh(name, v, f, mat, bone)


def ico(name, center, radius, scale, mat, bone, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=center)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    o["rigid_bone"] = bone
    return o


# Forward is -Y, matching Hoang. All dimensions are metres; this figure is 1.64 m.
taper("Blouse_body", .86, 1.37, (.30,.20), (.34,.225), (0,0), blouse, "spine")
box("Blouse_hem", (0,0,.865), (.31,.21,.036), seam, "spine", .008)
box("Blouse_placket", (0,-.121,1.17), (.014,.008,.33), seam, "spine")
for xsign, side in ((-1,"L"),(1,"R")):
    mesh(side+"_collar", [(0,-.128,1.385),(xsign*.135,-.118,1.382),(xsign*.065,-.169,1.284),
                          (0,-.133,1.385),(xsign*.135,-.123,1.382),(xsign*.065,-.174,1.284)],
         [(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)], blouse, "spine")

# Deep muted-red ribbon has two angular tails and a tiny centre knot.
box("Ribbon_knot", (0,-.158,1.312), (.046,.024,.049), ribbon, "spine", .007)
for side, sign in (("L",-1),("R",1)):
    box(side+"_ribbon_tail", (sign*.033,-.159,1.211),
        (.029,.010,.17), ribbon, "spine", .003)

taper("Skirt_waist", .79, .89, (.34,.23), (.29,.21), (0,0), skirt, "pelvis")
taper("Skirt_A_line", .55, .80, (.55,.36), (.33,.225), (0,0), skirt, "pelvis")
for i in range(7):
    x = (i-3)*.069
    mesh("Skirt_pleat_%02d"%i,
         [(x-.021,-.188,.556),(x+.021,-.188,.556),
          (x+.007,-.125,.785),(x-.007,-.125,.785)],
         [(0,1,2),(0,2,3)], skirt_fold if i%2 else skirt, "pelvis")

for side, sign in (("L",-1),("R",1)):
    x = sign*.107
    taper(side+"_thigh", .37, .79, (.105,.118), (.13,.13), (x,0), skin_shadow, side+"_thigh")
    taper(side+"_shin", .105, .39, (.085,.095), (.103,.11), (x,0), skin, side+"_shin")
    taper(side+"_sock", .07, .20, (.105,.115), (.103,.11), (x,0), sock, side+"_shin")
    box(side+"_shoe", (x,-.040,.066), (.145,.235,.083), shoe, side+"_foot", .028)
    box(side+"_shoe_strap", (x,-.092,.119), (.12,.027,.013), shoe, side+"_foot")
    sx = sign*.212
    taper(side+"_sleeve", 1.14, 1.36, (.12,.145), (.155,.165), (sx,0), blouse, side+"_upper_arm")
    taper(side+"_forearm", .895, 1.148, (.072,.079), (.095,.10), (sign*.244,0), skin, side+"_forearm")
    box(side+"_hand", (sign*.247,0,.85), (.075,.075,.105), skin, side+"_hand", .021)

box("Neck", (0,0,1.405), (.115,.118,.105), skin, "head")
taper("Jaw", 1.47, 1.535, (.125,.13), (.175,.15), (0,-.026), skin, "head")
ico("Face", (0,-.023,1.53), .118, (1.00,.82,1.18), skin, "head", 2)
box("Nose", (0,-.123,1.50), (.024,.029,.024), skin, "head", .008)
for side, sign in (("L",-1),("R",1)):
    box(side+"_eye", (sign*.055,-.129,1.538), (.034,.007,.012), eyes, "head")
    box(side+"_brow", (sign*.055,-.124,1.563), (.047,.009,.009), hair, "head")
    ico(side+"_ear", (sign*.115,-.007,1.514), .02, (1,1,1), skin, "head")

ico("Hair_crown", (0,.002,1.621), .136, (1.05,.97,.73), hair, "head", 2)
for i in range(7):
    x = (i-3)*.034
    taper("Fringe_%02d"%i, 1.546-(i%3)*.013, 1.625,
          (.025,.029),(.036,.047), (x,-.112), hair_facet if i%3==1 else hair, "head")
for side, sign in (("L",-1),("R",1)):
    taper(side+"_side_hair", 1.20, 1.61, (.055,.09), (.092,.11),
          (sign*.108,.017), hair, "head")
for i in range(5):
    x = (i-2)*.055
    taper("Back_hair_%02d"%i, 1.17+abs(i-2)*.027, 1.625,
          (.06,.065),(.075,.095), (x,.092), hair_facet if i%2 else hair, "head")

arm_data = bpy.data.armatures.new("An_Rig")
arm = bpy.data.objects.new("An_Rig", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm_data.edit_bones[parent]


bone("root", (0,0,0), (0,0,.78))
bone("pelvis", (0,0,.78), (0,0,.89), "root")
bone("spine", (0,0,.89), (0,0,1.37), "pelvis")
bone("head", (0,0,1.37), (0,0,1.65), "spine")
for side, sign in (("L",-1),("R",1)):
    bone(side+"_upper_arm", (sign*.19,0,1.34), (sign*.245,0,1.14), "spine")
    bone(side+"_forearm", (sign*.245,0,1.14), (sign*.245,0,.89), side+"_upper_arm")
    bone(side+"_hand", (sign*.245,0,.89), (sign*.245,0,.80), side+"_forearm")
    bone(side+"_thigh", (sign*.107,0,.78), (sign*.107,0,.39), "pelvis")
    bone(side+"_shin", (sign*.107,0,.39), (sign*.107,0,.105), side+"_thigh")
    bone(side+"_foot", (sign*.107,0,.105), (sign*.107,-.16,.06), side+"_shin")
bpy.ops.object.mode_set(mode="OBJECT")

parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in parts:
    group = o.vertex_groups.new(name=o["rigid_bone"])
    group.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    mod = o.modifiers.new("An_skin", "ARMATURE")
    mod.object = arm
    o.parent = arm
    del o["rigid_bone"]
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
figure = parts[0]
figure.name = "An_LowPoly"
figure.data.validate(clean_customdata=True)


def anim(name, poses, end=33):
    action = bpy.data.actions.new(name=name)
    arm.animation_data_create()
    arm.animation_data.action = action
    for frame, angles in poses:
        for p in arm.pose.bones:
            p.rotation_mode = "XYZ"
            p.rotation_euler = tuple(math.radians(v) for v in angles.get(p.name, (0,0,0)))
            p.keyframe_insert(data_path="rotation_euler", frame=frame, group=p.name)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_frame_start, strip.action_frame_end = 1, end


neutral = {}
anim("Idle", [(1,neutral),(17,{"spine":(2,0,0),"head":(-3,0,0)}),(33,neutral)])
walk_a = {"L_thigh":(19,0,0),"R_thigh":(-19,0,0),"R_shin":(13,0,0),
          "L_upper_arm":(-10,0,0),"R_upper_arm":(10,0,0)}
walk_b = {"L_thigh":(-19,0,0),"R_thigh":(19,0,0),"L_shin":(13,0,0),
          "L_upper_arm":(10,0,0),"R_upper_arm":(-10,0,0)}
anim("Walk", [(1,walk_a),(17,walk_b),(33,walk_a)])
anim("Sit", [(1,neutral),(17,{"L_thigh":(-78,0,0),"R_thigh":(-78,0,0),
                               "L_shin":(78,0,0),"R_shin":(78,0,0)}),(33,neutral)])
anim("Point", [(1,neutral),(17,{"R_upper_arm":(-63,0,-13),"R_forearm":(-24,0,0),
                                 "head":(-6,0,-8)}),(33,neutral)])
anim("Chess_Interact", [(1,neutral),(17,{"spine":(10,0,0),"R_upper_arm":(-59,0,0),
                                          "R_forearm":(-23,0,0),"head":(-7,0,0)}),(33,neutral)])
anim("Mirror_Stare", [(1,neutral),(17,{"head":(0,0,9),"spine":(0,0,-5)}),(33,neutral)])

bpy.context.preferences.filepaths.save_version = 0
source = OUT / "an.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
with ZipFile(OUT / "an_blender_source.zip", "w", ZIP_DEFLATED) as archive:
    archive.write(source, "an.blend")
source.unlink()

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
figure.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=str(OUT / "an.glb"), export_format="GLB",
    use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS",
    export_nla_strips=True, export_skins=True, export_yup=True)
print("AN_EXPORT_OK", OUT / "an.glb")

# Asset-review preview, rendered from Blender geometry (not an in-game capture).
from mathutils import Vector

bpy.context.scene.frame_set(1)
for track in arm.animation_data.nla_tracks:
    track.mute = True
for p in arm.pose.bones:
    p.rotation_mode = "XYZ"
    p.rotation_euler = (0,0,0)
bpy.ops.object.camera_add(location=(2.1,-4.2,1.9))
camera = bpy.context.object
direction = Vector((0,0,.84))-camera.location
camera.rotation_euler = direction.to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.15
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(-2.5,-3.0,3.8))
bpy.context.object.data.energy = 650
bpy.context.object.data.shape = 'DISK'
bpy.context.object.data.size = 4
bpy.ops.object.light_add(type='AREA', location=(2,1.5,2.7))
bpy.context.object.data.energy = 450
bpy.context.object.data.size = 3
bpy.context.scene.render.engine = 'BLENDER_EEVEE'
bpy.context.scene.render.resolution_x = 820
bpy.context.scene.render.resolution_y = 980
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = 'PNG'
preview_dir = ROOT / 'docs' / 'qa' / 'blender_previews'
preview_dir.mkdir(parents=True, exist_ok=True)
bpy.context.scene.render.filepath = str(preview_dir / 'an_preview.png')
bpy.context.scene.world.color = (.12,.12,.14)
bpy.context.scene.view_settings.view_transform = 'Standard'
bpy.ops.render.render(write_still=True)
print("AN_PREVIEW_OK", bpy.context.scene.render.filepath)
