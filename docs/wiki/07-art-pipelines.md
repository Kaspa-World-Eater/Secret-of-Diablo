<!-- Art · updated 2026-09-29 · 1164 words · source page #pipelines -->
# 07 · Art pipelines: how art gets made (and what failed)

## 1. PixelLab (heroes, lanterns, world pieces) — the current pipeline

- **Account:** Tier 2, 5,000 generations per cycle, resets on the 28th. On 2026-09-29 the user said to spend down to about zero and wait; ~80 were left after v72. **Next reset: Oct 28.**

- **Token:** only in `~/.pixellab/token` (chmod 600). Never print it or put it in game or project files. The user was advised to rotate it. Never delete the user's PixelLab characters.

- **Client (`~/.pixellab/`):** `mcp.py` (`init`, `call`), `img.py` (`durl`, `run`, `poll`), `dl.py` (character download; 423 while jobs run), `runq2.py` (animation queue; entries `[name, desc, frames, dirs?]`). Concurrency limit 10 jobs.

- **Heroes are generated without lanterns and bare-handed.** The lantern is its own sprite (`data/lanterns.js`: `iron` 22×35 k4 for the Hemomancer, `gold` 16×35 for the Mystic) and floats in code.

- **Current states:** Hemomancer "Penitent" `2c84fefa-ae41-4ca6-8ba8-f8507eff72a9`; Mystic "Trinkets" `b6035f8c-2baf-4c85-8483-e209b22a5784`. Animations: walk, idle, attack, attack2, cast, hit, death, dodge.

- **Packing (`/tmp/port/port.py` + `template.js`, rebuild from this if the session's /tmp is gone):** output HHD format, frame 258×249, K=3, anchor 129,234 → `data/hhd_.js` + `src/zz_hero__r8.js`. Options:

- `palclean`: drop colours not in the rotation's palette (PixelLab's glows and slashes); a frame with a big effect reuses the previous frame;

- `clip`: sets `meta.clip` so the code lantern is drawn;

- `fxclean`, `noglow`, `darklegs`, and `SUB` (per-view picks).

- **World pieces:** `data/w61.js` replaces W55 pieces at the heroes' grain (hr 3 or 4); textures in `data/wtex.js`; decor in `data/decor66.js`.

- **What goes wrong:** effects baked into action frames (fix with palclean); a regenerated state can change the face or add a second lantern (clip lanterns in code instead); large creatures come out cartoony at available sizes (the Hollow King) — park them rather than ship them.

## 2. Porting the user's own art

- Crop, cut the ground away, scale every frame by one factor; one shared palette (e.g. 48 colours), no dithering, dark outline, feet anchored. Examples: `hemo_port/build_r6.py` (the old r6 Hemomancer from the user's Midjourney videos), the Stranger's WebP in `zz_art_rd0_stranger.js`.

- **The approved HD monk:** baked in `show64/px_monk/bake.js` (v48) with designed flat shadow shapes and hand-typed pixel maps for faces and hands; ported by `monk_port/port.py` into `zz_hero_monk_hd.js` (`_hr` twin at 3× world grain).

## 3. Claude's own art on the grid (`own_art/px.py`, v0.54)

- Parts as flat shapes on the sprite's native grid, each with one colour ramp; shaded by its own silhouette (lit band upper-left, shade band lower-right, one-step cast shadow from a part in front); dark seams where parts cross; a selective outline; faces and hands as typed pixel maps; details pixel by pixel.

- First piece: **the Kneeler, pass 8** (`own_art/kneeler8.py` → `mk_kneeler_js.py` → `zz_mon_kneeler.js`), 100×88 hr frames: idle 4, walk 8, wind 3, attack 3, hit 2, death 1.

- Don't use the old `own_art/kit.py` (paint at 4×, area-average down): it made blobs and tubes.

## 4. Code-drawn art

- **HUD** (`scratchpad/hud54/`): `hud54.py` bakes the slab; `serpents.py` draws the stone ouroboroi; `head.js` + `gen.py` write `zz_hud54.js`. The glass liquids are painted in flat steps and now repaint only when needed.

- **Title** (`zp_title.js`, `zz_title54.js`): height maps lit by point lights, snapped to hand-picked palettes with ordered dither.

- **Ground scatter, canopy, wisps, lantern glow, shadows:** code-drawn at twice world grain (see 06 §4).

## 5. Engine grain

- Logical canvas 480×270; RS 4 on desktop, 2 on phones (the canvas is 960×540 internally in the browser build).

- World camera ZK 1.0 since v0.54: one world pixel = 4 screen px on desktop. Creatures and heroes draw at 0.75 about their feet (`zz_worldscale.js`), so the world is a third larger around them.

- Sprites carry an `_hr` twin drawn through the `drawImage` override (`_drawImage` is the raw call).

## 6. Rejected approaches (don't repeat)

| Approach | When | Why it failed |
|---|---|---|
| Rounded sculpts | v0.22 | "old school 3D" |
| Normal-mapped runtime sculpts | v0.37–v0.41 | "that ugly 3D look again", and slow |
| Replacing the game with an HD demo built by nine agents | v0.50 | replaced instead of upgraded; little review |
| Kneeler pass 6 (`kit.py`) | v0.53 | "Batman with no legs… blobby and tube like, no details" |
| Hand-drawn procedural hero | v0.57 | "ugly" |
| Straight cut-outs of Midjourney frames | v0.57 | "looks weird", missing legs, inconsistent frames |
| Optical-flow in-betweens of Midjourney stills | v0.57 | the upper body only bobbed; low-res flow noisy |
| 2D puppet with pasted feet | v0.57 | feet floated, skirt dead |
| Blender model skinned from the user's paintings (MakeHuman body, cloth-sim skirt, 88 simulated dreadlocks, texture baked from four Midjourney views) | v0.58 | smudged textures where details didn't sit on geometry; flat renders "don't look 2D". Scripts in `scratchpad/hemo3d/` |
| PixelOver animation | 2026-09-29 | the user chose PixelLab animations instead |
| PixelLab Hemomancer with the lantern at the waist | 2026-09-29 | wrong face and two lanterns → clip lanterns in code |
| PixelLab Hollow King | 2026-09-29 | cartoony, "doesn't fit our world" |

**What worked:** porting the user's own art faithfully; the HD monk bake; drawing on the grid with designed shadow shapes; PixelLab with palclean and code-clipped lanterns.

## 7. Motion notes (what each action must show; from the v0.58 motion study)

User: "a body moves... it has dynamic movement, not just two legs jiggling back and forth. The upper body moves too."
- **Walk:** the pelvis rides over the planted foot (lowest just after heel strike, highest mid-stance), sways toward the stance leg and drops on the swing side; the chest counter-twists against the hips; arms swing against the legs with the elbow trailing; head steady and bowed; heel strike, roll, toe push, arcing swing. A heavy man leans slightly into his walk.
- **Run:** forward lean from the ankles; a flight phase; arms pump bent; bigger twist; a hard drop on landing, then a spring.
- **Strike:** anticipation (weight back, torso coiled, fist by the head) → the drive runs hips, chest, shoulder, fist like a whip → weight crashes onto the front foot → follow-through past the target → recover.
- **Block:** a wider stance side-on; arms over head and chest, chin tucked; absorb impact through the knees.
- **Stagger / hit:** the struck part is thrown first (chest back, head snaps); arms fly out; the feet scramble a step back; settle into guard.
- **Death:** reeling → the knees go → slump forward onto the knees → roll to one side; compact enough to fit the frame.
- **Cast (the Hemomancer's bloodletting):** the bound arm raised, head thrown back, chest open.
- **Dodge:** a low quick sidestep led by the hips; hair and cloth trail.
- **Feel (from the game study):** pose-to-pose timing; holds on key poses and fast frames on swings; smears and one-frame impact frames instead of more frames; no glows.
