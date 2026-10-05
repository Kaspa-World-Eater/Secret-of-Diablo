"""Check every exported zone (data/zones/*.json.gz) the way a pilgrim would meet it: from where you arrive, can you
walk to every exit, lantern-stone, waystone, chest and shrine? Solid tiles are world/zone.gd's SOLID_TYPES; a body is
0.25 yd round, so a gap must be a whole tile wide (no diagonal squeezing between two solid corners).

python tools/zone_export/check.py [ZONE ...]   prints one line per zone-seed and every problem; exit 1 if any.
"""
import glob, gzip, json, os, sys
from collections import deque

SOLID = {2, 3, 4, 5, 7, 8, 9, 10, 15}
HERE = os.path.dirname(os.path.abspath(__file__))
ZONES = os.path.join(HERE, '..', '..', 'data', 'zones')


def flat(c):
    out = []
    for k in range(0, len(c), 2):
        out += [c[k]] * c[k + 1]
    return out


def reach(w, h, t, sx, sy):
    seen = bytearray(w * h)
    sx, sy = int(sx), int(sy)
    q = deque()
    # start on the nearest open tile (an arrival point may sit on a portal's own tile)
    for r in range(0, 4):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                x, y = sx + dx, sy + dy
                if 0 <= x < w and 0 <= y < h and t[y * w + x] not in SOLID and not q:
                    q.append((x, y)); seen[y * w + x] = 1
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and t[ny * w + nx] not in SOLID:
                seen[ny * w + nx] = 1
                q.append((nx, ny))
    return seen


def near(seen, w, h, x, y, r=1):
    """an object is usable if an open tile within r of it is reached"""
    x, y = int(x), int(y)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if 0 <= x + dx < w and 0 <= y + dy < h and seen[(y + dy) * w + x + dx]:
                return True
    return False


def check(path):
    d = json.loads(gzip.open(path).read()) if path.endswith('.gz') else json.load(open(path, encoding='utf-8'))
    w, h = d['grid']['w'], d['grid']['h']
    t = flat(d['grid']['cells'])
    m = d.get('markers', {})
    st = m.get('start') or next(iter(d.get('arrive', {}).values()), None)
    probs = []
    if not st:
        return d['id'], ['no start or arrival point']
    seen = reach(w, h, t, st['x'], st['y'])
    for k, a in d.get('arrive', {}).items():
        if not near(seen, w, h, a['x'], a['y'], 2):
            probs.append(f'arrival from {k} at ({a["x"]},{a["y"]}) cut off from the start')
    for i, o in enumerate(d['objects']):
        ty = o.get('type')
        if ty in ('portal', 'lantern', 'chest', 'shrine', 'altar') or o.get('q') in ('wp', 'npc'):
            if not near(seen, w, h, o['x'], o['y'], 2 if ty == 'portal' or o.get('q') == 'wp' else 1):
                probs.append(f'{ty}{"/" + o["q"] if o.get("q") else ""} {o.get("name", o.get("to", ""))} at ({o["x"]},{o["y"]}) unreachable')
    open_n = sum(seen)
    return f'{d["id"]} s{d["seed"]} {w}x{h} open {open_n}', probs


if __name__ == '__main__':
    want = set(sys.argv[1:])
    files = sorted(glob.glob(os.path.join(ZONES, '*.json.gz')))
    bad = 0
    for f in files:
        zid = os.path.basename(f).rsplit('_s', 1)[0]
        if want and zid not in want:
            continue
        name, probs = check(f)
        print(name + ('' if not probs else '  <<  ' + '; '.join(probs[:6]) + (f' (+{len(probs) - 6})' if len(probs) > 6 else '')))
        bad += bool(probs)
    print(f'{bad} zone-seed(s) with problems of {len(files)}')
    sys.exit(1 if bad else 0)
