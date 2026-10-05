<!-- Systems · updated 2026-09-30 · 40664 words · source page #checklist -->
# 14 · Mechanics checklist for the Godot port

*Written 2026-09-29 from the web build's source (`triune_desktop/src/`, the files in `src/_exclude.txt` left out) and the wiki. It lists every mechanic the web build has, so nothing is lost when Godmarrow moves to Godot 4. Where a later `zz_*` file wraps or overrides an earlier one, the line gives the final behaviour. Numbers marked "measured" were read from the running build (headless Chromium, the build made by `build_x.sh`), not from one file.*

**Size.** 636 checklist items: 455 tagged [Act I] and 181 [later]. They include all 153 skills, 64 creature kinds and 75 zones; the 26 errands are grouped per act.

**How to read a line.** Each checklist item is one bullet: what it is, the essential numbers or rules, then the source files in backticks, then a tag.
- **[Act I]**: the first act needs it (the Ashen Moor to the Ossuary Matron, hero levels 1 to about 17). A skill is tagged [Act I] when its row opens by level 12, because a hero ends Act I at about level 16 to 18.
- **[later]**: Acts II to V, endgame, or polish that can wait.
- **Load order.** The page runs `b_core` → `c_game` → `d_play` → `f_bone` … `e_ui`. Every `zz_*.js` is then spliced inside the same closure in filename order, and `zz_polish.js` goes last (`build.sh`, `build_x.sh`). Most `zz_*` files wrap a base function (`derive`, `hurtMon`, `hurtPlayer`, `dropLoot`, `rollItem`, `makeMon`, `updatePlayer` …). In Godot, **collapse each wrapper chain into one function**; the lines below give the collapsed result.
- **Skill numbers** come from the game's own tooltip functions (`skillInfo`, `skillCost`) for a fresh level-1 character: 25 Essence, damage multiplier ×1.30, daytime. The same skill scales with the hero's stats, gear and synergies.
- **Units.** 1 yard = 1 tile (36×18 art pixels on screen, `TW/TH` in `b_core.js`). Times are in seconds. "L10" means skill level 10.

---

## 0. The standing rules that constrain the port (from `01-rules-and-decisions.md`)

These are law. Every system below must respect them. Where the code still breaks one, section 0b says so.

- **No cooldowns anywhere.** Power is gated by cost (life, resource, poise, minions), never by timers. No durations that read like cooldowns. `wiki/01` `zz_monk_sand.js` **[Act I]**

- **Melee costs poise, never mana**, for every order (Carapace, Death and Destroyer trees; the basic weapon string's finisher). `zz_bone_melee_shard_costs.js` `zz_ossu_active_melee.js` `zz_melee_chain.js` **[Act I]**

- **Stagger is 20% stronger both ways (v79–v80).** Creatures' poise breaks 20% sooner and their reel lasts 20% longer. The player's poise drains 20% faster and a break stuns 20% longer (0.75 s → 0.9 s). `zz_zz_light79.js` **[Act I]**

- **Poise break (v60):** a short stun, a burst refill to half, then normal regeneration. **No rolling until poise is full.** `zz_zv60.js` **[Act I]**

- **Bosses are Diablo-style, never Dark Souls-style.** Never lock the player in a room: no sealed arenas, the player can run, kite and leave. A boss left far behind goes home and waits **without healing**. `zz_zz_perf74.js` `zz_zz_boss83.js` `zz_quests.js` **[Act I]**

- **Gold is the currency.** No currency-as-crafting. **Gold drops silently** (v88); picking it up still makes a small sound. `zz_zz_study82.js` `c_game.js` **[Act I]**

- **Loot is scarce, as in Diablo II.** About 7 items, 11 gold piles and 5 potions per 100 normal kills; magic and rare stay rare (section 16). `zz_pace_and_density.js` `zz_mech_loot.js` **[Act I]**

- **No red lighting.** Dusk may redden the vignette edge, but no light source is red; the dark is blue-teal (v77). `wiki/01` `zz_zz_cine76.js` **[Act I]**

- **No glows or effects on attacks and casts.** No swing arcs (removed v93), no comet streaks on wisps (v79), no glow on blood (`NOGLOW`). Only dark grit on the overhead finisher. `zz_melee_chain.js` `zz_zz_thread93.js` **[Act I]**

- **Openness:** zones are open and spacious (D2 Act I and Act V). Outdoor zones are 120–184 tiles a side with roads 5–6 wide. There are few corridors, and the narrowest point on any route is at least 5 tiles. A few loose tree lines and colonnades per zone are allowed (v89). `zz_openness.js` `zz_zz_world89.js` **[Act I]**

- **Maps are random** per New game and per Continue (a new `G.seed` each start); towns and quest vaults are hand-laid. `e_ui.js` `zz_quests.js` **[Act I]**

- **Packs are 15% smaller** (fewer creatures per pack, not smaller creatures). `zz_zv60.js` **[Act I]**

- **Monsters loiter like D2's imps** and are bold, not cowardly (v76, +20% bolder in v79). `zz_zz_imps67.js` `zz_mobai63.js` **[Act I]**

- **No strobing light.** Every flame is eased over about 0.2 s. `zz_zz_light79.js` **[Act I]**

- **Lantern perks are benign:** slow, fear, regeneration, radius. Never damage. `zz_zw_lantern63.js` **[Act I]**

- **Skill trees:** three per order, D2 layout, rows at levels 1/6/12/18/24/30, no capstones. There are a few clear synergies, a viable melee and a viable caster style for every order, no weak level-1 minions without a point, and no level-1 skill that needs a later one. `zz_mech_trees.js` **[Act I]**

- **The Reading:** every percent effect is ±1% at most; attributes ±2, armour and poise ±4, life per kill ±1. `zz_fate_zcap.js` **[Act I]**

- **Major Arcana never give +skill levels and never add waits.** `wiki/01` `zz_arcana_zbody.js` **[Act I]**

- **Hero's hands stay free** (weapons are separate layers, later). The hero casts a real shadow (no blob); wisps cast light but no shadow. `zz_zz_shadow70.js` `zz_zz_perf74.js` **[Act I]**

- **No corny markers** ("!" over NPCs, surfacing markers for burrowers). The player learns from visual cues. `zc_combat22.js` (v0.55 no burrow marker) **[Act I]**

- **Banned words in the world's voice:** cooldown, dps, proc, aggro, loot, buff, nerf, stun, lightning, mana (except in code), chain lightning, rot, cell, virus, DNA, organism, biology. The goddess is the *Bleeding* Maiden. The in-game audit is `window.__voice.audit()`. `zz_voice.js` `zz_tune_batch_c.js` **[Act I]**

- **No animals, no animal motifs.** Every creature is a piece of the god. `wiki/01` **[Act I]**

- **Performance law (v75):** a lighter render mode starts automatically on phones and tablets, or when frames average over 26 ms. `zz_zz_perf74.js` **[later]**

## 0b. Contradictions and bugs found in the code (decide them in the port)

- **Colossus leap on a timer:** `BS.leapCd` makes it leap every 5 s (3 s with Earthshaker). That is a wait; consider making it a cost, or tying it to distance. `f_bone.js` **[later]**

- **Other timers that read as waits.** Dazzling Challenge taunts every 5.8→4.3 s, and Laughter-Without-Warmth pulses every 3.8 s. Second Heart can pound you back up only every 59 s. Last Breath (Sigil Mastery) fires "once a minute", and the Last Silence "once per zone". The rule allows rhythmic auras; the once-per-minute saves need a ruling. `c_game.js` `zw_monk.js` `h_blood.js` `m_mias.js` **[later]**

- **The Empty Hand's sky skills:** the shared wait is gone in code (`zz_monk_sand.js` deletes `MONK_CD` and zeroes `kskyCd` each frame; the sky costs three times the sand instead). But `zz_mech_balance.js` still writes "shares its cooldown" into the text, patched later by a regex. The backlog question in `09` is answered; port the cost, not the wait. `zz_monk_sand.js` **[Act I]**

- **The class name shows "The Monk".** `zz_mech_balance.js` sets `CLASS_NAME.monk = 'The Monk'` after `e_ui.js` set "The Empty Hand", so the character page and the pause menu say "The Monk". Use **The Empty Hand**. `zz_mech_balance.js` `e_ui.js` **[Act I]**

- **Shrine Keeper tab names:** at run time they are Miasma · **Trap** · **Sigil** (`zz_mech_balance.js`), while the wiki says Distortion · Death and the HUD says Omens. Skill text says "Sigil" and the HUD says "OMENS". Pick one word (the wiki's backlog prefers Omen). Bird-named skills (Crow's Heel, Raven Flurry, "a raven moving between carcasses") break the no-animals rule. `zz_mech_balance.js` `m_mias.js` **[Act I]**

- **Stale text:** the Reading's god faces still say "+1 to Iron / Anima / Logos skills" (the Mystic's trees are Mirror · Soul · Thread). Tooltips still say "Weight" for the Empty Hand, which has no Weight since v0.54. `qa_fate22.js` `zw_monk.js` **[Act I]**

- **Tooltips that print NaN** (formula lost in rewrites): Procession per strike, Darting Wisps, Splitting Wisps and Soul Leash damage, Overcharge burst, Grave Leap, Bone Host carapace, Penitent Womb per-tumour count, Belly Maw and Swallow Whole digestion, Tentacles damage, Tumor Hump, Needle Sentry, Miasma Wake, Sighing Bladder. Recompute from the live formulas. `zz_ui_desc.js` **[Act I]**

- **Respawn resets a boss to full life** in `respawn()` (`d_play.js`), while v75 and v83 say a boss left behind waits without healing. Decide which applies on death. `d_play.js` `zz_zz_boss83.js` **[Act I]**

- **Omen life:** the card Omen-Sight says Omens last "15 s instead of 8", but the code has `omenLife` 14 s (24 s with the card). `m_mias.js` `k_arcana.js` **[later]**

- **Death March: text and numbers disagree with behaviour.** The cast handler (`zz_mech_balance.js`) makes every skeleton rush to the pointed spot at double speed for 3 s (+2 s with Long March), and its first blow on arrival shoves and staggers. But the description (`zz_mech_names.js`: "step in time and strike faster … falter with dread") and the tooltip numbers (6→10 s, +40% attack speed) describe the old War Horn. Pick one. `zz_mech_balance.js` `zz_mech_names.js` `f_bone.js` **[Act I]**

- **Blessed Growth tooltip** still prints the old Tumor Toss numbers (tumours, burst damage). The live skill is a 3 yd curse for 6 s (+3 s with Deep Roots): 2 damage/s × (1 + 50% per level), and a 1-life spawnling from each cursed death and every 2 s from a cursed enemy. It costs Vitae only. `zz_mech_balance.js` **[Act I]**

---

## 1. Engine, scale and the frame

- **Logical screen** 480×270, drawn at 4 screen px per art px on desktop (1920×1080) and 2 on phones (`RS`). World zoom `ZK` 1.0 since v0.54: the world is a third larger around the same-sized hero. Godot: viewport 1920×1080, `canvas_items` stretch, camera zoom 2 (`13-godot.md`). `b_core.js` `zz_worldscale.js` **[Act I]**

- **Isometric grid:** a tile is 36×18 art px (`TW`, `TH`). `iso(x,y)` → screen (x−y)·TW/2, (x+y)·TH/2. Depth sort is by x+y. `b_core.js` `d_play.js` **[Act I]**

- **Tile types** (`T`): grass, road, tree, rock, water, cliff, floor, wall, fog, pillar, palisade, dirt, shallow, mud, flags (flagstone), plus ruin (later files). Solid: tree, rock, water, cliff, wall, fog, pillar, palisade. Tall (blocks line of sight): the same minus water. `b_core.js` `zd_world22.js` **[Act I]**

- **Pathfinding:** A* (`findPath`) with a budget of 4 monster paths per frame; straight-line walk test first (`lineWalk`). The player repaths every 0.18 s while the button is held. `d_play.js` `e_ui.js` **[Act I]**

- **Line of sight for skills:** a target point behind a tall tile is pulled back to the wall (`losPoint`); rocks don't block. `d_play.js` **[Act I]**

- **Crowd spacing:** bodies push apart (ring instead of a pile). Big creatures push small ones more. Flyers, ghosts and burrowers don't collide. `d_play.js` **[Act I]**

- **Update radius:** idle monsters farther than 24 tiles are skipped; any monster farther than 40 goes idle. `d_play.js` **[Act I]**

- **Hit-stop and screen shake:** heavy blows, finishers and slams freeze the frame for 0.06–0.11 s. Shake can be turned off in Options. `zz_mech_heavy.js` `zz_melee_chain.js` **[Act I]**

- **Performance modes:** lighter mode paints the dark at half resolution and a third as often, and quantises the light map every other frame. Only the lantern shadow is drawn, with no monster wedge shadows. Force it with `?fx=lo` or `?fx=hi`. `zz_zz_perf74.js` **[later]**

## 2. Core loop and controls

### Mouse and keyboard (D2 style)

- **Left click:** walk (hold to keep walking; repath every 0.18 s); click a monster to walk to it and strike; click items, chests, lanterns, NPCs to walk to them and use them. **Shift + left:** attack in place. `d_play.js` **[Act I]**

- **Right click:** cast the right skill at the cursor; hold to repeat (hold skills channel). Right-click a fresh corpse to raise it with a corpse skill (the Ossuarch's skeleton, the Hemomancer's spawnlings). `d_play.js` `t_v17.js` **[Act I]**

- **Skill slots:** left and right skills, both able to hold the plain Attack. Shift + hotkey sets the left skill; the hotkey alone sets the right one. Click the bar icons to swap. `d_play.js` `e_ui.js` **[Act I]**

- **Hotkeys** Q W E R T Y U F by default; O Z X B N are also bindable. Hover a skill and press a key to bind it. Default binds per order are in `defaultKeys`. `c_game.js` `d_play.js` **[Act I]**

- **Space:** dodge roll toward the cursor. **1–4:** drink from the belt. `d_play.js` **[Act I]**

- **Panels:** I inventory · C character · S skills · A the body board (Inverted Triune) · J journal · Tab automap · Alt show items on the ground · V/G class panels (Mystic V choir, G golem orders; Ossuarch V or G army orders; Hemomancer V or G the Flesh) · Esc close panels or open the pause menu · M sound on/off · L turn the wick down or up. In the body board: +/− zoom, 0 home. `d_play.js` `zz_quests.js` `zz_zz_study82.js` `zz_arcana_zbody.js` **[Act I]**

- **Tooltips:** short lore by default; **Shift** (or the MORE stud on touch) shows the full numbers (cost, now and next level, perks, synergies, what it scales with, requirements). `zz_ui_desc.js` **[Act I]**

- **Auto-attack** option (off by default on desktop, on for touch); it uses a chosen skill or the plain attack. `e_ui.js` `zz_ux_touch54.js` **[Act I]**

- **Heavy attack:** hold the attack button past 0.18 s to wind up; full charge at 0.75 s. Release lunges up to 0.9 yd and strikes ×1.25→×2.0 damage and ×2→×3.5 poise damage, costing 12→24 poise. Walking is at 35% speed while charging. Under 10% poise the wind-up is 1.35× and the recovery 1.3× slower (never locked out). A roll cancels it. Option: "Hold to charge heavy attacks". Not for wands or thrown knives. `zz_mech_heavy.js` **[Act I]**

### Gamepad

- **Any standard pad**, detected on first press. Left stick moves; right stick aims (left alone, it aims at the nearest enemy). A attacks, picks up and opens (left skill); X or RT casts the right skill (hold); B rolls; Y drinks. LB/RB cycle the right skill, D-pad ←/→ the left. D-pad ↑ opens skills, ↓ inventory; LT the map; View the character page; Menu pauses. In panels and menus the stick drives a cursor (A click, X right-click, B back). Title and pause menus are walked by stick and D-pad. `x_pad20.js` **[later]**

### Touch (phones and tablets)

- **Detection:** a coarse pointer without a fine one, or any touch; a mouse movement switches back. `w_touch17.js` **[later]**

- **Tap** = left click; **touch and hold** = right click, held while the finger stays (drag to aim). `w_touch17.js` **[later]**

- **Right-hand column:** LOOT (toggle ground labels), AUTO (tap on/off, hold to choose what auto-attack uses; saved with the character), the right-click skill bubble (tap casts at the nearest foe, hold opens the picker), DRINK, ROLL. `zz_touch53.js` `zz_ux_touch54.js` **[later]**

- **Long press** pins the details card on the far side of the screen from the finger; a **quick double tap** in a panel acts as a right click. The body board drags and pinch-zooms; tap once to show a Minor or Major Arcanum, tap again to lay or lift it. `zz_touch53.js` `zz_ux_touch54.js` `zz_arcana_zbody.js` **[later]**

- **Portrait lock:** a "turn your device" screen in portrait on touch devices. `a_head.html` **[later]**

## 3. Hero stats and leveling

- **Three attributes**, all starting at Vitality 15 · Essence 25 · Constitution 15 (`BASE_ATTRS`). `c_game.js` **[Act I]**

- **Life** = 28 + 3×Vitality + 3×level + item life (measured: 76 at level 1; +3 per Vitality point, +3 per level). `c_game.js` **[Act I]**

- **Resource maximum:** Essence and Marrow = 8 + 2×Essence + 1.5×level + item (60 at level 1). Vitae = 20 + 2×Essence + 2×level (72). Miasma = 30 + 1.2×Essence + 1.5×level (62). The Empty Hand's glass = the Essence maximum split into two bulbs of half each. `c_game.js` `m_mias.js` `zz_monk_sand.js` **[Act I]**

- **Resource regeneration per second (measured at level 1):** Hollow Mystic (0.6 + 0.03×Essence)×(1 + 5% per Thread Mastery point) = 1.35. Ossuarch 1.2 + 0.04×Essence = 2.2. Hemomancer 0.5 + 0.012×Essence ≈ 0.8, plus blood pools. Shrine Keeper (1.5 + 0.03×Essence)×0.5 ≈ 1.13, plus breathing in. The Empty Hand 0 (the sand runs back instead). `zz_tune_batch_c.js` `h_blood.js` `zz_tune_batch_d.js` `zz_monk_sand.js` **[Act I]**

- **Poise (max)** = 28 + 1.4×Constitution + 0.08×Vitality + 0.25×base armour (≈52 at level 1). **Regeneration** = 4 + 0.35×Constitution per second (9.25 at level 1), after a 1 s delay following any spend. Walking drains 1.6/s. `zz_tune_batch_d.js` `zz_tune_batch_c.js` **[Act I]**

- **Armour** = Constitution/2 + item armour (+100 under the Shrine of Stone). Physical damage taken ×100/(100+armour). `c_game.js` `d_play.js` **[Act I]**

- **Skill damage multiplier** = 1 + 1.2% per Essence point + item "+% skill damage" (×1.5 under the Shrine of Echoes). **Melee multiplier** = 1 + 1.5% per Constitution point. `c_game.js` **[Act I]**

- **Attack speed** comes from Constitution (measured ×1.0225 at 15, ×1.0375 at 25); **cast speed** baseline 0.72×(1 + faster cast rate%) (0.75 measured). `zz_polish.js` `zz_pace_and_density.js` **[Act I]**

- **Movement speed** = 4.15 yd/s × (1 + effective faster-run%) × 0.75 = 3.11 yd/s at start. Faster-run tapers above 25% (0.6 per point) and is capped at 40%. `zz_movespd_curve.js` `zz_tune_batch_d.js` **[Act I]**

- **Magic resist** capped at 75% (`D.res`). **Nine-element resists** (phys, magic, miasma, blood, void, radiance, fire, cold, poison), each −100…+75%. Damage taken is capped at 2× under negative resist. The legacy "res" affix gives half its value to every non-physical element. `zz_mech_resists.js` `c_game.js` **[Act I]**

- **Magic find, gold find, life on kill, experience bonus** (`mf`, `goldK`, `lok`, `xpK`): from items, the Reading, the Minor Arcana and the dim wick. `c_game.js` `zz_zz_study82.js` **[Act I]**

- **Level cap 99.** XP to next level: floor((60·L^1.9 + 40·L) × (L>30 ? 1+((L−30)/25)² : 1) × (L>85 ? 1+0.35(L−85) : 1)). Measured: 100 (L1), 5,165 (L10), 18,587 (L20), 39,630 (L30), 78,861 (L40). `c_game.js` **[Act I]**

- **XP pacing** (target: level 36–40 at the end of the first playthrough). Kill XP is multiplied by monster level (0.72 at 1 → 0.74 at 24 → 0.78 at 30 → 0.6 at 34 → 0.72 at 40) and by hero level (1.0 to 16 → 0.92 at 21 → 0.9 at 27 → 0.6 at 32 → 0.53 at 40). A hero more than 5 levels above the monster gets −15% per extra level (floor 10%). Targets: end of Act I 16–18, II 24–26, III 30–31, IV 33–35, V 37–39. `zz_progression.js` `d_play.js` **[Act I]**

- **Per level:** +5 attribute points, +1 skill point, +1 Minor Arcana point (from level 2). A level-up refills life and resource. `d_play.js` `zz_arcana_web.js` **[Act I]**

- **Death XP loss:** 0% on Normal, 5% on Nightmare, 10% on Hell (share of the level's XP). `k_arcana.js` **[later]**

- **Starting kit (every order):** 40 gold, belt of 2+2 healing and 2 Essence draughts, 1 skill point, 1 Hollow Token. Gear by order: Mystic a Bone Wand and Ash Robe; Ossuarch a Ritual Knife, Ash Robe and Skull Relic; Hemomancer a Ritual Knife, Ash Robe and Bone Mask; Shrine Keeper Vharn Claws, Ash Robe and Mourning Hood; the Empty Hand Fist Wraps only. A new character opens on the skill page to spend the first point. `d_play.js` `zw_monk.js` `e_ui.js` **[Act I]**

- **Hard points and effective level:** points bought go in `P.hard`; the effective level adds +all-skills and +tree items. Max 20 hard points per skill. Every level past the first counts for 60% (`SKILL_GROWTH`, `L1()`). `k_arcana.js` `c_game.js` **[Act I]**

- **Respec:** the Hollow Token full reset (skills, attributes and Arcana; confirm by clicking twice within 3 s). You start with one; each act-boss and zone boss gives another. `k_arcana.js` **[Act I]**

- **Shrine buffs** last 60 s: Echoes +50% skill damage; the Wisp more wisps and faster regrowth (+2 cap, +100% regen); Stone +100 armour; Refilling restores life and resource at once. `d_play.js` **[Act I]**

## 4. Combat math

- **Player hit on a monster:** damage × 100/(100 + monster armour) × modifiers, then the monster's AI state (`monDmg22`), then resists for the element. Modifiers: Marked (+22–40%), Culled +15%, Tarnish +15%, Frail +15%, confused with Madness +20%, feared with Dread +20%, Grave +15%, Marrow Crush +25%, Ossified +20%. The difficulty HP scale divides the damage. `d_play.js` `zc_combat22.js` `zz_mech_resists.js` `zz_mech_balance.js` **[Act I]**

- **AI-state damage rules:** a flyer high up (z > 8) takes 35%, a swooping one 130%. A lit Gasp takes 150%. The Ossuary Warden's shield blocks 85% from the front arc (cos > 0.34) unless it is recovering or reeling. The Marrow Duelist parries light blows after 3 hits in 1.2 s (heavy = over 14% of its life breaks through) and ripostes for ×1.5 plus 60% of your poise. Reeling creatures take ×1.25 (`breakBonus`), and for 0.8 s after a reel ×1.12. Burrowed creatures take nothing. `zc_combat22.js` `zz_stagger_deep.js` **[Act I]**

- **Monster hit on the player:** there is no to-hit roll. Evasion comes only from the Shrine Keeper's cloud (up to 60%). Order of reduction: difficulty ×(1/1.5/2); dim wick ×1.15; Wraith Form (physical phases through, others ×1.5); armour (physical) or magic resist or per-element resist; the Veil ward (Essence absorbs a share); class absorbs (bone plates and shard aura, Vitae shield, Arcana). Then life loss, poise hit, and a shove only when the blow is heavy (over 12% of max life). `d_play.js` `zz_mech_balance.js` `zz_mech_resists.js` `zz_zv60.js` `zz_zz_study82.js` **[Act I]**

- **Weapon swing:** random weapon damage (min–max) × melee multiplier; a third of it splashes onto anything touching the target. Plain reach 1.5 yd (+Bone Host, +claws). A weapon swing costs 0.55 s/cast speed; the swing pose lasts 0.22 s. `d_play.js` **[Act I]**

- **Melee string (every order, v0.54):** cut ×1.00 (0.85 time, 0.12 yd step) → return cut ×1.10 (0.95 time, 0.2 yd step) → overhead finisher ×1.60 (1.35 time, +0.35 yd reach, 0.42 yd lunge, 4 poise, 0.07 s hit-stop, 0.35 s stagger). The string resets after 0.8 s idle, a roll or a heavy. `zz_melee_chain.js` **[Act I]**

- **Wand basic attack:** a ranged bolt up to 6.5 yd (`WAND_RANGE`) at the monster nearest the cursor. `d_play.js` **[Act I]**

- **Finishing blow:** a melee blow on a reeling creature lands ×2.2 (on top of the reel's ×1.25), with a 0.09 s hit-stop. It returns 15% of your resource (the Empty Hand's sand runs back 20%), a wisp for the Mystic and 20 poise. Once per reel (1.5 s lockout per creature). `zz_zz_study82.js` **[Act I]**

- **Critical hits** exist only where a skill grants them: Death's Head (Shrine Keeper, 5%→40% chance, ×2 or ×3 with Deathblow), One-Finger-Truth (always critical against the stone-cursed). There is no global crit stat. `m_mias.js` `zw_monk.js` **[Act I]**

- **Block** is not a player mechanic. Nearest equivalents: the Empty Hand's That-Which-Bars-The-Way (damage reduction, no knockback), Bell-Of-One-Syllable (stops missiles), Mirror-With-No-Face (reflects melee), Bowl-That-Holds-Nothing (catches frontal missiles). Monsters block with shields (Ossuary Warden) and parry (Marrow Duelist). `zw_monk.js` `zc_combat22.js` **[Act I]**

- **Dodge roll:** costs 34 poise and needs at least 16 (`POISE.rollCost/rollMin`). 0.34 s at 8.5 yd/s toward the cursor with 0.3 s of invulnerability. It ends Wraith Form and cancels infusing, the heavy wind-up and the melee string. Not allowed while stunned or until poise is full after a break. `d_play.js` `zz_zv60.js` **[Act I]**

- **Knockback:** the player is shoved 0.2 yd only by heavy blows (over 12% of max life) or when stunned. A Bellwether charge hits ×1.6, empties your poise and throws you about 1 yd. Skills shove monsters by their own rules. `d_play.js` `zz_zv60.js` `zc_combat22.js` **[Act I]**

- **Damage types in play:** physical (armour), magic (resist), and the elements fire, cold, poison/miasma, blood, void, radiance. Gear affixes add fire, cold, miasma and "magic" damage to **weapon attacks only**, not spells, minions or damage over time. `k_arcana.js` `zz_mech_resists.js` **[Act I]**

- **Elemental procs on weapon hits** (once per 0.35 s per creature): fire deals 50% at once and burns 50% dps for 3 s; cold deals its value and adds 0.3 chill; magic (the old lightning) deals its value, stuns 0.15 s 25% of the time and arcs 25% of the time; poison deals value/2 per second for 3 s. `k_arcana.js` **[Act I]**

- **Damage numbers** (off by default): chunky pixel digits; rapid hits on one creature add up; big hits are drawn twice the size. **Hit flash** is off by default. `za_death21.js` `b_core.js` **[Act I]**

- **Life on kill** (`lok`), **experience per kill**, and loot on kill; corpses stay about 30 s (`CORPSE_LIFE`) for corpse skills, then fade (about a minute visually). `d_play.js` `za_death21.js` **[Act I]**

## 5. Status effects

- **Burn:** dps ticking every 0.5 s. 10% a tick to spread to a neighbour within 2 yd, 5% to set the ground alight. `k_arcana.js` **[Act I]**

- **Chill and freeze:** chill builds (a boss at 35% rate); at 1.0 the creature freezes 1.5 s (a boss 0.6 s). Chilled means at least 30–40% slow for 3 s. **Shatter:** a chilled creature under 10% life bursts 35% of the time (not bosses). `k_arcana.js` **[later]**

- **Poison and miasma sickness:** dps ticking every 0.5 s. Stacks only when a skill says so. 6% of hits leave a small lingering cloud. `k_arcana.js` `m_mias.js` **[Act I]**

- **Bleed** (Hemomancer): damage over time from blood skills; bleeding creatures leave blood pools. Boiling Blood ×1.5; the Blood-Queen card spreads bleeds. `h_blood.js` **[Act I]**

- **Ground fires** (`G.fires`): burn what stands in them every 0.5 s; at most 40. Enemy fire trails (Pyre-Saints) hurt the player. `k_arcana.js` `zc_combat22.js` **[Act I]**

- **Clouds** (`G.clouds`): poison, haze (confusion), frost (chill), ticking every 0.5 s. `k_arcana.js` `m_mias.js` **[Act I]**

- **Crowd control on monsters:** stun (breaks wind-ups; a boss goes to recover), root (no movement), slow (monMove speed × (1 − min(0.6, slow)), decays 0.8/s), confused (wanders and fights others; not bosses), feared (flees), taunted (attacks the golem), marked, possessed (fights for you), silenced (cannot strike 3 s; Pinch), stone (Grip-Of-Old-Stone, next blow shatters), time stop (the Last Silence). `d_play.js` `k_arcana.js` `zw_monk.js` **[Act I]**

- **Marks on the player (Act V natives):** bleed (dps × 3 s), daze 1.4 s, corrosion 4 s (physical hurts more), void-cut (the top 4% of life, up to 25%, hollowed for 4 s), hush (Essence drained near Silence-Keepers), bile and acid pools. `zz_act5.js` **[later]**

- **Fetish-priest venom** (Act III): a landed blow poisons for 3 s. **Leech larvae** spill out of Brood-Swollen Husks. `zz_act3.js` **[later]**

- **Stagger on monsters** (section 6), **ossify** (30% slower, +20% damage taken, 8 s), **crush** (+25% taken, 5 s), **grave root** (1 s root). `zc_combat22.js` `c_game.js` **[Act I]**

## 6. Poise, stagger and the roll

- **Player poise:** one pool. Rolls, heavy attacks, the finisher and every melee skill spend it; landed blows drain it by max(4, damage × 1.8 × 1.5 if heavy) × 1.2. It regenerates after a 1 s delay (section 3). `zc_combat22.js` `zz_zz_light79.js` **[Act I]**

- **Player poise break:** at 0 the hero is stunned and rooted 0.75 s × 1.2 = 0.9 s (plays the hit animation). He cannot move or act, then gets a burst refill to 50% over 0.35 s, then normal regeneration. A 1.6 s grace (no new break) follows the stun. No rolling until poise is full ("too shaken to roll"). The old slow "recovering" state is removed. `zz_zv60.js` `zz_zz_light79.js` `zz_zv61.js` **[Act I]**

- **Monster poise:** max = life × the kind's `poiseK` (×1.6 boss, ×1.2 unique) × 3 (PoE2-style high poise), refilled after 2.2 s without hits. Poise damage = damage dealt (heavy ×2–3.5). `zc_combat22.js` `zz_tune_batch_d.js` **[Act I]**

- **Monster reel:** 0.35 s normal, 0.25 s unique, 0.2 s boss (×1.2 since v79). It breaks wind-ups, gives ×1.25 damage taken, then a 0.8 s stagger (55% walk speed, ×1.12 damage), then a grace of 2 s / 1.4 s / 0.9 s with no poise damage (no stun-lock). `zz_tune_batch_d.js` `zz_stagger_deep.js` `zz_zz_light79.js` **[Act I]**

- **Stagger meter:** a thin bone line under a boss's life (and under a hovered champion or unique) shows its poise giving way. It brightens when primed (≥80% for bosses, 70% for others) and fills while the creature reels. `zz_zz_boss83.js` **[Act I]**

- **Walls stop chargers:** a Bellwether that hits a wall is dazed 2.2 s (reel 2.2 s). `zc_combat22.js` **[Act I]**

## 7. Light, the lantern and the dark (the signature system)

- **The Wickbound lantern** is its own untargetable unit. It floats at shoulder height, trails a little behind while walking, drifts to the hero's side and idles in slow loops when still, and bobs and leans on a soft spring. It throws no shadow; it is the light. Hooks: `window.__lampW()`, `__plLamp()`, `__lampFoot()`. `zz_zy_lanclip64.js` **[Act I]**

- **The dark layer** covers the world. The lantern cuts a pool on the ground: a bright core, three stepped rings, a faint ring at the edge, then darkness deepening to about 2× the radius (never pitch black). By day it is a heavy dusk you can see through. The dark is blue-teal, so warm light reads amber. World flames, campfires, lanterns and each wisp cut their own smaller pools. `zz_zx_dark64.js` `zz_zz_cine76.js` **[Act I]**

- **Light radius:** `heroLightR` = 7 yd outdoors + 1.5 at night, 7.5 underground; ×0.45 near a Silent One (they swallow light). Lantern perk Bright (`lrad`) widens it (`__lampK` = 1.5 + lrad/100 × 0.5). `zd_world22.js` `zz_zw_lantern63.js` **[Act I]**

- **Light is gameplay:** creatures are seen by light (visibility = clamp(light × 1.2 + 0.05, 0.16, 1); emissive Pyre-Saints and hurt creatures always show). Gasps recoil from light and take ×1.5 lit. Moth-Saints are drawn to light. Silent Ones darken everything within 5 yd. `lightLevel()` sums ambient, the hero's lamp (blocked by walls), world lanterns (9 yd), props, fires and altars. `zd_world22.js` `zc_combat22.js` **[Act I]**

- **Occlusion (v84):** walls, cliffs and palisades (whole tiles), tree trunks, rocks and pillars (round bases), statues, gibbets, tents and shrines throw shadows away from the lantern; inside them the dark stays. The four nearest world flames (one in lighter mode) are occluded the same way. `zz_zx_dark64.js` **[Act I]**

- **Lantern perks** roll as item affixes; the strongest wick colour carried tints the light and acts on creatures in it: Bright `lrad` (+10–45% radius), Ghostlight `lblue` (8–20% chance per second to shy away), Hearth `lamber` (+1–3 life/s), Pale wick `lwhite` (slow 10–22%), Green Taper `lgreen` (+1–2 Essence/s), Violet `lviolet` (+1–3 Essence per kill in the light). `zz_zw_lantern63.js` `c_game.js` **[Act I]**

- **Turn the wick down** (L, or tap or click the lantern): the pool shrinks to about 62%. Wake range ×0.7 (you can slip past), creatures hit 15% harder, +40% magic find and +25% gold. The same again turns it up. Dying turns it back up. `zz_zz_study82.js` **[Act I]**

- **The lantern keeps a little:** each death adds one kept (max 3): −12% light, −10% magic find and −10% gold find each. What it kept waits where you fell as a small pale light (a remnant forms even with no gold). You must walk 2.5 yd away and come back to it; the lantern then takes it all back and mends 25% life. `zz_zz_study82.js` **[Act I]**

- **The flame's mood:** below 30% life the pool shrinks and stutters; when a boss wakes the flame gutters and draws in (`__lampMood`). `zz_zz_cine76.js` **[Act I]**

- **Shadows:** the hero throws a true silhouette shadow away from the lantern, plus one from each nearby flame (the nearer darker), and by day a sun shadow that turns and lengthens with the hour. The lantern throws monsters' shadows (desktop only). No blob under the feet. `zz_zz_shadow70.js` `zz_zz_cine76.js` `zz_zz_perf74.js` **[Act I]**

- **Eye-shine:** creatures in the dark facing you show two points of light, brighter when hunting. `zz_zz_cine76.js` **[Act I]**

- **Item glints:** items lying in your pool catch the light every few seconds. `zz_zz_cine76.js` **[Act I]**

- **Distant heat-lightning:** rarely, at night on open ground, a cold far flash lights the land for a breath (never in town or a boss fight; at most about once a minute; no sound). `zz_zz_cine76.js` **[later]**

- **Moonlit clearings:** 2–3 per outdoor zone on open ground, lit at night. Standing in one gives poise 1.5× as fast and mends 0.6% life/s; one line the first time. `zz_zz_moon86.js` **[later]**

- **Light shafts** through the canopy in the woods by day (off in lighter mode). `zz_zz_moon86.js` **[later]**

- **Class lamp colours:** Mystic ghostly blue (176,214,255); Ossuarch a skull with a candle, bone-white vapour; Hemomancer a neutral warm white so his dark brown skin reads true (no red cast); Shrine Keeper violet (200,150,255); the Empty Hand a black-flame lantern. `zz_zv61.js` `zz_tune_v59.js` `zd_world22.js` **[Act I]**

- **Flames without strobe:** every flicker is eased over about 0.2 s. `zz_zz_light79.js` **[Act I]**

- **Ambient grading:** per-land day and night ambient (the moor, wood, fen and Ossa lands; underground dimmer), dropped in v59 so the lantern carries the scene. `zz_tune_v59.js` `zz_grade55.js` `y_light21.js` **[Act I]**

---

## 8. The five orders

The shared rules for all five orders are in section 9 (trees and points). The code ids are `animancer` (Hollow Mystic), `ossumancer` (Ossuarch), `hemomancer`, `miasmancer` (Shrine Keeper) and `monk` (the Empty Hand). The Reading picks the order through the god chosen (section 11). Each order has its own lamp colour, body board, Major Arcana, HUD orb and class panel.

### 8.1 The Hollow Mystic (`animancer`): Essence and the choir of wisps

- **Resource: Essence** (the mana pool): max 8 + 2×Essence + 1.5×level; regen (0.6 + 0.03×Essence)×(1 + 5% per Thread Mastery point). The Mystic's skill costs are +20% (v58); every skill level adds 5% to its cost (base cost × 1.6 `COST_MULT` already in the data). `zz_tune_batch_c.js` `zz_tune_v58.js` `o_skills14.js` **[Act I]**

- **The choir of wisps:** revenant wisps drift round him and dive at what comes near, then regrow. Cap = 4 + ⌊Wisps level/3⌋ + 1 (Bright Choir perk) + item "+max wisps" (at most 3) + 2 (Shrine of the Wisp). Regrowth each = max(0.4, 2.6 − 0.1×Wisps) s ÷ (1 + (item regen% + 4%×Choir Mastery)/100), ÷1.2 with Quickened. `c_game.js` `d_play.js` `zy_anim.js` **[Act I]**

- **One choir, chances on each wisp strike (v90):** snag a thread (the foe is slowed and jarred) 4% + 1% per Wisps point, max 20%. Pass on untired (Restless Dead) 10% + 3%/pt, max 45%. A needle through the foe cuts what stands behind (Darting Wisps; 2.6 yd, 4.5 with Long Needle) 8% + 2.5%/pt, max 40%. A spark splits off at another foe (Splitting Wisps; two with Wide Split) 8% + 2.5%/pt, max 40%. Rolled independently per strike. `zz_zz_mystic90.js` **[Act I]**

- **Wisps are fuel (v80):** every spell burns 1 wisp (2 if its cost is at least 40) but is never refused. His spell damage is ×(0.65 + 0.55×choir fraction): 65% with no wisps, 120% at a full choir. Soul Swarm, Soul Storm, Condense and the plain attack keep their own wisp costs; melee and the golem are not affected. `zz_zz_light79.js` **[Act I]**

- **The choir shapes the spell (v81)**, judged at cast. A full choir (≥80%) adds one mirror, pillar, bounce or totem, and a thin one (<20%) takes one away (never below 1). Durations run ×0.75→×1.15 and sizes ×0.8→×1.1 from an empty to a full choir. `zz_zz_light79.js` **[Act I]**

- **The mirror rule:** wisps and darts rebound off standing mirrors, the golem and its shield, renewed: ×1.25 per bounce (+Resonance), up to 3 bounces (+1 with Resonance), and a rebound buys extra leaps. `c_game.js` `zy_anim.js` **[Act I]**

- **Burrowed creatures** count as absent for everything the wisps do (no targeting, no sparks, needles or threads). `zz_zz_thread93.js` **[Act I]**

- **The Iron Golem:** permanent. At 0 life it goes dormant and rises after max(8, 22 − 0.7×level) s. Casting it again sends it to the cursor; casting it on itself banishes it. It carries a weapon loadout: Knight Sword (fast, may strike twice), Headsman Axe (cleave arc), Morning Star (reach, splash, stun). Its orders (G panel): an Attack↔Guard and Close↔Roam grid plus charge, shield toss, focus and hold toggles. `d_play.js` `e_ui.js` `zb_giants21.js` **[Act I]**

- **The choir panel (V):** the four chances and the wisps' behaviour grid (range and aggression, focus, hold). `e_ui.js` `zz_zz_mystic90.js` **[Act I]**

- **Veil and Wraith Form** (Thread tree): the ward lets Essence soak blows (70%→95% of a blow, 1 Essence stops 1.06→2.2 damage). Wraith Form (toggle) drains Essence while you walk through the living, is untouched by physical blows but takes ×1.5 from magic, and moves at up to ×1.35. `c_game.js` `d_play.js` `zz_movespd_curve.js` **[Act I]**

- **The Mystic's skills, by tree** (the Mirror skills hit +20% since v88, already in these numbers):

#### Mirror tree (tab 0)

- **`pillars` Standing Mirrors** (row 1, level 1, cast; cost Essence 26.9→39 (L10)): Tall panes of polished silver burst from the ground in a wall at the target: they cut and stun as they rise, then stand as cover. Your wisps rebound off them renewed, brighter and with more leaps in them. Numbers: L1: 3 mirrors · 22 damage as they rise · stand 10.5s / L10: 5 mirrors · 81 damage as they rise · stand 15.0s / L20: 7 mirrors · 146 damage as they rise · stand 20.0s. Perks (at skill level): L6 Lure of the Glass: Enemies are drawn to their own reflections: mirrors drag nearby enemies toward them. L12 +50 Essence Resonance: Wisps rebound off mirrors harder, gain more leaps, and can rebound more times. Synergies (per hard point): Mirror Fissure +4%, Hall of Mirrors +3%, Falling Mirror +3%. `zz_zz_fix88.js` `c_game.js` `o_skills14.js` `d_play.js` **[Act I]**

- **`golem` Iron Golem** (row 1, level 1, cast; cost Essence 38.4→55.7 (L10)): A hulking knight of iron polished to a mirror sheen that never dies: at zero life it falls dormant and rises again. Your wisps rebound off it. Once summoned, casting it again orders it to that spot; casting it on the golem itself banishes it. With Overcharge you pour wisps into it: each one heals it and adds a charge. Full charge sends it berserk. G opens its orders and weapon loadout. Numbers: L1: Life 101 · hits 7-12 · charged aura 11/s · rises after 21s / L10: Life 290 · hits 23-34 · charged aura 41/s · rises after 18s / L20: Life 500 · hits 41-58 · charged aura 90/s · rises after 13s. Perks (at skill level): L5 Bulwark: Its shield charge knocks enemies back harder. L10 Juggernaut: Berserk lasts longer (up to 30s) and hits harder. L15 +60 Vitality Living Mirror: More life, damage and armor. Synergies (per hard point): Reflection +2.5%, Dazzling Challenge +2.5%, Overcharge +2.5%. `c_game.js` `d_play.js` `e_ui.js` **[Act I]**

- **`fissure` Mirror Fissure** (row 2, level 6, cast; cost Essence 34.6→50.2 (L10); needs Standing Mirrors): A crack of mirror-glass races along the ground toward the target, and jagged shards burst up out of it, cutting and stunning. The ground it leaves stays cracked mirror for a while: any wisp that crosses the broken glass fissures into more wisps. The last shards stay standing as mirrors, cracked, and split wisps too. Numbers: L1: 25 per shard · 5.2 yd of cracked glass for 5.3s · last 1 stand as mirrors / L10: 92 per shard · 7.0 yd of cracked glass for 7.5s · last 2 stand as mirrors / L20: 167 per shard · 9.0 yd of cracked glass for 10.0s · last 4 stand as mirrors. Perks (at skill level): L5 Deep Crack: The shards stun twice as long. L10 +50 Constitution Flying Glass: Every shard flings slivers of glass to either side. Synergies (per hard point): Standing Mirrors +4%, Falling Mirror +4%. `zz_zz_fix88.js` `c_game.js` `o_skills14.js` `zy_anim.js` **[Act I]**

- **`overcharge` Overcharge** (row 2, level 6, hold; cost none; needs Iron Golem): Hold to pour your wisps into the Iron Golem. Each wisp heals it and adds a charge; at full charge it goes berserk in white fire, then bursts. Each level needs more wisps for a full charge, but the rampage lasts longer and hits harder. The charge never needs more wisps than you can hold, and a charge left alone slowly bleeds its wisps back to you. Numbers: L1: Full charge: 3 wisps · rampage 10.6s at x1.33 · burst 43 / L10: Full charge: 4 wisps · rampage 16.0s at x1.60 · burst 151 / L20: Full charge: 4 wisps · rampage 22.0s at x1.90 · burst 271. Perks (at skill level): L5 Ghostfire: While berserk, its white beams fire twice as often. L10 Wellspring: When the rampage ends, every wisp poured in returns to you at once. L15 +55 Essence Overload: The final burst is half again as wide and twice as hard. `c_game.js` `d_play.js` `o_skills14.js` **[Act I]**

- **`toss` Mirror Shield** (row 2, level 6, passive; cost none; needs Iron Golem): The golem hurls its mirror-bright tower shield at distant foes. It spins at the end of its flight, then flies back. Wisps rebound off it the whole way. Numbers: L1: Shield hits for x0.90 golem damage · spins 0.9s / L10: Shield hits for x1.44 golem damage · spins 1.3s / L20: Shield hits for x2.04 golem damage · spins 1.8s. Perks (at skill level): L5 Ricochet: The shield bounces between more enemies. L10 +45 Constitution Crushing Rim: The shield stuns what it hits for a full second. Synergies (per hard point): Iron Golem +3%, Reflection +2%. `e_ui.js` `c_game.js` `o_skills14.js` **[Act I]**

- **`cage` Hall of Mirrors** (row 3, level 12, cast; cost Essence 46.1→66.8 (L10); needs Mirror Fissure): A ring of standing mirrors bursts up around the target, caging whatever stands inside. Wisps that fly into the hall rebound from mirror to mirror, gaining a leap from each. Numbers: L1: 7 mirrors · 16 damage each · stand 6.3s / L10: 9 mirrors · 58 damage each · stand 9.0s / L20: 11 mirrors · 105 damage each · stand 12.0s. Perks (at skill level): L5 Razor Glass: Whatever is caged inside is cut every second. L10 +50 Constitution Shattering Hall: When the hall ends its mirrors shatter inward, cutting everything inside. Synergies (per hard point): Standing Mirrors +4%, Mirror Fissure +3%. `zz_zz_fix88.js` `c_game.js` `d_play.js` `o_skills14.js` **[Act I]**

- **`challenge` Dazzling Challenge** (row 3, level 12, passive; cost none; needs Iron Golem): Every few seconds the golem flashes its polished face: nearby enemies, dazzled by their own reflection, must fight it instead of you. Numbers: L1: Taunts within 3.6 yd every 5.8s / L10: Taunts within 4.5 yd every 4.5s / L20: Taunts within 5.5 yd every 3.0s. Perks (at skill level): L5 Blinding Flash: The flash also slows enemies by 30% for 3 s. L10 +50 Vitality Defiance: For 3 s after each challenge, the golem takes 30% less damage. `c_game.js` `o_skills14.js` `k_arcana.js` **[Act I]**

- **`thorns` Reflection** (row 3, level 12, passive; cost none; needs Mirror Shield): The golem's polish throws blows back: enemies that strike it in melee take part of the damage back. Numbers: L1: Returns 85% of melee damage / L10: Returns 310% of melee damage / L20: Returns 560% of melee damage. Perks (at skill level): L8 Anima Overflow: Damage the golem takes also charges it, and its final burst looses a ring of seeking souls. L14 +55 Vitality Cutting Glare: Enemies that strike your mirror-iron are staggered. `o_skills14.js` `k_arcana.js` `d_play.js` **[Act I]**

- **`anvil` Falling Mirror** (row 4, level 18, cast; cost Essence 38.4→55.7 (L10); needs Hall of Mirrors): A great mirror drops out of the sky onto the target. It crushes and stuns everything under it, and its glass bursts outward in a ring of flying shards. The cracked mirror stands where it fell until it breaks: wisps rebound off it, and split on its broken glass. Numbers: L1: 34 crush · 8 shards × 8 · stands 8s / L10: 127 crush · 16 shards × 51 · stands 16s / L20: 230 crush · 16 shards × 92 · stands 16s. Perks (at skill level): L5 Shatterburst: Twice as many shards burst out, and they cut deeper. L10 Heavy Frame: The mirror stands twice as long, and enemies near it, caught by their reflection, are slowed. L15 +55 Constitution Mirror Rain: Two more mirrors fall around the first. Synergies (per hard point): Mirror Fissure +5%, Standing Mirrors +4%. `zz_zz_fix88.js` `o_skills14.js` `e_ui.js` `d_play.js` **[later]**

- **`forge` Quicksilver Heart** (row 6, level 30, passive; cost none): The heart of your work runs silver-quick. Mirrors, glass and the golem all strike harder, and every pane you raise stands longer before it silvers over and falls. Numbers: L1: Mirrors and glass +8% damage · mirrors stand +4% / L10: Mirrors and glass +80% damage · mirrors stand +40% / L20: Mirrors and glass +160% damage · mirrors stand +80%. Perks (at skill level): L5 Tempered Glass: Standing mirrors stand 50% longer. L10 +60 Constitution Sun-Catch: The golem's polish catches the light: its blows set enemies on fire. `c_game.js` `zy_anim.js` `e_ui.js` **[later]**

#### Soul tree (tab 1)

- **`wisps` Wisps** (row 1, level 1, passive; cost none): Your choir of wisps drifts around you and dives at what comes near. More points: more wisps, faster regrowth, harder strikes, and a better chance that a strike snags a thread: the foe is slowed and jarred. V: how they behave. Numbers: L1: 4 wisps · 2 per strike · snag 5% / L10: 9 wisps · 5 per strike · snag 14% / L20: 14 wisps · 8 per strike · snag 20%. Perks (at skill level): L5 Quickened: Wisps regrow 20% faster. L10 +50 Essence Bright Choir: One more wisp in your choir. Synergies (per hard point): Restless Dead +3%, Cull +2.5%. `zz_zz_mystic90.js` `c_game.js` `o_skills14.js` **[Act I]**

- **`restless` Restless Dead** (row 2, level 6, passive; cost none; needs Wisps): Revenants fly faster and pass through more of the living before they tire. Each strike has a chance to pass on without tiring at all. Numbers: L1: 3 strikes before rest · pass on 13% / L10: 6 strikes before rest · pass on 40% / L20: 9 strikes before rest · pass on 45%. Perks (at skill level): L5 Grave Burst: Revenants explode when they perish. L10 +45 Essence Soul Leech: Revenant passes steal life and Essence. `zz_zz_mystic90.js` `c_game.js` `o_skills14.js` **[Act I]**

- **`beam` Darting Wisps** (row 2, level 6, passive; cost none; needs Wisps): Each wisp strike has a chance to drive a needle of soul-light straight through the foe, cutting everything standing behind it. Numbers: L1: needle 11% · 1 damage · 2.6 yd / L10: needle 33% · 2 damage · 4.5 yd / L20: needle 40% · 2 damage · 4.5 yd. Perks (at skill level): L5 Long Needle: The needle runs much farther. L10 +50 Essence Searing Needle: The needle sets what it cuts on fire. Synergies (per hard point): Splitting Wisps +3%, Soul Lantern +2.5%. `zz_zz_mystic90.js` `c_game.js` `d_play.js` `zy_anim.js` **[Act I]**

- **`cull` Cull** (row 3, level 12, cast; cost Essence 11.5→16.7 (L10); needs Restless Dead): Every drifting revenant wisp dives at once through the enemies at the cursor, then comes home. No wisps are spent. Perks (at skill level): L5 Culling Mark: Enemies the dive strikes take 15% more damage for 4 s. L10 +50 Essence Twice Through: The revenants strike again on their way home. `o_skills14.js` `zz_mech_trees.js` `p_ui14.js` **[Act I]**

- **`condense` Condense** (row 3, level 12, hold; cost Essence 3.8→5.5 (L10) while held (per tick/unit); needs Wisps): Hold: stand still and crush wisps into one great wisp that grows with each one. Release it to hunt. Those wisps stay spent until it fades. Numbers: L1: 1 wisp per 0.31s · up to 7 · 7 per pass (+35% per wisp) / L10: 1 wisp per 0.23s · up to 16 · 24 per pass (+35% per wisp) / L20: 1 wisp per 0.14s · up to 26 · 44 per pass (+35% per wisp). Perks (at skill level): L5 Radiant Core: The great wisp pulses light that burns everything around it. L10 +55 Essence Supernova: When it fades, it detonates. Synergies (per hard point): Wisps +2.5%, Cull +2%. `c_game.js` `d_play.js` `zz_zz_thread93.js` **[Act I]**

- **`prism` Splitting Wisps** (row 3, level 12, passive; cost none; needs Darting Wisps): Each wisp strike has a chance to split: a spark of the wisp breaks off and darts at another foe nearby. Numbers: L1: split 11% · 1 spark · 1 damage / L10: split 33% · 2 sparks · 1 damage / L20: split 40% · 2 sparks · 2 damage. Perks (at skill level): L5 Wide Split: Two sparks break off instead of one. L10 +55 Essence Bright Sparks: Sparks hit 30% harder. Synergies (per hard point): Darting Wisps +3%, Soul Lantern +2.5%. `zz_zz_mystic90.js` `c_game.js` `e_ui.js` `d_play.js` **[Act I]**

- **`proc` Procession** (row 4, level 18, hold; cost Essence 3.6→5.2 (L10) while held (per tick/unit); needs Condense): Hold: your choir leaves you and circles the cursor in a slow ring, striking whatever is inside it. The wisps' chances to snag, pierce and split ride on every strike. Release and they come home. Costs Essence while held. Numbers: L1: 1 per strike · ring 1.7 yd · 3.6 Essence a second / L10: 1 per strike · ring 2.6 yd · 3.6 Essence a second / L20: 1 per strike · ring 2.6 yd · 3.6 Essence a second. Perks (at skill level): L5 Wide Procession: The ring is almost a yard wider. L10 +50 Essence Dirge: What the procession strikes is slowed. `zz_zz_thread93.js` **[later]**

- **`totem` Soul Lantern** (row 4, level 18, cast; cost Essence 28.8→41.8 (L10); needs Splitting Wisps): Plant a lantern of grave-light. Enemies in its light are exposed (they take 15% more damage), and each one that dies in it frees a wisp for you and mends a little of your life. Numbers: L1: Houses 3 wisps · 10 dmg/s each · lasts 15s / L10: Houses 5 wisps · 38 dmg/s each · lasts 22s / L20: Houses 7 wisps · 70 dmg/s each · lasts 30s. Perks (at skill level): L5 Beacon: You and your golem mend while standing in its light. L10 +55 Essence Grasping Light: The lantern drags enemies toward it. Synergies (per hard point): Darting Wisps +3%, Soul Leash +3%. `o_skills14.js` `c_game.js` `d_play.js` **[later]**

- **`choir` Choir Mastery** (row 5, level 24, passive; cost none; needs Cull): Your choir sings louder. Every wisp bites harder into the living, and the dead climb back into your orbit sooner. Numbers: L1: +12% wisp damage · +4% regrowth / L10: +120% wisp damage · +40% regrowth / L20: +240% wisp damage · +80% regrowth. Perks (at skill level): L5 Soul Harvest: Kills can free a wisp at once. L10 +60 Essence Hymn of Rest: Every kill mends 1% of your life for each 3 wisps in your choir. `e_ui.js` `c_game.js` `zz_ui_hud.js` **[later]**

- **`animam` Anima Mastery** (row 6, level 30, passive; cost none): The great wisp burns brighter, the Soul Leash bites deeper, and the Soul Lantern draws its dead more hungrily. Numbers: L1: +10% echo and great wisp damage · echoes +8% life / L10: +100% echo and great wisp damage · echoes +80% life / L20: +200% echo and great wisp damage · echoes +160% life. Perks (at skill level): L5 Stronger Bindings: Soul Leash lasts half again as long. L10 +65 Essence Great Soul: The great wisp holds 20% more. `c_game.js` `e_ui.js` **[later]**

#### Thread tree (tab 2)

- **`swarm` Soul Swarm** (row 1, level 1, cast; cost Essence 15.4→22.3 (L10)): Spend up to 3 wisps to loose a swarm of seeking souls. The more wisps you still hold, the more souls fly. Numbers: L1: 9 per soul · 2 souls per wisp spent / L10: 51 per soul · 2 souls per wisp spent / L20: 122 per soul · 2 souls per wisp spent. Perks (at skill level): L5 Ravenous Souls: Souls tear through several enemies. L10 +50 Essence Soul Legion: Each wisp spent looses more souls. Synergies (per hard point): Soul Storm +4%, Binding Thread +3%. `c_game.js` `d_play.js` `o_skills14.js` **[Act I]**

- **`ward` Veil** (row 1, level 1, passive; cost none): Your Essence answers the blow before your body does. Cuts and curses bruise the ward first, and only what breaks it ever reaches skin. Numbers: L1: Essence absorbs 70% of damage · 1 Essence stops 1.06 / L10: Essence absorbs 83% of damage · 1 Essence stops 1.60 / L20: Essence absorbs 95% of damage · 1 Essence stops 2.20. Perks (at skill level): L3 Quick Ward: The ward soaks a little more at once. L6 +50 Essence Rebuke: When the ward soaks enough, a whip of white light lashes out at your attackers. `c_game.js` `zz_openness.js` `zz_mech_trees.js` **[Act I]**

- **`lance` Needle and Thread** (row 1, level 1, hold; cost Essence 5.8→8.4 (L10) while held (per tick/unit)): Loose a darting wisp at the enemy nearest the cursor. It ricochets from foe to foe like a leaping arc, weaker with each leap, trailing a comet of soul-light. Mirrors catch it: a rebound off your golem, its shield or your mirrors costs it nothing and buys two more leaps. Hold to keep loosing them. Numbers: L1: 14 per strike · 3 leaps · reach 6.2 yd · -18% per leap / L10: 44 per strike · 5 leaps · reach 7.3 yd · -18% per leap / L20: 76 per strike · 7 leaps · reach 8.5 yd · -18% per leap. Perks (at skill level): L5 Focused Dart: The longer you hold it, the harder the darts strike. L10 Prismatic Dart: Every rebound off a mirror splits off sparks at nearby enemies. L15 +60 Essence Siphon: Returns part of its damage as life and Essence. Synergies (per hard point): Spool +3%, Unravelling +2.5%. `zz_zz_mystic90.js` `c_game.js` `d_play.js` `zy_anim.js` **[Act I]**

- **`wraith` Wraith Form** (row 2, level 6, cast; cost Essence 15.4→22.3 (L10); needs Veil): Toggle: your body thins to grave-smoke. You walk through the living untouched and drift through walls of flesh, and no blade knows where to find you. Essence bleeds out as you go, and the first strike you make drags you back. Numbers: L1: Drain 6.8 Essence/s · speed x1.21 / L10: Drain 4.5 Essence/s · speed x1.28 / L20: Drain 2.0 Essence/s · speed x1.35. Perks (at skill level): L5 Phantom Step: You leave afterimages that burst a moment later. L10 +50 Essence Wraith Haste: Wraith Form is a quarter faster. `c_game.js` `d_play.js` `zz_movespd_curve.js` **[Act I]**

- **`storm` Soul Storm** (row 3, level 12, cast; cost Essence 48→69.6 (L10); needs Soul Swarm): Spend two wisps to tear a shrieking vortex open at the target. It hangs there and spits seeking souls into everything in reach until its throat closes. Numbers: L1: Lasts 3.2s · a soul every 0.20s / L10: Lasts 7.5s · a soul every 0.15s / L20: Lasts 10.5s · a soul every 0.10s. Perks (at skill level): L5 Wide Eye: The storm lasts half again as long. L10 +60 Essence Tempest: Storm souls strike one more time. `c_game.js` `d_play.js` `o_skills14.js` **[Act I]**

- **`mark` Needle's Mark** (row 3, level 12, cast; cost Essence 19.2→27.8 (L10); needs Soul Swarm): Speak a brand over the living in a wide arc: their true names blister in the air above them, and every blow you and your choir land on the marked burns deeper. Numbers: L1: +22% damage taken · 2.3 yd · 8s / L10: +40% damage taken · 4.5 yd · 12s / L20: +60% damage taken · 5.7 yd · 16s. Perks (at skill level): L5 Wide Brand: The brand covers half again the area. L10 +50 Essence Soul Brand: Marked enemies that die release a seeking soul. `c_game.js` `d_play.js` `zz_hero_miasmancer.js` **[Act I]**

- **`orb` Spool** (row 3, level 12, cast; cost Essence 34.6→50.2 (L10); needs Needle and Thread): Hurl a slow white orb of bound life essence. It sprays aether shards in a spiral as it flies, then bursts into a ring of shards. Numbers: L1: 7 per shard · range 8 / L10: 24 per shard · range 8 / L20: 44 per shard · range 8. Perks (at skill level): L5 Aether Shards: More shards, and each one pierces. L10 +60 Essence Orb Cascade: The burst splits into smaller orbs. Synergies (per hard point): Needle and Thread +3%, Unravelling +3%. `d_play.js` `c_game.js` `o_skills14.js` **[Act I]**

- **`leash` Soul Leash** (row 4, level 18, cast; cost Essence 19.2→27.8 (L10); needs Needle's Mark): Every wisp in your choir throws a thread to an enemy near it. For a few seconds each thread burns the enemy it holds and cuts whatever crosses it. The threads move with the wisps, so they sweep through a crowd. With no wisps you throw three threads yourself, weaker. Numbers: L1: 12 a second on each thread · 3.1s · 1 per wisp / L10: 52 a second on each thread · 4.0s · 2 per wisp / L20: 92 a second on each thread · 5.0s · 2 per wisp. Perks (at skill level): L5 Barbed Thread: The threads slow whatever they hold or cut, and bite harder. L10 Double Thread: Each wisp throws two threads. L15 +70 Essence Soul Snare: An enemy that dies on a thread frees a wisp. Synergies (per hard point): Soul Lantern +3%, Cull +2.5%. `zz_zz_thread93.js` `c_game.js` `d_play.js` **[later]**

- **`word` Unravelling** (row 4, level 18, cast; cost Essence 53.8→78 (L10); needs Spool): Speak a word that unmakes. A sigil opens at the target, drags every enemy near it toward its heart for a second, then implodes. Perks (at skill level): L5 Wide Sigil: The sigil is half again as wide. L10 +60 Essence Echoing Word: The word is spoken twice. Synergies (per hard point): Spool +4%, Needle's Mark +3%. `o_skills14.js` `zz_mech_trees.js` `p_ui14.js` **[later]**

- **`chain` Binding Thread** (row 5, level 24, cast; cost Essence 23→33.4 (L10); needs Unravelling): Threads run from the enemy at the cursor to others near it, draw taut and drag them in against it. When they snap tight, every one of them is struck, jarred and slowed. The great are held, not dragged. Numbers: L1: binds 3 more · 16 on the snap · 5.5 yd / L10: binds 6 more · 58 on the snap · 5.5 yd / L20: binds 8 more · 105 on the snap · 5.5 yd. Perks (at skill level): L5 More Thread: Two more enemies are bound. L10 +55 Essence Knotted: Every enemy bound is Marked for 3 s. Synergies (per hard point): Soul Swarm +3%, Soul Storm +3%. `zz_zz_mystic90.js` `o_skills14.js` `zi_beasts22.js` **[later]**

- **`nmastery` Thread Mastery** (row 6, level 30, passive; cost none): The word made force sharpens on your tongue. Every Logos spell speaks harder, and its Essence flows back to you sooner. Numbers: L1: +10% Logos damage · +5% Essence regen / L10: +100% Logos damage · +50% Essence regen / L20: +200% Logos damage · +100% Essence regen. Perks (at skill level): L5 Word of Power: Logos spells cost 10% less. L10 +70 Essence Last Word: Every kill returns 3 Essence. `c_game.js` `e_ui.js` **[later]**

### 8.2 The Ossuarch (`ossumancer`): Marrow and the shard aura

- **Resource: Marrow** (mana, shown pearly bone-white): max 8 + 2×Essence + 1.5×level; regen 1.2 + 0.04×Essence (2.2 at start). Tooltips still label the cost "Essence"; the HUD shows Marrow. `c_game.js` `zz_hud54.js` **[Act I]**

- **The shard aura** is armour, ammunition and army at once. Cap = 20 + 2×Shard Aura level + Essence/5 + 4 per item "+max wisps" (at most 3), ×1.5 in the Bone Host with Shard Skin (25 at start). Shards tear out of the ground on their own at 0.22 + 0.014×aura level + 0.0016×Essence per second (×4 while holding Shard Aura, ×1.15 with Quick Bone, max 2.4/s), within 3 + 0.25×aura level yd (×1.5 with Deep Pull). A pulled shard cuts what it passes. `f_bone.js` **[Act I]**

- **Shards as armour:** each held shard turns 0.6% of a blow (+0.08% per Carapace Mastery point), capped at 45% (+1% per Carapace Mastery point). The Maelstrom card reversed removes this. `f_bone.js` **[Act I]**

- **Shards as ammunition:** bone spells cost shards (Lean Marrow −1). **Bone spells weaken as the aura thins:** power = skill damage multiplier × (1 + 10% per Bone Mastery point) × (floor + (1 − floor) × fullness), floor 55% (+2% per Bone Mastery point, +20% with Deep Marrow, max 95%). `f_bone.js` **[Act I]**

- **The army:** skeletons claw up out of the aura on their own when there is room. Each holds 5 shards while it stands, rises about every 4 s (min 2.4 s), and draws on its own marrow reserve (refills 0.36 + 0.012×Raise per second; ×4 while pulling; ×1.5 near corpses). A fallen skeleton gives nothing back. Max skeletons = 2 + ⌊(Raise level − 1)/3⌋ (+1 at Bone Legion 1, +1 at 10, +1 Endless Legion). `f_bone.js` **[Act I]**

- **Army orders (V or G):** three squads, each with a count, loadout and orders grid. Loadouts: Sword and Shield (×1.45 life, ×0.7 damage, 25% damage reduction, taunts), Greatsword (×1.15, sweeps), Halberd (1.55 yd reach, knockback), Flail (×1.2, 0.5 s stun), Bow (5.5 yd; needs the Bowyer card), Grave Staff mage (casts a small copy of your last Bone spell; needs the Grave-Chanter card). The Colossus has its own weapon: Tower Shield, Bone-Scythe Arm, Twin Swords or Spine-Flail. `f_bone.js` `g_bone_ui.js` **[Act I]**

- **Active bone melee:** Carapace strikes are D2 Paladin or Barbarian-style skills on either button, costing poise (Bone Blade 5, Spine Lash 6, Scythe Sweep 7, Marrow Crush 8, Grinding Charge 10, Grave Leap 12). His weapon becomes that skill's bone weapon for the stroke. Held strikes repeat. `zz_ossu_active_melee.js` `zz_bone_melee_shard_costs.js` **[Act I]**

- **Lantern rest:** at a lantern the aura refills to full, the Bone Host refills and the Colossus mends. `d_play.js` **[Act I]**

- **The Ossuarch's skills, by tree:**

#### Ossuary tree (tab 0)

- **`raise` Raise Skeleton** (row 1, level 1, passive; cost none): Skeletons claw their way up out of your aura on their own whenever there is room for them. Each one holds 5 shards of the aura while it stands. In army orders (V) you split them into three squads, each with its own size, loadout and orders. When you direct the Colossus, they follow it. Numbers: L1: Up to 2 skeletons · life 9 · hits 2-3 · each holds 5 shards / L10: Up to 3 skeletons · life 28 · hits 6-10 · each holds 5 shards / L20: Up to 5 skeletons · life 49 · hits 11-18 · each holds 5 shards. Perks (at skill level): L5 Bone Burst: Skeletons that fall burst into shards that cut everything around them. L10 Marrow-Knit: Skeletons mend three times as fast near you, and slowly everywhere else. L15 +50 Vitality Hardened Bone: All your skeletons take far less damage. Synergies (per hard point): Prayer Banner +2.5%, Death March +2.5%. `f_bone.js` `zz_hero_hemomancer.js` `zw_monk_ui.js` **[Act I]**

- **`banner` Prayer Banner** (row 2, level 6, cast; cost Marrow 19.2→27.8 (L10); needs Raise Skeleton): Plant a stave of bone hung with prayer-strips of flayed hide. Your skeletons and the Colossus fight faster and mend in its shadow; the living wither and slow as they draw near. Numbers: L1: Minions within 3.0 yd strike 31% faster and mend 3%/s · enemies slowed / L10: Minions within 5.0 yd strike 36% faster and mend 3%/s · enemies slowed / L20: Minions within 5.4 yd strike 42% faster and mend 3%/s · enemies slowed. Perks (at skill level): L5 Tall Banner: It reaches half again as far. L10 +50 Constitution Dread Standard: Enemies that first come near it flee in terror for a second. `o_skills14.js` `zz_mech_trees.js` `zz_act2.js` **[Act I]**

- **`offering` Bone Offering** (row 2, level 6, cast; cost Marrow 4.8→7 (L10); needs Raise Skeleton): Tear apart the skeleton nearest the cursor. Its bones burst outward as a spray of shards that pierce what they hit, and its share of the aura comes straight back to you. Numbers: L1: 8 shards · 10 each · 5 shards back to your aura / L10: 8 shards · 38 each · 5 shards back to your aura / L20: 8 shards · 70 each · 5 shards back to your aura. Perks (at skill level): L5 Blood Price: Each offering mends 8% of your life. L10 +50 Essence Bone Nova: The shards fly out in a full ring and pierce twice as many. Synergies (per hard point): Raise Skeleton +4%, Bone Lance +2.5%. `o_skills14.js` `z_props21.js` `p_ui14.js` **[Act I]**

- **`tithe` Grave Tithe** (row 2, level 6, passive; cost none; needs Raise Skeleton): The grave takes its share. Every kill owes bone to your aura, and now and then a shard tears loose from the dying and flies straight into your orbit. Numbers: L1: 13% chance per kill for a shard / L10: 24% chance per kill for a shard / L20: 36% chance per kill for a shard. Perks (at skill level): L5 Full Tithe: Champions and uniques always give two shards. L10 +45 Vitality Bone Tax: Each tithed shard mends 1% of your life. `f_bone.js` `zz_mech_trees.js` `g_bone_ui.js` **[Act I]**

- **`horn` Death March** (row 3, level 12, cast; cost Marrow 16→23.2 (L10); needs Prayer Banner): Sound the march. For a few seconds your skeletons and the Colossus step in time and strike faster; the living near you falter with dread in their marrow, and drag their feet. Numbers: L1: 6 s · minions +40% attack speed, +20% damage · shakes enemies in 5 yd / L10: 10 s · minions +40% attack speed, +20% damage · shakes enemies in 5 yd / L20: 10 s · minions +40% attack speed, +20% damage · shakes enemies in 5 yd. Perks (at skill level): L5 Long March: The march lasts 2 s longer. L10 +45 Essence Rally March: Skeletons mend 25% of their life when the march begins. `zz_mech_balance.js` `o_skills14.js` `zz_mech_trees.js` **[Act I]**

- **`colossus` Ossuary Colossus** (row 3, level 12, hold; cost Marrow 6.4→9.3 (L10) while held (per tick/unit); needs Raise Skeleton): Hold: skeletons march into one giant skeleton at the cursor, one by one. The more it holds, the bigger, faster and deadlier it is, and it keeps their shards of the aura. It leaps onto distant enemies and lands in a burst of bone. Tap to direct it: on an enemy it attacks it, on the ground it marches there, and your skeletons follow it. Its weapon is chosen in army orders (V). Numbers: L1: Fuses up to 4 skeletons · per skeleton: life 40, damage +15% / L10: Fuses up to 7 skeletons · per skeleton: life 126, damage +15% / L20: Fuses up to 10 skeletons · per skeleton: life 222, damage +15%. Perks (at skill level): L5 Unbroken Bulwark: The Colossus takes less damage and bellows a challenge that draws nearby enemies to it. L8 Cracked Marrow: Blows that land on the Colossus now and then knock a shard loose that flies to you. L12 Earthshaker: It leaps every 3 s and lands 30% harder. L16 +60 Vitality Titan of Bone: A quarter more life, and it moves faster. Synergies (per hard point): Raise Skeleton +2.5%, Reassemble +2.5%, Death March +2%. `f_bone.js` `g_bone_ui.js` `c_game.js` **[Act I]**

- **`unearth` Unearth** (row 3, level 12, cast; cost Marrow 16→23.2 (L10); needs Grave Tithe): The corpses near the cursor claw their way back up as grave-risen skeletons. They fight for 15 s and cost your aura nothing. Numbers: L1: Up to 3 corpses rise for 15 s / L10: Up to 4 corpses rise for 25 s / L20: Up to 6 corpses rise for 25 s. Perks (at skill level): L5 Restless Graves: They stand 10 s longer. L10 +55 Vitality Crumbling Dead: When they fall, their bones fly to your aura as shards. `o_skills14.js` `t_v17.js` `p_ui14.js` **[Act I]**

- **`bward` Shield of Bones** (row 4, level 18, passive; cost none; needs Death March): Skeletons standing within 3 yd of you throw themselves in front of the blows meant for you and take a share of them. Numbers: L1: Skeletons within 3 yd take 16% of each blow meant for you / L10: Skeletons within 3 yd take 21% of each blow meant for you / L20: Skeletons within 3 yd take 27% of each blow meant for you. Perks (at skill level): L5 Bristling: A skeleton that takes a blow for you cuts the attacker. L10 +55 Vitality Knitting Guard: Skeletons near you mend 2% of their life each second. `o_skills14.js` `p_ui14.js` **[later]**

- **`reasm` Reassemble** (row 5, level 24, passive; cost none; needs Ossuary Colossus): Fallen skeletons may pull themselves back together where they fell. The Colossus, when it collapses, reforms from its own rubble after a while, at half its size. Numbers: L1: 16% for a skeleton to rise again · Colossus reforms after 6 s / L10: 21% for a skeleton to rise again · Colossus reforms after 3 s / L20: 27% for a skeleton to rise again · Colossus reforms after 3 s. Perks (at skill level): L5 Quick Mending: The Colossus reforms in half the time. L10 +60 Vitality Whole Again: The Colossus reforms at its full size. `o_skills14.js` `zz_mech_trees.js` `p_ui14.js` **[later]**

- **`legion` Bone Legion** (row 6, level 30, passive; cost none; needs Reassemble): The march grows. Your skeletons and the Colossus stand harder and cut deeper, and the choir of the risen counts one more soul. Numbers: L1: Skeletons and Colossus +8% life, +10% damage / L10: Skeletons and Colossus +80% life, +100% damage / L20: Skeletons and Colossus +160% life, +200% damage. Perks (at skill level): L5 Forced March: Skeletons move 15% faster. L10 +65 Vitality Endless Legion: One more skeleton can stand. `f_bone.js` `g_bone_ui.js` **[later]**

#### Bone tree (tab 1)

- **`spear` Bone Lance** (row 1, level 1, cast; cost Marrow 8→11.6 (L10) + 1 bone shards): Hurl a lance of packed bone that pierces everything in its line. Like all bone spells, it bites deeper the more shards orbit you. Numbers: L1: 12 damage · pierces everything / L10: 43 damage · pierces everything / L20: 78 damage · pierces everything. Perks (at skill level): L5 Splinter: The first enemy it pierces sprays bone splinters to either side. L10 +50 Essence Impale: Enemies it pierces are pinned in place for a moment. Synergies (per hard point): Shard Storm +4%, Grave Spirit +3%, Marrow Siphon +2.5%. `o_skills14.js` `f_bone.js` `k_arcana.js` **[Act I]**

- **`siphon` Marrow Siphon** (row 2, level 6, cast; cost Marrow 9.6→13.9 (L10); needs Bone Lance): Draw the marrow out of the enemies in a cone before you. They are torn for damage, and each one hit sends a shard flying into your aura (four at most). Numbers: L1: 9 damage in a 3.5 yd cone · a shard from each (up to 4) / L10: 34 damage in a 3.5 yd cone · a shard from each (up to 4) / L20: 61 damage in a 3.5 yd cone · a shard from each (up to 4). Perks (at skill level): L5 Hollowed: Siphoned enemies are slowed for 2 s. L10 +50 Essence Marrow Draught: Every shard you siphon mends 1% of your life. Synergies (per hard point): Bone Lance +3%, Ossify +2.5%. `o_skills14.js` `zz_quests.js` `zz_mech_trees.js` **[Act I]**

- **`ribcage` Charnel Cage** (row 2, level 6, cast; cost Marrow 12.8→18.6 (L10) + 4 bone shards; needs Bone Lance): A great cage of ribs erupts under the target, hollow and stinking of the ossuary. The ribs pierce everything inside and hold it there, bleeding marrow, until the cage crumbles. Numbers: L1: 7 dmg/s to all inside · holds 2.5s / L10: 24 dmg/s to all inside · holds 3.2s / L20: 44 dmg/s to all inside · holds 3.9s. Perks (at skill level): L5 Marrow Drain: Held enemies feed your aura a shard every other second. L10 +55 Essence Iron Maiden of Bone: When the cage crumbles its ribs burst inward as spikes. Synergies (per hard point): Bone Spurs +3%, Ossify +3%. `f_bone.js` `zz_world_expand.js` `o_skills14.js` **[Act I]**

- **`ossify` Ossify** (row 2, level 6, cast; cost Marrow 14.4→20.9 (L10); needs Bone Lance): The enemies in an area at the cursor turn partly to bone for 8 s: they move 30% slower and take 20% more damage. An ossified enemy that dies bursts into shards. Numbers: L1: 1.8 yd · 8 s · 30% slower, +20% damage taken / L10: 3.0 yd · 8 s · 30% slower, +20% damage taken / L20: 3.3 yd · 8 s · 30% slower, +20% damage taken. Perks (at skill level): L5 Creeping Bone: The area is half again as wide. L10 +50 Essence Calcify: For the first 1.5 s they cannot move at all. `o_skills14.js` `zz_mech_trees.js` `p_ui14.js` **[Act I]**

- **`wall` Bone Arms** (row 3, level 12, cast; cost Marrow 12.8→18.6 (L10) + 3 bone shards; needs Charnel Cage): Skeletal arms claw up out of the ground in a line toward the target. They stay, tearing at and dragging on anything that walks over them. Numbers: L1: 6 arms · 7 dmg/s to what walks over them · slows · last 4.2s / L10: 8 arms · 24 dmg/s to what walks over them · slows · last 5.3s / L20: 10 arms · 44 dmg/s to what walks over them · slows · last 6.5s. Perks (at skill level): L5 Charnel Field: The arms erupt across a wide field around the target instead of in a line. L10 +55 Essence Crushing Grip: Arms that catch something crush it for double damage. Synergies (per hard point): Bone Spurs +2.5%, Bone Rain +2.5%. `f_bone.js` `s_env16.js` `k_arcana.js` **[Act I]**

- **`spikes` Bone Spurs** (row 3, level 12, cast; cost Marrow 14.4→20.9 (L10) + 4 bone shards; needs Ossify): Force the enemy's own bones outward as jagged spurs. They tear the marked thing open and gore everything within a step of it. Numbers: L1: 18 damage in 1.8 yd / L10: 60 damage in 2.0 yd / L20: 107 damage in 2.3 yd. Perks (at skill level): L5 Ossuary Bloom: Enemies killed by the spikes burst into spikes again. L10 +55 Essence Thicket: The spikes reach half again as far. Synergies (per hard point): Charnel Cage +4%, Ossify +3%. `o_skills14.js` `f_bone.js` `k_arcana.js` **[Act I]**

- **`sstorm` Shard Storm** (row 4, level 18, cast; cost Marrow 12.8→18.6 (L10); needs Marrow Siphon): Fire your aura: a fan of shards flies out in straight lines toward the target, each one piercing a few enemies. Your armor goes with them. Numbers: L1: Fires up to 6 shards in a fan · 9 each · pierce 2 / L10: Fires up to 9 shards in a fan · 32 each · pierce 2 / L20: Fires up to 12 shards in a fan · 57 each · pierce 2. Perks (at skill level): L5 Needle Storm: Each shard pierces two more enemies. L10 +55 Essence Homing Bone: A third of the shards fly back into your aura. Synergies (per hard point): Bone Lance +4%, Bone Rain +3%. `f_bone.js` `o_skills14.js` `k_arcana.js` **[later]**

- **`bonerain` Bone Rain** (row 4, level 18, cast; cost Marrow 22.4→32.5 (L10) + 3 bone shards; needs Bone Spurs): Shards tear up out of the ground, rise high and fall back as a rain of bone over the target area for 2 s. Numbers: L1: 8 per shard · 2.2 yd · 2 s / L10: 29 per shard · 2.2 yd · 3 s / L20: 52 per shard · 2.2 yd · 3 s. Perks (at skill level): L5 Downpour: The rain falls a second longer. L10 +55 Essence Pinning Rain: Every shard pins what it hits for a moment. Synergies (per hard point): Shard Storm +4%, Bone Spurs +3%. `o_skills14.js` `p_ui14.js` **[later]**

- **`spirit` Grave Spirit** (row 5, level 24, cast; cost Marrow 28.8→41.8 (L10) + 2 bone shards; needs Shard Storm): Loose a howling skull of bone and anima. It seeks the enemy nearest the cursor and bursts into a nova of shards. Numbers: L1: 52 to its prey · a nova of 8 shards / L10: 178 to its prey · a nova of 8 shards / L20: 319 to its prey · a nova of 8 shards. Perks (at skill level): L5 Twin Skulls: Two skulls fly at once. L10 +60 Essence Hungry Skull: After it bursts it seeks one more victim at half strength. Synergies (per hard point): Bone Lance +4%, Bone Rain +3%. `o_skills14.js` `p_ui14.js` **[later]**

- **`marrowm` Bone Mastery** (row 6, level 30, passive; cost none): Bone answers you sooner and hits truer. Every bone spell strikes harder, and a thin aura is slower to weaken them. Numbers: L1: +10% bone spell damage · thin aura floor 57% / L10: +100% bone spell damage · thin aura floor 75% / L20: +200% bone spell damage · thin aura floor 95%. Perks (at skill level): L5 Lean Marrow: Bone spells cost one shard less. L10 +65 Essence Deep Marrow: A thin aura weakens your bone spells far less. `f_bone.js` `g_bone_ui.js` **[later]**

#### Carapace tree (tab 2)

- **`barmor` Bone Armor** (row 1, level 1, cast; cost Marrow 17.6→25.5 (L10)): Plates of bone lock over your body seam by seam. They drink every blow meant for you until they crack apart and blow away as splinters. Numbers: L1: Soaks 30 damage / L10: Soaks 95 damage / L20: Soaks 167 damage. Perks (at skill level): L5 Barbed Plates: Enemies that strike the plates are cut. L10 +50 Constitution Shard Plates: Every shard your aura gathers rebuilds the plates a little. Synergies (per hard point): Shard Aura +3%, Carapace Mastery +2%. `o_skills14.js` `c_game.js` `p_ui14.js` **[Act I]**

- **`aura` Shard Aura** (row 1, level 1, hold; cost none): You are always pulling bone out of the earth, slowly: shards tear up from the ground around you and fly into your aura, cutting any enemy in their path. Hold it (bind it like any skill) to plant your feet and tear bone out four times as fast, shards and marrow both. Your army rises from its own reserve of marrow, which refills on its own and gives nothing back when a skeleton falls. The aura is your armor, your skeletons and the fuel for your spells. Levels pull from farther away and a little faster. Corpses give bone up faster. Numbers: L1: Holds 22 shards · pulls 0.27/s from 3.3 yd · each cuts for 3 · 0.60% damage turned per shard / L10: Holds 40 shards · pulls 0.40/s from 6.9 yd · each cuts for 10 · 0.60% damage turned per shard / L20: Holds 60 shards · pulls 0.54/s from 9.1 yd · each cuts for 17 · 0.60% damage turned per shard. Perks (at skill level): L5 Bone Spurs: Enemies that strike you in melee are cut by your shards. L10 Deep Pull: You pull bone from half again as far, and corpses give it up faster. L15 +60 Vitality Reforge: Every shard you gather mends you. `f_bone.js` `o_skills14.js` `g_bone_ui.js` **[Act I]**

- **`blade` Bone Blade** (row 1, level 1, cast; cost poise 5): For one stroke your weapon, whatever you hold, grows a long blade of bone. The stroke hits harder, reaches further and cleaves into the enemies beside the one you strike. Put it on either mouse button and hold to keep striking. [Poise: 5] Numbers: L1: x1.40 weapon damage · +0.45 yd reach · cleaves 1 for 52% / L10: x2.30 weapon damage · +0.45 yd reach · cleaves 3 for 70% / L20: x3.30 weapon damage · +0.45 yd reach · cleaves 3 for 90%. Perks (at skill level): L5 Great Cleave: The cleave reaches two more enemies. L10 +50 Constitution Long Bone: Your weapon reaches a third of a yard farther. `zz_ossu_active_melee.js` `f_bone.js` `zz_hero_ossumancer.js` **[Act I]**

- **`gcharge` Grinding Charge** (row 2, level 6, cast; cost poise 10; needs Bone Armor): Lower your shoulder and drive to the cursor. Bone plates grind everything in your path into the dirt and fling the rest aside like broken pilgrims. Numbers: L1: 8 damage · 5.1 yd / L10: 12 damage · 5.6 yd / L20: 16 damage · 6.2 yd. Perks (at skill level): L5 Bowl Over: Enemies you grind through are stunned for a full second. L10 +55 Constitution Grave Wake: Bone arms claw up along your path. Synergies (per hard point): Bone Host +3%, Grave Leap +3%. `zz_bone_melee_shard_costs.js` `f_bone.js` `zz_hero_ossumancer.js` `o_skills14.js` **[Act I]**

- **`crush` Marrow Crush** (row 2, level 6, cast; cost poise 8; needs Bone Blade): A heavy two-handed blow that cracks bone. The enemy takes 25% more damage from everything for 5 s, and two shards are knocked loose from it. [Poise: 8] Numbers: L1: 12 damage · +25% damage taken for 5 s · knocks 2 shards loose / L10: 17 damage · +25% damage taken for 5 s · knocks 2 shards loose / L20: 22 damage · +25% damage taken for 5 s · knocks 2 shards loose. Perks (at skill level): L5 Concuss: The blow stuns for a second. L10 +55 Constitution Shatterblow: The blow splashes everything within 1.5 yd of the target. Synergies (per hard point): Bone Blade +4%, Scythe Sweep +2.5%. `zz_bone_melee_shard_costs.js` `o_skills14.js` `zz_hero_ossumancer.js` `f_bone.js` **[Act I]**

- **`host` Bone Host** (row 3, level 12, hold; cost Marrow 8→11.6 (L10) while held (per tick/unit); needs Raise Skeleton (other tree)): Hold: your skeletons march onto you one by one and fuse into a carapace. For each one you grow larger, faster and harder-hitting, and bone grows out along your weapon so it reaches farther. Blows break the carapace down and every skeleton lost frees its shards for the aura to raise new ones. Hold again to channel them back on. Tap to shed the carapace. Numbers: L1: Carries up to 3 skeletons · each: +27% melee, +6 armor, 16 carapace / L10: Carries up to 5 skeletons · each: +45% melee, +6 armor, 16 carapace / L20: Carries up to 7 skeletons · each: +65% melee, +6 armor, 16 carapace. Perks (at skill level): L5 Everstanding: While hosting you take less damage and cannot be knocked back. L10 Shard Skin: While hosting, your aura holds half again as many shards. L15 +60 Constitution Titanfall: While hosting, every third blow slams the ground around you. `f_bone.js` `o_skills14.js` `g_bone_ui.js` **[Act I]**

- **`bscythe` Scythe Sweep** (row 3, level 12, cast; cost poise 7; needs Marrow Crush): Grow a scythe of vertebrae out of your arm and cut a full ring around you. Everything in reach is opened, then thrown clear on the follow-through. Numbers: L1: 9 damage all around you / L10: 14 damage all around you / L20: 20 damage all around you. Perks (at skill level): L5 Wide Arc: The sweep reaches half again as far. L10 +50 Constitution Reaping: Every third enemy the sweep hits gives up a shard. Synergies (per hard point): Bone Blade +4%, Marrow Crush +3%. `zz_bone_melee_shard_costs.js` `f_bone.js` `o_skills14.js` `zz_hero_hemomancer_r8.js` **[Act I]**

- **`leap` Grave Leap** (row 4, level 18, cast; cost poise 12; needs Grinding Charge): Kick free of the earth and come down on the cursor in a burst of driven spikes. The impact throws the living clear and staples the dying where they fall. Numbers: L1: 19 in 1.6 yd · up to 6 yd / L10: 61 in 1.6 yd · up to 6 yd / L20: 108 in 1.6 yd · up to 6 yd. Perks (at skill level): L5 Crater: The landing stuns for a second. L10 +55 Constitution Spike Field: Bone arms claw up where you land. Synergies (per hard point): Grinding Charge +4%, Bone Host +2.5%. `zz_bone_melee_shard_costs.js` `o_skills14.js` `zw_monk_ui.js` `zz_hero_ossumancer.js` **[later]**

- **`lash` Spine Lash** (row 4, level 18, cast; cost poise 6; needs Scythe Sweep): Crack a whip of vertebrae in a long straight line. It cuts everything along it and yanks the farthest enemy it catches to your feet. [Poise: 6] Numbers: L1: 7 along 3.5 yd · pulls the farthest / L10: 11 along 3.5 yd · pulls the farthest / L20: 14 along 3.5 yd · pulls the farthest. Perks (at skill level): L5 Double Lash: It cracks twice. L10 +55 Constitution Flayed Arc: The lash sweeps an arc instead of a line. Synergies (per hard point): Scythe Sweep +3%, Marrow Crush +3%. `zz_bone_melee_shard_costs.js` `zz_hero_hemomancer.js` `o_skills14.js` `zc_combat22.js` **[later]**

- **`carapm` Carapace Mastery** (row 6, level 30, passive; cost none): Your shell hardens as the pilgrimage grinds you thin. Your blows fall heavier, and every shard in your aura turns aside a little more of what strikes it. Numbers: L1: +6% melee · +0.08% per shard turned · shards cut +5% / L10: +60% melee · +0.80% per shard turned · shards cut +50% / L20: +120% melee · +1.60% per shard turned · shards cut +100%. Perks (at skill level): L5 Quick Bone: Your aura regrows 15% faster. L10 +65 Constitution Marrow Feast: Every kill mends 2% of your life. `f_bone.js` `o_skills14.js` `g_bone_ui.js` **[later]**

### 8.3 The Hemomancer (`hemomancer`): Vitae and the brood

- **Resource: Vitae** (the living blood): max 20 + 2×Essence + 2×level; regen 0.5 + 0.012×Essence per second, far more in blood. **Every skill costs life too, and Vitae pays the share:** the life price = max life × min(15%, (cost ÷ max(20, max Vitae)) × 0.35 × (0.4 + 1.3 × (1 − Vitae fullness))). That is −25% with Cheap Blood, and none above 80% Vitae with the Bleeding Heart upright. **Paying never kills:** at the edge you pay down to 1 life and the skill comes out weaker (never below 30%). `h_blood.js` **[Act I]**

- **Blood falls:** blood spells are flung, sprayed or poured; they arc, splash and pool, never fly straight. Bleeding enemies leave pools; pools merge and grow gently (toned down). Standing in blood heals him and refills Vitae (×3 with Blood Gills). No glow on blood. `h_blood.js` `zz_blood_pool_tone.js` **[Act I]**

- **The brood:** spawnlings from corpses, tumours and his own body (Penitent Womb). Brood cap = 4 + ⌊Penitent Womb level/2⌋ (+2 Brood Mother, +1 Teeming). Oozes (Blood Thrall) and the Flesh Golem (permanent; regrows after max(14, 30 − 0.6×level) s, at least 10 s) are made from corpses. `h_blood.js` `zy_flesh.js` **[Act I]**

- **Mutations:** worn in 2 slots (3 with Flesh Mastery): Belly Maw, Scar-Plates (code `chitin`), Tentacles, Blood Gills, Tumor Hump, Second Heart. Default worn: Maw and Scar-Plates. The golem can wear one (two with Flesh Lord). `h_blood.js` `i_blood_ui.js` **[Act I]**

- **Grafts** on the whole brood (1 slot, 2 with Second Graft): Fevered Blood (bites bleed), Leapers, Clingers (ride and bite), Volatile (burst on death), Spider Legs (+45% speed). `h_blood.js` **[Act I]**

- **The Flesh panel (V or G):** mutations, grafts, brood orders and the golem's orders and mutations. `i_blood_ui.js` **[Act I]**

- **Corpses:** right-click a fresh corpse to split it into spawnlings; the golem eats corpses to heal and to fill its brood stock (6, or 10 with Bottomless Gut). `t_v17.js` `zy_flesh.js` **[Act I]**

- **Look law:** dark brown skin, penitent not tribal, no head cage, a neutral warm lamp (the full redo is pending). `wiki/class-hemomancer.md` **[Act I]**

- **The Hemomancer's skills, by tree:**

#### Brood tree (tab 0)

- **`eggsac` Blessed Growth** (row 1, level 1, cast; cost Vitae 16.8→24.4 (L10) (Vitae only, no life)): Sow a curse over a patch of ground (3 yd) for 6 s. Every enemy that stands in it is cursed — their flesh loosens, they take a slow bleed, and a growth may split from them. When a cursed enemy dies, a spawnling crawls out of the wound. With no one to curse, the patch does nothing but wait. Vitae only, no life price. Numbers: L1: 1 tumor · 7 burst · each leaves a 1-life spawnling for 12s / L10: 2 tumors · 36 burst · each leaves a 1-life spawnling for 12s / L20: 3 tumors · 65 burst · each leaves a 1-life spawnling for 12s. Perks (at skill level): L5 Deep Roots: The growth lasts 3 s longer. L10 +45 Vitality Viable Growth: Growth spawnlings live twice as long and hit harder. Synergies (per hard point): Penitent Womb +3%, Brood Nest +2.5%. `zz_mech_balance.js` `h_blood.js` `o_skills14.js` **[Act I]**

- **`hatch` Penitent Womb** (row 1, level 1, hold; cost Vitae 9.6→13.9 (L10) + life share (see Vitae) while held (per tick/unit)): With no flesh near the cursor, hold it to bleed a brood out of yourself: a swarmling every moment, paid in Vitae and the rest in life (the fuller your Vitae, the less life; never the last of it). Otherwise: split open the corpses and tumors around the cursor: each corpse spills out spawnlings, torn torsos that crawl on their hands, and each tumor a whole clutch. V opens the Flesh panel: grafts, orders and the golem. Numbers: L1: Brood of 4 · life 10 · bites 2-3 · 1 per corpse, 2 per tumor · 2.5 yd · bled: 7 Vitae + 1 life each (less life the fuller your Vitae) / L10: Brood of 7 · life 32 · bites 5-9 · 1 per corpse, 2 per tumor · 2.8 yd · bled: 9 Vitae + 2 life each (less life the fuller your Vitae) / L20: Brood of 10 · life 56 · bites 9-16 · 2 per corpse, 2 per tumor · 3.1 yd · bled: 12 Vitae + 3 life each (less life the fuller your Vitae). Perks (at skill level): L5 Frenzy: Spawnlings bite much faster when the enemy is bleeding. L8 Quickening: Tumors hatch on their own a few seconds after they are laid. L12 Swollen Brood: Every corpse hatches one more spawnling. L16 +50 Vitality Infestation: Corpses that died bleeding hatch twice over. Synergies (per hard point): Assimilate +2.5%, Hivemind +2%. `zy_flesh.js` `h_blood.js` `o_skills14.js` `zz_mech_trees.js` **[Act I]**

- **`thrall` Blood Thrall** (row 2, level 6, cast; cost Vitae 19.2→27.8 (L10) + life share (see Vitae); needs Blessed Growth): Pour the corpse or blood pool nearest the cursor into an ooze: a quivering mass of blood with eyes drifting inside it. It keeps its distance and spits shards of clotted blood. It slurps up corpses and blood, and every meal makes it pulse: you and your minions near it strike faster for a while. Numbers: L1: 1 ooze · life 60 · shards 7 · pulse +21% attack speed for 6 s / L10: 2 oozes · life 168 · shards 24 · pulse +26% attack speed for 6 s / L20: 3 oozes · life 288 · shards 44 · pulse +32% attack speed for 6 s. Perks (at skill level): L5 Budding: You can keep one more ooze. L10 Clotted Shards: Its shards leave enemies bleeding. L15 +55 Vitality Rich Blood: Its pulse also mends you and your minions by 5% of their life. Synergies (per hard point): Penitent Womb +2.5%, Boiling Blood +2.5%. `o_skills14.js` `zz_hero_hemomancer.js` `h_blood.js` **[Act I]**

- **`rush` Rabid Charge** (row 2, level 6, cast; cost Vitae 12→17.4 (L10) + life share (see Vitae); needs Penitent Womb): Drive the spawnling nearest the target berserk. It swells up and charges the enemy at the cursor, bursting on impact in a blast of gore. The only way to spend your brood as a bomb. Numbers: L1: Burst 23 (more when grown) in 1.8 yd · 1 at a time / L10: Burst 80 (more when grown) in 1.8 yd · 2 at a time / L20: Burst 142 (more when grown) in 1.8 yd · 2 at a time. Perks (at skill level): L5 Pack Charge: Two spawnlings charge at once. L10 +55 Vitality Rebirth: Every enemy the burst kills rises as a spawnling. Synergies (per hard point): Penitent Womb +4%, Red Fervour +3%. `h_blood.js` `c_game.js` `zz_hero_hemomancer.js` **[Act I]**

- **`fgolem` Flesh Golem** (row 3, level 12, cast; cost Vitae 52.8→76.6 (L10) + life share (see Vitae); needs Blood Thrall): Sew a hulking brood-beast out of corpses and chitin, a vast gut-maw stitched shut down its belly. Its gut holds brood stock: when enemies come near it tears the stitches open and pukes up a gout of blood and bile full of swarmlings that fall on them. It seeks out corpses and eats them to refill its stock and heal, and its gut swells as it fills. It crushes enemies with its chitin fist, hurls its bulk at those a few yards off, and swallows enemies whole to digest them. It can wear one of your mutations (Flesh panel, V). It never dies for good: at zero life it slumps into a heap and regrows (at least 10 s). Cast it on the golem or its heap to feed it your life: that heals it, or quickens the regrowth. Cast elsewhere to send it to the cursor. Numbers: L1: Life 293 · crushes 12 · gut holds 6 stock · pukes 3 swarmlings (life 8, 12s) and 8 bile for 3 · +3 stock per corpse · 1 mutation slot / L10: Life 819 · crushes 44 · gut holds 10 stock · pukes 5 swarmlings (life 24, 12s) and 31 bile for 3 · +4 stock per corpse · 1 mutation slot / L20: Life 1404 · crushes 80 · gut holds 10 stock · pukes 6 swarmlings (life 42, 12s) and 56 bile for 3 · +4 stock per corpse · 1 mutation slot. Perks (at skill level): L5 Bottomless Gut: Its gut holds far more brood stock, every meal fills it further, and each puke spills two more swarmlings. L10 Gorge: Meals heal it far more, and it grows larger and stronger with every one. L15 +60 Vitality Split: When it dies it tears apart into a swarm of spawnlings. Synergies (per hard point): Penitent Womb +2.5%, Devour +2.5%, Hivemind +2.5%. `zy_flesh.js` `h_blood.js` `zz_hero_hemomancer.js` **[Act I]**

- **`graft` Graft** (row 3, level 12, passive; cost none; needs Penitent Womb): Graft a trait onto the whole brood: Fevered Blood, Leapers, Clingers, Volatile or Spider Legs. Chosen in the Flesh panel (V). Levels strengthen every graft. Numbers: L1: 1 graft slot · grafts x1.06 strength / L10: 1 graft slot · grafts x1.60 strength / L20: 1 graft slot · grafts x2.20 strength. Perks (at skill level): L5 Knitting Flesh: Spawnlings mend twice as fast in blood. L10 +50 Vitality Second Graft: A second graft slot. `h_blood.js` `zz_mech_trees.js` `k_arcana.js` **[Act I]**

- **`assim` Assimilate** (row 3, level 12, passive; cost none; needs Rabid Charge): Spawnlings that kill grow fat on it: bigger, tougher and harder-biting, up to twice over. Grown spawnlings give more when devoured. Numbers: L1: Kills grow a spawnling: up to x2 life and bite / L10: Kills grow a spawnling: up to x2 life and bite / L20: Kills grow a spawnling: up to x2 life and bite. Perks (at skill level): L5 Quick Growth: They grow twice as much from each kill. L10 +55 Vitality Monstrous: They can grow to two and a half times their size. `h_blood.js` `o_skills14.js` `i_blood_ui.js` **[Act I]**

- **`nest` Brood Nest** (row 4, level 18, cast; cost Vitae 38.4→55.7 (L10) + life share (see Vitae); needs Flesh Golem): Seed a pulsing nest of flesh on the ground. For 15 s it spits out a tumor spawnling every few seconds and mends the minions around it. Numbers: L1: 15 s · a spawnling every 2.9 s · mends minions 3%/s / L10: 15 s · a spawnling every 2.5 s · mends minions 3%/s / L20: 15 s · a spawnling every 2.0 s · mends minions 3%/s. Perks (at skill level): L5 Swelling Nest: It hatches real spawnlings while your brood has room. L10 +55 Vitality Deep Roots: It lasts twice as long. `o_skills14.js` `zz_quests.js` `zz_hero_hemomancer.js` **[later]**

- **`hive` Hivemind** (row 5, level 24, passive; cost none; needs Graft): Your minions think as one: each one hits harder and takes less damage for every other minion within 4 yd of it. Numbers: L1: +4.5% damage and -1.5% damage taken per minion nearby (8 at most) / L10: +7.2% damage and -1.5% damage taken per minion nearby (8 at most) / L20: +10.2% damage and -1.5% damage taken per minion nearby (8 at most). Perks (at skill level): L5 Shared Blood: Minions near each other mend 1% of their life each second. L10 +60 Vitality One Mind: Every minion turns on whatever you last struck. `o_skills14.js` `zz_quests.js` `zz_mech_trees.js` **[later]**

- **`broodm` Brood Mother** (row 6, level 30, passive; cost none; needs Hivemind): You are the belly they came from. Spawnlings, oozes and the Flesh Golem stand harder and bite harder, and the brood you carry grows fatter with you. Numbers: L1: Brood +8% life, +10% damage · +2 brood / L10: Brood +80% life, +100% damage · +2 brood / L20: Brood +160% life, +200% damage · +2 brood. Perks (at skill level): L5 Teeming: One more spawnling in your brood. L10 +65 Vitality Tough Hide: Your brood takes 20% less damage. `h_blood.js` `o_skills14.js` `i_blood_ui.js` **[later]**

#### Blood tree (tab 1)

- **`bboil` Boiling Blood** (row 1, level 1, cast; cost Vitae 19.2→27.8 (L10) + life share (see Vitae)): Bring the blood of everything around the cursor to a boil for 8 s. Boiling enemies bleed half again as hard and as long, and each one that dies boils over, scalding those next to it. Numbers: L1: 2.4 yd · 8 s · bleeding x1.53 / L10: 3.6 yd · 8 s · bleeding x1.69 / L20: 3.6 yd · 8 s · bleeding x1.87. Perks (at skill level): L5 Rolling Boil: The area is half again as wide. L10 +50 Essence Scalded: Boiling enemies move 25% slower. Synergies (per hard point): Hemorrhage +3%. `o_skills14.js` `zz_hero_hemomancer.js` `p_ui14.js` **[Act I]**

- **`blance` Sin Purge** (row 1, level 1, cast; cost Vitae 2.2→3.2 (L10) + life share (see Vitae)): Hold: spew a sloshing stream of blood in a narrow cone. It soaks through everything in its way, splashes where it lands and leaves them all bleeding. Every Hemomancer skill costs life as well as Vitae; the fuller your Vitae, the less life. Numbers: L1: 2 per gout, ~18 gouts/s · bleeds 1/s · soaks through / L10: 9 per gout, ~18 gouts/s · bleeds 3/s · soaks through / L20: 16 per gout, ~18 gouts/s · bleeds 5/s · soaks through. Perks (at skill level): L5 Coagulate: The stream slows what it soaks. L10 +50 Essence Lacerate: Its bleeding runs twice as deep. Synergies (per hard point): Hemorrhage +3%, Boiling Blood +3%. `h_blood.js` `o_skills14.js` `c_game.js` **[Act I]**

- **`hemor` Hemorrhage** (row 2, level 6, cast; cost Vitae 24→34.8 (L10) + life share (see Vitae); needs Boiling Blood): Burst the veins of the enemy nearest the cursor: it loses a share of its current life at once (far less for bosses), and the spray makes everything close by bleed. Numbers: L1: Tears 17% of current life (bosses 4%), at least 10 · splash 1.2 yd / L10: Tears 20% of current life (bosses 5%), at least 38 · splash 1.2 yd / L20: Tears 23% of current life (bosses 6%), at least 70 · splash 1.2 yd. Perks (at skill level): L5 Exsanguinate: Bleeding enemies that die spray their blood over everything around them. L10 Open Veins: The target also bleeds for a third of what it lost. L15 +60 Essence Arterial Spray: The splash is wider and cuts everything in it. Synergies (per hard point): Sin Purge +3%, Boiling Blood +3%. `h_blood.js` `o_skills14.js` `c_game.js` **[Act I]**

- **`vwhip` Grasping Veins** (row 2, level 6, cast; cost Vitae 14.4→20.9 (L10) + life share (see Vitae); needs Sin Purge): A burst of red veins erupts from your bandaged forearm like roots and snakes out to several enemies at once. Each vein bites its target and leaves it bleeding; some hold on and squeeze the blood out for a moment. Veins that reach nothing thrash in the air and bleed small pools onto the ground. Levels: more veins, longer reach, harder bites. Numbers: L1: 3 veins · 3.7 yd · each bites 12 and bleeds 4/s · 31% to hold and squeeze for 1.3s (4/s) / L10: 4 veins · 4.9 yd · each bites 43 and bleeds 13/s · 100% to hold and squeeze for 2.3s (13/s) / L20: 6 veins · 6.2 yd · each bites 78 and bleeds 24/s · 100% to hold and squeeze for 2.7s (24/s). Perks (at skill level): L5 Strangling Roots: Every vein that bites holds and squeezes, half again as long. L10 +50 Essence Hooked Roots: One more vein, and each vein drags what it bites a yard toward you. Synergies (per hard point): Sin Purge +3%, Tentacles +2.5%. `zy_flesh.js` `h_blood.js` `o_skills14.js` `zz_mech_trees.js` **[Act I]**

- **`cburst` Burst Vessel** (row 3, level 12, cast; cost Vitae 21.6→31.3 (L10) + life share (see Vitae); needs Hemorrhage): Detonate the corpse or tumor nearest the cursor in a burst of meat and blood that makes what it hits bleed. Numbers: L1: 20 damage in 2 yd · bleeds / L10: 69 damage in 2 yd · bleeds / L20: 123 damage in 2 yd · bleeds. Perks (at skill level): L5 Chain Burst: The burst sets off other corpses it reaches. L10 +55 Essence Seeding Burst: Every burst flings a tumor. Synergies (per hard point): Hemorrhage +3%, Tide of the Maiden +3%. `h_blood.js` `o_skills14.js` `c_game.js` **[Act I]**

- **`bfrenzy` Red Fervour** (row 3, level 12, cast; cost Vitae 28.8→41.8 (L10) + life share (see Vitae); needs Penitent Womb (other tree)): Scream the blood hot. Every minion around you goes rabid: faster, quicker to bite and hungry for anything nearby. You run and strike faster and your wounds knit. Numbers: L1: 6.3s · minions in 6 yd: +40% speed, +50% attack speed · you: +25% speed and attack speed, 1.5% life/s / L10: 7.6s · minions in 6 yd: +40% speed, +50% attack speed · you: +25% speed and attack speed, 1.5% life/s / L20: 9.1s · minions in 6 yd: +40% speed, +50% attack speed · you: +25% speed and attack speed, 1.5% life/s. Perks (at skill level): L5 Bloodlust: Frenzied minions mend as they fight. L10 +55 Vitality Red Rage: Frenzied minions hit 25% harder. `h_blood.js` `zz_hero_hemomancer.js` `o_skills14.js` **[Act I]**

- **`bwave` Tide of the Maiden** (row 4, level 18, cast; cost Vitae 33.6→48.7 (L10) + life share (see Vitae); needs Burst Vessel): A wave of blood rolls out from you, sweeping enemies back before it and leaving them bleeding. It grows taller for every bleeding enemy it swallows. Numbers: L1: 18 damage · 2.6 yd wide · sweeps enemies back / L10: 67 damage · 3.9 yd wide · sweeps enemies back / L20: 122 damage · 3.9 yd wide · sweeps enemies back. Perks (at skill level): L5 Riptide: The wave is half again as wide. L10 +55 Essence Drown: What the wave carries is stunned when it lets go. Synergies (per hard point): Sin Purge +4%, Burst Vessel +3%. `o_skills14.js` `zz_hero_hemomancer.js` `p_ui14.js` **[later]**

- **`spool` The Leeches** (row 4, level 18, passive; cost none; needs Grasping Veins): Fat leeches live in your sleeves. Whenever you wound an enemy one may drop out and crawl to the wound, latch on and drink its fill, then crawl back up your arm and feed you what it drank as life and Vitae. Levels: more leeches out at once, more drink, faster crawling. Numbers: L1: 33% per wound (half per bleed tick) · up to 2 out at once · drink 4/s, crawl home full at 12 · 4.7 yd/s · life 12 · you get 80% as life and 40% as Vitae / L10: 46% per wound (half per bleed tick) · up to 3 out at once · drink 22/s, crawl home full at 79 · 5.8 yd/s · life 23 · you get 80% as life and 40% as Vitae / L20: 61% per wound (half per bleed tick) · up to 5 out at once · drink 39/s, crawl home full at 166 · 7.0 yd/s · life 35 · you get 80% as life and 40% as Vitae. Perks (at skill level): L5 Fat Leeches: Leeches drink half again as fast. L10 +55 Vitality Leech Mother: Two more leeches out at once. Synergies (per hard point): Covenant of Blood +3%, Hemorrhage +2.5%. `zy_flesh.js` `h_blood.js` `zz_hero_hemomancer.js` **[later]**

- **`pact` Covenant of Blood** (row 5, level 24, cast; cost 12% of current life; needs Red Fervour): Open your veins for your children: lose 12% of your current life, and every minion is mended 40% and strikes 30% harder for 8 s. Numbers: L1: Costs 12% of your life · minions mend 40%, +30% damage for 8 s / L10: Costs 12% of your life · minions mend 40%, +30% damage for 12 s / L20: Costs 12% of your life · minions mend 40%, +30% damage for 12 s. Perks (at skill level): L5 Binding Oath: The pact lasts 4 s longer. L10 +55 Vitality Shared Veins: While the pact lasts, a fifth of the damage you take is spread among your minions. `zz_hero_hemomancer.js` `o_skills14.js` `p_ui14.js` **[later]**

- **`hemom` Hemomancy Mastery** (row 6, level 30, passive; cost none): Your covenant with the Bleeding Maiden deepens. Every blood-work and every open wound cuts a little further into what it opens. Numbers: L1: +10% blood magic and bleed damage / L10: +100% blood magic and bleed damage / L20: +200% blood magic and bleed damage. Perks (at skill level): L5 Blood Scent: Vitae refills 25% faster near bleeding enemies and blood. L10 +65 Essence Cheap Blood: Your skills cost 25% less life. `h_blood.js` `i_blood_ui.js` **[later]**

#### Flesh tree (tab 2)

- **`maw` Belly Maw** (row 1, level 1, passive · mutation; cost none): your belly splits into a toothed maw. Your blows bite harder, open bleeding wounds and drink life, and now and then the maw swallows the enemy whole. While something is inside you, you mend; if it has not died when you are done with it, you spit it out. Numbers: L1: x1.24 melee · drinks 4% · 9% to engulf · digests 8/s / L10: x1.46 melee · drinks 13% · 11% to engulf · digests 29/s / L20: x1.70 melee · drinks 18% · 14% to engulf · digests 52/s. Perks (at skill level): L5 Carnal Hunger: Your bites drink twice as much life. L10 +50 Vitality Bottomless: You swallow twice as often and digest faster. Synergies (per hard point): Swallow Whole +4%, Devour +2.5%. `h_blood.js` `o_skills14.js` `c_game.js` **[Act I]**

- **`chitin` Scar-Plates** (row 1, level 1, passive · mutation; cost none): every welt the scourge ever raised on you hardens into a ridge of scar, split and seamed like old plate. Blows glance off them, and what does bite you loses much of its weight before it ever reaches meat. Numbers: L1: +16 armor · 6% less damage / L10: +48 armor · 11% less damage / L20: +84 armor · 17% less damage. Perks (at skill level): L5 Barbed Scars: Enemies that strike you in melee are cut on the barbed ridges of scar. L10 +55 Constitution Thick Scar: Half again as much armor. `zz_text53.js` `h_blood.js` `i_blood_ui.js` `zz_hero_hemomancer.js` **[Act I]**

- **`swallow` Swallow Whole** (row 2, level 6, cast; cost Vitae 24→34.8 (L10) + life share (see Vitae); needs Belly Maw): Needs the Belly Maw worn. Your belly splits wide and swallows the enemy nearest the cursor within reach (not bosses) and begins to digest it. Numbers: L1: Swallows within 1.4 yd · digests 8/s / L10: Swallows within 1.4 yd · digests 8/s / L20: Swallows within 1.4 yd · digests 8/s. Perks (at skill level): L5 Warm Meal: While something digests inside you, you mend twice as fast. L10 +55 Vitality Spit Bone: Cast it again while full to spit what you hold at the cursor, hard. `o_skills14.js` `h_blood.js` `zz_hero_hemomancer.js` **[Act I]**

- **`tentacles` Tentacles** (row 2, level 6, passive · mutation; cost none; needs Belly Maw): tentacles sprout from your back. Each one lashes out once at an enemy in reach, tears off and constricts it where it stands, then slowly grows back on your body. More points grow more tentacles, up to eight, and regrow them faster. Numbers: L1: 2 tentacles · 4.1 yd · 7 damage · constrict 1.1s · regrow 5.8s each / L10: 3 tentacles · 4.5 yd · 24 damage · constrict 2.5s · regrow 5.0s each / L20: 5 tentacles · 5.0 yd · 44 damage · constrict 2.7s · regrow 4.1s each. Perks (at skill level): L5 Coiling Grip: Torn-off tentacles constrict twice as long. L10 +55 Vitality Barbed Suckers: Tentacles strike half again as hard and leave enemies bleeding. Synergies (per hard point): Grasping Veins +3%, Belly Maw +2.5%. `h_blood.js` `zz_hero_hemomancer.js` `i_blood_ui.js` **[Act I]**

- **`devour` Devour** (row 3, level 12, cast; cost none; needs Penitent Womb (other tree)): Eat the spawnling or tumor nearest you: it restores life and Vitae and gives a stacking bonus to all damage. The bigger the meal, the bigger the gain. Numbers: L1: +15% life and +12% Vitae (more for fat meals) · +8% damage per stack (5 max, 15s) / L10: +15% life and +12% Vitae (more for fat meals) · +8% damage per stack (8 max, 22s) / L20: +15% life and +12% Vitae (more for fat meals) · +8% damage per stack (8 max, 22s). Perks (at skill level): L5 Gluttony: Devour stacks higher and lasts longer. L10 +55 Vitality Shared Feast: Every meal also mends your minions nearby by 30%. `zz_hero_hemomancer.js` `o_skills14.js` `h_blood.js` **[Act I]**

- **`gills` Blood Gills** (row 3, level 12, passive · mutation; cost none; needs Scar-Plates): gills split open along your neck. Standing in blood heals you three times as fast and refills Vitae far more. Numbers: L1: Blood heals 3% life/s and refills 2.5 Vitae/s while you stand in it / L10: Blood heals 3% life/s and refills 2.5 Vitae/s while you stand in it / L20: Blood heals 3% life/s and refills 2.5 Vitae/s while you stand in it. Perks (at skill level): L5 Blood Breath: Pools you stand in spread wider and last longer. L10 +50 Vitality Deep Breath: Blood refills your Vitae twice as fast. `h_blood.js` `i_blood_ui.js` `zz_mech_trees.js` **[Act I]**

- **`bilehump` Tumor Hump** (row 4, level 18, passive · mutation; cost none; needs Tentacles): a glowing hump of tumors swells on your back. It buds tumor spawn that float off after enemies and burst in a spray of gore. Numbers: L1: A tumor spawn every 3.4s · bursts for 10 / L10: A tumor spawn every 3.0s · bursts for 38 / L20: A tumor spawn every 2.5s · bursts for 70. Perks (at skill level): L5 Bloated: The spawn burst wider. L10 +55 Vitality Twin Buds: The hump buds two at a time. Synergies (per hard point): Blessed Growth +3%. `h_blood.js` `i_blood_ui.js` `zz_hero_hemomancer.js` **[later]**

- **`molt` Molt** (row 4, level 18, cast; cost Vitae 28.8→41.8 (L10) + life share (see Vitae); needs Blood Gills): Shed your skin in one wet heave: mend a share of your life and shake off anything slowing you. The empty skin stands where you were and draws the enemy for 3 s. Numbers: L1: Mend 21% of your life · skin draws enemies for 3 s / L10: Mend 26% of your life · skin draws enemies for 3 s / L20: Mend 32% of your life · skin draws enemies for 3 s. Perks (at skill level): L5 Raw Flesh: For 4 s after, your blows open deep bleeding wounds. L10 +55 Vitality Crawling Skin: When the skin falls, two leeches crawl out of it. `o_skills14.js` `zz_mech_trees.js` `zz_hero_hemomancer.js` **[later]**

- **`heart` Second Heart** (row 5, level 24, passive · mutation; cost none; needs Molt): a second heart beats beside the first. You mend steadily, and when you fall near death it pounds you back up once in a while. Numbers: L1: Mend 0.55% life/s · below 25%: heal 40% (every 59s) / L10: Mend 0.82% life/s · below 25%: heal 40% (every 25s) / L20: Mend 1.12% life/s · below 25%: heal 40% (every 21s). Perks (at skill level): L5 Strong Beat: It is ready again in half the time. L10 +60 Vitality Shared Pulse: When it pounds, your brood and golem heal fully too. `h_blood.js` `zz_arcana_zbody.js` `l_arcana_ui.js` **[later]**

- **`fmastery` Flesh Mastery** (row 6, level 30, passive; cost none): The Bleeding Maiden reshapes you further. A third mutation slot opens beneath your skin, and every mutation you wear grows into you more truly. Numbers: L1: 3 mutation slots · mutations x1.06 / L10: 3 mutation slots · mutations x1.60 / L20: 3 mutation slots · mutations x2.20. Perks (at skill level): L5 Quick Flesh: Mutations work half again as fast in blood. L10 +70 Vitality Flesh Lord: Your Flesh Golem can wear a second mutation. `h_blood.js` `i_blood_ui.js` **[later]**

### 8.4 The Shrine Keeper (`miasmancer`): Miasma, the cloud and the Omens

- **Resource: Miasma:** max 30 + 1.2×Essence + 1.5×level; regen (1.5 + 0.03×Essence) × 0.5. It fills faster standing in miasma (×1.5, and overlapping clouds do not stack). **Inhale** is a passive trickle that sips nearby clouds and the sickened. **Exhale** empties the lungs in one blast. `m_mias.js` `zz_miasma_breath.js` `zz_tune_batch_d.js` **[Act I]**

- **Her cloud:** a violet haze that thickens as Miasma is levelled and as the pool fills. It sickens what stands in it, and blows miss her: evasion = min(60%, (6% + 1.2% per Miasma level) × fullness + 10% Shroud + 1% per Unseen point + 30% just after Blur). No green: every particle is purple gas. `m_mias.js` `zz_miasma_breath.js` `zz_miasma_gas.js` **[Act I]**

- **Omens (Sigils in the text):** strikes build them and finishers spend them; max 3 (4 with Fourth Sigil; 2 with Death reversed); each lasts 14 s (24 with Omen-Sight). Each held Omen gives +6% damage and +5% speed. They circle her as pale skulls. `m_mias.js` `zz_mech_balance.js` **[Act I]**

- **Weapons:** claws are her base (+25% weapon damage with claws); the war-fan is a skill for now. Thrown knives replace swings when a card or skill says so. `m_mias.js` **[Act I]**

- **Traps:** max 2 + 1 at Unseen 1, 5 and 10 (+2 Trapper-Queen, +1 Trap Field); they arm after 0.8 s (0 with Hair Trigger). `m_mias.js` **[Act I]**

- **The Mirror-Sister:** a reversed reflection fights beside her using her own skills at 35% + 1.5% per level of her strength (not commanded). `m_mias.js` **[later]**

- **Poise:** she has little; she survives by not being hit. Death-tree strikes cost poise. `wiki/class-shrine-keeper.md` **[Act I]**

- **The Shrine Keeper's skills, by tree:**

#### Miasma tree (tab 0)

- **`vblade` Venom Claws** (row 1, level 1, cast; cost Miasma 9.6→13.9 (L10)): Draw miasma along the length of your claws and let it settle in the metal. For a long while your blows leave the sickness in the wound, and the wounded drag their feet. Numbers: L1: 40 s · claws sicken 6/s for 4 s and slow / L10: 40 s · claws sicken 14/s for 4 s and slow / L20: 40 s · claws sicken 23/s for 4 s and slow. Perks (at skill level): L5 Venom Flick: Every third blow also flicks a miasma-soaked knife at the next enemy. L10 Deep Venom: Miasma from your claws stacks up to three times. L15 +50 Constitution Raking Claws: Your blows also rake a second enemy beside the first. Synergies (per hard point): Contagion +3%. `m_mias.js` `o_skills14.js` `n_mias_ui.js` **[Act I]**

- **`mcloud` Miasma** (row 1, level 1, passive; cost none): Miasma hangs about you as a cloud. It sickens whatever stands in it and blurs your outline, so blows miss you. The sickened leak miasma behind them, and standing in miasma thickens yours fast. The thicker the cloud, the wider it spreads, the harder it bites and the harder you are to hit. Numbers: L1: Cloud 0.8 yd · sickens 3/s · 7% of blows miss (full cloud: more) / L10: Cloud 2.5 yd · sickens 11/s · 14% of blows miss (full cloud: more) / L20: Cloud 4.5 yd · sickens 20/s · 21% of blows miss (full cloud: more). Perks (at skill level): L5 Thick Air: The cloud thickens twice as fast while sickened enemies stand in it. L10 Carrion Bloom: Sickened enemies that die burst into a miasma cloud twice as often. L15 +60 Essence Shroud: +10% chance for blows to miss you. `zz_miasma_breath.js` `m_mias.js` `o_skills14.js` **[Act I]**

- **`shuriken` Iron War-Fan** (row 1, level 1, cast; cost Miasma 9.6→13.9 (L10)): Hurl a spinning bone shuriken that spirals outward from where you stand, cutting everything it passes and trailing miasma behind it. Numbers: L1: 8 per cut · spirals out to ~4.5 yd · trails miasma / L10: 29 per cut · spirals out to ~4.5 yd · trails miasma / L20: 52 per cut · spirals out to ~4.5 yd · trails miasma. Perks (at skill level): L5 Twin Stars: Two shurikens spiral out in opposite turns. L10 +50 Constitution Splintering Star: Every enemy a shuriken cuts sheds a knife at the next. Synergies (per hard point): Venom Claws +3%, Miasma Tide +3%. `m_mias.js` `c_game.js` `o_skills14.js` **[Act I]**

- **`inhale` Inhale** (row 2, level 6, passive; cost none; needs Venom Claws): A slow, unconscious breathing-in. Every few beats she sips the miasma nearby — from the air, from her clouds, from anything sickened around her — and it trickles back as Miasma. She breathes deeper with rank: more often, and more taken in each breath. She still fills fast when standing inside her own cloud. Numbers: L1: Miasma torn out strikes for 84% of what it had left · clouds within 8 yd refill Miasma / L10: Miasma torn out strikes for 106% of what it had left · clouds within 8 yd refill Miasma / L20: Miasma torn out strikes for 130% of what it had left · clouds within 8 yd refill Miasma. Perks (at skill level): L5 Deep Draw: Passive inhale also drags the sickened toward you a little. L10 +50 Essence Sick Breath: A passive breath draws more from the sickened, and gives half again as much Miasma. `zz_miasma_breath.js` `m_mias.js` `zz_hero_miasmancer.js` **[Act I]**

- **`pnova` Miasmic Exhalation** (row 2, level 6, cast; cost Miasma 19.2→27.8 (L10); needs Miasma): She lets out a long purple breath: a ring of miasma rolls outward around her, shoving back and sickening hard everything it touches. Not a shout, not a blow — a slow, sickened exhale. Numbers: L1: 10 damage · sickens 5/s for 4 s · 5 yd / L10: 38 damage · sickens 21/s for 4 s · 5 yd / L20: 70 damage · sickens 38/s for 4 s · 5 yd. Perks (at skill level): L5 Lingering Ring: The ring leaves a circle of miasma clouds where it ends. L10 +55 Essence Second Breath: A second ring follows half a second later. Synergies (per hard point): Miasma +3%, Exhale +3%. `m_mias.js` `o_skills14.js` `zz_miasma_breath.js` **[Act I]**

- **`contagion` Contagion** (row 3, level 12, cast; cost Miasma 14.4→20.9 (L10); needs Inhale): Mark the enemy nearest the cursor. Its miasma leaps to the two nearest enemies every 1.5 s, and when it dies it bursts into a great cloud. Numbers: L1: Leaps every 1.5 s · 4/s miasma · 10 s / L10: Leaps every 1.5 s · 14/s miasma · 10 s / L20: Leaps every 1.5 s · 26/s miasma · 10 s. Perks (at skill level): L5 Epidemic: It leaps to three enemies instead of two. L10 +50 Essence Carried on the Wind: It leaps from 5 yd away. Synergies (per hard point): Venom Claws +3%, Miasma Vortex +3%. `m_mias.js` `o_skills14.js` `zz_hero_miasmancer.js` **[Act I]**

- **`rotwall` Miasma Tide** (row 3, level 12, cast; cost Miasma 22.4→32.5 (L10); needs Iron War-Fan): A slashing wall of miasma rolls forward from you in a straight line. It cuts and sickens everything it passes and carries enemies along before it. Numbers: L1: 13 damage · miasma 5/s · 2.4 yd wide / L10: 48 damage · miasma 19/s · 3.6 yd wide / L20: 87 damage · miasma 35/s · 3.6 yd wide. Perks (at skill level): L5 Broad Tide: The wall is half again as wide. L10 +50 Essence Lingering Wake: It leaves miasma clouds along its path. Synergies (per hard point): Iron War-Fan +4%, Miasmic Exhalation +3%. `m_mias.js` `o_skills14.js` `n_mias_ui.js` **[Act I]**

- **`exhale` Exhale** (row 4, level 18, cast; cost none; needs Miasmic Exhalation): Empty your lungs: the whole cloud bursts out around you at once and blows enemies back. The more Miasma you spend, the harder it hits. The cloud must then thicken again from nothing. Numbers: L1: 77 damage now (x1.24 per Miasma) · 3.5 yd / L10: 98 damage now (x1.59 per Miasma) · 3.5 yd / L20: 123 damage now (x1.98 per Miasma) · 3.5 yd. Perks (at skill level): L5 Last Gasp: The burst also leaves enemies confused for 2 s. L10 +60 Essence Held Back: Exhale keeps a third of what it spends. Synergies (per hard point): Inhale +4%, Miasmic Exhalation +3%. `zz_miasma_breath.js` `zz_hero_miasmancer.js` `m_mias.js` `o_skills14.js` **[later]**

- **`mstorm` Miasma Vortex** (row 5, level 24, cast; cost Miasma 35.2→51 (L10); needs Exhale): Draw your cloud into a slow purple vortex that turns around you and breathes: it inhales for a beat and drags every enemy toward you, then exhales and shoves them back, over and over. It tears at and sickens whatever cannot leave. Numbers: L1: 7/s in 3.2 yd · slows · 8 s / L10: 23/s in 4.2 yd · slows · 10 s / L20: 42/s in 4.2 yd · slows · 12 s. Perks (at skill level): L5 Wide Eye: The storm reaches a yard farther. L10 +55 Essence Undertow: The storm drags enemies in toward you. Synergies (per hard point): Contagion +4%, Miasma +3%. `zz_miasma_flavor.js` `m_mias.js` `o_skills14.js` **[later]**

- **`toxic` Toxicology** (row 6, level 30, passive; cost none): The breath you make is fouler. Every miasma cloud hangs longer, and its sickness bites deeper into whatever stands in it. Numbers: L1: +10% miasma · clouds +5% longer / L10: +100% miasma · clouds +50% longer / L20: +200% miasma · clouds +100% longer. Perks (at skill level): L5 Seeping Sickness: The sickened leak miasma twice as often. L10 +65 Essence Miasma-Eater: Standing in miasma thickens yours twice as fast again. `m_mias.js` `n_mias_ui.js` **[later]**

#### Trap tree (tab 1)

- **`ntrap` Needle Sentry** (row 1, level 1, cast; cost Miasma 11.2→16.2 (L10)): Throw a sentry of bone needles. Once armed it spits miasma-soaked needles at the nearest enemy until it runs dry. Numbers: L1: 12 needles · 5 each · miasma / L10: 18 needles · 19 each · miasma / L20: 18 needles · 35 each · miasma. Perks (at skill level): L5 Full Quiver: Six more needles. L8 Corpse Sentry: Every couple of seconds it bursts a corpse near it into a great miasma cloud. L12 +45 Constitution Long Needles: Needles pass through an enemy. Synergies (per hard point): Sighing Bladder +3%, Miasma Wake +3%. `m_mias.js` `o_skills14.js` `zx_minions32.js` **[Act I]**

- **`blur` Blur** (row 1, level 1, cast; cost Miasma 12.8→18.6 (L10)): Bend the air and step to the cursor. A decoy of you stays behind and draws the enemy for 3 s. Numbers: L1: Step up to 6 yd · decoy 3 s / L10: Step up to 6 yd · decoy 3 s / L20: Step up to 6 yd · decoy 3 s. Perks (at skill level): L5 Miasmic Double: The decoy bursts into a miasma cloud when it fades or falls. L10 +45 Essence Smear: For 2 s after you step, blows miss you 30% more often. `m_mias.js` `c_game.js` `n_mias_ui.js` **[Act I]**

- **`mwake` Miasma Wake** (row 2, level 6, cast; cost Miasma 16→23.2 (L10); needs Needle Sentry): Throw a cracked censer that never stops smoking. It leaks miasma all around it and, whenever an enemy comes near, breathes a rolling wave of it that shoves them back. Numbers: L1: Smokes 12 s · waves 7 and sicken / L10: Smokes 12 s · waves 24 and sicken / L20: Smokes 12 s · waves 44 and sicken. Perks (at skill level): L5 Deep Censer: Its waves are wider and roll farther. L10 +50 Essence Everburning: It smokes twice as long. Synergies (per hard point): Needle Sentry +3%, Sighing Bladder +3%. `m_mias.js` `zx_minions32.js` `o_skills14.js` **[Act I]**

- **`haze` Haze** (row 2, level 6, cast; cost Miasma 17.6→25.5 (L10); needs Blur): A cloud of distortion at the cursor. Enemies inside lose their minds: they wander and turn on each other. Numbers: L1: 4 s · 2.2 yd · confuses / L10: 6 s · 2.2 yd · confuses / L20: 6 s · 2.2 yd · confuses. Perks (at skill level): L5 Deep Haze: The haze lasts 2 s longer. L10 +50 Essence Madness: Confused enemies take 20% more damage. `m_mias.js` `c_game.js` `zz_hero_miasmancer.js` **[Act I]**

- **`bmine` Sighing Bladder** (row 3, level 12, cast; cost Miasma 19.2→27.8 (L10); needs Miasma Wake): Throw a swollen bladder of breath caught and gone wrong. When anything comes near it splits open with a wet sigh, and a great purple miasma cloud unfurls. Numbers: L1: Bursts for 23 · cloud 2.2 yd / L10: Bursts for 80 · cloud 3.3 yd / L20: Bursts for 142 · cloud 3.3 yd. Perks (at skill level): L5 Wider Sigh: The sigh unfurls half again as wide. L10 +50 Essence Wailing Rot: The bladder wails as it splits: what the sigh touches is terrified for 1.5 s. Synergies (per hard point): Needle Sentry +4%, Miasma Wake +3%. `zz_miasma_flavor.js` `m_mias.js` `o_skills14.js` **[Act I]**

- **`mirage` Mirage** (row 3, level 12, cast; cost Miasma 20.8→30.2 (L10); needs Haze): A field of bent light at the cursor. Enemies inside move at half speed, and missiles that cross it veer off course. Numbers: L1: 6 s · 2.6 yd · half speed · missiles veer / L10: 9 s · 2.6 yd · half speed · missiles veer / L20: 9 s · 2.6 yd · half speed · missiles veer. Perks (at skill level): L5 Lasting Mirage: It lasts 3 s longer. L10 +55 Essence Folded Air: Missiles that cross it turn back the way they came. `m_mias.js` `n_mias_ui.js` `c_game.js` **[Act I]**

- **`lure` Siren Lure** (row 4, level 18, cast; cost Miasma 16→23.2 (L10); needs Haze): Throw a charm of birch and finger-bone that sings small and terrible. For a few seconds it drags the living toward it by the ears. Numbers: L1: 3 s · pulls within 5 yd / L10: 5 s · pulls within 5 yd / L20: 5 s · pulls within 5 yd. Perks (at skill level): L5 Long Song: It sings 2 s longer. L10 +50 Essence Siren Call: It pulls from 8 yd away. `m_mias.js` `zx_minions32.js` `n_mias_ui.js` **[later]**

- **`warp` Warped Miasma** (row 4, level 18, passive; cost none; needs Mirage): Your distortion seeps into every miasma cloud you make, and into your own. Enemies in them are now and then struck by it: confused, slowed to a crawl, or twisted toward the heart of the cloud. Numbers: L1: 4% per tick per enemy in your miasma / L10: 13% per tick per enemy in your miasma / L20: 18% per tick per enemy in your miasma. Perks (at skill level): L5 Thin Veil: It strikes twice as often. L10 +55 Essence Night Terrors: It can also terrify. `m_mias.js` `n_mias_ui.js` `c_game.js` **[later]**

- **`sister` The Mirror-Sister** (row 5, level 24, passive; cost none; needs Warped Miasma): A distorted reflection of you steps out of the haze and walks at your side. You do not command her. She fights with your own skills, as she sees fit, at a share of your strength. Numbers: L1: Acts every 3.2 s · 37% of your strength / L10: Acts every 1.4 s · 45% of your strength / L20: Acts every 1.3 s · 54% of your strength. Perks (at skill level): L5 Eager Reflection: She acts twice as often. L10 +60 Essence Wrong Face: Whatever she strikes is confused for a msigilt. `m_mias.js` `zz_miasma_breath.js` `zx_minions32.js` **[later]**

- **`unseen` The Unseen** (row 6, level 30, passive; cost none): Your confusion, slows and snares last longer, blows miss you more often, and your traps hit harder. You can have more traps out at once (one more at levels 1, 5 and 10). Numbers: L1: +4% control time · +1% evasion · 3 traps, +8% trap damage / L10: +40% control time · +10% evasion · 5 traps, +80% trap damage / L20: +80% control time · +20% evasion · 6 traps, +160% trap damage. Perks (at skill level): L5 Vanish: After a Blur you are unseen for 1 s. L8 Hair Trigger: Traps arm the msigilt they land. L12 Trap Field: One more trap. L16 +60 Essence Deep Dark: Your control lasts a quarter longer again. `m_mias.js` `q_fate.js` `n_mias_ui.js` **[later]**

#### Sigil tree (tab 2)

- **`rarc` Rending Arc** (row 1, level 1, cast; cost poise 5): A wide, sweeping claw cut in a half-circle before you, tearing everything in reach. Each enemy caught beyond the first adds 10% to the blow. Catching three or more gives a Sigil. Numbers: L1: 7 to each in a half-circle · +10% per extra enemy / L10: 11 to each in a half-circle · +10% per extra enemy / L20: 14 to each in a half-circle · +10% per extra enemy. Perks (at skill level): L5 Crossing Arcs: A second arc tears back across the first. L10 +50 Constitution Wide Sweep: The arc reaches 0.6 yd farther. Synergies (per hard point): Grave Strike +3%, Raven Flurry +2.5%. `m_mias.js` `o_skills14.js` `c_game.js` **[Act I]**

- **`gstrike` Grave Strike** (row 1, level 1, cast; cost poise 6): A heavy claw blow that marks you with a Sigil of death. Sigils circle you as pale skulls: each one makes you strike harder and faster. They stack up to three and fade after a while. Finishers (Reap, Execute) spend them. Numbers: L1: 10 damage · +1 Omen · each Omen +6% damage, +5% speed / L10: 15 damage · +1 Omen · each Omen +6% damage, +5% speed / L20: 20 damage · +1 Omen · each Omen +6% damage, +5% speed. Perks (at skill level): L5 Soul Rend: Strikes mend 2% of your life for each Sigil you hold. L10 +50 Constitution Grave Combo: Every third Grave Strike hits twice. Synergies (per hard point): Rending Arc +3%, Execute +2.5%. `m_mias.js` `o_skills14.js` `c_game.js` **[Act I]**

- **`thrust` Impaling Thrust** (row 1, level 1, cast; cost poise 6): Drive both claws forward in a straight, piercing thrust that runs through every enemy in a 3 yd line. Gives a Sigil if it pierces anything. Numbers: L1: 9 to each in a 3 yd line / L10: 13 to each in a 4 yd line / L20: 18 to each in a 4 yd line. Perks (at skill level): L5 Long Reach: The thrust reaches a yard farther. L10 +50 Constitution Pinned: The first enemy it runs through is pinned in place for a second. Synergies (per hard point): Death's Step +3%, Grave Strike +2.5%. `m_mias.js` `zz_hero_miasmancer.js` `o_skills14.js` **[Act I]**

- **`talon` Crow's Heel** (row 2, level 6, cast; cost poise 7; needs Rending Arc): A spinning flurry of three kicks into the enemy nearest the cursor, the last one throwing it back. Gives a Sigil. Numbers: L1: 3 kicks · 4 each · +1 Omen / L10: 4 kicks · 6 each · +1 Omen / L20: 4 kicks · 9 each · +1 Omen. Perks (at skill level): L5 Fourth Kick: One more kick. L10 +50 Constitution Crushing Heel: The last kick stuns for a second. Synergies (per hard point): Rending Arc +3%, Death's Step +2.5%. `m_mias.js` `o_skills14.js` `n_mias_ui.js` **[Act I]**

- **`dstep` Death's Step** (row 2, level 6, cast; cost poise 10; needs Impaling Thrust): Rush to the cursor through your enemies, cutting each one you pass. Gives a Sigil if you cut anything. Numbers: L1: 7 to each · 5 yd / L10: 10 to each · 8 yd / L20: 13 to each · 8 yd. Perks (at skill level): L5 Long Stride: You rush up to 8 yd. L10 +50 Constitution Sigil Trail: An Sigil for every enemy you cut. Synergies (per hard point): Impaling Thrust +4%. `m_mias.js` `o_skills14.js` `n_mias_ui.js` **[Act I]**

- **`reap` Reap** (row 3, level 12, cast; cost poise 8; needs Crow's Heel): Finisher: a sweeping claw cut all around you that spends every Sigil. Each Sigil widens it and adds damage; with three it throws enemies back. Numbers: L1: 9 · +70% and +0.3 yd per Omen / L10: 13 · +70% and +0.3 yd per Omen / L20: 17 · +70% and +0.3 yd per Omen. Perks (at skill level): L5 Wide Harvest: Reap reaches 30% farther. L8 Mourning Knell: Kills made by a finisher ring a funeral knell: enemies around you flee in terror for 2 s. L12 Harvest Feast: Mend 3% of your life for each Sigil spent. L16 +50 Essence Dread: Terrified enemies take 20% more damage. Synergies (per hard point): Execute +3%, Grave Strike +2.5%. `m_mias.js` `o_skills14.js` `n_mias_ui.js` **[Act I]**

- **`flurry` Raven Flurry** (row 3, level 12, cast; cost poise 7; needs Grave Strike): Hold: a fast chain of claw strikes at the enemy nearest the cursor. Each strike leaps to another enemy within reach if there is one, like a raven moving between carcasses. Every fourth strike gives a Sigil. Numbers: L1: 4 strikes · 4 each · hops between enemies in reach / L10: 6 strikes · 6 each · hops between enemies in reach / L20: 6 strikes · 8 each · hops between enemies in reach. Perks (at skill level): L5 Murder of Crows: Two more strikes in each chain. L10 +55 Constitution Carrion Sigil: Every third strike gives a Sigil instead. Synergies (per hard point): Rending Arc +3%, Crow's Heel +3%. `m_mias.js` `zw_monk_ui.js` `o_skills14.js` **[Act I]**

- **`dhead` Death's Head** (row 3, level 12, passive; cost none; needs Death's Step): You find the seam under the skin, where a stroke goes through to the marrow. Now and then your blows and strikes land as clean, killing cuts. Numbers: L1: 5% critical chance / L10: 18% critical chance / L20: 33% critical chance. Perks (at skill level): L5 Deathblow: Critical hits strike for triple instead. L10 +55 Constitution Death Sign: Critical hits give a Sigil. `m_mias.js` `n_mias_ui.js` **[Act I]**

- **`execute` Execute** (row 4, level 18, cast; cost poise 8; needs Raven Flurry): Finisher: strike the enemy nearest the cursor, spending every Sigil. Below 10% life (+8% per Sigil) it dies outright; bosses take triple damage instead. Numbers: L1: 12 · +90% per Omen · kills below 10% +8% per Omen / L10: 16 · +90% per Omen · kills below 10% +8% per Omen / L20: 21 · +90% per Omen · kills below 10% +8% per Omen. Perks (at skill level): L5 Clean Kill: Execute costs no stamina. L10 +60 Constitution Headsman: It kills outright below 15% life (+8% per Sigil). Synergies (per hard point): Reap +3%, Grave Strike +2.5%. `m_mias.js` `o_skills14.js` `n_mias_ui.js` **[later]**

- **`deathm` Sigil Mastery** (row 6, level 30, passive; cost none): Death sits closer to your hands. Every claw stroke and every strike falls heavier than the last. Numbers: L1: +6% melee · 3 Omens · claws: +25% strikes, +15% speed / L10: +60% melee · 3 Omens · claws: +25% strikes, +15% speed / L20: +120% melee · 3 Omens · claws: +25% strikes, +15% speed. Perks (at skill level): L5 Swift Death: You strike 10% faster. L8 Last Breath: Once a minute, a killing blow leaves you at 1 life instead, unseen and untouchable for 2 s. L12 Second Wind: Last Breath also mends 30% of your life. L16 +65 Constitution Fourth Sigil: You can hold a fourth Sigil. `m_mias.js` `n_mias_ui.js` **[later]**

### 8.5 The Empty Hand (`monk`): the hourglass

- **Resource: the glass** (v0.54–v0.55). Two sands in one hourglass: Radiance skills pour amber sand **down** and Absence skills pour black sand **up**. Destroyer costs poise instead (0.6× cost; Thousand Arms 1.2×). Each bulb holds half the Essence maximum. `zz_monk_sand.js` **[Act I]**

- **The fuller a bulb, the weaker that tree:** strength = 1 − 0.9 × fullness^2.5 (half full 84%, full 10%). **Never locked out:** a full bulb still casts, at a tenth. `zz_monk_sand.js` **[Act I]**

- **Pouring:** a cast pours 5% of the bulb per 12.8 of cost, max 25% at once. Turning the sky (Halo-That-Turns, Gate-Without-A-Gate) pours ×3; underground it lasts and costs half. Held skills pour while held. `zz_monk_sand.js` **[Act I]**

- **Running back:** 10% a second while fighting or casting, 35% a second after 0.4 s without casting (a full bulb empties in under 3 s). Every hit runs both bulbs back 1.5%, every kill 12%, from any tree. The finishing blow and the Bowl also run it back. `zz_monk_sand.js` `zz_zz_study82.js` **[Act I]**

- **The sky:** Radiance is ×(0.75 + 0.6×daylight), stronger by day; Absence ×(0.75 + 0.6×darkness). Destroyer ignores the sky; underground is neutral (×1) unless he turns the sky. Radiance areas are ×0.88→1.12 by day; Absence durations ×0.85→1.2 by night. His skill damage carries a global ×0.75 (`MONK_TUNE`). `zw_monk.js` **[Act I]**

- **Kills leave no corpse:** glass, dust, rubble or red mist (the Silence's servants leave nothing to raise). `zw_monk.js` **[Act I]**

- **Doorways:** That-Which-Bars-The-Way lets him close a doorway or narrow pass; nothing smaller than a Bellwether presses past. `zw_monk.js` **[later]**

- **Removed:** Weight, stances, Perfect Poise, the yin-yang orb and every wait (the code forces Weight to 50 each frame; the tooltips still print "eats 5 Weight", so strip that). `zz_monk_sand.js` **[Act I]**

- **HUD:** a tall hourglass in a pointed niche, with no serpent. `zz_hud55.js` **[Act I]**

- **The Empty Hand's skills, by tree:**

#### Radiance tree (tab 0)

- **`kdawn` Halo-That-Turns** (row 1, level 1, cast; cost Radiance sand ≈22% of the bulb (cost 19.2→27.8 at L10)): The class skill (turning the sky is dear: it pours three times the sand). Raise your palm and force a blinding noon for 20 s. Radiance peaks; night creatures are dazzled; ghosts and Gasps are dragged into the open. Underground it lasts half as long and costs half. Numbers: L1: 20 s · turning the sky pours three times the sand / L10: 28 s · turning the sky pours three times the sand / L20: 28 s · turning the sky pours three times the sand. Perks (at skill level): L5 Long Noon: The false noon lasts 8 s longer. L10 White Glare: Everything the glare dazzles also burns. `zw_monk.js` `zz_monk_sand.js` `zz_mech_balance.js` **[Act I]**

- **`kamber` Amber-That-Eats-Itself** (row 1, level 1, cast; cost Radiance sand ≈4% of the bulb (cost 9.6→13.9 at L10)): Toggle: an aura of amber-white fire sears everything near you. While it burns it sets you on fire: it eats a little of your life every second. Numbers: L1: 9/s within 2.4 yd · eats 5 Weight and 1% life a second · sky x1.35 / L10: 30/s within 2.4 yd · eats 5 Weight and 1% life a second · sky x1.35 / L20: 54/s within 2.4 yd · eats 5 Weight and 1% life a second · sky x1.35. Perks (at skill level): L5 Ash-For-Breakfast: Enemies the aura kills give back 3% of your life. L10 +50 Essence Wide Amber: The aura reaches a yard farther. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`khands` Hundred-Hands-Of-Morning** (row 1, level 1, cast; cost Radiance sand ≈5% of the bulb (cost 12.8→18.6 at L10)): A quick melee flurry: one hundred open palms in 1.5 s into the enemy nearest the cursor, each burning it, ending with a shove that throws it back. Numbers: L1: 100 palms · 110 in all · sky x1.35 / L10: 100 palms · 169 in all · sky x1.35 / L20: 100 palms · 235 in all · sky x1.35. Perks (at skill level): L5 Last Palm: The final shove stuns for 1.5 s and throws twice as far. Synergies (per hard point): Fist-Of-High-Noon +3%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`klaugh` Laughter-Without-Warmth** (row 2, level 6, passive; cost none; needs Halo-That-Turns): Every few seconds a dry laugh rattles out of you: a pulse of white radiation that burns everything near and strips wards. Shield-guards drop, parries break, and the Silent Ones' darkness lifts. Numbers: L1: 7 within 3.6 yd every 3.8 s · sky x1.35 / L10: 27 within 4.5 yd every 3.5 s · sky x1.35 / L20: 49 within 4.5 yd every 3.2 s · sky x1.35. Perks (at skill level): L5 Laugh Down The Valley: The laugh reaches 25% farther. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`kstar` Morning-Star-Exhaled** (row 2, level 6, cast; cost Radiance sand ≈6% of the bulb (cost 16→23.2 at L10); needs Amber-That-Eats-Itself): A long, rattling breath out, then a cone of radiant fire that sweeps the arc of your aim. It is half again as strong against the raised dead. Numbers: L1: 16 in a 5.2 yd cone · x1.5 on the raised dead · sky x1.35 / L10: 55 in a 5.2 yd cone · x1.5 on the raised dead · sky x1.35 / L20: 98 in a 5.2 yd cone · x1.5 on the raised dead · sky x1.35. Perks (at skill level): L5 Dawn On The Grave: The raised dead it touches keep burning. Synergies (per hard point): Amber-That-Eats-Itself +3%, Fist-Of-High-Noon +2.5%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`ksutra` Sutra-That-Seeks** (row 3, level 12, cast; cost Radiance sand ≈4% of the bulb (cost 9.6→13.9 at L10); needs Laughter-Without-Warmth): A halo of burning paper sutras floats behind your head. Cast to loose it: each sutra peels off, seeks an enemy near the cursor and bursts. The halo regrows over time. Numbers: L1: 3 talismans · 12 each · one regrows every 1.4 s · sky x1.35 / L10: 7 talismans · 40 each · one regrows every 1.4 s · sky x1.35 / L20: 10 talismans · 72 each · one regrows every 1.4 s · sky x1.35. Perks (at skill level): L5 Long Sutra: Two more sutras in the halo. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`kfist` Fist-Of-High-Noon** (row 3, level 12, cast; cost Radiance sand ≈10% of the bulb (cost 25.6→37.1 at L10); needs Hundred-Hands-Of-Morning): Raise one bare hand: a colossal fist of light slams down from the sky on the cursor. It deals huge damage to whatever is beneath it, then leaves a ring of holy fire. Numbers: L1: 55 to the one beneath · ring 19 · sky x1.35 / L10: 183 to the one beneath · ring 64 · sky x1.35 / L20: 325 to the one beneath · ring 114 · sky x1.35. Perks (at skill level): L5 Noon Ring: The ring of fire is a yard wider and sets what it touches alight. Synergies (per hard point): Hundred-Hands-Of-Morning +4%, Morning-Star-Exhaled +2.5%. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`ktears` Tears-For-The-Living** (row 4, level 18, cast; cost Radiance sand ≈8% of the bulb (cost 19.2→27.8 at L10); needs Sutra-That-Seeks): Weep in mock sorrow. Glowing tears fall around you and lie as flame-mines; each erupts as a geyser of white fire when something steps on it. Numbers: L1: 5 tears · geysers 21 · lie 15 s · sky x1.35 / L10: 10 tears · geysers 71 · lie 15 s · sky x1.35 / L20: 12 tears · geysers 126 · lie 15 s · sky x1.35. Perks (at skill level): L5 Inconsolable: Three more tears. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[later]**

- **`keye` Eye-Between-The-Brows** (row 4, level 18, hold; cost Radiance sand ≈2% of the bulb (cost 6.4→9.3 at L10); needs Morning-Star-Exhaled): Hold: the third eye opens and fires a thin phosphor-white beam from your forehead. Move the cursor to sweep it. It cuts through everything in its line, armour and bone, and through the ruins' pillars too. Numbers: L1: 32/s along 7.5 yd, through walls · sky x1.35 / L10: 96/s along 7.5 yd, through walls · sky x1.35 / L20: 167/s along 7.5 yd, through walls · sky x1.35. Perks (at skill level): L5 Armour Like Paper: What the beam touches loses a third of its armour for 4 s. Synergies (per hard point): Morning-Star-Exhaled +3%, Lotus-Without-Mercy +2.5%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

- **`kbell` Bell-Of-One-Syllable** (row 4, level 18, cast; cost Radiance sand ≈11% of the bulb (cost 28.8→41.8 at L10); needs Fist-Of-High-Noon): Chant one deafening syllable: a bell of bronze light drops over you. It stops missiles, and every blow struck on it from outside rings a blinding wave that burns and dazzles. Numbers: L1: 5.2 s · waves 13 · blows on the bell lose 70% · sky x1.35 / L10: 6.0 s · waves 45 · blows on the bell lose 70% · sky x1.35 / L20: 6.9 s · waves 81 · blows on the bell lose 70% · sky x1.35. Perks (at skill level): L5 Great Bell: Its waves stun for 1.5 s. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

- **`klotus` Lotus-Without-Mercy** (row 5, level 24, hold; cost Radiance sand ≈3% of the bulb (cost 8→11.6 at L10); needs Eye-Between-The-Brows): Hold: sit cross-legged in the air, eyes shut. A vortex of solid light grows around you every second, shredding anything inside. You cannot move, and nothing can shake you. Numbers: L1: 18/s at full size · grows to 4.0 yd · sky x1.35 / L10: 61/s at full size · grows to 4.0 yd · sky x1.35 / L20: 108/s at full size · grows to 4.0 yd · sky x1.35. Perks (at skill level): L5 Drawn To The Flame: The vortex drags enemies inward. Synergies (per hard point): Eye-Between-The-Brows +3%, Amber-That-Eats-Itself +2.5%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

- **`ksun` He-Who-Hangs-As-The-Sun** (row 6, level 30, cast; cost Radiance sand ≈25% of the bulb (cost 64→92.8 at L10); needs Lotus-Without-Mercy): Laugh, rise into the air and become a small sun for 10 s. No blow can reach you, and amber beams track and melt every enemy in your gaze. The glass pays dearly for it. Numbers: L1: 10 s · beams 26 at 3 enemies · sky x1.35 / L10: 10 s · beams 76 at 4 enemies · sky x1.35 / L20: 10 s · beams 131 at 5 enemies · sky x1.35. Perks (at skill level): L1 +75 Essence The Long Day: You hang in the sky 4 s longer, and your beams strike one more enemy. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

#### Absence tree (tab 1)

- **`keclipse` Gate-Without-A-Gate** (row 1, level 1, cast; cost Absence sand ≈22% of the bulb (cost 19.2→27.8 at L10)): The class skill (turning the sky is dear: it pours three times the sand). Close your hand over the sun and force night for 20 s. Every light but your own gutters; Absence peaks; enemies lose sight of you beyond 6 yd. Underground it lasts half as long and costs half. Numbers: L1: 20 s · turning the sky pours three times the sand / L10: 28 s · turning the sky pours three times the sand / L20: 28 s · turning the sky pours three times the sand. Perks (at skill level): L5 Long Night: The false night lasts 8 s longer. L10 Blind Dark: Enemies lose you beyond 4 yd instead. `zw_monk.js` `zz_monk_sand.js` `zz_mech_balance.js` **[Act I]**

- **`kpalm` Palm-That-Is-Hungry** (row 1, level 1, cast; cost Absence sand ≈6% of the bulb (cost 16→23.2 at L10)): Open one palm into a black hole. For a second it drags every enemy within 7 yd across the field toward you, tearing at them as they come. Numbers: L1: Drags within 7 yd · 18/s · sky x0.75 / L10: Drags within 10 yd · 66/s · sky x0.75 / L20: Drags within 10 yd · 118/s · sky x0.75. Perks (at skill level): L5 Bottomless: It reaches 10 yd. Synergies (per hard point): Hand-From-Below +3%. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`kclap` Clap-That-Ends-Speech** (row 1, level 1, cast; cost Absence sand ≈5% of the bulb (cost 12.8→18.6 at L10)): One enormous clap: a ring of negative pressure. Everything near is stunned for a moment, and every wind-up is broken off: the blow never lands. Numbers: L1: 4 · stuns 0.6 s within 3.4 yd · sky x0.75 / L10: 15 · stuns 1.2 s within 4.9 yd · sky x0.75 / L20: 26 · stuns 1.2 s within 4.9 yd · sky x0.75. Perks (at skill level): L5 Thunder Of Nothing: The ring is 1.5 yd wider and stuns twice as long. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`kbowl` Bowl-That-Holds-Nothing** (row 2, level 6, cast; cost none; needs Gate-Without-A-Gate): You carry a wooden alms bowl. Missiles and spells that strike you from the front can fall into it instead (the chance grows with level). When it is full you drink: life, and a quarter of the sand in both bulbs of your glass runs back. Cast to drink what is in it now. Numbers: L1: 33% of frontal missiles swallowed · full at 6 · holds 0 / L10: 46% of frontal missiles swallowed · full at 6 · holds 0 / L20: 61% of frontal missiles swallowed · full at 6 · holds 0. Perks (at skill level): L5 Beggar Of All Sides: The bowl catches missiles from every side. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` `zz_mech_trees.js` **[Act I]**

- **`kspade` Spade-That-Cuts-Shadows** (row 2, level 6, cast; cost Absence sand ≈4% of the bulb (cost 11.2→16.2 at L10); needs Palm-That-Is-Hungry): A wide arc of the spade (or staff, or fist) that hooks enemies' shadows and tears them loose. A shadowless enemy is rooted to the spot and bleeds spirit. It only works on the lit: torchlight matters. Best with a spade. Numbers: L1: 7 in an arc · shadowless: rooted 2.1 s, 5/s · sky x0.75 / L10: 10 in an arc · shadowless: rooted 2.1 s, 17/s · sky x0.75 / L20: 13 in an arc · shadowless: rooted 2.1 s, 30/s · sky x0.75. Perks (at skill level): L5 Grave-Light: It tears the shadows of the unlit too, for half as long. Synergies (per hard point): Hand-From-Below +2.5%. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`kpinch` Pinch-That-Cuts-The-Strings** (row 2, level 6, cast; cost Absence sand ≈4% of the bulb (cost 11.2→16.2 at L10); needs Clap-That-Ends-Speech): A precise pinch at the enemy nearest the cursor. Lesser raised things (Husks, Weepers, the Ossuary's dead) collapse to dust at once. The living are silenced and drained: they cannot strike for 3 s and hit weakly for 6. Numbers: L1: Lesser raised dead collapse · the living: silenced 3 s, 10 damage · sky x0.75 / L10: Lesser raised dead collapse · the living: silenced 3 s, 34 damage · sky x0.75 / L20: Lesser raised dead collapse · the living: silenced 3 s, 60 damage · sky x0.75. Perks (at skill level): L5 All Strings: Champions of the raised dead collapse too. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`kbelow` Hand-From-Below** (row 3, level 12, cast; cost Absence sand ≈9% of the bulb (cost 22.4→32.5 at L10); needs Spade-That-Cuts-Shadows): A colossal, many-jointed hand of shadow erupts under the strongest enemy near the cursor. It grips it, holds it and slowly crushes it. Bosses are held for a moment only. Numbers: L1: Holds 2.5 s · crushes 9/s · sky x0.75 / L10: Holds 2.5 s · crushes 29/s · sky x0.75 / L20: Holds 2.5 s · crushes 50/s · sky x0.75. Perks (at skill level): L8 Two Hands: A second hand grips the next strongest enemy nearby. Synergies (per hard point): Palm-That-Is-Hungry +3%, Spit-For-The-Starving +2.5%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`kspit` Spit-For-The-Starving** (row 3, level 12, cast; cost Absence sand ≈8% of the bulb (cost 19.2→27.8 at L10); needs Pinch-That-Cuts-The-Strings): Spit in the dirt at the cursor. Black roots of the starved dead burst up under your enemies: they entangle them and siphon their blood to you. Numbers: L1: Roots 2.2 yd · 5/s for 2.5 s · a fifth comes back as life · sky x0.75 / L10: Roots 3.3 yd · 18/s for 2.5 s · a fifth comes back as life · sky x0.75 / L20: Roots 3.3 yd · 32/s for 2.5 s · a fifth comes back as life · sky x0.75. Perks (at skill level): L5 Famine Field: The roots spread half again as wide. Synergies (per hard point): Hand-From-Below +2.5%. `zw_monk.js` `zz_monk_sand.js` `zz_mech_trees.js` `zw_monk_ui.js` **[Act I]**

- **`kmirror` Mirror-With-No-Face** (row 4, level 18, cast; cost Absence sand ≈6% of the bulb (cost 16→23.2 at L10); needs Bowl-That-Holds-Nothing): A short stance: your shawl goes abyss-black. Any melee blow that lands is swallowed, and a shadow-copy of the attacker strikes it back at double force. Numbers: L1: 3.1 s · blows come back x2 · sky x0.75 / L10: 3.6 s · blows come back x3 · sky x0.75 / L20: 4.2 s · blows come back x3 · sky x0.75. Perks (at skill level): L5 Deep Mirror: Reflected blows strike at triple force. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[later]**

- **`kwalk` Walks-Without-Feet** (row 4, level 18, cast; cost Absence sand ≈4% of the bulb (cost 9.6→13.9 at L10); needs Spit-For-The-Starving): Toggle: float an inch above the ground, your shawl gone black as pitch. Rhythmic waves of shadow wither everything around you. Mud and water no longer slow you. Drains Essence while it lasts. Numbers: L1: Waves 5 every 1.2 s within 2.8 yd · drains 1.5 Essence/s · sky x0.75 / L10: Waves 18 every 1.2 s within 2.8 yd · drains 1.5 Essence/s · sky x0.75 / L20: Waves 32 every 1.2 s within 2.8 yd · drains 1.5 Essence/s · sky x0.75. Perks (at skill level): L5 Hungry Ground: The waves also slow what they wither. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

- **`knothing` One-With-Nothing** (row 6, level 30, cast; cost Absence sand ≈22% of the bulb (cost 56→81.2 at L10); needs Hand-From-Below): For 8 s you do not exist: nothing can strike or see you, and the world drains to grey. Everything you pass near is marked. When you return, every mark collapses inward at once. The glass pays dearly for it. Numbers: L1: 8 s unseen · each mark collapses for 25 · sky x0.75 / L10: 8 s unseen · each mark collapses for 76 · sky x0.75 / L20: 8 s unseen · each mark collapses for 133 · sky x0.75. Perks (at skill level): L1 +75 Essence Returned Whole: Each collapsing mark gives back 2% of your life. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

#### Destroyer tree (tab 2)

- **`kbar` That-Which-Bars-The-Way** (row 1, level 1, passive; cost none): Your body is a fortress: blows lose much of their force on you and no longer push you. Standing in a doorway or a narrow pass, you close it: nothing smaller than a Bellwether can press past you. Numbers: L1: 16% less from blows · holds doorways · standing still: Weight +3/s / L10: 25% less from blows · holds doorways · standing still: Weight +3/s / L20: 34% less from blows · holds doorways · standing still: Weight +3/s. Perks (at skill level): L5 Stone Thorns: Enemies that strike you in melee take a fifth of the blow back. `zw_monk.js` `zz_monk_sand.js` `zz_mech_trees.js` `zw_monk_ui.js` **[Act I]**

- **`kfinger` One-Finger-Truth** (row 1, level 1, cast; cost poise ≈6 (0.6× cost 9.6)): After the old koan of the teacher who answered every question with one finger: a single thrust that ignores armour and guards and leaves a cauterized hole straight through. Always critical against the stone-cursed. Numbers: L1: 15 through any armour · x2.5 on stone / L10: 22 through any armour · x2.5 on stone / L20: 30 through any armour · x2.5 on stone. Perks (at skill level): L5 Straight Through: The hole goes on into the enemy behind. Synergies (per hard point): Grip-Of-Old-Stone +3%, Mantra-Of-Obsidian +2.5%. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`kgrip` Grip-Of-Old-Stone** (row 1, level 1, cast; cost poise ≈8 (0.6× cost 12.8)): Grasp the enemy nearest the cursor with ash-coated hands: it calcifies into weeping stone and cannot move. Your next blow on it shatters it into rubble for great damage. No corpse. Numbers: L1: Stone 4 s · the shattering blow +25 / L10: Stone 4 s · the shattering blow +83 / L20: Stone 4 s · the shattering blow +148. Perks (at skill level): L5 Spreading Stone: The stone creeps into one more enemy beside it. `zw_monk.js` `zz_monk_sand.js` `zz_mech_trees.js` `zw_monk_ui.js` **[Act I]**

- **`kobsid` Mantra-Of-Obsidian** (row 2, level 6, cast; cost poise ≈12 (0.6× cost 19.2); needs That-Which-Bars-The-Way): A guttural chant turns your skin to polished obsidian for a while. You move slower, but your fists hit far harder, and every punch leaves a fault in the enemy: at five faults it shatters. Numbers: L1: 11 s · fists x1.48 · 5 faults shatter / L10: 13 s · fists x1.64 · 4 faults shatter / L20: 16 s · fists x1.82 · 4 faults shatter. Perks (at skill level): L5 Brittle World: Four faults are enough. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` `zw_monk_ui.js` **[Act I]**

- **`kmount` Mountain-Falls-Laughing** (row 2, level 6, cast; cost poise ≈13 (0.6× cost 22.4); needs That-Which-Bars-The-Way): Leap with shocking agility for a starved old man and come down knees-first at the cursor, flattening everything beneath you. An earthquake of jagged stone rolls out from the impact. Numbers: L1: Leap 5.0 yd · 24 in 2.3 yd / L10: Leap 5.0 yd · 77 in 2.3 yd / L20: Leap 5.0 yd · 136 in 2.3 yd. Perks (at skill level): L5 Aftershock: The rolling stone stuns what it strikes. Synergies (per hard point): Step-That-Wakes-Bedrock +3.5%, Mantra-Of-Obsidian +2%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`kstep` Step-That-Wakes-Bedrock** (row 3, level 12, cast; cost poise ≈12 (0.6× cost 19.2); needs Mountain-Falls-Laughing): A slow, deliberate stomp: a line of bedrock spears thrusts up toward the cursor and impales from below. Water stops it; on the old flagstone roads it strikes twice as hard. Numbers: L1: 15 per spear · 6.5 yd · x2 on flagstones / L10: 49 per spear · 6.5 yd · x2 on flagstones / L20: 87 per spear · 6.5 yd · x2 on flagstones. Perks (at skill level): L5 Forked Stone: Two more lines of spears fan out beside the first. Synergies (per hard point): Mountain-Falls-Laughing +3.5%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`kpagoda` Pagoda-For-One** (row 3, level 12, cast; cost poise ≈13 (0.6× cost 22.4); needs Grip-Of-Old-Stone): Slap the ground with both palms: a stone pagoda bursts up and encases the enemy nearest the cursor. A snap of your fingers two seconds later collapses it inward. Numbers: L1: 33 when it falls / L10: 102 when it falls / L20: 178 when it falls. Perks (at skill level): L5 Falling Tiers: The collapse crushes everything within 2 yd. Synergies (per hard point): Grip-Of-Old-Stone +3%, Step-That-Wakes-Bedrock +2.5%. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[Act I]**

- **`kweep` The-Weeping-One-Who-Walks** (row 4, level 18, cast; cost poise ≈23 (0.6× cost 38.4); needs Mantra-Of-Obsidian): Call up the weeping stone guardian from the gate of the Peak, many-armed and taller than a house. It lumbers after your enemies, smashes them flat and draws their anger to itself. Only one walks at a time: cast again to send it to the cursor, or on it to dismiss it. It keeps its wounds. Numbers: L1: Life 136 · slams 21 · draws enemies within 5 yd / L10: Life 352 · slams 63 · draws enemies within 5 yd / L20: Life 592 · slams 110 · draws enemies within 5 yd. Perks (at skill level): L5 Quaking Palm: Its slams stun for a second. L10 +60 Vitality Temple Stone: Half again as much life. `zw_monk.js` `zz_monk_sand.js` `zw_monk_ui.js` **[later]**

- **`kthousand` Thousand-Arms-Of-Nothing** (row 6, level 30, cast; cost poise ≈43 (0.6× cost 72); needs Step-That-Wakes-Bedrock): A spectral many-armed figure stands up behind you, and a thousand arms of ash and stone strike out in a cone. Armour is pulverised; crowds turn to red mist. The glass pays dearly for it. Numbers: L1: 12 waves · 9 each in a 5.5 yd cone · halves armour / L10: 12 waves · 27 each in a 5.5 yd cone · halves armour / L20: 12 waves · 48 each in a 5.5 yd cone · halves armour. Perks (at skill level): L1 +75 Constitution Ten Thousand: Half again as many blows. Synergies (per hard point): Mountain-Falls-Laughing +1.5%, Step-That-Wakes-Bedrock +1.5%, One-Finger-Truth +1.5%. `zw_monk.js` `zz_monk_sand.js` `zz_arcana_monk.js` **[later]**

---

## 9. Skill trees and points (all orders)

- **Three trees per order**, ten to eleven skills each, in a D2 grid of 6 rows × 3 columns. Rows open at levels 1, 6, 12, 18, 24 and 30 (`ROWREQ`). Arrows show prerequisites; a prerequisite on another page shows as a short stub in that page's colour. `c_game.js` `zz_mech_trees.js` **[Act I]**

- **Learning:** 1 point per level plus quest and boss points; max 20 hard points per skill; needs the level and the prerequisite learned. The first point in a cast or hold skill puts it on the right button. `c_game.js` **[Act I]**

- **Cost growth:** each skill level adds 5% to its cost (`skillCost`), times any Arcana cost change. `o_skills14.js` **[Act I]**

- **Level growth:** each level past the first counts for 60% of the old per-level gain (`SKILL_GROWTH`). `c_game.js` **[Act I]**

- **Synergies (D2-style):** only hard points count; each synergy adds a fixed percent per point to the target skill (the lists are under each skill). `c_game.js` `zz_ui_desc.js` **[Act I]**

- **Perks:** each skill has 2–4 perks that switch on at a skill level (and sometimes an attribute threshold, for example +50 Essence). They then scale with the skill as virtual skills. `c_game.js` **[Act I]**

- **Kinds:** passive (tagged "[Passive]" in every description), cast, hold (channel while held), toggle, weapon (golem loadouts), mutation. `zz_passive_tag.js` **[Act I]**

- **+skills on items:** "+1 to  skills" (Adept, Scholarly, Hierophantic) and "+1 to All Skills" (Exalted, rare only). The Unmade card reversed gives +1 per Major held (max +4). They add to the effective level only. `k_arcana.js` `c_game.js` **[Act I]**

- **Melee skills never teleport:** out of reach, you walk to the foe and strike on arrival (the approach gives up after 4 s). `o_skills14.js` **[Act I]**

- **Hold-to-repeat** for every cast and hold skill on either mouse button. `o_skills14.js` **[Act I]**

- **Skill page** (S): the grimoire look (illuminated vellum page, carved tabs, tier numerals, 24 px engraved icon per skill, lit, dim and locked states). `zz_ui.js` **[Act I]**

- **Skill renames:** the final names come from `zz_mech_balance.js` and `zz_mech_names.js` (for example Bone Lance, Charnel Cage, Prayer Banner, Penitent Womb, Needle and Thread, Binding Thread, Spool, Unravelling, Veil, Iron War-Fan). Tree names at run time: Mystic Mirror · Soul · Thread; Ossuarch Ossuary · Bone · Carapace; Hemomancer Brood · Blood · Flesh; Shrine Keeper Miasma · Trap · Sigil; Empty Hand Radiance · Absence · Destroyer. `zz_mech_balance.js` `zz_mech_names.js` **[Act I]**

- **Skill lore text:** two to four lines of lore in each order's voice, with the numbers behind Shift. `zz_ui_desc.js` `zz_zz_empty92.js` **[Act I]**

## 10. The body board: the Inverted Triune (key A)

- **One engraved plate per order**, in ink on old paper (a microcosm figure in a circle), carrying one system: the Ossuarch's is *The Standing Frame* (bone; Majors over the sacrum), the Hemomancer's *The Red Nave* (blood; heart), the Hollow Mystic's *The Hall of Mirrors* (nerves and threads; head), the Shrine Keeper's *The Well-Shrine* (breath; lungs) and the Empty Hand's *The Black-Flame Road* (channels; lower dantian). `zz_arcana_zbody.js` **[Act I]**

- **Minor Arcana (pegs):** small passives laid along the roads, a peg every 1.25 units of path (150 pegs, 16 notables, 25 key sockets and 5 roots across the five bodies). Values per peg: life +1%, Essence +1%, resource regen +2%, armour +2, poise +2, poise recovery +3%, shard +1, skill damage +1%, melee +1%, cast speed +1%, wisp +2% regen, resist +1%, magic find +2%, move +0.5%, life on kill +1, bleed +2%, sickness +2%, evasion +0.5%, sun/moon +1.5%, attributes +1. Notables give about +4–6% or two small things, with a lore line. `zz_arcana_web.js` `zz_arcana_zbody.js` **[Act I]**

- **Two currencies:** a **Minor point** each level from 2 plus quest gifts (`webGrantPoints`); a **Major point** ("Arcana") from bosses, Heralds, hidden shrines and quests. The header reads "Major n · Minor n". `zz_arcana_web.js` **[Act I]**

- **Reachability:** roads start at the order's seat (gate) and at every Major held. Clicking a Minor lays the cheapest road to it (hover previews the road and cost). A Major can be laid next to a laid Minor or an anchor. `zz_arcana_web.js` **[Act I]**

- **Lifting:** right-click lifts a leaf peg for 10 + 5×level gold. A peg holding up a Major cannot be lifted. The Hollow Token reset returns everything. `zz_arcana_web.js` **[Act I]**

- **Major Arcana** (tarot cards; each order has 36, the Empty Hand 32): each changes how one skill works, set **upright or reversed**. Flip for free at any lantern. Pages of Majors flower past each tree's keystone (the hands, the crown or the fan); hybrids (a borrowed god's card) sit near the feet. The **Void** (two hollow steps, then four void cards) sits at the seat and opens after ten Majors (`VOID_GATE`). The card list per order is in `ARC` (`k_arcana.js`, `zz_arcana_monk.js`), for example the Ossuarch's Pyre-Dead, Bowyer, Grave-Chanter, Oathbound, Tower, Cage-Warden, Grasping Earth, Rime, Reliquary and Maelstrom. `k_arcana.js` `zz_arcana_zbody.js` `zz_arcana_monk.js` **[Act I]**

- **Card kinds:** major (upright or reversed), minor card (one rule, for example Caltrops or Spike Echo), hybrid, hollow (Hollow Step: dodge rolls leave an afterimage that staggers within 3 yd for 0.5 s; Unheard: wake range ×0.7), void (the Unwritten, the Crown, the Last Silence, the Unmade). `k_arcana.js` **[Act I]**

- **Per-order crowns (v0.54):** the Ossuarch's Hollow Crown (minions can't die above half life, each drains 0.5% life/s; reversed: potions don't heal, minions within 4 yd mend 1%/s). The Crown of the Brood (the same for the brood). The Choir Crown (a wisp spent or lost returns in 3 s, each drains 0.3%/s; reversed: each wisp mends 0.3%/s). The Paper Crown (Omens never fade, each drains 0.5%/s; reversed: each mends 0.6%/s). The Crown of Nothing (neither bulb fills past four fifths, each bulb over half drains 0.5%/s; reversed: both under a quarter, mend 1.5%/s). `zz_arcana_percls.js` **[later]**

- **The Unwritten** refills each order's own resource on kills (5%), or runs 5% of the sand back for the Empty Hand; reversed: an enemy that can't see you for 2 s loses you. **The Unmade:** one Major counts upright and reversed at once, or +1 all skills per Major held (max 4), −25% max life. **The Last Silence:** once per zone a killing blow stops time for 3 s and leaves you at 1 life; reversed: your skills make no light (notice range halved). `k_arcana.js` `zz_arcana_percls.js` **[later]**

- **Rules:** Majors never give +skill levels (except the Unmade's reversal, flagged in 0b) and never add waits. `wiki/01` **[Act I]**

- **Controls:** drag to pan, wheel or +/− to zoom, 0 home; Whole, Mine and Sums buttons; the reader column shows the card text and the turn and unmake buttons. `zz_arcana_zbody.js` **[Act I]**

- **Save:** `P.arc.web = {taken, pts, bonus}`. Pegs saved on the old shared web are refunded on load. `zz_arcana_web.js` **[Act I]**

- **Arcana sources in Act I:** the Carrion Warden and the Matron (+2 Arcana each, plus skill points and a Hollow Token); the Barrow lord (+1); the Fen guardians (+1 with +5 attribute points); one hidden Arcana shrine per zone, as far as possible from its lantern (+1 once); Heralds (+1 Major each, at most 4 per act); quests. `k_arcana.js` `zd_world22.js` `zz_quests.js` **[Act I]**

## 11. The Reading (character creation) and the title

- **The Reading:** character creation plays in front of the Mysterious Stranger (the user's Midjourney animation, 121 frames at 25 fps, a lossless WebP). He idles still and gestures only now and then; his text box stays up. `zz_art_reading.js` `zz_art_rd0_stranger.js` **[Act I]**

- **Eight choices, four tarot cards a side** (ink on old paper, no colour):
  1. **the god**, which sets the order: Oss-Vharoth → Ossuarch; Nol-Shogthuth → Hemomancer; Yh'Anuul → Hollow Mystic; the Myriad → Shrine Keeper; Ur-Nihl → the Empty Hand;
  2. **its face** (three per god, each +1 to one tree plus a small ±);
  3. **a drawn card**, upright or reversed (17 cards);
  4. **a fear** (11);
  5. **a seeking** (11);
  6. **the road that brought you** (8);
  7. **a spoken answer** (one of five questions, three answers each);
  8. **a sacrifice** (12).

Bone throwing is removed. `q_fate.js` `qa_fate22.js` `zz_fate_tune.js` `zz_art_reading.js` **[Act I]**
- **Reading effects:** every percent ±1% at most; attributes ±2, armour and poise ±4, life per kill ±1. Totals are capped per stat (`FATE_CAP`: attributes 2, poise 8, armour 6, magic find 6, life% 5, damage 4, cast rate 5, gold 8, resist 5, move 4, experience 4, regen 6, life on kill 1). Stats: con, vit, spi, stam, lok, armor, mf, hpPct, dmg, fcr, gold, res, frw, xp, regen, and skt (+tree). `zz_fate_zcap.js` `qa_fate22.js` **[Act I]**
- **Enter/Space** advances and **Escape** skips the Reading. `d_play.js` **[Act I]**
- **Title screen:** the dead god weeps into the Seer's bowl (a painted chapel). GODMARROW is cut in stepped bronze and an eye blinks. The menu words float on the blood and are brighter and larger with no dark box (v95). Items: Continue (level n), New Pilgrim, Trial of Thirty, Full screen, Controls, The Codex. Hidden HTML buttons keep keyboard, controller and screen-reader support. `zp_title.js` `zz_title54.js` `a_head.html` **[Act I]**
- **Trial of Thirty** (test character): level 30, 30 skill points, 145 attribute points, every waystone kindled, kept in its own save slot. `d_play.js` `zz_mech_balance.js` `zz_quests.js` **[later]**
- **Title music** plays (since v97). `zz_zz_music96.js` **[Act I]**

## 12. Saving, loading and options

- **Save slot:** browser localStorage `spiritmancer.save.v2` (the test character `spiritmancer.test`). Saved: order, level, xp, attributes, points, hard skill points, keys, left and right skills, orders for golem, wisps, squads and brood, mutations, grafts, gold, inventory, equipment, belt, Arcana, Reading choices, finished one-shot rewards (`P.done`), Hollow Tokens, quests and waystones (`d.qst`), voice lines seen, auto-attack skill. **Not saved:** the map (every start rolls a new seed and new zones), monster state, ground items. Old saves are migrated (refunds when trees changed). `d_play.js` `zz_quests.js` `zz_voice.js` `zz_ux_touch54.js` **[Act I]**

- **When it saves:** entering a zone, touching a lantern, finishing a quest, from the pause menu, on page hide (tab switch, phone background; the Android wrapper calls `__androidPause`), and on quit to title. `d_play.js` `zz_ux_save_hidden.js` **[Act I]**

- **Continue** loads the save into a freshly rolled world and starts at the Ashen Moor camp. `e_ui.js` **[Act I]**

- **Shared stash storage:** `triune.stash.v1` (48 items, shared by every character on the machine). `zz_quests.js` **[Act I]**

- **Pause menu (Esc):** Resume, Save game, Controls, Full screen, Options, Sound on/off, Music on/off, Save and quit to title. Options: damage numbers (off), hit flash (off), screen shake (on), auto-attack, hold to charge heavy attacks (on). Stored in `triune.opts`. `a_head.html` `b_core.js` `zz_mech_heavy.js` **[Act I]**

- **Error reporting** to the screen (`reportError`), and every wrapper is guarded so one fault does not stop the game. `e_ui.js` **[later]**

## 13. Items

- **Bases** (`BASES`), each with slot, grid size, damage or armour range, item level and optional order lock:

- Weapons: Bone Wand 2–5 (a ranged bolt, 6.5 yd), Ritual Knife 3–7 (L3), Grave Staff 5–10 (L6); Vharn Claws 3–6 and Raven Talons 6–11 (L6; Shrine Keeper only); Fist Wraps 3–6, Sutra-Bound Wraps 6–11 (L8), Gravedigger's Spade 5–11 (L4) and Ringed Staff 6–12 (L6) (the Empty Hand only).

- Off-hand: Skull Relic (armour 2–5).

- Armour: Mourning Hood 3–6, Bone Mask 7–11 (L5), Ash Robe 6–12, Grave Mail 15–24 (L6), Wrappings 1–3, Grave Boots 2–4, Cord Belt 1–3.

- Jewellery: Amulet (L3), Ring (L2).

Bases drop at item level + 1 or lower. `c_game.js` `zw_monk.js` **[Act I]**
- **Equipment slots (10):** head, neck, weapon, body, off-hand, hands, ring ×2, waist, feet. Equipping needs the item's required level (the highest affix level). `c_game.js` **[Act I]**
- **Rarities:** normal (grey), magic (blue `#8b95ff`), rare (gold `#f1e05a`), unique (tan `#c9a45a`). There are no sets, sockets, gems, runes or charms. `c_game.js` `zz_mech_loot.js` **[Act I]**
- **Quality roll** (`rollItem`, final after its wrappers). Base thresholds: unique 1.2%, rare 7.5%, magic 36% (cumulative), all ×(1 + magic find/100). Then half of magic and rare drops are downgraded to normal, and a rare or unique is re-rolled into something lesser 30% of the time. Measured at item level 10, no magic find: 82.6% normal, 14.3% magic, 2.3% rare, 0.9% unique; at +100% magic find: 65% / 29% / 4.4% / 1.7%. `c_game.js` `zz_tune_batch_c.js` `zz_tune_batch_e.js` **[Act I]**
- **Affixes** (`AFFIX`): prefixes and suffixes gated by item level and slot. Prefixes: life, Essence, skill damage % (rare only, capped at 15), armour, +max wisps (rare only), +1 tree skills (Adept, Scholarly, Hierophantic), +1 all skills (Exalted, rare only), lantern radius (Bright or Blazing). Suffixes: Constitution, Vitality, Essence, faster movement (feet only), faster cast rate, wisp regrowth, magic resist, magic find, life on kill, fire, cold, miasma and magic weapon damage, and the five lantern wicks. **Magic items carry 2 affixes, rares 6** (filled to that density). Rare names are prefix word + slot word (for example "Grim Whisper"). `c_game.js` `zz_mech_resists.js` `zz_pace_and_density.js` `zz_zw_lantern63.js` **[Act I]**
- **Uniques (6 named):** Lanternkeeper's Hood (+20 life, +1 wisp, +10% resist), The Hollow Choir amulet, Warden's Ribcage mail (+40 armour, +30 life, −5% move), Whisperbone wand (+12% damage, +20% cast rate, +1 wisp), Grave-Walkers boots (+25% move), Knot of Sorrows ring. Uniques get ×1.3 base armour and one lore line in the tooltip. `c_game.js` `zz_voice.js` **[Act I]**
- **Item tooltips:** name in rarity colour, base name (rare and unique), damage or armour, required level (red if too high), affix lines, a lore line for rares and uniques, and the sell value at a vendor. `c_game.js` `zz_voice.js` **[Act I]**
- **Drop rates** (measured per 100 kills). Normal monster: 7.9 items (6.4 normal, 1.3 magic, 0.1 rare, 0.1 unique), 10.6 gold piles, 4.7 potions; 84% of kills drop nothing. Minion: 5.1 items. Champion: 193 items, at least one magic guaranteed. Unique: 451 items, a rare guaranteed. Boss: 8 items, 2 rares guaranteed, +200 magic find. The rank gate: normal 22%, minion 18%, champion 70%, unique 90%, boss and chest 100%. `zz_pace_and_density.js` `zz_mech_loot.js` **[Act I]**
- **Chests:** two 60% item rolls plus one 25% roll, gold 85%, potion 25%. A chest that rolled nothing still gives a few coins half the time. Measured: 1.47 items, 0.86 gold piles, 0.26 potions per chest; 0.5% empty. Loot spills 1–1.8 tiles out in front of the chest (toward the camera), fanned. `zz_zz_chest91.js` **[Act I]**
- **Gold piles:** chance per rank (normal 45%, minion 40%, champion 95%, unique and boss 100%, chest 85%); amount = random 2–6 (normal) up to 10–20 (boss) × item level × rank multiplier (champion 2.5, unique 5, boss 14, chest 1.5). Gold is **picked up by walking over it** (0.9 yd); +25% with the wick dimmed. `zz_mech_loot.js` `d_play.js` **[Act I]**
- **Drop sounds by rarity:** a dull fall (normal or potion), a glassy tick (magic), two clear notes (rare), a deep bell (unique or set). Gold makes no sound when it drops. `zz_zz_study82.js` **[Act I]**
- **Ground items:** loot scatters 0.3–1.6 yd from the corpse (never into a wall). **Alt** (or LOOT on touch) shows name labels. Items in your pool glint. Clicking an item walks to it and picks it up. `c_game.js` `zz_zz_cine76.js` **[Act I]**
- **Item level:** a monster's level (+1 for uniques); a chest's zone level; quest rewards max(level, act top) + 2. `d_play.js` `zz_quests.js` **[Act I]**
- **Weapon art:** hands stay free; weapons will be separate layers (later). The Ossuarch shows each skill's bone weapon. `wiki/01` `zz_ossu_active_melee.js` **[later]**
- **Armour tiers** (front and back paired by file name in the `ARMOR_x` folders): parked. `wiki/09` **[later]**

## 14. Inventory, belt, potions, stash, vendors and gold

- **Inventory:** a 10×4 grid; items are 1×1 to 2×3. Right-click equips or drinks (at a vendor, sells). Drag with the cursor; dropping outside places it on the ground. Auto-placement finds the first free spot. `c_game.js` `e_ui.js` `zz_ui.js` **[Act I]**

- **Belt:** 4 slots, each stacking 4 of one potion kind. Keys 1–4 drink, and the slot refills from the inventory. Potions picked up go to the belt first. `c_game.js` **[Act I]**

- **Potions:** Healing Draught (40% of max life over time, at most 30% of max per second) and Essence Draught (50% of max resource, at most 40% per second). 55% of potion drops are healing. The Hollow and Brood crowns reversed stop potions healing. `c_game.js` `d_play.js` `k_arcana.js` **[Act I]**

- **Vendor** (Maren in Act I; one per town): sells both draughts at 30 gold and buys items. Sell value: normal 5, magic 25, rare 70, unique 160, + 4 per item level; a potion 8. `e_ui.js` `c_game.js` **[Act I]**

- **Smith (wares):** 7 items (no uniques) at item level max(hero level, act minimum + 2) with +60 magic find. Price = sell value × 5 + level × 6. Restocked when the hero levels. `zz_quests.js` **[Act I]**

- **Healer:** restores life, resource and poise, and cures poison and burn, with a spoken line. `zz_quests.js` **[Act I]**

- **The Reliquary Chest (stash):** 48 items, in every town, shared by every character on the machine (a separate stash for the test character). `zz_quests.js` **[Act I]**

- **Gambling and crafting:** none in the web build. The rules forbid currency-as-crafting; gold buys potions and the smith's wares, and lifts Minor Arcana. `wiki/01` **[later]**

- **Gold on death:** all carried gold is left in a remnant where you fell; walk back to take it (and the lantern's kept light, section 7). `d_play.js` `zz_zz_study82.js` **[Act I]**

## 15. Monsters

### 15.1 Levels, scaling and ranks

- **Stat scaling** (`makeMon`, final): life = base × (1 + 0.35×(mlvl−1)) × 1.6 × ease; damage = base × (1 + 0.2×(mlvl−1)) × 1.35 × ease. Ease = 0.5 at mlvl ≤5, rising to 1.0 at 10, then to 1.2 at 25+. XP = base × (1 + 0.3×(mlvl−1)) × the level knot (section 3). Measured Husk: 16 life at mlvl 1, 133 at 10, 278 at 20, 428 at 30, 563 at 40. `c_game.js` `zz_mech_balance.js` `zz_progression.js` **[Act I]**

- **Zone level bumps:** crypt +3, barrow +3, fen +4, cata1 +3, cata2 +2 (the Matron at 18). Runtime spawns in those zones are capped near the zone's top. Act I spans mlvl 1–17 (Matron 18). `zz_mech_balance.js` `zz_progression.js` **[Act I]**

- **Ranks:** champion ×2.5 life, ×1.4 damage, ×3 XP, ×1.1 speed. Unique ×4 life, ×1.7 damage, ×5 XP, a generated name (for example "Grimmaw the Hungry"), with minions (×1.3 life). One or two modifiers: Extra Fast (×1.4 speed), Extra Strong (×1.5 damage), Stone Skin (+80 armour). Per pack: unique 4% and champion 6% at mlvl ≤3, else 8% and 12%. `c_game.js` `b_core.js` **[Act I]**

- **The hour changes creatures outdoors** (a day is 600 s: day 55%, dusk 11%, night 24%, dawn 10%). Dusk ×1.12 speed for everything, night ×1.05, dawn ×0.95; per-kind damage multipliers by hour (listed per creature). Gasps, Mire Gasps and Moth-Saints only walk in their hours and lie hidden otherwise. `zv_time24.js` `zd_world22.js` **[Act I]**

### 15.2 Behaviour layers (all creatures)

- **Packs:** chosen from tables by zone and level (`PACKS_LOW/MID/HIGH/CRYPT/FEN/BONE`, later act tables). Size scales with strength (weak kinds up to ×1.6, strong down to ×0.5, then −25%…+30%), then ×0.85 (15% smaller). About 45% extra normal kin are added beside members, then about 40% more packs are copied onto open ground (at least 14 tiles from the start, 8 from others). `b_core.js` `zz_tune_v58.js` `zz_zv60.js` `zz_tune_batch_e.js` **[Act I]**

- **Wanderers:** each open zone adds 4–18 singles and pairs (about one per 1,400 tiles), at least 9 tiles from others and away from entrances, lanterns and camps. `zz_zz_world89.js` **[Act I]**

- **Loitering:** a sleeping pack drifts about its spot (0.5–2.6 yd hops every 1.2–3 s). `zz_mobai63.js` **[Act I]**

- **Waking:** wake range 7.5 yd with line of sight (×0.7 up to level 3, ×0.85 up to level 8; ×0.7 with the wick dimmed or Unheard; ×0.5 with the Last Silence reversed). Packmates within 10 yd wake one by one after 0.35–1.6 s plus 0.08 s per yard. `k_arcana.js` `zz_mobai63.js` **[Act I]**

- **Attack tokens:** only min(7, round((3 + ⌊level/5⌋) × 1.2)) melee creatures press the attack at once (4 at level 1), or half of those within 5 yd if more. The rest circle in a loose ring and feint. A creature that just struck gives up its turn half the time (0.8–1.8 s). `zz_mobai63.js` **[Act I]**

- **D2-imp skittishness** (falls as the kind's XP worth rises; bosses 0; bolder in v76 and v79): weaving approach with hesitations, strike and hop back, a short scatter when a packmate dies nearby, rare flight when badly hurt. In a crowd of 3+ skittishness drops (5+: ×0.3). `zz_zz_imps67.js` **[Act I]**

- **Standard melee rhythm:** chase → wind-up (the kind's `wind`) → strike (a hit within 0.8 yd of the aim point) → recover (`rec`) → 0.3 s gap. Any stun cancels a wind-up. `zc_combat22.js` **[Act I]**

- **Tells, never flashes:** every creature has a pose or sound tell and a counter (the world bible's table); champions and uniques show a small grit tell under melee wind-ups. `zc_combat22.js` `zz_zz_boss83.js` **[Act I]**

- **Targets:** the nearest of the hero, the golem, echoes, skeletons, the Colossus, the brood, oozes, the Flesh Golem and decoys (a taunt forces the golem). `d_play.js` **[Act I]**

- **Corpses:** the slain topple from their last pose and lie darkened, bleeding into the floor or scattering bone, until raised, hatched, eaten or faded. `za_death21.js` **[Act I]**

### 15.3 Act I bestiary

- **Husk** (`hollow`): a pilgrim who drank from the wound. Waits for company: with 2+ awake packmates within 4.5 yd it surges (×1.35 speed) and charge-lunges (0.38 s wind, 6.5 yd/s, ×1.2 hit) from 1.3–2.6 yd; alone it shambles (×0.78) but lunges if you turn your back. Tell: head snaps up, arms spread. Counter: pull a few, fight in a doorway. base hp 20, dmg 3–7, speed 1.9 yd/s, xp 12, AI `husk`, wind-up 0.5 s, poise ×0.5. Hours: night ×1.25, dusk ×1.35. Zones: moor, crypt, barrow, cata1, cata2, sighing_ridge, ash_shore, burnt_heath, fern_gully, pilgrim_road, fallen_monastery, wolf_den_chapel … `zc_combat22.js` **[Act I]**

- **Tithe-Hand** (`hound`): a severed hand on its fingers. Circles at 2.7 yd, darts in from behind (or when you are busy, or holds an attack token), 1.7× lunge in the wind-up; the last one flees at half life. Back to a wall and they can only circle. Tell: fingers tense. Counter: back to a wall. base hp 13, dmg 2–5, speed 3.4 yd/s, xp 11, AI `flank`, wind-up 0.26 s, poise ×0.4. Hours: dusk ×1.5, night ×1.2, day ×0.9. Zones: moor, barrow, sighing_ridge, ash_shore, fern_gully, pilgrim_road, wolf_den_chapel, smugglers_hold, tree_hollow, hunter_cache, broken_bridge, hollow_wood … `zc_combat22.js` **[Act I]**

- **Weeper** (`archer`): faceless mourner; kites (backs off inside 4.2 yd, closes past 6.5), shoots bone-needle arrows (8.5 yd/s, physical) from under 8 yd with line of sight, ducks behind cover half the time. Tell: tilts head back. Counter: break line of sight, corner it. base hp 15, dmg 3–6, speed 1.8 yd/s, xp 15, AI `kiter`, wind-up 0.75 s, poise ×0.4. Hours: dawn ×1.5, day ×1.05. Zones: moor, fen, barrow, sighing_ridge, ash_shore, burnt_heath, fern_gully, pilgrim_road, drowned_village, sunken_bog, fallen_monastery, wolf_den_chapel … `zc_combat22.js` **[Act I]**

- **Gasp** (`caster`): a stray scrap of breath. Drifts through walls, keeps 4.5–5 yd off, fires a slow magic orb (4.6 yd/s). Recoils from any light within 5 yd and takes ×1.5 while lit. Walks only at dusk, night and dawn (hidden by day). Tell: inhales, veil billows. Counter: fight near lanterns and fire. base hp 17, dmg 5–9, speed 1.5 yd/s, xp 20, AI `ghost`, wind-up 0.9 s, poise ×0.3. Hours: walks only dusk/night/dawn, night ×1.3, dusk ×1.4. Zones: moor, crypt, pilgrim_road, fallen_monastery, plague_hospice, smugglers_hold, tree_hollow, fallen_watchtower, broken_bridge, hollow_wood, root_deep. `zc_combat22.js` `zv_time24.js` **[Act I]**

- **Gravebloat** (`bloat`): a walking stomach. Shuffles close (1.2 yd), winds up and bursts for its damage as magic in 1.9 yd (hurts your minions too), dying. Tell: swells, gurgles. Counter: range, or let it burst in a crowd. base hp 28, dmg 10–16, speed 1.4 yd/s, xp 18, AI `bomber`, wind-up 0.8 s, poise ×0.8. Hours: dusk ×1.2. Zones: moor, crypt, fen, cata1, cata2, drowned_village, sunken_bog, fallen_monastery, plague_hospice, well_shaft, bogwitch_shack, root_deep. `d_play.js` **[Act I]**

- **Ossuary Warden** (`knight`): bone knight with a skull tower-shield; blocks 85% from the front unless recovering or reeling. Armour 30. Tell: shield lowers. Counter: flank, or break its poise. base hp 44, dmg 7–12, speed 1.7 yd/s, xp 30, armour 30, AI `shield`, wind-up 0.6 s, poise ×0.9. Hours: dawn ×1.35, day ×1.1. Zones: crypt, cata1, fallen_monastery, plague_hospice. `zc_combat22.js` **[Act I]**

- **Pyre-Saint** (`pyre`): a burning martyr. Walks straight at you leaving burning footprints (fires every 0.45 s), erupts at 1.35 yd (1.8 yd blast ×1.6 magic plus a ring of fires) and dies; also erupts weaker (55%) when killed. Wading through shallows douses it for good (×0.7 speed, ×0.45 damage). Emissive (always visible). Tell: flames roar white. Counter: douse in water, or range. base hp 26, dmg 6–10, speed 1.55 yd/s, xp 22, AI `pyre`, wind-up 0.9 s, poise ×0.6. Hours: day ×1.25, dusk ×1.1, night ×0.8, dawn ×1.4. Zones: moor, fen, barrow, burnt_heath, fern_gully, drowned_village, sunken_bog, wolf_den_chapel, plague_hospice, well_shaft, bogwitch_shack, fallen_watchtower … `zc_combat22.js` **[Act I]**

- **Bellwether** (`bell`): a hulk with its head sealed in a bell. At 2.8–9 yd with a clear line it tolls twice (0.9 s) then charges at 8.5 yd/s: ×1.6 damage, empties your poise and throws you; a wall stops it dead, dazed 2.2 s. Armour 20. Tell: two tolls. Counter: stand before a wall, sidestep. base hp 70, dmg 9–15, speed 1.3 yd/s, xp 45, armour 20, AI `charger`, wind-up 0.7 s, poise ×1.1. Hours: dusk ×1.45, dawn ×1.45. Zones: moor, fen, drowned_village, sunken_bog, well_shaft, broken_bridge, a4_bellhollow, root_deep. `zc_combat22.js` **[Act I]**

- **Vein-Worm** (`worm`): a severed artery. Burrows (untargetable, no damage) under soft ground, bursts up under you after 0.75 s (×1.4 in 0.95 yd), lashes, and dives again after 2.8 s. Cannot dig through stone: on roads and flagstones it circles at 3 yd. Tell: soil ripples (no surfacing marker since v0.55). Counter: stand on stone or roads. base hp 22, dmg 4–8, speed 3 yd/s, xp 18, AI `burrow`, wind-up 0.35 s, poise ×0.5. Hours: night ×1.25. Zones: moor, barrow, sighing_ridge, ash_shore, burnt_heath, fern_gully, pilgrim_road, wolf_den_chapel, smugglers_hold, fallen_watchtower, hollow_wood. `zc_combat22.js` **[Act I]**

- **Moth-Saint** (`moth`): a porcelain face on a moth's body. Hovers in a 4.2 yd circle out of reach (takes 35% high up), drawn to light, folds its wings (0.45 s) and swoops through you in an arc (takes 130% low). Walks only at dusk and night. Tell: wings fold back. Counter: strike during the swoop. base hp 14, dmg 4–7, speed 2.6 yd/s, xp 17, AI `flyer`, wind-up 0.45 s, poise ×0.3. Hours: walks only dusk/night, dusk ×1.5, night ×1.2. Zones: moor, fen, barrow, sighing_ridge, ash_shore, burnt_heath, fern_gully, drowned_village, sunken_bog, wolf_den_chapel, smugglers_hold, bogwitch_shack … `zc_combat22.js` **[Act I]**

- **The Carrion Warden** (`boss`): Act I zone boss of the Hollow Crypt (quest a1_warden). Boss chassis: slam (0.9 s wind, 2.1 yd, ×1.3 magic) and charge (0.7 s wind, 10 yd/s); at half life calls 4 dead (Warden and Husk) and speeds up ×1.25. base hp 300, dmg 14–22, speed 2.1 yd/s, xp 900, AI `boss`. Zones: crypt. `d_play.js` **[Act I]**

- **Drowned Husk** (`drowned`): fen Husk (same surge AI), tougher. base hp 26, dmg 4–8, speed 1.7 yd/s, xp 16, AI `husk`, wind-up 0.55 s, poise ×0.5. Hours: night ×1.3, dusk ×1.3. Zones: fen, drowned_village, sunken_bog, well_shaft, bogwitch_shack, a3_flats. `c_game.js` **[Act I]**

- **Mire Vein-Worm** (`leech`): fen burrower (same AI). base hp 24, dmg 4–8, speed 3.2 yd/s, xp 18, AI `burrow`, wind-up 0.35 s, poise ×0.5. Hours: night ×1.25, dusk ×1.2. Zones: fen, drowned_village, sunken_bog, well_shaft, a3_delta, a3_sumps. `c_game.js` **[Act I]**

- **Mire Gasp** (`bogwitch`): fen Gasp (ghost AI; walks dusk to dawn). base hp 20, dmg 6–10, speed 1.5 yd/s, xp 22, AI `ghost`, wind-up 0.8 s, poise ×0.3. Hours: walks only dusk/night/dawn, night ×1.3, dusk ×1.4. Zones: fen, cata1, cata2, drowned_village, sunken_bog, a3_amber. `c_game.js` **[Act I]**

- **Marrow Duelist** (`marrow`): skeleton fencer; after 3 light hits in 1.2 s it parries (0.7 s) and ripostes ×1.5 and 60% of your poise; heavy blows (over 14% of its life) break through. Armour 30. Tell: blade tip rises. Counter: slow heavy hits, spells. base hp 50, dmg 8–14, speed 2.2 yd/s, xp 34, armour 30, AI `duelist`, wind-up 0.45 s, poise ×0.7. Hours: dawn ×1.4, day ×1.1. Zones: cata1, cata2, a2_chapter, a2_marrow, a4_monastery, a5_highway, a5_siphon. `zc_combat22.js` **[Act I]**

- **Ossuary Weeper** (`ossarcher`): bone-white Weeper (kiter). base hp 18, dmg 4–8, speed 1.9 yd/s, xp 18, AI `kiter`, wind-up 0.65 s, poise ×0.4. Hours: dawn ×1.5. Zones: cata1, cata2, a2_dunes, a2_avenue, a2_chapter, a2_ribvalley, a2_banners. `c_game.js` **[Act I]**

- **The Ossuary Matron** (`matron`): Act I boss in Bone Catacombs II (quest a1_matron). Boss chassis; at half life summons Marrow Duelists and Ossuary Weepers; her death opens the way to Act II. base hp 420, dmg 18–28, speed 2.2 yd/s, xp 2400, AI `boss`. Zones: cata2. `d_play.js` `zz_quests.js` **[Act I]**

- **Kneeler** (`kneeler`): a pilgrim still on its knees, on kneeling-boards, a candle on its skull. Husk AI but slow (1.05 yd/s), long wind-up (0.75 s) and recovery (1.2 s), high poise (1.0). Tell: rears back, scourge up behind the flame. Counter: hit it while it rears, or step past. base hp 30, dmg 5–10, speed 1.05 yd/s, xp 19, AI `husk`, wind-up 0.75 s, poise ×1. Zones: moor, crypt, sighing_ridge, ash_shore, fallen_monastery, plague_hospice. `zz_mon_kneeler.js` **[Act I]**

- **Moth-Saint of the Canopy** (`moth_saint`): taller Moth-Saint that dives out of the canopy (flyer). base hp 20, dmg 5–9, speed 2.8 yd/s, xp 28, AI `flyer`, wind-up 0.5 s, poise ×0.35. Zones: moor, fen, barrow, burnt_heath, fern_gully, pilgrim_road, drowned_village, wolf_den_chapel, well_shaft, smugglers_hold, tree_hollow, fallen_watchtower … `zz_monsters_new.js` **[Act I]**

- **Elder Vein-Worm** (`veinworm_elder`): larger burrower that surfaces deeper. base hp 44, dmg 7–12, speed 3.2 yd/s, xp 60, AI `burrow`, wind-up 0.4 s, poise ×0.7. Zones: moor, root_deep. `zz_monsters_new.js` **[Act I]**

- **Stalker Crone** (`stalker_crone`): stalker AI: skulks in your rear cone and springs in a straight dash for a heavy strike when your front turns away; seen, she circles wide. base hp 22, dmg 6–10, speed 2.6 yd/s, xp 34, AI `stalker`, wind-up 0.3 s, poise ×0.45. Zones: barrow, fern_gully, pilgrim_road, wolf_den_chapel, smugglers_hold. `zz_monsters_new.js` **[Act I]**

- **The Trunk-Thing** (`trunk_thing`): a face grown into a great trunk; near-stationary (0.35 yd/s) shield-AI lash-tank, 1.8 yd reach, armour 60. base hp 180, dmg 12–20, speed 0.35 yd/s, xp 220, armour 60, AI `shield`, wind-up 0.7 s, poise ×1. Zones: moor, root_deep. `zz_monsters_new.js` **[Act I]**

- **Chorister** (`chorister`): singing Gasp; its dirge slows the hero's walk nearby. base hp 26, dmg 7–11, speed 1.4 yd/s, xp 46, AI `ghost`, wind-up 1.05 s, poise ×0.35. Zones: crypt, fallen_monastery, plague_hospice, a4_breathcaves. `zz_monsters_new.js` **[Act I]**

- **Bloatling** (`bloatling`): small, quick Gravebloat with a light fuse (0.55 s). base hp 14, dmg 7–11, speed 2.2 yd/s, xp 12, AI `bomber`, wind-up 0.55 s, poise ×0.5. Zones: moor, fen, barrow, sighing_ridge, burnt_heath, drowned_village, sunken_bog, wolf_den_chapel, well_shaft, smugglers_hold, hunter_cache, fallen_watchtower … `zz_monsters_new.js` **[Act I]**

### 15.4 The Heralds (god altars)

- **God altars:** at most 4 Heralds per act (`ACT_MAJORS`), one per god per playthrough. An altar appears in a zone with a 40% chance outdoors or 25% in dungeons, preferably in a ruined chapel, at least 25 tiles from the start. Its glow shows the speaker's name (Old Upright, the Red Mother, the Last Breath, the Hush), never the true name. Touching it wakes the Herald: unique rank at the zone's highest level, 45% life, a 1.2 s rise. It enrages ×1.3 below half life. Killing it grants a Major Arcanum. `zd_world22.js` **[Act I]**

- **The Marrow Pontiff** (`hbone`): Herald of Bone (altar speaker Old Upright): walls you in with a ring of 7 bone walls (5 s) every 7 s; at half life calls 3 Wardens once; shield AI; enrages ×1.3 below half. base hp 260, dmg 12–20, speed 1.7 yd/s, xp 700, armour 40, AI `herald`, wind-up 0.7 s, poise ×1.2. `zd_world22.js` **[Act I]**

- **The Wet Nurse** (`hflesh`): Herald of Flesh (the Red Mother): births 2 Husks every 6 s (max 6), spews a 5-orb bile fan at 2–6 yd every 3.5 s. base hp 320, dmg 10–17, speed 1.1 yd/s, xp 700, AI `herald`, wind-up 0.8 s, poise ×1.4. `zd_world22.js` **[Act I]**

- **The Long Exhale** (`hbreath`): Herald of Breath (the Last Breath): drifts like a Gasp; every 5 s within 6 yd breathes you away (with damage) or pulls you in. base hp 200, dmg 12–19, speed 1.9 yd/s, xp 700, AI `herald`, wind-up 0.8 s, poise ×0.8. `zd_world22.js` **[Act I]**

- **A Silent One** (`hhollow`): Herald of the Silence (the Hush): no light near it; steps out of the dark behind you every 4.5 s. base hp 230, dmg 14–22, speed 2.3 yd/s, xp 700, AI `herald`, wind-up 0.5 s, poise ×0.9. `zd_world22.js` **[Act I]**

### 15.5 Acts II–V bestiary

- **Calcified Knight** (`calc_knight`): shield AI, armour 45. base hp 58, dmg 8–14, speed 1.5 yd/s, xp 44, armour 45, AI `shield`, wind-up 0.65 s, poise ×1. Zones: a2_dunes, a2_avenue, a2_chapter, a2_ribvalley, a2_tomb, a2_banners, a2_marrow, a2_lair. `zz_act2.js` **[later]**

- **Oath-Fused Blade** (`oath_blade`): duelist AI (parry and riposte). base hp 46, dmg 9–15, speed 2.1 yd/s, xp 40, armour 30, AI `duelist`, wind-up 0.42 s, poise ×0.75. Zones: a2_avenue, a2_chapter, a2_ribvalley, a2_banners, a2_oasis, a2_marrow, a2_lair. `zz_act2.js` **[later]**

- **Marrow-Ghoul** (`marrow_ghoul`): charger AI (tolls and charges), armour 20. base hp 84, dmg 10–17, speed 1.8 yd/s, xp 58, armour 20, AI `charger`, wind-up 0.7 s, poise ×1.1. Zones: a2_dunes, a2_ribvalley, a2_stormflat, a2_tomb, a2_banners, a2_oasis, a2_marrow, a2_lair. `zz_act2.js` **[later]**

- **Chalk-Wyrm** (`chalk_worm`): burrower; swims in the tomb's sand drifts. base hp 34, dmg 6–11, speed 3.1 yd/s, xp 30, AI `burrow`, wind-up 0.35 s, poise ×0.55. Zones: a2_dunes, a2_avenue, a2_ribvalley, a2_stormflat, a2_tomb, a2_oasis. `zz_act2.js` **[later]**

- **Chalk Wraith** (`chalk_wraith`): ghost AI; rides the chalk storm (+45% speed, nearly unseen). base hp 26, dmg 7–12, speed 1.6 yd/s, xp 32, AI `ghost`, wind-up 0.85 s, poise ×0.3. Zones: a2_avenue, a2_chapter, a2_stormflat, a2_tomb, a2_banners, a2_oasis, a2_marrow. `zz_act2.js` **[later]**

- **Grit-Moth** (`dune_kite`): kiter AI. base hp 20, dmg 5–9, speed 2 yd/s, xp 26, AI `kiter`, wind-up 0.6 s, poise ×0.35. Zones: a2_dunes, a2_avenue, a2_ribvalley, a2_stormflat, a2_oasis. `zz_act2.js` **[later]**

- **Brood-Swollen Husk** (`a3_broodhusk`): husk AI; bursts into 3 Leech-Larvae on death. base hp 34, dmg 5–9, speed 1.6 yd/s, xp 22, AI `husk`, wind-up 0.55 s, poise ×0.6. Zones: a3_flats, a3_mangroves, a3_fetish, a3_delta, a3_amber, a3_broodbanks, a3_causeway, a3_sumps, a3_egggal, a3_ziggurat, a3_lair. `zz_act3.js` **[later]**

- **Leech-Larva** (`a3_larva`): tiny flanker (7 hp), no loot. base hp 7, dmg 2–4, speed 3.6 yd/s, xp 3, AI `flank`, wind-up 0.22 s, poise ×0.2. `zz_act3.js` **[later]**

- **Masked Fetish-Priest** (`a3_fetishpriest`): flanker; its blows leave venom for 3 s. base hp 22, dmg 5–8, speed 3.3 yd/s, xp 24, AI `flank`, wind-up 0.28 s, poise ×0.4. Zones: a3_flats, a3_mangroves, a3_fetish, a3_delta, a3_broodbanks, a3_causeway, a3_egggal, a3_ziggurat. `zz_act3.js` **[later]**

- **Mud-Leaper** (`a3_mudleaper`): burrower. base hp 30, dmg 6–11, speed 3.2 yd/s, xp 26, AI `burrow`, wind-up 0.35 s, poise ×0.5. Zones: a3_flats, a3_mangroves, a3_delta, a3_amber, a3_broodbanks, a3_causeway, a3_sumps. `zz_act3.js` **[later]**

- **Mangrove Stalker** (`a3_mangrovestalker`): stalker AI (springs when you turn away). base hp 30, dmg 7–12, speed 2.7 yd/s, xp 32, AI `stalker`, wind-up 0.3 s, poise ×0.45. Zones: a3_mangroves, a3_fetish, a3_amber, a3_causeway, a3_ziggurat. `zz_act3.js` **[later]**

- **Amber-Weeping Gasp** (`a3_amberwitch`): ghost AI. base hp 24, dmg 7–11, speed 1.5 yd/s, xp 28, AI `ghost`, wind-up 0.85 s, poise ×0.3. Zones: a3_mangroves, a3_fetish, a3_delta, a3_amber, a3_causeway, a3_sumps, a3_egggal, a3_ziggurat, a3_lair. `zz_act3.js` **[later]**

- **Brood-Sow** (`a3_broodsow`): charger AI, armour 20. base hp 80, dmg 10–16, speed 1.3 yd/s, xp 52, armour 20, AI `charger`, wind-up 0.7 s, poise ×1.1. Zones: a3_broodbanks, a3_causeway, a3_egggal, a3_ziggurat. `zz_act3.js` **[later]**

- **Anima-Bound Monk** (`a4_animamonk`): duelist AI, armour 30. base hp 52, dmg 8–14, speed 2.3 yd/s, xp 38, armour 30, AI `duelist`, wind-up 0.42 s, poise ×0.75. Zones: a4_foothills, a4_glasspass, a4_flags, a4_spires, a4_cloudshelf, a4_windscour, a4_stair, a4_bellhollow, a4_monastery, a4_lair. `zz_act4.js` **[later]**

- **Chime-Golem** (`a4_chimegolem`): charger; stands dormant until struck, brushed or something dies near it; armour 45. base hp 90, dmg 12–18, speed 1.35 yd/s, xp 60, armour 45, AI `charger`, wind-up 0.75 s, poise ×1.2. Zones: a4_flags, a4_spires, a4_cloudshelf, a4_windscour, a4_stair, a4_bellhollow, a4_monastery, a4_lair. `zz_act4.js` **[later]**

- **Rime-Wraith** (`a4_rimewraith`): ghost AI. base hp 24, dmg 7–12, speed 1.6 yd/s, xp 30, AI `ghost`, wind-up 0.85 s, poise ×0.3. Zones: a4_foothills, a4_glasspass, a4_spires, a4_cloudshelf, a4_windscour, a4_stair, a4_breathcaves, a4_bellhollow, a4_monastery. `zz_act4.js` **[later]**

- **Prayer-Flag Moth** (`a4_flagmoth`): flyer AI. base hp 18, dmg 5–9, speed 2.9 yd/s, xp 22, AI `flyer`, wind-up 0.42 s, poise ×0.3. Zones: a4_foothills, a4_glasspass, a4_flags, a4_spires, a4_cloudshelf, a4_windscour, a4_stair. `zz_act4.js` **[later]**

- **Tethered Pilgrim** (`a4_tetherpilgrim`): flanker AI. base hp 26, dmg 5–9, speed 3.3 yd/s, xp 24, AI `flank`, wind-up 0.26 s, poise ×0.4. Zones: a4_foothills, a4_glasspass, a4_flags, a4_spires, a4_windscour, a4_stair, a4_breathcaves. `zz_act4.js` **[later]**

- **Basalt Borer** (`a4_basaltborer`): burrower. base hp 36, dmg 8–13, speed 3.1 yd/s, xp 34, AI `burrow`, wind-up 0.35 s, poise ×0.6. Zones: a4_foothills, a4_glasspass, a4_spires, a4_cloudshelf, a4_windscour, a4_breathcaves. `zz_act4.js` **[later]**

- **Marrow-Sapper** (`a5_sapper`): husk AI; blows bleed (10%/s of the hit for 3 s). base hp 34, dmg 7–12, speed 2 yd/s, xp 40, AI `husk`, wind-up 0.5 s, poise ×0.55. Zones: a5_highway, a5_siphon, a5_skerries, a5_valves. `zz_act5.js` **[later]**

- **Osteo-Golem** (`a5_osteo`): charger, armour 45. base hp 96, dmg 10–17, speed 1.35 yd/s, xp 90, armour 45, AI `charger`, wind-up 0.7 s, poise ×1.25. Zones: a5_highway, a5_siphon. `zz_act5.js` **[later]**

- **Rib-Cage Bulwark** (`a5_ribward`): shield AI, armour 40. base hp 70, dmg 8–13, speed 1.5 yd/s, xp 70, armour 40, AI `shield`, wind-up 0.6 s, poise ×1. Zones: a5_highway, a5_siphon. `zz_act5.js` **[later]**

- **Hemorrhagic Leaper** (`a5_leaper`): flanker; heavy bleed (22%). base hp 26, dmg 6–11, speed 3.6 yd/s, xp 42, AI `flank`, wind-up 0.24 s, poise ×0.4. Zones: a5_skerries, a5_valves, a5_shaft. `zz_act5.js` **[later]**

- **Tumor-Swell Monstrosity** (`a5_tumor`): bomber, armour 70; bursts into burning bile pools. base hp 80, dmg 14–22, speed 1.1 yd/s, xp 70, armour 70, AI `bomber`, wind-up 1 s, poise ×1.2. Zones: a5_skerries, a5_valves, a5_crucible. `zz_act5.js` **[later]**

- **Neural Wraith** (`a5_wraith`): ghost; its orbs daze (1.4 s). base hp 30, dmg 8–13, speed 1.6 yd/s, xp 52, AI `ghost`, wind-up 0.85 s, poise ×0.3. Zones: a5_shaft, a5_cerebrum, a5_lair. `zz_act5.js` **[later]**

- **Synapse-Walker** (`a5_synapse`): stalker; blows daze. base hp 34, dmg 9–15, speed 2.8 yd/s, xp 55, AI `stalker`, wind-up 0.3 s, poise ×0.45. Zones: a5_shaft, a5_cerebrum. `zz_act5.js` **[later]**

- **Stomach-Parasite Worm** (`a5_parasite`): burrower; leaves acid pools where it surfaces. base hp 40, dmg 8–13, speed 3 yd/s, xp 50, AI `burrow`, wind-up 0.4 s, poise ×0.6. Zones: a5_crucible. `zz_act5.js` **[later]**

- **Corrosion-Stalker** (`a5_corroder`): duelist; corrosion (physical hurts more for 4 s). base hp 60, dmg 10–16, speed 2.1 yd/s, xp 62, armour 35, AI `duelist`, wind-up 0.45 s, poise ×0.8. Zones: a5_crucible. `zz_act5.js` **[later]**

- **Thought-Form** (`a5_thought`): kiter; mind shots. base hp 28, dmg 8–13, speed 1.9 yd/s, xp 54, AI `kiter`, wind-up 0.7 s, poise ×0.35. Zones: a5_cerebrum, a5_lair. `zz_act5.js` **[later]**

- **Alien Sentinel** (`a5_sentinel`): ghost AI with a beam, armour 50. base hp 44, dmg 10–15, speed 1.3 yd/s, xp 66, armour 50, AI `ghost`, wind-up 1.1 s, poise ×0.9. Zones: a5_cerebrum, a5_lair. `zz_act5.js` **[later]**

- **Null-Shade** (`a5_nullshade`): stalker; darkens light (m.dark); void-cut hollows 4% of your life per hit (max 25%). base hp 36, dmg 9–15, speed 2.9 yd/s, xp 60, AI `stalker`, wind-up 0.28 s, poise ×0.45. Zones: a5_scar, a5_monolith. `zz_act5.js` **[later]**

- **Silence-Keeper** (`a5_silence`): shield AI, armour 45; hush drains Essence nearby. base hp 84, dmg 10–16, speed 1.4 yd/s, xp 80, armour 45, AI `shield`, wind-up 0.65 s, poise ×1. Zones: a5_scar, a5_monolith. `zz_act5.js` **[later]**

- **Calcified Knight** (`qa_calcknight`): Calcified Knight (Saint Calcifer's add). base hp 60, dmg 9–14, speed 1.6 yd/s, xp 60, armour 40, AI `shield`, wind-up 0.6 s, poise ×0.9. `zz_quests.js` **[later]**

- **Brood-Leech** (`qa_broodling`): Brood-Leech (Brood-Mother's add). base hp 24, dmg 7–11, speed 3 yd/s, xp 20, AI `burrow`, wind-up 0.4 s, poise ×0.5. `zz_quests.js` **[later]**

- **Chime-Golem of the Upper Bell** (`qa_chimegolem`): Chime-Golem of the Upper Bell (Chime-Abbot's champion adds). base hp 150, dmg 13–21, speed 1.3 yd/s, xp 200, armour 80, AI `shield`, wind-up 0.8 s, poise ×1.2. `zz_quests.js` **[later]**

- **Thought-Form** (`qa_thoughtform`): Thought-Form (the Slayer's split). base hp 40, dmg 10–16, speed 1.8 yd/s, xp 50, AI `ghost`, wind-up 1 s, poise ×0.35. `zz_quests.js` **[later]**

## 16. Bosses

- **No sealed rooms (v75):** the fight starts when you come near (Act I rooms: stepping inside the boss room; lairs: within 8.5 yd of the boss spot). You can run, kite and leave. A boss left behind (34 tiles in Act I rooms, 26 in lairs) goes home and waits **without healing** (v83; the old code healed 20%/s). `zz_zz_perf74.js` `zz_zz_boss83.js` `zz_quests.js` **[Act I]**

- **Boss telegraphs:** during a slam wind-up, dust and grit lift in the 2.1-tile circle, thickening from the centre, ringed by broken grit, with cracks near the end. A charge scores its lane. Drawn above the dark, bone-grey, never red, no glow. `zz_zz_boss83.js` **[Act I]**

- **Slam aftermath:** the ground stays cracked for 2.5 s and standing in it drains 14 poise/s (no damage). `zz_zz_boss83.js` **[Act I]**

- **Boss chassis (Act I):** chase; slam at under 2.5 yd (0.9 s wind, ×1.3 magic in 2.1 yd); charge at 2.5–8 yd (0.7 s wind, 10 yd/s for 0.6 s); recover 0.9 s. At half life it calls 4 of its dead and moves ×1.25 faster. `d_play.js` **[Act I]**

- **The Carrion Warden** (Hollow Crypt; base life 300, measured 2,390 at mlvl 12): the zone boss; its kill gives +1 skill point, +1 Hollow Token, +2 Arcana and completes quest a1_warden. `c_game.js` `k_arcana.js` `zz_quests.js` **[Act I]**

- **The Ossuary Matron** (Bone Catacombs II; base 420, measured 5,168 at mlvl 18): the act boss; summons Marrow Duelists and Ossuary Weepers at half life; drops +2 skill points, +1 Hollow Token, +2 Arcana; opens the gate to Act II's town. `c_game.js` `zz_quests.js` **[Act I]**

- **Lair bosses (Acts II–V)** use HP-threshold stages, adds and arena hazards (telegraphed circles, expanding rings, beams, lingering pools):

- **Saint Calcifer** (Act II, base 480, level 26, scale ×2.1). Reliquary lances (5 circles on you every 6.5 s, 5 s later). At 70% his knights rise (4 adds). At 40% +40 armour. At 15% the femur-standard: expanding rings every 5.5 s.

- **The Brood-Mother** (Act III, base 520, level 31, ×2.6). Bile fans of 5 (7 frenzied) poison orbs. At 75% eggs (5 broodlings). At 45% the basin floods (blood pools). At 20% frenzy ×1.3 speed and more adds. She holds her ground when you are close.

- **The Chime-Abbot** (Act IV, base 430, level 36, ×2.2). Keeps 4–7.5 yd away, tolls rings of cold orbs (8, then 12), blinks away when you close. At 66% two champion Chime-Golems. At 33% the harmony breaks: expanding cold rings.

- **The Thought of the Slayer** (Act V, base 560, level 42, ×2.3). Void beams in a fan (3, then 5). At 60% it splits into 4 Thought-Forms and blinks. At 30% the temple inverts: falling circles, blinks every 6 s. Its death plays the Stranger's line and the credits, then opens the Scar.

`zz_quests.js` **[later]**
- **Boss banners** (name in the header; "FELLED" on death), the stagger meter under the life bar, and the lantern guttering when a boss wakes. `d_play.js` `zz_zz_boss83.js` `zz_zz_cine76.js` **[Act I]**
- **The Hollow King** (zombie cow king for the dead herd): parked, and its file is excluded from the build. `zz_zz_king68.js` (excluded) **[later]**

## 17. Difficulty

- **Normal only is live.** The scaffolding holds Nightmare (monster life ×1.5, damage ×1.5, resist −40) and Hell (×2.5, ×2, −100), applied through `hurtMon` and `hurtPlayer`, plus death XP loss of 5% and 10%. There is no selection UI (`window.__setDifficulty`). `zz_mech_balance.js` `k_arcana.js` **[later]**

- **The opening is gentler:** the ease curve (section 15.1), smaller early packs (×0.65 at mlvl ≤3), shorter wake range and 4 attack tokens at low level. `c_game.js` `b_core.js` `zz_mobai63.js` **[Act I]**

## 18. The world

### 18.1 Structure, generation and openness

- **Five acts plus a side region:** I the Hide (mlvl 1–17, 25 zones, town = Maren's camp on the Moor, lair `cata2`); II the Bleached Barrens of Ossa (18–24, town `a2_town`); III the Parasitic Fen of Shog-Mire (24–30, `a3_town`); IV the Frigid Heights of An-Vhar (30–34, `a4_town`); V the Descent (34–40, `a5_town`); side: the Scar of Ur-Nihl and the Silent Monolith (36–40). Zone ids are `aN_*`, the town `aN_town` and the lair `aN_lair`. `zz_quests.js` `zz_act2.js` `zz_act3.js` `zz_act4.js` `zz_act5.js` **[Act I]**

- **Random per start:** every zone is generated from `G.seed` when first entered (`ZONE_GEN[id](seed)`). Towns and quest vaults are laid by hand. `d_play.js` **[Act I]**

- **Open outdoor builder** (`OPENNESS.buildOpen`): noise groves that clear into meadows, wide curving roads (radius and verge), irregular rims of cliff, per-layout masks (crossroads plain, crest line, coastal L, ring road, gully, S-curve road, flooded grid, bog islands, hilltop tor, river crossing), pocket stitching (every sealed pocket joined or filled), spaced packs. Trees are generated at target density (`__treesHalved`). `zz_openness.js` `zz_act1_expand.js` **[Act I]**

- **Wide dungeons** (`wideDungeon`): about 1.32× the old size, rooms at least 11×11 (13–21 in later acts), a great hall, corridors 5–7 wide, no closets. Boss arenas are at least 16×16 and never sealed. `zz_openness.js` **[Act I]**

- **Channels (v89):** 2–4 loose tree lines or broken colonnades per open zone, sometimes paired into lanes. They always have gaps and are never on roads or near exits, lanterns, shrines or camps. `zz_zz_world89.js` **[Act I]**

- **Connectivity audit:** every portal, lantern and object must be reachable; the narrowest point on a route is at least 5 tiles; landmarks may not lower reachability. `zz_openness.js` `zz_landmarks55.js` **[Act I]**

- **Terrain:** shallows at water's edge (×0.72 speed, douse Pyre-Saints), mud in the fen (×0.8), flagstone roads (stone: burrowers can't cross, and the Empty Hand's Step-That-Wakes-Bedrock hits ×2). Water blocks. Flyers and ghosts ignore terrain. `zc_combat22.js` `zd_world22.js` **[Act I]**

- **Ruins:** roofless chapels (flagstone floor, doorways for chokepoints), colonnades that break line of sight, toppled three-faced Triune statues (cover), lone arches (a doorway to nowhere). `zd_world22.js` **[Act I]**

- **Landmarks:** one-of-a-kind ruins and statues of forgotten gods, a few per zone, never repeated in a zone, placed on open ground away from the start and lanterns. Each blocks its footprint. Walking near one surfaces its name and inscription; candles on them are real lights. `zz_landmarks55.js` **[Act I]**

- **The Hide showing through (Act I):** about one organic piece per 2,500 tiles in outdoor zones (a rib from the turf, a vein breaching soil, skin with pores and hairs, a pool that looks back like an eye), never near the entry. `zz_zz_decor66.js` **[Act I]**

- **The dead herd:** on the Burnt Heath, in the corner farthest from the road, seven horned carcasses lie in a ring facing the same way, with skull heaps; one line on first visit. `zz_zz_decor66.js` **[Act I]**

- **Pilgrims' camps** (a tent and a banked fire, the only warm light) in about half the open zones; **wayside saint and angel statues** by roads; **gibbet cages** at the edges. `zz_zz_decor66.js` **[Act I]**

- **Ground scatter** (non-solid, per land): leaf litter, twigs, moss, mushrooms and ferns in the wood; ash, stones, bone chips, black glass and straw on the moor; reeds, wet stones and puddles in the fen; charcoal and bone on the heath. It leans with the wind. Canopy dapple in the woods. `zz_zz_world77.js` **[Act I]**

- **Props that never block:** graves, cairns, gibbets on the moor; reeds, stumps and glowing fungus in the fen; coffins, skull piles, candles and braziers underground (braziers and candles are lights). `z_props21.js` `zz_world_props.js` **[Act I]**

### 18.2 Act I zones (measured at seed 12345)

- **Ashen Moor** (`moor`, 164x164, theme moor): mlvl 2–6; about 538 creatures at generation (mostly Husk, Tithe-Hand, Moth-Saint, Weeper, Gasp, Gravebloat); 2 lanterns, 1 vendor, 7 chests, 2 shrine refill, 1 shrine echo, 2 shrine stone, 2 statues; links to crypt, fen, barrow, sighing_ridge, hollow_wood. The start: Maren's camp (palisade; vendor Maren, then the quest NPCs, stash and waystone), a radial crossroads plain. The dead herd lies on the Burnt Heath, not here. `b_core.js` `zz_openness.js` **[Act I]**

- **Hollow Crypt** (`crypt`, 109x109, theme crypt): mlvl 9–12; about 85 creatures at generation (mostly Husk, Gravebloat, Ossuary Warden, Chorister, Gasp, Kneeler); 1 lantern, 2 chest; links to moor, fallen_monastery, hollow_wood. Rooms and halls; the Carrion Warden's boss room. `b_core.js` `zz_openness.js` **[Act I]**

- **Drowned Fen** (`fen`, 160x160, theme fen): mlvl 10–15; about 490 creatures at generation (mostly Drowned Husk, Moth-Saint, Bloatling, Mire Vein-Worm, Weeper, Gravebloat); 2 lanterns, 6 chests, 1 shrine wisp, 2 shrine stone, 1 shrine refill, 2 statues; links to moor, cata1, drowned_village, root_deep, pilgrim_road. Braided delta; shallows and mud; two guardian packs at treasure sites (+5 attribute points, +1 Arcana when both fall); the Well-Shrine lore site. `b_core.js` `zz_openness.js` **[Act I]**

- **Old Barrow** (`barrow`, 87x87, theme barrow): mlvl 7–10; about 96 creatures at generation (mostly Husk, Moth-Saint, Tithe-Hand, Weeper, Vein-Worm, Bloatling); 1 lantern, 4 chest; links to moor, fallen_watchtower. The Barrow lord pack (+1 skill point, +1 Arcana when cleared). `b_core.js` `zz_openness.js` **[Act I]**

- **Bone Catacombs I** (`cata1`, 117x117, theme bone): mlvl 14–16; about 148 creatures at generation (mostly Ossuary Weeper, Husk, Marrow Duelist, Gravebloat, Ossuary Warden, Mire Gasp); 1 lantern, 4 chests, 1 altar; links to fen, cata2, plague_hospice, root_deep. The Reader's Bay (quest relic). `b_core.js` `zz_openness.js` **[Act I]**

- **Bone Catacombs II** (`cata2`, 113x113, theme bone): mlvl 15–18; about 112 creatures at generation (mostly Marrow Duelist, Gravebloat, Ossuary Weeper, Husk, Mire Gasp); 1 lantern, 1 chest; links to cata1, smugglers_hold. Act I lair: the Ossuary Matron; her death opens the road to Act II. `b_core.js` `zz_openness.js` **[Act I]**

- **Sighing Ridge** (`sighing_ridge`, 172x124, theme moor): mlvl 2–4; about 72 creatures at generation (mostly Husk, Tithe-Hand, Moth-Saint, Kneeler, Bloatling, Weeper); 4 lanterns, 5 chests, 2 shrine echo, 1 shrine refill, 3 statues, 1 altar; links to moor, burnt_heath, wolf_den_chapel. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Ash Shore** (`ash_shore`, 152x152, theme moor): mlvl 3–5; about 97 creatures at generation (mostly Husk, Tithe-Hand, Kneeler, Weeper, Vein-Worm, Moth-Saint); 4 lanterns, 5 chests, 1 shrine stone, 2 shrine refill, 3 statues, 1 altar; links to burnt_heath. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Burnt Heath** (`burnt_heath`, 152x152, theme moor): mlvl 4–6; about 117 creatures at generation (mostly Husk, Weeper, Moth-Saint, Bloatling, Moth-Saint of the Canopy, Vein-Worm); 4 lanterns, 5 chests, 1 shrine wisp, 2 shrine echo, 3 statues, 1 altar; links to sighing_ridge, ash_shore, fern_gully. The dead herd (cow-level homage): seven horned carcasses in a ring in the far corner, one line on first visit. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Fern Gully** (`fern_gully`, 132x172, theme hollow_wood): mlvl 3–6; about 85 creatures at generation (mostly Weeper, Vein-Worm, Tithe-Hand, Husk, Moth-Saint, Pyre-Saint); 4 lanterns, 3 chests, 1 shrine wisp, 2 shrine echo; links to burnt_heath, hunter_cache. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Pilgrim Road** (`pilgrim_road`, 184x128, theme moor): mlvl 6–8; about 148 creatures at generation (mostly Husk, Weeper, Tithe-Hand, Stalker Crone, Gasp, Moth-Saint of the Canopy); 5 lanterns, 5 chests, 1 shrine stone, 1 shrine echo, 1 shrine wisp, 2 statues; links to hollow_wood, fen, tree_hollow. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Drowned Village** (`drowned_village`, 152x144, theme fen): mlvl 6–9; about 156 creatures at generation (mostly Drowned Husk, Moth-Saint, Moth-Saint of the Canopy, Gravebloat, Weeper, Bellwether); 5 lanterns, 5 chests, 1 shrine echo, 1 shrine refill, 1 shrine wisp, 2 statues; links to fen, sunken_bog, well_shaft. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Sunken Bog** (`sunken_bog`, 164x152, theme fen): mlvl 9–11; about 139 creatures at generation (mostly Drowned Husk, Mire Vein-Worm, Pyre-Saint, Bloatling, Mire Gasp, Moth-Saint); 5 lanterns, 5 chests, 1 shrine refill, 2 shrine echo, 1 statue; links to drowned_village, bogwitch_shack. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Fallen Monastery** (`fallen_monastery`, 120x120, theme crypt): mlvl 7–9; about 163 creatures at generation (mostly Husk, Chorister, Ossuary Warden, Gasp, Gravebloat, Kneeler); 3 lanterns, 4 chests, 1 altar; links to crypt, bogwitch_shack. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Wolf-Den Chapel** (`wolf_den_chapel`, 104x104, theme crypt): mlvl 4–8; about 103 creatures at generation (mostly Husk, Tithe-Hand, Moth-Saint, Weeper, Moth-Saint of the Canopy, Bloatling); 3 lanterns, 4 chest; links to sighing_ridge. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Plague Hospice** (`plague_hospice`, 120x120, theme crypt): mlvl 9–12; about 118 creatures at generation (mostly Husk, Ossuary Warden, Weeper, Chorister, Gasp, Gravebloat); 3 lanterns, 4 chest; links to cata1. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **The Well-Shaft** (`well_shaft`, 105x105, theme crypt): mlvl 10–13; about 110 creatures at generation (mostly Drowned Husk, Bloatling, Bellwether, Mire Vein-Worm, Moth-Saint of the Canopy, Pyre-Saint); 3 lanterns, 3 chest; links to drowned_village. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Smugglers' Hold** (`smugglers_hold`, 107x107, theme barrow): mlvl 5–9; about 113 creatures at generation (mostly Tithe-Hand, Husk, Bloatling, Vein-Worm, Moth-Saint, Gasp); 3 lanterns, 4 chest; links to cata2. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Bog-Witch's Shack** (`bogwitch_shack`, 104x104, theme fen): mlvl 7–10; about 53 creatures at generation (mostly Drowned Husk, Pyre-Saint, Moth-Saint, Gravebloat, Weeper); 1 lantern, 3 chests, 1 shrine stone, 1 statue, 1 altar; links to sunken_bog, fallen_monastery. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **The Tree-Hollow** (`tree_hollow`, 104x104, theme hollow_wood): mlvl 6–7; about 54 creatures at generation (mostly Husk, Gasp, Tithe-Hand, Weeper, Moth-Saint, Moth-Saint of the Canopy); 1 lantern, 2 chests, 1 shrine echo; links to pilgrim_road. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Hunter's Cache** (`hunter_cache`, 104x104, theme moor): mlvl 4–5; about 76 creatures at generation (mostly Husk, Tithe-Hand, Bloatling, Weeper); 1 lantern, 4 chests, 1 shrine stone, 1 statue; links to fern_gully. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Fallen Watchtower** (`fallen_watchtower`, 124x124, theme moor): mlvl 6–9; about 94 creatures at generation (mostly Husk, Weeper, Moth-Saint of the Canopy, Moth-Saint, Bloatling, Vein-Worm); 2 lanterns, 5 chests, 1 shrine refill, 1 shrine echo, 5 statues, 1 altar; links to barrow. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **The Broken Bridge** (`broken_bridge`, 152x132, theme moor): mlvl 10–13; about 92 creatures at generation (mostly Tithe-Hand, Moth-Saint of the Canopy, Husk, Pyre-Saint, Bellwether, Gasp); 2 lanterns, 5 chests, 1 shrine stone, 1 shrine wisp, 3 statues, 1 altar; links to root_deep. `zz_act1_expand.js` `zz_openness.js` **[Act I]**

- **Hollow Wood** (`hollow_wood`, 152x152, theme hollow_wood): mlvl 5–8; about 204 creatures at generation (mostly Husk, Vein-Worm, Tithe-Hand, Bloatling, Weeper, Moth-Saint of the Canopy); 2 lanterns, 4 chests, 3 shrine wisp, 1 altar; links to moor, crypt, pilgrim_road. `zz_world_expand.js` `zz_openness.js` **[Act I]**

- **Root Deep** (`root_deep`, 164x164, theme root_deep): mlvl 13–16; about 253 creatures at generation (mostly Husk, Tithe-Hand, Weeper, Gravebloat, Moth-Saint of the Canopy, Pyre-Saint); 3 lanterns, 6 chests, 1 shrine echo, 1 shrine wisp, 1 shrine stone; links to fen, cata1, broken_bridge. `zz_world_expand.js` `zz_openness.js` **[Act I]**

### 18.3 Acts II–V zones

- **Citadel of the Shattered Femur** (`a2_town`, 124x96, theme ossa_town town): no monsters; about 0 creatures at generation; 1 lantern; links to a2_dunes. `zz_act2.js` **[later]**

- **The Bleached Dunes** (`a2_dunes`, 170x150, theme ossa): mlvl 18–19; about 152 creatures at generation (mostly Chalk-Wyrm, Grit-Moth, Marrow-Ghoul, Calcified Knight, Ossuary Weeper); 4 lanterns, 4 chests, 2 shrine refill, 1 shrine wisp, 1 altar; links to a2_town, a2_avenue. `zz_act2.js` **[later]**

- **Reliquary Avenue** (`a2_avenue`, 180x120, theme ossa): mlvl 19–20; about 157 creatures at generation (mostly Grit-Moth, Calcified Knight, Ossuary Weeper, Oath-Fused Blade, Chalk Wraith, Chalk-Wyrm); 3 lanterns, 4 chests, 2 shrine wisp, 1 shrine stone; links to a2_dunes, a2_ribvalley, a2_chapter. `zz_act2.js` **[later]**

- **The Buried Chapter-House** (`a2_chapter`, 104x104, theme ossa_chapter): mlvl 19–21; about 78 creatures at generation (mostly Calcified Knight, Chalk Wraith, Marrow Duelist, Ossuary Weeper, Oath-Fused Blade); 2 lanterns, 3 chest; links to a2_avenue. `zz_act2.js` **[later]**

- **The Valley of Standing Ribs** (`a2_ribvalley`, 170x160, theme ossa): mlvl 20–21; about 137 creatures at generation (mostly Chalk-Wyrm, Grit-Moth, Ossuary Weeper, Marrow-Ghoul, Calcified Knight, Oath-Fused Blade); 3 lanterns, 4 chests, 3 shrine stone; links to a2_avenue, a2_stormflat. `zz_act2.js` **[later]**

- **The Chalk Flats** (`a2_stormflat`, 180x170, theme ossa): mlvl 21–22; about 126 creatures at generation (mostly Chalk Wraith, Grit-Moth, Chalk-Wyrm, Marrow-Ghoul); 4 lanterns, 4 chests, 2 shrine refill, 1 shrine wisp; links to a2_ribvalley, a2_banners, a2_tomb. Chalk storms (about every minute, 20 breaths): the lamp shrinks, arrows drift, Chalk Wraiths speed up. `zz_act2.js` **[later]**

- **The Sand-Choked Tomb** (`a2_tomb`, 100x100, theme ossa_tomb): mlvl 21–23; about 44 creatures at generation (mostly Chalk Wraith, Calcified Knight, Chalk-Wyrm, Marrow-Ghoul); 2 lanterns, 3 chests, 1 altar; links to a2_stormflat. `zz_act2.js` **[later]**

- **The Field of Fallen Standards** (`a2_banners`, 170x150, theme ossa): mlvl 22–23; about 179 creatures at generation (mostly Ossuary Weeper, Calcified Knight, Oath-Fused Blade, Marrow-Ghoul, Chalk Wraith); 3 lanterns, 4 chests, 1 shrine echo, 2 shrine refill, 1 altar; links to a2_stormflat, a2_oasis. `zz_act2.js` **[later]**

- **The Dry Oasis** (`a2_oasis`, 160x160, theme ossa): mlvl 22–23; about 140 creatures at generation (mostly Chalk-Wyrm, Grit-Moth, Oath-Fused Blade, Chalk Wraith, Marrow-Ghoul); 3 lanterns, 4 chests, 1 shrine refill, 1 shrine stone, 1 shrine wisp, 1 altar; links to a2_banners, a2_marrow. `zz_act2.js` **[later]**

- **The Marrow Cavity** (`a2_marrow`, 112x112, theme ossa_marrow): mlvl 23–24; about 58 creatures at generation (mostly Chalk Wraith, Marrow-Ghoul, Marrow Duelist, Calcified Knight, Oath-Fused Blade); 2 lanterns, 1 chest, 1 altar; links to a2_oasis, a2_lair. `zz_act2.js` **[later]**

- **The Empty Socket** (`a2_lair`, 140x140, theme ossa): mlvl 23–24; about 29 creatures at generation (mostly Oath-Fused Blade, Calcified Knight, Marrow-Ghoul); 1 lantern, 2 chests, 1 shrine stone, 1 shrine wisp; links to a2_marrow. Act II lair: Saint Calcifer. `zz_act2.js` **[later]**

- **Kettlewick Stilts** (`a3_town`, 84x84, theme shogmire town): no monsters; about 0 creatures at generation; 1 lantern; links to a3_flats. `zz_act3.js` **[later]**

- **The Heartbeat Flats** (`a3_flats`, 160x150, theme shogmire): mlvl 24–25; about 255 creatures at generation (mostly Brood-Swollen Husk, Drowned Husk, Bloatling, Mud-Leaper, Masked Fetish-Priest); 3 lanterns, 1 statue, 7 chests, 2 shrine refill, 1 shrine wisp; links to a3_town, a3_mangroves. Heartbeat mud: every 1.7 s the mud clutches, slowing walkers a further 40% for the beat. `zz_act3.js` **[later]**

- **The Weeping Mangroves** (`a3_mangroves`, 150x150, theme shogmire): mlvl 25–26; about 154 creatures at generation (mostly Brood-Swollen Husk, Moth-Saint of the Canopy, Amber-Weeping Gasp, Masked Fetish-Priest, Mud-Leaper, Mangrove Stalker); 3 lanterns, 1 statue, 6 chests, 2 shrine wisp, 1 shrine refill; links to a3_flats, a3_delta, a3_fetish. `zz_act3.js` **[later]**

- **The Fetish-Tree Groves** (`a3_fetish`, 140x140, theme shogmire): mlvl 26–27; about 143 creatures at generation (mostly Masked Fetish-Priest, Brood-Swollen Husk, Amber-Weeping Gasp, Mangrove Stalker); 3 lanterns, 5 chests, 2 shrine stone, 1 shrine refill; links to a3_mangroves, a3_sumps. `zz_act3.js` **[later]**

- **The Blood Delta** (`a3_delta`, 170x140, theme shogmire): mlvl 26–28; about 188 creatures at generation (mostly Brood-Swollen Husk, Mud-Leaper, Masked Fetish-Priest, Amber-Weeping Gasp, Mire Vein-Worm); 3 lanterns, 7 chests, 1 shrine stone, 1 shrine wisp, 1 shrine echo, 1 altar; links to a3_mangroves, a3_amber. `zz_act3.js` **[later]**

- **The Amber-Grease Mire** (`a3_amber`, 140x140, theme shogmire): mlvl 27–28; about 169 creatures at generation (mostly Brood-Swollen Husk, Mire Gasp, Amber-Weeping Gasp, Mud-Leaper, Mangrove Stalker); 3 lanterns, 6 chests, 2 shrine wisp, 1 shrine refill; links to a3_delta, a3_broodbanks. `zz_act3.js` **[later]**

- **The Brood-Banks** (`a3_broodbanks`, 150x130, theme shogmire): mlvl 28–29; about 201 creatures at generation (mostly Brood-Swollen Husk, Brood-Sow, Masked Fetish-Priest, Mud-Leaper); 3 lanterns, 6 chests, 2 shrine refill, 1 shrine echo; links to a3_amber, a3_egggal, a3_causeway. `zz_act3.js` **[later]**

- **Causeway of the First Brood** (`a3_causeway`, 150x150, theme shogmire): mlvl 29–30; about 162 creatures at generation (mostly Brood-Swollen Husk, Masked Fetish-Priest, Amber-Weeping Gasp, Mangrove Stalker, Brood-Sow, Mud-Leaper); 3 lanterns, 6 chests, 1 shrine echo, 2 shrine refill; links to a3_broodbanks, a3_ziggurat. `zz_act3.js` **[later]**

- **The Leech-Sumps** (`a3_sumps`, 110x110, theme shogmire_deep): mlvl 26–29; about 118 creatures at generation (mostly Brood-Swollen Husk, Mire Vein-Worm, Amber-Weeping Gasp, Mud-Leaper); 2 lanterns, 5 chests, 1 altar; links to a3_fetish. `zz_act3.js` **[later]**

- **The Egg-Galleries** (`a3_egggal`, 110x100, theme shogmire_deep): mlvl 28–30; about 94 creatures at generation (mostly Brood-Swollen Husk, Masked Fetish-Priest, Amber-Weeping Gasp, Brood-Sow); 2 lanterns, 4 chest; links to a3_broodbanks. `zz_act3.js` **[later]**

- **Ziggurat of the First Brood** (`a3_ziggurat`, 120x120, theme shogmire_deep): mlvl 29–30; about 140 creatures at generation (mostly Masked Fetish-Priest, Brood-Swollen Husk, Amber-Weeping Gasp, Mangrove Stalker, Brood-Sow); 3 lanterns, 3 chest; links to a3_causeway, a3_lair. `zz_act3.js` **[later]**

- **The Blood-Basin** (`a3_lair`, 96x96, theme shogmire): mlvl 30–30; about 11 creatures at generation (mostly Brood-Swollen Husk, Amber-Weeping Gasp); 1 lantern; links to a3_ziggurat. Act III lair: the Brood-Mother. `zz_act3.js` **[later]**

- **Bellrest Hearth** (`a4_town`, 86x80, theme anvhar town): no monsters; about 0 creatures at generation; 1 lantern; links to a4_foothills. `zz_act4.js` **[later]**

- **The Chime-Foothills** (`a4_foothills`, 160x150, theme anvhar): mlvl 30–31; about 177 creatures at generation (mostly Tethered Pilgrim, Prayer-Flag Moth, Anima-Bound Monk, Rime-Wraith, Basalt Borer); 3 lanterns, 7 chests, 2 shrine wisp, 1 shrine refill; links to a4_town, a4_glasspass. Chime-winds (all outdoor Act IV zones): every 10–16 s a 2.4 s gust drains poise, never below 35%; lanterns and Lantern-Spires shelter you. `zz_act4.js` **[later]**

- **The Glass Pass** (`a4_glasspass`, 150x150, theme anvhar): mlvl 30–31; about 120 creatures at generation (mostly Prayer-Flag Moth, Tethered Pilgrim, Basalt Borer, Rime-Wraith, Anima-Bound Monk); 2 lanterns, 6 chests, 1 shrine echo, 1 shrine stone, 1 shrine refill; links to a4_foothills, a4_breathcaves, a4_flags. `zz_act4.js` **[later]**

- **The Prayer-Flag Terraces** (`a4_flags`, 150x150, theme anvhar): mlvl 31–32; about 155 creatures at generation (mostly Tethered Pilgrim, Prayer-Flag Moth, Anima-Bound Monk, Chime-Golem); 3 lanterns, 1 statue, 7 chests, 1 shrine echo, 2 shrine stone, 1 altar; links to a4_glasspass, a4_spires. `zz_act4.js` **[later]**

- **Field of Lantern-Spires** (`a4_spires`, 160x160, theme anvhar): mlvl 31–32; about 181 creatures at generation (mostly Prayer-Flag Moth, Chime-Golem, Tethered Pilgrim, Basalt Borer, Rime-Wraith, Anima-Bound Monk); 3 lanterns, 1 statue, 8 chests, 1 shrine wisp, 2 shrine refill; links to a4_flags, a4_cloudshelf. `zz_act4.js` **[later]**

- **The Cloud-Shelf** (`a4_cloudshelf`, 170x150, theme anvhar): mlvl 32–33; about 157 creatures at generation (mostly Prayer-Flag Moth, Rime-Wraith, Chime-Golem, Anima-Bound Monk, Basalt Borer); 3 lanterns, 1 statue, 6 chests, 1 shrine echo, 2 shrine refill; links to a4_spires, a4_bellhollow, a4_windscour. `zz_act4.js` **[later]**

- **The Wind-Scoured Ridges** (`a4_windscour`, 150x150, theme anvhar): mlvl 32–33; about 172 creatures at generation (mostly Tethered Pilgrim, Prayer-Flag Moth, Anima-Bound Monk, Basalt Borer, Rime-Wraith, Chime-Golem); 3 lanterns, 7 chests, 2 shrine refill, 1 shrine wisp; links to a4_cloudshelf, a4_stair. `zz_act4.js` **[later]**

- **Stair of the Sky-Climbers** (`a4_stair`, 140x160, theme anvhar): mlvl 33–34; about 224 creatures at generation (mostly Prayer-Flag Moth, Anima-Bound Monk, Tethered Pilgrim, Rime-Wraith, Chime-Golem); 4 lanterns, 8 chests, 1 shrine wisp, 1 shrine refill, 1 shrine stone; links to a4_windscour, a4_monastery. `zz_act4.js` **[later]**

- **The Breath-Caves** (`a4_breathcaves`, 110x110, theme anvhar_deep): mlvl 31–33; about 79 creatures at generation (mostly Tethered Pilgrim, Basalt Borer, Rime-Wraith, Chorister); 2 lanterns, 5 chests, 1 altar; links to a4_glasspass. `zz_act4.js` **[later]**

- **The Bell-Hollow** (`a4_bellhollow`, 110x110, theme anvhar_deep): mlvl 32–34; about 72 creatures at generation (mostly Chime-Golem, Anima-Bound Monk, Rime-Wraith, Bellwether); 2 lanterns, 3 chest; links to a4_cloudshelf. `zz_act4.js` **[later]**

- **Sky-Climber's Monastery** (`a4_monastery`, 130x120, theme anvhar_deep): mlvl 33–34; about 110 creatures at generation (mostly Anima-Bound Monk, Rime-Wraith, Chime-Golem, Marrow Duelist); 3 lanterns, 4 chest; links to a4_stair, a4_lair. `zz_act4.js` **[later]**

- **Summit of the Unrung Bell** (`a4_lair`, 100x100, theme anvhar): mlvl 34–34; about 4 creatures at generation (mostly Anima-Bound Monk, Chime-Golem); 1 lantern; links to a4_monastery. Act IV lair: the Chime-Abbot. `zz_act4.js` **[later]**

- **The Last Vigil** (`a5_town`, 104x104, theme a5_town town): no monsters; about 0 creatures at generation; 1 lantern; links to a5_highway, a5_scar. `zz_act5.js` **[later]**

- **The Grand Calcified Highway** (`a5_highway`, 196x92, theme a5_marrow): mlvl 34–35; about 80 creatures at generation (mostly Marrow-Sapper, Rib-Cage Bulwark, Marrow Duelist, Osteo-Golem); 2 lanterns, 6 chests, 1 shrine wisp, 1 shrine echo, 1 shrine refill; links to a5_town, a5_siphon. `zz_act5.js` **[later]**

- **The Siphon Vaults** (`a5_siphon`, 144x144, theme a5_marrow): mlvl 35–36; about 104 creatures at generation (mostly Marrow-Sapper, Osteo-Golem, Marrow Duelist, Rib-Cage Bulwark); 2 lanterns, 6 chests, 1 shrine wisp, 1 shrine refill, 1 shrine echo; links to a5_highway, a5_skerries. `zz_act5.js` **[later]**

- **The Sanguine Cavity** (`a5_skerries`, 184x168, theme a5_sanguine): mlvl 36–37; about 117 creatures at generation (mostly Hemorrhagic Leaper, Tumor-Swell Monstrosity, Marrow-Sapper); 2 lanterns, 5 chests, 1 shrine echo, 1 shrine wisp, 1 shrine refill, 1 altar; links to a5_siphon, a5_valves. `zz_act5.js` **[later]**

- **The Valve Gates** (`a5_valves`, 132x132, theme a5_sanguine): mlvl 36–37; about 47 creatures at generation (mostly Hemorrhagic Leaper, Tumor-Swell Monstrosity, Marrow-Sapper); 2 lanterns, 5 chests, 1 shrine echo, 2 shrine wisp; links to a5_skerries, a5_shaft. `zz_act5.js` **[later]**

- **The Shaft of Fading Echoes** (`a5_shaft`, 164x164, theme a5_shaft): mlvl 37–38; about 76 creatures at generation (mostly Synapse-Walker, Hemorrhagic Leaper, Neural Wraith); 2 lanterns, 2 shrine echo, 5 chests, 1 shrine wisp, 1 altar; links to a5_valves, a5_crucible. Void spanned by 5-tile nerve-strand bridges (the void is solid). `zz_act5.js` **[later]**

- **The Digesting Crucible** (`a5_crucible`, 164x152, theme a5_crucible): mlvl 38–39; about 123 creatures at generation (mostly Stomach-Parasite Worm, Corrosion-Stalker, Tumor-Swell Monstrosity); 2 lanterns, 7 chests, 1 shrine stone, 1 shrine echo, 1 shrine wisp; links to a5_shaft, a5_cerebrum. Acid basins and bile shallows burn the feet. `zz_act5.js` **[later]**

- **The Cerebrum Labyrinth** (`a5_cerebrum`, 208x208, theme a5_cerebrum): mlvl 39–40; about 156 creatures at generation (mostly Alien Sentinel, Thought-Form, Synapse-Walker, Neural Wraith); 2 lanterns, 7 chests, 2 shrine wisp, 1 shrine echo; links to a5_crucible, a5_lair. A brain-coral labyrinth (wave-field walls, 7-tile doors, no maze pinches). `zz_act5.js` **[later]**

- **The Alien Temple of the Slayers** (`a5_lair`, 148x148, theme a5_temple): mlvl 40–40; about 104 creatures at generation (mostly Alien Sentinel, Thought-Form, Neural Wraith); 2 lanterns, 4 chests, 1 shrine stone, 1 shrine wisp, 1 shrine echo, 1 altar; links to a5_cerebrum. Act V lair: the Thought of the Slayer; the end credits; then the Scar opens. `zz_act5.js` **[later]**

- **The Scar of Ur-Nihl** (`a5_scar`, 188x124, theme a5_scar): mlvl 36–38; about 55 creatures at generation (mostly Null-Shade, Silence-Keeper); 2 lanterns, 5 chests, 1 shrine echo, 1 shrine stone, 1 shrine wisp; links to a5_town, a5_monolith. Side region: black canyon, void rifts. `zz_act5.js` **[later]**

- **The Silent Monolith** (`a5_monolith`, 140x140, theme a5_scar): mlvl 38–40; about 65 creatures at generation (mostly Null-Shade, Silence-Keeper); 2 lanterns, 5 chests, 1 shrine refill, 2 shrine stone, 1 altar; links to a5_scar. Dead-end treasure. `zz_act5.js` **[later]**

- **The Ossified Vault** (`qvault_2`, 44x44, theme bone): no monsters; about 0 creatures at generation; 3 chest; links to a2_town. `zz_quests.js` **[later]**

- **A Sealed Vault** (`qvault_3`, 44x44, theme crypt): no monsters; about 0 creatures at generation; 3 chest; links to a3_town. `zz_quests.js` **[later]**

- **The Vault of the Unrung Bell** (`qvault_4`, 44x44, theme crypt): no monsters; about 0 creatures at generation; 3 chest; links to a4_town. `zz_quests.js` **[later]**

- **A Sealed Vault** (`qvault_5`, 44x44, theme crypt): no monsters; about 0 creatures at generation; 3 chest; links to a5_town. `zz_quests.js` **[later]**

### 18.4 Towns, waystones and lanterns

- **Towns are safe:** monsters are swept out of the safe circle and cannot hurt you there (`qSafeHere`). Each town has a vendor, healer, smith, quest-giver, the Stranger, the Reliquary Chest and a waystone. Act I: Maren (vendor), Sister Ysolde (healer), Brannoc of the Nail (smith), Warden-Crone Esk (quests). Act II: Qasim the Dust-Factor, Mother Oss-Ana, Ibbat the Knuckle-Smith, the Last Reliquarist. Act III: Lugh the Eel-Monger, Asheth the Leech-Wife, Old Tamb, Priestess Ninsun. Act IV: Dorje the Salt-Trader, Sister Palden, Chime-Wright Ulan, Brother Tenzar. Act V: the Tallow-Merchant, the Nurse Without a Face, Ferrous, the Mysterious Stranger himself. `zz_quests.js` **[Act I]**

- **Waystones (waypoints):** one per town and about every other zone. Act I has 13: moor, hollow_wood, fen, crypt, barrow, cata1, cata2, root_deep, sighing_ridge, pilgrim_road, drowned_village, sunken_bog, burnt_heath. Later acts have every other zone (lairs and vaults none). **Kindled by standing in one** ("… knows your step"). The panel is grouped by act tabs (towns marked). `zz_quests.js` **[Act I]**

- **The waystone's look:** a broken ring of eight fang-shaped standing stones (carved bands, a channel down each face; one fallen) round a sunken pit with steps down. At the bottom something dark and wet breathes under an ash crust; stains seep from the plinths and pale fibres run into the ground. An unknown waystone is clenched shut. `zz_zz_maw95.js` **[Act I]**

- **The travel sequence:** walk to the centre (within 3.5 yd; otherwise plain travel) → sink into the throat as it widens → the body comes apart in blood, bone and viscera → the stones close → black → at the destination the matter draws back together and you rise out of the pit, wet, and it closes behind you. Nothing glows; blood is matter, never light. `zz_zz_maw95.js` `zz_quests.js` **[Act I]**

- **Lanterns (the lantern-stones):** world lanterns in every zone (1–5). Passing within 6 yd kindles one ("… lantern kindled"). Touching one sets your return point, restores life, resource and poise, refills wisps and shards, mends the golem and Colossus, wakes a dormant golem, flips Major Arcana for free, and saves. The lantern panel lists the kindled lanterns for travel. Each lantern has a name and an inscription. `d_play.js` `e_ui.js` `zz_voice.js` `k_arcana.js` **[Act I]**

- **Portals between zones:** caves, gates and stairs placed by each generator. Arriving from a zone puts you at that zone's matching arrival point (`z.arrive[from]`). Act bosses open a gate to the next act's town. `b_core.js` `zz_act1_expand.js` `zz_quests.js` **[Act I]**

- **Quest vaults** (`qvault_2..5`): 44×44 hand-laid rooms opened by the three seals; they hold 3 chests and the vault guardian. `zz_quests.js` **[later]**

### 18.5 Death and return

- **Death:** at 0 life (unless the Last Silence, Last Breath or Second Heart saves you) you die: the banner "ANIMA SEVERED", a death line, and XP loss by difficulty (0 on Normal). Gold is left in a remnant. The lantern keeps a little (section 7). Minions, wisps, shards, the golem, pillars and every summoned thing are cleared; Arcana and Miasma states reset. `d_play.js` `k_arcana.js` `zz_zz_study82.js` `zz_voice.js` **[Act I]**

- **Return:** after 3 s you rise at the last lantern touched, at full life, resource and poise, with a return line ("The lantern gives you back. It keeps a little, as it always does."). Creatures that were chasing go idle. `d_play.js` `zz_voice.js` **[Act I]**

- **Hero death animation:** the PixelLab heroes fall through their death frames and lie there. `zz_monk_hitdeath.js` `zz_zv61.js` **[Act I]**

### 18.6 Day, night and weather

- **The day:** 600 s, starting at 12% through (morning). Day until 55%, dusk to 66%, night to 90%, dawn to 100%. Only outdoor zones have hours; underground is always dim. A corner sky dial shows the hour (no announcement banners since v0.34; hidden while a panel is open). `zd_world22.js` `zv_time24.js` `zz_polish.js` `zz_fix_ui53.js` **[Act I]**

- **The hour's look:** dusk embers and a darkened edge (never a red light source), dawn gold dust in long light, cloud shadows by day, soul-lights wandering at dusk and night. `zv_time24.js` `zz_atmos62.js` **[Act I]**

- **Wind:** one shared gust that mist, leaves, dust, grass and the hero's flame all answer to. `zz_atmos62.js` **[Act I]**

- **Mist banks** drift over the ground and show only where light reaches them; dust turns in the lantern light; leaves tumble on the moor and in the woods. `zz_atmos62.js` `zz_env.js` **[Act I]**

- **Chalk storms** (Act II Chalk Flats), **heartbeat mud** (Act III), **chime-winds** (Act IV), **acid and bile shallows** and the **void** (Act V): see the zone lines. `zz_act2.js` `zz_act3.js` `zz_act4.js` `zz_act5.js` **[later]**

### 18.7 Secrets, chests and shrines

- **Chests:** Act I open zones have 2–7 (26 in the old moor; fewer since v0.22d); two treasure sites in the Fen hold 2 chests each (item level 10) behind guardian packs. The loot rules are in section 13. `b_core.js` `zd_world22.js` **[Act I]**

- **Shrines:** Echoes (+50% skill damage 60 s), the Wisp (+2 wisps and faster regrowth 60 s), Stone (+100 armour 60 s), Refilling (full life and resource). One use each. `d_play.js` **[Act I]**

- **Hidden Arcana shrine:** one per zone, placed as far as possible from the lantern on open ground; +1 Arcana once per zone. `k_arcana.js` **[Act I]**

- **God altars** (Heralds): section 15.4. `zd_world22.js` **[Act I]**

- **Fen guardians and the Barrow lord:** one-time rewards (section 10). `k_arcana.js` **[Act I]**

## 19. Quests (errands)

- **The journal (J):** 5–6 errands per act, tabbed by act. Each shows its name, target, description (with the resolved zone name), state and reward. New errands are written when you reach an act. `zz_quests.js` **[Act I]**

- **Kinds:**

- **zoneboss:** a zone's existing boss.

- **kill:** a named unique placed in a zone.

- **relic:** walk to it and take it.

- **shrine:** kneel; hold through two waves (5 creatures, then 6 with an Extra Fast champion).

- **captive:** the keepers within 12 yd must fall first.

- **seal:** press three seals or bells to open a vault; the guardian inside completes it.

- **actboss.**

Zones resolve by id, or by keyword for acts II–V. `zz_quests.js` **[Act I]**
- **Rewards:** gold, skill points, attribute points, Arcana (as Minor points into the web when possible), +% to every resistance, +life, and a magic, rare or unique relic (rolled until it meets the rarity, dropped at your feet). The banner "ERRAND FULFILLED" and the giver's line. `zz_quests.js` **[Act I]**
- **Act I errands:**
  - **The Carrion Warden** (crypt; 200 gold and a magic item).
  - **The Sighing Lantern** (shrine on the Sighing Ridge; 1 skill point).
  - **The Widow's Daughter** (free Nell in the Drowned Village; 3 attribute points).
  - **The Reader's Ink** (the relic book in the Bone Catacombs I; a rare and 1 Arcana).
  - **The Tallow-Mother** (kill Tallow-Mother Hesk in the Bog-Witch's Shack; +5% all resistances).
  - **The Ossuary Matron** (cata2; 400 gold and a rare).

`zz_quests.js` **[Act I]**
- **Act II:** Obb the Marrow-Gnawer (1 skill), the Banner of the Last Crusade (a rare and 1 Arcana), the Lantern of the Avenue (3 attributes), the Three Knuckle-Seals (vault guardian Hessary; 1 Arcana and 500 gold), Saint Calcifer (900 gold and a rare). `zz_quests.js` **[later]**
- **Act III:** the Sewn Pilgrim (+20 life), Ukko-Tal the Masked Priest (1 skill), the Shell of the First Egg (+5% resist, 300 gold), the Pulse-Well (1 Arcana, 400 gold), the Brood-Mother (1,400 gold and a rare). `zz_quests.js` **[later]**
- **Act IV:** the Frozen Mantras (1 Arcana), the Lantern-Keeper (+10% resist), the Silent Bells (vault guardian Brother Silence; 1 skill), Hollow-Throat (3 attributes), the Chime-Abbot (1,800 gold and a rare). `zz_quests.js` **[later]**
- **Act V:** Foreman Grist (1 skill), the Bell of Reminiscence (2 Arcana), a Crown of the Forgotten Epoch (a unique), the Thought That Remembers You (5 attributes), the Thought of the Slayer (3,000 gold and a unique; the credits). `zz_quests.js` **[later]**
- **The road:** each act boss opens a gate to the next act's town ("THE WAY DOWN OPENS"). After the last boss: the credits (click or key to continue after 2.5 s), then post-game portals to the Scar. `zz_quests.js` **[later]**
- **Quest objects in the world:** relics, shrines, captives and seals are placed on open ground far into their zone (`qFarSpot`); the named kill targets are placed with guards. `zz_quests.js` **[Act I]**

## 20. NPCs, dialogue and the voice of the world

- **Town NPCs:** vendor, healer, smith, stash chest, quest-giver and the Stranger, placed at a town's `npcSpots` or around its centre. Each speaks 4–8 barks per role per town, shown as a wrapped italic line with the speaker's name over any open panel. `zz_quests.js` `zz_voice.js` **[Act I]**

- **The Mysterious Stranger:** in the Reading and in every town. He speaks in half-lines and ellipses and calls each god by a different name every time; 2–3 lines per act that cycle when you talk to him. `zz_quests.js` `zz_art_reading.js` **[Act I]**

- **Zone entry lines:** a quiet italic line (14 words or fewer) under the zone banner the first time you enter (saved per character). `zz_voice.js` **[Act I]**

- **Whispers:** every 60–120 s of exploring (18 words or fewer); never in a boss fight, with a panel open, or twice running. `zz_voice.js` **[Act I]**

- **Inscriptions:** every lantern, waystone and landmark has a name and an inscription (lanterns and waystones when touched, landmarks the first time you pass). Generic lantern names are replaced. `zz_voice.js` **[Act I]**

- **Death and return lines;** **item lore lines** on rare and unique tooltips (by base, and by name for the named uniques). `zz_voice.js` **[Act I]**

- **Messages:** short state lines ("Poise broken", "too shaken to roll", "No room in your inventory") and banners only for moments that matter (level, zone, boss, Herald, Arcana, death, errand). Skill and hour announcements are dropped. `zz_polish.js` **[Act I]**

- **Voice audit:** `window.__voice.audit()` checks the word limits and banned words. `zz_voice.js` **[later]**

- **The text source of truth:** `src/zz_voice.js` (readable copy `claude/godmarrow-voice-lines.md`). `zz_voice.js` **[Act I]**

## 21. UI panels, HUD and hotkeys

- **The bottom bar (HUD)** reads left to right: life orb | left skill | class gauges | belt | menu studs | right skill | resource orb. The slab is carved stone with a bronze rail. The orbs are glass held by stone serpents (the Empty Hand: an hourglass in a pointed niche) and show their value. The XP bar is a gold rule along the top. Skill wells show the bound key and the cost in the order's own resource (life % for the Hemomancer, shards for bone spells), and dim red when it can't be paid. Menu studs are engraved stone tablets. Gauges flash when critical. `zz_ui_hud.js` `zz_hud54.js` `zz_hud55.js` `zz_polish.js` **[Act I]**

- **Class gauges:** the Ossuarch's shard and marrow bars; the Shrine Keeper's OMENS; the Hemomancer's Vitae note; the Mystic's wisp count. `zz_ui_hud.js` **[Act I]**

- **Menu studs:** Inventory (I), Character (C), Skills (S), Map (Tab), the class panels (V/G), The Inverted Triune (A), Menu (Esc). Each is lit when its panel is open and shows a pip when points wait. `zz_ui_hud.js` **[Act I]**

- **Character page (C):** an illuminated vellum page with the order name, level, attributes with +buttons to spend points, and derived stats (life, resource, poise, armour, resists, damage, speed). `e_ui.js` `zz_ui.js` **[Act I]**

- **Inventory (I):** the equipment doll (10 slots), the 10×4 grid, gold, tooltips with sell and use hints. `e_ui.js` `zz_ui.js` **[Act I]**

- **Skills (S):** section 9. **Body board (A):** section 10. `zz_ui.js` `zz_arcana_zbody.js` **[Act I]**

- **Journal (J), Waystones, Stash, Smith's wares, Vendor, Lantern** panels: sections 14 and 18–19. `zz_quests.js` `e_ui.js` **[Act I]**

- **Class panels:** the Mystic's choir (V) and golem orders (G); the Ossuarch's army orders (V or G); the Hemomancer's Flesh (V or G). All share the orders grid: Attack↔Guard × Close↔Roam, focus (strike what you strike) and hold (stay put). `e_ui.js` `g_bone_ui.js` `i_blood_ui.js` **[Act I]**

- **Automap (Tab):** explored tiles within 11 yd are revealed around you (every 0.25 s); portals, lanterns and waystones are marked. `e_ui.js` `d_play.js` **[Act I]**

- **Tooltips:** compact by default (name, 3 lines, cost, one "Now:" line); Shift or MORE shows everything. Smart quotes in the book font. `zz_ui.js` `zz_ui_desc.js` `zz_fix_ui53.js` **[Act I]**

- **Banners and messages:** zone banners in the upper third; the level banner; boss names; short `say` lines. `zz_ui_hud.js` `c_game.js` **[Act I]**

- **Steam Deck (1280×800):** the game fills the screen. `zz_ui_hud.js` **[later]**

- **Hover and targeting:** the thing under the cursor (monster, item, object, corpse) is highlighted and shown in a top line (a monster's name, rank, life and stagger meter); a raisable corpse shows it. `e_ui.js` `t_v17.js` **[Act I]**

## 22. Audio

- **Sound effects:** synthesised with WebAudio oscillators (`sfx(freq, dur, type, vol, slide)`) for every action (swings, hits, rolls, pickups, level up, shrines, tolls, bursts). M toggles sound. Port to recorded or synthesised samples with the same cues. `c_game.js` **[Act I]**

- **Drop sounds by rarity** (section 13) and **gold silent on drop**. `zz_zz_study82.js` **[Act I]**

- **Music engine (the current score, v97 as restored in v101):** live-synthesised in the manner of Diablo II and Lord of Destruction; no melody or sample copied. Each place has a cue with its own seeded motif, stated, answered and varied. Every cue plays on its own bus and buses cross-fade when the place changes. Starts on the first key or click. Music on/off is in the pause menu. `zz_zz_music96.js` **[Act I]**

- **Cues:** the Act I camp (fingerpicked twelve-string in 6/8); wilderness (long silences, wind, drones, reversed guitar, lone harmonics); dungeons (sub drones, clusters, scrapes, heartbeat drums, far bells); Act II (oud-like lute in hijaz over darbuka); Act III (log drums in three-against-four, flute, marimba); Act IV (strings, low horn, men's choir, bells); Act V (a choir at the gate, then industrial inferno); bosses (thunder drums, phrygian ostinato, choir stabs in the act's colour); the title. `zz_zz_music96.js` **[Act I]**

- **The v98–v99 variants** (a sad cello leading, second movements alternating every few minutes) were liked and then rolled back in v101; keep them documented as an option. `wiki/01` **[later]**

- **The Godot slice** renders the Moor's two movements to OGG (`moor_a.ogg`, `moor_b.ogg`) and alternates them; porting the live engine is an open step. `13-godot.md` **[Act I]**

- **Voice lines** are text only (no recorded speech). `zz_voice.js` **[Act I]**

## 23. The Codex (the lore tome)

- **The Codex of the Hide:** opened from the title menu. A book bound in old pitted bronze: vellum pages foxed at the edges, iron-gall ink, bronze rubrics, drop capitals, corner guards with rivets, stacked page edges, a gutter, a ribbon, illuminated initials, a cup stain and a torn corner. `zz_zz_tome94.js` **[Act I]**

- **Layout:** the left leaf is the index (chapters in Roman numerals, the Hush's eye sigil); the right leaf is the chapter. Arrow keys and PageUp/PageDown turn chapters; Escape closes. On a phone the close button sits in the index leaf's corner. `zz_zz_tome94.js` **[Act I]**

- **Content:** nine chapters of in-world works (66 voices): The Reliquary; The Roads and the Stones; The Pale Order; The Gilded Peak; The Polished Heart; The Precious Wound; The House of Eight Million; Before the Last Breath; The Feuds. Each is a preface by the Sage (the Mysterious Stranger), the works, then Relics and Rites. It opens with the Sage's letter (dated 1114 of the Last Breath). Generated from `lore/chapters.py` + `lore/voices/*.md` by `lore/gen.py` into `zz_zz_tome94_text.js`. `zz_zz_tome94_text.js` `lore/gen.py` **[Act I]**

- **Unlock by discovery (for release):** all chapters are open during development; later chapters, paragraphs and relic entries unlock as the player finds them (meeting an order, picking up a relic, reading an inscription, entering a land), and unfound entries show as blank or scratched-out pages. `wiki/09` **[later]**

## 24. Other systems

- **Corpse raising on right-click** near a fresh corpse (whatever skill is on the right button): the Ossuarch drags up a skeleton, the Hemomancer splits it into spawnlings. The corpse under the cursor shows it can be raised. `t_v17.js` **[Act I]**

- **Minion bodies:** the Iron Golem, Colossus, skeletons, Bone Host, spawnlings, oozes, Flesh Golem, the Weeping One, echoes, decoys and molted skins all take hits through `hitTarget` and carry their own life, armour and AI. `d_play.js` `f_bone.js` `h_blood.js` `zw_monk.js` **[Act I]**

- **Wraith, possession, fear and confusion AI** for monsters (`updatePossessed`, `updateFeared`, `updateConfused`). `d_play.js` `k_arcana.js` **[Act I]**

- **Hero animation set:** idle, walk, attack, attack2 (alternating), cast, hit (also played through a poise break), death, dodge (for rolls), 8 facings from 5 painted views (mirrored). PixelLab heroes: Mystic and Hemomancer (lantern in hand), Ossuarch; the Empty Hand is HD. `zz_hero_animancer_r8.js` `zz_hero_hemomancer_r8.js` `zz_hero_ossumancer_r7.js` `zz_hero_monk_hd.js` `zz_zv61.js` **[Act I]**

- **Hero sprite gear:** clothes change with robe, armour, hood or mask (older painters); hands stay free. `zl_heroes22.js` `zq_hero32.js` **[later]**

- **Monster poses:** idle, walk, wind-up, strike, hit, death (and parry for the duelist); 32-bit painters per creature; tints for variants and champions. `zr_mon32.js` `zs_monA.js` `zs_monB.js` `zs_monC.js` **[Act I]**

- **Test hooks:** `window.__spm` (state and functions), `window.__qa` (zone generator, derive, step), `window.__zt` (world painters), `window.__desc`, `window.__voice`, `window.__maw`, `window.__tome`, `window.__web`, `window.__body`, the resist test key 0. Useful for porting tests; strip from release. `e_ui.js` `zz_progression.js` `zz_dbg_hooks.js` `zz_mech_resists.js` **[later]**

- **Android and desktop wrappers:** builds load `data/*.js` beside the page. The Android pause hook saves. `zz_ux_save_hidden.js` `wiki/08` **[later]**

---

## Appendix: where each system lives

- **Core:** `b_core.js` (canvas, tiles, zones, packs, the old Moor, Fen and dungeon generators), `c_game.js` (monsters, items, skills data, `derive`, WS numbers, inventory, loot), `d_play.js` (input, player actions, Mystic spells, damage, zones, objects, monsters AI, save), `e_ui.js` (render, HUD, panels, start).

- **Orders:** `f_bone.js` and `g_bone_ui.js` (Ossuarch), `h_blood.js`, `i_blood_ui.js` and `zy_flesh.js` (Hemomancer), `m_mias.js` and `n_mias_ui.js` (Shrine Keeper), `zw_monk.js`, `zw_monk_ui.js` and `zz_monk_sand.js` (Empty Hand), `zy_anim.js`, `zz_zz_mystic90.js` and `zz_zz_thread93.js` (Hollow Mystic), `o_skills14.js` and `p_ui14.js` (shared skill systems).

- **Arcana:** `k_arcana.js`, `l_arcana_ui.js`, `zz_arcana_web.js`, `zz_arcana_zbody.js`, `zz_arcana_percls.js`, `zz_arcana_monk.js`.

- **Combat tuning:** `zc_combat22.js`, `zz_stagger_deep.js`, `zz_tune_batch_c/d/e.js`, `zz_tune_v58.js`, `zz_zv60.js`, `zz_zz_light79.js`, `zz_mech_heavy.js`, `zz_melee_chain.js`, `zz_mech_balance.js`, `zz_mech_resists.js`, `zz_mech_loot.js`, `zz_pace_and_density.js`, `zz_progression.js`, `zz_movespd_curve.js`.

- **World:** `zd_world22.js`, `zv_time24.js`, `zz_openness.js`, `zz_act1_expand.js`, `zz_world_expand.js`, `zz_act2.js` to `zz_act5.js`, `zz_quests.js`, `zz_landmarks55.js`, `zz_zz_world89.js`, `zz_zz_decor66.js`, `zz_zz_maw95.js`.

- **Light:** `y_light21.js`, `zz_zx_dark64.js`, `zz_zw_lantern63.js`, `zz_zy_lanclip64.js`, `zz_zz_shadow70.js`, `zz_zz_cine76.js`, `zz_zz_moon86.js`, `zz_zz_study82.js`, `zz_zz_perf74.js`.

- **Presentation:** `zz_ui.js`, `zz_ui_desc.js`, `zz_ui_hud.js`, `zz_hud55.js`, `zp_title.js`, `zz_title54.js`, `zz_art_reading.js`, `zz_zz_tome94.js`, `zz_voice.js`, `zz_zz_music96.js`.
