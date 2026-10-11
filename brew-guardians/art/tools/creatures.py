"""Builds every guardian as a textured FBX plus a preview render.

Run with Blender's Python module:
    python creatures.py -- <out_dir> [Name ...]
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from artlib import Asset, export_fbx, hexcol, mix, preview_scene, render, reset  # noqa: E402

WHITE = (1, 1, 1)
DARK = hexcol("1b1424")


def mossling(a):
    G, GL, GD, FOOT = hexcol("62b552"), hexcol("b5e68f"), hexcol("2f6b33"), hexcol("4c9142")
    a.blob((0, 0, 0.44), 0.44, G, size=(1.08, 0.98, 0.95))
    a.blob((0, -0.24, 0.36), 0.3, GL, size=(1.0, 0.55, 0.95))
    for s in (-1, 1):
        a.blob((s * 0.22, -0.14, 0.08), 0.12, FOOT, size=(1.0, 1.35, 0.62))
        a.blob((s * 0.22, 0.18, 0.08), 0.11, FOOT, size=(1.0, 1.25, 0.62))
        a.blob((s * 0.46, -0.06, 0.32), 0.1, G, size=(0.7, 0.85, 1.35), rot=(0, s * 28, 0))
    # mossy cap on the back of the head
    for x, y, z, r in [(0, 0.1, 0.86, 0.17), (-0.21, 0.16, 0.8, 0.14), (0.22, 0.14, 0.79, 0.14), (0.0, 0.33, 0.72, 0.15), (-0.17, 0.35, 0.66, 0.12), (0.18, 0.34, 0.65, 0.12), (0.0, -0.1, 0.89, 0.12)]:
        a.blob((x, y, z), r, GD)
    a.build_body()
    a.eyes(0.16, 0.5, 0.105, iris=hexcol("2c4a2a"))
    for s in (-1, 1):
        loc, n = a.hit(s * 0.29, 0.37)
        a.stick(loc, n, (0, -0.005, 0), (0.07, 0.025, 0.045), hexcol("ff94b4"))
    loc, n = a.hit(0, 0.36)
    a.stick(loc, n, (0, -0.008, 0), (0.05, 0.02, 0.022), hexcol("3a1f2a"))
    # sprout
    a.cylinder((0, 0.02, 0.86), 0.022, 0.22, hexcol("4f8f3c"))
    for s in (-1, 1):
        a.sphere((s * 0.12, 0.02, 1.08), (0.14, 0.055, 0.025), hexcol("8fd66a"), rot=(0, s * -28, 0))
    a.sphere((0, 0.02, 1.11), (0.055, 0.055, 0.055), hexcol("ffd34a"), glow=True)


def thornback(a):
    HIDE, PLATE, HEAD, SNOUT, LEG = hexcol("5a8a4c"), hexcol("3e6436"), hexcol("6f9b5c"), hexcol("c69a7e"), hexcol("39552f")
    a.blob((0, 0.05, 0.44), 0.42, HIDE, size=(0.95, 1.4, 0.8))
    for y in (-0.3, 0.02, 0.34):
        a.blob((0, y, 0.52), 0.4, PLATE, size=(1.05, 0.32, 0.8))
    a.blob((0, -0.62, 0.42), 0.27, HEAD, size=(1.05, 1.0, 0.92))
    a.blob((0, -0.86, 0.36), 0.13, SNOUT, size=(1.25, 1.0, 0.85))
    for s in (-1, 1):
        a.blob((s * 0.27, -0.32, 0.16), 0.12, LEG, size=(1, 1.05, 1.5))
        a.blob((s * 0.27, 0.4, 0.16), 0.13, LEG, size=(1, 1.05, 1.5))
        a.blob((s * 0.2, -0.56, 0.62), 0.07, LEG, size=(0.6, 0.9, 1.3), rot=(0, s * -30, 0))
    a.blob((0, 0.66, 0.42), 0.08, HIDE, size=(0.9, 1.4, 0.9), rot=(-30, 0, 0))
    a.build_body()
    # three rows of thorns down the back
    for row in (-1, 0, 1):
        for i in range(5):
            y = -0.38 + i * 0.2
            x = row * 0.22
            loc, n = a.hit(x, 2.0, direction=(0, 0, -1), y=y)
            h = 0.2 if row == 0 else 0.15
            back = (0, 0.35, 0)  # thorns sweep backwards
            a.spike(loc - n * 0.02, n, 0.05, h, hexcol("e2c08a"), bend=back)
            tipdir = (n + __import__("mathutils").Vector(back)).normalized()
            a.spike(loc + tipdir * (h * 0.55), n, 0.024, h * 0.45, hexcol("b4462f"), bend=back)
    a.eyes(0.12, 0.52, 0.06, iris=hexcol("5a2a18"), lid=HEAD, tilt=-18)
    loc, n = a.hit(0, 0.37)
    for s in (-1, 1):
        a.stick(loc, n, (s * 0.04, -0.01, 0.0), (0.025, 0.015, 0.03), DARK)
        # tusks curling up from the snout
        tusk = loc + __import__("mathutils").Vector((s * 0.1, 0.05, -0.05))
        a.spike(tusk, (s * 0.35, -0.5, 0.8), 0.028, 0.14, hexcol("fbf4e2"))


def cinderpup(a):
    FUR, CREAM, EAR, PAW = hexcol("ea7a3e"), hexcol("ffe4bd"), hexcol("b9502a"), hexcol("fff0dc")
    a.blob((0, 0.12, 0.36), 0.28, FUR, size=(0.85, 1.35, 0.85))
    a.blob((0, -0.12, 0.42), 0.21, CREAM, size=(0.95, 0.75, 1.0))
    a.blob((0, -0.24, 0.7), 0.29, FUR, size=(1.08, 0.95, 0.94))
    a.blob((0, -0.46, 0.62), 0.12, CREAM, size=(1.25, 1.0, 0.82))
    for s in (-1, 1):
        a.blob((s * 0.2, -0.36, 0.6), 0.1, CREAM, size=(0.9, 0.7, 0.8))
        a.blob((s * 0.29, -0.18, 0.72), 0.12, EAR, size=(0.5, 0.8, 1.55), rot=(0, s * 24, 0))
        a.blob((s * 0.15, -0.08, 0.13), 0.08, FUR, size=(1, 1, 1.7))
        a.blob((s * 0.15, 0.34, 0.13), 0.085, FUR, size=(1, 1, 1.7))
        a.blob((s * 0.15, -0.12, 0.04), 0.08, PAW, size=(1.1, 1.3, 0.55))
        a.blob((s * 0.15, 0.3, 0.04), 0.08, PAW, size=(1.1, 1.3, 0.55))
    a.build_body()
    a.eyes(0.13, 0.75, 0.095, iris=hexcol("4a2416"))
    loc, n = a.hit(0, 0.64)
    a.stick(loc, n, (0, 0.005, 0.01), (0.05, 0.035, 0.035), DARK)
    loc, n = a.hit(0, 0.57)
    a.stick(loc, n, (0, -0.01, -0.01), (0.04, 0.02, 0.03), hexcol("ff7d8f"))
    # flame tuft and tail
    for i, (y, z, r, c) in enumerate([(-0.22, 0.98, 0.09, "ff8a2a"), (-0.2, 1.06, 0.06, "ffc23a"), (-0.18, 1.12, 0.035, "fff0a0")]):
        a.sphere((0, y, z), (r, r, r * 1.3), hexcol(c), glow=True)
    for i, (y, z, r, c) in enumerate([(0.42, 0.42, 0.08, "ff7a22"), (0.5, 0.52, 0.075, "ff9a2a"), (0.55, 0.63, 0.06, "ffc23a"), (0.57, 0.72, 0.04, "fff0a0")]):
        a.sphere((0, y, z), (r, r, r * 1.25), hexcol(c), glow=True)


def magmaw(a):
    ROCK, ROCK2, JAW, LEG = hexcol("43342f"), hexcol("5c4740"), hexcol("2a201e"), hexcol("36292a")
    a.blob((0, 0.12, 0.38), 0.48, ROCK, size=(1.12, 1.15, 0.68))
    a.blob((0, -0.4, 0.46), 0.42, ROCK2, size=(1.1, 0.85, 0.55))
    a.blob((0, -0.42, 0.24), 0.4, JAW, size=(1.05, 0.85, 0.32))
    for x, y, z, r in [(-0.22, 0.05, 0.66, 0.15), (0.24, 0.1, 0.64, 0.14), (0.0, 0.3, 0.6, 0.16), (-0.1, -0.15, 0.68, 0.11), (0.15, 0.42, 0.54, 0.12)]:
        a.blob((x, y, z), r, ROCK2)
    for s in (-1, 1):
        a.blob((s * 0.46, -0.22, 0.15), 0.15, LEG, size=(1, 1, 1.3))
        a.blob((s * 0.48, 0.4, 0.15), 0.17, LEG, size=(1, 1.1, 1.25))
        a.blob((s * 0.3, -0.45, 0.66), 0.1, ROCK2, size=(1, 1, 0.8))  # brow ridges
    a.blob((0, 0.72, 0.25), 0.15, ROCK, size=(0.9, 1.6, 0.7), rot=(-15, 0, 0))
    a.blob((0, 0.98, 0.17), 0.08, ROCK, size=(0.9, 1.6, 0.7), rot=(-15, 0, 0))
    a.build_body()
    # glowing mouth seam and lava cracks
    loc, n = a.hit(0, 0.33)
    a.stick(loc, n, (0, -0.012, 0), (0.36, 0.03, 0.02), hexcol("ff6a1a"), glow=True)
    for i in range(6):
        y = -0.15 + i * 0.13
        x = math.sin(i * 1.7) * 0.18
        loc, n = a.hit(x, 2.0, direction=(0, 0, -1), y=y)
        a.stick(loc, n, (0, 0.005, 0), (0.035, 0.012, 0.13), hexcol("ff7a20"), glow=True, rot=(0, 0, i * 37))
    a.eyes(0.22, 0.6, 0.065, iris=hexcol("ff9d1c"), lid=ROCK2, tilt=-22)
    for s in (-1, 1):
        loc, n = a.hit(s * 0.3, 2.0, direction=(0, 0, -1), y=-0.3)
        a.spike(loc - n * 0.03, n, 0.07, 0.24, hexcol("201818"), bend=(s * 0.4, 0.6, 0))
        for k in range(3):
            loc, n = a.hit(s * (0.08 + k * 0.1), 0.36)
            a.spike(loc + n * 0.01, (0, -0.3, -1), 0.022, 0.07, hexcol("f4ead8"))


def glimmerfox(a):
    FUR, WHITEFUR, GEM, LEG = hexcol("a9c8ef"), hexcol("ffffff"), hexcol("b083ff"), hexcol("8fb0d8")
    a.blob((0, 0.08, 0.5), 0.23, FUR, size=(0.92, 1.65, 0.95))
    a.blob((0, -0.18, 0.56), 0.19, WHITEFUR, size=(1.08, 0.8, 1.12))
    a.blob((0, -0.34, 0.82), 0.2, FUR, size=(1.08, 1.0, 0.95))
    a.blob((0, -0.54, 0.76), 0.09, WHITEFUR, size=(0.95, 1.5, 0.8))
    for s in (-1, 1):
        a.blob((s * 0.16, -0.4, 0.74), 0.08, WHITEFUR, size=(0.9, 0.9, 0.75))
        a.blob((s * 0.1, -0.14, 0.24), 0.065, LEG, size=(1, 1, 2.9))
        a.blob((s * 0.1, 0.32, 0.24), 0.07, LEG, size=(1, 1, 2.8))
        a.blob((s * 0.1, -0.17, 0.035), 0.055, WHITEFUR, size=(1.1, 1.4, 0.6))
        a.blob((s * 0.1, 0.29, 0.035), 0.055, WHITEFUR, size=(1.1, 1.4, 0.6))
    # big fluffy tail
    a.blob((0, 0.44, 0.6), 0.16, FUR, size=(1, 1.4, 1), rot=(-30, 0, 0))
    a.blob((0, 0.62, 0.78), 0.19, FUR, size=(1, 1.2, 1.1), rot=(-55, 0, 0))
    a.blob((0, 0.66, 0.98), 0.15, WHITEFUR, size=(1, 1, 1.1))
    a.build_body()
    a.eyes(0.11, 0.86, 0.07, iris=hexcol("6a3dc4"), tilt=18)
    loc, n = a.hit(0, 0.78)
    a.stick(loc, n, (0, 0.005, 0.01), (0.035, 0.025, 0.025), DARK)
    for s in (-1, 1):
        loc, n = a.hit(s * 0.11, 2.0, direction=(0, 0, -1), y=-0.32)
        a.spike(loc - n * 0.03, (s * 0.25, 0.1, 1), 0.075, 0.27, FUR)
        a.spike(loc - n * 0.0 + __import__("mathutils").Vector((0, -0.025, 0.02)), (s * 0.25, 0.1, 1), 0.04, 0.2, hexcol("e9a6d8"))
    for i in range(4):
        loc, n = a.hit(0, 2.0, direction=(0, 0, -1), y=-0.12 + i * 0.12)
        a.crystal(loc - n * 0.02, 0.03 - i * 0.004, 0.16 - i * 0.025, GEM, rot=(15, 0, 0), glow=True)
    a.crystal((0, 0.66, 1.08), 0.04, 0.14, GEM, glow=True)


def aurorath(a):
    DEEP, LIGHT, GLOW, PINK = hexcol("1f5866"), hexcol("9af2df"), hexcol("7dffe0"), hexcol("ff8ce8")
    a.blob((0, 0.05, 0.64), 0.27, DEEP, size=(0.92, 1.5, 0.88))
    a.blob((0, -0.21, 0.72), 0.21, LIGHT, size=(1.02, 0.8, 1.05))
    a.blob((0, -0.3, 0.86), 0.11, DEEP, size=(1, 1, 1.7), rot=(25, 0, 0))
    a.blob((0, -0.38, 1.04), 0.12, DEEP, size=(1, 1.25, 0.95))
    a.blob((0, -0.52, 1.0), 0.065, LIGHT, size=(1, 1.35, 0.8))
    for s in (-1, 1):
        for y in (-0.12, 0.3):
            a.blob((s * 0.12, y, 0.52), 0.085, DEEP, size=(1, 1.1, 1.5))
            a.blob((s * 0.11, y - 0.01, 0.24), 0.04, DEEP, size=(1, 1, 5.5))
        a.blob((s * 0.1, -0.33, 1.1), 0.045, DEEP, size=(0.6, 1, 1.4), rot=(0, s * -50, 0))
    a.build_body()
    a.eyes(0.075, 1.07, 0.045, iris=hexcol("1a9e8e"), tilt=14)
    # hooves
    for s in (-1, 1):
        for y in (-0.13, 0.29):
            a.sphere((s * 0.11, y, 0.03), (0.05, 0.06, 0.035), PINK, glow=True)
    # crystal antlers
    for s in (-1, 1):
        base = (s * 0.07, -0.36, 1.13)
        a.crystal(base, 0.022, 0.32, GLOW, rot=(-15, s * 28, 0), glow=True)
        a.crystal((s * 0.15, -0.37, 1.3), 0.016, 0.18, GLOW, rot=(-10, s * 70, 0), glow=True)
        a.crystal((s * 0.11, -0.33, 1.25), 0.015, 0.16, PINK, rot=(25, s * 15, 0), glow=True)
    # aurora mane and tail ribbons
    for i in range(6):
        t = i / 5
        a.sphere((0, -0.3 + t * 0.5, 1.02 - t * 0.28), (0.025, 0.07, 0.06), GLOW if i % 2 == 0 else PINK, glow=True, rot=(-30, 0, 0))
    for i in range(4):
        a.sphere((0, 0.4 + i * 0.09, 0.66 - i * 0.07), (0.03, 0.07, 0.05), PINK if i % 2 == 0 else GLOW, glow=True, rot=(-40, 0, 0))
    for i in range(3):
        ang = i / 3 * math.tau
        a.sphere((math.cos(ang) * 0.45, math.sin(ang) * 0.45, 0.85 + i * 0.08), (0.04, 0.04, 0.04), GLOW if i != 1 else PINK, glow=True)


CREATURES = {
    "Mossling": (mossling, dict(distance=2.9, target=(0, 0, 0.5))),
    "Thornback": (thornback, dict(distance=3.6, target=(0, -0.1, 0.45))),
    "Cinderpup": (cinderpup, dict(distance=3.0, target=(0, 0, 0.55))),
    "Magmaw": (magmaw, dict(distance=3.6, target=(0, 0, 0.4))),
    "Glimmerfox": (glimmerfox, dict(distance=3.4, target=(0, 0.1, 0.6))),
    "Aurorath": (aurorath, dict(distance=3.8, target=(0, 0, 0.7))),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    out = args[0]
    names = args[1:] or list(CREATURES)
    os.makedirs(out, exist_ok=True)
    manifest_path = os.path.join(out, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    for name in names:
        fn, view = CREATURES[name]
        reset()
        a = Asset(name)
        fn(a)
        objs = a.finish(out)
        export_fbx(objs, os.path.join(out, name + ".fbx"))
        zmax = max((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
        manifest[name] = {"height": round(zmax, 4), "tris": sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)}
        preview_scene(target=view["target"], distance=view["distance"], angle=-30, height=0.22)
        render(os.path.join(out, name + "_preview.png"), 720, 560, samples=40)
        print("BUILT", name, manifest[name])
    json.dump(manifest, open(manifest_path, "w"), indent=2)


main()
