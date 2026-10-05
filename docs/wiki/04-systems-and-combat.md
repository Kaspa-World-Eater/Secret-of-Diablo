<!-- Systems · updated 2026-09-29 · 2412 words · source page #systems -->
# 04 · Systems and combat

*How the game plays. Rules that are law are in `01-rules-and-decisions.md`; order-specific detail is on each class page.*

## 1. Orders, resources and trees

| Order | Resource orb | Trees | Signature |
|---|---|---|---|
| Hollow Mystic | Essence | Mirror · Soul · Thread | the choir of wisps, standing mirrors, the Iron Golem, threads and needles |
| Ossuarch | Marrow (works exactly as mana) | Ossuary · Marrow · Carapace | raised skeletons, the Colossus, a shard aura, straight bone spells, active bone melee |
| Hemomancer | Vitae: every skill costs life, Vitae pays the share | Brood · Blood · Flesh | brood of spawn, the Flesh Golem, bleeds and blood pools, mutations |
| Shrine Keeper | Miasma (breathe in, breathe out) | Miasma · Distortion · Death | a drifting violet haze, Inhale/Exhale, the Vortex, Omens, the war-fan |
| The Empty Hand | the hourglass: Radiance pours amber sand down, Absence black sand up; the fuller a bulb the weaker that tree; Destroyer costs poise | Radiance · Absence · Destroyer | day/night strikes, barefoot, a black-flame lantern |

- Skills carry a [Passive] tag where passive. Tooltips state mechanics plainly; lore goes in flavour text.

- **Rebuild plan:** 12 skills per tree (10 today). Reuse the game's own skills first; the rejected ones (Skull Cup, Ornaments Loosed, Skull's Cry, Ritual Dagger) are not offered again.

- **The class-design Claude Docs** (the user comments inline): "The Orders of the Martyr" https://claude.ai/code/artifact/c16d21e4-fec8-4057-bbbe-bcd9a6803671 · "Hemomancer Skill Trees" https://claude.ai/code/artifact/976cf373-2763-4fdd-a313-c3dfa41b3618 · "Ossuarch Skill Trees" https://claude.ai/code/artifact/f61096c0-3591-4e4d-9dfd-e65f8b9b9935

## 2. Attributes, poise and melee

- **Attributes:** Vitality (life, a trace of poise), Essence, Constitution (poise).

- **Poise:** regenerates gradually; rolling and melee spend it; walking drains it very slowly.

- **Stagger, 20% stronger both ways (v79–v80):** blows break a creature's poise 20% sooner and its reel lasts 20% longer; the player's poise also drains 20% faster and a break stuns 20% longer (0.9 s) (`zz_zz_light79.js`).

- **Break (v60, `zz_zv60.js`):** a 0.75 s stun; after a grace, poise refills fast to **half** (burst), then regenerates normally. **No rolling until poise is full** (`P._noRoll`, "too shaken to roll"). The PixelLab heroes play their hit animation when hurt and through a heavy stun (`zz_zv61.js`).

- **Monster poise:** PoE2-style: high poise, quick recovery, a grace period, no stun-lock.

- **Melee string (every order, from the Empty Hand's moveset, `zz_melee_chain.js`):** quick cut, return cut, a slow overhead finisher that lunges, hits 1.6× and staggers; a held heavy (`zz_mech_heavy.js`); the roll. The PixelLab heroes alternate two strike animations (atk/atk2) and use a dodge animation for rolls.

- **Ossuarch melee:** D2 Paladin/Barbarian-style strikes on either button, costing poise; his weapon becomes that skill's bone weapon for the stroke.

## 3. Light, the lantern and the dark (the signature system)

- **The Wickbound lantern** (lore in 02) is its own untargetable unit (`zz_zy_lanclip64.js`): floats at shoulder height, trails a little behind while walking, drifts to the hero's side and idles in slow loops when still, bobs and leans. `window.__lampW()` = its world position; `__plLamp()` = its glass on screen; `__lampFoot()` = the ground under it.

- **The pool:** the darkness layer (`zz_zx_dark64.js`) covers the world and cuts a pool under the lantern: brightest by the lantern, a natural falloff, a faint ring just inside the edge, the dark deepening out to about twice the radius, never pitch black. By day it's a dusk you can see through. World flames, campfires and each wisp cut their own smaller pools. The dark is **blue-teal** (analogous), so warm light reads amber.

- **Light radius** is a stat: `heroLightR()`; lantern stats widen it (`lrad`); `__lampK` = 1.5 + lrad/100·0.5.

- **Lantern perks** roll on items and are **benign** (`zz_zw_lantern63.js`):

| Perk | Effect |
|---|---|
| Bright (`lrad`) | light radius |
| Ghostlight (`lblue`) | creatures in the light may flee (`m.feared`) |
| Hearth (`lamber`) | life regeneration |
| Pale wick (`lwhite`) | slows creatures in the light |
| Green Taper (`lgreen`) | essence regeneration |
| Violet (`lviolet`) | essence on kill in the light |

- **The flame's mood (v77):** below 30% life the pool shrinks and stutters; in a boss fight it gutters and draws in (`__lampMood`).

- **Shadows (v73, `zz_zz_shadow70.js`):** the hero throws a true silhouette shadow away from the lantern, a second from the nearest flames, and by day a sun shadow that turns and lengthens with the hour. Your lantern also throws monsters' shadows (desktop). No blob under the hero.

- **Cinematic cues (v77, `zz_zz_cine76.js`):** eye-shine from creatures in the dark facing you (brighter when hunting); items in your light glint; rare cold distant lightning at night on open ground (never in town or a boss fight).

- **Wisps** cast light (their own small pools), no shadow, and shed a little twinkling dust. A darting wisp keeps the same ghost look (no comet streak, v79).

- **The Hollow Mystic's wisps are fuel (v80):** each spell burns one wisp (two for the dearest, cost ≥ 40) but is never refused. His spell damage follows the choir he has when it strikes: 65% with no wisps, rising to 120% at a full choir (`__choirK`). Soul Swarm, Soul Storm, the echo and Condense keep their own wisp costs; his melee and golem are unaffected.

- **The choir shapes the spell too (v81)**, judged at the moment of casting: a full choir (≥80%) adds one more mirror, pillar, chain bounce or totem, and the thin choir (26 ms average) on any device. Force with `?fx=lo` / `?fx=hi`.

- In lighter mode: the dark is painted at half resolution and a third as often; the light map is quantised every other frame; only the lantern shadow, with no pixel readback; no monster wedge shadows; slightly less ground scatter.

- Everywhere: the HUD orbs repaint only when their level moves or the ripple is due (they were the biggest per-frame cost).
