<!-- Build · updated 2026-09-30 · 3649 words · source page #godot -->
# 13 · Godot version (started 2026-09-29)

The user asked to develop the game in Godot and to build it **one act at a time**, porting **all** mechanics, aiming at the Dark Souls concept-art look. **Godot 4.7.2**, GDScript, Compatibility renderer, viewport 1920×1080 (`canvas_items`), camera zoom 1 (1 Godot unit = 1 web screen px; 4 per web world px).

**The web browser version is retired (the user, 2026-09-30: "its time is over").** It is not built, updated or published again; the last published version is v105. All work goes into the Godot build. The lore's `gen.py` no longer writes the web tome file. The published codex page ("The Ossuary of Words") is still kept current as a reading copy.

## Where things are

- **Play:** the **Godmarrow** icon on the Desktop (`Godmarrow.lnk` → `Desktop\Godmarrow\Launch Godmarrow.bat`, icon `godmarrow.ico`, the soul lantern). It first takes in a newer build if `_backup\gm_new.zip` is newer than `_backup\applied.stamp` (PowerShell Expand-Archive), then imports and starts the game. Claude's sync writes the stamp after applying, so a normal launch goes straight to play. The older `Play Godmarrow (Godot).bat` still works. **Editor:** `Open in Godot editor.bat` (`Desktop\Godot\Godot_v4.7.2-stable_win64.exe`). Project: `Desktop\Godmarrow\Godot Project\`. The first slice is kept in `Desktop\Godmarrow\_backup\Godot Project (first slice)`.

- **Master copy:** Claude's cloud workspace `/tmp/gd/Godmarrow` (git). Synced to the Desktop as a zip in parts, unpacked with a Python writer (the connected folder forbids deletes, so `unzip -o` fails; overwrite in place).

- Architecture for helpers: `PORTING.md` in the project root. Checklist of every mechanic: `wiki/14-mechanics-checklist.md`.

- Data exported from the (now retired) web build (Node + Playwright, `window.__ev` hook): `data/*.json` (skills, monsters, items, classes, progression, world, zones with 3 seeds each, `board.json` = the body board per order with its roads, v103, `reading.json`). Tools in `tools/` (`export_board.js`, `draw_board.py`, `test_arcana.gd`, `renames.json`, `arcana_mystic103.json`, `render_mus.js`, `dirge_cue.js`, `test_sfx.gd`, `test_amb.gd`, `codex_to_bb.py`, `cap_chapel.js`, `title_cut.py`, `title_pix.py`, `reading_data.py`, `exp_fate.js`, `exp_cards.js`).

## State (2026-09-30), Act I with the Hollow Mystic

- **World:** all 25 Act I zones, maps random per run (one of 3 exported seeds), gates, waystones and the travel sequence, lantern-stones, towns, NPCs, barks, whispers every 60–120 s, zone lines first visit only.

- **Lighting:** the web's dark layer ported as a shader (`shaders/dark.gdshader`, `world/dark_layer.gd`): a cold blue-teal dark, stepped dithered pools (the hero's lantern, world flames, wisps), occluder shadows from walls, trunks and stones, the land's ambient shade, a warm shift from flames (never brightening pale stone), the lantern's mood (shrinks and stutters under 30% life, gutters in a boss fight). Pale stone wall tops darkened as in the web. Wall candles pool their light on the floor in front of the wall.

- **Combat:** D2 controls, melee string with the overhead finisher (lunge, reach, stagger), heavy attack (hold 0.18 s → full at 0.75 s), finishing blows (+15% resource, +20 poise, hit-stop), screen shake, roll, poise and poise break, walking poise drain, fear and confusion, monsters fight the golem (nearest, or challenged), 14 AI kinds, bosses (no sealed rooms, telegraphs, cracked ground, FELLED banner and gifts).

- **Loop:** save and Continue (one save per order, `user://godmarrow_.save`; new world each start, at the camp), death beat (ANIMA SEVERED, death and return lines, summons cleared, chasers lose you), lantern panel (rest, travel to kindled lanterns), town windows (Maren, Brannoc, the Reliquary Chest, journal J), choir (V) and golem (G) orders, Hollow Token respec, XP pacing by hero level.

- **Arcana (A):** the body board with Minor knots and Major cards, the Outer Circle and the rungs (v103), card texts for the Hollow Mystic rewritten to the current skills and all 36 implemented (see `wiki/15-arcana-v103.md`).

- **Names and words:** Act I text carries no animal words and no "rot" (`tools/renames.json`). No real-world words: copper not pennies, lands not country, leagues not miles, the fast-day not Friday (the Shrine Keeper's knot is "Three Leagues More").

## Front end (2026-09-30)

- **Title stages** (`ui/title.gd` holds the words, the order pages and input; the scene behind is a stage in `ui/title_stage/`, chosen in Options → "The title", `Settings.title_scene`; each stage gives `order_at(p)`, `label_at(i)`, `hint()` and reads the title's `t`, `mode`, `fig_hover`, `order_i`, `_flick()`). Test: `--title --title_scene=stranger|bowl|fire`.

- **the Stranger's box** (`stranger.gd`, the default and the user's favourite): he whispers of the order whose card you linger on (`WHISPERS`, four lines each, taken in turn, typed out above him), and on Begin draws that order's card from the face-down deck at the end of the lid, turns it up and holds it out before the dark takes the screen (`draw_card`, the title's mode "draw"). the user's animation of the Stranger at his fire (`art/reading/stranger_sheet.webp`, ×4 from x=640, its left edge falling into the dark where the words stand); the five orders' cards lie face up across the lid of his box of cards; hover lifts one off the lid, larger, turned to you; embers off the fire, dust falling. "Or take a card from the Stranger's box."

- **the Seer's bowl** (`bowl.gd`): the old web title's chapel captured whole (`tools/cap_chapel2.js` → `art/ui/title_bowl.png`, `title_bowl.json`, `title_refl.png`); the blood in `shaders/title_blood.gdshader` (sway, rings from each drop, the hooded reflection, candles streaked in it), the god's breath in `shaders/title_breath.gdshader`, drops, sparks, embers, ash; a spill of cards round the bowl, the orders' five face up. "Or turn a card beside the bowl."

- **the pilgrims' fire** (`fire.gd`, the first Godot title, from commit e75c6e7): the user's three paintings cut down to pilgrims round a fire in the chapel; the unpainted orders stand as tarot cards in the flagstones. "Or choose one of those at the fire."

- **order pages:** a large portrait (the user's paintings as placeholders), or, with no painting, the order's own sprite drawn large; the god, the Stranger's words, what they draw on, three ways, and that order's pilgrim (Continue this pilgrim · Begin anew · Back). The Hollow Mystic, the Empty Hand and the Shrine Keeper can walk; the others say "This road is not yet open.";

- **saves are one per order** (`core/save.gd`: `user://godmarrow_.save`);

- test hooks: `GM_TITLE_ACT=continue`, `order1`, `order1,order_new,order_new`, `hover0`, `credits`.

- **The Reading** (`ui/reading.gd`, character creation, rewritten 2026-09-30): "Begin" on an order's page reloads into the Stranger's fire. It opens with the god's star card face up (its gift and its cost), then: the Face (the order's three), the Card (four drawn blind, each upright or reversed with its own give and take), the Fear, the Seeking, the Road, one Question, and the Price; then a prophecy and the sum in two columns, IT GAVE and IT TOOK, and "Rise". Esc lets the Stranger choose the rest.

- **Balance:** every choice gives and takes on one scale (`tools/reading_src.py`: VALUE in "marks" per key, e.g. 1% damage, 2 life; `tune()` scales each choice so its net lands at +1.0, faces +1.85, stars +1.3; `check()` reports anything off the scale). The sum is held within CAPS.

- **Flavour:** the Stranger speaks a prompt at each step (several per step), asides on the Fear, Seeking, Road, Question and Price that say where the thing is found in the Hide, and prophecies that answer the picks made (`{"when": [ids], "say": ...}`, chosen 75% of the time when any match).

- **Keys** read by the game (`core/hero_stats.gd` `fate`, saved with `fate_picks`): through `item()` (xp → xpK, gold → gf, and the rest as item keys), life ×hpPct, poise +stam, regain ×regen, damage ×dmg, `dmg_day` under an open sky and `dmg_night` in the dark (`fate_hour()`), `raised` (more damage taken by the raised dead, `entities/monster.gd` `RAISED`), `potion` (draughts), `skt0-2` (+1 to a tree).

- Data: `tools/reading_src.py` → `data/reading.json` (the web's `reading_data.py` is kept for history).

- Test: `--reading --new --cls=` with `GM_READ_ACT=all` (picks everything and rises) or `end`.

- **The Codex of the Hide in the game** (`ui/codex.gd`, `data/codex.json` made by `tools/codex_to_bb.py` from the lore's `codex.json`): a dark reliquary book, chapters and works on a rail, one page at a time. From the title, the pause menu, or K. Each work opens with the Stranger's note of how it came to him (under the title) and ends with its writer's signature or mark (right-aligned). Keys: Up/Down or PageUp/PageDown pages, Left/Right chapters, Esc or K closes. Test: `--open=codex --page=3.2`.

- **Icon:** `icon_godmarrow.png` is the window icon and the boot splash.

## The living world (2026-09-30)

- **Wind** (`Game.wind`, one shared gust): grass and reeds, young trees, cloth, cobwebs and chains sway (`shaders/sway.gdshader`); water swells in rows and throws cold glints (`shaders/ground_iso.gdshader`); the lantern leans in the gust.

- **Atmosphere** (`world/atmos.gd`): mist lit by nearby light, dust in the lantern, soul-lights at dusk and night, leaves, cloud shadows, dusk embers, dawn motes, canopy dapple, sparks off braziers, eye-shine.

- **Figures:** silhouette shadows away from the sun or the lantern (`entities/sil_shadow.gd`); the Wickbound lantern floats beside the hero (`entities/lantern_unit.gd`).

- **Weather** (`world/weather.gd`): ash-fall on the moor and heath, rain in the fen and bog (strongest where a lantern catches it, splashes about you), light rays in the woods by day, drips from the roof under the ground. Each swells and fades on its own slow beat. The light rays move: each swings slowly about its top, widens and narrows, shimmers with the canopy (faster in a gust), and carries a leaf-shadow sliding down it now and then.

- **The camera's eye** (`world/cam_director.gd`): leads a little into the walk; on arrival through a gate it opens deeper in the land and drifts back to you, and from a lantern it sinks down onto you; holds a woken boss in the frame; leans toward a near lantern; pushes in slowly when you fall.

- **The near dark** (`world/foreground.gd`): outdoors, near-black grass, reeds, dead branches and (in the woods) great trunks stand between the eye and the world, sliding past faster than it (parallax ×1.45). They appear only at the frame's sides and foot, and their upper-left edges catch the nearby light. None underground.

- **Far pilgrims** (`world/far_pilgrims.gd`): outdoors (not the camp) at dusk and night, every 40–90 s one pilgrim of another order walks across the upper part of the frame 6–10 yd off, pale and a little see-through, seen only in its own small amber lantern pool. It fades when you come within 4.5 yd or after 24–40 s. `GM_FARNOW=1` spawns one at once for tests.

- Crow props became small offerings (no animals).

- **Order greetings and land sayings** (`world/quests.gd` `ORDER_GREET`, `LAND_SAYINGS`): townsfolk greet each order in its own idiom (the Ossuarch: "Got a bone to pick? Pick one of ours, we've plenty."; the Mystic: "God-mirror to you."; the Empty Hand: "Godmarrow. Or god-nothing, as your lot has it."), and now and then a whisper is a folk saying of the land you stand in (Moor, fen, wood, heath, and the diggers' underground).

- **Greetings** (`world/quests.gd` `GREET`, `greet()`): "Godmarrow" is the Hide's greeting (a play on good morrow). Once a game-day each speaker opens with a turn of it ("Godmarrow to you.", the vendor's "Buying or burying?", by night "Or god-evening. The god won't mind which."), and there is more wordplay in the barks.

- Words from the world (barks, whispers, banners; `world/objects/world_ui.gd`) wait while the title or the Reading stands over it, and come when the pilgrim rises.

## Sound (2026-09-30)

- **Score** (`world/soundscape.gd`, `audio/music/*.ogg`): the web's live-synthesised Act I cues (`zz_zz_music96.js`) rendered through its `testRender` hook in an OfflineAudioContext (`tools/render_mus.js`), made into seamless loops (6 s tail folded into the head, levelled to about −21 dB RMS). Cues: `a1_town` (the camp), `a1_wild`, `a1_deep` (under the ground), `boss1` (fast cut-in, rings out 4 s after the fall), `dirge` (the title and the Reading). Cross-fade 3.5 s between places. Follows the Music volume; quieter while paused.

- **The land** (same file): wind whose loudness and pitch follow `Game.wind`; rain that swells with the shower; a low hum underground; fire crackle near braziers, fires, lantern-stones and candles; drips from the roof when a drop lands; a far bell on the ash moor every 70–150 s. Made-from-noise loops ride over recorded beds (`audio/amb/`, see `CREDITS.txt`): fire crackle (CC0, AntumDeluge), rain (CC0, Ylmir), a dungeon drone with drips (CC0, JaggedStone), wind (**CC-BY 3.0, Jonathan Shaw / InspectorJ**, credited on the title's credits page).

- **The body** (`core/sfx.gd`, `Sfx.play(name)`): footsteps by ground (`zone.surface_at`: ash, stone, leaf, wet), swing, hit, heavy blow, guard broken, hurt, a body falling, roll, draught; recordings from Kenney's CC0 Impact Sounds and RPG Audio (Asset Library 1841/1840, taken from kenney.nl because the library's GitHub archives are blocked here) where they serve better (`SAMPLES`, `LAYERS`, `SGAIN`). A `World` reverb bus rings under the ground. Creatures' wind-ups creak and their blows cut the air; the Mystic's casts sound as glass, breath or thread; chests, lanterns, shrines, passages, coins, pickups and pages have their sounds.

- Asset searches (Godot Asset Library, then OpenGameArt): shader packs (mostly 3D), 2D lighting engines, pixel-camera smoothers, sound managers, Kenney UI and sci-fi sounds, FilmGrain and VFX 2D were looked at and left.

## The Empty Hand (2026-09-30)

- The second order you can walk: `skills/monk.gd` (all 32 skills from `zw_monk.js`), `skills/monk/fx.gd` (drawn effects), `skills/monk/buddha.gd` (the Weeping One, an ally that draws anger). His place at the fire is open (still the empty bowl until a painting comes).

- **The hourglass** (`zz_monk_sand.js`): Radiance pours amber sand, Absence black sand. The fuller a bulb, the weaker that tree (1 − 0.9·f^2.5). Each cast pours about 5% of the bulb (at most 25%; turning the sky pours three times as much). The sand runs back 10%/s while he casts and 35%/s once he stops, 1.5% per hit and 12% per kill. Destroyer costs poise. He is never refused a cast. No cooldowns.

- **The sky:** Radiance is stronger by day and Absence by night. He can force noon or night (`Game.sky_force` holds the hour, so the light and the creatures follow).

- Kills leave glass, rubble, dust or mist instead of a corpse. Uses the painted poses (flurry, skyfist, leap, clap, pinch, sky) and his three-blow chain (light1–3, heavy, dodge).

- **Shared hooks added:** `before_hit`, `catch_missile`, `fist_add`, `light_mod`, `unseen` on SkillBook; `cast_anim`/`cast_len`; `k_silent`/`k_weak` metas on creatures; `--arena_live` (hostile arena), `--arena_lvl`.

- Test: `--cls=monk --new --learn=all:8 --autocast --monktrace --arena=6 --arena_kind=hollow` (not on the moor: the camp's safe circle sweeps spawns).

- **His orb is an hourglass** (`ui/hourglass.gdshader`, from `zz_monk_sand.js`): amber below, black above, the stream through the neck while he casts; the tooltip gives both bulbs and each way's strength.

- **His Arcana:** all 26 cards from `data/board.json` (kr_*, ka_*, kd_*, kh_*) act in `skills/monk.gd` (Majors upright and reversed, Minors, the Black-Flame Lantern and the Unraised). Missiles are in group "missiles".

- Still to do: a painted Weeping One, balance after play.

## The Shrine Keeper (2026-09-30)

- The third order you can walk: `skills/miasmancer.gd` (all 30 skills from `m_mias.js`, `o_skills14.js` and `zz_miasma_breath.js`), `skills/miasmancer/fx.gd` (clouds drawn as breathing violet puffs, never green), `skills/miasmancer/ally.gd` (Blur's decoy and the Mirror-Sister, both allies creatures can strike).

- **Miasma:** the cloud about her grows with rank and with how full her breath is; it sickens (meta `k_psn`: the strongest dose kept, some skills stack) and makes blows miss. Inhale is a passive trickle; standing in her own miasma fills her; the sickened leak small clouds.

- **Omens** (the class gauge, OMENS n/max): Death strikes build them (+6% damage and +5% speed each), finishers (Reap, Execute) spend them; they fade after 14 s.

- **Distortion:** traps thrown and arming, Haze confuses, Mirage slows and bends missiles, Siren Lure drags, Warped Miasma twists what stands in her clouds, the Mirror-Sister acts with her skills at a share of her strength.

- Her 26 Arcana (z_*, zm_*, zd_*, zx_*) are read in the book. Texts tidied by `tools/fix_mias_text.py` (Sigil → Omen, "msigilt", old skill names in the cards, the dropped Vharn lore; tabs Miasma · Distortion · Death).

- Test: `--cls=miasmancer --new --learn=all:8 --autocast --miastrace --arena=6 --arena_kind=hollow`.

- Still to do: her painting and a better sprite (the old painter sprite is below standard), balance after play.

## Champions' deeds (2026-09-30)

- **Rules (the user, 2026-09-30):** every danger is plainly seen (no Diablo IV invisible deaths); D2-style marks only. Warded (D2's Magic Resistant: +40 to every working, not steel) came in; the deed fx draw unshaded and ash burns only once it has settled.

- `entities/affixes.gd` + `entities/affix_fx.gd`. Every champion pack shares one deed (chosen from its pack name), uniques from level 8 carry a second. The old stat marks keep their data and show in the Stranger's words (Extra Strong → Heavy-Handed, Extra Fast → Quick, Stone Skin → Stone-Skinned).

- **Ash-Trailing**: smouldering ash where it walks (fire, 4.5 s, burns after 0.5 s, one patch at a time). **Grave-Called**: when it falls, one lesser dead claws up (two for uniques). **Thirsting**: its blows drink 7% of your pool. **Nail-Fisted**: its blows break footing ×2.2. **Thorned**: close blows give back 8% (at most 4% of your life a blow). **Candle-Eater**: within 5 yards your lantern loses a quarter of its reach. **Warded**: +40 resistance to every working (not steel). **Bursting**: the body swells for a second (its reach marked in the dust, a ring tightening), then bursts in bone within 2.4 yards. **Unquiet**: when 4.5–14 yards off, it sinks and comes up beside you every 5–7 s.

- Hooks: Monster.setup/die/_physics_process, `Combat.hit_hero` (knows whose blow it is through `Combat.striker`, set in `Monster.roll_damage`), `Combat.hit_monster`, `Hero.light_radius`.

- The Codex: "What the Marked Carry" (the Roads), a road-warden's notice (`tools/codex_extra.py`, the Godot build's own works, appended by `codex_to_bb.py`).

- Tests: `--arena=N --arena_live --arena_rank=champion --affix=Bursting --afftrace`.

## Balance G1 (2026-09-30)

- Whole-kit arena (level 20, every skill at 8, the order's eight default keys, 6 tireless hollows, 30 s, noon): **Mystic 147**, Empty Hand 260 → **221**, Shrine Keeper 388 → **196**. The two new orders sit above the Mystic on purpose (they fight close).

- Shrine Keeper: `TUNE` 0.8 on all her damage; sickness ticks ×0.8 (`PSN_K`); needle traps ×0.5 (four were half her damage); Miasma Wake ×0.7; one breath draws at most a tenth of her pool (a field of clouds refilled her four times faster than the Mystic's Essence).

- Empty Hand: `TUNE` 0.75 → 0.6; the glass now binds: a common cast pours 12% of a bulb (was 5%), sand runs back 2%/s while he casts (was 10%) and 25%/s once still for 0.9 s (was 35% after 0.4 s), hits 0.3% at most four times a second (was 1.5% every 0.08 s), kills 7% (was 12%); the Hundred Hands feel the glass; the Hungry Palm ×0.7 and the Hundred Hands ×0.8 (row-one skills out-dealt his row-three ones).

- **His bearing**: the Empty Hand has 10 + 1.5 armour a level (level 14: 38, was 8), whatever he wears (at first only with an empty body slot; the user: that would cost him the gear's own gifts).

- No waits: the Shrine Keeper's Last Breath holds her once in each place (twice with Grave Breath), no longer once a minute. Thirsting fills the Empty Hand's glass instead of draining a pool he doesn't have.

- Per-skill survey: `/tmp/gd/survey.sh` pattern (each skill alone at 10, hero 20, 6 targets, 12 s). The arena now logs every order (`trace`), prints `HERO … falls, life lost, kills`; `--cls=X` wakes that order's own pilgrim (it used to load the latest save); `GM_AUTO_T` sets the Empty Hand's test cadence.

## Clarity pass (2026-09-30, the user's rule: every danger is plainly seen)

- **The death screen names the killer:** "Slain by Weeper (Quick): its needle." Every blow carries who and how: `Combat.hit_hero` writes `hero.last_blow` (`Combat.who(m)` = name and marks); missiles remember who loosed them (the damage rolled that frame, `Missile.by_desc`); ash, bursts, fires, eruptions, slams and burrowers say what they are (`opts.src`).

- **No shots from the dark:** needle-throwers and wraiths fire only when the hero could see them (open ground by day, inside the lantern's pool plus a step, or near a world light: `Brain.in_sight_of`); otherwise they close in first.

- **Ground hazards burn as one:** ash and fire underfoot hurt at most once every third of a second together (hero meta `ground_hurt`).

## Skill trees redone to the lore (2026-09-30)

- `tools/skill_trees.py` is the source of every change to `data/skills.json`, `classes.json` (tabs, keys) and `board.json` (card words); safe to run again. New icons: `tools/icons_g1.py`. Test the panel: `--cls=X --new --lvl=30 --panel=skills --skilltab=N`.

- **The trees intersect the way Diablo II's do** (2026-09-30, the user): skills rest on one or two others, lines cross between the columns and meet again lower down, and each Mastery rests on its tree's deep skills (`PREREQ` in `tools/skill_trees.py`, checked: same tree, parents above). Pilgrims already saved keep what they learned.

- **Every Mastery is a level-30 skill** (the Mystic's Choir Mastery moved up from 24).

- **Ossuarch:** Ossuary (the dead) · **Carapace** (bone spells and plate; the aura is **Mantle**; Grave Spirit → **Pale Lord**; Shield of Bones folded into Bone Armor, Bone Arms into Charnel Cage) · **the Count** (melee and numerology curses: Tally (blows in threes), Open Count, The Fewer, The Weighing, The Ninth Stair, Count Mastery; Marrow Crush reads the count). Data only: he is not yet ported. **The count, seen:** `entities/count_sigil.gd`, a small white ghostly sigil over the cursed one's head: the curse's figure in nine strands, the lit strands are the count (no numeral, the user); it swells and thins away at nine; test `--arena=4 --sigils`.

- **The Red Penitent** (the Hemomancer, renamed): Mortification (the penances he wears) · Blood (magic and blood made to walk) · Penances (melee and self-buffs); every skill distinct; see the class page. Data only: the redo waits on art.

- The Shrine Keeper's trees now read Miasma · Distortion · Death everywhere (the data said Trap and Omen).

## Next

- Listen-through with the user; adjust levels.

- Ash plumes in the sky.

- Engraved figure on the body board; card audit for the other orders; second balance pass after play.

- The Hemomancer (needs a sprite redo) and the Ossuarch (on hold).

- Final portraits and the Shrine Keeper's and Empty Hand's paintings (the user will bring art).
