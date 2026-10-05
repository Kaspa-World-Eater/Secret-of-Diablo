# Custom sprites

Every unit has a sprite key. If `res://assets/sprites/<key>.json` exists, that unit is drawn with
your sprite sheet instead of the placeholder art. No code changes needed.

| Key | Unit |
|---|---|
| `necromancer` | Player |
| `merc` | Mercenary |
| `skeleton`, `skel_mage` | Skeletons / mages |
| `clay_golem`, `blood_golem`, `iron_golem`, `fire_golem` | Golems |
| `hopper`, `shroom`, `goblin`, `goblin_archer`, `ghoul`, `wisp` | Monsters |

## Config format (`necromancer.json`)
```json
{
  "sheet": "necromancer.png",
  "frame_size": [32, 32],
  "offset": [0, -16],
  "scale": 1.0,
  "animations": {
    "idle_down":  {"frames": [[0, 0]], "fps": 1},
    "walk_down":  {"frames": [[0, 0], [1, 0], [2, 0], [1, 0]], "fps": 8},
    "walk_up":    {"frames": [[0, 1], [1, 1], [2, 1], [1, 1]], "fps": 8},
    "walk_right": {"frames": [[0, 2], [1, 2], [2, 2], [1, 2]], "fps": 8},
    "attack_down":{"frames": [[3, 0], [4, 0]], "fps": 10, "loop": false}
  }
}
```
- Frames are `[column, row]` on a grid of `frame_size`, or `[x, y, w, h]` pixel rectangles for irregular sheets.
- Animation names are `<state>_<direction>`; states: `idle`, `walk`, `attack`; directions: `down`, `up`, `left`, `right`.
- Missing `left` is auto-mirrored from `right` (and vice versa). Missing states fall back to walk/idle.
- `offset` positions the sprite relative to the unit's feet.

Sprites from Secret of Mana / Diablo 2 are copyrighted — fine for a private build from your own copy,
but swap in original art before sharing publicly.
