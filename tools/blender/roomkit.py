"""Shared kit for building rooms of the house in Blender, at figure scale (real x 12).

Used by build_room.py (kids' room) and build_kitchen.py. All coordinates are
Godot space (Y up); g2b() converts.

What a room glTF carries (the contract with scripts/level/level.gd):
  * visual meshes, joined per furniture group, materials named by role
    (parquet, wood_light, tile_floor, ...) so Godot can swap in its own
  * collision boxes as separate objects "<name>-convcolonly"; Godot makes them
    StaticBody3D nodes. A name containing "_climb" marks a climbable surface.
  * empties used as markers: spawn_player, cam_intro_<n>, grapple_pull_<n>,
    grapple_swing_<n>, arena_<n> (+ arena_<n>_barrier_<k>, scaled to the block
    size, origin at the block base), checkpoint_<n>, star_<n>, goal (scaled box),
    hazard_water_<n> / hazard_hot_<n> (scaled boxes, origin at base centre)
  * window_l / window_r: casements with origins on their hinges (Godot swings them)
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

# Room builders author in "real size x 12" units (a 15 cm figure). The export
# scales the whole room by ROOM_SCALE so the figure is far smaller than the
# furniture: a chair seat is out of double-jump reach, a room takes minutes to cross.
ROOM_SCALE = 1.6

MATS = {
    "parquet": (0.62, 0.42, 0.25, 0.55), "wall": (0.86, 0.83, 0.74, 0.9), "ceiling": (0.95, 0.95, 0.93, 0.9),
    "baseboard": (0.95, 0.95, 0.93, 0.5), "wood_light": (0.78, 0.6, 0.4, 0.5), "wood_white": (0.92, 0.91, 0.88, 0.4),
    "wood_dark": (0.35, 0.22, 0.14, 0.5), "fabric_blanket": (0.25, 0.45, 0.75, 0.95), "fabric_sheet": (0.92, 0.92, 0.95, 0.95),
    "fabric_curtain": (0.85, 0.55, 0.3, 0.95), "fabric_shirt": (0.5, 0.65, 0.4, 0.95), "rug": (0.75, 0.3, 0.25, 1.0),
    "metal": (0.75, 0.75, 0.78, 0.3), "cardboard": (0.65, 0.5, 0.32, 0.9), "sill": (0.95, 0.95, 0.95, 0.3),
    "glass": (0.75, 0.88, 0.95, 0.05), "sky": (0.7, 0.85, 1.0, 1.0), "lampshade": (0.95, 0.9, 0.75, 0.8),
    "plastic_red": (0.85, 0.12, 0.1, 0.3), "plastic_blue": (0.1, 0.35, 0.85, 0.3), "plastic_yellow": (0.95, 0.75, 0.1, 0.3),
    "plastic_green": (0.15, 0.65, 0.25, 0.3), "plastic_grey": (0.55, 0.55, 0.58, 0.5), "book_a": (0.6, 0.15, 0.15, 0.7),
    "book_b": (0.15, 0.3, 0.55, 0.7), "book_c": (0.85, 0.7, 0.3, 0.7), "book_d": (0.2, 0.5, 0.35, 0.7),
    "pot": (0.75, 0.4, 0.25, 0.8), "leaf": (0.15, 0.45, 0.15, 0.6), "paper": (0.97, 0.97, 0.95, 0.9),
    "rope": (0.8, 0.75, 0.6, 0.9),
    "tile_floor": (0.85, 0.82, 0.76, 0.35), "tile_wall": (0.93, 0.95, 0.95, 0.2), "granite": (0.22, 0.22, 0.24, 0.25),
    "steel": (0.78, 0.79, 0.8, 0.25), "water": (0.3, 0.55, 0.75, 0.05), "hotplate": (0.08, 0.08, 0.08, 0.4),
    "hotplate_glow": (1.0, 0.25, 0.05, 0.4), "cabinet_mint": (0.6, 0.82, 0.72, 0.4), "ceramic": (0.95, 0.93, 0.88, 0.2),
    "cookie": (0.75, 0.5, 0.25, 0.8), "choc": (0.25, 0.13, 0.07, 0.6), "fruit_red": (0.8, 0.08, 0.06, 0.3),
    "fruit_yellow": (0.98, 0.85, 0.2, 0.4), "fruit_orange": (1.0, 0.5, 0.05, 0.5), "towel": (0.85, 0.25, 0.25, 0.95),
}


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def rot_b(deg):
    x, y, z = (math.radians(a) for a in deg)
    rg = Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z")
    return C @ rg @ C.transposed()


class Room:
    def __init__(self):
        self.mats = {}
        for name, (r, g, b, rough) in MATS.items():
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
            bsdf.inputs["Roughness"].default_value = rough
            if name == "metal":
                bsdf.inputs["Metallic"].default_value = 1.0
            if name in ("sky", "hotplate_glow"):
                bsdf.inputs["Emission Color"].default_value = (r, g, b, 1)
                bsdf.inputs["Emission Strength"].default_value = 3.0
            self.mats[name] = m
        self.groups = {}  # group -> [objects]
        self.group = "misc"
        self.ncol = 0

    # ------------------------------------------------------------ primitives
    def _finish(self, o, mat, bevel):
        o.data.materials.append(self.mats[mat])
        if bevel > 0:
            b = o.modifiers.new("bevel", "BEVEL")
            b.width = bevel
            b.segments = 2
            b.limit_method = "ANGLE"
            b.harden_normals = True
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        me.transform(o.matrix_world)
        for p in me.polygons:
            p.use_smooth = True
        baked = bpy.data.objects.new(o.name, me)
        bpy.context.collection.objects.link(baked)
        bpy.data.objects.remove(o, do_unlink=True)
        self.groups.setdefault(self.group, []).append(baked)
        return baked

    def collider(self, c, s, rot=(0, 0, 0), climb=False, name=None):
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        o.data.transform(Matrix.Diagonal((s[0], s[2], s[1], 1)))
        o.matrix_world = Matrix.Translation(g2b(c)) @ rot_b(rot).to_4x4()
        self.ncol += 1
        base = name or self.group
        o.name = "%s%s_%03d-convcolonly" % (base, "_climb" if climb else "", self.ncol)
        return o

    def box(self, c, s, mat, bevel=0.15, col=True, climb=False, rot=(0, 0, 0), taper=(1.0, 1.0)):
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        for v in o.data.vertices:
            if v.co.z < 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
        o.data.transform(Matrix.Diagonal((s[0], s[2], s[1], 1)))
        o.matrix_world = Matrix.Translation(g2b(c)) @ rot_b(rot).to_4x4()
        bpy.context.view_layer.update()
        self._finish(o, mat, min(bevel, min(s) * 0.45))
        if col:
            self.collider(c, s, rot, climb)

    def cyl(self, p0, p1, r0, r1, mat, sides=24, bevel=0.08, col=False):
        a, b = g2b(p0), g2b(p1)
        bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r0, radius2=r1, depth=(b - a).length)
        o = bpy.context.active_object
        o.matrix_world = Matrix.Translation((a + b) / 2) @ Vector((0, 0, 1)).rotation_difference(b - a).to_matrix().to_4x4()
        bpy.context.view_layer.update()
        self._finish(o, mat, bevel)
        if col:
            # an upright cylinder collides as its bounding box, which is what a figure expects to stand on
            lo = [min(p0[i], p1[i]) for i in range(3)]
            hi = [max(p0[i], p1[i]) for i in range(3)]
            r = max(r0, r1) * 0.9
            c = [(lo[i] + hi[i]) / 2 for i in range(3)]
            s = [hi[0] - lo[0] + 2 * r, hi[1] - lo[1], hi[2] - lo[2] + 2 * r]
            self.collider(c, s)

    def ball(self, c, r, mat, scale=(1, 1, 1), col=False):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=r)
        o = bpy.context.active_object
        o.data.transform(Matrix.Diagonal((scale[0], scale[2], scale[1], 1)))
        o.location = g2b(c)
        bpy.context.view_layer.update()
        self._finish(o, mat, 0)
        if col:
            self.collider(c, (2 * r * scale[0] * 0.85, 2 * r * scale[1] * 0.85, 2 * r * scale[2] * 0.85))

    def marker(self, name, c, size=(1, 1, 1)):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "CUBE"
        e.location = g2b(c)
        e.scale = (size[0], size[2], size[1])
        bpy.context.collection.objects.link(e)

    def join_groups(self, pivots):
        for name, objs in self.groups.items():
            with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs):
                bpy.ops.object.join()
            o = objs[0]
            o.name = o.data.name = name
            if name in pivots:
                p = g2b(pivots[name])
                o.data.transform(Matrix.Translation(-p))
                o.location = p


def finish(r, out, pivots=None, scale=ROOM_SCALE):
    """Join groups, scale the room up, sanity-check the markers, export the glb."""
    out = out if os.path.isabs(out) else os.path.join(ROOT, out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    r.join_groups(pivots or {})
    # bake the scale into meshes and positions: physics in Godot wants unscaled bodies
    grow = Matrix.Scale(scale, 4)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.data.transform(grow)
        o.location = o.location * scale
        if o.type == "EMPTY":
            o.scale = o.scale * scale
    bpy.context.view_layer.update()
    cols = [o for o in bpy.data.objects if o.name.endswith("-convcolonly")]
    marks = [o for o in bpy.data.objects if o.type == "EMPTY"]
    tris = sum(sum(len(f.vertices) - 2 for f in o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o not in cols)
    assert any(o.name == "spawn_player" for o in marks), "no spawn"
    assert any(o.name == "goal" for o in marks), "no goal"
    print("CHECK ok: %d groups, %d colliders, %d markers, %d tris" % (len(r.groups), len(cols), len(marks), tris))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False, export_extras=False)
    print("EXPORTED", out)


def out_path(default):
    """The output path from the command line (after --), and a fresh scene."""
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return args[0] if args else default
