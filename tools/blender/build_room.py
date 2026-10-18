"""Builds level 1, the kids' room, at figure scale (real size x 12).

    "N:/Programme/Blender/blender.exe" --background --python-exit-code 1 \
        --python tools/blender/build_room.py -- assets/models/rooms/kids_room.glb

Room: 54 x 54 x 30 (x -27..27, z -27..27, floor y 0). North wall (-z) has the
window, the goal. All coordinates are Godot space (Y up); g2b() converts.

What the glTF carries (the contract with scripts/level/room.gd):
  * visual meshes, joined per furniture group, materials named by role
    (parquet, wood_light, fabric_blanket, ...) so Godot can swap in its own
  * collision boxes as separate objects "<name>-convcolonly"; Godot makes them
    StaticBody3D nodes. A name containing "_climb" marks a climbable surface.
  * empties used as markers: spawn_player, cam_intro_<n>, grapple_pull_<n>,
    grapple_swing_<n>, arena_<n> (+ arena_<n>_barrier_<k>, scaled to the block
    size, origin at the block base), checkpoint_<n>, goal
  * window_l / window_r: the casements, origins on their hinges, so Godot can
    swing them open
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

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
            if name in ("sky",):
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


# ------------------------------------------------------------------ the room
def shell(r):
    r.group = "shell"
    r.box((0, -0.5, 0), (54, 1, 54), "parquet", 0)
    r.box((0, 30.5, 0), (54, 1, 54), "ceiling", 0)
    r.box((0, 15, 27.75), (57, 30, 1.5), "wall", 0)
    r.box((-27.75, 15, 0), (1.5, 30, 57), "wall", 0)
    r.box((27.75, 15, 0), (1.5, 30, 57), "wall", 0)
    # north wall around the window opening x[-6, 9.6] y[13.2, 27]
    r.box((-17.25, 15, -27.75), (22.5, 30, 1.5), "wall", 0)
    r.box((19.05, 15, -27.75), (18.9, 30, 1.5), "wall", 0)
    r.box((1.8, 6.6, -27.75), (15.6, 13.2, 1.5), "wall", 0)
    r.box((1.8, 28.5, -27.75), (15.6, 3, 1.5), "wall", 0)
    for c, s in (((0, 0.42, 26.88), (54, 0.84, 0.24)), ((-26.88, 0.42, 0), (0.24, 0.84, 54)),
                 ((26.88, 0.42, 0), (0.24, 0.84, 54)), ((-16.5, 0.42, -26.88), (21, 0.84, 0.24)),
                 ((18.3, 0.42, -26.88), (17.4, 0.84, 0.24)), ((1.8, 0.42, -26.88), (15.6, 0.84, 0.24))):
        r.box(c, s, "baseboard", 0.06, col=False)
    r.group = "door"  # decor: the door to the hallway, south wall
    r.box((2, 12.6, 26.85), (11, 25.2, 0.4), "wood_white", 0.1, col=False)
    r.box((-3.9, 12.6, 26.7), (0.9, 26, 0.6), "wood_white", 0.1, col=False)
    r.box((7.9, 12.6, 26.7), (0.9, 26, 0.6), "wood_white", 0.1, col=False)
    r.box((2, 25.6, 26.7), (12.7, 0.9, 0.6), "wood_white", 0.1, col=False)
    r.ball((-2.4, 12.6, 26.4), 0.45, "metal")


def window(r):
    r.group = "window_frame"
    r.box((1.8, 12.9, -26.1), (17.6, 0.6, 3.3), "sill", 0.1)  # top 13.2, front edge z -24.45
    for c, s in (((-5.7, 20.1, -28.0), (0.6, 13.8, 0.8)), ((9.3, 20.1, -28.0), (0.6, 13.8, 0.8)),
                 ((1.8, 26.7, -28.0), (15.6, 0.6, 0.8)), ((1.8, 13.5, -28.0), (15.6, 0.6, 0.8))):
        r.box(c, s, "wood_white", 0.08, col=False)
    r.group = "sky"
    r.box((1.8, 20, -42), (60, 40, 0.5), "sky", 0, col=False)
    for side, x0, x1 in (("l", -5.4, 1.8), ("r", 1.8, 9.0)):
        r.group = "window_" + side
        w = x1 - x0
        cx = (x0 + x1) / 2
        r.box((cx, 13.95, -28.0), (w, 0.9, 0.7), "wood_white", 0.08, col=False)
        r.box((cx, 26.25, -28.0), (w, 0.9, 0.7), "wood_white", 0.08, col=False)
        r.box((x0 + 0.45, 20.1, -28.0), (0.9, 13.2, 0.7), "wood_white", 0.08, col=False)
        r.box((x1 - 0.45, 20.1, -28.0), (0.9, 13.2, 0.7), "wood_white", 0.08, col=False)
        r.box((cx, 20.1, -28.0), (w - 1.6, 11.5, 0.12), "glass", 0, col=False)
        r.collider((cx, 20.1, -27.6), (w, 13.2, 0.6), name="window_glass_" + side)
    r.group = "window_r"
    r.box((7.9, 20, -27.45), (0.5, 2.4, 0.5), "metal", 0.1, col=False)  # handle
    r.marker("grapple_pull_window", (4.0, 14.0, -24.2))
    r.marker("goal", (1.8, 13.4, -27.0), (12, 6, 4))

    r.group = "curtains"
    r.cyl((-12.5, 28.6, -25.6), (16.2, 28.6, -25.6), 0.25, 0.25, "metal", 12)
    for x in (-12.6, 16.3):
        r.ball((x, 28.6, -25.6), 0.5, "metal")
    for x0, x1 in ((-11.2, -6.4), (10.2, 15.0)):
        n = 5
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            r.cyl((x, 0.4, -26.0 + 0.25 * (i % 2)), (x, 28.2, -26.0 + 0.25 * (i % 2)), 0.62, 0.58, "fabric_curtain", 12, 0)
        r.collider(((x0 + x1) / 2, 14.3, -26.0), (x1 - x0, 27.8, 1.3), climb=True, name="curtain")


def wardrobe(r):
    r.group = "wardrobe"
    W = "wood_white"
    r.box((20.5, 0.6, 23.7), (12.4, 1.2, 6.2), W, 0.1)
    r.box((20.5, 1.5, 23.4), (13, 0.6, 7.2), W, 0.1)
    r.box((14.3, 12, 23.4), (0.6, 24, 7.2), W, 0.1)
    r.box((26.7, 12, 23.4), (0.6, 24, 7.2), W, 0.1)
    r.box((20.5, 23.7, 23.4), (13, 0.6, 7.2), W, 0.12)
    r.box((20.5, 12, 26.85), (13, 24, 0.3), W, 0.05)
    r.box((20.5, 12.9, 23.55), (0.6, 21.6, 6.9), W, 0.08)
    r.box((17.4, 8.1, 23.55), (5.6, 0.6, 6.9), W, 0.08)
    r.box((17.4, 14.4, 23.55), (5.6, 0.6, 6.9), W, 0.08)
    r.cyl((20.8, 21, 23.2), (26.4, 21, 23.2), 0.18, 0.18, "metal", 12)
    for i, x in enumerate((21.8, 23.0, 24.2, 25.4)):
        r.box((x, 16.2, 23.2), (0.7, 9, 5.2), "fabric_shirt" if i % 2 else "fabric_curtain", 0.25, col=False)
    # doors: left wide open, right ajar
    r.box((12.69, 12.3, 16.74), (6.2, 22.2, 0.5), W, 0.12, rot=(0, 115, 0))
    r.box((24.23, 12.3, 17.95), (6.4, 22.2, 0.5), W, 0.12, rot=(0, -30, 0))
    r.ball((11.4, 12.3, 15.3), 0.4, "metal")
    # start compartment: a shoe box to hop over, socks
    r.box((17.2, 2.9, 25.2), (4.2, 2.2, 2.6), "cardboard", 0.08)
    r.ball((19.2, 2.4, 21.6), 0.6, "fabric_blanket", (1, 0.7, 1.2))
    r.marker("spawn_player", (17.4, 1.9, 22.4))
    r.marker("checkpoint_0", (17.4, 1.9, 22.4))


def rug_and_toys(r):
    r.group = "rug"
    r.box((0, 0.1, 6), (24, 0.2, 20), "rug", 0.08, col=False)
    r.collider((0, 0.05, 6), (24, 0.1, 20))
    r.box((0, 0.21, 6), (20, 0.02, 16), "fabric_sheet", 0, col=False)  # pattern border
    r.box((0, 0.22, 6), (19.2, 0.02, 15.2), "rug", 0, col=False)

    r.group = "castle"  # toy castle: cover and a perch in the first fight
    cx, cz = -7, 12
    r.box((cx, 1.8, cz), (7.2, 3.6, 7.2), "plastic_grey", 0.2)
    for dx in (-3.3, 3.3):
        for dz in (-3.3, 3.3):
            r.cyl((cx + dx, 0, cz + dz), (cx + dx, 6, cz + dz), 1.3, 1.3, "plastic_grey", 16, 0.1, col=True)
            r.cyl((cx + dx, 6, cz + dz), (cx + dx, 8.2, cz + dz), 1.5, 0.1, "plastic_red", 16, 0.05)
    for i in range(6):
        r.box((cx - 3.3 + 1.32 * i, 4.0, cz - 3.4), (0.7, 0.8, 0.5), "plastic_grey", 0.08, col=False)
    r.box((cx, 1.4, cz - 3.62), (2.4, 2.8, 0.1), "wood_dark", 0.05, col=False)

    r.group = "toys"
    blocks = [((9, 1.2, 1), "plastic_red"), ((11.6, 1.2, 1.4), "plastic_blue"), ((10.2, 3.6, 1.2), "plastic_yellow"),
              ((-3.5, 1.2, 18.0), "plastic_green"), ((-3.5, 3.6, 18.0), "plastic_red"), ((-1.0, 1.2, 18.6), "plastic_yellow")]
    for c, m in blocks:
        r.box(c, (2.4, 2.4, 2.4), m, 0.25)
    r.ball((14, 2.4, -3), 2.4, "plastic_yellow", col=True)
    # toy car
    r.box((3, 1.0, -1), (3.2, 1.2, 6), "plastic_red", 0.4)
    r.box((3, 2.0, -0.6), (2.8, 1.0, 3), "glass", 0.3, col=False)
    for dx in (-1.6, 1.6):
        for dz in (-2.0, 2.0):
            r.cyl((3 + dx * 0.9, 0.7, -1 + dz), (3 + dx * 1.1, 0.7, -1 + dz), 0.7, 0.7, "plastic_grey", 16, 0.05)
    r.collider((3, 1.1, -1), (3.6, 2.2, 6))
    # toy chest against the south wall
    r.group = "toybox"
    r.box((-7, 0.3, 24), (10, 0.6, 5.6), "wood_light", 0.1)
    for c, s in (((-7, 3, 21.4), (10, 6, 0.5)), ((-7, 3, 26.6), (10, 6, 0.5)), ((-11.8, 3, 24), (0.5, 6, 5.6)), ((-2.2, 3, 24), (0.5, 6, 5.6))):
        r.box(c, s, "wood_light", 0.1)
    r.box((-7, 7.6, 26.9), (10, 0.5, 5.6), "wood_light", 0.1, rot=(80, 0, 0))
    r.ball((-8.5, 4.6, 24), 1.8, "plastic_blue")
    r.box((-5, 4.2, 23.6), (2.4, 2.4, 2.4), "plastic_green", 0.25, col=False, rot=(20, 30, 10))
    r.marker("checkpoint_1", (6, 0.3, 14))
    r.marker("arena_1", (0, 0.1, 6), (22, 7, 18))
    for k, (c, s) in enumerate((((0, 0.1, -3.2), (24, 6, 1)), ((0, 0.1, 15.2), (24, 6, 1)),
                                ((-12.2, 0.1, 6), (1, 6, 19)), ((12.2, 0.1, 6), (1, 6, 19)))):
        r.marker("arena_1_barrier_%d" % k, c, s)


def loft_bed(r):
    r.group = "loft_bed"
    L = "wood_light"
    for x in (-26.4, -15.6):
        for z in (-1.4, 21.4):
            r.box((x, 12, z), (1.2, 24, 1.2), L, 0.15)
    r.box((-15.6, 17.7, 10), (1.2, 1.8, 24), L, 0.12)
    r.box((-26.4, 17.7, 10), (1.2, 1.8, 24), L, 0.12)
    r.box((-21, 17.4, 10), (10.8, 0.6, 22.8), L, 0.05)
    r.box((-21, 18.9, 10), (10.4, 2.4, 22.4), "fabric_sheet", 0.6)
    r.box((-21, 20.4, 12.5), (10.8, 0.7, 15), "fabric_blanket", 0.3)
    r.box((-15.35, 19.0, 12.5), (0.5, 3.4, 15), "fabric_blanket", 0.2, col=False)  # duvet hanging over the rail
    r.box((-21, 20.9, 2.2), (6.5, 1.4, 3.2), "fabric_sheet", 0.6)
    r.box((-21, 21, -1.4), (10.8, 6, 0.6), L, 0.12)
    r.box((-21, 21, 21.4), (10.8, 6, 0.6), L, 0.12)
    r.box((-15.6, 23.4, 6.8), (0.6, 0.6, 16.4), L, 0.1)
    r.box((-15.6, 23.4, 20.3), (0.6, 0.6, 2.2), L, 0.1)
    for z in range(1, 15, 2):
        r.box((-15.6, 21.6, z), (0.4, 3.4, 0.4), L, 0.08, col=False)
    # ladder (climbable) on the east side
    for z in (15.6, 19.2):
        r.box((-14.7, 10.5, z), (0.6, 21, 0.6), L, 0.1, col=False)
    for i in range(11):
        y = 1.6 + i * 1.8
        r.cyl((-14.7, y, 15.6), (-14.7, y, 19.2), 0.22, 0.22, L, 10, 0.03)
    r.collider((-14.7, 10.2, 17.4), (0.6, 20.4, 3.9), climb=True, name="ladder")
    # reading nook underneath
    r.ball((-21, 2.4, 12), 3.6, "fabric_curtain", (1.2, 0.65, 1.1), col=True)
    r.marker("checkpoint_2", (-17, 20.8, 17))
    r.marker("arena_2", (-21, 20.75, 10), (10, 7, 20))
    r.marker("arena_2_barrier_0", (-15.6, 20.75, 10), (0.8, 6, 23))


def hanging_plant(r):
    r.group = "hanging_plant"
    r.cyl((-20, 30, -10), (-20, 24.5, -10), 0.12, 0.12, "rope", 8, 0)
    r.cyl((-20, 22.0, -10), (-20, 24.6, -10), 1.6, 2.4, "pot", 20, 0.15)
    for i in range(7):
        a = i * 0.9
        r.ball((-20 + math.cos(a) * 2.2, 22.5 - (i % 3), -10 + math.sin(a) * 2.2), 1.3, "leaf", (1.4, 0.4, 0.9))
    r.marker("grapple_swing_plant", (-20, 28.4, -10))


def bookshelf(r):
    r.group = "bookshelf"
    W = "wood_white"
    x0, x1, z0, z1 = -26.4, -9.6, -27.0, -19.8
    cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    r.box((cx, 0.6, cz), (w, 1.2, d), W, 0.1)
    for y in (6.3, 11.4, 16.5):
        r.box((cx, y, cz), (w, 0.6, d), W, 0.1)
    r.box((cx, 21.3, cz), (w, 0.6, d), W, 0.12)
    r.box((x0 + 0.3, 10.8, cz), (0.6, 21.6, d), W, 0.1)
    r.box((x1 - 0.3, 10.8, cz), (0.6, 21.6, d), W, 0.1)
    r.box((cx, 10.8, z0 + 0.15), (w, 21.6, 0.3), W, 0.05)
    # book rows per compartment; every row is solid so the shelf front reads as ledges
    books = ["book_a", "book_b", "book_c", "book_d"]
    for row, (yb, yt) in enumerate(((1.2, 6.0), (6.6, 11.1), (11.7, 16.2), (16.8, 21.0))):
        x = x0 + 0.8
        i = row
        while x < x1 - 1.2:
            bw = 0.7 + 0.35 * ((i * 7) % 3)
            bh = (yt - yb) * (0.62 + 0.08 * ((i * 5) % 4))
            r.box((x + bw / 2, yb + bh / 2, cz + 0.4), (bw - 0.05, bh, d - 1.6), books[i % 4], 0.08, col=False)
            x += bw
            i += 1
        r.collider((cx, yb + (yt - yb) * 0.31, cz + 0.4), (w - 1.2, (yt - yb) * 0.62, d - 1.6))
    # protruding books: a staircase up the front, the way back if you fall
    for k, (bx, by) in enumerate(((-12.5, 1.2), (-16.5, 6.6), (-12.5, 11.7), (-16.5, 16.8))):
        r.box((bx, by + 1.2, z1 + 0.9), (2.2, 2.4, 3.6), books[(k + 2) % 4], 0.1)
    # shelf-top props
    r.cyl((-24.5, 21.6, -23.4), (-24.5, 23.4, -23.4), 1.2, 0.5, "metal", 16, 0.05, col=True)
    r.ball((-24.5, 26, -23.4), 2.6, "plastic_blue")
    r.collider((-24.5, 26, -23.4), (4.4, 4.4, 4.4))
    r.marker("checkpoint_3", (-16, 21.7, -22.5))
    r.marker("arena_3", (-16, 21.6, -23.4), (13, 7, 6.6))


def ceiling_lamp(r):
    r.group = "ceiling_lamp"
    r.cyl((2, 30, -12), (2, 24.6, -12), 0.12, 0.12, "rope", 8, 0)
    r.cyl((2, 21.6, -12), (2, 24.6, -12), 3.2, 0.8, "lampshade", 28, 0.1)
    r.marker("grapple_swing_lamp", (2, 27.2, -12))
    r.group = "mobile"
    r.cyl((13, 30, -15), (13, 26.5, -15), 0.08, 0.08, "rope", 6, 0)
    r.cyl((10, 26.5, -15), (16, 26.5, -15), 0.12, 0.12, "wood_light", 8, 0)
    for x, m in ((10, "plastic_red"), (16, "plastic_yellow")):
        r.cyl((x, 26.5, -15), (x, 24.6, -15), 0.05, 0.05, "rope", 6, 0)
        r.box((x, 24.0, -15), (2.2, 0.6, 0.8), m, 0.2, col=False)
        r.box((x, 24.0, -15), (0.5, 0.15, 2.4), m, 0.05, col=False)
    r.marker("grapple_swing_mobile", (13, 26.3, -15))


def desk(r):
    r.group = "desk"
    L = "wood_light"
    r.box((22.2, 8.7, -16.8), (9.6, 0.6, 19.2), L, 0.15)
    r.box((22.2, 4.2, -22.8), (9.0, 8.4, 6.6), L, 0.12)
    for i, y in enumerate((1.6, 4.4, 7.0)):
        r.box((17.65, y, -22.8), (0.2, 2.2, 6.2), "wood_white", 0.08, col=False)
        r.box((17.4, y, -22.8), (0.3, 0.4, 1.6), "metal", 0.08, col=False)
    r.box((22.2, 4.2, -7.8), (9.0, 8.4, 0.8), L, 0.1)
    # hutch along the wall: a high perch
    r.box((25.8, 13.5, -16.8), (2.4, 9, 0.6), L, 0.08)
    r.box((25.8, 13.5, -8.0), (2.4, 9, 0.6), L, 0.08)
    r.box((25.8, 13.5, -25.6), (2.4, 9, 0.6), L, 0.08)
    r.box((25.8, 17.7, -16.8), (2.4, 0.6, 18.2), L, 0.1)
    r.box((25.8, 13.5, -16.8), (2.4, 0.5, 18.2), L, 0.08)
    # props
    r.box((19.4, 10.2, -11.5), (3.4, 2.4, 4.6), "book_b", 0.15)
    r.box((19.2, 11.9, -11.8), (3.0, 1.0, 4.2), "book_c", 0.12)
    r.cyl((19.6, 9.0, -8.8), (19.6, 13.5, -8.8), 1.1, 1.1, "plastic_red", 20, 0.1, col=True)
    for dx, dz, m in ((0.3, 0.2, "plastic_yellow"), (-0.4, 0.3, "plastic_blue"), (0.1, -0.4, "plastic_green")):
        r.cyl((19.6 + dx, 13.5, -8.8 + dz), (19.6 + dx * 2, 18, -8.8 + dz * 2), 0.25, 0.15, m, 8, 0)
    r.box((21.0, 9.25, -18.5), (6.2, 0.5, 4.6), "plastic_grey", 0.15)
    r.box((23.5, 9.1, -14.0), (3.0, 0.2, 4.0), "paper", 0.02, col=False)
    # desk lamp
    r.cyl((20.4, 9.0, -24.6), (20.4, 9.5, -24.6), 1.4, 1.4, "metal", 20, 0.05)
    r.cyl((20.4, 9.5, -24.6), (20.4, 15.5, -23.2), 0.18, 0.18, "metal", 10, 0)
    r.cyl((20.4, 15.5, -23.2), (19.6, 15.2, -19.5), 0.18, 0.18, "metal", 10, 0)
    r.cyl((19.6, 14.8, -19.2), (19.4, 13.6, -18.4), 0.5, 1.6, "plastic_yellow", 20, 0.05)
    # chair: a step up from the floor
    r.group = "chair"
    r.box((13.2, 5.1, -15), (5.4, 0.6, 5.4), L, 0.15)
    r.box((10.8, 9.6, -15), (0.6, 8.4, 5.4), L, 0.15)
    for dx in (-2.4, 2.4):
        for dz in (-2.4, 2.4):
            r.box((13.2 + dx, 2.4, -15 + dz), (0.5, 4.8, 0.5), L, 0.08, col=False)
    r.marker("checkpoint_4", (21, 9.1, -9.5))
    r.marker("arena_4", (22.2, 9.0, -16.8), (8.8, 7, 18))


def stars(r):
    # optional collectibles, each a short detour off the main route
    for i, c in enumerate(((17.4, 9.6, 23.8), (-3.7, 7.2, 8.7), (-24.5, 1.2, 19.5), (-7.0, 1.6, 24.0), (25.8, 19.4, -21.0))):
        r.marker("star_%d" % i, c)


def intro_camera(r):
    # fly-through: from the wardrobe up over the room to the window, then back
    for i, c in enumerate(((12, 8, 24), (4, 20, 18), (-6, 26, 4), (0, 22, -14), (10, 14, -8), (17.4, 5, 15))):
        r.marker("cam_intro_%d" % i, c)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if args else os.path.join("assets", "models", "rooms", "kids_room.glb")
    out = out if os.path.isabs(out) else os.path.join(ROOT, out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    r = Room()
    shell(r)
    window(r)
    wardrobe(r)
    rug_and_toys(r)
    loft_bed(r)
    hanging_plant(r)
    bookshelf(r)
    ceiling_lamp(r)
    desk(r)
    stars(r)
    intro_camera(r)
    r.join_groups({"window_l": (-5.4, 13.2, -28.0), "window_r": (9.0, 13.2, -28.0)})
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


main()
