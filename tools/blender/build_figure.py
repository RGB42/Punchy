"""Builds an action figure from rigid plastic parts, one object per joint.

    "N:/Programme/Blender/blender.exe" --background --python-exit-code 1 \
        --python tools/blender/build_figure.py -- blaze assets/models/figures/blaze.glb

Each part's origin sits on its joint and carries no rotation, so in Godot every
part is a Node3D whose `rotation` is the joint angle â€” exactly how a real action
figure works, and no skinning to go wrong. Godot is Y-up and the figure faces -Z;
every point goes through g2b(). Part names are the contract with
scripts/anim/figure_animator.gd.

Materials are named by role (primary, secondary, accent, joint, glow, metal) so
Godot can recolour one body into seven heroes and their enemies.
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HEIGHT = 1.8
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Godot -> Blender basis

PALETTES = {
    "blaze": {"primary": (0.85, 0.16, 0.05), "secondary": (0.12, 0.1, 0.1), "accent": (1.0, 0.5, 0.05),
              "joint": (0.2, 0.18, 0.18), "glow": (1.0, 0.85, 0.2), "metal": (0.9, 0.7, 0.3)},
    "knight": {"primary": (0.55, 0.58, 0.62), "secondary": (0.25, 0.2, 0.35), "accent": (0.75, 0.6, 0.2),
               "joint": (0.15, 0.15, 0.17), "glow": (0.9, 0.2, 0.15), "metal": (0.75, 0.77, 0.8)},
    "king": {"primary": (0.22, 0.22, 0.27), "secondary": (0.45, 0.07, 0.1), "accent": (0.92, 0.7, 0.18),
             "joint": (0.08, 0.08, 0.1), "glow": (1.0, 0.4, 0.1), "metal": (0.55, 0.56, 0.6)},
    "doll": {"primary": (0.95, 0.5, 0.68), "secondary": (0.96, 0.94, 0.92), "accent": (0.98, 0.8, 0.35),
             "joint": (0.97, 0.8, 0.7), "glow": (0.2, 0.95, 1.0), "metal": (0.6, 0.08, 0.15)},
    "soldier": {"primary": (0.13, 0.24, 0.66), "secondary": (0.06, 0.06, 0.08), "accent": (0.85, 0.12, 0.1),
                "joint": (0.97, 0.8, 0.7), "glow": (1.0, 0.85, 0.35), "metal": (0.85, 0.68, 0.28),
                "white": (0.95, 0.95, 0.93), "wood": (0.45, 0.27, 0.14)},
}

# Joint pivots in Godot space; parent first. The contract with figure_animator.gd.
PARTS = [
    ("hips", None, (0, 1.0, 0)),
    ("abdomen", "hips", (0, 1.08, 0)),
    ("chest", "abdomen", (0, 1.25, 0)),
    ("head", "chest", (0, 1.55, 0)),
]
for _s, _x in (("l", -1), ("r", 1)):
    PARTS += [
        ("upper_arm_" + _s, "chest", (0.25 * _x, 1.46, 0)),
        ("lower_arm_" + _s, "upper_arm_" + _s, (0.25 * _x, 1.18, 0)),
        ("hand_" + _s, "lower_arm_" + _s, (0.25 * _x, 0.95, 0)),
        ("thigh_" + _s, "hips", (0.11 * _x, 0.95, 0)),
        ("shin_" + _s, "thigh_" + _s, (0.115 * _x, 0.54, 0)),
        ("foot_" + _s, "shin_" + _s, (0.115 * _x, 0.1, 0)),
    ]

# Props that ride on a joint: (name, parent part, pivot). Godot can hide them.
EXTRAS = {
    "knight": [("sword", "hand_r", (0.25, 0.88, 0)), ("shield", "lower_arm_l", (-0.25, 1.06, 0))],
    "king": [("sword", "hand_r", (0.25, 0.88, 0)), ("shield", "lower_arm_l", (-0.25, 1.06, 0))],
    "soldier": [("rifle", "hand_r", (0.25, 0.88, 0))],
}


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def rot_b(deg):
    """Godot euler degrees (YXZ, like Node3D.rotation_degrees) as a Blender 3x3."""
    x, y, z = (math.radians(a) for a in deg)
    rg = Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z")
    return C @ rg @ C.transposed()


class Builder:
    def __init__(self, palette):
        self.mats = {}
        for name, col in palette.items():
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (*col, 1)
            bsdf.inputs["Roughness"].default_value = 0.35 if name != "joint" else 0.6
            if name == "metal":
                bsdf.inputs["Metallic"].default_value = 1.0
            if name == "glow":
                bsdf.inputs["Emission Color"].default_value = (*col, 1)
                bsdf.inputs["Emission Strength"].default_value = 4.0
            self.mats[name] = m
        self.pieces = {}  # part name -> [objects]
        self.part = None

    def _add(self, obj, mat, bevel=0.0, segments=3):
        obj.data.materials.append(self.mats[mat])
        if bevel > 0:
            b = obj.modifiers.new("bevel", "BEVEL")
            b.width = bevel
            b.segments = segments
            b.limit_method = "ANGLE"
            b.harden_normals = True
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        me.transform(obj.matrix_world)
        for p in me.polygons:
            p.use_smooth = True
        baked = bpy.data.objects.new(obj.name, me)
        bpy.context.collection.objects.link(baked)
        bpy.data.objects.remove(obj, do_unlink=True)
        self.pieces.setdefault(self.part, []).append(baked)
        return baked

    def box(self, center, size, mat, bevel=0.02, rot=(0, 0, 0), taper=(1.0, 1.0)):
        """taper scales the bottom face (width, depth): a V-shaped torso is a box
        with taper < 1."""
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        for v in o.data.vertices:
            if v.co.z < 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
        # Scale lives in the mesh, not the object, so the bevel stays round.
        o.data.transform(Matrix.Diagonal((size[0], size[2], size[1], 1)))
        o.matrix_world = Matrix.Translation(g2b(center)) @ rot_b(rot).to_4x4()
        bpy.context.view_layer.update()
        return self._add(o, mat, min(bevel, min(size) * 0.49))

    def limb(self, p0, p1, r0, r1, mat, bevel=0.015, sides=20):
        a, b = g2b(p0), g2b(p1)
        bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r0, radius2=r1, depth=(b - a).length)
        o = bpy.context.active_object
        o.matrix_world = Matrix.Translation((a + b) / 2) @ Vector((0, 0, 1)).rotation_difference(b - a).to_matrix().to_4x4()
        bpy.context.view_layer.update()
        return self._add(o, mat, bevel)

    def ball(self, center, r, mat, scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=r)
        o = bpy.context.active_object
        o.data.transform(Matrix.Diagonal((scale[0], scale[2], scale[1], 1)))
        o.location = g2b(center)
        bpy.context.view_layer.update()
        return self._add(o, mat)

    def assemble(self, parts):
        objs = {}
        for name, parent, pivot in parts:
            pieces = self.pieces[name]
            with bpy.context.temp_override(active_object=pieces[0], selected_editable_objects=pieces):
                bpy.ops.object.join()
            o = pieces[0]
            o.name = o.data.name = name
            o.data.transform(Matrix.Translation(-g2b(pivot)))
            o.location = g2b(pivot)
            objs[name] = o
        for name, parent, pivot in parts:
            if parent:
                o = objs[name]
                o.parent = objs[parent]
                o.matrix_parent_inverse = Matrix.Identity(4)
                o.location = g2b(pivot) - g2b(dict((n, p) for n, _, p in parts)[parent])
        bpy.context.view_layer.update()
        return objs


def build_body(b, variant):
    """The shared heroic body. Variants dress it in different armour."""
    hero = variant == "blaze"
    b.part = "hips"
    b.box((0, 0.99, 0), (0.3, 0.17, 0.2), "secondary", 0.04, taper=(0.75, 0.9))
    b.box((0, 1.065, 0), (0.33, 0.06, 0.22), "metal", 0.015)
    b.box((0, 1.065, -0.115), (0.1, 0.08, 0.035), "accent", 0.01)

    b.part = "abdomen"
    b.box((0, 1.165, 0), (0.25, 0.17, 0.18), "secondary", 0.05, taper=(0.9, 0.95))
    for sx in (-1, 1):
        for y in (1.13, 1.2):
            b.box((0.05 * sx, y, -0.085), (0.08, 0.05, 0.03), "joint", 0.012)

    b.part = "chest"
    b.box((0, 1.385, 0.005), (0.5, 0.29, 0.26), "primary", 0.06, taper=(0.6, 0.85))
    for sx in (-1, 1):  # pecs
        b.box((0.095 * sx, 1.41, -0.115), (0.17, 0.15, 0.06), "accent" if hero else "primary", 0.03,
              rot=(0, 0, 8 * sx), taper=(0.8, 1.0))
    b.box((0, 1.38, -0.15), (0.08, 0.08, 0.03), "glow", 0.01, rot=(0, 0, 45))
    b.limb((0, 1.5, 0), (0, 1.58, 0), 0.065, 0.055, "joint")
    b.box((0, 1.41, 0.135), (0.3, 0.2, 0.05), "secondary", 0.02, taper=(0.8, 1.0))
    if hero:  # thruster pack: the fire dash comes out of these
        for sx in (-1, 1):
            b.limb((0.08 * sx, 1.47, 0.16), (0.08 * sx, 1.3, 0.2), 0.045, 0.055, "metal", 0.01)
            b.limb((0.08 * sx, 1.3, 0.2), (0.08 * sx, 1.28, 0.205), 0.042, 0.042, "glow", 0.005)

    b.part = "head"
    if hero:
        b.box((0, 1.67, 0.0), (0.21, 0.24, 0.23), "primary", 0.09, taper=(0.85, 1.0))
        b.box((0, 1.67, -0.105), (0.17, 0.045, 0.04), "glow", 0.015, taper=(0.8, 1.0))
        b.box((0, 1.6, -0.08), (0.12, 0.075, 0.08), "joint", 0.03, taper=(0.75, 1.0))
        # flame crest: three fins sweeping back
        for z, h, tilt in ((-0.06, 0.13, -35), (0.01, 0.16, -15), (0.08, 0.11, 10)):
            b.box((0, 1.75 + h * 0.25, z), (0.03, h, 0.07), "accent", 0.012, rot=(tilt, 0, 0), taper=(1.6, 1.4))
        for sx in (-1, 1):
            b.box((0.11 * sx, 1.71, 0.03), (0.02, 0.06, 0.13), "accent", 0.008, rot=(-25, 0, 0))
    else:
        b.box((0, 1.67, 0.0), (0.21, 0.24, 0.23), "primary", 0.07)
        b.box((0, 1.67, -0.112), (0.15, 0.022, 0.02), "glow", 0.006)
        for i in range(4):
            b.box((0, 1.62 - i * 0.022, -0.116), (0.12, 0.01, 0.015), "joint", 0.003)
        b.box((0, 1.81, 0.02), (0.03, 0.06, 0.2), "secondary", 0.012)

    for s, sx in (("l", -1), ("r", 1)):
        b.part = "upper_arm_" + s
        b.ball((0.25 * sx, 1.46, 0), 0.085, "joint")
        b.box((0.28 * sx, 1.5, 0), (0.2, 0.1, 0.23), "primary" if hero else "metal", 0.04, rot=(0, 0, -22 * sx))
        b.box((0.32 * sx, 1.44, 0), (0.11, 0.08, 0.2), "accent" if hero else "metal", 0.03, rot=(0, 0, -40 * sx))
        b.limb((0.25 * sx, 1.42, 0), (0.25 * sx, 1.2, 0), 0.066, 0.056, "primary" if hero else "secondary")

        b.part = "lower_arm_" + s
        b.ball((0.25 * sx, 1.18, 0), 0.055, "joint")
        b.limb((0.25 * sx, 1.16, 0), (0.25 * sx, 0.98, 0), 0.058, 0.072, "accent" if hero else "metal")
        b.limb((0.25 * sx, 1.0, 0), (0.25 * sx, 0.965, 0), 0.078, 0.078, "metal", 0.008)

        b.part = "hand_" + s
        b.ball((0.25 * sx, 0.95, 0), 0.04, "joint")
        b.box((0.25 * sx, 0.885, -0.005), (0.095, 0.11, 0.11), "secondary", 0.035)
        b.box((0.25 * sx, 0.87, -0.065), (0.085, 0.06, 0.04), "joint", 0.015)
        b.box((0.25 * sx - 0.045 * sx, 0.89, -0.03), (0.03, 0.05, 0.06), "joint", 0.01)

        b.part = "thigh_" + s
        b.ball((0.11 * sx, 0.95, 0), 0.08, "joint")
        b.limb((0.11 * sx, 0.93, 0), (0.115 * sx, 0.58, 0), 0.088, 0.068, "secondary")
        b.box((0.13 * sx, 0.84, -0.02), (0.07, 0.16, 0.15), "primary" if hero else "metal", 0.025)

        b.part = "shin_" + s
        b.ball((0.115 * sx, 0.54, 0), 0.06, "joint")
        b.box((0.115 * sx, 0.545, -0.065), (0.11, 0.11, 0.06), "accent" if hero else "metal", 0.02)
        b.limb((0.115 * sx, 0.52, 0), (0.115 * sx, 0.13, 0), 0.066, 0.078, "primary" if hero else "metal")

        b.part = "foot_" + s
        b.ball((0.115 * sx, 0.1, 0), 0.05, "joint")
        b.box((0.115 * sx, 0.05, -0.04), (0.13, 0.1, 0.27), "secondary", 0.035)
        b.box((0.115 * sx, 0.105, -0.12), (0.11, 0.03, 0.08), "primary" if hero else "metal", 0.012)


def build_knight_gear(b):
    """Toy sword in the right fist (blade forward along -Z), kite shield strapped
    in front of the left forearm."""
    b.part = "sword"
    b.box((0.25, 0.88, -0.02), (0.04, 0.12, 0.05), "secondary", 0.01)  # grip
    b.box((0.25, 0.88, -0.1), (0.2, 0.04, 0.05), "accent", 0.012)  # crossguard
    b.box((0.25, 0.88, -0.48), (0.075, 0.025, 0.72), "metal", 0.01, taper=(1.0, 1.0))  # blade
    b.box((0.25, 0.88, -0.86), (0.045, 0.02, 0.08), "metal", 0.008)
    b.ball((0.25, 0.88, 0.05), 0.035, "accent")  # pommel
    b.part = "shield"
    b.box((-0.27, 1.05, -0.12), (0.36, 0.46, 0.05), "primary", 0.04, taper=(0.35, 1.0))
    b.box((-0.27, 1.06, -0.15), (0.3, 0.38, 0.02), "secondary", 0.03, taper=(0.3, 1.0))
    b.box((-0.27, 1.1, -0.165), (0.06, 0.22, 0.015), "accent", 0.005)
    b.box((-0.27, 1.12, -0.165), (0.18, 0.05, 0.015), "accent", 0.005)

def build_crown(b):
    b.part = "head"
    for i in range(8):
        a = i * math.tau / 8
        x, z = math.sin(a) * 0.105, math.cos(a) * 0.105
        b.box((x, 1.81, z), (0.05, 0.08, 0.03), "accent", 0.01, rot=(0, math.degrees(a), 0), taper=(1.0, 1.0))
    b.limb((0, 1.77, 0), (0, 1.8, 0), 0.12, 0.12, "accent", 0.01)
    for i in range(4):
        a = i * math.tau / 4
        b.ball((math.sin(a) * 0.12, 1.785, math.cos(a) * 0.12), 0.018, "glow")
    for sx in (-1, 1):  # shoulder spikes
        b.part = "upper_arm_" + ("l" if sx < 0 else "r")
        b.limb((0.3 * sx, 1.54, 0), (0.36 * sx, 1.66, 0), 0.04, 0.005, "accent", 0.005)


def build_doll(b):
    """A porcelain-faced doll: bell skirt, big head, pigtails, glowing eyes."""
    b.part = "hips"
    b.limb((0, 1.08, 0), (0, 0.7, 0), 0.15, 0.34, "primary", 0.03, sides=24)
    b.limb((0, 0.725, 0), (0, 0.7, 0), 0.355, 0.355, "secondary", 0.01, sides=24)
    b.part = "abdomen"
    b.box((0, 1.165, 0), (0.2, 0.17, 0.15), "primary", 0.05)
    b.box((0, 1.24, -0.08), (0.12, 0.06, 0.04), "secondary", 0.02)
    b.part = "chest"
    b.box((0, 1.38, 0), (0.32, 0.26, 0.2), "primary", 0.07, taper=(0.75, 0.9))
    b.box((0, 1.49, -0.02), (0.26, 0.05, 0.18), "secondary", 0.02)
    b.limb((0, 1.5, 0), (0, 1.58, 0), 0.045, 0.04, "joint")
    b.part = "head"
    b.ball((0, 1.68, 0), 0.155, "joint")
    b.ball((0, 1.715, 0.025), 0.165, "accent", (1.05, 0.88, 1.05))
    b.box((0, 1.69, -0.135), (0.22, 0.06, 0.06), "accent", 0.02)
    for sx in (-1, 1):
        b.ball((0.175 * sx, 1.64, 0.04), 0.06, "accent", (0.9, 1.4, 0.9))
        b.box((0.055 * sx, 1.675, -0.148), (0.045, 0.045, 0.02), "glow", 0.01)
        b.ball((0.085 * sx, 1.62, -0.13), 0.025, "primary")
    b.box((0, 1.6, -0.15), (0.04, 0.012, 0.01), "metal", 0.003)
    for s, sx in (("l", -1), ("r", 1)):
        b.part = "upper_arm_" + s
        b.ball((0.23 * sx, 1.45, 0), 0.085, "primary")
        b.limb((0.24 * sx, 1.42, 0), (0.25 * sx, 1.2, 0), 0.042, 0.038, "joint")
        b.part = "lower_arm_" + s
        b.limb((0.25 * sx, 1.18, 0), (0.25 * sx, 0.97, 0), 0.037, 0.032, "joint")
        b.part = "hand_" + s
        b.ball((0.25 * sx, 0.92, -0.005), 0.042, "joint")
        b.part = "thigh_" + s
        b.limb((0.1 * sx, 0.93, 0), (0.11 * sx, 0.56, 0), 0.06, 0.05, "joint")
        b.part = "shin_" + s
        b.limb((0.11 * sx, 0.54, 0), (0.115 * sx, 0.12, 0), 0.05, 0.045, "secondary")
        b.part = "foot_" + s
        b.box((0.115 * sx, 0.05, -0.04), (0.1, 0.1, 0.2), "metal", 0.04)


def build_soldier(b):
    """A tin soldier: blue coat, white cross belts, black shako with a red
    plume, rosy cheeks, moustache."""
    b.part = "hips"
    b.box((0, 0.98, 0), (0.3, 0.2, 0.2), "primary", 0.04, taper=(0.85, 0.9))
    b.box((0, 1.06, 0), (0.32, 0.05, 0.22), "white", 0.01)
    b.part = "abdomen"
    b.box((0, 1.165, 0), (0.26, 0.17, 0.19), "primary", 0.05)
    b.part = "chest"
    b.box((0, 1.38, 0), (0.42, 0.28, 0.24), "primary", 0.06, taper=(0.75, 0.9))
    for zrot in (35, -35):
        b.box((0, 1.33, -0.123), (0.05, 0.42, 0.015), "white", 0.005, rot=(0, 0, zrot))
    for y in (1.26, 1.33, 1.4, 1.47):
        b.ball((0.07, y, -0.12), 0.015, "metal")
    b.box((0, 1.48, -0.05), (0.2, 0.05, 0.16), "accent", 0.02)
    b.limb((0, 1.5, 0), (0, 1.58, 0), 0.05, 0.045, "joint")
    b.part = "head"
    b.box((0, 1.64, 0), (0.17, 0.18, 0.17), "joint", 0.07)
    b.box((0, 1.77, 0), (0.17, 0.16, 0.17), "secondary", 0.03, taper=(1.12, 1.12))
    b.box((0, 1.705, -0.07), (0.18, 0.025, 0.08), "secondary", 0.01)
    b.ball((0, 1.865, -0.06), 0.035, "accent", (1.0, 1.4, 1.0))
    b.box((0, 1.77, -0.087), (0.04, 0.05, 0.01), "metal", 0.005)
    b.box((0, 1.61, -0.09), (0.08, 0.018, 0.015), "secondary", 0.006)
    for sx in (-1, 1):
        b.box((0.035 * sx, 1.655, -0.088), (0.022, 0.022, 0.01), "secondary", 0.005)
        b.ball((0.06 * sx, 1.625, -0.082), 0.02, "accent")
    for s, sx in (("l", -1), ("r", 1)):
        b.part = "upper_arm_" + s
        b.ball((0.24 * sx, 1.46, 0), 0.07, "primary")
        b.box((0.26 * sx, 1.51, 0), (0.12, 0.04, 0.14), "metal", 0.015)
        b.limb((0.25 * sx, 1.42, 0), (0.25 * sx, 1.2, 0), 0.058, 0.05, "primary")
        b.part = "lower_arm_" + s
        b.limb((0.25 * sx, 1.17, 0), (0.25 * sx, 0.97, 0), 0.05, 0.05, "primary")
        b.limb((0.25 * sx, 0.99, 0), (0.25 * sx, 0.96, 0), 0.056, 0.056, "accent", 0.008)
        b.part = "hand_" + s
        b.ball((0.25 * sx, 0.91, -0.005), 0.045, "white")
        b.part = "thigh_" + s
        b.limb((0.1 * sx, 0.93, 0), (0.11 * sx, 0.56, 0), 0.075, 0.062, "white")
        b.part = "shin_" + s
        b.limb((0.11 * sx, 0.55, 0), (0.115 * sx, 0.11, 0), 0.068, 0.07, "secondary")
        b.part = "foot_" + s
        b.box((0.115 * sx, 0.05, -0.04), (0.12, 0.1, 0.24), "secondary", 0.035)
    b.part = "rifle"
    b.box((0.25, 0.87, 0.06), (0.05, 0.08, 0.22), "wood", 0.015)
    b.box((0.25, 0.88, -0.2), (0.045, 0.05, 0.36), "wood", 0.012)
    b.limb((0.25, 0.9, -0.1), (0.25, 0.9, -0.62), 0.016, 0.014, "metal", 0.004, sides=10)
    b.limb((0.25, 0.9, -0.62), (0.25, 0.9, -0.78), 0.008, 0.002, "white", 0.002, sides=8)


def check(objs, parts):
    names = {n for n, _, _ in parts}
    assert set(objs) == names, "parts differ: %s" % sorted(set(objs) ^ names)
    zs, tris = [], 0
    for o in objs.values():
        tris += sum(len(f.vertices) - 2 for f in o.data.polygons)
        zs += [(o.matrix_world @ v.co).z for v in o.data.vertices]
        assert o.rotation_euler.to_matrix() == Matrix.Identity(3), "%s carries a rotation" % o.name
    h = max(zs) - min(zs)
    assert abs(min(zs)) < 0.01, "feet at %.3f, not 0" % min(zs)
    assert abs(h - HEIGHT) < 0.15, "figure is %.3f tall, not %.2f" % (h, HEIGHT)
    assert tris < 25000, "too many triangles: %d" % tris
    print("CHECK ok: %d parts, %d tris, %.3f tall" % (len(objs), tris, h))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    variant = args[0] if args else "blaze"
    out = args[1] if len(args) > 1 else os.path.join("assets", "models", "figures", variant + ".glb")
    out = out if os.path.isabs(out) else os.path.join(ROOT, out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = Builder(PALETTES[variant])
    if variant == "doll":
        build_doll(b)
    elif variant == "soldier":
        build_soldier(b)
    else:
        build_body(b, variant)
    if variant in ("knight", "king"):
        build_knight_gear(b)
    if variant == "king":
        build_crown(b)
    parts = PARTS + EXTRAS.get(variant, [])
    objs = b.assemble(parts)
    check(objs, parts)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False)
    print("EXPORTED", out)


main()
