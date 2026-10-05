# Drop your Secret of Mana exports here

Everything in this folder comes from **your own copy** of the game. You export the files,
put them here and push. Claude does the rest: imports, cleanup, animation mapping and collision.

> **Keep the GitHub repo private** once these files are in it.

## What you need
1. Your game as an SNES ROM file (`.sfc`), e.g. dumped from your own cartridge.
2. **Mesen**, a free SNES emulator with export tools: https://www.mesen.ca

Open the `.sfc` in Mesen and play to the area you want.

## Levels → `assets/rip/maps/<area_name>/`
For each area (e.g. `potos`, `gaia_navel`, `upper_land_spring`):
1. Stand in the area. Open **Debug → Tilemap Viewer**.
2. Select **BG2** (ground layer), right-click the map → **Export to PNG** → save as `1_bg2.png`.
3. Select **BG1** (trees, roofs, overhangs) → export → save as `2_bg1.png`.
4. Put both in a folder named after the area.

The game loads big areas in pieces as you walk, so one export may only show part of an area.
If so, walk to another part and export again (`1_bg2_b.png`, `2_bg1_b.png`, …). Claude will stitch them.

Optional `zone.json` in the folder:
```json
{"tile": 16, "level": 3, "transparent": [0, 0, 0]}
```
`level` = monster level for that area. `transparent` = the colour Mesen shows for "empty" on BG1.

## Characters and monsters → `assets/rip/sprites/<name>/`
Folder names that hook up automatically: `necromancer` (player), `merc`, `skeleton`, `skel_mage`,
`clay_golem`, `blood_golem`, `iron_golem`, `fire_golem`, `hopper` (Rabite), `shroom` (Mushboom),
`goblin`, `goblin_archer`, `ghoul`, `wisp`, `shade`. Any other name is fine too; Claude will map it.

Easiest way: get the character on screen and press **F12** (screenshot) while it walks, attacks and
gets hit in each direction. Step frame by frame with **Debug → Debugger → Step (one frame)** to
catch every pose. Dump the screenshots in the folder, as many as you like; duplicates are removed.
(**Debug → Sprite Viewer → Export** also works.)

## Music & sounds → `assets/rip/audio/` (later)
**Tools → Sound Recorder** in Mesen, one file per track/effect.

## Then
Push, and tell Claude "new rip files are in". Claude will run:
```
godot --headless --path . --script res://tools/import_rip.gd
```
…then map animations, paint collision and check everything in-game.

In game: **F10** travels between the wilderness and imported areas, **F9** opens the collision painter.
