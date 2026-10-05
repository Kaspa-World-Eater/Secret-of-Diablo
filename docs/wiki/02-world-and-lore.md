<!-- World · updated 2026-09-29 · 2351 words · source page #world -->
# 02 · The world and its lore

*God names follow `claude/godmarrow-naming-codex.md`. Every in-game line lives in `src/zz_voice.js` (readable copy: `claude/godmarrow-voice-lines.md`).*

> Everything that lives here grew out of a dead god. Nothing was born; everything was shed.

## 1. Cosmology

- **The Silence came first** (Ur-Nihl, the Hush): not darkness, but the absence of anything that could be named.

- **The god** of three natures, **Soul, Bone and Flesh**, held a space open inside the Silence. The Silence **unsaid** it, one name at a time, until it forgot how to be three-in-one and died.

- **Its corpse is the world: the Reliquary.** Its true name is lost; "Triune", "the Three-in-One" and "the God Beneath" are only descriptions.

- **The godmarrow:** what still lives in the corpse's bones, in everything that walks. Every order draws on it differently.

- **Breath:** the god's last breath and the small spirits of every stone, river and bell that ride it are **the Myriad**.

- **Miasma** is breath gone wrong, essence twisted out of true. **Never called rot.**

- **No animals.** Every creature is a piece of the god that forgot it was part of something: a cell that grew legs, a thought that grew teeth, a prayer that grew skin. The deeper you go, the older and stranger.

- **The Tithed** (people) descend from the congregation inside the god, at worship, when it died. They are the only things not made of the god; its pieces want to **eat** them or **become** them.

- **Corpses:** anything made of the god leaves a corpse, because the god is still dying. The Silence's servants leave nothing.

- **The Pale Order (Bone):** an ancient order, as old as the world or so it claims, that keeps the ossuaries of the Ossa range, built over ruins older than itself. It reveres bone and calls the Bone **the Bearing Mother**. It tends the bones and the marrow, and its dead stand vigil in their niches. Bone gone to dust is sacred, the only thing in a dying world that has finished, and it is given to the wind in sky funerals. The Order hides something. See `claude/godmarrow-class-ossuarch.md`.

- **Each hero stands alone.** Their orders feud (see each class page).

| Power | True name | What it is now | Order |
|---|---|---|---|
| Soul | Yh'Anuul | the threads of fate the god wove and still weaves | Hollow Mystic |
| Bone | Oss-Vharoth | the skeleton that refuses to lie down | Ossuarch |
| Flesh | Nol-Shogthuth | the flesh that keeps growing without a mind | Hemomancer |
| Breath | none (the Myriad) | the last breath and the small spirits riding it | Shrine Keeper |
| the Silence | Ur-Nihl (taboo) | what killed the god, leaking in through its wounds | The Empty Hand |

## 2. The lanterns: the Wickbound (v74)

- **No lantern in the Godmarrow burns oil.** Each is lit with a soul that chose to be kept rather than go down into the Last Breath: a pilgrim who fell on the road, a mother from the crypt niches, someone nobody remembers. The soul is the flame.

- It **chooses whom it follows** and goes where they go, a little behind, a little to one side, the way a dog walks with you at night. It can't be struck or commanded.

- When you fall, it **carries your anima back** to the lantern-stones and **keeps a little of you** each time; that is what it burns. (Existing return line: *"The lantern gives you back. It keeps a little, as it always does."* Lantern inscription: *"Dust on the glass. Wipe it. It is someone."*)

- **In play:** the lantern floats at shoulder height beside the hero; its light makes the pool on the ground; its flame struggles when you're near death and gutters when something great wakes. See `04-systems-and-combat.md` §Light.

## 3. Mechanics that express the world

- **Poise** is the Tithed body refusing to fall. Monsters have poise too (Path of Exile 2 rules).

- **Light** is sacred and practical: the dark is the danger; creatures' eyes catch your lantern; Gasps and Moth-Saints react to light, Silent Ones eat it; day and night matter (the Empty Hand is bound to them).

- **Water** douses fire. **Stone** stops burrowers. **Doorways** stop giants.

## 4. The openness rule

> "We want all the open spaces and not overcrowding or too many narrow spaces. Act 5 and Act 1 [of Diablo 2] are really good examples."
> - **Outdoors:** 120–180 tiles a side, 52–82% open ground, roads 5–6 wide, groves that clear into meadows, sparse props (trees deliberately halved; `z.__treesHalved`).
> - **Dungeons:** rooms 13–21 tiles, halls 5 wide (7 in catacombs and monasteries), boss arenas ≥16×16 and **never sealed**.
> - **Some channeling (v89):** 2–4 loose tree lines or broken colonnades per open zone, sometimes paired into lanes, always with gaps and open ends (`zz_zz_world89.js`).
> - **Toolkit:** `zz_openness.js` (`buildOpen`, `wideDungeon`, `spreadPacks`); narrowest point on any route to a portal ≥5 tiles.

## 5. The acts (first playthrough ends around level 36–40)

| Act | Region | Monster levels | Town | Act boss |
|---|---|---|---|---|
| I | **The Hide**: Ashen Moor, Hollow Wood, Drowned Fen, barrows, crypts, catacombs (25 zones) | 1–17 | Maren's camp on the Moor | the Ossuary Matron (in `cata2`); the Carrion Warden guards the crypt |
| II | **The Bleached Barrens of Ossa** | 18–24 | Citadel of the Shattered Femur (`a2_town`) | Saint Calcifer, in the Empty Socket |
| III | **The Parasitic Fen of Shog-Mire** | 24–30 | Kettlewick Stilts (`a3_town`) | the Brood-Mother, in the Blood-Basin |
| IV | **The Frigid Heights of An-Vhar** | 30–34 | Bellrest Hearth (`a4_town`) | the Chime-Abbot, Summit of the Unrung Bell |
| V | **The Descent** into the body | 34–40 | The Last Vigil (`a5_town`) | the Thought of the Slayer, Alien Temple of the Slayers |
| side | **The Scar of Ur-Nihl** and the Silent Monolith | 36–40 | none | none |

**Zones**
- **Act I:** Moor, crypt, fen, barrow, two catacombs; Sighing Ridge, Ash Shore, Burnt Heath, Fern Gully, Pilgrim Road, Drowned Village, Sunken Bog; Fallen Monastery, Wolf-Den Chapel, Plague Hospice, Well-Shaft, Smugglers' Hold, Bog-Witch's Shack; Tree-Hollow, Hunter's Cache, Fallen Watchtower, Broken Bridge; Hollow Wood, Root Deep.
- **Act II:** Bleached Dunes, Reliquary Avenue, Buried Chapter-House, Valley of Standing Ribs, Chalk Flats, Sand-Choked Tomb, Field of Fallen Standards, Dry Oasis, Marrow Cavity, Empty Socket.
- **Act III:** Heartbeat Flats, Weeping Mangroves, Fetish-Tree Groves, Blood Delta, Amber-Grease Mire, Brood-Banks, Causeway of the First Brood, Leech-Sumps, Egg-Galleries, Ziggurat of the First Brood, Blood-Basin. *Heartbeat mud:* every 1.7 s it clutches, slowing you a further 40%.
- **Act IV:** Chime-Foothills, Glass Pass, Prayer-Flag Terraces, Field of Lantern-Spires, Cloud-Shelf, Wind-Scoured Ridges, Stair of the Sky-Climbers, Breath-Caves, Bell-Hollow, Sky-Climber's Monastery. *Chime-winds* drain poise, never below 35%; lanterns and spires give shelter.
- **Act V:** Grand Calcified Highway, Siphon Vaults, Sanguine Cavity, Valve Gates, Shaft of Fading Echoes, Digesting Crucible, Cerebrum Labyrinth, Alien Temple of the Slayers.
- **Ids:** Act N zones are `aN_*`, town `aN_town`, lair `aN_lair`.

## 6. Act I details worth remembering

- **The Ashen Moor** is the god's cheek, where it struck first. The ash is warm because the flesh beneath is still cooling; black glass forms where a Husk's blood ran into the ash. Landmarks: the Sighing Lantern, the Widow's Stumps, the Broken Kneeler, the Ashwake milestones.

- **The Rib Crypts** are dug between the god's ribs; the flagstones lift as something below breathes. Landmarks: the Empty Reliquary of Sister Un, the Weeping Rib, the Counting Wall, the Long Candle.

- **The Barrows** hold the Tithed's own dead, who rise wrong; every barrow-lid is dished inward. Landmarks: the Turned Mound, Widow's Lane, the Grieving Stone, the Empty Ninth.

- **The Drowned Fen** is the god's lymph: clear water that does not wet. The Well-Shrine stands here; below it, Minasoko-dō, the Drowned Nave. Landmarks: the Kneeling Arch, the Reed That Points Home, the Iron Hook.

- **The catacombs:** upper, the pilgrim ossuary with bone laid as sermons; lower, the patterns forget themselves, and at the bottom there is something warm.

- **The Hollow Wood** is the god's veins stood up as pale trees; luminous fungi in three colours; every tenth trunk holds something the god was carrying. Landmarks: the Ribcage Bough, the Blind Face, the Niche Candle, the Sword-in-Root.

- **The Root Deep** (Ne-no-kuni) is the country under the Hide, and it breathes; the oni's road down.

- **The Hide showing through (v66):** 2–6 rare, unexplained organic pieces per Act I outdoor zone: a rib arching from the turf, a vein breaching soil, a patch of skin with pores and coarse hairs, a pool that looks back like an eye.

- **The dead herd (a quiet cow-level homage):** on the Burnt Heath, the corner farthest from the road, seven great horned carcasses lie in a ring facing the same way, with skull heaps. First visit: *"The herd lay down here, facing the same way. The ground between them was opened once, and closed."* (Its king, the Hollow King, is parked; see backlog.)

- **Pilgrims' camps** (a tent and a banked fire, ~60% of open zones), **wayside saint/angel statues** by roads, **gibbet cages** at the edges.

## 7. Towns, errands and the road

- **Towns are safe.** Each has a vendor, healer, smith, quest-giver, the Stranger, the Reliquary Chest (shared 48-slot stash) and a waypoint.

| Act | Vendor | Healer | Smith | Quest-giver |
|---|---|---|---|---|
| I | Maren | Sister Ysolde | Brannoc of the Nail | Warden-Crone Esk |
| II | Qasim the Dust-Factor | Mother Oss-Ana | Ibbat the Knuckle-Smith | The Last Reliquarist |
| III | Lugh the Eel-Monger | Asheth the Leech-Wife | Old Tamb | Priestess Ninsun |
| IV | Dorje the Salt-Trader | Sister Palden | Chime-Wright Ulan | Brother Tenzar |
| V | The Tallow-Merchant | The Nurse Without a Face | Ferrous | The Hollow Seer |

- **Errands** (J opens the journal): about 5–6 per act: kill, relic, shrine (hold through two waves), captive, seal (three seals open a vault), zone boss, act boss. Rewards: skill/stat points, resistances, gold, uniques, Arcana.

- **The road:** killing an act boss opens a gate to the next act's town. The Thought of the Slayer's death plays the Stranger's line and the credits, then opens the Scar.

- **Heralds** wake at rare god altars and alone grant Major Arcana: the Marrow Pontiff (Bone), the Wet Nurse (Flesh), the Long Exhale (Breath), a Silent One (the Silence). Altars show a speaker's name (Old Upright, the Red Mother, the Last Breath, the Hush), never the true name.

## 8. Act I bestiary: every creature is a lesson

Nothing flashes. Each creature has a **tell** and a **counter**.

| Creature | What it is | Behaviour | Tell | Counter |
|---|---|---|---|---|
| Husk | a pilgrim who drank from the wound | waits until three gather, then surges | head snaps up, arms spread | pull a few; fight in a doorway |
| Tithe-Hand | a severed hand of the god on its fingers | packs circle and dart in from behind | fingers tense and spread | back to a wall |
| Weeper | faceless mourner, tears harden into bone needles | keeps distance behind ruins | tilts head back | break line of sight, corner it |
| Gasp | a stray scrap of breath, a veil of mouths | drifts through walls, recoils from light | inhales, veil billows | fight near lanterns and fire |
| Pyre-Saint | a martyr whose faith still burns | burning footprints, erupts | flames roar white | douse in water, or range |
| Bellwether | a hulk with its head sealed in a bell | tolls, then charges; a wall stuns it | two tolls | stand before a wall, sidestep |
| Vein-Worm | a severed artery, still pumping | burrows, erupts under you | ring of blood-bubbles | stand on stone or roads |
| Moth-Saint | a porcelain saint's face on a moth's body | swoops in an arc, climbs away | wings fold back | strike during the swoop |
| Ossuary Warden | bone knight with a skull tower-shield | blocks everything from the front | shield lowers | flank, or break its poise |
| Marrow Duelist | skeleton fencer | parries flurries, ripostes | blade tip rises | slow heavy hits, spells |
| Gravebloat | a walking stomach | shuffles close and bursts | swells, gurgles | range, or let it burst in a crowd |
| the Kneeler | a penitent still on its knees | (in game since v0.53, Moor and crypt packs) |  |  |

**Ideas not yet built:** the Long Sister (a shroud-weaver who wrapped herself), the Ash-Choir (three tiny singers who never finished the note), the Splint, the Weeping Post, the Miscount (two skeletons sharing one set of bones), the Un-Bell, the Root-Bride, the Sub-Deacon (four-armed censer priest), the Late Sister (always three paces behind you).

## 9. Voice

- **Tone:** elegiac. Second person present for the player; third person for the world.

- **Entry line:** first visit to a zone, ≤14 words. **Whispers:** every 60–120 s of exploring, ≤18 words, never in fights. Landmarks, lantern names and inscriptions surface when you pass or touch them. Death and return lines. One lore line on rare and unique tooltips.

- **The Mysterious Stranger** (the Reading and every town) speaks in half-lines and ellipses and calls each god by a different name every time.

- Banned words: see `01-rules-and-decisions.md`. `window.__voice.audit()` checks the limits in game.

## 10. Mood board (not canon)

Another AI's ten realm concepts feed props and atmosphere, never names (the Frigid Heights and Bleached Barrens were used; the Marrow Catacombs, Sanguine Cavity, Shaft of Echoes, Digesting Crucible and Cerebrum Labyrinth are in Act V). The user: *"just flavor material, not so much lore."*
