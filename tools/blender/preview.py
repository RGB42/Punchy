"""Renders a quick look at a .glb from the front three-quarter and the back.

    "N:/Programme/Blender/blender.exe" --background --python tools/blender/preview.py -- \
        assets/models/figures/blaze.glb out.png [yaw_degrees]

For checking a scripted model by eye before it goes into the game.
"""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
yaw = math.radians(float(args[2])) if len(args) > 2 else math.radians(30)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
centre, size = (lo + hi) / 2, (hi - lo).length

bpy.ops.mesh.primitive_plane_add(size=size * 8, location=(centre.x, centre.y, lo.z))
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.5, 0.45, 1)
bpy.context.active_object.data.materials.append(gm)

# Godot -Z forward is Blender +Y after the glTF import: yaw 0 looks at the face.
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
bpy.context.collection.objects.link(cam)
d = size * 1.5
cam.location = centre + Vector((math.sin(yaw) * d, math.cos(yaw) * d, d * 0.25))
cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(150))
bpy.context.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA"))
fill.data.energy = 150.0 * size
fill.location = centre + Vector((-d, d * 0.6, d * 0.5))
fill.rotation_euler = (centre - fill.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.collection.objects.link(fill)

world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.8, 0.9, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
bpy.context.scene.world = world

scene = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
scene.render.resolution_x = 700
scene.render.resolution_y = 900
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
