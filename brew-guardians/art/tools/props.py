"""Builds the scenery meshes (cauldron, trees, rocks, crystals, chest).

    python props.py -- <out_dir> [Name ...]
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from artlib import Asset, export_fbx, hexcol, mix, preview_scene, render, reset  # noqa: E402

IRON, IRON_HI, WOOD, WOOD_DK = hexcol("24222c"), hexcol("4a4656"), hexcol("8a5a36"), hexcol("5e3b22")


def cauldron(a):
    # outer belly, rolled lip, then the inner wall down below the brew line
    profile = [(0.0, 0.26), (0.34, 0.23), (0.62, 0.3), (0.85, 0.47), (0.97, 0.68), (0.99, 0.88), (0.92, 1.05),
               (0.85, 1.14), (0.86, 1.19), (0.97, 1.22), (1.02, 1.28), (0.97, 1.35), (0.86, 1.35), (0.81, 1.29),
               (0.82, 1.15), (0.86, 0.95), (0.6, 0.9), (0.0, 0.9)]

    def iron(p):
        r = math.hypot(p.x, p.y)
        if p.z > 1.17:
            return IRON_HI
        band = abs(p.z - 0.72) < 0.035
        return mix(IRON, IRON_HI, 0.55) if band else mix(IRON, IRON_HI, max(0, (p.z - 0.3)) * 0.25)

    a.lathe(profile, iron, segments=56)
    # rivets around the belly band
    for i in range(16):
        ang = i / 16 * math.tau
        a.sphere((math.cos(ang) * 0.985, math.sin(ang) * 0.985, 0.72), (0.035, 0.035, 0.035), IRON_HI)
    # clawed legs
    for i in range(3):
        ang = i / 3 * math.tau + 0.3
        x, y = math.cos(ang), math.sin(ang)
        a.spike((x * 0.55, y * 0.55, 0.36), (x * 0.5, y * 0.5, -1), 0.11, 0.38, IRON)
        a.sphere((x * 0.72, y * 0.72, 0.04), (0.13, 0.13, 0.06), IRON_HI)
    # handles
    import bpy
    for side in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.045, location=(side * 1.02, 0, 1.05), rotation=(0, math.radians(90), 0))
        obj = bpy.context.active_object
        bpy.ops.object.transform_apply(location=True, rotation=True)
        from artlib import _paint
        _paint(obj.data, lambda p: IRON_HI)
        for poly in obj.data.polygons:
            poly.use_smooth = True
        a.solids.append((obj, False))
    # firewood
    for i in range(4):
        ang = i / 4 * math.pi + 0.2
        a.cylinder((math.cos(ang) * -0.5, math.sin(ang) * -0.5, 0.07), 0.07, 1.0, WOOD, rot=(90, 0, math.degrees(ang) + 90))
    a.sphere((0, 0, 0.1), (0.32, 0.32, 0.1), hexcol("ff7a24"), glow=True)


def tree_round(a, seed=1):
    rnd = random.Random(seed)
    TR, TR2 = hexcol("7a5234"), hexcol("5d3d25")
    greens = [hexcol("4f9a45"), hexcol("67b552"), hexcol("82c95d"), hexcol("3f8040")]
    for i in range(7):
        a.blob((0, 0, 0.16 + i * 0.19), 0.17 - i * 0.008, TR, size=(1, 1, 1.5))
    for ang in (0, 2.1, 4.2):
        a.blob((math.cos(ang) * 0.2, math.sin(ang) * 0.2, 0.08), 0.11, TR2, size=(1.6, 1.0, 0.6), rot=(0, 0, math.degrees(ang)))
    for side in (-1, 1):
        a.blob((side * 0.25, 0, 1.1), 0.08, TR, size=(2.2, 1, 1), rot=(0, side * -35, 0))
    clusters = [(0, 0, 1.85, 0.8), (0.62, 0.12, 1.6, 0.58), (-0.62, -0.12, 1.62, 0.6), (0.12, 0.6, 1.66, 0.56), (-0.12, -0.6, 1.68, 0.56), (0.0, 0.0, 2.35, 0.55), (0.4, -0.35, 2.1, 0.45), (-0.38, 0.38, 2.12, 0.45)]
    for x, y, z, r in clusters:
        shade = greens[2] if z > 1.9 else greens[rnd.randrange(0, 2)]
        a.blob((x, y, z), r, shade, size=(1, 1, 0.82))
    for k in range(8):
        ang = rnd.uniform(0, math.tau)
        a.blob((math.cos(ang) * 0.8, math.sin(ang) * 0.8, rnd.uniform(1.7, 2.2)), rnd.uniform(0.24, 0.32), greens[2], size=(1, 1, 0.8))
    a.build_body(voxel=0.02, smooth=10)


def tree_pine(a, snow=False):
    TR = hexcol("6a4630")
    G1, G2 = (hexcol("3c7a4c"), hexcol("2d6340")) if not snow else (hexcol("3d6e5a"), hexcol("2c5546"))
    a.blob((0, 0, 0.35), 0.13, TR, size=(1, 1, 3))
    for i in range(4):
        r = 0.78 - i * 0.17
        z = 0.75 + i * 0.5
        a.blob((0, 0, z), r, G1 if i % 2 == 0 else G2, size=(1, 1, 0.55))
        a.blob((0, 0, z + 0.2), r * 0.62, G2 if i % 2 == 0 else G1, size=(1, 1, 0.7))
        if snow:
            a.blob((0, 0, z + 0.2), r * 0.82, hexcol("f4f9ff"), size=(1, 1, 0.3))
    a.blob((0, 0, 2.75), 0.16, hexcol("f4f9ff") if snow else G1, size=(1, 1, 1.4))
    a.build_body(voxel=0.02, smooth=8)


def tree_dead(a, seed=3):
    rnd = random.Random(seed)
    BARK = hexcol("2e2422")
    z = 0.0
    x = y = 0.0
    for i in range(7):
        a.blob((x, y, z + 0.18), 0.15 - i * 0.013, BARK, size=(1, 1, 1.5))
        z += 0.3
        x += rnd.uniform(-0.05, 0.05)
        y += rnd.uniform(-0.05, 0.05)
    for k in range(4):
        ang = k / 4 * math.tau + rnd.uniform(-0.4, 0.4)
        bz = rnd.uniform(1.0, 1.8)
        for j in range(5):
            d = 0.12 + j * 0.12
            a.blob((math.cos(ang) * d, math.sin(ang) * d, bz + j * 0.1), 0.085 - j * 0.009, BARK, size=(1.6, 1, 1), rot=(0, -35, math.degrees(ang)))
    for ang in (0.5, 2.6, 4.4):
        a.blob((math.cos(ang) * 0.22, math.sin(ang) * 0.22, 0.05), 0.1, BARK, size=(1.8, 1, 0.6), rot=(0, 0, math.degrees(ang)))
    a.build_body(voxel=0.016, smooth=6)
    a.sphere((0.02, 0.0, 0.25), (0.05, 0.02, 0.09), hexcol("ff7a20"), glow=True)


def bush(a, seed=5):
    rnd = random.Random(seed)
    greens = [hexcol("4f9a45"), hexcol("67b552"), hexcol("3f8040")]
    for k in range(7):
        ang = k / 7 * math.tau
        d = 0.0 if k == 0 else 0.35
        a.blob((math.cos(ang) * d, math.sin(ang) * d, 0.3 + rnd.uniform(0, 0.15)), rnd.uniform(0.3, 0.42), greens[k % 3], size=(1, 1, 0.8))
    a.build_body(voxel=0.02, smooth=8)
    for k in range(5):
        ang = rnd.uniform(0, math.tau)
        a.sphere((math.cos(ang) * 0.45, math.sin(ang) * 0.45, rnd.uniform(0.4, 0.6)), (0.05, 0.05, 0.05), hexcol("ff6f91"))


def rock(a, variant="Grey", seed=7):
    rnd = random.Random(seed)
    base = {"Grey": hexcol("8e8a86"), "Dark": hexcol("3a302e"), "Snow": hexcol("9aa4ad")}[variant]
    top = {"Grey": hexcol("6fa257"), "Dark": hexcol("4a3c39"), "Snow": hexcol("f4f8ff")}[variant]

    def col(center, normal):
        shade = mix(base, (0, 0, 0), rnd.uniform(0.0, 0.15))
        return mix(shade, top, 0.85) if normal.z > 0.62 else shade

    a.rock((0, 0, 0.35), (0.75, 0.6, 0.55), col, seed=seed)
    a.rock((0.55, 0.25, 0.2), (0.38, 0.32, 0.3), col, seed=seed + 1)
    a.rock((-0.5, -0.2, 0.15), (0.3, 0.26, 0.22), col, seed=seed + 2)
    if variant == "Dark":
        a.sphere((0.05, -0.2, 0.35), (0.04, 0.4, 0.02), hexcol("ff7a20"), glow=True, rot=(0, 30, 20))


def crystals(a, seed=9):
    rnd = random.Random(seed)
    cols = [hexcol("9bd8ff"), hexcol("c3e9ff"), hexcol("7fc2f5")]
    a.crystal((0, 0, 0), 0.16, 1.3, cols[0])
    for k in range(6):
        ang = k / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        h = rnd.uniform(0.45, 0.9)
        tilt = rnd.uniform(18, 35)
        a.crystal((math.cos(ang) * 0.15, math.sin(ang) * 0.15, 0), rnd.uniform(0.07, 0.11), h, cols[k % 3], rot=(tilt * math.sin(ang + math.pi / 2), tilt * math.cos(ang - math.pi / 2) * -1, 0))
    a.rock((0, 0, 0.02), (0.32, 0.32, 0.12), lambda c, n: hexcol("8fa0b0"), seed=seed)


def coin_chest(a):
    GOLD, GOLD_DK = hexcol("ffcf4a"), hexcol("d9982a")
    import bpy
    from artlib import _paint

    def box(loc, size, color, bevel=0.03):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.active_object
        o.scale = size
        bpy.ops.object.transform_apply(scale=True, location=True)
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 3
        bpy.ops.object.modifier_apply(modifier="bevel")
        _paint(o.data, lambda p: color)
        a.solids.append((o, False))

    def lid_piece(width, radius, x, color):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=width, location=(0, 0, 0), rotation=(0, math.radians(90), 0))
        o = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
        o.location = (x, 0.3, 0.72)
        o.rotation_euler = (math.radians(-55), 0, 0)
        bpy.ops.object.transform_apply(location=True, rotation=True)
        for poly in o.data.polygons:
            poly.use_smooth = True
        _paint(o.data, lambda p: color)
        a.solids.append((o, False))

    box((0, 0, 0.32), (1.0, 0.66, 0.62), WOOD)
    for x in (-0.44, 0.44):
        box((x, 0, 0.32), (0.09, 0.69, 0.65), GOLD_DK, bevel=0.015)
    box((0, 0, 0.62), (1.03, 0.69, 0.06), WOOD_DK, bevel=0.01)
    lid_piece(1.0, 0.34, 0, WOOD)
    for x in (-0.44, 0.44):
        lid_piece(0.09, 0.355, x, GOLD_DK)
    rnd = random.Random(2)
    a.sphere((0, -0.02, 0.64), (0.44, 0.28, 0.14), GOLD)
    for k in range(18):
        a.cylinder((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.25, 0.2), 0.64 + rnd.uniform(0.02, 0.14)), 0.07, 0.02, GOLD if k % 3 else GOLD_DK,
                   rot=(rnd.uniform(-35, 35), rnd.uniform(-35, 35), 0))
    a.sphere((0, -0.34, 0.45), (0.08, 0.03, 0.1), GOLD_DK)  # lock


PROPS = {
    "Cauldron": (cauldron, False, dict(distance=4.2, target=(0, 0, 0.7))),
    "TreeRound": (tree_round, False, dict(distance=7.5, target=(0, 0, 1.3))),
    "TreePine": (lambda a: tree_pine(a), False, dict(distance=7.5, target=(0, 0, 1.4))),
    "TreeSnow": (lambda a: tree_pine(a, snow=True), False, dict(distance=7.5, target=(0, 0, 1.4))),
    "TreeDead": (tree_dead, False, dict(distance=6.5, target=(0, 0, 1.1))),
    "Bush": (bush, False, dict(distance=3.5, target=(0, 0, 0.3))),
    "RockGrey": (lambda a: rock(a, "Grey"), True, dict(distance=4.2, target=(0, 0, 0.3))),
    "RockDark": (lambda a: rock(a, "Dark", 11), True, dict(distance=4.2, target=(0, 0, 0.3))),
    "RockSnow": (lambda a: rock(a, "Snow", 13), True, dict(distance=4.2, target=(0, 0, 0.3))),
    "Crystals": (crystals, True, dict(distance=4.0, target=(0, 0, 0.55))),
    "CoinChest": (coin_chest, False, dict(distance=3.4, target=(0, 0, 0.45))),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    out = args[0]
    names = args[1:] or list(PROPS)
    os.makedirs(out, exist_ok=True)
    manifest_path = os.path.join(out, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    for name in names:
        fn, flat, view = PROPS[name]
        reset()
        a = Asset(name, flat=flat)
        fn(a)
        budget = {"Cauldron": 6000, "Bush": 1500, "CoinChest": 4000}.get(name, 3000)
        objs = a.finish(out, tex_size=512, max_tris=budget)
        export_fbx(objs, os.path.join(out, name + ".fbx"))
        zmax = max((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
        manifest[name] = {"height": round(zmax, 4), "tris": sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)}
        preview_scene(target=view["target"], distance=view["distance"], angle=-30, height=0.3)
        render(os.path.join(out, name + "_preview.png"), 560, 440, samples=32)
        print("BUILT", name, manifest[name])
    json.dump(manifest, open(manifest_path, "w"), indent=2)


main()
