"""Builds the toy dragon, boss of the kitchen: a quadruped on its own rig.

    "N:/Programme/Blender/blender.exe" --background --python-exit-code 1 \
        --python tools/blender/build_dragon.py -- assets/models/figures/dragon.glb

Same rules as build_figure.py (one object per joint, origin on the joint, no
rotation, materials named by role); only the skeleton differs. PARTS is the
contract with scripts/enemies/dragon.gd. Faces -Z, feet at y 0.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import build_figure as bf  # noqa: E402

PALETTE = {"primary": (0.48, 0.14, 0.58), "secondary": (0.24, 0.07, 0.3), "accent": (0.95, 0.72, 0.18),
           "joint": (0.3, 0.1, 0.36), "glow": (1.0, 0.5, 0.1), "metal": (0.95, 0.94, 0.88)}

PARTS = [
    ("body", None, (0, 2.6, 0)),
    ("neck", "body", (0, 3.2, -1.5)),
    ("head", "neck", (0, 4.7, -2.5)),
    ("jaw", "head", (0, 4.65, -2.7)),
    ("tail1", "body", (0, 2.6, 1.7)),
    ("tail2", "tail1", (0, 2.2, 3.3)),
    ("tail3", "tail2", (0, 1.7, 4.7)),
    ("leg_fl", "body", (-0.85, 2.2, -1.0)),
    ("leg_fr", "body", (0.85, 2.2, -1.0)),
    ("leg_bl", "body", (-0.9, 2.2, 1.1)),
    ("leg_br", "body", (0.9, 2.2, 1.1)),
    ("wing_l", "body", (-0.6, 3.4, -0.5)),
    ("wing_r", "body", (0.6, 3.4, -0.5)),
]


def build(b):
    b.part = "body"
    b.ball((0, 2.6, 0), 1.0, "primary", (1.1, 1.0, 1.9))
    b.ball((0, 2.25, -0.1), 0.85, "accent", (0.95, 0.7, 1.75))  # belly plates
    for i in range(5):
        z = -1.2 + i * 0.6
        b.box((0, 3.55 - abs(z) * 0.08, z), (0.08, 0.35, 0.3), "accent", 0.04, rot=(-20, 0, 0), taper=(0.2, 1.0))
    b.part = "neck"
    b.limb((0, 3.2, -1.5), (0, 4.6, -2.4), 0.55, 0.42, "primary", 0.05)
    b.limb((0, 3.0, -1.6), (0, 4.4, -2.55), 0.38, 0.3, "accent", 0.04)
    b.part = "head"
    b.box((0, 5.0, -2.9), (0.9, 0.75, 1.2), "primary", 0.25)
    b.box((0, 4.88, -3.75), (0.7, 0.45, 0.95), "primary", 0.18)
    for sx in (-1, 1):
        b.limb((0.3 * sx, 5.3, -2.6), (0.5 * sx, 5.95, -1.9), 0.13, 0.02, "accent", 0.01, sides=12)
        b.limb((0.42 * sx, 5.0, -2.5), (0.7 * sx, 5.1, -2.0), 0.08, 0.01, "accent", 0.01, sides=10)
        b.ball((0.36 * sx, 5.15, -3.3), 0.13, "glow")
        b.ball((0.18 * sx, 4.95, -4.2), 0.06, "secondary")
    b.part = "jaw"
    b.box((0, 4.5, -3.45), (0.62, 0.22, 1.25), "secondary", 0.08)
    for sx in (-1, 1):
        for z in (-3.0, -3.4, -3.8):
            b.box((0.24 * sx, 4.66, z), (0.06, 0.14, 0.06), "metal", 0.01, taper=(0.2, 0.2))
    b.part = "tail1"
    b.limb((0, 2.6, 1.7), (0, 2.2, 3.3), 0.6, 0.42, "primary", 0.05)
    b.part = "tail2"
    b.limb((0, 2.2, 3.3), (0, 1.7, 4.7), 0.42, 0.26, "primary", 0.04)
    b.part = "tail3"
    b.limb((0, 1.7, 4.7), (0, 1.3, 5.9), 0.26, 0.08, "primary", 0.03)
    b.box((0, 1.25, 6.05), (0.05, 0.6, 0.6), "accent", 0.04, rot=(45, 0, 0))  # spade tip
    for s, sx, z in (("fl", -1, -1.0), ("fr", 1, -1.0), ("bl", -1, 1.1), ("br", 1, 1.1)):
        b.part = "leg_" + s
        x = (0.85 if z < 0 else 0.9) * sx
        b.ball((x, 2.2, z), 0.5, "primary")
        b.limb((x, 2.1, z), (x * 1.1, 0.4, z - 0.2 * (1 if z < 0 else -1)), 0.4, 0.3, "primary", 0.04)
        b.box((x * 1.1, 0.2, z - 0.35), (0.6, 0.4, 0.85), "secondary", 0.12)
        for dx in (-0.18, 0.0, 0.18):
            b.box((x * 1.1 + dx, 0.12, z - 0.85), (0.08, 0.14, 0.18), "metal", 0.02, taper=(0.3, 0.3))
    for s, sx in (("l", -1), ("r", 1)):
        b.part = "wing_" + s
        root = (0.6 * sx, 3.4, -0.5)
        for tip in ((3.2 * sx, 4.7, 0.1), (2.9 * sx, 3.7, 1.1), (2.0 * sx, 3.1, 1.7)):
            b.limb(root, tip, 0.1, 0.04, "secondary", 0.01, sides=10)
        b.box((1.9 * sx, 3.85, 0.45), (2.7, 0.06, 1.9), "joint", 0.03, rot=(0, 10 * sx, 14 * sx))
        b.box((1.5 * sx, 3.5, 1.05), (1.8, 0.05, 1.2), "joint", 0.03, rot=(0, 25 * sx, 8 * sx))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if args else os.path.join("assets", "models", "figures", "dragon.glb")
    out = out if os.path.isabs(out) else os.path.join(bf.ROOT, out)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = bf.Builder(PALETTE)
    build(b)
    objs = b.assemble(PARTS)
    names = {n for n, _, _ in PARTS}
    assert set(objs) == names, "parts differ: %s" % sorted(set(objs) ^ names)
    tris = sum(sum(len(f.vertices) - 2 for f in o.data.polygons) for o in objs.values())
    zs = [(o.matrix_world @ v.co).z for o in objs.values() for v in o.data.vertices]
    assert abs(min(zs)) < 0.05, "feet at %.3f" % min(zs)
    print("CHECK ok: %d parts, %d tris, %.2f tall" % (len(objs), tris, max(zs) - min(zs)))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False)
    print("EXPORTED", out)


main()
