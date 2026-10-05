<!-- Systems · updated 2026-09-30 · 957 words · source page #arcana -->
# 15 · Arcana v103: pathways between the Majors, and the Mystic's balance

User (2026-09-30): "work on skill balance and arcana building, needs more pathways between majors."

## The problem

On every order's body plate the Major Arcana sat at the tips of their pages' branches (the two hands, the crown), and the hybrids at the feet. Every Major was a dead end: holding one opened nothing, and reaching a second page meant walking the whole body back through the seat.

## The change (web v103 and Godot)

- **The rungs:** each page's Majors are joined side by side, one small knot between neighbours (area "The Rungs"; the knot's gift follows the order: Mystic cast speed, damage, Essence; Ossuarch shard, armour, poise; Hemomancer bleeding, life, life on kill; Shrine Keeper sickness, evasion, resist; Empty Hand melee, sun, moon). A held Major opens its sisters for one knot.

- **The Outer Circle:** a road just outside the plate's ring joins the stations all the way round: right hand → right foot → left foot → left hand → crown → right hand. Each arc runs from the Major nearest the neighbour, with a knot every ~2.8 units and a **great knot at its middle** (5 per order, each with its own name, gift and lore line, e.g. the Mystic's *The Bell Over the Anvil*, *The Thread Let Down*, *Between Two Footfalls*, *The Hungry Thread*, *The Rebuke Sung Upward*). Code: `zz_arcana_zbody.js` (`RING`, the block after the Void); Godot reads it from `data/board.json`.

- Result (Mystic plate): 158 → 224 nodes, 164 → 242 roads. A held Major is a crossroads: tested, holding The Anvil opens its rung and the Circle arc.

## Card texts and effects (Hollow Mystic, Godot)

The web's card texts named skills that no longer exist (Spirit Dart, Aether Orb, Mark of Logos, Spirit Ward) and used banned words (lightning, stun). All 36 Mystic cards (and the Hollow and Void cards) were rewritten to the current skills (`tools/arcana_mystic103.json`), and **every one is implemented in Godot** (`skills/animancer.gd`, the Arcana section; `golem.gd`, `hero.gd`, `brain.gd`, `combat.gd`, `missile.gd` hooks). In the web build only about 20 of them ever worked.
- The Anvil: glass splinters on the ground / the golem worn as a shell (half of each blow to its iron, +50% weapon).
- The Maiden's Kiss: the Hall drags in from 3 yd / closes on you (60% of melee blows back, 20% slower).
- Storm: standing mirrors shed a splinter each second / the Mirror Shield rebounds once more per creature cut (up to 4).
- The Choir: the whole choir dives together every 2 s / struck creatures turn on their own kind for 3 s.
- The Bell-Warden: every fifth spell staggers within 3.5 yd / nothing within 5 yd can shoot, and you can't cast for 1 s after a spell.
- The Lantern-Bearer: the Soul Lantern walks with you / swung as a flail (splash, a wisp every other blow).
- The Aether-Sage: Soul Swarm, Needle and Thread and Spool jump to 2 more at 60% / a draining thread, and lance and Spool mend 20%.
- The Hollow Blade: a smouldering seam along the lance / a spirit sword (melee, costs poise).
- Pyre: storm souls and Spool shards set burning / Wraith Form leaves pale fire.
- The Rebuke: the leash cracks like a whip each second / a harpoon that pins.
- Minors: Aftershock, Tarnish, Quicksilver Stride, Rally, Wide Arc, Standing Shards, Swift Wisps, Long Flight (needles 30% farther, one more spark), Great Host, Silver Tether (the golem mends 2%/s near you), Long Vigil, Wake, Deep Veil, Branding Mark, Heavy Spool, Soul Hunger, Wraith Step, Eye of the Storm. Hybrids: The Revenant (a perished wisp returns armoured for 5 s), The Hungering Aether.
- Hollow: Hollow Step, Unheard. Void: The Unwritten, The Choir Crown, The Last Silence, The Unmade (the "both" button on the board).

## Skill balance (Hollow Mystic, Godot, first pass)

**How it was measured:** the balance arena (`core/main.gd --arena=N --arena_t=T`): harmless, tireless targets round a standing hero who casts one skill (`--autocast=`), level 15, the skill alone at level 10, 30 s, Essence as the limit. `--nobal` gives the web's numbers for comparison. Scripts: `/tmp/gd/bal3.sh` (cloud workspace).

**What it found (web numbers):**
- The Mystic starved: 1.35 Essence a second at level 15 against spells costing 25–78, so one dear spell a minute. The pool itself (~80) is D2-like; the costs are not.
- The Thread tree (Soul Leash, Soul Swarm, Needle and Thread) dealt 2–5× the Mirror tree per Essence; Mirror Fissure, Spool and Unravelling trailed badly (≈2–4 per Essence); Unravelling was often uncastable.

**v103 changes (in `skills/animancer.gd` BAL tables and `hero_stats.gd`):**
- Mystic Essence refill ×2.
- Costs ×: Unravelling 0.75, Soul Storm 0.85, Hall of Mirrors 0.82, Mirror Fissure 0.8, Spool 0.8, Falling Mirror 0.9, Standing Mirrors 0.9.
- Damage ×: Mirror Fissure 2.0, Spool 1.6, Unravelling 1.3, Hall of Mirrors 1.3, Falling Mirror 1.2, Binding Thread 1.2, Soul Leash 0.7.
- After (30 s, 4 targets, damage a second): Standing Mirrors 28, Falling Mirror 25, Soul Storm 27, Soul Lantern 34, Soul Swarm 34, Binding Thread 33, Needle and Thread 24, Unravelling 20, Spool 18, Hall 15, Fissure 13, golem 12, Soul Leash ~49 (after its cut). The Mirror skills keep their value in walls, cages and staggers.

## Still to do

- The other orders' cards need the same audit (texts vs current skills, banned words, implementations).

- The web build keeps its old card texts and the old balance (Godot is where the cards now work).

- A second balance pass once the Mystic has been played through Act I (the golem, the Essence economy by level, and the cards' numbers).
