#!/usr/bin/env python3
"""The Bone Spear's picture, drawn here from nothing (no outside art): a jagged spike of pale cold bone, knuckled like
a spine, barbs swept back, in 32 headings, written as art/fx/bone_spear.png + .json in the format
skills/ossumancer/fx.gd reads (frames: rect, anchor, angle in screen degrees, 0 = right, 90 = down).

    python3 tools/build_bone_spear.py      (needs Pillow)
"""
import json
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
CELL = 52
N = 32
LEN = 46.0          # tip to tail, art px

BONE_HI = (246, 244, 236)
BONE = (222, 218, 204)
BONE_MID = (184, 180, 166)
BONE_LO = (128, 126, 118)
OUTLINE = (38, 36, 44)
COLD = (200, 222, 255)


def in_tri(px, py, a, b, c):
    def side(p1, p2):
        return (px - p2[0]) * (p1[1] - p2[1]) - (p1[0] - p2[0]) * (py - p2[1])
    d1, d2, d3 = side(a, b), side(b, c), side(c, a)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def shape(x, y):
    """The spear along +x, tail at 0, tip at LEN; y across. Returns None outside, else a shade 0..3."""
    ay = abs(y)
    # the head: a long leaf of bone tapering to the point
    if 30.0 <= x <= LEN:
        w = 4.6 * (LEN - x) / (LEN - 30.0) + 0.6
        if ay <= w:
            if x > LEN - 4.0:
                return 0                       # the bright point
            return 0 if y < -0.8 else (1 if y < 1.4 else 2)
    # the barbs swept back from the head's base
    if in_tri(x, ay, (31.0, 1.8), (21.5, 7.8), (26.5, 1.8)):
        return 1 if y < 0 else 2
    # the shaft: a spine of knuckles
    if 0.0 <= x <= 31.0:
        ph = (x % 6.5) / 6.5
        knuckle = max(0.0, 1.0 - abs(ph - 0.5) * 4.0)
        w = 2.1 + 1.6 * knuckle
        if ay <= w:
            if knuckle > 0.6 and ay > w - 1.0:
                return 2                      # the knuckle's rim
            return 0 if y < -1.0 else (1 if y < 1.2 else 3)
    # the splintered tail
    if -4.0 <= x < 0.0:
        jag = 1.8 * (x + 4.0) / 4.0 + (0.8 if int((y + 8) * 1.7) % 2 else 0.0)
        if ay <= jag:
            return 3
    return None


SHADES = [BONE_HI, BONE, BONE_MID, BONE_LO]


def frame(angle_deg):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    c = CELL / 2.0
    mask = {}
    for j in range(CELL):
        for i in range(CELL):
            dx, dy = i + 0.5 - c, j + 0.5 - c
            # into the spear's own frame (centre of the spear at the cell's centre)
            lx = dx * ca + dy * sa + LEN / 2.0
            ly = -dx * sa + dy * ca
            s = shape(lx, ly)
            if s is not None:
                mask[(i, j)] = s
    for (i, j), s in mask.items():
        r, g, b = SHADES[s]
        px[i, j] = (r, g, b, 255)
    # a one-pixel dark outline, and a faint cold rim on the outline's outer side toward the light (up)
    for j in range(CELL):
        for i in range(CELL):
            if (i, j) in mask:
                continue
            near = any((i + di, j + dj) in mask for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if near:
                px[i, j] = OUTLINE + (255,)
    return img


def main():
    sheet = Image.new("RGBA", (CELL * N, CELL), (0, 0, 0, 0))
    frames = []
    for k in range(N):
        ang = k * 360.0 / N
        sheet.paste(frame(ang), (k * CELL, 0))
        frames.append({"rect": [k * CELL, 0, CELL, CELL], "anchor": [CELL / 2.0, CELL / 2.0], "angle": round(ang, 2)})
    out = os.path.join(ROOT, "art", "fx")
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, "bone_spear.png"))
    with open(os.path.join(out, "bone_spear.json"), "w") as f:
        json.dump({"about": "The Bone Spear in 32 headings, drawn by tools/build_bone_spear.py (no outside art)",
                   "frames": frames}, f)
    print("bone_spear: %d headings" % N)


if __name__ == "__main__":
    main()
