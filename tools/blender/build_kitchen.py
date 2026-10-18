"""Builds level 2, the kitchen (54 x 54 x 30; x -27..27, z -27..27, floor y 0).

    "N:/Programme/Blender/blender.exe" --background --python-exit-code 1 \\
        --python tools/blender/build_kitchen.py -- assets/models/rooms/kitchen.glb

Counter run along the north wall (worktop at 10.8): stove + hot plate (west),
sink under the window, prep area (east), fridge in the NE corner (top 21.6).
Upper cabinets east of the window (top 25.8), extractor hood over the stove.
Kitchen table in the middle (top 9) with the cookie jar: the goal.
Route: door -> floor fight -> drawers up -> prep fight -> sink -> stove fight ->
hood -> herb pot swing -> upper cabinets -> fridge fight -> pot rack + lamp
swings -> table: the dragon. Marker contract in roomkit.py.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from roomkit import Room, finish, out_path  # noqa: E402

TOP = 10.8  # worktop height
CZ0, CZ1 = -27.0, -19.8  # counter depth (z)


def shell(r):
    r.group = "shell"
    r.box((0, -0.5, 0), (54, 1, 54), "tile_floor", 0)
    r.box((0, 30.5, 0), (54, 1, 54), "ceiling", 0)
    r.box((0, 15, 27.75), (57, 30, 1.5), "wall", 0)
    r.box((-27.75, 15, 0), (1.5, 30, 57), "wall", 0)
    r.box((27.75, 15, 0), (1.5, 30, 57), "wall", 0)
    # north wall around the window x[-13, -1] y[14.4, 26.4]
    r.box((-20.25, 15, -27.75), (14.5, 30, 1.5), "wall", 0)
    r.box((13.25, 15, -27.75), (28.5, 30, 1.5), "wall", 0)
    r.box((-7, 7.2, -27.75), (12, 14.4, 1.5), "wall", 0)
    r.box((-7, 28.2, -27.75), (12, 3.6, 1.5), "wall", 0)
    r.box((-3.6, 13.0, -26.95), (46.8, 4.4, 0.1), "tile_wall", 0, col=False)  # backsplash
    for c, s in (((0, 0.42, 26.88), (54, 0.84, 0.24)), ((-26.88, 0.42, 0), (0.24, 0.84, 54)),
                 ((26.88, 0.42, 0), (0.24, 0.84, 54))):
        r.box(c, s, "baseboard", 0.06, col=False)
    r.group = "door"  # the hallway door stands open: that is where you come in
    r.box((10.6, 12.6, 26.95), (13, 25.2, 0.2), "wall", 0, col=False)
    r.box((4.4, 12.6, 26.7), (0.9, 26, 0.6), "wood_white", 0.1, col=False)
    r.box((16.6, 12.6, 26.7), (0.9, 26, 0.6), "wood_white", 0.1, col=False)
    r.box((10.5, 25.6, 26.7), (13.1, 0.9, 0.6), "wood_white", 0.1, col=False)
    r.box((1.2, 12.6, 21.6), (0.4, 24.6, 10.6), "wood_white", 0.1, rot=(0, 0, 0))  # the door, swung open against the wall
    r.marker("spawn_player", (13, 0.1, 23))
    r.marker("checkpoint_0", (13, 0.1, 23))


def window(r):
    r.group = "window_frame"
    r.box((-7, 14.1, -26.4), (13.2, 0.6, 2.7), "sill", 0.1)
    for c, s in (((-12.7, 20.4, -28.0), (0.6, 12.0, 0.8)), ((-1.3, 20.4, -28.0), (0.6, 12.0, 0.8)),
                 ((-7, 26.1, -28.0), (12, 0.6, 0.8)), ((-7, 20.4, -28.0), (0.4, 12, 0.6))):
        r.box(c, s, "wood_white", 0.08, col=False)
    r.box((-7, 20.4, -28.1), (11, 11.4, 0.12), "glass", 0, col=False)
    r.collider((-7, 20.4, -27.8), (12, 12, 0.6), name="window_glass")
    r.group = "sky"
    r.box((-7, 20, -42), (60, 40, 0.5), "sky", 0, col=False)
    r.group = "curtain"  # cafe curtain on the lower half, climbable
    for i in range(6):
        x = -12.3 + i * 2.1
        r.cyl((x, 14.8, -26.0), (x, 20.0, -26.0), 0.55, 0.55, "towel", 10, 0)
    r.cyl((-13, 20.2, -26.0), (-1, 20.2, -26.0), 0.15, 0.15, "steel", 10, 0)


def counter(r):
    r.group = "counter"
    W = "cabinet_mint"
    # base cabinets: carcass box, doors, kickboard
    r.box((-3.6, 0.6, -23.1), (46.8, 1.2, 6.6), "wood_dark", 0.05)
    for x0, x1 in ((-27, -15), (-15, -12), (-2.8, 10), (16.6, 19.8)):
        r.box(((x0 + x1) / 2, 5.8, -23.4), (x1 - x0, 9.2, 7.0), W, 0.1)
    r.box((-7.4, 3.75, -23.4), (9.2, 5.1, 7.0), W, 0.1)  # under the basin: low, the basin sits on it
    r.collider((-7.4, 8.3, -20.0), (9.2, 4.0, 0.4))  # the sink cabinet's door front
    for x0, x1 in ((-15, -12), (-12, -2.8), (-2.8, -1)):
        cx = (x0 + x1) / 2
        r.box((cx, 5.8, -19.85), (x1 - x0 - 0.3, 8.6, 0.12), W, 0.08, col=False)
        r.box((cx + 1.0, 8.8, -19.7), (1.4, 0.35, 0.35), "steel", 0.1, col=False)
        n = max(1, int((x1 - x0) / 5.5))
        for i in range(n):
            cx = x0 + (x1 - x0) * (i + 0.5) / n
            r.box((cx, 5.8, -19.85), ((x1 - x0) / n - 0.3, 8.6, 0.12), W, 0.08, col=False)
            r.box((cx + 1.2, 8.8, -19.7), (1.8, 0.35, 0.35), "steel", 0.1, col=False)
    # drawer stack: three drawers pulled out to make a staircase
    r.box((13.3, 5.8, -23.6), (6.6, 9.2, 6.6), W, 0.1)
    for y, out in ((1.8, 4.2), (5.4, 2.8), (9.0, 1.4)):
        r.box((13.3, y, -20.2 + out / 2), (6.0, 1.8, out + 0.4), W, 0.08)
        r.box((13.3, y + 0.2, -20.0 + out), (2.4, 0.35, 0.4), "steel", 0.1, col=False)
    # worktop, with the sink cut out of it
    gy = TOP - 0.24
    r.box((-19.5, gy, -23.4), (15, 0.48, 7.6), "granite", 0.08)  # stove part x[-27,-12]
    r.box((8.5, gy, -23.4), (22.6, 0.48, 7.6), "granite", 0.08)  # prep part x[-2.8, 19.8]
    r.box((-7.4, gy, -26.45), (9.2, 0.48, 1.5), "granite", 0.05)  # behind the sink
    r.box((-7.4, gy, -20.35), (9.2, 0.48, 1.5), "granite", 0.05)  # sink front rim
    # oven under the stove, with a tea towel hanging from its handle (climbable)
    r.box((-20.5, 4.8, -19.75), (10, 7.2, 0.3), "steel", 0.1, col=False)
    r.box((-20.5, 4.6, -19.6), (7.5, 4.2, 0.1), "glass", 0.05, col=False)
    r.cyl((-24.5, 9.0, -19.2), (-16.5, 9.0, -19.2), 0.25, 0.25, "steel", 12, 0.05)
    r.box((-20.5, 6.4, -19.0), (3.6, 5.2, 0.25), "towel", 0.1, col=False)
    r.collider((-20.5, 6.2, -18.9), (3.8, 5.6, 0.5), climb=True, name="towel")


def stove(r):
    r.group = "stove"
    r.box((-20.5, TOP + 0.08, -23.4), (11, 0.16, 6.6), "hotplate", 0.05, col=False)
    for x, z, hot in ((-23.5, -25.2, False), (-17.5, -25.2, False), (-23.5, -21.6, False), (-17.5, -21.6, True)):
        r.cyl((x, TOP + 0.16, z), (x, TOP + 0.24, z), 1.6, 1.6, "hotplate_glow" if hot else "hotplate", 28, 0.02)
    r.marker("hazard_hot_0", (-17.5, TOP + 0.1, -21.6), (3.2, 1.6, 3.2))
    # a pan on a back plate: cover in the fight
    r.cyl((-23.5, TOP + 0.24, -25.2), (-23.5, TOP + 1.5, -25.2), 2.2, 2.4, "steel", 24, 0.1, col=True)
    r.cyl((-23.5, TOP + 1.0, -22.8), (-23.5, TOP + 1.0, -19.6), 0.3, 0.3, "wood_dark", 10, 0.05)
    # extractor hood and its chimney
    r.group = "hood"
    r.box((-20.5, 19.5, -24.0), (11, 3.0, 6.0), "steel", 0.15, taper=(1.0, 1.0))
    r.box((-20.5, 25.5, -25.5), (4.5, 9.0, 3.0), "steel", 0.1)
    r.marker("grapple_pull_hood", (-14.5, 21.6, -21.8))
    # utensil rail
    r.group = "utensils"
    r.cyl((-26, 16.0, -26.5), (-15, 16.0, -26.5), 0.12, 0.12, "steel", 8, 0)
    for x, m in ((-24.5, "wood_dark"), (-22, "steel"), (-19.5, "plastic_red"), (-17, "steel")):
        r.cyl((x, 16.0, -26.4), (x, 12.6, -26.4), 0.12, 0.12, m, 8, 0)
        r.ball((x, 12.4, -26.4), 0.6, m, (1, 0.5, 0.25))
    r.marker("checkpoint_3", (-14, TOP + 0.1, -22.5))
    r.marker("arena_3", (-20.5, TOP + 0.1, -23.4), (11, 7, 6.6))


def sink(r):
    r.group = "sink"
    # basin: steel walls down to 6.6, water inside (a hazard)
    for c, s in (((-11.9, 8.7, -23.4), (0.3, 4.2, 4.6)), ((-2.9, 8.7, -23.4), (0.3, 4.2, 4.6)),
                 ((-7.4, 8.7, -25.6), (9.2, 4.2, 0.3)), ((-7.4, 8.7, -21.2), (9.2, 4.2, 0.3))):
        r.box(c, s, "steel", 0.05)
    r.box((-7.4, 6.5, -23.4), (9.0, 0.3, 4.6), "steel", 0.05)
    r.box((-7.4, 8.2, -23.4), (8.6, 0.05, 4.2), "water", 0, col=False)
    r.marker("hazard_water_0", (-7.4, 6.7, -23.4), (8.6, 2.2, 4.2))
    # faucet: the hook that gets you across
    r.cyl((-7.4, TOP, -26.2), (-7.4, 16.2, -26.2), 0.45, 0.4, "steel", 16, 0.05, col=True)
    r.cyl((-7.4, 16.2, -26.2), (-7.4, 16.2, -23.0), 0.4, 0.4, "steel", 16, 0.05)
    r.ball((-7.4, 16.2, -26.2), 0.5, "steel")
    r.cyl((-7.4, 16.2, -23.0), (-7.4, 15.2, -23.0), 0.4, 0.3, "steel", 16, 0.05)
    r.marker("grapple_pull_faucet", (-7.4, 17.0, -24.8))
    # sponge and dish soap on the rim
    r.box((-1.2, TOP + 0.6, -26.0), (1.6, 1.2, 1.0), "fruit_yellow", 0.3, col=False)
    r.marker("star_0", (-7.0, 15.2, -26.6))  # on the window sill


def prep(r):
    r.group = "prep"
    r.box((2.0, TOP + 1.8, -25.2), (4.8, 3.6, 3.0), "steel", 0.5)  # toaster
    for x in (1.2, 2.8):
        r.box((x, TOP + 3.62, -25.2), (0.5, 0.05, 2.2), "hotplate", 0.02, col=False)
    r.box((12.5, TOP + 3.6, -25.6), (4.4, 7.2, 1.8), "plastic_yellow", 0.15)  # cereal box
    r.box((12.5, TOP + 4.6, -24.68), (3.2, 2.4, 0.05), "fruit_red", 0.05, col=False)
    r.box((7.0, TOP + 0.2, -23.0), (6.0, 0.4, 4.0), "wood_light", 0.12)  # cutting board
    r.cyl((5.5, TOP + 1.3, -23.0), (9.0, TOP + 1.3, -22.6), 0.9, 0.85, "leaf", 16, 0.3, col=True)  # cucumber
    r.ball((17.5, TOP + 1.6, -24.5), 1.6, "fruit_red", col=True)  # tomato
    r.marker("checkpoint_1", (16, TOP + 0.1, -22.0))
    r.marker("arena_2", (8.0, TOP + 0.1, -23.4), (21, 7, 6.6))
    r.marker("star_1", (12.5, TOP + 8.4, -25.6))  # on the cereal box


def uppers(r):
    r.group = "uppers"
    W = "cabinet_mint"
    r.box((10.4, 21.6, -24.9), (18.8, 8.4, 4.2), W, 0.1)  # x[1, 19.8], top 25.8
    for i in range(4):
        cx = 1 + 18.8 * (i + 0.5) / 4
        r.box((cx, 21.6, -22.75), (4.4, 8.0, 0.12), W, 0.08, col=False)
        r.box((cx + 1.4, 18.4, -22.6), (0.35, 1.6, 0.35), "steel", 0.1, col=False)
    for x, h, m in ((5, 3.0, "glass"), (9, 4.0, "ceramic"), (15, 2.4, "glass")):  # jars at the back, room to pass
        r.cyl((x, 25.8, -25.9), (x, 25.8 + h, -25.9), 1.0, 1.0, m, 18, 0.1, col=True)
    r.box((10.4, 17.2, -24.9), (18.4, 0.3, 3.8), "lampshade", 0.05, col=False)  # led strip
    r.marker("checkpoint_4", (3.0, 25.9, -24.5))
    r.marker("grapple_pull_cabinet", (1.8, 26.4, -22.4))  # after the herb swing: pull up onto the cabinets
    r.group = "herbs"  # hanging herb pot: the swing from the hood to the cabinets
    r.cyl((-7, 30, -21), (-7, 25.5, -21), 0.1, 0.1, "rope", 6, 0)
    r.cyl((-7, 23.4, -21), (-7, 25.6, -21), 1.4, 1.9, "pot", 18, 0.1)
    for i in range(5):
        a = i * 1.25
        r.ball((-7 + math.cos(a) * 1.4, 26.0 + (i % 2) * 0.5, -21 + math.sin(a) * 1.4), 0.9, "leaf", (1.2, 0.5, 0.8))
    r.marker("grapple_swing_herbs", (-7, 28.6, -21))


def fridge(r):
    r.group = "fridge"
    r.box((23.4, 10.8, -23.1), (7.2, 21.6, 7.8), "ceramic", 0.4)
    r.box((23.4, 15.6, -19.15), (7.0, 11.6, 0.12), "ceramic", 0.1, col=False)
    r.box((23.4, 4.8, -19.15), (7.0, 9.2, 0.12), "ceramic", 0.1, col=False)
    r.cyl((20.6, 11.4, -18.8), (20.6, 19.0, -18.8), 0.3, 0.3, "steel", 10, 0.05)
    for x, y, m in ((22.5, 16, "plastic_red"), (25, 13.5, "plastic_blue"), (24, 7, "plastic_yellow")):
        r.box((x, y, -19.05), (1.2, 1.2, 0.2), m, 0.15, col=False)  # magnets
    r.box((24.5, 15.2, -19.08), (3.0, 3.8, 0.04), "paper", 0, col=False)  # a drawing
    r.marker("checkpoint_5", (23.4, 21.7, -23.0))
    r.marker("arena_4", (23.4, 21.6, -23.1), (6.8, 7, 7.4))
    r.marker("star_2", (26.0, 22.8, -26.0))


def table(r):
    r.group = "table"
    L = "wood_light"
    tx, tz = 2.0, 6.0
    r.box((tx, 8.7, tz), (14.4, 0.6, 9.6), L, 0.2)
    for dx in (-6.6, 6.6):
        for dz in (-4.2, 4.2):
            r.box((tx + dx, 4.2, tz + dz), (0.8, 8.4, 0.8), L, 0.1)
    for (cx, cz, rot) in ((tx - 3.5, tz - 7.6, 0), (tx + 3.5, tz - 7.6, 0), (tx - 3.5, tz + 7.6, 180), (tx + 3.5, tz + 7.6, 180)):
        r.box((cx, 5.1, cz), (5.0, 0.6, 5.0), L, 0.15)
        back = 2.3 if rot == 180 else -2.3
        r.box((cx, 8.4, cz + back), (5.0, 6.0, 0.5), L, 0.12)
        for dx in (-2.1, 2.1):
            for dz in (-2.1, 2.1):
                r.box((cx + dx, 2.4, cz + dz), (0.45, 4.8, 0.45), L, 0.06, col=False)
    # fruit bowl and a milk glass: cover on the table
    r.cyl((tx - 4.5, 9.0, tz + 2.0), (tx - 4.5, 10.6, tz + 2.0), 1.6, 2.6, "ceramic", 24, 0.15, col=True)
    for dx, dz, m in ((0.4, 0.3, "fruit_red"), (-0.6, -0.2, "fruit_orange"), (0.2, -0.8, "fruit_yellow")):
        r.ball((tx - 4.5 + dx, 11.0, tz + 2.0 + dz), 0.8, m)
    r.cyl((tx + 5.0, 9.0, tz - 3.0), (tx + 5.0, 12.6, tz - 3.0), 1.0, 1.1, "glass", 18, 0.05, col=True)
    r.marker("checkpoint_6", (tx - 4.5, 9.1, tz - 3.0))
    r.marker("arena_5", (tx, 9.0, tz), (13.6, 8, 8.8))
    for k, (c, s) in enumerate((((tx, 9.0, tz - 4.95), (14.6, 5, 0.6)), ((tx, 9.0, tz + 4.95), (14.6, 5, 0.6)),
                                ((tx - 7.35, 9.0, tz), (0.6, 5, 10.2)), ((tx + 7.35, 9.0, tz), (0.6, 5, 10.2)))):
        r.marker("arena_5_barrier_%d" % k, c, s)
    r.marker("star_3", (tx, 1.6, tz))  # under the table
    # the cookie jar: the goal, its lid lifts once the dragon is beaten
    r.group = "cookie_jar"
    jx, jz = tx + 5.0, tz + 2.5
    r.cyl((jx, 9.0, jz), (jx, 13.2, jz), 1.7, 1.8, "glass", 24, 0.15, col=True)
    for i in range(6):
        a = i * 1.05
        r.cyl((jx + math.cos(a) * 0.9, 9.6 + (i % 3) * 1.1, jz + math.sin(a) * 0.9),
              (jx + math.cos(a) * 0.9, 9.9 + (i % 3) * 1.1, jz + math.sin(a) * 0.9), 0.75, 0.75, "cookie", 14, 0.05)
    r.group = "jar_lid"
    r.cyl((jx, 13.2, jz), (jx, 13.8, jz), 1.95, 1.95, "plastic_red", 24, 0.1)
    r.ball((jx, 14.1, jz), 0.45, "plastic_red")
    r.marker("goal", (jx, 9.0, jz - 2.6), (4, 5, 3))


def hanging(r):
    r.group = "pot_rack"  # swing 1 from the fridge toward the table
    r.cyl((14, 30, -11), (14, 27.0, -11), 0.1, 0.1, "steel", 6, 0)
    r.cyl((11, 27.0, -11), (17, 27.0, -11), 0.2, 0.2, "steel", 8, 0)
    for x in (11.8, 14, 16.2):
        r.cyl((x, 27.0, -11), (x, 25.0, -11), 0.06, 0.06, "steel", 6, 0)
        r.cyl((x, 23.6, -11), (x, 25.0, -11), 1.2, 1.2, "steel", 20, 0.08)
    r.marker("grapple_swing_rack", (14, 27.2, -11))
    r.marker("star_4", (14, 23.0, -11))  # inside the middle pot, catch it on the swing
    r.group = "lamp"  # swing 2: the pendant over the table
    r.cyl((2, 30, 4), (2, 24.4, 4), 0.1, 0.1, "rope", 6, 0)
    r.cyl((2, 22.0, 4), (2, 24.4, 4), 2.8, 0.7, "lampshade", 28, 0.1)
    r.marker("grapple_swing_lamp", (2, 27.4, 4))


def floor_stuff(r):
    r.group = "floor_stuff"
    r.box((-14, 0.6, 18), (3.6, 1.2, 3.6), "ceramic", 0.4)  # the cat's bowl, no cat
    r.box((-14, 1.15, 18), (2.8, 0.1, 2.8), "cookie", 0, col=False)
    r.box((22, 0.05, 6), (8, 0.1, 12), "towel", 0.05)  # a mat by the door
    r.marker("checkpoint_2", (14.0, 0.1, -15.0))
    r.marker("arena_1", (17.0, 0.1, 1.0), (15, 7, 24))
    for k, (c, s) in enumerate((((17.0, 0.1, -11.4), (16, 6, 1)), ((17.0, 0.1, 13.4), (16, 6, 1)),
                                ((9.3, 0.1, 1.0), (1, 6, 25)), ((25.6, 0.1, 1.0), (1, 6, 25)))):
        r.marker("arena_1_barrier_%d" % k, c, s)


def intro_camera(r):
    for i, c in enumerate(((13, 6, 20), (6, 18, 12), (-12, 22, -6), (-8, 18, -16), (16, 24, -14), (9, 14, 2), (13, 4, 18))):
        r.marker("cam_intro_%d" % i, c)


def main():
    out = out_path(os.path.join("assets", "models", "rooms", "kitchen.glb"))
    r = Room()
    for build in (shell, window, counter, stove, sink, prep, uppers, fridge, table, hanging, floor_stuff, intro_camera):
        build(r)
    finish(r, out, {"jar_lid": (7.0, 13.5, 8.5)})  # the lid pivots on itself when it pops


main()
