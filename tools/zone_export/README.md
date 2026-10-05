# Zone export: the browser's maps for the Godot build

Godot doesn't generate maps itself. The browser build's generators (`web/triune_desktop`, the reference) make
them, and these tools write each zone at many seeds into `data/zones/<id>_s<seed>.json.gz`. A new game picks one
seed per zone (`core/game.gd seed_for`), so each run is a different world.

| File | What it does |
| --- | --- |
| `build.sh OUT.html` | builds the browser game (as `build_x.sh` does) with `hook.js` spliced inside its closure |
| `hook.js` | `window.__zx.zone(id, seed)` generates a zone the way a new game at that seed would, runs one full draw pass, records every painted piece drawn (key, foot in tiles, depth, flip), and returns the Godot zone format |
| `cdp.mjs` | drives headless Chrome or Edge over the DevTools protocol, with no packages to install |
| `export.mjs` | every Act I zone at N seeds, in parallel browsers; rewrites `data/zones/index.json` |
| `check.py` | for every exported map: is every exit, lantern-stone, waystone, chest and shrine reachable from where you arrive? |
| `compare.mjs ZONE SEED [HOUR] [CLS]` | the same zone, seed and hour in the browser (left) and Godot (right), side by side in `docs/screens/compare/` |

```
node tools/zone_export/export.mjs --seeds=20 --first=1001 --workers=8   # about 50 min for all of Act I
python tools/zone_export/check.py                                       # every map walkable
node tools/zone_export/compare.mjs moor 1003 0.75                       # the moor at night, both builds
```

Godot test flag: `--zseed=S` loads every zone at exported seed S (with `--zone`, `--hour`, `--shot`).

The browser stays the source of truth for what a map is. To change generation, change `web/triune_desktop/src`,
then export again.
