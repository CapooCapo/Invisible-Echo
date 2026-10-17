"""Build the original low-poly Hoang character and animation library in Blender.

Run: blender -b --factory-startup --python tools/generate_hoang.py
The generated GLB is original project geometry, not an extracted reference image.
"""

import bpy
import math
from mathutils import Vector
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile, ZIP_DEFLATED


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "characters" / "hoang"
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color, roughness=0.9):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


shirt = material("M_Hoang_Uniform_Navy", (0.045, 0.070, 0.135))
shirt_edge = material("M_Hoang_Uniform_Navy_Edge", (0.075, 0.105, 0.19))
shirt_fold = material("M_Hoang_Uniform_Navy_Folds", (0.028, 0.046, 0.095))
uniform_collar = material("M_Hoang_Uniform_Collar", (0.68, 0.71, 0.76))
trousers = material("M_Hoang_Trousers_Navy", (0.025, 0.036, 0.070))
trouser_fold = material("M_Hoang_Trousers_Fold", (0.014, 0.022, 0.046))
skin = material("M_Hoang_Skin", (0.58, 0.39, 0.30))
skin_shadow = material("M_Hoang_Skin_Shadow", (0.42, 0.27, 0.21))
hair = material("M_Hoang_Hair_Black", (0.002, 0.0025, 0.0035))
hair_alt = material("M_Hoang_Hair_Facet", (0.003, 0.0035, 0.0045))
bag = material("M_Hoang_Backpack_Light_Gray", (0.59, 0.62, 0.67))
bag_fold = material("M_Hoang_Backpack_Gray_Trim", (0.40, 0.44, 0.50))
shoe = material("M_Hoang_Sneaker_White", (0.82, 0.82, 0.80))
sole = material("M_Hoang_Sneaker_Sole", (0.53, 0.53, 0.51))
eye = material("M_Hoang_Eyes", (0.004, 0.004, 0.005))
eye_white = material("M_Hoang_Eye_White", (0.78, 0.70, 0.63))
lip = material("M_Hoang_Lips", (0.28, 0.14, 0.125))
for hair_mat in (hair, hair_alt):
    hair_bsdf = hair_mat.node_tree.nodes.get("Principled BSDF")
    if "Specular IOR Level" in hair_bsdf.inputs:
        hair_bsdf.inputs["Specular IOR Level"].default_value = 0.03
    hair_bsdf.inputs["Roughness"].default_value = 1.0


def mesh(name, verts, faces, mat, bone):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj["rigid_bone"] = bone
    return obj


def box(name, center, size, mat, bone, bevel=0.0):
    x, y, z = center
    a, b, c = (v / 2 for v in size)
    v = [(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
         (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
    f = [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    ob = mesh(name, v, f, mat, bone)
    if bevel:
        mod = ob.modifiers.new("Soft angular corners", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


def tapered(name, z0, z1, lower, upper, center_xy, mat, bone):
    x, y = center_xy
    verts = []
    for z, (w, d) in ((z0, lower), (z1, upper)):
        a, b, c = w/2, d/2, min(w,d)*.16
        verts += [(x-a+c,y-b,z),(x+a-c,y-b,z),(x+a,y-b+c,z),
                  (x+a,y+b-c,z),(x+a-c,y+b,z),(x-a+c,y+b,z),
                  (x-a,y+b-c,z),(x-a,y-b+c,z)]
    faces = [tuple(range(7,-1,-1)),tuple(range(8,16))]
    faces += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    return mesh(name, verts, faces, mat, bone)


def loft(name, rings, mat, bone):
    """Angular eight-sided section loft; rings are (x,y,z,width,depth)."""
    verts = []
    for x, y, z, width, depth in rings:
        a, b, corner = width / 2, depth / 2, min(width, depth) * .16
        verts += [(x-a+corner,y-b,z),(x+a-corner,y-b,z),
                  (x+a,y-b+corner,z),(x+a,y+b-corner,z),
                  (x+a-corner,y+b,z),(x-a+corner,y+b,z),
                  (x-a,y+b-corner,z),(x-a,y-b+corner,z)]
    faces = [tuple(range(7,-1,-1)), tuple(range(len(verts)-8,len(verts)))]
    for section in range(len(rings)-1):
        base = section*8
        faces += [(base+i,base+(i+1)%8,base+8+(i+1)%8,base+8+i)
                  for i in range(8)]
    return mesh(name, verts, faces, mat, bone)


def facet(name, points, mat, bone):
    return mesh(name, points, [tuple(range(len(points)))], mat, bone)


def ico(name, center, radius, mat, bone, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj["rigid_bone"] = bone
    return obj


# The visual vocabulary is angular and economical, but it is a clothed human,
# not a collection of boxes. Front is negative Y; floor is Z=0; height 1.8 m.
loft("Untucked_school_shirt", [(0,0,.905,.30,.22),(-.012,0,1.00,.305,.215),
     (0,0,1.16,.29,.205),(0,0,1.34,.315,.22),(0,0,1.415,.28,.20)], shirt,"spine")
facet("Hem_front_left", [(-.172,-.124,.91),(-.006,-.128,.90),(-.015,-.129,.943)],shirt_fold,"spine")
facet("Hem_front_right", [(.007,-.129,.90),(.17,-.124,.91),(.022,-.128,.943)],shirt_fold,"spine")
facet("Fold_left_waist", [(-.164,-.119,1.01),(-.108,-.124,1.105),(-.101,-.125,.962)],shirt_fold,"spine")
facet("Fold_right_chest", [(.174,-.114,1.333),(.107,-.131,1.238),(.146,-.12,1.175)],shirt_fold,"spine")
facet("Center_placket", [(-.009,-.135,1.39),(.009,-.135,1.39),(.009,-.139,.955),(-.009,-.139,.955)],shirt_fold,"spine")
for z in (1.01,1.115,1.22,1.325):
    ico("Shirt_button", (0,-.143,z), .0055, bag_fold, "spine")
for side, sign in (("L",-1),("R",1)):
    facet(side+"_collar", [(sign*.012,-.114,1.444),(sign*.133,-.113,1.409),
          (sign*.046,-.159,1.337),(sign*.012,-.161,1.412)],uniform_collar,"spine")
    facet(side+"_collar_underside", [(sign*.046,-.16,1.337),(sign*.133,-.114,1.407),
          (sign*.11,-.134,1.348)],shirt_edge,"spine")
facet("Chest_pocket",[(.085,-.131,1.305),(.174,-.119,1.305),
      (.167,-.122,1.226),(.13,-.132,1.212),(.088,-.132,1.228)],shirt_fold,"spine")
facet("Pocket_top",[(.084,-.132,1.302),(.174,-.12,1.302),(.173,-.121,1.289),(.086,-.133,1.289)],shirt_edge,"spine")
loft("Trousers_hips",[(0,.018,.81,.305,.17),(0,.018,.87,.313,.17),
     (0,.018,.911,.31,.17)],trousers,"pelvis")

for side, sign in (("L",-1),("R",1)):
    x = sign*.095
    loft(side+"_trouser_upper",[(x,0,.445,.14,.18),(x,-.004,.56,.147,.182),
         (x,.003,.73,.157,.19),(x,0,.86,.162,.19)],trousers,side+"_thigh")
    loft(side+"_trouser_lower",[(x,-.014,.10,.145,.19),(x,.006,.17,.138,.175),
         (x,.014,.29,.143,.177),(x,0,.445,.145,.177)],trousers,side+"_shin")
    facet(side+"_knee_crease",[(x-sign*.064,-.089,.449),(x+sign*.048,-.09,.425),
          (x-sign*.004,-.092,.436)],trouser_fold,side+"_shin")
    facet(side+"_cuff_fold",[(x-.07,-.10,.168),(x+.065,-.10,.155),
          (x+.067,-.11,.125),(x-.068,-.11,.138)],trouser_fold,side+"_shin")
    loft(side+"_sneaker_sole",[(x,-.073,.017,.17,.296),(x,-.073,.038,.17,.295)],sole,side+"_foot")
    loft(side+"_sneaker",[(x,-.083,.038,.158,.278),(x,-.084,.079,.158,.276),
         (x,-.025,.128,.139,.147)],shoe,side+"_foot")
    facet(side+"_shoe_vamp",[(x-.055,-.207,.082),(x+.055,-.207,.082),
          (x+.048,-.103,.122),(x-.048,-.103,.122)],shoe,side+"_foot")
    for y in (-.174,-.146,-.118):
        facet(side+"_lace",[(x-.036,y,.124),(x+.036,y+.009,.124),
              (x+.036,y+.017,.128),(x-.036,y+.008,.128)],shoe,side+"_foot")

    sx=sign*.239
    loft(side+"_shirt_sleeve",[(sign*.258,0,1.193,.112,.128),
         (sign*.251,0,1.26,.12,.138),(sign*.214,0,1.405,.124,.15)],shirt,side+"_upper_arm")
    loft(side+"_sleeve_hem",[(sign*.258,0,1.184,.113,.129),
         (sign*.258,0,1.198,.114,.13)],shirt_fold,side+"_upper_arm")
    if sign < 0:
        # Reference pose: viewer-left arm bends inward and the hand grips the
        # backpack strap on the chest. Front is -Y.
        loft("L_upper_arm_skin",[(-.258,0,1.184,.105,.105),
             (-.277,-.004,1.143,.094,.095),(-.292,-.004,1.105,.082,.082)],skin,"L_upper_arm")
        loft("L_forearm",[(-.292,-.004,1.105,.082,.082),
             (-.238,-.075,1.17,.088,.084),(-.157,-.157,1.255,.078,.078)],skin,"L_forearm")
        # Palm overlaps the strap; thumb and two folded fingers visibly hook
        # around it rather than floating in front of the chest.
        loft("L_hand",[(-.15,-.19,1.214,.068,.05),
             (-.143,-.205,1.245,.068,.054),(-.14,-.199,1.274,.058,.05)],skin,"L_hand")
        # Thumb opposes the fingers across the webbing; the fingers are short,
        # distinct curled segments, not a closed fist silhouette.
        loft("L_thumb",[(-.098,-.218,1.27,.021,.024),
             (-.119,-.24,1.258,.022,.025),(-.145,-.241,1.25,.021,.024)],skin,"L_hand")
        for finger, z in enumerate((1.223, 1.24, 1.257)):
            loft("L_gripping_finger_%d" % finger,
                 [(-.177,-.224,z,.017,.019),(-.159,-.242,z+.004,.018,.020),
                  (-.128,-.24,z+.002,.016,.019)],skin,"L_hand")
    else:
        # The opposite arm hangs naturally at his side.
        loft(side+"_forearm",[(sign*.292,0,.895,.077,.077),
             (sign*.294,0,1.04,.091,.093),(sign*.262,0,1.18,.105,.105)],skin,side+"_forearm")
        loft(side+"_hand",[(sign*.292,-.003,.81,.067,.068),
             (sign*.294,-.002,.87,.084,.079),(sign*.292,0,.91,.078,.078)],skin,side+"_hand")
        loft(side+"_thumb",[(sign*.331,-.036,.848,.025,.026),
             (sign*.339,-.026,.897,.028,.029)],skin,side+"_hand")

loft("Neck",[(0,0,1.404,.13,.125),(0,0,1.505,.126,.121)],skin,"head")
loft("Face_jaw",[(0,-.018,1.51,.116,.131),(0,-.018,1.54,.167,.162),
     (0,-.014,1.635,.242,.205),(0,-.003,1.735,.24,.21),
     (0,0,1.758,.185,.185)],skin,"head")
facet("Nose_bridge",[(-.014,-.119,1.648),(.014,-.119,1.648),
      (.017,-.144,1.597),(-.017,-.144,1.597)],skin_shadow,"head")
loft("Nose_tip",[(0,-.151,1.592,.031,.034),(0,-.14,1.611,.029,.031)],skin,"head")
facet("Mouth",[(-.026,-.108,1.558),(0,-.111,1.567),(.027,-.108,1.558),
      (.023,-.11,1.553),(0,-.113,1.562),(-.022,-.11,1.553)],lip,"head")
for side, sign in (("L",-1),("R",1)):
    cx = sign*.064
    facet(side+"_open_sclera",[(cx-.027,-.128,1.66),(cx+.027,-.128,1.655),
          (cx+.025,-.134,1.627),(cx-.025,-.134,1.632)],eye_white,"head")
    # Low pupils inside an open eye shape give a clearly downward gaze.
    facet(side+"_iris",[(cx-.012,-.14,1.645),(cx+.012,-.14,1.642),
          (cx+.011,-.143,1.626),(cx-.011,-.143,1.629)],eye,"head")
    facet(side+"_brow",[(sign*.034,-.133,1.681),(sign*.095,-.124,1.664),
          (sign*.095,-.126,1.659),(sign*.034,-.135,1.674)],hair,"head")
    ico(side+"_ear",(sign*.128,.004,1.623),.026,skin,"head")
    facet(side+"_cheek_shadow",[(sign*.101,-.085,1.635),(sign*.115,-.065,1.59),
          (sign*.089,-.096,1.603)],skin_shadow,"head")
cap=ico("Hair_mass",(0,.009,1.747),.148,hair,"head",2)
cap.scale=(1.08,.96,.69)
for i in range(9):
    xx=-.115+i*.029
    length=.012+(i*7%5)*.008
    facet("Fringe_%02d"%i,[(xx-.025,-.127,1.753),(xx+.02,-.13,1.749),
          (xx+.008,-.139,1.696-length),(xx-.014,-.136,1.72-length*.45)],
          hair_alt if i%3==0 else hair,"head")
for i in range(6):
    xx=-.116+i*.047
    facet("Crown_facet_%02d"%i,[(xx-.027,-.074,1.776),(xx+.018,-.078,1.775),
          (xx+.028,-.044,1.805),(xx-.012,-.042,1.805)],
          hair_alt if i%3==0 else hair,"head")
# Soft overlapping low-poly clumps build a full shaggy silhouette without
# the sharp spike/helmet outline of separate triangular tufts.
for i, (center, scale) in enumerate((
        ((-.105,.018,1.775),(.62,.74,.62)),((-.055,.006,1.795),(.69,.72,.67)),
        ((.005,.008,1.80),(.73,.72,.65)),((.065,.018,1.79),(.67,.72,.65)),
        ((.112,.025,1.755),(.58,.70,.62)),((-.132,.01,1.69),(.53,.62,.78)),
        ((.132,.01,1.69),(.53,.62,.78)))):
    clump = ico("Shaggy_hair_clump_%02d" % i,center,.088,hair if i%3 else hair_alt,"head",2)
    clump.scale = scale
for side, sign in (("L",-1),("R",1)):
    facet(side+"_sideburn",[(sign*.123,-.058,1.735),(sign*.136,.002,1.738),
          (sign*.136,-.008,1.617),(sign*.112,-.061,1.655)],hair,"head")

loft("Backpack_body",[(-.085,.22,.835,.32,.19),(-.09,.235,.94,.385,.235),
     (-.09,.235,1.20,.39,.235),(-.075,.21,1.405,.31,.195)],bag,"spine")
loft("Backpack_front_pocket",[(-.09,.354,1.00,.25,.04),(-.09,.365,1.10,.275,.045),
     (-.09,.354,1.16,.24,.04)],bag_fold,"spine")
facet("Backpack_zipper",[(-.22,.393,1.164),(.04,.393,1.164),
      (.035,.392,1.154),(-.215,.392,1.154)],sole,"spine")
loft("Backpack_top_handle",[(-.085,.187,1.38,.083,.04),(-.085,.182,1.445,.084,.04)],bag_fold,"spine")
for side, sign in (("L",-1),("R",1)):
    loft(side+"_backpack_strap",[(sign*.12,-.12,1.096,.032,.019),
         (sign*.158,-.151,1.22,.034,.02),(sign*.145,-.145,1.31,.033,.019),
         (sign*.125,-.111,1.407,.03,.018)],bag,"spine")
    loft(side+"_strap_buckle",[(sign*.12,-.145,1.11,.033,.022),
         (sign*.125,-.151,1.128,.033,.022)],bag_fold,"spine")


# Armature: a compact humanoid rig. Rigid weighted pieces retain the intentional
# angular PS2 silhouette while supporting locomotion and interaction animation.
arm_data = bpy.data.armatures.new("Hoang_Rig")
arm = bpy.data.objects.new("Hoang_Rig", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm_data.edit_bones[parent]
    return b


bone("root", (0,0,0), (0,0,.85))
bone("pelvis", (0,0,.84), (0,0,.98), "root")
bone("spine", (0,0,.98), (0,0,1.43), "pelvis")
bone("head", (0,0,1.43), (0,0,1.77), "spine")
for side, sign in (("L",-1),("R",1)):
    if sign < 0:
        bone("L_upper_arm", (sign*.21,0,1.39), (-.292,-.004,1.105), "spine")
        bone("L_forearm", (-.292,-.004,1.105), (-.145,-.193,1.22), "L_upper_arm")
        bone("L_hand", (-.145,-.193,1.22), (-.139,-.20,1.28), "L_forearm")
    else:
        bone(side+"_upper_arm", (sign*.21,0,1.39), (sign*.275,0,1.16), "spine")
        bone(side+"_forearm", (sign*.275,0,1.16), (sign*.28,0,.91), side+"_upper_arm")
        bone(side+"_hand", (sign*.28,0,.91), (sign*.28,0,.82), side+"_forearm")
    bone(side+"_thigh", (sign*.105,0,.84), (sign*.105,0,.46), "pelvis")
    bone(side+"_shin", (sign*.105,0,.46), (sign*.105,0,.13), side+"_thigh")
    bone(side+"_foot", (sign*.105,0,.13), (sign*.105,-.18,.07), side+"_shin")
bpy.ops.object.mode_set(mode="OBJECT")
arm.show_in_front = True
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    group = obj.vertex_groups.new(name=obj["rigid_bone"])
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("Hoang_skin", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    del obj["rigid_bone"]

# One skinned mesh preserves material separation while avoiding one draw call
# per little button, hair lock or buckle.
parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
parts[0].name = "Hoang_LowPoly"


def anim(name, poses, count=32):
    action = bpy.data.actions.new(name=name)
    arm.animation_data_create()
    arm.animation_data.action = action
    for frame, angles in poses:
        for pb in arm.pose.bones:
            pb.rotation_mode = "XYZ"
            xyz = angles.get(pb.name, neutral.get(pb.name, (0,0,0)))
            pb.rotation_euler = tuple(math.radians(v) for v in xyz)
            pb.keyframe_insert(data_path="rotation_euler", frame=frame, group=pb.name)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_frame_start = 1
    strip.action_frame_end = count
    return action


neutral = {"spine":(4,0,0),"head":(18,0,0)}
anim("Idle", [(1,neutral),(17,{"spine":(2,0,0),"head":(16,0,0)}),(33,neutral)])
walk_a = {"L_thigh":(23,0,0),"R_thigh":(-23,0,0),"L_shin":(-8,0,0),
          "R_shin":(16,0,0),"R_upper_arm":(15,0,0)}
walk_b = {"L_thigh":(-23,0,0),"R_thigh":(23,0,0),"L_shin":(16,0,0),
          "R_shin":(-8,0,0),"R_upper_arm":(-15,0,0)}
anim("Walk", [(1,walk_a),(17,walk_b),(33,walk_a)])
run_a = {"L_thigh":(39,0,0),"R_thigh":(-39,0,0),"R_shin":(34,0,0),
         "R_upper_arm":(32,0,0),"spine":(9,0,0)}
run_b = {"L_thigh":(-39,0,0),"R_thigh":(39,0,0),"L_shin":(34,0,0),
         "R_upper_arm":(-32,0,0),"spine":(9,0,0)}
anim("Run", [(1,run_a),(13,run_b),(25,run_a)],24)
anim("Turn_Left", [(1,neutral),(16,{"spine":(0,0,17),"head":(0,0,21)}),(33,neutral)])
anim("Turn_Right", [(1,neutral),(16,{"spine":(0,0,-17),"head":(0,0,-21)}),(33,neutral)])
anim("Pick_Up", [(1,neutral),(17,{"spine":(43,0,0),"head":(-20,0,0),"R_upper_arm":(-41,0,0),"R_forearm":(-22,0,0)}),(33,neutral)])
anim("Interact", [(1,neutral),(15,{"R_upper_arm":(-65,0,-12),"R_forearm":(-20,0,0)}),(33,neutral)])
anim("Hide", [(1,neutral),(17,{"spine":(24,0,0),"L_thigh":(-55,0,0),"R_thigh":(-55,0,0),"L_shin":(82,0,0),"R_shin":(82,0,0)}),(33,neutral)])
anim("Look_Behind", [(1,neutral),(17,{"spine":(0,0,12),"head":(0,0,63)}),(33,neutral)])
anim("Frightened", [(1,neutral),(9,{"spine":(-12,0,0),"head":(8,0,0),"L_upper_arm":(-38,0,25),"R_upper_arm":(-38,0,-25)}),(33,neutral)])
anim("Sit", [(1,neutral),(17,{"L_thigh":(-80,0,0),"R_thigh":(-80,0,0),"L_shin":(78,0,0),"R_shin":(78,0,0),"spine":(5,0,0)}),(33,neutral)])
anim("Chess_Interact", [(1,neutral),(17,{"spine":(12,0,0),"R_upper_arm":(-60,0,0),"R_forearm":(-25,0,0),"head":(-8,0,0)}),(33,neutral)])

arm.animation_data.nla_tracks.active = arm.animation_data.nla_tracks[0]
bpy.context.preferences.filepaths.save_version = 0
with TemporaryDirectory(prefix="hoang-source-") as source_dir:
    blend_source = Path(source_dir) / "hoang.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_source))
    with ZipFile(OUT / "hoang_blender_source.zip", "w", ZIP_DEFLATED) as archive:
        archive.write(blend_source, "hoang.blend")
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "hoang.glb"), export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="NLA_TRACKS",
    export_nla_strips=True, export_skins=True, export_yup=True,
)
print("HOANG_EXPORT_OK", OUT / "hoang.glb")

# A Blender render is evidence of the generated model, never a substitute for
# an in-engine screenshot. Render after GLB/source export so preview lights are
# not part of the game asset.
# The still uses a reference-matching three-quarter, withdrawn pose only. These
# preview transforms are intentionally applied after export and do not affect
# the gameplay rig or its animation clips.
arm.rotation_euler.z = math.radians(7)
arm.animation_data.use_nla = False
for pose_bone in arm.pose.bones:
    pose_bone.rotation_mode = "XYZ"
    pose_bone.rotation_euler = (0, 0, 0)
arm.pose.bones["spine"].rotation_euler.x = math.radians(7)
arm.pose.bones["head"].rotation_euler.x = math.radians(18)
preview_dir = ROOT / "builds" / "visual-qa"
preview_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.object.camera_add(location=(-2.5, -4.5, 2.15))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, .89)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.17
bpy.context.scene.camera = camera
for name, position, power, size in (
    ("Key", (1.3, -2.5, 3.4), 630, 3.0),
    ("Fill", (2.2, -1.1, 1.9), 310, 2.5),
    ("Rim", (0.4, 2.0, 2.9), 760, 2.0),
):
    bpy.ops.object.light_add(type="AREA", location=position)
    light = bpy.context.object
    light.name = name
    light.data.energy = power
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, .9)) - light.location).to_track_quat("-Z", "Y").to_euler()
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -.6
scene.world.color = (.10, .11, .14)
scene.render.resolution_x = 720
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.render.filepath = str(preview_dir / "hoang_reference_match_preview.png")
bpy.ops.render.render(write_still=True)
print("HOANG_BLENDER_PREVIEW_OK", scene.render.filepath)
