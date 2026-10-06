#!/usr/bin/env python3
"""The Reading's cards (ui/reading.gd) with free art: each emblem a game-icons.net icon (CC BY 3.0, see CREDITS.md)
set in pale gold on a dark card with a bronze frame, and a patterned back. 54 x 84, as the Reading draws them.

    GI=/path/to/game-icons/icons/ffffff/transparent/1x1 python3 tools/build_reading_cards.py   (needs Pillow)
"""
import glob
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
W, H = 54, 84
EMB = 34

ICON = {
    "bell": "ringing-bell", "blacksun": "barbed-sun", "bones": "crossed-bones", "bowl": "bowl-spiral",
    "breath": "wind-slap", "candle": "candle-flame", "coin": "crown-coin", "crown": "crenel-crown",
    "cup": "jeweled-chalice", "dagger": "broad-dagger", "door": "door", "drop": "water-drop", "eye": "all-seeing-eye",
    "feather": "feather", "flame": "flame", "grave": "tombstone", "hammer": "warhammer", "hand": "hand",
    "hanged": "tarot-12-the-hanged-man", "heart": "hearts", "key": "pendant-key", "kiln": "furnace",
    "lantern": "old-lantern", "mirror": "mirror-mirror", "moon": "moon", "mountain": "mountains", "mouth": "lips",
    "saint": "spiked-halo", "shadow": "shadow-follower", "skull": "death-skull", "spool": "sewing-string",
    "staff": "wizard-staff", "stone": "stone-block", "sun": "striped-sun", "waves": "waves", "weep": "tear-tracks",
    "wheel": "stone-wheel",
}

INK = (20, 14, 17, 255)
FACE_TOP = (46, 31, 28)
FACE_LOW = (26, 18, 20)
BRONZE = (122, 90, 46, 255)
BRONZE_HI = (176, 136, 74, 255)
GOLD = (231, 207, 154)


def find_icon(gi, name):
    hits = glob.glob(os.path.join(gi, "*", name + ".png"))
    return hits[0] if hits else None


def blank(top, low):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(H):
        k = y / (H - 1)
        c = tuple(int(top[i] * (1 - k) + low[i] * k) for i in range(3)) + (255,)
        d.line([(0, y), (W - 1, y)], fill=c)
    # rounded corners: knock out the four corner pixels
    for x, y in ((0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)):
        img.putpixel((x, y), (0, 0, 0, 0))
    d.rectangle([0, 0, W - 1, H - 1], outline=INK)
    d.rectangle([2, 2, W - 3, H - 3], outline=BRONZE)
    d.line([(3, 3), (W - 4, 3)], fill=BRONZE_HI)
    return img, d


def emblem(path, size, col):
    ic = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            a = ic.getpixel((x, y))[3]
            if a > 110:                       # crisp pixel edges, no soft halo
                out.putpixel((x, y), col + (255,))
    return out


def face(gi, emb):
    img, d = blank(FACE_TOP, FACE_LOW)
    path = find_icon(gi, ICON[emb])
    if path:
        e = emblem(path, EMB, GOLD)
        img.alpha_composite(e, ((W - EMB) // 2, (H - EMB) // 2 - 4))
    # pips top and bottom
    for y in (8, H - 10):
        d.rectangle([W // 2 - 1, y, W // 2, y + 1], fill=BRONZE_HI)
    d.line([(10, H - 18), (W - 11, H - 18)], fill=BRONZE)
    return img


def back(gi):
    img, d = blank((34, 22, 24), (22, 15, 18))
    # a diamond lattice in dull bronze
    for y in range(5, H - 5):
        for x in range(5, W - 5):
            if (x + y) % 8 == 0 or (x - y) % 8 == 0:
                img.putpixel((x, y), (74, 54, 34, 255))
    path = find_icon(gi, "all-seeing-eye")
    if path:
        e = emblem(path, 26, (150, 116, 66))
        d.rectangle([W // 2 - 15, H // 2 - 15, W // 2 + 14, H // 2 + 14], fill=(26, 18, 20, 255), outline=BRONZE)
        img.alpha_composite(e, ((W - 26) // 2, (H - 26) // 2))
    return img


def main():
    gi = os.environ.get("GI", "")
    if not gi or not os.path.isdir(gi):
        raise SystemExit("Set GI to game-icons' icons/ffffff/transparent/1x1 folder")
    out = os.path.join(ROOT, "art", "reading", "cards")
    os.makedirs(out, exist_ok=True)
    for emb in ICON:
        face(gi, emb).save(os.path.join(out, emb + ".png"))
    back(gi).save(os.path.join(out, "_back.png"))
    print("reading cards: %d faces and a back" % len(ICON))


if __name__ == "__main__":
    main()
