<!-- Art · updated 2026-09-29 · 1320 words · source page #art -->
# 06 · Art direction: the standard, the family, the light

*The art law is summarised in `01-rules-and-decisions.md`. How to judge a piece: `claude/godmarrow-art-judge-primer.md`. How art is made: `07-art-pipelines.md`. The Claude Doc "Triune Art Codex" (https://claude.ai/code/artifact/cd53d6bb-57fc-49d4-90b5-cfaacbecf26a) holds the ten hard rules and the banned list.*

## 1. The standard

- **Register:** grimdark hand-made pixel art, Dark Souls fan pixel art and Blasphemous. The title screen is the quality bar.

- **Values:** darkness is the canvas; light is scarce, so where it lands matters. Scenes ~85–90% dark; figures mostly mid-tones (30–57% dark, 43–67% mid) with one lighter focal area.

- **Temperature:** shadows lean cool (teal, slate, violet); lights warm only where a real source exists. Never grey-on-grey. **No red light.**

- **Materials:** three or four flat values per material, stepped hard; folds as a dark valley beside a lit ridge; hems in long ragged strips; texture as 1–2 px clusters, never even noise; glints only as single pixels on metal.

- **Proportions:** realistic, 7.5–8 heads, grounded, heavy; never chibi.

- **Colour:** everything muted and hue-shifted, plus **one bold saturated mass per figure**.

- **Never 3D:** no tube limbs, balloon muscles, soft gradients, evenly-lit render look, or plastic/clay feel. A posing rig may place limbs and outlines, never decide a colour or shadow.

- **Depth by haze:** far things lighter, cooler, flatter; small figures in a huge world.

- **Everything worn:** chipped stone, torn cloth, dented metal, moss and grass pushing through.

- **Mood references** (in `scratchpad/refs/`): the user's monk references `refs/monk_std` (top standard for heroes), `ref_red_knight.png` (heroes), `ref_blasphemous.png` (world and scale), `ref_gravelord.png` (creatures), `ref_bonfire_knight.png` (fire), gallery `refs/style/s01–s18` (see the primer for what each teaches).

## 2. The hero family (from the Hero Bible, still the target)

The five heroes are pilgrims of one dead god and must read as **five people from one world, drawn by one hand**.
- **One grain, one scale:** frame 256×248, anchor [128,234]; one art pixel = one screen pixel at hero grain; heights by build (Hemomancer tallest ~176, Keeper shortest ~160).
- **One light:** a key from the upper left, a hard terminator, designed shadow shapes; a cool rim on the right; an outline tinted with the material's hue.
- **One accent each**, so they're told apart at a glance:

| Hero | Muted base | The one bold mass | Silhouette at 40 px |
|---|---|---|---|
| The Empty Hand | ash robe, umber skin | dried-blood vermilion shawl | dome and beard |
| Hemomancer | dark brown skin, iron, church cloth | fresh wet crimson (blood on cloth and wounds) | a wide inverted triangle (redo pending) |
| Ossuarch | black quilted cassock, bone plates | saffron sash and fringe | an exclamation mark |
| Hollow Mystic | slate coat, iron | cold silver-blue mirrors and soul-wire | a tall hat over a bell of coat |
| Shrine Keeper | white robe, madder hakama | miasma violet | a wide disc over a flaring triangle |

- **Physiques:** each body says how that hero fights. The Empty Hand gaunt and self-mummified (done). The Hemomancer the heaviest body, broad shoulders, deep chest, heavy arms; **brutal penitent, not a mummy, not tribal** (see `claude/godmarrow-class-hemomancer.md` §Look for the redo brief). The Ossuarch tall and bone-lean, never bends. The Mystic long-limbed, craning, listening. The Keeper compact and athletic.

- **Hands free** until weapons come as separate layers.

## 3. Lighting and cinematography (the world's language)

User: *"Shadows bring life to a world just like light does. Cinematography is key... Lighting drives moods and feelings."*

**Principles**
1. **Motivated light:** every light has a visible source (lantern, brazier, moon).
2. **Low key / chiaroscuro:** mostly dark, pockets of light. What you can't see does the work.
3. **Shadow is information:** contact, direction, time of day, threat.
4. **Key / fill / rim:** the lantern is the key; the moon or sky a low cool fill; rim light separates figures from the dark.
5. **Temperature is emotion:** warm = human, safe; cool = the outside, the dead.
6. **Restraint:** take light away rather than add it.
7. **Hard vs soft:** small close sources throw long hard shadows; big distant ones short soft shadows.
8. **The brightest spot leads the eye:** loot, paths, exits in light; threats at the edges.
9. **Practicals layer depth:** lamps in scene give dark foreground, lit midground, glimmering background.
10. **Moving light makes frames alive:** flicker, swing, breath.

**Reference lessons:** Deakins' flare-lit town in *1917* (one moving source, shifting silhouettes); Playdead's *Limbo/Inside* (harsh light against long shadows, silhouettes, selective light, dithering against banding); *Hyper Light Drifter* (analogous darks, complementary lights); Diablo II (light radius as a stat and a feeling); FromSoftware (warm islands in a cold world). Full study: `10-study-great-games.md`.

**In the game:** the lantern pool; world flames' pools; the hero's silhouette shadow (lantern, flames, sun); lantern-cast monster shadows; eye-shine; loot glints; the lantern's mood; rare distant lightning; blue-teal darkness; wisps as small lights; atmosphere (mist, dust, soul-lights, leaves, clouds, gusts) subtle and rare (`zz_atmos62.js`); the per-land grade (`zz_grade55.js`, dusk tint cool, no red).

## 4. The world's surface

- **Tiles and props:** `zt_env32.js` (procedural tiles, trees, props); the world is drawn a third larger around the characters since v0.54 (`zz_worldscale.js`).

- **PixelLab world pieces** (`data/w61.js`): Act I trees in stages, rocks, graves, cairns, rubble, bones, shrubs, stumps, pillars, coffins, shrine, braziers, candles, gate, waypoints, chests, lantern post, cave, stairs, gallows, arch, bells, fences, banners, sconces, offerings, skulls, fungus, lilies, chains, cobwebs, puddles. Walls and cliffs re-surfaced with PixelLab textures (`data/wtex.js`, `zz_walls63.js`).

- **Decor** (`data/decor66.js`, `zz_zz_decor66.js`): the Hide's organic hints, the dead herd, pilgrims' camps, wayside statues, gibbet cages.

- **Ground detail (v78, `zz_zz_world77.js`):** non-solid per-land scatter at twice world grain. Wood: leaf litter, twigs, moss, mushrooms, grass. Moor: stones, ash, bone chips, black glass, straw. Fen: reeds with cattails, wet stones, moss, puddles. Heath: ash, charcoal, bone. Grass and reeds sway with the wind; paved roads get a rare weed or loose stone. **Canopy dapple** drifts over the woods by day.

## 5. State of the art (v78)

| Piece | State |
|---|---|
| Hemomancer | PixelLab "Penitent" (walk, idle, attack, attack2, cast, hit, death, dodge). Reads as a mummy → **full redo planned** |
| Hollow Mystic | PixelLab "Trinkets", same animation set; good |
| The Empty Hand | the approved HD monk bake |
| Ossuarch | painter with per-skill bone weapons; **out of commission** |
| Shrine Keeper | 32-bit painter, below standard |
| Lanterns | PixelLab iron (Hemomancer) and gold filigree (Mystic), floating in code |
| Creatures | M32 painters; the Kneeler drawn on the grid by Claude; HD boss sheets baked but not in game |
| The Hollow King | PixelLab art came out cartoony; parked (`data_off/king.js`) |
| HUD | carved slab, bronze rail, stone ouroboros serpents holding the glass orbs |
| Title | code-generated face and bowl, GODMARROW in stepped bronze, menu on the blood |
| World | procedural tiles + PixelLab props and wall textures + decor + ground scatter; ground tiles themselves still the old painted ground; Acts II–V use the nearest Act I palettes |
| Body board | an engraved anatomical plate per order |

## 6. Lessons to keep (from the art history)

- Silhouette first: three or four big shapes with negative space, then detail.

- Pose for legibility (a kneeling creature reads in profile with soles trailing).

- Heads and hands by hand (a procedural ellipse reads as a jar).

- Depth without gradients: seams where parts cross, a one-step cast shadow.

- **Always check under the game's grade and lighting**: pale greys wash out; warm saturated skins and deep darks survive.

- Stone on stone needs a full value step; dark materials on dark ground need a lit crest.

- PixelLab adds glows, slashes and flashes to action frames; strip them (palclean) — the user wants no effects on attacks.
