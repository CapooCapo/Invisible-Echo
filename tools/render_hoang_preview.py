"""Render a local inspection still: blender -b builds/visual-qa/hoang.blend --python tools/render_hoang_preview.py"""
import bpy
from mathutils import Vector
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "builds" / "visual-qa"
out.mkdir(parents=True, exist_ok=True)

bpy.ops.object.camera_add(location=(2.3, -4.2, 2.15))
camera = bpy.context.object
direction = Vector((0, 0, .88)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.2
bpy.context.scene.camera = camera

for name, position, power, size in (
    ("Key", (1.0, -2.8, 3.6), 570, 3.0),
    ("Fill", (-2.4, -1.0, 1.8), 260, 2.5),
    ("Rim", (0.5, 2.0, 2.8), 700, 2.0),
):
    bpy.ops.object.light_add(type="AREA", location=position)
    light = bpy.context.object
    light.name = name
    light.data.energy = power
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (Vector((0,0,.9)) - light.location).to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -1.0
scene.world.color = (.11,.12,.14)
scene.render.resolution_x = 640
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.filepath = str(out / "hoang_blender_preview.png")
bpy.ops.render.render(write_still=True)
print("HOANG_PREVIEW_OK", scene.render.filepath)
