"""Generate original, meter-scaled low-poly computer-lab props.

Run from anywhere: blender -b --factory-startup --python tools/generate_lab_props.py
The source .blend and GLBs are authored here; the reference image is not an asset.
Blender Z is up. A monitor's screen faces Blender -Y (glTF/Godot front).
"""

from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "props" / "lab"
PREV = ROOT / "docs" / "qa" / "blender_previews"
OUT.mkdir(parents=True, exist_ok=True)
PREV.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def mat(name, rgb, rough=.82, metallic=0.0, emission=None):
    m = bpy.data.materials.new("M_Lab_" + name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    if emission:
        p.inputs["Emission Color"].default_value = (*emission, 1)
        p.inputs["Emission Strength"].default_value = .65
    return m


ivory = mat("AgedIvory", (.53, .52, .45))
ivory_light = mat("PlasticEdge", (.65, .62, .53))
ivory_shadow = mat("PlasticGrime", (.33, .34, .30))
dark = mat("CharcoalPlastic", (.028, .035, .037), .68)
rubber = mat("Rubber", (.013, .018, .018), .96)
glass = mat("CRTGlass", (.007, .027, .025), .24)
phosphor = mat("Phosphor", (.045, .23, .13), .46, emission=(.009, .075, .032))
led = mat("PowerLED", (.07, .49, .23), .25, emission=(.02, .35, .1))
steel = mat("PaintedSteel", (.11, .14, .14), .62, .24)
steel_edge = mat("WornSteelEdge", (.22, .25, .24), .74, .14)
wood = mat("WornSchoolWood", (.26, .16, .095), .83)
wood_edge = mat("ExposedWood", (.37, .24, .13), .87)
wood_dark = mat("WoodWornDark", (.12, .075, .043), .89)
paper = mat("Paper", (.66, .64, .55), .94)
ink = mat("Ink", (.10, .13, .13), .91)

def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

def put(obj, coll, material):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.data.materials.append(material)
    return obj

def bevel(obj, width=.01, segments=1):
    if width:
        mod = obj.modifiers.new("LowPolyChamfer", "BEVEL")
        mod.width = width
        mod.segments = segments
        mod.affect = "EDGES"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def cube(coll, name, loc, scale, material, edge=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    put(o, coll, material)
    # Sub-3 mm chamfers inflate repeated keys, vents, and scratches without
    # affecting their silhouette at the game's 960x540 target resolution.
    bevel(o, edge if edge >= .003 else 0)
    return o

def cylinder(coll, name, loc, radius, depth, material, vertices=12, axis="Z"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    if axis == "Y":
        o.rotation_euler.x = math.pi / 2
    elif axis == "X":
        o.rotation_euler.y = math.pi / 2
    put(o, coll, material)
    bevel(o, min(radius * .16, .006))
    return o

def loft(coll, name, rings, material):
    """Rectangular truncated shell; rings are (y, half-width, half-height, center-z)."""
    verts = []
    for y, w, h, z in rings:
        verts += [(-w,y,z-h),(w,y,z-h),(w,y,z+h),(-w,y,z+h)]
    faces = [(3,2,1,0)]
    for i in range(len(rings)-1):
        n = 4*i
        faces.extend([(n+j,n+(j+1)%4,n+4+(j+1)%4,n+4+j) for j in range(4)])
    n = len(verts)-4
    faces.append((n,n+1,n+2,n+3))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    coll.objects.link(obj)
    obj.data.materials.append(material)
    bevel(obj, .009)
    return obj

def line(coll, name, start, end, radius, material, vertices=6):
    v = Vector(end)-Vector(start)
    mid = (Vector(start)+Vector(end))/2
    o = cylinder(coll, name, mid, radius, v.length, material, vertices)
    o.rotation_euler = v.to_track_quat("Z", "Y").to_euler()
    return o

def join_by_material(coll):
    """Keep one draw surface per material, rather than hundreds of tiny key meshes."""
    groups = {}
    for o in list(coll.objects):
        if o.type == "MESH":
            groups.setdefault(o.data.materials[0].name, []).append(o)
    for mname, objs in groups.items():
        if len(objs) == 1:
            objs[0].name = coll.name + "__" + mname.removeprefix("M_Lab_")
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name = coll.name + "__" + mname.removeprefix("M_Lab_")
    bpy.ops.object.select_all(action="DESELECT")

def export(coll):
    join_by_material(coll)
    bpy.ops.object.select_all(action="DESELECT")
    for o in coll.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (coll.name + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False)
    bpy.ops.object.select_all(action="DESELECT")


# CRT origin is the desktop. Screen faces -Y; its height is ~0.62 m.
crt = collection("aged_crt_monitor")
cube(crt,"Foot",(0,0,.027),(.32,.29,.054),ivory_shadow,.014)
cube(crt,"Neck",(0,.035,.085),(.105,.12,.09),ivory,.012)
loft(crt,"DeepTaperedCRTCase",[(-.09,.36,.275,.36),(.08,.385,.282,.355),(.43,.33,.245,.35)],ivory)
cube(crt,"FrontBezelOuter",(0,-.112,.36),(.755,.06,.584),ivory_light,.018)
cube(crt,"BezelWell",(0,-.150,.385),(.655,.012,.465),ivory_shadow,.014)
cube(crt,"CurvedScreenApproximation",(0,-.160,.385),(.624,.012,.435),glass,.035)
for z in (.29,.33,.37,.41,.45):
    cube(crt,"FaintPhosphorLine",(-.18,-.168,z),(.17,.002,.002),phosphor,.0005)
cube(crt,"PhosphorCursor",(-.055,-.169,.288),(.012,.002,.017),phosphor,.001)
for side in (-1,1):
    cube(crt,"TopBezelWear",(side*.23,-.146,.623),(.25,.003,.008),ivory,.002)
    for i in range(7):
        # Low-relief side vent cuts read at a 960x540 third-person camera.
        cube(crt,"SideVentShadow",(side*.355,.115+i*.037,.422),(.004,.023,.090),ivory_shadow,.001)
        cube(crt,"SideVentLip",(side*.357,.114+i*.037,.468),(.006,.025,.004),ivory_light,.001)
for i in range(12):
    cube(crt,"TopVent",(-.22+i*.04,.245,.608),(.021,.14,.003),ivory_shadow,.001)
for x in (-.305,-.275,-.245):
    cylinder(crt,"OSDButton",(x,-.156,.101),.008,.011,dark,8,"Y")
cylinder(crt,"PowerButton",(.301,-.16,.098),.015,.012,ivory_shadow,12,"Y")
cylinder(crt,"PowerLED",(.337,-.163,.096),.004,.004,led,8,"Y")
cube(crt,"RearServicePlate",(0,.432,.36),(.28,.006,.16),ivory_shadow,.007)

# Beige 1990s classroom keyboard, including staggered key rows and worn spacebar.
keyboard = collection("beige_keyboard")
loft(keyboard,"KeyboardWedge",[(-.10,.31,.014,.015),(.11,.31,.021,.028)],ivory)
cube(keyboard,"KeyWell",(0,-.014,.037),(.58,.173,.004),ivory_shadow,.004)
for row in range(4):
    y = -.079 + row*.041
    for col in range(14 if row < 3 else 12):
        x = -.269 + col*.039 + (row%2)*.009
        if row==3 and 4 <= col <= 8:
            continue
        cube(keyboard,"Keycap",(x,y,.047+row*.003),(.032,.031,.014),ivory_light,.002)
cube(keyboard,"WornSpacebar",(-.02,.045,.061),(.19,.032,.014),ivory_light,.003)
for i in range(5):
    cube(keyboard,"FunctionKey",(-.24+i*.07,-.126,.045),(.046,.019,.012),ivory_light,.002)
cube(keyboard,"KeyboardCableSocket",(.19,.114,.037),(.035,.017,.027),dark,.003)

mouse = collection("ball_mouse")
loft(mouse,"MouseShell",[(-.07,.049,.018,.026),(.07,.044,.023,.024)],ivory)
cube(mouse,"LeftButton",(-.025,-.047,.049),(.039,.05,.008),ivory_light,.003)
cube(mouse,"RightButton",(.025,-.047,.049),(.039,.05,.008),ivory_light,.003)
cube(mouse,"ButtonSeam",(0,-.048,.051),(.003,.048,.002),ivory_shadow,.001)
cube(mouse,"MouseCord",(0,-.11,.019),(.006,.07,.006),rubber,.001)

# Desk dimensions match existing Godot .78 m top and 2.45 x .84 m footprint.
desk = collection("school_computer_desk")
cube(desk,"DesktopCore",(0,0,.77),(2.45,.84,.065),wood,.012)
cube(desk,"FrontLaminateBand",(0,-.417,.77),(2.43,.018,.073),wood_edge,.003)
cube(desk,"RearLaminateBand",(0,.417,.77),(2.43,.018,.073),wood_edge,.003)
for side in (-1,1):
    cube(desk,"EndGrain",(side*1.22,0,.77),(.015,.83,.067),wood_dark,.002)
    for y in (-.32,.32):
        cube(desk,"SquareSteelLeg",(side*1.06,y,.378),(.050,.05,.756),steel,.004)
        cube(desk,"BlackFootCap",(side*1.06,y,.024),(.057,.057,.048),rubber,.002)
    cube(desk,"SideApron",(side*1.06,0,.689),(.035,.58,.11),wood_dark,.004)
cube(desk,"RearCrossbar",(0,.32,.36),(2.12,.04,.045),steel_edge,.003)
cube(desk,"FrontApron",(0,-.34,.683),(2.12,.034,.10),wood_dark,.003)
for i in range(5):
    # Thin gouges expose timber without relying on a photo texture.
    cube(desk,"DeskEdgeScratch",(-.71+i*.36,-.428,.803),(.075,.003,.002),wood_edge,.001)

chair = collection("school_computer_chair")
cube(chair,"SeatFrame",(0,0,.455),(.51,.45,.046),steel,.008)
cube(chair,"WornSeat",(0,-.006,.492),(.46,.40,.035),wood,.010)
cube(chair,"FrontSeatLip",(0,-.212,.488),(.45,.009,.032),wood_edge,.002)
for side in (-1,1):
    cube(chair,"RearLeg",(side*.205,.19,.53),(.037,.038,1.06),steel,.004)
    cube(chair,"FrontLeg",(side*.205,-.17,.235),(.037,.038,.47),steel,.004)
    cube(chair,"ChairFoot",(side*.205,-.17,.024),(.042,.045,.045),rubber,.002)
    cube(chair,"BackFoot",(side*.205,.19,.024),(.042,.045,.045),rubber,.002)
cube(chair,"CurvedBackPanel",(0,.19,.87),(.46,.045,.30),wood,.013)
cube(chair,"BackRestTopEdge",(0,.18,1.035),(.46,.03,.015),wood_edge,.004)
cube(chair,"LowBrace",(0,.19,.20),(.405,.030,.031),steel_edge,.002)

tower = collection("beige_pc_tower")
cube(tower,"CaseShell",(0,.02,.355),(.34,.58,.71),ivory,.012)
cube(tower,"FrontFace",(0,-.277,.356),(.322,.012,.684),ivory_light,.008)
for z in (.54,.61):
    cube(tower,"DriveBezel",(0,-.289,z),(.257,.005,.044),ivory_shadow,.003)
    cube(tower,"DriveSlot",(0,-.294,z),(.195,.002,.006),dark,.001)
cube(tower,"FloppyDriveSlot",(-.035,-.292,.43),(.19,.003,.012),dark,.001)
for i in range(5):
    cube(tower,"FrontIntake",(-.097+i*.049,-.293,.20),(.022,.002,.065),ivory_shadow,.001)
cylinder(tower,"TowerPowerButton",(.104,-.298,.09),.018,.008,ivory_shadow,12,"Y")
cylinder(tower,"TowerLED",(.054,-.299,.091),.005,.004,led,8,"Y")
for i in range(7):
    cube(tower,"SideVent",(.171,.09+i*.045,.47),(.003,.022,.09),ivory_shadow,.001)

# Distinct rear-right printer: low front paper slot, top tray, side seam, status lights.
printer = collection("dot_matrix_printer")
cube(printer,"BaseFeet",(0,.03,.022),(.58,.58,.044),dark,.008)
loft(printer,"TaperedPrinterCase",[(-.31,.35,.095,.21),(.30,.33,.15,.21)],ivory)
cube(printer,"FrontControlSlope",(0,-.315,.285),(.63,.06,.09),ivory_light,.008)
cube(printer,"OutputMouth",(0,-.347,.224),(.48,.005,.034),dark,.003)
cube(printer,"OutputPaper",(0,-.359,.199),(.39,.17,.008),paper,.002)
for i in range(6):
    cube(printer,"PrintedLine",(-.04,-.363-i*.017,.207),(.19,.002,.001),ink,.0004)
cube(printer,"TopRollerHousing",(0,.09,.365),(.53,.19,.11),ivory_shadow,.012)
cube(printer,"PaperFeedTray",(0,.22,.475),(.43,.025,.22),steel,.006)
cube(printer,"InputPaper",(0,.194,.49),(.36,.008,.20),paper,.002)
for x in (-.27,.27):
    cylinder(printer,"TractorKnob",(x,.16,.369),.032,.015,dark,12,"X")
for i in range(4):
    cylinder(printer,"FunctionButton",(.19-i*.06,-.35,.324),.012,.008,dark,8,"Y")
cylinder(printer,"PrinterStatusLED",(-.247,-.35,.324),.006,.004,led,8,"Y")

for c in (crt, keyboard, mouse, desk, chair, tower, printer):
    export(c)

# Save an editable, organized Blender source and archive it with this generator.
for c in (crt, keyboard, mouse, desk, chair, tower, printer):
    c.hide_render = False
    c.hide_viewport = False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "lab_props_source.blend"))
with ZipFile(OUT / "lab_props_source.zip", "w", ZIP_DEFLATED) as z:
    z.write(OUT / "lab_props_source.blend", "lab_props_source.blend")
    z.write(__file__, "generate_lab_props.py")

# Evidence render: models only, not a Godot runtime screenshot.
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.view_settings.exposure = -.9
scene.render.resolution_x = 1500
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world.color = (.075,.09,.10)
positions = {
    "school_computer_desk":(-1.65,.5,0),
    "school_computer_chair":(-1.65,-.65,0),
    "aged_crt_monitor":(-1.65,.35,.81),
    "beige_keyboard":(-1.65,-.05,.81),
    "ball_mouse":(-1.10,-.05,.81),
    "beige_pc_tower":(-.66,.44,0),
    "dot_matrix_printer":(1.35,.15,.0),
}
for c in (crt, keyboard, mouse, desk, chair, tower, printer):
    delta = Vector(positions[c.name])
    for o in c.objects:
        o.location += delta
floor = collection("PreviewOnly")
cube(floor,"PreviewFloor",(0,0,-.045),(7,4,.08),mat("PreviewFloor",(.09,.115,.115)),.01)
def area(name, loc, power, size, color):
    data = bpy.data.lights.new(name,"AREA")
    data.energy, data.shape, data.size, data.color = power,"DISK",size,color
    ob = bpy.data.objects.new(name,data)
    scene.collection.objects.link(ob)
    ob.location=loc
    ob.rotation_euler=(Vector((0,0,.45))-ob.location).to_track_quat("-Z","Y").to_euler()
area("ColdKey",(-2,-2.6,3.7),550,4,(.65,.78,1))
area("GreenCRTGlow",(-1.6,-.8,1.4),25,1,(.2,1,.55))
area("RimLight",(2,2,3.4),330,3,(.9,.88,.73))
bpy.ops.object.camera_add(location=(4,-5.5,3.25))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,.42))-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type="ORTHO"
cam.data.ortho_scale=5.8
scene.camera=cam
scene.render.filepath=str(PREV / "lab_props_overview.png")
bpy.ops.render.render(write_still=True)
print("LAB_PROPS_PASS", len(list(OUT.glob("*.glb"))), "GLBs", scene.render.filepath)
