# Secret of Diablo

**Godmarrow in Secret of Mana's clothes.** Everything from Godmarrow (its four ported orders, 156 skills,
68 kinds of creature, items and affixes, the body board, the Reading, grave vows, quests, Act I's 26 zones, the
lantern, the dark and the day, the HUD, the music and its rules) runs here in a **top-down, Secret of Mana view** with
**free LPC art**. Godmarrow is the Diablo-feel version; this is the Secret of Mana-feel version.

Godot **4.7.2**, GDScript, Compatibility renderer.

## Play
Open `project.godot` in Godot 4.7.2 and press F5. (The first open imports the art; give it a minute.)
Test hooks (after `--`): `--zone=moor --cls=ossumancer --new --lvl=12 --learn=all:3 --demo --at=80,60 --hour=0.5`.
See `core/test_hooks.gd`.

## What changed from Godmarrow
| Area | Godmarrow | Here |
|---|---|---|
| Camera / grid | isometric diamonds | top-down squares: `core/iso.gd` (one file turns every system top-down) |
| Ground, walls, props | Godmarrow's painted art | LPC autotiled ground, cliff/wall tiles, LPC props: `world/topdown.gd` |
| Characters / creatures | PixelForge / painter sets | LPC composites in Godmarrow's atlas format: `art/sprites/` + `skins.json` |
| Facing | 5 iso views + mirror | 4 directions (down / up / side, mirrored for left): `entities/anim_sprite.gd` |
| Palette | painted grimdark | free art pulled to Godmarrow's muddy palette by `shaders/grade.gdshader` |

Everything else is Godmarrow's code and data, unchanged. Its rules apply (see `docs/wiki/01-rules-and-decisions.md`).

## Rebuilding the art
The art is generated from the free packs listed in `CREDITS.md`:
```
LPC_SRC=/path/to/packs godot --headless --path . --script res://tools/build_lpc_sets.gd    # characters + skins.json
LPC_SRC=/path/to/packs godot --headless --path . --script res://tools/build_lpc_world.gd   # terrain + props
```

## Tests
`GODOT=/path/to/godot tools/smoke.sh OUT.txt` — every order, champions, sigils, every panel, the title. Must print errors 0.

## Docs
- `docs/GODMARROW_HANDOFF.md`, `docs/GODMARROW_PORTING.md` — Godmarrow's architecture and hand-off.
- `docs/wiki/` — the design wiki and the rules (law).
- `PLAN.md` — this project's plan and steps.
- `legacy/sandbox/` — the first Secret of Diablo prototype (Godot 4.3), kept playable.
